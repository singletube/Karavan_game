"""Retarget locomotion clips from "Zombie De Goma" onto the cyborg template.

Source model: "Zombie De Goma" by julianmurcia245 (CC-BY-4.0)
https://sketchfab.com/3d-models/zombie-de-goma-d0da88595c6b47129170937d1e442733

The source is a Mixamo-style rig whose rest pose (T-pose) and bone rolls differ
completely from the cyborg template. Retargeting therefore does not copy local
rotations; it matches bone *directions* in world space ("aim" retargeting):

    for every mapped bone pair, rotate the target bone so that the direction
    towards its child matches the source direction.

This is robust to different rest poses, bone rolls and limb lengths, and it
reproduces the knee/foot behaviour of the source exactly, so knees can never
bend the wrong way.

Usage:
    python tools/retarget_zombie_anim.py <source scene.gltf> <template.glb> <out.glb>
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fix_movement_animations import (  # noqa: E402
    Rig,
    load_glb,
    save_glb,
    read_accessor,
    qmul,
    qinv,
    qnorm,
    qslerp,
    world_rotation,
    min_skinned_y,
)

FPS = 30

# (source bone, target bone, source child, target child)
BONE_MAP = [
    ("hip_016", "Hips", "spine01_052", "Spine"),
    ("spine01_052", "Spine", "chest_017", "Chest"),
    ("chest_017", "Chest", "neck_013", "Neck"),
    ("neck_013", "Neck", "head_014", "Head"),
    ("head_014", "Head", "jaw_019", "Jaw"),
    ("shoulder_L_015", "Clavicle.L", "upper_arm_L_03", "UpperArm.L"),
    ("upper_arm_L_03", "UpperArm.L", "forearm_L_051", "Forearm.L"),
    ("forearm_L_051", "Forearm.L", "hand_L_01", "Hand.L"),
    ("shoulder_R_06", "Clavicle.R", "upper_arm_R_07", "UpperArm.R"),
    ("upper_arm_R_07", "UpperArm.R", "forearm_R_09", "Forearm.R"),
    ("forearm_R_09", "Forearm.R", "hand_R_010", "Hand.R"),
    ("thigh_L_034", "Thigh.L", "shin_L_035", "Shin.L"),
    ("shin_L_035", "Shin.L", "foot_L_036", "Foot.L"),
    ("foot_L_036", "Foot.L", "toe_L_037", "Toes.L"),
    ("thigh_R_038", "Thigh.R", "shin_R_039", "Shin.R"),
    ("shin_R_039", "Shin.R", "foot_R_040", "Foot.R"),
    ("foot_R_040", "Foot.R", "toe_R_041", "Toes.R"),
]

# target clip name -> (segments, looping)
# A segment is (source clip, start seconds, end seconds or None). The source
# "death" clip already lies on the ground, so Death is built from "down"
# (standing -> lying) followed by the first part of "death" (throes).
CLIPS = {
    "Idle": ([("idle01", 0.0, None)], True),
    "Walk": ([("walk01", 0.0, None)], True),
    "Run": ([("run", 0.0, None)], True),
    "Hit": ([("damage", 0.0, 0.9)], False),
    "Death": ([("down", 0.0, None), ("death", 0.0, 2.0)], False),
    "Attack": ([("attack01", 0.0, None)], False),
    "Roar": ([("attack02", 0.0, None)], False),
}

# The source is authored at ~2.2x the height of the template; horizontal hip
# travel is scaled by the leg-length ratio so weight shifts stay believable.
HIPS_SCALE = 0.181

# Clips where the body leaves its feet: the vertical hip trajectory comes from
# the source and a single offset grounds the whole clip, so the fall keeps its
# arc instead of being glued to the floor every frame.
FALL_CLIPS = {"Death"}


def load_gltf_file(path: Path):
    """Load a .gltf plus its external buffers into one byte chunk."""
    gltf = json.loads(path.read_text(encoding="utf-8"))
    chunk = bytearray()
    for buffer in gltf.get("buffers", []):
        uri = buffer.get("uri")
        if not uri or uri.startswith("data:"):
            continue
        data = (path.parent / uri).read_bytes()
        chunk.extend(data)
    return gltf, chunk


def load_channels(gltf, bin_chunk, rig: Rig, anim: dict):
    out = {}
    for (node, path), (inp, outp) in rig.channels(anim).items():
        times = read_accessor(gltf, bin_chunk, inp).reshape(-1).astype(np.float64)
        values = read_accessor(gltf, bin_chunk, outp).astype(np.float64)
        out[(node, path)] = (times, values)
    return out


def _interp(times, values, t, is_rotation):
    if len(times) == 1:
        return values[0].copy()
    t = min(max(t, float(times[0])), float(times[-1]))
    i = int(np.searchsorted(times, t, side="right") - 1)
    i = max(0, min(i, len(times) - 2))
    t0, t1 = float(times[i]), float(times[i + 1])
    a = 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
    if is_rotation:
        return qslerp(qnorm(values[i]), qnorm(values[i + 1]), a)
    return values[i] * (1.0 - a) + values[i + 1] * a


def sample_pose(rig: Rig, channels, t):
    tt = [v.copy() for v in rig.rest_t]
    qq = [v.copy() for v in rig.rest_q]
    ss = [v.copy() for v in rig.rest_s]
    for (node, path), (times, values) in channels.items():
        if path == "rotation":
            qq[node] = _interp(times, values, t, True)
        elif path == "translation":
            tt[node] = _interp(times, values, t, False)
        elif path == "scale":
            ss[node] = _interp(times, values, t, False)
    return tt, qq, ss


def quat_from_to(a, b):
    """Minimal rotation (quaternion) turning direction `a` onto `b`."""
    na = float(np.linalg.norm(a))
    nb = float(np.linalg.norm(b))
    if na < 1e-9 or nb < 1e-9:
        return np.array([0.0, 0.0, 0.0, 1.0])
    a = np.asarray(a, dtype=np.float64) / na
    b = np.asarray(b, dtype=np.float64) / nb
    d = float(np.dot(a, b))
    if d > 0.9999995:
        return np.array([0.0, 0.0, 0.0, 1.0])
    if d < -0.9999995:
        axis = np.cross(a, np.array([1.0, 0.0, 0.0]))
        if float(np.linalg.norm(axis)) < 1e-6:
            axis = np.cross(a, np.array([0.0, 0.0, 1.0]))
        axis = axis / float(np.linalg.norm(axis))
        return np.array([axis[0], axis[1], axis[2], 0.0])
    axis = np.cross(a, b)
    return qnorm(np.array([axis[0], axis[1], axis[2], 1.0 + d]))


def add_accessor(gltf, bin_chunk, values, type_name):
    values = np.asarray(values, dtype=np.float32)
    while len(bin_chunk) % 4:
        bin_chunk.append(0)
    offset = len(bin_chunk)
    bin_chunk.extend(values.tobytes())
    gltf["bufferViews"].append({
        "buffer": 0,
        "byteOffset": offset,
        "byteLength": int(values.nbytes),
    })
    accessor = {
        "bufferView": len(gltf["bufferViews"]) - 1,
        "componentType": 5126,
        "count": int(values.shape[0]),
        "type": type_name,
    }
    flat = values.reshape(values.shape[0], -1)
    accessor["min"] = [float(v) for v in flat.min(axis=0)]
    accessor["max"] = [float(v) for v in flat.max(axis=0)]
    gltf["accessors"].append(accessor)
    return len(gltf["accessors"]) - 1


def build_clip(gltf, bin_chunk, rig: Rig, name: str, times, quats, hips_t):
    anim = {"name": name, "samplers": [], "channels": []}
    input_idx = add_accessor(gltf, bin_chunk, np.asarray(times, dtype=np.float32).reshape(-1, 1), "SCALAR")
    for node, frames in quats.items():
        out_idx = add_accessor(gltf, bin_chunk, np.asarray(frames, dtype=np.float32), "VEC4")
        anim["samplers"].append({"input": input_idx, "output": out_idx, "interpolation": "LINEAR"})
        anim["channels"].append({
            "sampler": len(anim["samplers"]) - 1,
            "target": {"node": node, "path": "rotation"},
        })
    hips = rig.index["Hips"]
    out_idx = add_accessor(gltf, bin_chunk, np.asarray(hips_t, dtype=np.float32), "VEC3")
    anim["samplers"].append({"input": input_idx, "output": out_idx, "interpolation": "LINEAR"})
    anim["channels"].append({
        "sampler": len(anim["samplers"]) - 1,
        "target": {"node": hips, "path": "translation"},
    })
    return anim


def retarget_clip(src_anims, src_gltf, src_bin, src_rig, tgt_gltf, tgt_bin, tgt_rig,
                  name, segments, looping):
    timeline = []
    for src_name, start, end in segments:
        src_anim = src_anims.get(src_name)
        if src_anim is None:
            print(f"  ! source clip {src_name!r} not found, skipping {name}")
            return None
        channels = load_channels(src_gltf, src_bin, src_rig, src_anim)
        duration = max(float(times[-1]) for (times, _values) in channels.values())
        begin = max(0.0, float(start))
        finish = duration if end is None else min(duration, float(end))
        timeline.append((channels, begin, finish))

    total = sum(finish - begin for (_c, begin, finish) in timeline)
    frame_count = int(round(total * FPS))
    if looping:
        # Sample the full cycle inclusive of the end pose (which repeats the
        # start) so Godot's LOOP_LINEAR wraps without a visible pop.
        step = total / max(1, frame_count)
        sample_times = [i * step for i in range(frame_count + 1)]
    else:
        sample_times = [i / FPS for i in range(frame_count + 1)]

    src_rest_world = src_rig.world_matrices(src_rig.rest_t, src_rig.rest_q, src_rig.rest_s)
    src_hips = src_rig.index["hip_016"]
    tgt_hips = tgt_rig.index["Hips"]
    tgt_rest_world = tgt_rig.world_matrices(tgt_rig.rest_t, tgt_rig.rest_q, tgt_rig.rest_s)

    quats = {tgt_rig.index[tgt]: [] for (_s, tgt, _sc, _tc) in BONE_MAP}
    hips_t = []
    floor_offsets = []
    height_scale = float(tgt_rig.rest_t[tgt_hips][1]) / float(src_rest_world[src_hips][1, 3])

    for t in sample_times:
        # Locate the segment that contains this point of the combined timeline.
        offset = 0.0
        channels, begin, finish = timeline[0]
        for index, (seg_channels, seg_begin, seg_finish) in enumerate(timeline):
            is_last = index == len(timeline) - 1
            if t < offset + (seg_finish - seg_begin) or is_last:
                channels, begin, finish = seg_channels, seg_begin, seg_finish
                break
            offset += seg_finish - seg_begin
        src_t = begin + min(max(t - offset, 0.0), finish - begin)

        st, sq, ss = sample_pose(src_rig, channels, src_t)
        src_world = src_rig.world_matrices(st, sq, ss)

        q = [v.copy() for v in tgt_rig.rest_q]
        tr = [v.copy() for v in tgt_rig.rest_t]
        sc = [v.copy() for v in tgt_rig.rest_s]

        # Hip motion from the source: horizontal weight shift for every clip,
        # plus the vertical trajectory for falls. Falls use the height ratio
        # (the template's legs are proportionally shorter than the source's),
        # so the body does not hover while it topples over.
        delta = src_world[src_hips][:3, 3] - src_rest_world[src_hips][:3, 3]
        if name in FALL_CLIPS:
            vertical = float(src_world[src_hips][1, 3]) * height_scale - tgt_rig.rest_t[tgt_hips][1]
            tr[tgt_hips] = tgt_rig.rest_t[tgt_hips] + np.array(
                [delta[0] * HIPS_SCALE, vertical, delta[2] * HIPS_SCALE])
        else:
            tr[tgt_hips] = tgt_rig.rest_t[tgt_hips] + np.array(
                [delta[0], 0.0, delta[2]], dtype=np.float64) * HIPS_SCALE

        for src_b, tgt_b, src_c, tgt_c in BONE_MAP:
            world_q = tgt_rig.world_quats(q)
            world = tgt_rig.world_matrices(tr, q, sc)
            src_dir = src_world[src_rig.index[src_c]][:3, 3] - src_world[src_rig.index[src_b]][:3, 3]
            tgt_dir = world[tgt_rig.index[tgt_c]][:3, 3] - world[tgt_rig.index[tgt_b]][:3, 3]
            rot = quat_from_to(tgt_dir, src_dir)
            world_rotation(tgt_rig, q, world_q, tgt_rig.index[tgt_b], rot)

        # Ground the pose. Locomotion is glued to the floor every frame; a fall
        # keeps the source vertical trajectory and is grounded once at the end.
        world = tgt_rig.world_matrices(tr, q, sc)
        lowest = min_skinned_y(tgt_gltf, tgt_bin, tgt_rig, world)
        if name in FALL_CLIPS:
            floor_offsets.append(lowest)
        else:
            tr[tgt_hips] = tr[tgt_hips] - np.array([0.0, lowest, 0.0])

        for (_s, tgt, _sc, _tc) in BONE_MAP:
            quats[tgt_rig.index[tgt]].append(q[tgt_rig.index[tgt]].copy())
        hips_t.append(tr[tgt_hips].copy())

    if name in FALL_CLIPS and floor_offsets:
        shift = np.array([0.0, min(floor_offsets), 0.0])
        hips_t = [value - shift for value in hips_t]

    if looping:
        # The source run does not close its cycle perfectly. Spread the
        # difference over the whole cycle so the loop is seamless.
        count = len(sample_times)
        identity = np.array([0.0, 0.0, 0.0, 1.0])
        for node, frames in quats.items():
            delta = qmul(qinv(frames[-1]), frames[0])
            for i in range(count):
                weight = i / max(1, count - 1)
                frames[i] = qnorm(qmul(frames[i], qslerp(identity, delta, weight)))
        delta_t = np.asarray(hips_t[0]) - np.asarray(hips_t[-1])
        for i in range(count):
            weight = i / max(1, count - 1)
            hips_t[i] = np.asarray(hips_t[i]) + delta_t * weight

    label = " + ".join(src_name for (src_name, _s, _e) in segments)
    print(f"  {name:6s} <- {label:18s} {total:.3f}s ({len(sample_times)} frames)")
    return build_clip(tgt_gltf, tgt_bin, tgt_rig, name, sample_times, quats, hips_t)


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 1
    src_path = Path(sys.argv[1])
    tgt_path = Path(sys.argv[2])
    out_path = Path(sys.argv[3])

    src_gltf, src_bin = load_gltf_file(src_path)
    src_rig = Rig(src_gltf)
    tgt_gltf, tgt_bin = load_glb(tgt_path)
    tgt_rig = Rig(tgt_gltf)

    src_anims = {a.get("name"): a for a in src_gltf.get("animations", [])}
    new_anims = []
    print("Retargeting:")
    for name, (segments, looping) in CLIPS.items():
        anim = retarget_clip(src_anims, src_gltf, src_bin, src_rig,
                             tgt_gltf, tgt_bin, tgt_rig,
                             name, segments, looping)
        if anim is not None:
            new_anims.append(anim)

    kept = [a for a in tgt_gltf.get("animations", []) if a.get("name") not in CLIPS]
    tgt_gltf["animations"] = kept + new_anims
    tgt_gltf["buffers"][0]["byteLength"] = len(tgt_bin)
    save_glb(out_path, tgt_gltf, tgt_bin)
    print(f"Wrote {out_path} ({out_path.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

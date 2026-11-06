# -*- coding: utf-8 -*-
"""
Build the final zombie movement animations from the original template.

The original Walk/Run clips are authored backwards (the planted foot travels
forward), the arms hang behind the back, and the legs barely flex while the
body floats above the ground. This script fixes all of that in one pass:

  1. Walk / Run are reversed in time, so the planted foot travels backwards.
  2. Upper arms are rotated forward around the character's left-right axis and
     elbows are flexed, so the arms swing in front of the body instead of
     staying behind the back.
  3. Idle gets a relaxed knee bend; Walk/Run get extra knee flexion on the
     swing leg (the leg whose foot is higher), so the knees visibly bend.
  4. Every frame is grounded: the Hips are shifted vertically so the lowest
     skinned vertex touches y = 0.

Run this on the ORIGINAL, unpatched template only. The fix is not idempotent.
Usage:
    python tools/fix_movement_animations.py <original.glb> <output.glb>
"""

from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import numpy as np

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------
REVERSE_CLIPS = {"Walk", "Run"}
POLISH_CLIPS = {"Idle", "Walk", "Run"}

# Forward is +Z on this rig. Negative rotation around world X swings a limb
# forward; -25 degrees puts the hanging arms next to/in front of the hips.
ARM_WORLD_X_DEG = -25.0
# Elbow flexion (local X of the forearm). Negative bends the hand forward.
FOREARM_LOCAL_X_DEG = -25.0
# Keep only this fraction of the authored arm swing. The source clips swing the
# arms too far behind the torso; blending towards the rest pose tames it.
ARM_SWING_SCALE = 0.55
# Relaxed stance for Idle.
IDLE_SHIN_LOCAL_X_DEG = -8.0
# Extra knee flexion for the swing leg in Walk/Run.
SWING_KNEE_LOCAL_X_DEG = -20.0
# Foot height difference (metres) at which the swing knee gets full flexion.
SWING_KNEE_FULL_DIFF = 0.08

COMPONENT_FORMAT = {
    5120: "b",
    5121: "B",
    5122: "h",
    5123: "H",
    5125: "I",
    5126: "f",
}

TYPE_COUNT = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
    "MAT2": 4,
    "MAT3": 9,
    "MAT4": 16,
}

NP_DTYPE = {
    5120: np.int8,
    5121: np.uint8,
    5122: np.int16,
    5123: np.uint16,
    5125: np.uint32,
    5126: np.float32,
}


# ---------------------------------------------------------------------------
# GLB / accessor helpers
# ---------------------------------------------------------------------------
def load_glb(path: Path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("Not a GLB file")
    offset = 12
    json_chunk = None
    bin_chunk = None
    while offset < length:
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        offset += 8
        chunk = data[offset:offset + chunk_len]
        offset += chunk_len
        if chunk_type == 0x4E4F534A:
            json_chunk = chunk
        elif chunk_type == 0x004E4942:
            bin_chunk = bytearray(chunk)
    if json_chunk is None or bin_chunk is None:
        raise ValueError("GLB is missing JSON or BIN chunk")
    return json.loads(json_chunk.decode("utf-8")), bin_chunk


def save_glb(path: Path, gltf: dict, bin_chunk: bytearray):
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    bin_bytes = bytes(bin_chunk)
    bin_bytes += b"\x00" * ((4 - len(bin_bytes) % 4) % 4)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
    out = bytearray()
    out += struct.pack("<III", 0x46546C67, 2, total)
    out += struct.pack("<II", len(json_bytes), 0x4E4F534A)
    out += json_bytes
    out += struct.pack("<II", len(bin_bytes), 0x004E4942)
    out += bin_bytes
    path.write_bytes(out)


def accessor_layout(gltf: dict, accessor_index: int):
    accessor = gltf["accessors"][accessor_index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    component_type = accessor["componentType"]
    comps = TYPE_COUNT[accessor["type"]]
    dtype = NP_DTYPE[component_type]
    count = accessor["count"]
    item_size = np.dtype(dtype).itemsize * comps
    stride = view.get("byteStride") or item_size
    base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return accessor, view, dtype, comps, count, item_size, stride, base


def read_accessor(gltf: dict, bin_chunk: bytearray, accessor_index: int) -> np.ndarray:
    _, _, dtype, comps, count, item_size, stride, base = accessor_layout(gltf, accessor_index)
    if stride == item_size:
        arr = np.frombuffer(bin_chunk, dtype=dtype, count=count * comps, offset=base)
        return arr.reshape(count, comps).copy()
    out = np.empty((count, comps), dtype=dtype)
    for i in range(count):
        out[i] = np.frombuffer(bin_chunk, dtype=dtype, count=comps, offset=base + i * stride)
    return out


def write_accessor(gltf: dict, bin_chunk: bytearray, accessor_index: int, values: np.ndarray):
    accessor, _, dtype, comps, count, item_size, stride, base = accessor_layout(gltf, accessor_index)
    if values.shape != (count, comps):
        raise ValueError(f"Accessor {accessor_index}: expected {(count, comps)}, got {values.shape}")
    flat = values.astype(dtype).reshape(-1)
    if stride == item_size:
        view = np.frombuffer(bin_chunk, dtype=dtype, count=count * comps, offset=base)
        view[:] = flat
    else:
        for i in range(count):
            item = np.frombuffer(bin_chunk, dtype=dtype, count=comps, offset=base + i * stride)
            item[:] = flat[i * comps:(i + 1) * comps]
    if "min" in accessor or "max" in accessor:
        for c in range(comps):
            column = values[:, c]
            if "min" in accessor:
                accessor["min"][c] = float(column.min())
            if "max" in accessor:
                accessor["max"][c] = float(column.max())


# ---------------------------------------------------------------------------
# Math
# ---------------------------------------------------------------------------
def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    ], dtype=np.float64)


def qnorm(q):
    n = math.sqrt(float(np.dot(q, q)))
    if n < 1e-12:
        return np.array([0.0, 0.0, 0.0, 1.0])
    return q / n


def qinv(q):
    return np.array([-q[0], -q[1], -q[2], q[3]], dtype=np.float64)


def qx(degrees: float):
    half = math.radians(degrees) * 0.5
    return np.array([math.sin(half), 0.0, 0.0, math.cos(half)], dtype=np.float64)


def qslerp(a, b, t: float):
    """Spherical interpolation from a (t=0) to b (t=1)."""
    a = qnorm(np.asarray(a, dtype=np.float64))
    b = qnorm(np.asarray(b, dtype=np.float64))
    dot = float(np.dot(a, b))
    if dot < 0.0:
        b = -b
        dot = -dot
    if dot > 0.9995:
        return qnorm(a + t * (b - a))
    theta = math.acos(max(-1.0, min(1.0, dot)))
    sin_theta = math.sin(theta)
    if sin_theta < 1e-12:
        return a.copy()
    wa = math.sin((1.0 - t) * theta) / sin_theta
    wb = math.sin(t * theta) / sin_theta
    return qnorm(wa * a + wb * b)


def trs_matrix(t, q, s):
    x, y, z, w = q
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    m = np.eye(4, dtype=np.float64)
    m[0, 0] = 1.0 - 2.0 * (yy + zz)
    m[0, 1] = 2.0 * (xy - wz)
    m[0, 2] = 2.0 * (xz + wy)
    m[1, 0] = 2.0 * (xy + wz)
    m[1, 1] = 1.0 - 2.0 * (xx + zz)
    m[1, 2] = 2.0 * (yz - wx)
    m[2, 0] = 2.0 * (xz - wy)
    m[2, 1] = 2.0 * (yz + wx)
    m[2, 2] = 1.0 - 2.0 * (xx + yy)
    m[:3, :3] *= np.asarray(s, dtype=np.float64)[None, :]
    m[:3, 3] = np.asarray(t, dtype=np.float64)
    return m


# ---------------------------------------------------------------------------
# Animation sampling
# ---------------------------------------------------------------------------
class Rig:
    def __init__(self, gltf: dict):
        self.gltf = gltf
        self.nodes = gltf["nodes"]
        self.names = [n.get("name", "") for n in self.nodes]
        self.index = {name: i for i, name in enumerate(self.names)}
        self.parent = {}
        for i, node in enumerate(self.nodes):
            for child in node.get("children", []):
                self.parent[child] = i

        self.rest_t = []
        self.rest_q = []
        self.rest_s = []
        for node in self.nodes:
            self.rest_t.append(np.array(node.get("translation", [0.0, 0.0, 0.0]), dtype=np.float64))
            self.rest_q.append(qnorm(np.array(node.get("rotation", [0.0, 0.0, 0.0, 1.0]), dtype=np.float64)))
            self.rest_s.append(np.array(node.get("scale", [1.0, 1.0, 1.0]), dtype=np.float64))

    def channels(self, anim: dict):
        out = {}
        for channel in anim["channels"]:
            target = channel["target"]
            sampler = anim["samplers"][channel["sampler"]]
            out[(target["node"], target["path"])] = (sampler["input"], sampler["output"])
        return out

    def sample(self, values: dict, frame: int):
        count = len(self.nodes)
        t = [None] * count
        q = [None] * count
        s = [None] * count
        for i in range(count):
            key_t = (i, "translation")
            key_q = (i, "rotation")
            key_s = (i, "scale")
            t[i] = self.rest_t[i].copy()
            q[i] = self.rest_q[i].copy()
            s[i] = self.rest_s[i].copy()
            if key_t in values:
                t[i] = values[key_t][frame].astype(np.float64)
            if key_q in values:
                q[i] = qnorm(values[key_q][frame].astype(np.float64))
            if key_s in values:
                s[i] = values[key_s][frame].astype(np.float64)
        return t, q, s

    def world_matrices(self, t, q, s):
        count = len(self.nodes)
        world = [None] * count

        def get(i):
            if world[i] is None:
                m = trs_matrix(t[i], q[i], s[i])
                if i in self.parent:
                    m = get(self.parent[i]) @ m
                world[i] = m
            return world[i]

        for i in range(count):
            get(i)
        return world

    def world_quats(self, q):
        count = len(self.nodes)
        world = [None] * count

        def get(i):
            if world[i] is None:
                if i in self.parent:
                    world[i] = qnorm(qmul(get(self.parent[i]), q[i]))
                else:
                    world[i] = qnorm(q[i])
            return world[i]

        for i in range(count):
            get(i)
        return world


def reverse_clip(gltf: dict, bin_chunk: bytearray, anim: dict):
    """Reverse every output accessor of a clip exactly once."""
    done = set()
    for channel in anim["channels"]:
        sampler = anim["samplers"][channel["sampler"]]
        out_idx = sampler["output"]
        if out_idx in done:
            continue
        values = read_accessor(gltf, bin_chunk, out_idx)
        values = values[::-1].copy()
        write_accessor(gltf, bin_chunk, out_idx, values)
        done.add(out_idx)


def min_skinned_y(gltf: dict, bin_chunk: bytearray, rig: Rig, world):
    skin = gltf["skins"][0]
    joints = skin["joints"]
    ibm_raw = read_accessor(gltf, bin_chunk, skin["inverseBindMatrices"])
    # glTF matrices are column-major: transpose each 4x4 block.
    ibm = ibm_raw.reshape(-1, 4, 4).transpose(0, 2, 1)
    joint_world = np.array([world[j] for j in joints])
    joint_mats = np.einsum("nij,njk->nik", joint_world, ibm)

    min_y = float("inf")
    ones = np.ones((1, 1))
    for node_idx, node in enumerate(gltf["nodes"]):
        if "mesh" not in node or node.get("skin") != 0:
            continue
        mesh = gltf["meshes"][node["mesh"]]
        mesh_world = world[node_idx]
        mesh_world_inv = np.linalg.inv(mesh_world)
        local_joint_mats = np.einsum("ij,njk->nik", mesh_world_inv, joint_mats)
        for prim in mesh["primitives"]:
            attrs = prim["attributes"]
            if not all(k in attrs for k in ("POSITION", "JOINTS_0", "WEIGHTS_0")):
                continue
            pos = read_accessor(gltf, bin_chunk, attrs["POSITION"]).astype(np.float64)
            jidx = read_accessor(gltf, bin_chunk, attrs["JOINTS_0"]).astype(np.int64)
            weights = read_accessor(gltf, bin_chunk, attrs["WEIGHTS_0"]).astype(np.float64)
            p4 = np.concatenate([pos, np.ones((pos.shape[0], 1))], axis=1)
            skinned = np.zeros((pos.shape[0], 3), dtype=np.float64)
            for k in range(4):
                mats = local_joint_mats[jidx[:, k]]
                transformed = np.einsum("nij,nj->ni", mats, p4)
                skinned += weights[:, k, None] * transformed[:, :3]
            skinned4 = np.concatenate([skinned, np.ones((skinned.shape[0], 1))], axis=1)
            world_pos = np.einsum("ij,nj->ni", mesh_world, skinned4)[:, :3]
            min_y = min(min_y, float(world_pos[:, 1].min()))
    return min_y


def polish_clip(gltf: dict, bin_chunk: bytearray, rig: Rig, anim: dict):
    name = anim.get("name", "")
    channels = rig.channels(anim)
    values = {}
    for key, (input_idx, output_idx) in channels.items():
        values[key] = read_accessor(gltf, bin_chunk, output_idx)
    count = len(next(iter(values.values())))

    hips = rig.index["Hips"]
    upper_l = rig.index["UpperArm.L"]
    upper_r = rig.index["UpperArm.R"]
    fore_l = rig.index["Forearm.L"]
    fore_r = rig.index["Forearm.R"]
    shin_l = rig.index["Shin.L"]
    shin_r = rig.index["Shin.R"]
    foot_l = rig.index["Foot.L"]
    foot_r = rig.index["Foot.R"]

    hips_trans_accessor = channels[(hips, "translation")][1]
    hips_trans = read_accessor(gltf, bin_chunk, hips_trans_accessor).astype(np.float64)

    new_quats = {b: [] for b in (upper_l, upper_r, fore_l, fore_r, shin_l, shin_r)}
    new_hips_y = []

    for frame in range(count):
        t, q, s = rig.sample(values, frame)

        # Foot heights before any leg correction.
        world_before = rig.world_matrices(t, q, s)
        foot_y_l = world_before[foot_l][1, 3]
        foot_y_r = world_before[foot_r][1, 3]

        # Arms: rotate the upper arm around world X (parent-space conjugation),
        # then flex the elbow around its own local X.
        world_q = rig.world_quats(q)
        for upper, fore in ((upper_l, fore_l), (upper_r, fore_r)):
            # Tame the exaggerated authored swing before correcting the arms.
            q[upper] = qslerp(rig.rest_q[upper], q[upper], ARM_SWING_SCALE)
            q[fore] = qslerp(rig.rest_q[fore], q[fore], ARM_SWING_SCALE)
            parent_q = world_q[rig.parent[upper]]
            q_world = qx(ARM_WORLD_X_DEG)
            correction = qmul(qmul(qinv(parent_q), q_world), parent_q)
            q[upper] = qnorm(qmul(correction, q[upper]))
            q[fore] = qnorm(qmul(q[fore], qx(FOREARM_LOCAL_X_DEG)))

        # Knees.
        if name == "Idle":
            q[shin_l] = qnorm(qmul(q[shin_l], qx(IDLE_SHIN_LOCAL_X_DEG)))
            q[shin_r] = qnorm(qmul(q[shin_r], qx(IDLE_SHIN_LOCAL_X_DEG)))
        elif name in ("Walk", "Run"):
            diff = abs(foot_y_l - foot_y_r)
            weight = max(0.0, min(1.0, diff / SWING_KNEE_FULL_DIFF))
            swing_shin = shin_l if foot_y_l > foot_y_r else shin_r
            q[swing_shin] = qnorm(qmul(q[swing_shin], qx(SWING_KNEE_LOCAL_X_DEG * weight)))

        # Ground the pose: shift Hips so the lowest skinned vertex is at y=0.
        world_after = rig.world_matrices(t, q, s)
        lowest = min_skinned_y(gltf, bin_chunk, rig, world_after)
        hips_offset = -lowest
        new_hips_y.append(float(t[hips][1] + hips_offset))

        for b in new_quats:
            new_quats[b].append(q[b].copy())

    # Write modified rotation accessors.
    for bone, values in new_quats.items():
        acc = channels[(bone, "rotation")][1]
        write_accessor(gltf, bin_chunk, acc, np.array(values, dtype=np.float64))

    # Write modified Hips translation.
    hips_trans[:, 1] = np.array(new_hips_y, dtype=np.float64)
    write_accessor(gltf, bin_chunk, hips_trans_accessor, hips_trans)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    source = Path(sys.argv[1])
    target = Path(sys.argv[2]) if len(sys.argv) > 2 else source.with_name(
        source.stem + "_fixed" + source.suffix
    )
    gltf, bin_chunk = load_glb(source)

    # 1. Reverse the backwards locomotion clips.
    for anim in gltf.get("animations", []):
        if anim.get("name") in REVERSE_CLIPS:
            reverse_clip(gltf, bin_chunk, anim)

    # 2. Polish Idle/Walk/Run: arms, knees, ground contact.
    rig = Rig(gltf)
    for anim in gltf.get("animations", []):
        if anim.get("name") in POLISH_CLIPS:
            polish_clip(gltf, bin_chunk, rig, anim)

    save_glb(target, gltf, bin_chunk)
    print(f"Wrote {target} ({target.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

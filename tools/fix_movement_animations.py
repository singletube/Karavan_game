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
  3. The authored knee bend hyperextends and is bent at the wrong phase, so
     locomotion knees are rebuilt from foot lift: nearly straight on the ground
     and flexing as the foot rises. The death clip is straightened.
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
# Every clip is grounded so the lowest skinned vertex touches y = 0.
GROUND_CLIPS = {"Idle", "Walk", "Run", "Attack", "Death", "Hit", "Roar"}
# Clips whose arms get the forward correction and whose knees get rebuilt.
ARM_POLISH_CLIPS = {"Idle", "Walk", "Run"}
# The authored shin rotation hyperextends the knee and bends it at the wrong
# phase (bent while planted, straight while lifted). For these clips the knee
# flexion is rebuilt from the foot lift instead: nearly straight on the ground,
# bending as the foot rises.
KNEE_LIFT_CLIPS = {"Idle", "Walk", "Run"}
# Extra knee flexion (degrees) added to the rest pose at full foot lift.
KNEE_LIFT_AMP = {"Idle": 2.0, "Walk": 38.0, "Run": 56.0}
# Maximum backward tilt of the shin (degrees from vertical) while the thigh is
# behind the body. Without this clamp the rebuilt knee throws the shin up
# horizontally, which reads as an ostrich kick.
KNEE_SHIN_BACK_LIMIT = {"Walk": 50.0, "Run": 65.0}
# The authored stride swings the thigh extremely far back (47 deg walk, 70 deg
# run). Clamp that backward swing so the trailing leg does not kick up like a
# bird; the stride stays long enough to read as a walk/run.
KNEE_THIGH_BACK_LIMIT = {"Walk": 38.0, "Run": 50.0}
# The authored death clip folds the knees the wrong way while falling. Keep
# them almost straight so the zombie simply topples over.
KNEE_STRAIGHT_CLIPS = {"Death"}
KNEE_STRAIGHT_EXTRA = 4.0
# The rest skeleton splays the legs outward (~9 degrees per leg). Rotate both
# thighs inwards around the forward axis to bring the feet closer together.
STANCE_CLIPS = {"Idle", "Walk", "Run", "Attack", "Hit", "Roar"}
STANCE_INWARD_DEG = 6.0

# The source clips lean the whole body far forward (up to ~39 degrees in Run).
# Each entry is (pelvis tilt, torso lean) in degrees: the pelvis is straightened
# first, then the spine is straightened until the hips->neck line matches.
UPRIGHT_TARGETS = {
    "Idle": (None, 3.0),
    "Walk": (None, 5.0),
    "Run": (None, 10.0),
}

# Forward is +Z on this rig. Negative rotation around the chest's left-right
# axis swings a limb forward; -25 degrees puts the hanging arms next to/in front
# of the hips.
ARM_WORLD_X_DEG = -25.0
# Elbow flexion (local X of the forearm). Negative bends the hand forward.
FOREARM_LOCAL_X_DEG = -25.0
# Keep only this fraction of the authored arm swing. The source clips swing the
# arms too far behind the torso; blending towards the rest pose tames it.
ARM_SWING_SCALE = 0.55
# Clips where the hands must never end up behind the torso. Value is
# (minimum angle in degrees of the shoulder->hand line measured from the chest's
# "down" axis towards its "forward" axis, ramp start frame, ramp end frame).
# Used by the death pose, whose authored arms fold behind the back. The
# correction fades in so the flailing during the fall is preserved.
HAND_FRONT_CLIPS = {"Death": (8.0, 8, 30)}

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


def qaxis(axis, degrees: float):
    """Quaternion rotating `degrees` around an arbitrary world-space axis."""
    ax, ay, az = float(axis[0]), float(axis[1]), float(axis[2])
    length = math.sqrt(ax * ax + ay * ay + az * az)
    if length < 1e-12:
        return np.array([0.0, 0.0, 0.0, 1.0], dtype=np.float64)
    ax, ay, az = ax / length, ay / length, az / length
    half = math.radians(degrees) * 0.5
    s = math.sin(half)
    return np.array([ax * s, ay * s, az * s, math.cos(half)], dtype=np.float64)


def rotate_vec(q, v):
    """Rotate a 3-vector by a quaternion."""
    x, y, z, w = q
    qv = np.array([x, y, z], dtype=np.float64)
    v = np.asarray(v, dtype=np.float64)
    t = 2.0 * np.cross(qv, v)
    return v + w * t + np.cross(qv, t)


def world_rotation(rig: "Rig", q, world_q, bone: int, rot):
    """Pre-multiply a world-space rotation onto a bone's local rotation."""
    parent = rig.parent.get(bone)
    if parent is None:
        parent_q = np.array([0.0, 0.0, 0.0, 1.0], dtype=np.float64)
    else:
        parent_q = world_q[parent]
    corr = qmul(qmul(qinv(parent_q), rot), parent_q)
    q[bone] = qnorm(qmul(corr, q[bone]))


def world_x_tilt(matrix) -> float:
    """Forward tilt (degrees) of a node's Y axis in the world YZ plane."""
    y_axis = matrix[:3, 1]
    return math.degrees(math.atan2(float(y_axis[2]), float(y_axis[1])))


def signed_knee_angle(world, rig: "Rig", side: str) -> float:
    """Signed knee flexion (degrees) around the thigh's hinge axis.

    Positive means the shin swings backwards relative to the thigh (a normal
    knee bend); negative means the shin swings forwards (hyperextension).
    """
    hip = world[rig.index[f"Thigh.{side}"]][:3, 3]
    knee = world[rig.index[f"Shin.{side}"]][:3, 3]
    ankle = world[rig.index[f"Foot.{side}"]][:3, 3]
    u = knee - hip
    v = ankle - knee
    nu = math.sqrt(float(np.dot(u, u)))
    nv = math.sqrt(float(np.dot(v, v)))
    axis = world[rig.index[f"Thigh.{side}"]][:3, 0]
    na = math.sqrt(float(np.dot(axis, axis)))
    if nu < 1e-9 or nv < 1e-9 or na < 1e-9:
        return 0.0
    u = u / nu
    v = v / nv
    axis = axis / na
    return math.degrees(math.atan2(float(np.dot(np.cross(u, v), axis)), float(np.dot(u, v))))


def _smooth_loop(values, radius: int = 2):
    """Circular moving average for looping clips."""
    n = len(values)
    if n == 0:
        return []
    out = []
    for i in range(n):
        total = 0.0
        for k in range(-radius, radius + 1):
            total += values[(i + k) % n]
        out.append(total / (2 * radius + 1))
    return out


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
    spine = rig.index["Spine"]
    neck = rig.index["Neck"]
    chest = rig.index["Chest"]
    upper_l = rig.index["UpperArm.L"]
    upper_r = rig.index["UpperArm.R"]
    fore_l = rig.index["Forearm.L"]
    fore_r = rig.index["Forearm.R"]
    hand_l = rig.index["Hand.L"]
    hand_r = rig.index["Hand.R"]
    shin_l = rig.index["Shin.L"]
    shin_r = rig.index["Shin.R"]
    thigh_l = rig.index["Thigh.L"]
    thigh_r = rig.index["Thigh.R"]
    foot_l = rig.index["Foot.L"]
    foot_r = rig.index["Foot.R"]

    hips_trans_accessor = channels[(hips, "translation")][1]
    hips_trans = read_accessor(gltf, bin_chunk, hips_trans_accessor).astype(np.float64)

    touched = [hips, spine, upper_l, upper_r, fore_l, fore_r, shin_l, shin_r]
    if name in STANCE_CLIPS:
        touched += [thigh_l, thigh_r, foot_l, foot_r]
    new_quats = {b: [] for b in touched}
    new_hips_y = []

    # Rest knee angle (the rest pose has a slight natural bend).
    rest_world = rig.world_matrices(rig.rest_t, rig.rest_q, rig.rest_s)
    rest_knee = {
        "L": signed_knee_angle(rest_world, rig, "L"),
        "R": signed_knee_angle(rest_world, rig, "R"),
    }

    # Foot lift per frame, used to time the rebuilt knee flexion. The ankle
    # height is normalised per foot; a clip with almost no vertical foot travel
    # (Idle) gets a flat, slightly bent stance.
    lift_l = [0.0] * count
    lift_r = [0.0] * count
    if name in KNEE_LIFT_CLIPS:
        raw_l = []
        raw_r = []
        for base_frame in range(count):
            bt, bq, bs = rig.sample(values, base_frame)
            bw = rig.world_matrices(bt, bq, bs)
            raw_l.append(float(bw[foot_l][1, 3]))
            raw_r.append(float(bw[foot_r][1, 3]))

        def _normalize(raw):
            lo, hi = min(raw), max(raw)
            if hi - lo < 0.05:
                return [0.0] * len(raw)
            return [max(0.0, min(1.0, (v - lo) / (hi - lo))) for v in raw]

        lift_l = _smooth_loop(_normalize(raw_l))
        lift_r = _smooth_loop(_normalize(raw_r))

    # Straightening is a constant offset: the authored sway of the clip is kept.
    pelvis_base = None
    lean_base = None
    if name in UPRIGHT_TARGETS:
        pelvis_base = []
        lean_base = []
        for base_frame in range(count):
            bt, bq, bs = rig.sample(values, base_frame)
            bw = rig.world_matrices(bt, bq, bs)
            pelvis_base.append(world_x_tilt(bw[hips]))
            bdz = bw[neck][2, 3] - bw[hips][2, 3]
            bdy = bw[neck][1, 3] - bw[hips][1, 3]
            lean_base.append(math.degrees(math.atan2(float(bdz), float(bdy))))
        pelvis_mean = sum(pelvis_base) / count
        lean_mean = sum(lean_base) / count

    for frame in range(count):
        t, q, s = rig.sample(values, frame)

        # Straighten the body: first the pelvis, then the spine. Both are pure
        # world-X rotations, so the measured forward tilt changes by exactly the
        # applied angle.
        if name in UPRIGHT_TARGETS:
            target_pelvis, target_torso = UPRIGHT_TARGETS[name]
            world_q = rig.world_quats(q)
            world = rig.world_matrices(t, q, s)
            if target_pelvis is not None:
                pelvis = world_x_tilt(world[hips])
                pelvis_goal = target_pelvis + (pelvis_base[frame] - pelvis_mean)
                world_rotation(rig, q, world_q, hips, qx(pelvis_goal - pelvis))

            # The spine joint sits between the hips and the neck, so one rotation
            # only removes part of the lean. Iterate until the measured lean hits
            # the target.
            lean_goal = target_torso + (lean_base[frame] - lean_mean)
            for _ in range(8):
                world_q = rig.world_quats(q)
                world = rig.world_matrices(t, q, s)
                dz = world[neck][2, 3] - world[hips][2, 3]
                dy = world[neck][1, 3] - world[hips][1, 3]
                lean = math.degrees(math.atan2(float(dz), float(dy)))
                delta = lean_goal - lean
                if abs(delta) < 0.05:
                    break
                world_rotation(rig, q, world_q, spine, qx(delta))

        # Arms: swing the upper arms forward around the chest's left-right axis,
        # then flex the elbows around their own local X.
        if name in ARM_POLISH_CLIPS:
            world_q = rig.world_quats(q)
            chest_x = rotate_vec(world_q[chest], (1.0, 0.0, 0.0))
            for upper, fore in ((upper_l, fore_l), (upper_r, fore_r)):
                # Tame the exaggerated authored swing before correcting the arms.
                q[upper] = qslerp(rig.rest_q[upper], q[upper], ARM_SWING_SCALE)
                q[fore] = qslerp(rig.rest_q[fore], q[fore], ARM_SWING_SCALE)
                world_rotation(rig, q, world_q, upper, qaxis(chest_x, ARM_WORLD_X_DEG))
                q[fore] = qnorm(qmul(q[fore], qx(FOREARM_LOCAL_X_DEG)))

        # Clamp the extreme backward thigh swing before narrowing/knees.
        if name in KNEE_THIGH_BACK_LIMIT:
            world = rig.world_matrices(t, q, s)
            world_q = rig.world_quats(q)
            axis = world[hips][:3, 0]
            limit = -KNEE_THIGH_BACK_LIMIT[name]
            for side, thigh in (("L", thigh_l), ("R", thigh_r)):
                hip_pos = world[thigh][:3, 3]
                knee_pos = world[rig.index[f"Shin.{side}"]][:3, 3]
                v = knee_pos - hip_pos
                tilt = math.degrees(math.atan2(float(v[2]), float(-v[1])))
                if tilt < limit:
                    world_rotation(rig, q, world_q, thigh, qaxis(axis, tilt - limit))

        # Narrow the stance: the rest skeleton splays both legs outward, so
        # rotate the thighs inwards around the forward axis and roll the feet
        # back to level. Applied to standing clips only (Death lies down).
        if name in STANCE_CLIPS:
            world_q = rig.world_quats(q)
            for thigh, sign in ((thigh_l, -1.0), (thigh_r, 1.0)):
                world_rotation(rig, q, world_q, thigh,
                               qaxis((0.0, 0.0, 1.0), sign * STANCE_INWARD_DEG))

        # Knees: the authored shin rotation hyperextends the joint and bends it
        # at the wrong phase. Locomotion knees are rebuilt from foot lift, and
        # the death clip is kept almost straight. Rotating the shin around the
        # thigh's hinge axis by (target - current) sets the angle exactly.
        if name in KNEE_LIFT_CLIPS or name in KNEE_STRAIGHT_CLIPS:
            world_q = rig.world_quats(q)
            world = rig.world_matrices(t, q, s)
            for side, shin, lift in (("L", shin_l, lift_l[frame]),
                                     ("R", shin_r, lift_r[frame])):
                if name in KNEE_STRAIGHT_CLIPS:
                    target = rest_knee[side] + KNEE_STRAIGHT_EXTRA
                else:
                    target = rest_knee[side] + KNEE_LIFT_AMP[name] * _smoothstep(lift)
                    if name in KNEE_SHIN_BACK_LIMIT:
                        thigh = world[rig.index[f"Thigh.{side}"]]
                        knee_pos = world[rig.index[f"Shin.{side}"]][:3, 3]
                        tv = knee_pos - thigh[:3, 3]
                        thigh_tilt = math.degrees(
                            math.atan2(float(tv[2]), float(-tv[1]))
                        )
                        target = max(
                            rest_knee[side],
                            min(target, KNEE_SHIN_BACK_LIMIT[name] + thigh_tilt),
                        )
                current = signed_knee_angle(world, rig, side)
                axis = world[rig.index[f"Thigh.{side}"]][:3, 0]
                world_rotation(rig, q, world_q, shin, qaxis(axis, target - current))

        # Keep the feet level after the inward stance rotation.
        if name in STANCE_CLIPS:
            world_q = rig.world_quats(q)
            for foot, sign in ((foot_l, 1.0), (foot_r, -1.0)):
                world_rotation(rig, q, world_q, foot,
                               qaxis((0.0, 0.0, 1.0), sign * STANCE_INWARD_DEG))

        # Keep the hands in front of the torso (the death pose folds them behind
        # the back). The whole arm rotates rigidly about the shoulder, so the
        # angle correction is exact. The correction ramps in over the clip.
        if name in HAND_FRONT_CLIPS:
            phi_min, ramp_start, ramp_end = HAND_FRONT_CLIPS[name]
            if frame <= ramp_start:
                weight = 0.0
            elif frame >= ramp_end:
                weight = 1.0
            else:
                weight = _smoothstep((frame - ramp_start) / float(ramp_end - ramp_start))
            if weight > 0.0:
                world_q = rig.world_quats(q)
                world = rig.world_matrices(t, q, s)
                chest_q = world_q[chest]
                chest_inv = qinv(chest_q)
                for upper, hand in ((upper_l, hand_l), (upper_r, hand_r)):
                    shoulder = world[upper][:3, 3]
                    v = world[hand][:3, 3] - shoulder
                    local_v = rotate_vec(chest_inv, v)
                    phi = math.degrees(math.atan2(float(local_v[2]), float(-local_v[1])))
                    if phi < phi_min:
                        axis = rotate_vec(chest_q, (1.0, 0.0, 0.0))
                        world_rotation(rig, q, world_q, upper,
                                       qaxis(axis, (phi - phi_min) * weight))

        # Ground the pose: shift Hips so the lowest skinned vertex is at y=0.
        world_after = rig.world_matrices(t, q, s)
        lowest = min_skinned_y(gltf, bin_chunk, rig, world_after)
        new_hips_y.append(float(t[hips][1] - lowest))

        for b in new_quats:
            new_quats[b].append(q[b].copy())

    # Write modified rotation accessors.
    for bone, new_values in new_quats.items():
        acc = channels[(bone, "rotation")][1]
        write_accessor(gltf, bin_chunk, acc, np.array(new_values, dtype=np.float64))

    # Write modified Hips translation.
    hips_trans[:, 1] = np.array(new_hips_y, dtype=np.float64)
    write_accessor(gltf, bin_chunk, hips_trans_accessor, hips_trans)


# ---------------------------------------------------------------------------
# Attack: rebuilt from scratch
# ---------------------------------------------------------------------------
# The authored Attack flails (arms cross the face, torso bends sideways). It is
# replaced by a readable two-arm claw lunge: pull back, thrust forward, recover.
# Angles are degrees; arm/elbow follow the same conventions as above, thigh and
# shin bend the legs into a crouch.
ATTACK_KEYS = [
    (0, dict(pelvis=0, spine=0, chest=0, head=0, arm_l=0, arm_r=0,
             elbow_l=0, elbow_r=0, thigh=0, shin=0, hip_z=0.0)),
    (4, dict(pelvis=-2, spine=-4, chest=-4, head=4, arm_l=14, arm_r=20,
             elbow_l=-70, elbow_r=-88, thigh=-5, shin=10, hip_z=-0.02)),
    (8, dict(pelvis=-4, spine=-7, chest=-7, head=6, arm_l=20, arm_r=28,
             elbow_l=-82, elbow_r=-98, thigh=-7, shin=14, hip_z=-0.045)),
    (12, dict(pelvis=6, spine=10, chest=8, head=-6, arm_l=-58, arm_r=-70,
              elbow_l=-18, elbow_r=-10, thigh=-15, shin=28, hip_z=0.08)),
    (16, dict(pelvis=8, spine=12, chest=10, head=-8, arm_l=-66, arm_r=-78,
              elbow_l=-26, elbow_r=-18, thigh=-17, shin=32, hip_z=0.06)),
    (21, dict(pelvis=3, spine=5, chest=4, head=-3, arm_l=-24, arm_r=-30,
              elbow_l=-32, elbow_r=-28, thigh=-8, shin=16, hip_z=0.015)),
    (27, dict(pelvis=0, spine=0, chest=0, head=0, arm_l=0, arm_r=0,
              elbow_l=0, elbow_r=0, thigh=0, shin=0, hip_z=0.0)),
]


def _smoothstep(x: float) -> float:
    return x * x * (3.0 - 2.0 * x)


def _attack_params(frame: int) -> dict:
    keys = ATTACK_KEYS
    if frame <= keys[0][0]:
        return dict(keys[0][1])
    for (f0, p0), (f1, p1) in zip(keys, keys[1:]):
        if frame <= f1:
            u = _smoothstep((frame - f0) / float(f1 - f0))
            return {k: p0[k] + (p1[k] - p0[k]) * u for k in p0}
    return dict(keys[-1][1])


def build_attack(gltf: dict, bin_chunk: bytearray, rig: Rig, anim: dict):
    channels = rig.channels(anim)
    count = len(read_accessor(gltf, bin_chunk, next(iter(channels.values()))[1]))

    hips = rig.index["Hips"]
    spine = rig.index["Spine"]
    chest = rig.index["Chest"]
    neck = rig.index["Neck"]
    upper_l = rig.index["UpperArm.L"]
    upper_r = rig.index["UpperArm.R"]
    fore_l = rig.index["Forearm.L"]
    fore_r = rig.index["Forearm.R"]
    thigh_l = rig.index["Thigh.L"]
    thigh_r = rig.index["Thigh.R"]
    shin_l = rig.index["Shin.L"]
    shin_r = rig.index["Shin.R"]
    foot_l = rig.index["Foot.L"]
    foot_r = rig.index["Foot.R"]

    animated = sorted({node for (node, path) in channels if path == "rotation"})
    new_rot = {bone: [] for bone in animated}
    new_hips_t = []

    for frame in range(count):
        p = _attack_params(frame)
        q = [q.copy() for q in rig.rest_q]

        q[hips] = qnorm(qmul(qx(p["pelvis"]), q[hips]))
        world_q = rig.world_quats(q)
        world_rotation(rig, q, world_q, spine, qx(p["spine"]))
        world_q = rig.world_quats(q)
        world_rotation(rig, q, world_q, chest, qx(p["chest"]))
        world_q = rig.world_quats(q)
        world_rotation(rig, q, world_q, neck, qx(p["head"]))

        world_q = rig.world_quats(q)
        chest_x = rotate_vec(world_q[chest], (1.0, 0.0, 0.0))
        for upper, fore, arm, elbow in (
            (upper_l, fore_l, p["arm_l"], p["elbow_l"]),
            (upper_r, fore_r, p["arm_r"], p["elbow_r"]),
        ):
            world_rotation(rig, q, world_q, upper, qaxis(chest_x, arm))
            q[fore] = qnorm(qmul(q[fore], qx(elbow)))

        world_q = rig.world_quats(q)
        for thigh, shin, foot in ((thigh_l, shin_l, foot_l), (thigh_r, shin_r, foot_r)):
            world_rotation(rig, q, world_q, thigh, qx(p["thigh"]))
            world_q2 = rig.world_quats(q)
            world_rotation(rig, q, world_q2, shin, qx(p["shin"]))
            world_q3 = rig.world_quats(q)
            world_rotation(rig, q, world_q3, foot, qx(-(p["thigh"] + p["shin"])))

        for bone in animated:
            new_rot[bone].append(q[bone].copy())

        rest_t = rig.rest_t[hips].copy()
        rest_t[2] += p["hip_z"]
        new_hips_t.append(rest_t)

    for bone, new_values in new_rot.items():
        write_accessor(gltf, bin_chunk, channels[(bone, "rotation")][1],
                       np.array(new_values, dtype=np.float64))
    write_accessor(gltf, bin_chunk, channels[(hips, "translation")][1],
                   np.array(new_hips_t, dtype=np.float64))


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    source = Path(sys.argv[1])
    target = Path(sys.argv[2]) if len(sys.argv) > 2 else source.with_name(
        source.stem + "_fixed" + source.suffix
    )
    gltf, bin_chunk = load_glb(source)
    rig = Rig(gltf)

    # 1. Reverse the backwards locomotion clips.
    for anim in gltf.get("animations", []):
        if anim.get("name") in REVERSE_CLIPS:
            reverse_clip(gltf, bin_chunk, anim)

    # 2. Rebuild the flailing attack animation.
    for anim in gltf.get("animations", []):
        if anim.get("name") == "Attack":
            build_attack(gltf, bin_chunk, rig, anim)

    # 3. Straighten, polish arms/knees and ground every clip.
    for anim in gltf.get("animations", []):
        if anim.get("name") in GROUND_CLIPS:
            polish_clip(gltf, bin_chunk, rig, anim)

    save_glb(target, gltf, bin_chunk)
    print(f"Wrote {target} ({target.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# -*- coding: utf-8 -*-
"""Temporary per-frame walk/run diagnostic."""
import json
import math
import struct
import sys
from pathlib import Path


def load(path):
    d = Path(path).read_bytes()
    off = 12
    j = b = None
    total = struct.unpack_from("<I", d, 8)[0]
    while off < total:
        ln, tp = struct.unpack_from("<II", d, off)
        off += 8
        ch = d[off:off + ln]
        off += ln
        if tp == 0x4E4F534A:
            j = json.loads(ch.decode("utf-8"))
        elif tp == 0x004E4942:
            b = ch
    return j, b


j, b = load(sys.argv[1])


def acc(i):
    a = j["accessors"][i]
    v = j["bufferViews"][a["bufferView"]]
    comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    fmt = {5126: "f", 5123: "H", 5125: "I", 5121: "B", 5120: "b", 5122: "h"}[a["componentType"]]
    base = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride") or struct.calcsize("<" + fmt * comps)
    return [struct.unpack_from("<" + fmt * comps, b, base + k * stride) for k in range(a["count"])]


nodes = j["nodes"]
names = [n.get("name", "") for n in nodes]
idx = {n: i for i, n in enumerate(names)}
parents = {}
for i, n in enumerate(nodes):
    for c in n.get("children", []):
        parents[c] = i


def mat(t, q, s):
    x, y, z, w = q
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    return [[(1 - 2 * (yy + zz)) * s[0], 2 * (xy - wz) * s[1], 2 * (xz + wy) * s[2], t[0]],
            [2 * (xy + wz) * s[0], (1 - 2 * (xx + zz)) * s[1], 2 * (yz - wx) * s[2], t[1]],
            [2 * (xz - wy) * s[0], 2 * (yz + wx) * s[1], (1 - 2 * (xx + yy)) * s[2], t[2]],
            [0.0, 0.0, 0.0, 1.0]]


def mm(a, c):
    return [[sum(a[r][k] * c[k][col] for k in range(4)) for col in range(4)] for r in range(4)]


def sample(an, frame):
    chans = {}
    for ch in an["channels"]:
        t = ch["target"]
        s = an["samplers"][ch["sampler"]]
        chans[(t["node"], t["path"])] = acc(s["output"])
    local = []
    for i, n in enumerate(nodes):
        t = n.get("translation", [0, 0, 0])
        q = n.get("rotation", [0, 0, 0, 1])
        s = n.get("scale", [1, 1, 1])
        if (i, "translation") in chans:
            t = chans[(i, "translation")][frame]
        if (i, "rotation") in chans:
            q = chans[(i, "rotation")][frame]
        if (i, "scale") in chans:
            s = chans[(i, "scale")][frame]
        local.append((t, q, s))
    world = [None] * len(nodes)

    def get(i):
        if world[i] is None:
            m = mat(*local[i])
            if i in parents:
                m = mm(get(parents[i]), m)
            world[i] = m
        return world[i]

    for i in range(len(nodes)):
        get(i)
    return {names[i]: (world[i][0][3], world[i][1][3], world[i][2][3]) for i in range(len(names))}


def sub(a, c):
    return tuple(x - y for x, y in zip(a, c))


def angle(a, c):
    la = math.sqrt(sum(x * x for x in a))
    lc = math.sqrt(sum(x * x for x in c))
    d = sum(x * y for x, y in zip(a, c)) / (la * lc)
    return math.degrees(math.acos(max(-1.0, min(1.0, d))))


for clip in ("Walk", "Run"):
    an = next(a for a in j["animations"] if a.get("name") == clip)
    count = len(acc(an["samplers"][0]["input"]))
    print("==", clip)
    print(" f   t     Lknee  LfootY LfootZ  LtoeY  Rknee  RfootY RfootZ  RtoeY   LhandZ RhandZ")
    for f in range(count):
        pos = sample(an, f)
        t = acc(an["samplers"][0]["input"])[f][0]
        vals = []
        for side in ("L", "R"):
            th, sh, ft, toe = pos[f"Thigh.{side}"], pos[f"Shin.{side}"], pos[f"Foot.{side}"], pos[f"Toes.{side}"]
            vals.append((angle(sub(sh, th), sub(ft, sh)), ft[1], ft[2], toe[1]))
        ch = pos["Chest"]
        hl = pos["Hand.L"][2] - ch[2]
        hr = pos["Hand.R"][2] - ch[2]
        print(f"{f:2d} {t:5.3f}  {vals[0][0]:5.1f}  {vals[0][1]:+.3f} {vals[0][2]:+.3f}  {vals[0][3]:+.3f}  "
              f"{vals[1][0]:5.1f}  {vals[1][1]:+.3f} {vals[1][2]:+.3f}  {vals[1][3]:+.3f}   {hl:+.3f} {hr:+.3f}")

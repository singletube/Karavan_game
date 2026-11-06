# -*- coding: utf-8 -*-
"""Temporary rig/animation diagnostic for the zombie cyborg GLB."""
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


def main(path):
    j, b = load(path)

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
    index = {n: i for i, n in enumerate(names)}
    parents = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parents[c] = i

    def qmul(a, c):
        ax, ay, az, aw = a
        bx, by, bz, bw = c
        return (aw * bx + ax * bw + ay * bz - az * by,
                aw * by - ax * bz + ay * bw + az * bx,
                aw * bz + ax * by - ay * bx + az * bw,
                aw * bw - ax * bx - ay * by - az * bz)

    def mat(t, q, s):
        x, y, z, w = q
        xx, yy, zz = x * x, y * y, z * z
        xy, xz, yz = x * y, x * z, y * z
        wx, wy, wz = w * x, w * y, w * z
        return [[(1 - 2 * (yy + zz)) * s[0], 2 * (xy - wz) * s[1], 2 * (xz + wy) * s[2], t[0]],
                [2 * (xy + wz) * s[0], (1 - 2 * (xx + zz)) * s[1], 2 * (yz - wx) * s[2], t[1]],
                [2 * (xz - wy) * s[0], 2 * (yz + wx) * s[1], (1 - 2 * (xx + yy)) * s[2], t[2]],
                [0.0, 0.0, 0.0, 1.0]]

    def mmul(a, c):
        return [[sum(a[r][k] * c[k][col] for k in range(4)) for col in range(4)] for r in range(4)]

    def sample(an, frame):
        chans = {}
        for ch in an["channels"]:
            t = ch["target"]
            s = an["samplers"][ch["sampler"]]
            chans[(t["node"], t["path"])] = (acc(s["input"]), acc(s["output"]))
        local = []
        for i, n in enumerate(nodes):
            t = n.get("translation", [0, 0, 0])
            q = n.get("rotation", [0, 0, 0, 1])
            s = n.get("scale", [1, 1, 1])
            if (i, "translation") in chans:
                t = chans[(i, "translation")][1][frame]
            if (i, "rotation") in chans:
                q = chans[(i, "rotation")][1][frame]
            if (i, "scale") in chans:
                s = chans[(i, "scale")][1][frame]
            local.append((t, q, s))
        world = [None] * len(nodes)

        def get(i):
            if world[i] is None:
                m = mat(*local[i])
                if i in parents:
                    m = mmul(get(parents[i]), m)
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

    for clip in ("Idle", "Walk", "Run", "Attack"):
        an = next(a for a in j["animations"] if a.get("name") == clip)
        count = len(acc(an["samplers"][0]["input"]))
        print("==", clip, "frames", count)
        for f in sorted({0, count // 4, count // 2, (3 * count) // 4, count - 1}):
            pos = sample(an, f)
            line = [f"f{f:2d}"]
            for side in ("L", "R"):
                th, sh, ft = pos[f"Thigh.{side}"], pos[f"Shin.{side}"], pos[f"Foot.{side}"]
                knee = angle(sub(sh, th), sub(ft, sh))
                # Signed sagittal knee: shin direction relative to thigh in Y/Z (forward = -Z)
                td = sub(sh, th)
                sd = sub(ft, sh)
                # angle of shin in thigh's YZ plane, positive = heel backward (+Z)
                signed = math.degrees(math.atan2(sd[2], -sd[1]) - math.atan2(td[2], -td[1]))
                line.append(f"{side}: knee={knee:5.1f} sign={signed:+6.1f}")
            ch = pos["Chest"]
            for side in ("L", "R"):
                ua, fa, hd = pos[f"UpperArm.{side}"], pos[f"Forearm.{side}"], pos[f"Hand.{side}"]
                elbow = angle(sub(fa, ua), sub(hd, fa))
                line.append(f"{side}elb={elbow:4.1f} hand=({hd[0]-ch[0]:+.2f},{hd[1]-ch[1]:+.2f},{hd[2]-ch[2]:+.2f})")
            print("  " + "  ".join(line))

    print("\nREST world positions / local axes:")
    # Build rest world matrices
    rest = []
    for i, n in enumerate(nodes):
        rest.append((n.get("translation", [0, 0, 0]), n.get("rotation", [0, 0, 0, 1]), n.get("scale", [1, 1, 1])))
    world = [None] * len(nodes)

    def getr(i):
        if world[i] is None:
            m = mat(*rest[i])
            if i in parents:
                m = mmul(getr(parents[i]), m)
            world[i] = m
        return world[i]

    for i in range(len(nodes)):
        getr(i)
    for nm in ("Hips", "Thigh.L", "Shin.L", "Foot.L", "UpperArm.L", "Forearm.L", "Hand.L"):
        m = world[index[nm]]
        axes = [(m[r][0], m[r][1], m[r][2]) for r in range(3)]
        print(f"{nm:10} pos=({m[0][3]:+.3f},{m[1][3]:+.3f},{m[2][3]:+.3f}) "
              f"localX=({axes[0][0]:+.2f},{axes[0][1]:+.2f},{axes[0][2]:+.2f}) "
              f"localY=({axes[1][0]:+.2f},{axes[1][1]:+.2f},{axes[1][2]:+.2f}) "
              f"localZ=({axes[2][0]:+.2f},{axes[2][1]:+.2f},{axes[2][2]:+.2f})")


if __name__ == "__main__":
    main(sys.argv[1])

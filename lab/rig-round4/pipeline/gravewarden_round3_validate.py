# Gravewarden round 3: check the capped GLB against the contact-batch baseline without Blender.
#   python3 -I gravewarden_round3_validate.py
# Animation and skin are byte-equal; every baseline triangle survives; the extra triangles are caps
# on the dark texel block; each rigid piece is closed, one bone and outward; caps sit inside the
# baseline surface at rest; the outer shading is unchanged.
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

lane = Path(__file__).resolve().parent.parent
folder = lane / "mobs" / "gravewarden"
BASE = folder / "rig-contact-batch" / "gravewarden.glb"
CAP = folder / "rig-round3-capped" / "gravewarden.glb"
BASELINE_SHA = "eb652071cdf02ddb622fce945f86f9975e112a1cfb6b8662c7c1619284182a70"
CT = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def load(path):
    b = path.read_bytes()
    off, js, bn = 12, None, None
    while off < len(b):
        n, kind = struct.unpack_from("<II", b, off)
        chunk = b[off + 8:off + 8 + n]
        off += 8 + n
        if kind == 0x4E4F534A:
            js = json.loads(chunk)
        elif kind == 0x004E4942:
            bn = chunk
    return js, bn, hashlib.sha256(b).hexdigest()


def acc(g, i):
    js, bn = g[0], g[1]
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    dt, n = np.dtype(CT[a["componentType"]]), NC[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", 0) or dt.itemsize * n
    return np.ndarray((a["count"], n), dt, buffer=bn, offset=start, strides=(stride, dt.itemsize)).copy()


def mesh(g):
    prims = g[0]["meshes"][0]["primitives"]
    assert len(g[0]["meshes"]) == 1 and len(prims) == 1, "Expected one mesh primitive"
    at = prims[0]["attributes"]
    W = acc(g, at["WEIGHTS_0"])
    J = acc(g, at["JOINTS_0"])
    return {"P": acc(g, at["POSITION"]).astype(float), "N": acc(g, at["NORMAL"]).astype(float),
            "UV": acc(g, at["TEXCOORD_0"]).astype(float), "J": J[np.arange(len(J)), W.argmax(1)],
            "Wmax": W.max(1), "F": acc(g, prims[0]["indices"]).reshape(-1, 3).astype(int)}


def keys(m):
    """A corner key that survives re-export: position, UV and bone."""
    return [tuple(np.round(m["P"][i], 6)) + tuple(np.round(m["UV"][i], 6)) + (int(m["J"][i]),)
            for i in range(len(m["P"]))]


def canon(tri):
    """The triangle's corners from its smallest key, and that start corner."""
    k = min(range(3), key=lambda i: tri[i])
    return tri[k:] + tri[:k], k


def pieces(P, J, F):
    key = np.c_[np.round(P, 6), J]
    _, w = np.unique(key, axis=0, return_inverse=True)
    w = w.ravel()
    T = w[F]
    parent = np.arange(w.max() + 1)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for a, b, c in T:
        ra = find(a)
        parent[find(b)] = ra
        parent[find(c)] = ra
    comp = np.array([find(t[0]) for t in T])
    co = np.zeros((w.max() + 1, 3))
    co[w] = P
    rows = []
    for root in np.unique(comp):
        t = T[comp == root]
        e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
        u, inv, count = np.unique(np.sort(e, 1), axis=0, return_inverse=True, return_counts=True)
        fwd = np.zeros(len(u), int)
        np.add.at(fwd, inv.ravel(), (e[:, 0] < e[:, 1]).astype(int))
        bones = sorted(set(J[F[comp == root].ravel()].tolist()))
        rows.append({"joints": bones, "faces": int(len(t)), "boundary": int((count == 1).sum()),
                     "nonmanifold": int((count > 2).sum()), "winding_flips": int(((count == 2) & (fwd != 1)).sum()),
                     "volume_m3": round(float(np.einsum("ij,ij->i", co[t[:, 0]], np.cross(co[t[:, 1]], co[t[:, 2]])).sum() / 6), 6)})
    return rows


def inside(points, V0, V1, V2):
    """Ray parity against triangles (Moller-Trumbore), majority of three directions."""
    e1, e2 = V1 - V0, V2 - V0
    votes = np.zeros(len(points), int)
    for d in np.array([[.577, .5774, .5771], [-.6, .53, .61], [.41, -.82, .397]]):
        d = d / np.linalg.norm(d)
        h = np.cross(d, e2)
        det = np.einsum("ij,ij->i", e1, h)
        ok = np.abs(det) > 1e-14
        inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
        for k, p in enumerate(points):
            s = p - V0
            u = np.einsum("ij,ij->i", s, h) * inv
            q = np.cross(s, e1)
            v = (q @ d) * inv
            t = np.einsum("ij,ij->i", e2, q) * inv
            votes[k] += int((ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-7)).sum()) % 2
    return votes >= 2


def animation(g):
    js = g[0]
    names = [n.get("name") for n in js["nodes"]]
    out = {}
    for a in js["animations"]:
        for ch in a["channels"]:
            s = a["samplers"][ch["sampler"]]
            out[(a["name"], names[ch["target"]["node"]], ch["target"]["path"])] = (
                s.get("interpolation", "LINEAR"), acc(g, s["input"]).tobytes(), acc(g, s["output"]).tobytes())
    return out


def main():
    base, cap = load(BASE), load(CAP)
    assert base[2] == BASELINE_SHA, "Baseline changed"
    spec = json.loads((lane / "pipeline" / "gravewarden_round3_cap.json").read_text())
    assert spec["glb_sha256"] == cap[2], "Trial GLB differs from its build report"
    mb, mc = mesh(base), mesh(cap)
    report = {"baseline_glb": str(BASE), "baseline_sha256": base[2], "capped_glb": str(CAP), "capped_sha256": cap[2]}
    ab, ac = animation(base), animation(cap)
    report["animation_channels"] = len(ac)
    report["animation_identical"] = ab == ac
    sb, sc = base[0]["skins"][0], cap[0]["skins"][0]
    jb = [base[0]["nodes"][j]["name"] for j in sb["joints"]]
    jc = [cap[0]["nodes"][j]["name"] for j in sc["joints"]]
    report["skin_identical"] = jb == jc and acc(base, sb["inverseBindMatrices"]).tobytes() == acc(cap, sc["inverseBindMatrices"]).tobytes()
    report["clips"] = sorted(a["name"] for a in cap[0]["animations"])
    report["materials"] = len(cap[0].get("materials", []))
    kb, kc = keys(mb), keys(mc)
    nb = {}  # baseline triangle -> its corner normals, so shading is compared corner by corner
    for f in mb["F"]:
        t, k = canon(tuple(kb[i] for i in f))
        nb[t] = mb["N"][np.roll(f, -k)]
    tb = set(nb)
    tc, dots = [], []
    for f in mc["F"]:
        t, k = canon(tuple(kc[i] for i in f))
        tc.append(t)
        if t in nb:
            dots.extend(np.einsum("ij,ij->i", nb[t], mc["N"][np.roll(f, -k)]))
    extra = np.array([t not in tb for t in tc])
    report["baseline_triangles"] = len(mb["F"])
    report["baseline_triangles_kept"] = len(tb & set(tc))
    report["cap_triangles"] = int(extra.sum())
    u0, v0, du, dv = (spec["cap_texels"]["block_px"][0] / 1024, spec["cap_texels"]["block_px"][1] / 1024,
                      spec["cap_texels"]["block_px"][2] / 1024, spec["cap_texels"]["block_px"][2] / 1024)
    uv = mc["UV"][mc["F"][extra].ravel()]
    uv = np.c_[uv[:, 0], 1 - uv[:, 1]]  # glTF v runs top to bottom; Blender and the block run bottom to top
    report["cap_uvs_in_dark_block"] = bool(((uv[:, 0] >= u0) & (uv[:, 0] <= u0 + du) & (uv[:, 1] >= v0) & (uv[:, 1] <= v0 + dv)).all())
    report["rigid_single_joint"] = bool((mc["Wmax"] > .999).all() and (mc["J"][mc["F"]].min(1) == mc["J"][mc["F"]].max(1)).all())
    rows = pieces(mc["P"], mc["J"], mc["F"])
    report["pieces"] = rows
    report["closed_pieces"] = sum(r["boundary"] == r["nonmanifold"] == r["winding_flips"] == 0
                                  and r["volume_m3"] > 0 and len(r["joints"]) == 1 for r in rows)
    report["outer_normal_min_dot"] = round(float(min(dots)), 6)
    report["outer_corners_compared"] = len(dots)
    Fb = mb["F"]
    cent = mc["P"][mc["F"][extra]].mean(1)
    ins = inside(cent, mb["P"][Fb[:, 0]], mb["P"][Fb[:, 1]], mb["P"][Fb[:, 2]])
    report["cap_centroids_inside_baseline"] = f"{int(ins.sum())}/{len(ins)}"
    passed = (report["animation_identical"] and report["skin_identical"] and report["materials"] == 1
              and report["baseline_triangles_kept"] == report["baseline_triangles"]
              and report["cap_triangles"] == spec["cap_triangles"] and report["cap_uvs_in_dark_block"]
              and report["rigid_single_joint"] and report["closed_pieces"] == len(rows)
              and report["outer_normal_min_dot"] > .999 and bool(ins.all()))
    report["result"] = "passed" if passed else "failed"
    out = lane / "pipeline" / "gravewarden_round3_validate.json"
    out.write_text(json.dumps(report, indent=2) + "\n")
    print("VALIDATE", json.dumps({k: v for k, v in report.items() if k != "pieces"}))
    assert passed, "Validation failed"


main()

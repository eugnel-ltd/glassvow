# Gravewarden round 4: which fist and leg faces are hidden inside the other shell at rest, their
# texture colour, and how much of them each clip exposes. Also lists open loops per piece.
#   python3 -I round4_hidden.py
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from read_glb import load  # noqa: E402
import round4_segments as seg  # noqa: E402
import gravewarden_round4_motion as mo  # noqa: E402


def fitted_with_uv(path, height):
    doc, acc = load(path)
    node = next(n for n in doc["nodes"] if "mesh" in n)
    assert not any(k in node for k in ("matrix", "rotation", "scale", "translation")) or True
    prim = doc["meshes"][node["mesh"]]["primitives"][0]
    p = acc(prim["attributes"]["POSITION"]).astype(float)[:, [0, 2, 1]] * [1, -1, 1]
    uv = acc(prim["attributes"]["TEXCOORD_0"]).astype(float)
    f = acc(prim["indices"]).reshape(-1, 3).astype(int)
    lo, hi = p.min(0), p.max(0)
    p = (p - [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]]) * height / (hi[2] - lo[2])
    key, inv = np.unique(np.round(p, 6), axis=0, return_inverse=True)
    img_index = doc["materials"][prim["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    image = doc["images"][doc["textures"][img_index]["source"]]
    view = doc["bufferViews"][image["bufferView"]]
    raw = path.read_bytes()
    # The binary chunk starts after the JSON chunk.
    jlen = int.from_bytes(raw[12:16], "little")
    bin0 = 20 + jlen + 8
    tex = np.asarray(Image.open(io.BytesIO(raw[bin0 + view.get("byteOffset", 0): bin0 + view.get("byteOffset", 0) + view["byteLength"]])).convert("RGB"), float) / 255
    return key, inv.ravel()[f], uv[f], tex


def inside(points, tri, dirs=((.05, .03, -1), (-.04, .06, -1), (.07, -.05, -1))):
    """Ray parity against triangles `tri` (n,3,3); majority of three near-downward rays."""
    v0, v1, v2 = tri[:, 0], tri[:, 1], tri[:, 2]
    e1, e2 = v1 - v0, v2 - v0
    votes = np.zeros(len(points), int)
    for d in dirs:
        d = np.asarray(d, float) / np.linalg.norm(d)
        h = np.cross(d, e2)
        det = np.einsum("ij,ij->i", e1, h)
        ok = np.abs(det) > 1e-12
        inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
        for k, p in enumerate(points):
            s = p - v0
            u = np.einsum("ij,ij->i", s, h) * inv
            q = np.cross(s, e1)
            v = (q @ d) * inv
            t = np.einsum("ij,ij->i", e2, q) * inv
            votes[k] += int((ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-7)).sum()) % 2
    return votes >= 2


def area(tri):
    return .5 * np.linalg.norm(np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1)


def colour(uv, tex):
    h, w, _ = tex.shape
    c = uv.mean(1)
    x = np.clip((c[:, 0] % 1) * w, 0, w - 1).astype(int)
    y = np.clip((c[:, 1] % 1) * h, 0, h - 1).astype(int)  # glTF v runs top to bottom
    return tex[y, x]


def loops(tris, lab):
    """Open loops per piece after the split: edges whose two faces differ in label, plus open edges."""
    fa, fb, ek = seg.edges_of(tris)
    e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
    key, count = np.unique(np.sort(e, 1), axis=0, return_counts=True)
    open_edges = key[count == 1]
    out = {}
    for k, name in enumerate(seg.PIECES):
        on = lab == k
        edges = [tuple(x) for x in ek[(on[fa] ^ on[fb])]] + [tuple(x) for x in open_edges]
        # keep open edges only when they belong to this piece
        mine = set(np.unique(tris[on]))
        edges = [e2 for e2 in edges if e2[0] in mine and e2[1] in mine]
        adj = {}
        for a, b in edges:
            adj.setdefault(a, []).append(b)
            adj.setdefault(b, []).append(a)
        seen, rows = set(), []
        for v in adj:
            if v in seen:
                continue
            comp, todo = [], [v]
            seen.add(v)
            while todo:
                u = todo.pop()
                comp.append(u)
                for w in adj[u]:
                    if w not in seen:
                        seen.add(w)
                        todo.append(w)
            rows.append(comp)
        out[name] = rows
    return out, int(len(open_edges))


def main():
    co, tris, uv, tex = fitted_with_uv(HERE / "src" / "gravewarden.glb", 2.4)
    m, lab = seg.main(str(HERE / "gravewarden-fit.npz"))
    d = np.load(HERE / "gravewarden-fit.npz")
    assert np.allclose(d["p"], co) and (d["f"] == tris).all(), "Fit differs from the segmentation input"
    tri = co[tris]
    body = mo.Body(co, tris, lab, m)
    clips = mo.clips(body)
    report = {"texture_size": list(tex.shape[:2])}
    # Hidden regions at rest: fist faces inside the leg shells, leg faces inside the fist shell.
    for side in ("Left", "Right"):
        fist = lab == seg.PIECES.index(side + "LowerArm")
        leg = np.isin(lab, [seg.PIECES.index(side + n) for n in ("UpperLeg", "LowerLeg", "Foot")])
        c = tri.mean(1)
        hid_fist = np.zeros(len(tris), bool)
        hid_fist[np.nonzero(fist)[0]] = inside(c[fist], tri[leg])
        hid_leg = np.zeros(len(tris), bool)
        hid_leg[np.nonzero(leg)[0]] = inside(c[leg], tri[fist])
        rgb_all = colour(uv, tex)
        row = {}
        for name, hid, own in (("fist_inside_leg", hid_fist, fist), ("leg_inside_fist", hid_leg, leg)):
            a = area(tri[hid])
            row[name] = {"faces": int(hid.sum()), "area_m2": round(float(a.sum()), 4),
                         "mean_rgb": np.round((rgb_all[hid] * a[:, None]).sum(0) / max(a.sum(), 1e-9), 3).tolist() if hid.any() else None,
                         "piece_mean_rgb": np.round(rgb_all[own].mean(0), 3).tolist()}
            # Exposure: hidden faces now outside the other posed shell, per clip (max over frames).
            other = leg if name == "fist_inside_leg" else fist
            exp = {}
            for clip in ("attack", "cast", "death"):
                keys = clips[clip]
                worst = (0.0, None)
                for frame in range(keys[0][0], keys[-1][0] + 1, 1):
                    pose = body.grounded(mo.sample(keys, frame))
                    dm = mo.deform(body.bones, pose)
                    pos = lambda idx, bones: np.einsum("nij,nkj->nki", np.array([dm[b][:3, :3] for b in bones]), tri[idx]) + np.array([dm[b][:3, 3] for b in bones])[:, None]
                    hb = np.array(seg.PIECES)[lab[hid]]
                    ob = np.array(seg.PIECES)[lab[other]]
                    if not hid.any():
                        break
                    ph = pos(hid, hb)
                    po = pos(other, ob)
                    still = inside(ph.mean(1), po)
                    shown = float(area(ph[~still]).sum())
                    if shown > worst[0]:
                        worst = (shown, frame)
                exp[clip] = {"max_exposed_m2": round(worst[0], 4), "frame": worst[1]}
            row[name]["exposure"] = exp
        report[side] = row
    lp, n_open = loops(tris, lab)
    report["source_open_edges"] = n_open
    rows = {}
    for name, comps in lp.items():
        rows[name] = []
        for comp in comps:
            p = co[comp]
            ctr = p.mean(0)
            sv = np.linalg.svd(p - ctr)[1]
            rows[name].append({"verts": len(comp), "centre": np.round(ctr, 3).tolist(),
                               "plane_rms_mm": round(float(sv[-1] / np.sqrt(len(comp)) * 1000), 1)})
    report["loops_before_bisect"] = rows
    print(json.dumps(report, indent=1))
    (HERE / "round4-hidden.json").write_text(json.dumps(report, indent=1) + "\n")


if __name__ == "__main__":
    main()

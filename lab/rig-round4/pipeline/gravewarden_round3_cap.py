# Gravewarden round 3: cap every rigid piece of the contact-batch rig, so an opening seam shows
# dark stone instead of the hollow shell (the attack "shoulder hole"). Isolated trial: char_rig.py
# and rig-contact-batch stay unchanged; the motion is not reduced.
# The source mesh is closed, so after rigid_split each boundary edge is a seam rim or a same-bone
# crack the glTF importer left unwelded. Cracks are welded within their bone. Each seam rim is then
# fanned to one apex vertex that carries the piece's bone at 1.0 (inherited weights). The apex moves
# into the body until every cap triangle tests inside the source surface, so caps stay hidden at rest.
# A flat lid (holes_fill) was rejected: it reused piece edges (non-manifold) and sat outside concave
# patches (Chest volume < 0).
#   blender -b --factory-startup --python-exit-code 1 --python gravewarden_round3_cap.py -- [--dry-run]
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
folder = lane / "mobs" / "gravewarden"
source = folder / "rig-contact-batch" / "gravewarden.blend"
out = folder / "rig-round3-capped"
BASELINE_SHA = "eb652071cdf02ddb622fce945f86f9975e112a1cfb6b8662c7c1619284182a70"
dry = "--dry-run" in sys.argv[sys.argv.index("--") + 1:]
RAYS = [Vector(d).normalized() for d in ((.577, .5774, .5771), (-.6, .53, .61), (.41, -.82, .397))]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def resources():
    load, free = os.getloadavg()[0], shutil.disk_usage(lane).free / 2**30
    print("CAP load", round(load, 1), "free GiB", round(free, 1), flush=True)
    assert load < 30 and free >= 100, "Resource floor reached"


def base_image(mat):
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    todo = [bsdf.inputs["Base Color"]]
    while todo:
        for link in todo.pop().links:
            if link.from_node.type == "TEX_IMAGE":
                return link.from_node.image
            todo.extend(i for i in link.from_node.inputs if i.is_linked)
    raise SystemExit("No base colour texture")


def dark_block(img):
    """A large uniform, opaque block at half the texture's median brightness: shadowed stone, not a
    black void (black read as a hole again). Large, so the first mips keep its colour."""
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)  # Blender rows run bottom to top, the same way as UV v
    for b in (64, 32, 16):
        blk = px[:h - h % b, :w - w % b].reshape(h // b, b, w // b, b, 4).transpose(0, 2, 1, 3, 4)
        blk = blk.reshape(h // b, w // b, b * b, 4)
        lum = blk[..., :3] @ np.array([.2126, .7152, .0722], np.float32)
        mean, std, alpha = lum.mean(-1), lum.std(-1), blk[..., 3].min(-1)
        target = .5 * float(np.median(mean))
        ok = (alpha > .99) & (std < .03) & (np.abs(mean - target) < .25 * target)
        if ok.any():
            break
    assert ok.any(), "No uniform dark stone block in the texture"
    by, bx = np.unravel_index(np.argmin(np.where(ok, np.abs(mean - target) + std, np.inf)), mean.shape)
    margin = b / 4  # stay inside the block so filtering keeps its colour
    box = ((bx * b + margin) / w, (by * b + margin) / h, (b - 2 * margin) / w, (b - 2 * margin) / h)
    return box, {"image": img.name, "size": [w, h], "block_px": [int(bx * b), int(by * b), b],
                 "rgb_encoded": [round(float(c), 4) for c in blk[by, bx, :, :3].mean(0)],
                 "lum_mean": round(float(mean[by, bx]), 4), "lum_std": round(float(std[by, bx]), 4),
                 "texture_lum_percentiles_5_50_95": [round(float(p), 4) for p in np.percentile(mean, [5, 50, 95])]}


def inside(bvh, p):
    """Ray parity against the closed source surface, majority of three directions."""
    votes = 0
    for d in RAYS:
        o, hits = Vector(p), 0
        while hits < 500:
            loc = bvh.ray_cast(o, d)[0]
            if loc is None:
                break
            hits += 1
            o = loc + d * 1e-5
        votes += hits % 2
    return votes >= 2


def pieces(co, tris, bone):
    """Closure per rigid piece: connected faces of one bone, no open or shared edge, one winding, outward."""
    parent = np.arange(len(co))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for a, b, c in tris:
        ra = find(a)
        parent[find(b)] = ra
        parent[find(c)] = ra
    comp = np.array([find(t[0]) for t in tris])
    rows = []
    for root in np.unique(comp):
        t = tris[comp == root]
        e = np.concatenate([t[:, [0, 1]], t[:, [1, 2]], t[:, [2, 0]]])
        uniq, inv, count = np.unique(np.sort(e, 1), axis=0, return_inverse=True, return_counts=True)
        forward = np.zeros(len(uniq), int)
        np.add.at(forward, inv.ravel(), (e[:, 0] < e[:, 1]).astype(int))
        volume = float(np.einsum("ij,ij->i", co[t[:, 0]], np.cross(co[t[:, 1]], co[t[:, 2]])).sum() / 6)
        rows.append({"bone": sorted(set(bone[t.ravel()].tolist())), "faces": int(len(t)),
                     "boundary": int((count == 1).sum()), "nonmanifold": int((count > 2).sum()),
                     "winding_flips": int(((count == 2) & (forward != 1)).sum()), "volume_m3": round(volume, 6)})
    return rows


def crossings(P, a):
    """Self-intersections of the fan: two non-adjacent rim arcs that cross on the sphere around the
    apex share a direction, so their two triangles intersect along that ray."""
    A = (P - a) / np.linalg.norm(P - a, axis=1, keepdims=True)
    B = np.roll(A, -1, 0)
    N = np.cross(A, B)
    n, hits = len(A), 0
    for i in range(n):
        for j in range(i + 2, n - (i == 0)):
            x = np.cross(N[i], N[j])
            if np.linalg.norm(x) < 1e-12:
                continue
            for s in (x, -x):
                if (np.cross(A[i], s) @ N[i] >= 0 and np.cross(s, B[i]) @ N[i] >= 0
                        and np.cross(A[j], s) @ N[j] >= 0 and np.cross(s, B[j]) @ N[j] >= 0):
                    hits += 1
    return hits


def apex_for(bvh, P, d_list, r):
    """The apex with every cap triangle inside the body: fewest self-intersections first, then the
    shallowest one with a clearance of r / 4, else the largest clearance."""
    best = None
    for k, d in enumerate(d_list):
        for t in np.linspace(0, 2, 21):
            a = P.mean(0) + d * t * r
            if not inside(bvh, a):
                continue
            if not all(inside(bvh, p) for p in (P + np.roll(P, -1, 0) + a) / 3):
                continue
            clear = (Vector(a) - bvh.find_nearest(Vector(a))[0]).length
            row = (a, clear, float(t), k, crossings(P, a))
            if best is None or (row[4], -min(clear, .25 * r)) < (best[4], -min(best[1], .25 * r)):
                best = row
            if best[4] == 0 and best[1] >= .25 * r:
                return best
    return best


def main():
    resources()
    assert sha(folder / "rig-contact-batch" / "gravewarden.glb") == BASELINE_SHA, "Baseline changed"
    assert dry or not out.exists(), "Inspect an existing trial before replacing it"
    blend_sha = sha(source)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    fps = bpy.context.scene.render.fps  # ground_candidate.py stores the contact bake at 120; keep it
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm)
    me = body.data
    assert len(me.materials) == 1 and me.uv_layers.active
    box, swatch = dark_block(base_image(me.materials[0]))
    report = {"source_blend": str(source), "source_blend_sha256": blend_sha, "baseline_glb_sha256": BASELINE_SHA,
              "fps": fps, "vertices_before": len(me.vertices), "faces_before": len(me.polygons),
              "custom_normals_before": me.has_custom_normals, "material": me.materials[0].name,
              "actions": sorted(a.name for a in bpy.data.actions), "cap_texels": swatch}
    l0, f0 = len(me.loops), len(me.polygons)
    lv = np.empty(l0, int)
    me.loops.foreach_get("vertex_index", lv)
    vco = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", vco)
    vco = vco.reshape(-1, 3)
    corner_co = vco[lv]
    corner_uv = np.empty(l0 * 2)
    me.uv_layers.active.data.foreach_get("uv", corner_uv)
    corner_n = np.empty(l0 * 3)
    me.corner_normals.foreach_get("vector", corner_n)
    corner_n = corner_n.reshape(-1, 3)
    bvh = BVHTree.FromPolygons([Vector(v) for v in vco], [tuple(p.vertices) for p in me.polygons])

    bm = bmesh.new()
    bm.from_mesh(me)
    tag = bm.faces.layers.int.new("round3_cap")  # before any element refs: a new layer invalidates them
    dl, uvl = bm.verts.layers.deform.active, bm.loops.layers.uv.active
    assert all(len(v[dl]) == 1 and abs(next(iter(v[dl].values())) - 1) < 1e-6 for v in bm.verts), "Rigid weights expected"
    groups = {}
    for v in bm.verts:
        groups.setdefault(next(iter(v[dl].keys())), []).append(v)
    rim_before = sum(e.is_boundary for e in bm.edges)
    n0 = len(bm.verts)
    for vs in groups.values():  # weld same-bone cracks only; the rigid seams between bones stay cut
        bmesh.ops.remove_doubles(bm, verts=vs, dist=1e-6)
    report["crack_vertices_welded"] = n0 - len(bm.verts)
    bm.normal_update()
    bone = {v: next(iter(v[dl].keys())) for v in bm.verts}
    rim = [e for e in bm.edges if e.is_boundary]
    keys = {}
    for e in rim:
        k = tuple(sorted(tuple(round(c, 6) for c in v.co) for v in e.verts))
        keys.setdefault(k, set()).add(bone[e.verts[0]])
    assert all(bone[e.verts[0]] == bone[e.verts[1]] for e in rim), "A rim edge crosses two bones"
    seam_only = all(len(b) >= 2 for b in keys.values())
    report.update(rim_edges_before_weld=rim_before, rim_edges=len(rim), rim_all_seams=seam_only)
    assert seam_only, "A boundary edge has no twin in another bone"
    nxt = {}
    for e in rim:
        loop = e.link_loops[0]
        a, b = loop.vert, loop.link_loop_next.vert  # the piece face runs a -> b; its cap runs b -> a
        assert b not in nxt, "Pinched rim vertex"
        nxt[b] = (a, loop.face)
    rings, seen = [], set()
    for s in list(nxt):
        if s in seen:
            continue
        ring, v = [], s
        while v not in seen:
            seen.add(v)
            ring.append((v, nxt[v][1]))
            v = nxt[v][0]
        assert v is s, "Rim walk did not close"
        rings.append(ring)
    u0, v0, du, dv = box
    details, failed, cap_normal = [], [], [None]
    for i, ring in enumerate(rings):
        verts = [v for v, _ in ring]
        P = np.array([v.co[:] for v in verts])
        r = float(np.linalg.norm(P - P.mean(0), axis=1).mean())
        newell = np.cross(P, np.roll(P, -1, 0)).sum(0) / 2  # area vector in cap orientation
        nn = newell / max(np.linalg.norm(newell), 1e-12)
        side = sum((np.array(f.normal) * f.calc_area() for _, f in ring), np.zeros(3))
        area = sum(f.calc_area() for _, f in ring)
        inward = np.linalg.norm(side) > .2 * area  # patch-like rim: go under the skin; tube cut: into the piece
        d_list = ([-side / np.linalg.norm(side)] if inward else []) + [-nn]
        labels = (["under skin"] if inward else []) + ["into piece"]
        best = apex_for(bvh, P, d_list, r)
        row = {"ring": i + 1, "bone": body.vertex_groups[bone[verts[0]]].name, "edges": len(ring),
               "perimeter_m": round(float(np.linalg.norm(P - np.roll(P, -1, 0), axis=1).sum()), 3),
               "radius_m": round(r, 3)}
        if best is None:
            failed.append(row)
            details.append({**row, "result": "no inside apex"})
            continue
        a, clear, t, k, cross = best
        apex = bm.verts.new(a)
        apex[dl][bone[verts[0]]] = 1.0
        pts = np.vstack([P, a])
        c = pts - pts.mean(0)
        axes = np.linalg.svd(c, full_matrices=False)[2][:2]  # project on the cap's best-fit plane
        uv = c @ axes.T
        uv = (uv - uv.min(0)) / max(float(np.ptp(uv, 0).max()), 1e-9)
        uv = np.c_[u0 + uv[:, 0] * du, v0 + uv[:, 1] * dv]
        folded = 0
        for j in range(len(verts)):
            q = (j + 1) % len(verts)
            f = bm.faces.new((verts[j], verts[q], apex))
            f.smooth, f.material_index, f[tag] = False, 0, i + 1
            for loop, idx in zip(f.loops, (j, q, len(verts))):
                loop[uvl].uv = uv[idx]
            f.normal_update()
            folded += float(np.dot(f.normal, nn)) < 0
        cap_normal.append(nn)
        details.append({**row, "apex_depth_r": t, "direction": labels[k],
                        "clearance_m": round(clear, 3), "folded_triangles": folded, "self_crossings": cross})
    bm.faces.layers.int.remove(tag)  # keep the saved mesh free of trial attributes
    bm.to_mesh(me)
    bm.free()
    me.update()
    report.update(caps=len(rings), caps_failed=len(failed), cap_details=details,
                  cap_triangles=len(me.polygons) - f0,
                  cap_folded_triangles=sum(d.get("folded_triangles", 0) for d in details),
                  cap_self_crossings=sum(d.get("self_crossings", 0) for d in details))

    lv2 = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", lv2)
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    uv2 = np.empty(len(me.loops) * 2)
    me.uv_layers.active.data.foreach_get("uv", uv2)
    report["source_corner_position_max_delta"] = float(np.abs(co[lv2[:l0]] - corner_co).max())
    report["source_corner_uv_max_delta"] = float(np.abs(uv2[:l0 * 2] - corner_uv).max())
    assert report["source_corner_position_max_delta"] == 0 and report["source_corner_uv_max_delta"] == 0, "Source faces changed"
    normals = np.empty((len(me.loops), 3))
    normals[:l0] = corner_n  # the outer surface keeps its shading; caps are flat
    for p in me.polygons[f0:]:
        normals[p.loop_start:p.loop_start + p.loop_total] = p.normal
    me.normals_split_custom_set(normals.tolist())
    check = np.empty(len(me.loops) * 3)
    me.corner_normals.foreach_get("vector", check)
    report["source_corner_normal_max_delta"] = float(np.abs(check.reshape(-1, 3)[:l0] - corner_n).max())

    me.calc_loop_triangles()
    tri = np.empty(len(me.loop_triangles) * 3, int)
    me.loop_triangles.foreach_get("vertices", tri)
    tri = tri.reshape(-1, 3)
    names = {g.index: g.name for g in body.vertex_groups}
    vbone = np.array([names[v.groups[0].group] for v in me.vertices])
    assert all(len(v.groups) == 1 and abs(v.groups[0].weight - 1) < 1e-6 for v in me.vertices)
    rows = pieces(co, tri, vbone)
    report["pieces"] = rows
    report["closed_pieces"] = sum(r["boundary"] == r["nonmanifold"] == r["winding_flips"] == 0
                                  and r["volume_m3"] > 0 and len(r["bone"]) == 1 for r in rows)
    report.update(vertices_after=len(me.vertices), faces_after=len(me.polygons), triangles_after=len(tri))
    print("CAP REPORT", json.dumps({k: v for k, v in report.items() if k not in ("pieces", "cap_details")}), flush=True)
    for d in details:
        print("RING", json.dumps(d), flush=True)
    for r in rows:
        print("PIECE", json.dumps(r), flush=True)
    assert not failed, "A rim has no apex inside the body"
    assert report["closed_pieces"] == len(rows), "A rigid piece is not closed"
    if dry:
        print("DRY RUN: nothing saved", flush=True)
        return
    resources()
    assert bpy.context.scene.render.fps == fps
    out.mkdir()
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "gravewarden.blend"))
    bpy.ops.export_scene.gltf(filepath=str(out / "gravewarden.glb"), export_format="GLB",
                              export_animations=True, export_animation_mode="ACTIONS")
    assert sha(folder / "rig-contact-batch" / "gravewarden.glb") == BASELINE_SHA and sha(source) == blend_sha
    report["glb_sha256"] = sha(out / "gravewarden.glb")
    (pipeline / "gravewarden_round3_cap.json").write_text(json.dumps(report, indent=2) + "\n")
    print("CAP DONE", out, report["glb_sha256"], flush=True)


main()

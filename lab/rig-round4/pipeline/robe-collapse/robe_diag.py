# Blender, read-only: measure a robed candidate's rig, weights, support and death clip.
#   blender -b candidate.blend --python-exit-code 1 --python robe_diag.py -- out.json
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

out = Path(sys.argv[sys.argv.index("--") + 1])
scene = bpy.context.scene
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm)
mw = np.array(body.matrix_world)
co = np.array([v.co[:] for v in body.data.vertices]) @ mw[:3, :3].T + mw[:3, 3]
names = {g.index: g.name for g in body.vertex_groups}
bones = [b.name for b in arm.data.bones if b.use_deform]
col = {n: i for i, n in enumerate(bones)}
W = np.zeros((len(co), len(bones)))
for v in body.data.vertices:
    for g in v.groups:
        if names[g.group] in col:
            W[v.index, col[names[g.group]]] = g.weight
top = W.argmax(1)
H = float(co[:, 2].max())
area = np.zeros(len(co))
for p in body.data.polygons:
    for i in p.vertices:
        area[i] += p.area / len(p.vertices)
com = (co * area[:, None]).sum(0) / area.sum()
ground = co[:, 2] < 0.03
hips = arm.data.bones["Hips"]
report = {
    "fps": scene.render.fps, "verts": len(co), "height": H, "bounds": [co.min(0).tolist(), co.max(0).tolist()],
    "area_centroid": com.tolist(),
    "bones": {b.name: {"head": list(arm.matrix_world @ b.head_local), "tail": list(arm.matrix_world @ b.tail_local),
                       "parent": b.parent.name if b.parent else None, "deform": b.use_deform} for b in arm.data.bones},
    "dominant_counts": {bones[k]: int((top == k).sum()) for k in np.unique(top)},
    "ground_footprint": {"verts": int(ground.sum()), "x": [float(co[ground, 0].min()), float(co[ground, 0].max())],
                         "y": [float(co[ground, 1].min()), float(co[ground, 1].max())]},
}
# Height bands: which bones own the skin at each height (share of vertex weight).
bands = []
for z0 in np.arange(0, H, H / 20):
    m = (co[:, 2] >= z0) & (co[:, 2] < z0 + H / 20)
    if not m.any():
        continue
    share = W[m].sum(0) / max(W[m].sum(), 1e-9)
    radius = np.hypot(co[m, 0], co[m, 1] - com[1])
    bands.append({"z": round(float(z0), 3), "n": int(m.sum()), "r_max": round(float(radius.max()), 3),
                  "owners": {bones[k]: round(float(share[k]), 2) for k in np.argsort(-share)[:5] if share[k] > .03}})
report["bands"] = bands
# Death clip: Hips channels as keyed (after the ground bake), sampled per output frame.
act = bpy.data.actions["death"]
arm.animation_data.action = act
f0, f1 = (int(round(v)) for v in act.frame_range)
step = max(1, (f1 - f0) // 40)
death = []
pb = arm.pose.bones["Hips"]
for f in range(f0, f1 + 1, step):
    scene.frame_set(f)
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    m = ev.to_mesh()
    p = np.array([v.co[:] for v in m.vertices]) @ mw[:3, :3].T + mw[:3, 3]
    ev.to_mesh_clear()
    floor = p[:, 2] < p[:, 2].min() + .01
    owners = {}
    for k in top[floor]:
        owners[bones[k]] = owners.get(bones[k], 0) + 1
    head = arm.matrix_world @ pb.head
    death.append({"frame": f, "hips_loc_local": [round(x, 4) for x in pb.location],
                  "hips_head_world": [round(x, 3) for x in head], "min_z": round(float(p[:, 2].min()), 4),
                  "top_z": round(float(p[:, 2].max()), 3), "floor_owners": owners})
report["death"] = death
keyed = sorted({c.data_path.split('"')[1] for layer in act.layers for s in layer.strips for bag in s.channelbags
                for c in bag.fcurves if '"' in c.data_path and any(abs(k.co.y - c.keyframe_points[0].co.y) > 1e-5 for k in c.keyframe_points)})
report["death_moving_bones"] = keyed
out.write_text(json.dumps(report, indent=1))
print("ROBE DIAG", out, flush=True)

# Blender, read-only: sample a candidate's death clip for the pelvis-height curve, contact, hem and stretch.
#   blender -b candidate.blend --python-exit-code 1 --python robe_bake_probe.py -- out.json [step]
# step: sample every n-th scene frame (default: one sample per 30 FPS frame).
import json
import sys
from pathlib import Path

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
out = Path(args[0])
scene = bpy.context.scene
factor = scene.render.fps // 30
step = int(args[1]) if len(args) > 1 else factor
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm)
props = [o for o in bpy.data.objects if o.type == "MESH" and o is not body and o.parent == arm and o.parent_type == "BONE"]
mw = np.array(body.matrix_world)


def verts(obj):
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = ev.to_mesh()
    co = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    m = np.array(ev.matrix_world)
    return co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]


arm.data.pose_position = "REST"
rest = verts(body)
arm.data.pose_position = "POSE"
edges = np.array([e.vertices[:] for e in body.data.edges])
rest_len = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
groups = {g.index: g.name for g in body.vertex_groups}
W = {}
for v in body.data.vertices:
    for g in v.groups:
        W.setdefault(groups[g.group], np.zeros(len(rest)))[v.index] = g.weight


def share(*keys):
    return sum((w for n, w in W.items() if any(k in n for k in keys)), np.zeros(len(rest)))


regions = {"skirt": share("Skirt"), "hands": share("Hand", "LowerArm"), "head": share("Head", "Neck"),
           "torso": share("Spine", "Chest"), "shoulders": share("Shoulder", "UpperArm"), "feet": share("Foot", "Toes")}
regions = {k: v > .5 for k, v in regions.items()}
hem = (rest[:, 2] < .06) & (regions["skirt"] if regions["skirt"].any() else (share("Leg", "Hips") > .5))
death = bpy.data.actions["death"]
arm.animation_data.action = death
first, last = (int(x) for x in death.frame_range)
rows, prev = [], None
for f in range(first, last + 1, step):
    scene.frame_set(f)
    v = verts(body)
    hips = arm.matrix_world @ arm.pose.bones["Hips"].head
    L = np.linalg.norm(v[edges[:, 0]] - v[edges[:, 1]], axis=1)
    low = v[:, 2].min()
    pz = min(float(verts(p)[:, 2].min()) for p in props) if props else None
    rows.append({"frame": f / factor, "hips": [round(x, 4) for x in hips], "hips_loc": [round(x, 4) for x in arm.pose.bones["Hips"].location],
                 "min_z": round(float(low), 4), "prop_min_z": round(pz, 4) if pz is not None else None,
                 "hem_z_p10_p90": [round(float(np.percentile(v[hem, 2], q)), 4) for q in (10, 90)],
                 "hem_r_p90": round(float(np.percentile(np.hypot(v[hem, 0] - hips[0], v[hem, 1] - hips[1]), 90)), 4),
                 "severe": int(((rest_len > 1e-6) & (L > 3 * rest_len) & (L > .03)).sum()),
                 "hem_step": round(float(np.linalg.norm(v[hem] - prev[hem], axis=1).max()), 4) if prev is not None else 0.0,
                 "contact": {k: int((v[m, 2] < low + .01).sum()) for k, m in regions.items() if (v[m, 2] < low + .01).any()}})
    prev = v
out.write_text(json.dumps({"file": bpy.data.filepath, "fps": scene.render.fps, "step": step, "rows": rows}, indent=1) + "\n")
print("ROBE BAKE PROBE", out, len(rows), "samples", flush=True)

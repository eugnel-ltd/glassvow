# Blender, read-only: export a candidate's rest skeleton, skin and props for offline motion work.
#   blender -b candidate.blend --python-exit-code 1 --python robe_export.py -- out.npz
import sys

import bpy
import numpy as np

out = sys.argv[sys.argv.index("--") + 1]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm)
assert np.allclose(np.array(arm.matrix_world), np.eye(4), atol=1e-6), "Armature must sit at the origin"
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
bones = list(arm.data.bones)
names = [b.name for b in bones]
mw = np.array(body.matrix_world)
co = np.array([v.co[:] for v in body.data.vertices]) @ mw[:3, :3].T + mw[:3, 3]
body.data.calc_loop_triangles()
tris = np.array([t.vertices[:] for t in body.data.loop_triangles], dtype=np.int32)
gname = {g.index: g.name for g in body.vertex_groups}
W = np.zeros((len(co), len(names)), dtype=np.float32)
for v in body.data.vertices:
    for g in v.groups:
        if gname[g.group] in names:
            W[v.index, names.index(gname[g.group])] = g.weight
props, prop_bones, prop_verts, prop_tris = [], [], [], []
for o in bpy.data.objects:
    if o.type == "MESH" and o is not body and o.parent == arm and o.parent_type == "BONE":
        m = np.array(o.matrix_world)
        props.append(o.name)
        prop_bones.append(o.parent_bone)
        prop_verts.append(np.array([v.co[:] for v in o.data.vertices]) @ m[:3, :3].T + m[:3, 3])
        o.data.calc_loop_triangles()
        prop_tris.append(np.array([t.vertices[:] for t in o.data.loop_triangles], dtype=np.int32))
np.savez_compressed(
    out, names=np.array(names), parents=np.array([b.parent.name if b.parent else "" for b in bones]),
    rest=np.array([np.array(b.matrix_local) for b in bones]), lengths=np.array([b.length for b in bones]),
    connect=np.array([b.use_connect for b in bones]), deform=np.array([b.use_deform for b in bones]),
    verts=co, tris=tris, weights=W, props=np.array(props), prop_bones=np.array(prop_bones),
    **{f"prop_verts_{i}": v for i, v in enumerate(prop_verts)}, **{f"prop_tris_{i}": t for i, t in enumerate(prop_tris)},
    fps=bpy.context.scene.render.fps, actions=np.array([a.name for a in bpy.data.actions]),
    ranges=np.array([a.frame_range[:] for a in bpy.data.actions]))
print("ROBE EXPORT", out, len(co), "verts", len(tris), "tris", len(names), "bones", props, flush=True)

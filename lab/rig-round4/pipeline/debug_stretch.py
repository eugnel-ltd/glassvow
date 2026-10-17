# Find edges that stretch under a clip: which vertices, which bone weights.
#   blender -b <file.blend> --python debug_stretch.py -- <action> <frame>
import bpy, sys
from collections import Counter

args = sys.argv[sys.argv.index("--") + 1:]
act_name, frame = args[0], float(args[1])
if len(args) == 3:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args[2], merge_vertices=True)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm and not o.name.endswith("_prop"))
arm.animation_data_create()
arm.animation_data.action = bpy.data.actions[act_name]
bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
dg = bpy.context.evaluated_depsgraph_get()
ev = body.evaluated_get(dg).to_mesh()
rest, pose = body.data.vertices, ev.vertices
bad = []
for e in body.data.edges:
    a, b = e.vertices
    r = (rest[a].co - rest[b].co).length
    p = (pose[a].co - pose[b].co).length
    if r > 1e-6 and p / r > 3 and p > .03:
        bad.append((p / r, a, b))
bad.sort(reverse=True)
print("DBG stretched edges", len(bad))
names = {g.index: g.name for g in body.vertex_groups}
seen = Counter()
for ratio, a, b in bad[:12]:
    for v in (a, b):
        top = sorted(((g.weight, names[g.group]) for g in rest[v].groups), reverse=True)
        world = body.matrix_world @ rest[v].co
        print(f"DBG x{ratio:.1f} v{v} world rest {tuple(round(c, 3) for c in world)} {[(n, round(w, 3)) for w, n in top]}")
for _, a, b in bad:
    for v in (a, b):
        top = max(((g.weight, names[g.group]) for g in rest[v].groups), default=(0, "NONE"))
        seen[top[1]] += 1
print("DBG top bones of stretched verts", seen.most_common(8))

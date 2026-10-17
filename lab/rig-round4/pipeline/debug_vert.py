# Distances from given vertices to every deform bone, plus their weights.
#   blender -b <file.blend> --python debug_vert.py -- v1 v2 ...
import bpy, sys
ids = [int(a) for a in sys.argv[sys.argv.index("--") + 1:]]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm)
print("DBG body mw identity", body.matrix_world.is_identity if hasattr(body.matrix_world, "is_identity") else body.matrix_world, "arm", arm.matrix_world)
def dist(p, a, b):
    d = b - a
    t = max(0.0, min(1.0, (p - a).dot(d) / max(d.length_squared, 1e-12)))
    return (a + d * t - p).length
names = {g.index: g.name for g in body.vertex_groups}
for i in ids:
    v = body.data.vertices[i]
    p = body.matrix_world @ v.co
    ds = sorted((dist(p, arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local), b.name) for b in arm.data.bones if b.use_deform)
    print("DBG v", i, tuple(round(c, 3) for c in p), "w", [(names[g.group], round(g.weight, 2)) for g in v.groups])
    print("DBG   nearest", [(n, round(d, 3)) for d, n in ds[:4]])
for n in ("RightHand", "RightLowerArm", "RightUpperLeg"):
    b = arm.data.bones[n]
    print("DBG bone", n, tuple(round(c, 3) for c in b.head_local), tuple(round(c, 3) for c in b.tail_local))

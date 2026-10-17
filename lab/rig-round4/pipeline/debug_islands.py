# List the connected mesh islands of a GLB after the same import as char_rig (merged seams, fitted to H=1).
#   blender -b --factory-startup --python debug_islands.py -- body.glb
import bpy, sys
import numpy as np

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path, merge_vertices=True)
ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
me = ob.data
co = np.array([ob.matrix_world @ v.co for v in me.vertices])
lo, hi = co.min(0), co.max(0)
co = (co - [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]]) / (hi[2] - lo[2])
parent = list(range(len(co)))


def find(a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]
        a = parent[a]
    return a


for e in me.edges:
    a, b = find(e.vertices[0]), find(e.vertices[1])
    if a != b:
        parent[a] = b
roots = np.array([find(i) for i in range(len(co))])
ids, counts = np.unique(roots, return_counts=True)
print("ISL", len(ids), "islands")
for r, n in sorted(zip(ids, counts), key=lambda t: -t[1])[:12]:
    p = co[roots == r]
    print("ISL", n, "verts  min", p.min(0).round(2), "max", p.max(0).round(2))

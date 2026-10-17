# Blender: list the open boundary loops of the skinned body mesh (rest pose).
#   blender -b source.blend --python boundary_loops.py
from collections import defaultdict

import bpy

arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
mesh = body.data
count = defaultdict(int)
for poly in mesh.polygons:
    for key in poly.edge_keys:
        count[key] += 1
boundary = [key for key, n in count.items() if n == 1]
links = defaultdict(list)
for a, b in boundary:
    links[a].append(b)
    links[b].append(a)
seen, loops = set(), []
for start in links:
    if start in seen:
        continue
    stack, loop = [start], []
    while stack:
        v = stack.pop()
        if v in seen:
            continue
        seen.add(v)
        loop.append(v)
        stack.extend(links[v])
    loops.append(loop)
print('BOUNDARY', body.name, 'vertices', len(mesh.vertices), 'faces', len(mesh.polygons), 'open edges', len(boundary), 'loops', len(loops))
for loop in sorted(loops, key=len, reverse=True)[:12]:
    co = [body.matrix_world @ mesh.vertices[i].co for i in loop]
    xs, ys, zs = zip(*co)
    print('LOOP', len(loop), 'z', round(min(zs), 3), round(sum(zs) / len(zs), 3), round(max(zs), 3),
          'x', round(min(xs), 3), round(max(xs), 3), 'y', round(min(ys), 3), round(max(ys), 3))

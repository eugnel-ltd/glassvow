# Blender: list vertices that mix two bone groups above thresholds.
#   blender -b source.blend --python mixed_weights.py -- <boneA> <minA> <boneB> <minB>
import sys

import bpy

bone_a, min_a, bone_b, min_b = sys.argv[sys.argv.index('--') + 1:]
arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
ga, gb = body.vertex_groups[bone_a].index, body.vertex_groups[bone_b].index
rows = []
for vertex in body.data.vertices:
    w = {g.group: g.weight for g in vertex.groups}
    if w.get(ga, 0) > float(min_a) and w.get(gb, 0) > float(min_b):
        rows.append((vertex.index, tuple(round(v, 3) for v in body.matrix_world @ vertex.co), round(w[ga], 2), round(w[gb], 2)))
for row in sorted(rows, key=lambda r: r[1][2]):
    print('MIX', *row)
print('MIX COUNT', len(rows))

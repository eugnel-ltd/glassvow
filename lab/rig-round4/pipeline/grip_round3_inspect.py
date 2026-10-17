"""Inspect the selected hand geometry without changing a candidate or rendering."""
import json
import os
from pathlib import Path
import shutil

import bpy

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'mobs/uncrossedSelf/round3-grip-inspection.json'
assert not OUT.exists(), 'Preserve existing evidence'
resources = {'load': os.getloadavg()[0], 'free_gib': shutil.disk_usage(ROOT).free / 2**30}
if resources['load'] >= 30 or resources['free_gib'] < 100:
    OUT.write_text(json.dumps({'blocked': resources}, indent=2) + '\n')
    raise RuntimeError(resources)
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'mobs/uncrossedSelf/rig-hold-contact/uncrossedSelf.blend'))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.find_armature() == arm)
book = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent_bone == 'LeftHand')
arm.animation_data.action = bpy.data.actions['idle']
bpy.context.scene.frame_set(1)
group = body.vertex_groups['LeftHand'].index
indices = [v.index for v in body.data.vertices if any(g.group == group and g.weight > .5 for g in v.groups)]
graph = bpy.context.evaluated_depsgraph_get()
evaluated = body.evaluated_get(graph)
mesh = evaluated.to_mesh()
hand_inverse = (arm.matrix_world @ arm.pose.bones['LeftHand'].matrix).inverted()
report = {
    'resources': resources,
    'objects': [{'name': o.name, 'type': o.type, 'parent': o.parent.name if o.parent else None,
                 'parent_bone': o.parent_bone, 'modifiers': [m.type for m in o.modifiers]} for o in bpy.context.scene.objects],
    'bones': [{'name': b.name, 'head': list(b.head_local), 'tail': list(b.tail_local)} for b in arm.data.bones],
    'hand_vertices': [{'index': i, 'rest': list(body.data.vertices[i].co),
                       'world': list(evaluated.matrix_world @ mesh.vertices[i].co),
                       'hand_local': list(hand_inverse @ evaluated.matrix_world @ mesh.vertices[i].co),
                       'weights': {body.vertex_groups[g.group].name: g.weight for g in body.data.vertices[i].groups}} for i in indices],
    'hand_faces': [list(p.vertices) for p in body.data.polygons if all(i in indices for i in p.vertices)],
    'book_bounds_world': [[min((book.matrix_world @ v.co)[i] for v in book.data.vertices),
                           max((book.matrix_world @ v.co)[i] for v in book.data.vertices)] for i in range(3)],
    'book_bounds_hand': [[min((hand_inverse @ book.matrix_world @ v.co)[i] for v in book.data.vertices),
                          max((hand_inverse @ book.matrix_world @ v.co)[i] for v in book.data.vertices)] for i in range(3)],
    'book_matrix': [list(row) for row in book.matrix_world],
    'body_matrix': [list(row) for row in body.matrix_world],
    'hand_matrix': [list(row) for row in arm.matrix_world @ arm.pose.bones['LeftHand'].matrix],
    'actions': [{'name': a.name, 'range': list(a.frame_range)} for a in bpy.data.actions],
}
evaluated.to_mesh_clear()
OUT.write_text(json.dumps(report, indent=2) + '\n')
print('INSPECTED', len(indices), 'hand vertices;', len(report['hand_faces']), 'hand faces', flush=True)
print('BOOK BOUNDS', report['book_bounds_world'], report['book_bounds_hand'], flush=True)
print('BONES', [b.name for b in arm.data.bones], flush=True)

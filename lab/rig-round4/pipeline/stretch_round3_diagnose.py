# Blender: collect all failing edge endpoints at each clip's worst sample.
import json
from pathlib import Path
import sys

import bpy

lane = Path(__file__).resolve().parent.parent
name, variant = sys.argv[sys.argv.index('--') + 1:]
folder = lane / 'mobs' / name / variant
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(folder / f'{name}.glb'), merge_vertices=True)
arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
rows = []
for report in json.loads((folder / 'reimport-deformation.json').read_text()):
    if not report['max_stretched_edges']:
        continue
    arm.animation_data.action = bpy.data.actions[report['clip']]
    frame = report['worst_frame']
    bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    indices = set()
    for edge in body.data.edges:
        a, b = edge.vertices
        rest = (body.data.vertices[a].co - body.data.vertices[b].co).length
        posed = (mesh.vertices[a].co - mesh.vertices[b].co).length
        if rest > 1e-6 and posed > rest * 3 and posed > .03:
            indices.update((int(a), int(b)))
    rows.append({'clip': report['clip'], 'vertices': [{'index': index, 'position': list(body.matrix_world @ body.data.vertices[index].co), 'weights': {body.vertex_groups[g.group].name: g.weight for g in body.data.vertices[index].groups}} for index in sorted(indices)]})
    evaluated.to_mesh_clear()
output = folder / 'round3-current-diagnosis.json'
assert not output.exists()
output.write_text(json.dumps(rows, indent=2) + '\n')
print('DIAGNOSED', name, [(row['clip'], len(row['vertices'])) for row in rows], flush=True)

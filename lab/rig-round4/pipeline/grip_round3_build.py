"""Curl the existing thumb towards the book; preserve every previous candidate."""
import hashlib
import json
import math
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector, kdtree
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
FOLDER = ROOT / 'mobs/uncrossedSelf'
SOURCE = FOLDER / 'rig-hold-contact'
OUT = FOLDER / 'rig-round3-grip-thumb20'
CLIPS = ('idle', 'walk', 'attack', 'cast', 'hurt', 'death')


def resource_gate():
    state = {'load': os.getloadavg()[0], 'free_gib': shutil.disk_usage(ROOT).free / 2**30}
    print('RESOURCES', state, flush=True)
    assert state['load'] < 30 and state['free_gib'] >= 100, state
    return state


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def scene_objects():
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.find_armature() == arm)
    book = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent_bone == 'LeftHand'
                and o.name.startswith('uncrossedSelf_prop'))
    return arm, body, book


def contacts(arm, body, book, patches):
    """Measure actual triangles at each eighth-frame, in a rigid book reference frame."""
    scene = bpy.context.scene
    arm.animation_data.action = bpy.data.actions['idle']
    scene.frame_set(1)
    book_reference = book.matrix_world.copy()
    tree = BVHTree.FromPolygons([book_reference @ v.co for v in book.data.vertices],
                               [tuple(p.vertices) for p in book.data.polygons])
    reference_scale = book_reference.to_scale()
    report = []
    for name in CLIPS:
        action = bpy.data.actions[name]
        arm.animation_data.action = action
        first, last = [round(x) for x in action.frame_range]
        rows = []
        for eighth in range(first * 8, last * 8 + 1):
            scene.frame_set(eighth // 8, subframe=(eighth % 8) / 8)
            assert (book.matrix_world.to_scale() - reference_scale).length < 1e-5
            transform = book_reference @ book.matrix_world.inverted()
            evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            row = {'frame': eighth / 8}
            for label, indices in patches.items():
                values = []
                for i in indices:
                    point = transform @ evaluated.matrix_world @ mesh.vertices[i].co
                    nearest, normal, _, gap = tree.find_nearest(point)
                    values.append((gap, (point-nearest).dot(normal)))
                row[label] = {'min_gap_m': min(v[0] for v in values),
                              'mean_gap_m': sum(v[0] for v in values)/len(values),
                              'vertices_within_5mm': sum(v[0] <= .005 for v in values),
                              'min_signed_nearest_normal_m': min(v[1] for v in values)}
            evaluated.to_mesh_clear()
            rows.append(row)
        summary = {'clip': name, 'samples': len(rows)}
        for label in patches:
            summary[label] = {
                'min_gap_m': min(row[label]['min_gap_m'] for row in rows),
                'max_gap_m': max(row[label]['min_gap_m'] for row in rows),
                'max_mean_gap_m': max(row[label]['mean_gap_m'] for row in rows),
                'minimum_vertices_within_5mm': min(row[label]['vertices_within_5mm'] for row in rows),
                'min_signed_nearest_normal_m': min(row[label]['min_signed_nearest_normal_m'] for row in rows),
            }
        report.append({'summary': summary, 'frames': rows})
        print('CONTACT', json.dumps(summary), flush=True)
    return report


assert not OUT.exists(), 'Preserve existing candidates'
resources = resource_gate()
source_hashes = {p.name: digest(p) for p in SOURCE.iterdir() if p.is_file()}
bpy.ops.wm.open_mainfile(filepath=str(SOURCE / 'uncrossedSelf.blend'))
arm, body, book = scene_objects()
hand_matrix = arm.data.bones['LeftHand'].matrix_local.copy()
hand_inverse = hand_matrix.inverted()
group = body.vertex_groups['LeftHand'].index
hand_indices = [v.index for v in body.data.vertices if any(g.group == group and g.weight > .5 for g in v.groups)]
local = {i: hand_inverse @ body.data.vertices[i].co for i in hand_indices}
adjacency = {i: set() for i in hand_indices}
for face in body.data.polygons:
    if all(i in adjacency for i in face.vertices):
        for i in face.vertices:
            adjacency[i].update(j for j in face.vertices if i != j)
# A 32 mm longitudinal cut separates the anatomical thumb from the four fingers.
allowed = {i for i, p in local.items() if p.y > .032}
thumb, pending = {1719}, [1719]
while pending:
    found = adjacency[pending.pop()] & allowed - thumb
    thumb.update(found)
    pending.extend(found)
assert thumb == {1694, 1704, 1707, 1708, 1712, 1713, 1716, 1719}, 'Source topology changed'
patches = {'thumb': sorted(thumb), 'other_hand': sorted(set(hand_indices)-thumb)}
original = np.array([v.co[:] for v in body.data.vertices])
original_weights = [[(g.group, g.weight) for g in v.groups] for v in body.data.vertices]
edges = np.array([e.vertices[:] for e in body.data.edges])
faces = np.array([p.vertices[:] for p in body.data.polygons])
assert faces.shape[1] == 3
before = contacts(arm, body, book, patches)
pivot = Vector((.008, .02, 0))
for i in thumb:
    p = local[i]
    blend = min(1, max(0, (p.y-pivot.y)/.04))
    blend = blend*blend*(3-2*blend)
    rotation = Matrix.Rotation(math.radians(20)*blend, 3, 'Z')
    body.data.vertices[i].co = hand_matrix @ (pivot + rotation @ (p-pivot))
body.data.update()
bpy.context.view_layer.update()
revised = np.array([v.co[:] for v in body.data.vertices])
changed = np.linalg.norm(revised-original, axis=1)
assert set(np.flatnonzero(changed > 1e-7)) == thumb
assert [[(g.group,g.weight) for g in v.groups] for v in body.data.vertices] == original_weights
base_lengths = np.linalg.norm(original[edges[:,0]]-original[edges[:,1]],axis=1)
new_lengths = np.linalg.norm(revised[edges[:,0]]-revised[edges[:,1]],axis=1)
changed_edges = np.any(np.isin(edges, list(thumb)),axis=1)
ratios = new_lengths[changed_edges]/base_lengths[changed_edges]
base_normals = np.cross(original[faces[:,1]]-original[faces[:,0]],original[faces[:,2]]-original[faces[:,0]])
new_normals = np.cross(revised[faces[:,1]]-revised[faces[:,0]],revised[faces[:,2]]-revised[faces[:,0]])
flips = int((np.sum(base_normals*new_normals,axis=1) <= 0).sum())
static = {'changed_vertices': len(thumb), 'max_vertex_delta_m': float(changed.max()),
          'affected_edges': int(changed_edges.sum()), 'min_edge_ratio': float(ratios.min()),
          'max_edge_ratio': float(ratios.max()), 'normal_flips': flips,
          'new_edges_over_3x_and_30mm': int(((new_lengths>base_lengths*3)&(new_lengths>.03)&(base_lengths>1e-6)).sum())}
print('STATIC DEFORMATION', json.dumps(static), flush=True)
after = contacts(arm, body, book, patches)
(FOLDER/'round3-grip-build-analysis.json').write_text(json.dumps({'static_deformation': static, 'before':before, 'after':after},indent=2)+'\n')
assert flips == 0 and ratios.min() > .6 and ratios.max() < 1.5 and static['new_edges_over_3x_and_30mm']==0, static
for baseline, candidate in zip(before, after):
    assert candidate['summary']['thumb']['max_gap_m'] < baseline['summary']['thumb']['max_gap_m']
    assert candidate['summary']['thumb']['max_gap_m'] < .008
    assert candidate['summary']['thumb']['min_signed_nearest_normal_m'] >= -.001
    for b, c in zip(baseline['frames'], candidate['frames']):
        assert abs(b['other_hand']['min_gap_m']-c['other_hand']['min_gap_m']) < 1e-6

OUT.mkdir()
report = {'source': str(SOURCE), 'source_sha256': source_hashes, 'resources_at_start': resources,
          'change': 'Curl only the existing eight-vertex thumb branch by up to 20 degrees with a smooth base falloff.',
          'unchanged': ['Book transform and attachment', 'Other four fingers', 'All weights and bones', 'All six actions', 'Other characters'],
          'measurement': 'Nearest actual book triangle for each selected evaluated hand vertex at every eighth-frame. Signed nearest-normal distance is a local proxy, not an inside/outside volume proof.',
          'anatomy': 'Separate thumb and four finger branches exist. No finger bones exist; this is a fixed mesh grip.',
          'static_deformation': static, 'patches': patches, 'before': before, 'after': after}
(OUT / 'grip.json').write_text(json.dumps(report,indent=2)+'\n')
arm.animation_data.action = bpy.data.actions['idle']
bpy.context.scene.frame_set(1)
reference_points = {label:[list(body.matrix_world @ body.data.vertices[i].co) for i in indices]
                    for label,indices in patches.items()}
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'uncrossedSelf.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT / 'uncrossedSelf.glb'),export_format='GLB',
                          export_animations=True,export_animation_mode='ACTIONS')
resource_gate()
sys.argv = [str(ROOT/'pipeline/check_candidate_batch.py'),'--','mobs/uncrossedSelf/rig-round3-grip-thumb20']
runpy.run_path(str(ROOT/'pipeline/check_candidate_batch.py'),run_name='__main__')
deformation = json.loads((OUT/'reimport-deformation.json').read_text())
assert {r['clip'] for r in deformation} == set(CLIPS)
assert all(r['max_stretched_edges']==0 and r['min_z']>=-.005 and r['max_min_z']<=.015 for r in deformation)
arm, body, book = scene_objects()
# GLB import can reorder vertices; map against the exact saved rest positions.
tree = kdtree.KDTree(len(body.data.vertices))
for v in body.data.vertices:
    tree.insert(body.matrix_world @ v.co,v.index)
tree.balance()
imported_patches = {}
for label, points in reference_points.items():
    matches = [tree.find(Vector(p)) for p in points]
    assert all(distance<1e-5 for _,_,distance in matches), 'Rest position changed during export'
    imported_patches[label] = [i for _,i,_ in matches]
    assert len(set(imported_patches[label])) == len(points), 'Ambiguous imported patch'
imported = contacts(arm,body,book,imported_patches)
(OUT/'reimport-contact.json').write_text(json.dumps(imported,indent=2)+'\n')
assert all(r['summary']['thumb']['max_gap_m']<.008 and r['summary']['thumb']['min_signed_nearest_normal_m']>=-.001 for r in imported)
assert all(digest(SOURCE/name)==value for name,value in source_hashes.items()), 'Source changed'
print('ROUND3 GRIP PASS', json.dumps(static), flush=True)

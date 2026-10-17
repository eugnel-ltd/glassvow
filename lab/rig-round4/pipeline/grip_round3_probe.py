"""Measure existing finger branches and bounded mesh curls; no renders or saved rigs."""
import json
import math
import os
from pathlib import Path
import shutil

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'mobs/uncrossedSelf/round3-grip-probe.json'
assert not OUT.exists()
assert os.getloadavg()[0] < 30 and shutil.disk_usage(ROOT).free / 2**30 >= 100
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'mobs/uncrossedSelf/rig-hold-contact/uncrossedSelf.blend'))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.find_armature() == arm)
book = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent_bone == 'LeftHand')
arm.animation_data.action = bpy.data.actions['idle']
bpy.context.scene.frame_set(1)
hand = arm.data.bones['LeftHand'].matrix_local
hand_inv = hand.inverted()
group = body.vertex_groups['LeftHand'].index
original = {v.index: v.co.copy() for v in body.data.vertices}
local = {v.index: hand_inv @ v.co for v in body.data.vertices if any(g.group == group and g.weight > .5 for g in v.groups)}
# The separate thumb branch is isolated by the hand-local lateral coordinate.
thumb = [i for i, p in local.items() if p.y > .025 and p.z > .008]
fingers = [i for i, p in local.items() if p.y > .055 and p.z < .008]
palm = [i for i, p in local.items() if -.005 < p.y < .055 and p.z < .008]
book_vertices = [book.matrix_world @ v.co for v in book.data.vertices]
book_faces = [tuple(p.vertices) for p in book.data.polygons]
tree = BVHTree.FromPolygons(book_vertices, book_faces)

def measure(indices):
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    records = []
    for i in indices:
        p = evaluated.matrix_world @ mesh.vertices[i].co
        nearest, normal, face, distance = tree.find_nearest(p)
        records.append({'index': i, 'world': list(p), 'nearest': list(nearest), 'normal': list(normal),
                        'gap': distance, 'signed_normal_distance': (p-nearest).dot(normal)})
    evaluated.to_mesh_clear()
    return {'min_gap': min(r['gap'] for r in records), 'mean_gap': sum(r['gap'] for r in records)/len(records),
            'within_5mm': sum(r['gap'] <= .005 for r in records),
            'min_signed_normal_distance': min(r['signed_normal_distance'] for r in records), 'vertices': records}

def curl(angle, thumb_angle):
    for i, p in original.items():
        body.data.vertices[i].co = p
    for indices, degrees, pivot_y in ((fingers, angle, .05), (thumb, thumb_angle, .02)):
        pivot = Vector((.008, pivot_y, 0))
        for i in indices:
            p = local[i]
            blend = min(1, max(0, (p.y - pivot_y)/.04))
            blend = blend*blend*(3-2*blend)
            rotation = Matrix.Rotation(math.radians(degrees)*blend, 3, 'Z')
            body.data.vertices[i].co = hand @ (pivot + rotation @ (p-pivot))
    body.data.update()
    bpy.context.view_layer.update()

results=[]
for angle, thumb_angle in ((0,0),(20,20),(35,35),(50,45),(-20,-20)):
    curl(angle, thumb_angle)
    results.append({'finger_degrees': angle, 'thumb_degrees': thumb_angle,
                    'thumb': measure(thumb), 'fingers': measure(fingers), 'palm': measure(palm),
                    'max_delta': max((v.co-original[v.index]).length for v in body.data.vertices)})
    print('PROBE', angle, thumb_angle, {g:{k:v for k,v in results[-1][g].items() if k!='vertices'} for g in ('thumb','fingers','palm')}, flush=True)
OUT.write_text(json.dumps({'source':'rig-hold-contact','thumb_indices':thumb,'finger_indices':fingers,'trials':results},indent=2)+'\n')

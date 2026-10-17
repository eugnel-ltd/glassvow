# Blender: source.blend --python hem_uv_fill.py -- settings.json
# Tripo paints the never-seen robe underside near-black, and a forward fall shows it to a rear camera.
# Give each downward-facing face near the ground the UV of the nearest side-facing hem vertex, so the
# underside reads as robe cloth. Geometry, weights and animation stay unchanged; feet keep their UVs.
import json
from pathlib import Path
import sys

import bpy
from mathutils.kdtree import KDTree

settings = json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text())
arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
mesh = body.data
uv = mesh.uv_layers.active.data
world, turn = body.matrix_world, body.matrix_world.to_3x3()
foot = {group.index for group in body.vertex_groups if 'Foot' in group.name or 'Toes' in group.name}
height = settings.get('hem_height', .15)
bottom_nz = settings.get('bottom_nz', -.7)
if settings.get('cap_hem'):
    # An open robe hem shows the inside to a low camera. Close large ground-level loops with
    # faces on the existing vertices, so the cap inherits their weights and needs no new data.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    edges = [e for e in bm.edges if e.is_boundary
             and all((world @ v.co).z < height for v in e.verts)]
    made = bmesh.ops.holes_fill(bm, edges=edges, sides=0)['faces']
    bmesh.ops.recalc_face_normals(bm, faces=made)
    bmesh.ops.triangulate(bm, faces=made)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    uv = mesh.uv_layers.active.data
    print('HEM CAP', len(made), 'faces', flush=True)


def on_foot(poly):
    return any(sum(g.weight for g in mesh.vertices[v].groups if g.group in foot) > .5 for v in poly.vertices)


bottom, side = [], []
for poly in mesh.polygons:
    if on_foot(poly):
        continue
    centre, normal = world @ poly.center, (turn @ poly.normal).normalized()
    if centre.z < height and normal.z < bottom_nz:
        bottom.append(poly)
    elif centre.z < height + .1 and abs(normal.z) < .3:
        side.append(poly)
assert bottom and side, (len(bottom), len(side))
tree = KDTree(sum(poly.loop_total for poly in side))
side_uv = []
for poly in side:
    for i in poly.loop_indices:
        tree.insert(world @ mesh.vertices[mesh.loops[i].vertex_index].co, len(side_uv))
        side_uv.append(uv[i].uv.copy())
tree.balance()
for poly in bottom:
    for i in poly.loop_indices:
        uv[i].uv = side_uv[tree.find(world @ mesh.vertices[mesh.loops[i].vertex_index].co)[1]]
# Contact candidates use 120 FPS to sample quarter frames. Restore 30 FPS for grounding.
assert bpy.context.scene.render.fps == 120, 'Use a grounded quarter-frame source'
for action in bpy.data.actions:
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    assert not curve.modifiers and not curve.sampled_points, 'Use baked keyframes without curve modifiers'
                    for key in curve.keyframe_points:
                        key.co.x /= 4
                        key.handle_left.x /= 4
                        key.handle_right.x /= 4
    if action.use_frame_range:
        action.frame_start /= 4
        action.frame_end /= 4
bpy.context.scene.render.fps = 30
output = Path(settings['source_output'])
assert not output.exists(), 'Preserve an existing trial'
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('HEM UV FILL', len(bottom), 'underside faces from', len(side), 'side faces', flush=True)

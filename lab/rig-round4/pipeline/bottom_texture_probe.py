# Blender: compare base-colour texture samples on downward-facing hem faces with side faces near the hem.
#   blender -b source.blend --python bottom_texture_probe.py
import bpy
from mathutils import Vector

arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
mesh = body.data
uv = mesh.uv_layers.active.data
image = next(node.image for slot in body.material_slots for node in slot.material.node_tree.nodes
             if node.type == 'TEX_IMAGE' and node.image)
width, height = image.size
pixels = image.pixels[:]


def sample(poly):
    u = sum(uv[i].uv.x for i in poly.loop_indices) / poly.loop_total % 1
    v = sum(uv[i].uv.y for i in poly.loop_indices) / poly.loop_total % 1
    index = (int(v * (height - 1)) * width + int(u * (width - 1))) * 4
    return pixels[index:index + 3]


groups = {'bottom': [], 'side': []}
for poly in mesh.polygons:
    centre = body.matrix_world @ poly.center
    normal = (body.matrix_world.to_3x3() @ poly.normal).normalized()
    if centre.z < .15 and normal.z < -.7:
        groups['bottom'].append(sample(poly))
    elif centre.z < .25 and abs(normal.z) < .3:
        groups['side'].append(sample(poly))
for name, rows in groups.items():
    if rows:
        mean = [round(sum(c) / len(rows), 3) for c in zip(*rows)]
        print('TEXTURE', body.name, name, len(rows), 'faces mean rgb', mean)

# Crude A-pose humanoid + stick prop, for testing char_rig.py without credits.
#   blender -b --factory-startup --python make_standin.py -- out_dir
import bpy, math, os, sys
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)


def limb(a, b, r):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, location=(a + b) / 2, vertices=16)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return o


def blob(c, r):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=c, segments=16, ring_count=10)
    return bpy.context.object


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True)


bpy.ops.wm.read_factory_settings(use_empty=True)
parts = [limb((0, 0, .9), (0, 0, 1.45), .17), blob((0, 0, 1.6), .12)]  # torso, head
for s in (1, -1):
    sh, el, wr = (s * .2, 0, 1.42), (s * .38, 0, 1.15), (s * .52, 0, .9)
    parts += [limb(sh, el, .05), limb(el, wr, .045), blob((s * .56, 0, .84), .05)]
    parts += [limb((s * .1, 0, .9), (s * .12, 0, .5), .07), limb((s * .12, 0, .5), (s * .13, 0, .08), .06)]
    parts += [limb((s * .13, .02, .04), (s * .13, -.14, .04), .045)]
export(parts, os.path.join(out, "standin-body.glb"))
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
export([limb((0, 0, 0), (0, 0, .7), .02), blob((0, 0, .7), .06)], os.path.join(out, "standin-prop.glb"))
print("STANDIN ok")

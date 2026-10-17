import bpy, sys, os
src, out = sys.argv[-2], sys.argv[-1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
act = arm.animation_data.action
act.name = 'death'
arm.animation_data.action = act
scene = bpy.context.scene
scene.render.resolution_x, scene.render.resolution_y = 640, 480
scene.render.image_settings.file_format = 'PNG'
scene.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
scene.collection.objects.link(cam)
cam.location = (3.2, -3.2, 1.6)
cam.rotation_euler = (1.15, 0, 0.78)
scene.camera = cam
light = bpy.data.objects.new('key', bpy.data.lights.new('key', 'SUN'))
scene.collection.objects.link(light)
light.rotation_euler = (0.9, 0.2, 0.6)
light.data.energy = 4
for f in (1, 12, 24, 29, 36, 48):
    scene.frame_set(f)
    scene.render.filepath = os.path.join(out, f'death-f{f:02d}.png')
    bpy.ops.render.render(write_still=True)
print('SHADE FRAMES DONE')

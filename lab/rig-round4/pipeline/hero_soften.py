# Blender: source.blend --python hero_soften.py -- output.blend clip:factor:Bone,Bone [...]
# Scale each named bone's rotation in a clip towards the clip's first key, then re-bake the cape for that clip by
# hero_cape_bones.py's rule. Ashwarden tore at the armpits lifting the lantern and at the coat in the death fold.
import math
from pathlib import Path
import sys

import bpy
from mathutils import Quaternion

output, *specs = sys.argv[sys.argv.index("--") + 1:]
assert specs and not Path(output).exists(), "Preserve an existing experiment"
scene = bpy.context.scene
assert scene.render.fps == 30
arm = next(obj for obj in scene.objects if obj.type == "ARMATURE")
for item in specs:
    clip, factor, names = item.split(":")
    action = bpy.data.actions[clip]
    arm.animation_data.action = action
    curves = [curve for layer in action.layers for strip in layer.strips for bag in strip.channelbags for curve in bag.fcurves]
    for name in names.split(","):
        bone = arm.pose.bones[name]
        path = f'pose.bones["{name}"].rotation_quaternion'
        frames = sorted({key.co.x for curve in curves if curve.data_path == path for key in curve.keyframe_points})
        values = {}
        for frame in frames:
            scene.frame_set(int(frame), subframe=frame % 1)
            if not values:
                start = bone.rotation_quaternion.copy()
            values[frame] = (start @ Quaternion().slerp(start.inverted() @ bone.rotation_quaternion, float(factor))).normalized()
        for frame, value in values.items():
            bone.rotation_quaternion = value
            bone.keyframe_insert("rotation_quaternion", frame=frame)
        print("SOFTEN", clip, name, factor, "keys", len(frames), flush=True)
    first, last = (int(value) for value in action.frame_range)
    for frame in range(first, last + 1):
        scene.frame_set(frame)
        chest = arm.pose.bones["UpperChest"]
        rotation = chest.matrix.to_quaternion() @ chest.bone.matrix_local.to_quaternion().inverted()
        phase = 2 * math.pi * (frame - first) / max(last - first, 1)
        for index, name in enumerate(("CapeUpper", "CapeLower")):
            bone = arm.pose.bones[name]
            follow = .20 if index == 0 else .06
            flutter = 0 if clip == "death" else math.radians(2) * math.sin(phase) * (index + 1)
            target = Quaternion().slerp(rotation, follow) @ Quaternion((1, 0, 0), flutter)
            desired = (target @ bone.bone.matrix_local.to_quaternion()).to_matrix().to_4x4()
            desired.translation = bone.head
            bone.matrix = desired
            bpy.context.view_layer.update()
            for property_name in ("location", "rotation_quaternion", "scale"):
                bone.keyframe_insert(property_name, frame=frame)
arm.animation_data.action = bpy.data.actions["idle"]
scene.frame_set(1)
Path(output).parent.mkdir()
bpy.ops.wm.save_as_mainfile(filepath=output)

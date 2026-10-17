# Blender: print each animated bone's rotation away from rest, at chosen fractions of one clip.
#   blender -b source.blend --python pose_probe.py -- <clip> <fraction> ...
import math
import sys

import bpy

clip, *fractions = sys.argv[sys.argv.index('--') + 1:]
scene = bpy.context.scene
arm = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
action = bpy.data.actions[clip]
arm.animation_data.action = action
first, last = action.frame_range
print('BONES', [(b.name, b.parent.name if b.parent else None) for b in arm.data.bones])
for fraction in map(float, fractions):
    frame = first + (last - first) * fraction
    scene.frame_set(int(frame), subframe=frame % 1)
    for bone in arm.pose.bones:
        angle = math.degrees(bone.rotation_quaternion.angle)
        if angle > 3:
            # Report the rotation axis in world space so it can be compared with edit axes.
            axis = (bone.bone.matrix_local.to_3x3() @ bone.rotation_quaternion.axis).normalized()
            print(f'POSE {clip} {fraction:.2f} {bone.name} {angle:.1f} deg axis {tuple(round(v, 2) for v in axis)}')

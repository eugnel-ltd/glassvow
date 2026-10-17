# Blender: print armature-space head and Y direction of chosen bones at a fraction of one clip.
#   blender -b source.blend --python bone_where.py -- <clip> <fraction> <bone> ...
import sys

import bpy

clip, fraction, *bones = sys.argv[sys.argv.index('--') + 1:]
scene = bpy.context.scene
arm = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
action = bpy.data.actions[clip]
arm.animation_data.action = action
first, last = action.frame_range
frame = first + (last - first) * float(fraction)
scene.frame_set(int(frame), subframe=frame % 1)
for name in bones:
    pose = arm.pose.bones[name]
    direction = pose.matrix.to_3x3().col[1].normalized()
    rest = arm.data.bones[name].matrix_local.to_3x3().col[1].normalized()
    print('WHERE', name, 'head', tuple(round(v, 3) for v in pose.head), 'dir', tuple(round(v, 2) for v in direction),
          'rest_dir', tuple(round(v, 2) for v in rest))

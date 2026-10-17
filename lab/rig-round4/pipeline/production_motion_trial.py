# Blender: edit a preserved candidate with explicit per-clip rotation offsets.
# Use grounded 120 FPS sources. Save a 30 FPS source for the existing contact bake.
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Quaternion, Vector

settings = json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text())
scene = bpy.context.scene
arm = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
assert scene.render.fps == 120 and not arm.animation_data.nla_tracks
output = Path(settings['source_output'])
assert not output.exists()
for action in bpy.data.actions:
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    assert not curve.modifiers and not curve.sampled_points
                    for key in curve.keyframe_points:
                        key.co.x /= 4
                        key.handle_left.x /= 4
                        key.handle_right.x /= 4
    if action.use_frame_range:
        action.frame_start /= 4
        action.frame_end /= 4
scene.render.fps = 30
for edit in settings['motion_edits']:
    action = bpy.data.actions[edit['clip']]
    arm.animation_data.action = action
    first, last = action.frame_range
    bone = arm.pose.bones[edit['bone']]
    samples = []
    # A 'scale' edit multiplies the bone-local scale; otherwise rotate about a world axis.
    path = 'scale' if 'scale' in edit else 'rotation_quaternion'
    if path == 'rotation_quaternion' and 'upright' not in edit:
        axis = (bone.bone.matrix_local.to_3x3().inverted() @ Vector(edit['axis'])).normalized()
    for quarter in range(round(first * 4), round(last * 4) + 1):
        frame = quarter / 4
        scene.frame_set(quarter // 4, subframe=quarter % 4 / 4)
        fraction = (frame - first) / (last - first)
        if edit.get('cycles'):
            # Signed whole-number wave: a looping clip keeps matching start and end poses.
            assert edit['cycles'] == int(edit['cycles'])
            amount = math.sin(2 * math.pi * edit['cycles'] * fraction + math.radians(edit.get('phase', 0)))
        elif edit.get('hold_end'):
            t = max(0, min(1, (fraction - edit.get('start', .25)) / (edit.get('finish', .8) - edit.get('start', .25))))
            amount = t * t * (3 - 2 * t)
        else:
            amount = math.sin(math.pi * fraction) ** 2
        if path == 'scale':
            factor = [1 + (target - 1) * amount for target in edit['scale']]
            samples.append((frame, Vector([s * f for s, f in zip(bone.scale, factor)])))
        elif 'upright' in edit:
            # Hang the bone: blend towards the local rotation that restores its rest orientation
            # in armature space, whatever the parent chain is doing (a lantern under gravity).
            # Optional target_axis/target_degrees turn the rest orientation in world space first
            # (e.g. lay a dropped weapon down); timed edits blend in with the usual amount.
            rest = bone.bone.matrix_local.to_quaternion()
            if 'target_axis' in edit:
                rest = Quaternion(Vector(edit['target_axis']), math.radians(edit['target_degrees'])) @ rest
            relative = (bone.parent.bone.matrix_local.inverted() @ bone.bone.matrix_local).to_quaternion()
            hanging = (bone.parent.matrix.to_quaternion() @ relative).inverted() @ rest
            # 'pulse' blends in and out with the sin^2 amount, so the clip's first and last poses stay unchanged.
            weight = edit['upright'] * (amount if edit.get('hold_end') or edit.get('cycles') or edit.get('pulse') else 1)
            samples.append((frame, bone.rotation_quaternion.slerp(hanging, weight).normalized()))
        else:
            rotation = Quaternion(axis, math.radians(edit['degrees']) * amount) @ bone.rotation_quaternion
            samples.append((frame, rotation.normalized()))
    for frame, value in samples:
        setattr(bone, path, value)
        bone.keyframe_insert(path, frame=frame)
    print('MOTION OFFSET', edit, flush=True)
arm.animation_data.action = bpy.data.actions['idle']
scene.frame_set(1)
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output))

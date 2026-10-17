# Blender: fold the cape above body support before the existing root-contact bake.
import json
import math
import os
from pathlib import Path
import shutil
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector
import numpy as np

lane = Path(__file__).resolve().parent.parent
name, *variants = sys.argv[sys.argv.index("--") + 1:]  # optional: source and output variant, for an experiment
assert name in ("duskblade", "ashwarden")
folder = lane / "chars" / name
source_variant, output_variant = variants or (
    "rig-cape-connected" if name == "duskblade" else "rig-cape-anchored", "rig-cape-floor-fold")
output = folder / output_variant
assert not output.exists(), "Preserve an existing experiment"
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
bpy.ops.wm.open_mainfile(filepath=str(folder / source_variant / f"{name}.blend"))
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
scene = bpy.context.scene
assert scene.render.fps == 30
cape_bones = ("CapeUpper", "CapeLower")
cape_groups = {group.index for group in body.vertex_groups if group.name in cape_bones}
fixed = [vertex.index for vertex in body.data.vertices
         if sum(group.weight for group in vertex.groups if group.group in cape_groups) < 1e-6]
assert len(fixed) > len(body.data.vertices) * .6
axis = (arm.matrix_world.to_3x3().inverted() @ Vector((1, 0, 0))).normalized()


def points():
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    try:
        result = np.array([(evaluated.matrix_world @ vertex.co)[:] for vertex in mesh.vertices])
    finally:
        evaluated.to_mesh_clear()
    assert np.isfinite(result).all()
    return result


# Cache original matrices before inserting any new keys into their actions.
poses = {}
for action in bpy.data.actions:
    arm.animation_data.action = action
    first, last = (int(value) for value in action.frame_range)
    for frame in range(first, last + 1):
        scene.frame_set(frame)
        vertices = points()
        poses[action.name, frame] = (
            {name: arm.pose.bones[name].matrix.copy() for name in cape_bones},
            vertices[fixed].copy(),
            {bone.name: bone.matrix.copy() for bone in arm.pose.bones if bone.name not in cape_bones},
        )

reports = []
expected = {}
for action in list(bpy.data.actions):
    arm.animation_data.action = action
    first, last = (int(value) for value in action.frame_range)
    angles = []
    for frame in range(first, last + 1):
        scene.frame_set(frame)
        base, original_fixed, original_bones = poses[action.name, frame]
        support = float(original_fixed[:, 2].min())
        arm.pose.bones["CapeUpper"].matrix = base["CapeUpper"]
        bpy.context.view_layer.update()

        def test(degrees):
            matrix = base["CapeLower"]
            pivot = matrix.translation
            desired = (Matrix.Translation(pivot)
                       @ Quaternion(axis, math.radians(degrees)).to_matrix().to_4x4()
                       @ Matrix.Translation(-pivot) @ matrix)
            arm.pose.bones["CapeLower"].matrix = desired
            bpy.context.view_layer.update()
            posed = points()
            assert np.max(np.abs(posed[fixed] - original_fixed)) < 2e-5
            return float(posed[:, 2].min()) - support

        angle = 0.0
        if test(0) < -.0001:
            # ponytail: one fold axis; replace with cloth collision if this bounded solve fails.
            for high in range(5, 101, 5):
                if test(high) >= -.0001:
                    low = high - 5
                    for _ in range(8):
                        middle = (low + high) / 2
                        if test(middle) >= -.0001:
                            high = middle
                        else:
                            low = middle
                    angle = min(high + 1, 100)
                    break
            else:
                raise AssertionError((action.name, frame, "Cape fold has no feasible angle"))
        assert test(angle) >= -.0001, (action.name, frame, angle)
        angles.append(angle)
        bone = arm.pose.bones["CapeLower"]
        bone.rotation_mode = "QUATERNION"
        for property_name in ("location", "rotation_quaternion", "scale"):
            bone.keyframe_insert(property_name, frame=frame)
        expected[action.name, frame] = bone.matrix.copy()
        for bone_name, matrix in original_bones.items():
            assert max(abs(arm.pose.bones[bone_name].matrix[r][c] - matrix[r][c])
                       for r in range(4) for c in range(4)) < 2e-5
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    if 'pose.bones["CapeLower"]' in curve.data_path:
                        for key in curve.keyframe_points:
                            key.interpolation = "LINEAR"
    relative_heights = []
    for eighth in range(first * 8, last * 8 + 1):
        scene.frame_set(eighth // 8, subframe=(eighth % 8) / 8)
        posed = points()
        relative_heights.append(float(posed[:, 2].min() - posed[fixed, 2].min()))
    assert min(relative_heights) >= -.005, (action.name, min(relative_heights))
    for frame in range(first, last + 1):
        scene.frame_set(frame)
        matrix = expected[action.name, frame]
        assert max(abs(arm.pose.bones["CapeLower"].matrix[r][c] - matrix[r][c])
                   for r in range(4) for c in range(4)) < 2e-5
    report = {"clip": action.name, "maximum_fold_degrees": max(angles),
              "minimum_cape_relative_to_support_m": min(relative_heights),
              "samples": len(relative_heights)}
    reports.append(report)
    print("CAPE FLOOR", json.dumps(report), flush=True)
output.mkdir()
(output / "fold.json").write_text(json.dumps({"clips": reports,
    "original_body_pose_control": "passed at every integer frame",
    "unaffected_surface_control": "passed at every solve evaluation",
    "limitation": "Single-axis baked fold against the body support plane; no cloth self-collision"}, indent=2) + "\n")
arm.animation_data.action = bpy.data.actions["idle"]
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(output / f"{name}.blend"))
print("CAPE FLOOR CANDIDATE DONE", str(output), flush=True)

# Blender: test cape folding against the support plane without changing the body pose.
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
folder = lane / "chars" / "duskblade" / "rig-cape-connected"
output = folder / "floor-fold-probe.json"
assert not output.exists(), "Preserve an existing experiment"
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
bpy.ops.wm.open_mainfile(filepath=str(folder / "duskblade.blend"))
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
scene = bpy.context.scene
assert scene.render.fps == 30
cape = {group.index for group in body.vertex_groups if group.name in ("CapeUpper", "CapeLower")}
fixed = [vertex.index for vertex in body.data.vertices
         if sum(group.weight for group in vertex.groups if group.group in cape) < 1e-6]
assert len(fixed) > 3000
axis = (arm.matrix_world.to_3x3().inverted() @ Vector((1, 0, 0))).normalized()


def minima():
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    try:
        points = np.array([(evaluated.matrix_world @ vertex.co)[:] for vertex in mesh.vertices])
    finally:
        evaluated.to_mesh_clear()
    assert np.isfinite(points).all()
    return float(points[:, 2].min()), float(points[fixed, 2].min())


def rotate_about(matrix, pivot, degrees):
    return Matrix.Translation(pivot) @ Quaternion(axis, math.radians(degrees)).to_matrix().to_4x4() @ Matrix.Translation(-pivot) @ matrix


rows = []
arm.animation_data.action = bpy.data.actions["death"]
first, last = arm.animation_data.action.frame_range
for fraction in (0, .5, .75, 1):
    frame = first + (last - first) * fraction
    scene.frame_set(math.floor(frame), subframe=frame % 1)
    base = {name: arm.pose.bones[name].matrix.copy() for name in ("CapeUpper", "CapeLower")}
    before, support = minima()
    trials = []
    for upper in (0, 15, 30, 45, 60):
        for lower in (0, 15, 30, 45, 60, 75, 90):
            upper_matrix = rotate_about(base["CapeUpper"], base["CapeUpper"].translation, upper)
            lower_matrix = rotate_about(base["CapeLower"], base["CapeUpper"].translation, upper)
            lower_matrix = rotate_about(lower_matrix, lower_matrix.translation, lower)
            arm.pose.bones["CapeUpper"].matrix = upper_matrix
            bpy.context.view_layer.update()
            arm.pose.bones["CapeLower"].matrix = lower_matrix
            bpy.context.view_layer.update()
            height, unchanged_support = minima()
            assert abs(unchanged_support - support) < 2e-5
            trials.append({"upper_deg": upper, "lower_deg": lower, "relative_min_z_m": height - support})
    feasible = [row for row in trials if row["relative_min_z_m"] >= -1e-4]
    best = min(feasible, key=lambda row: (row["upper_deg"], row["lower_deg"])) if feasible else None
    rows.append({"fraction": fraction, "frame": frame, "before_relative_min_z_m": before - support,
                 "best": best, "trials": trials})
    print("FLOOR FOLD PROBE", json.dumps({key: value for key, value in rows[-1].items() if key != "trials"}), flush=True)
output.write_text(json.dumps(rows, indent=2) + "\n")

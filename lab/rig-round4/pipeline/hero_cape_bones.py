# Blender: inspect a cape region, then test two baked garment bones on a separate candidate.
import ast
import json
import math
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector
import numpy as np

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
mode = sys.argv[sys.argv.index("--") + 1]
assert mode in ("--mask", "--build", "--anchored")
source = pipeline / "char_rig.py"
module = ast.parse(source.read_text())
assert module.body[-1].value.func.id == "main"
module.body.pop()

for name in (("ashwarden",) if mode == "--anchored" else ("duskblade", "ashwarden")):
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    folder = lane / "chars" / name
    variant = "rig-cape-anchored" if mode == "--anchored" else "rig-cape-connected"
    output = folder / ("cape-region-connected" if mode == "--mask" else variant)
    assert not output.exists(), "Preserve an existing experiment"
    sys.argv = [str(source), "--", str(folder / "rig.json")]
    helpers = {"__file__": str(source)}
    exec(compile(module, str(source), "exec"), helpers)
    bpy.ops.wm.open_mainfile(filepath=str(folder / "rig-fitted-weights" / f"{name}.blend"))
    scene = bpy.context.scene
    assert scene.render.fps == 30
    arm = next(obj for obj in scene.objects if obj.type == "ARMATURE")
    body = next(obj for obj in scene.objects if obj.type == "MESH" and obj.find_armature() == arm)
    co = np.array([(body.matrix_world @ vertex.co)[:] for vertex in body.data.vertices])
    # Grow from the hanging hem below the measured body connection height.
    top = 1.35 if name == "duskblade" else 1.10
    adjacency = [set() for _ in co]
    for edge in body.data.edges:
        a, b = edge.vertices
        adjacency[a].add(b)
        adjacency[b].add(a)
    allowed = set(np.flatnonzero(co[:, 2] < top).tolist())
    seeds = set(np.flatnonzero((co[:, 1] > .23) & (co[:, 2] < .65)).tolist())
    selected, pending = set(seeds), list(seeds)
    while pending:
        vertex = pending.pop()
        neighbours = (adjacency[vertex] & allowed) - selected
        selected |= neighbours
        pending.extend(neighbours)
    ids = np.array(sorted(selected))
    assert 500 < len(ids) < 1000 and co[ids, 1].min() > .02 and co[ids, 2].min() > .1
    mask = np.zeros(len(co))
    mask[ids] = np.clip((top - co[ids, 2]) / .14, 0, 1)
    mask = mask * mask * (3 - 2 * mask)
    assert 100 < np.count_nonzero(mask > .5) < len(co) / 2
    output.mkdir()
    if mode == "--mask":
        colours = body.data.color_attributes.new(name="CapeRegion", type="FLOAT_COLOR", domain="CORNER")
        for loop in body.data.loops:
            value = mask[loop.vertex_index]
            colours.data[loop.index].color = (.18 + .7 * value, .18 * (1 - value), .18 * (1 - value), 1)
        material = bpy.data.materials.new("Cape region inspection")
        material.use_nodes = True
        nodes = material.node_tree.nodes
        colour = nodes.new("ShaderNodeVertexColor")
        colour.layer_name = colours.name
        material.node_tree.links.new(colour.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
        body.data.materials.clear()
        body.data.materials.append(material)
        for polygon in body.data.polygons:
            polygon.material_index = 0
        helpers["stage"]()
        arm.animation_data.action = bpy.data.actions["idle"]
        scene.frame_set(1)
        graph = bpy.context.evaluated_depsgraph_get()
        evaluated = body.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        points = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
        evaluated.to_mesh_clear()
        for index, direction in enumerate(((0, 1, .1), (1, 0, .1))):
            helpers["frame_camera"](points, direction)
            helpers["shot"](str(output / f"region-{index}.png"))
        (output / "region.json").write_text(json.dumps({"affected": int((mask > 0).sum()),
            "core": int((mask > .5).sum()), "vertices": len(co)}, indent=2) + "\n")
        continue

    # Preserve every original bone pose as an executable control.
    originals = {}
    for action in bpy.data.actions:
        arm.animation_data.action = action
        first, last = action.frame_range
        for frame in (first, (first + last) / 2, last):
            scene.frame_set(int(frame), subframe=frame % 1)
            originals[action.name, frame] = {bone.name: bone.matrix.copy() for bone in arm.pose.bones}
    arm.animation_data.action = None
    for bone in arm.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    helpers["only"]([arm])
    bpy.ops.object.mode_set(mode="EDIT")
    edit = arm.data.edit_bones
    cape_bones = ("CapeUpper", "CapeLower")
    levels = (1.10, .70, .30) if mode == "--anchored" else (1.40, .90, .30)
    joints = []
    for height in levels:
        section_mask = (mask > 0) if mode == "--anchored" else (co[:, 1] > .20 - .19 * co[:, 2])
        section = co[section_mask & (abs(co[:, 2] - height) < .09)]
        assert len(section) > 5, (name, height)
        joints.append(arm.matrix_world.inverted() @ Vector((0, float(np.median(section[:, 1])), height)))
    for index, bone_name in enumerate(cape_bones):
        bone = edit.new(bone_name)
        bone.head, bone.tail = joints[index:index + 2]
        bone.align_roll(Vector((0, -1, 0)))
        bone.parent = edit["UpperChest" if index == 0 else cape_bones[index - 1]]
        bone.use_connect = index > 0
    bpy.ops.object.mode_set(mode="OBJECT")
    old_groups = list(body.vertex_groups)
    old = np.zeros((len(co), len(old_groups)))
    for vertex in body.data.vertices:
        for group in vertex.groups:
            old[vertex.index, group.group] = group.weight
    for bone_name in cape_bones:
        body.vertex_groups.new(name=bone_name)
    lower = np.clip(((.88 if mode == "--anchored" else 1.12) - co[:, 2]) / (.45 if mode == "--anchored" else .55), 0, 1)
    array = np.column_stack((old * (1 - mask[:, None]), mask * (1 - lower), mask * lower))
    support = np.argpartition(array, -4, axis=1)[:, -4:]
    limited = np.zeros_like(array)
    np.put_along_axis(limited, support, np.take_along_axis(array, support, axis=1), axis=1)
    limited /= limited.sum(1, keepdims=True)
    assert np.isfinite(limited).all() and np.allclose(limited.sum(1), 1)
    assert np.allclose(limited[mask == 0, :len(old_groups)], old[mask == 0])
    for group in body.vertex_groups:
        group.remove(list(range(len(co))))
    for vertex, row in enumerate(limited):
        for index in np.flatnonzero(row > 1e-6):
            body.vertex_groups[index].add([vertex], float(row[index]), "REPLACE")

    expected_cape = {}
    for action in list(bpy.data.actions):
        arm.animation_data.action = action
        for bone_name in cape_bones:
            arm.pose.bones[bone_name].matrix_basis = Matrix.Identity(4)
        first, last = (int(value) for value in action.frame_range)
        for frame in range(first, last + 1):
            scene.frame_set(frame)
            chest = arm.pose.bones["UpperChest"]
            rotation = chest.matrix.to_quaternion() @ chest.bone.matrix_local.to_quaternion().inverted()
            phase = 2 * math.pi * (frame - first) / max(last - first, 1)
            for index, bone_name in enumerate(cape_bones):
                bone = arm.pose.bones[bone_name]
                bone.rotation_mode = "QUATERNION"
                # Baked gravity follow, not a cloth simulation. The lower section follows less.
                follow = .20 if index == 0 else .06
                flutter = 0 if action.name == "death" else math.radians(2) * math.sin(phase) * (index + 1)
                target = Quaternion().slerp(rotation, follow) @ Quaternion((1, 0, 0), flutter)
                desired = (target @ bone.bone.matrix_local.to_quaternion()).to_matrix().to_4x4()
                desired.translation = bone.head
                bone.matrix = desired
                bpy.context.view_layer.update()
                assert bone.matrix.to_quaternion().rotation_difference(desired.to_quaternion()).angle < 1e-3
                for property_name in ("location", "rotation_quaternion", "scale"):
                    bone.keyframe_insert(property_name, frame=frame)
            expected_cape[action.name, frame] = {bone_name: arm.pose.bones[bone_name].matrix.copy() for bone_name in cape_bones}
        for frame in range(first, last + 1):
            scene.frame_set(frame)
            for bone_name, matrix in expected_cape[action.name, frame].items():
                actual = arm.pose.bones[bone_name].matrix
                assert max(abs(actual[r][c] - matrix[r][c]) for r in range(4) for c in range(4)) < 2e-5
        for frame in (first, (first + last) / 2, last):
            scene.frame_set(int(frame), subframe=frame % 1)
            for bone_name, matrix in originals[action.name, frame].items():
                actual = arm.pose.bones[bone_name].matrix
                assert max(abs(actual[r][c] - matrix[r][c]) for r in range(4) for c in range(4)) < 2e-5
    arm.animation_data.action = bpy.data.actions["idle"]
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), export_format="GLB",
                              export_animations=True, export_animation_mode="ACTIONS")
    (output / "repair.json").write_text(json.dumps({"source": "rig-fitted-weights", "new_bones": list(cape_bones),
        "affected_vertices": int((mask > 0).sum()), "joint_levels": list(levels),
        "original_pose_control": "passed at start, midpoint and endpoint of all six clips",
        "limitation": "Baked gravity follow; no cloth collision or secondary simulation"}, indent=2) + "\n")
    sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", f"chars/{name}/{variant}"]
    runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
    print("CAPE BONES DONE", name, flush=True)

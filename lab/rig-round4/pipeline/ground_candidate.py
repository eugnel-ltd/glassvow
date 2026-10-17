# Bake ground contact into a separate candidate, preserving the source Blender file.
# blender -b source.blend --python-exit-code 1 --python ground_candidate.py -- spec.json
import ast
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

spec_path = Path(sys.argv[sys.argv.index("--") + 1])
spec = json.loads(spec_path.read_text())
source = Path(__file__).with_name("char_rig.py")
module = ast.parse(source.read_text(), filename=str(source))
assert isinstance(module.body[-1], ast.Expr)
assert isinstance(module.body[-1].value, ast.Call)
assert module.body[-1].value.func.id == "main"
module.body.pop()
helpers = {"__file__": str(source)}
exec(compile(module, str(source), "exec"), helpers)
out = Path(spec["out_dir"])
out.mkdir(parents=True, exist_ok=True)
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
hips = arm.pose.bones["Hips"]
scene = bpy.context.scene
clips = [bpy.data.actions[name] for name in ("idle", "walk", "attack", "cast", "hurt", "death")]
reports = []
# Apply the export influence limit before measuring the deformed surface.
helpers["only"]([body])
bpy.ops.object.vertex_group_limit_total(limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)


def minimum_z():
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    try:
        return min((evaluated.matrix_world @ vertex.co).z for vertex in mesh.vertices)
    finally:
        evaluated.to_mesh_clear()


for change in spec.get("pose_overrides", []):
    arm.animation_data.action = bpy.data.actions[change["clip"]]
    scene.frame_set(change["frame"])
    for name, degrees in change["bones"].items():
        bone = arm.pose.bones[name]
        rotations = [(axis, angle) for axis, angle in zip((helpers["X"], helpers["Y"], helpers["Z"]), degrees)]
        bone.rotation_quaternion = helpers["q"](bone, helpers["fwd"](bone, rotations))
        bone.keyframe_insert("rotation_quaternion", frame=change["frame"])

contact_clips = spec.get("ground_clips", [action.name for action in clips])
assert contact_clips and len(contact_clips) == len(set(contact_clips))
assert set(contact_clips) <= {action.name for action in clips}
for action in clips:
    if action.name not in contact_clips:
        continue
    arm.animation_data.action = action
    first, last = (int(value) for value in action.frame_range)
    samples = []
    for quarter in range(first * 4, last * 4 + 1):
        frame = quarter / 4
        scene.frame_set(quarter // 4, subframe=(quarter % 4) / 4)
        samples.append((frame, hips.location.copy(), minimum_z()))
    local_up = (arm.matrix_world.to_3x3() @ hips.bone.matrix_local.to_3x3()).inverted() @ Vector((0, 0, 1))
    clearance = float(spec.get("ground_clearance", 0.002))
    for frame, location, height in samples:
        hips.location = location + local_up * (clearance - height)
        hips.keyframe_insert("location", frame=frame)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    if curve.data_path == hips.path_from_id("location"):
                        for key in curve.keyframe_points:
                            key.interpolation = "LINEAR"
    heights = []
    for eighth in range(first * 8, last * 8 + 1):
        scene.frame_set(eighth // 8, subframe=(eighth % 8) / 8)
        heights.append(minimum_z())
    report = {"clip": action.name, "before_min_z": min(row[2] for row in samples),
              "after_min_z": min(heights), "after_max_z": max(heights), "samples": len(heights)}
    reports.append(report)
    print("CONTACT", json.dumps(report), flush=True)
    assert min(heights) >= -0.005, report
    assert max(heights) <= 0.015, report

(out / "contact.json").write_text(json.dumps(reports, indent=2) + "\n")
# Export sampling uses integer frames: scale all keys and FPS by the same factor.
factor = 4
for action in clips:
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.co.x *= factor
                        key.handle_left.x *= factor
                        key.handle_right.x *= factor
    if action.use_frame_range:
        action.frame_start *= factor
        action.frame_end *= factor
scene.render.fps *= factor
arm.animation_data.action = clips[0]
scene.frame_set(int(clips[0].frame_range[0]))
bpy.ops.wm.save_as_mainfile(filepath=str(out / (spec["name"] + ".blend")))
bpy.ops.export_scene.gltf(filepath=str(out / (spec["name"] + ".glb")), export_format="GLB",
                          export_animations=True, export_animation_mode="ACTIONS")
if spec.get("render_inspection", True):
    # Research rigs can omit lights; add the established inspection stage when needed.
    if not any(obj.type == "LIGHT" for obj in scene.objects):
        saved_fps = scene.render.fps
        helpers["stage"]()
        scene.render.fps = saved_fps
    # Include props and every sampled pose in the shared camera framing.
    views = ((2.2, -3.2, 0.42), (4, 0, 0.05))
    for action in clips:
        points = helpers["pose_bounds"](arm, action, meshes)
        first, last = action.frame_range
        paths = []
        for view_index, direction in enumerate(views):
            helpers["frame_camera"](points, direction)
            for index in range(8):
                scene.frame_set(round(first + (last - first) * index / 7))
                paths.append(helpers["shot"](str(out / f"_{action.name}-{view_index}-{index}.png")))
        helpers["sheet"](paths, 8, str(out / f"clip-{action.name}.png"))
    arm.animation_data.action = clips[0]
    scene.frame_set(int(clips[0].frame_range[0]))
    graph = bpy.context.evaluated_depsgraph_get()
    points = [obj.evaluated_get(graph).matrix_world @ Vector(corner)
              for obj in meshes for corner in obj.evaluated_get(graph).bound_box]
    paths = []
    for index, direction in enumerate(((0, -1, .1), (1, 0, .1), (0, 1, .1), (-1, 0, .1))):
        helpers["frame_camera"](points, direction)
        paths.append(helpers["shot"](str(out / f"_view-{index}.png")))
    helpers["sheet"](paths, 4, str(out / "views.png"))
print("CONTACT DONE", str(out), "inspection renders", spec.get("render_inspection", True), flush=True)

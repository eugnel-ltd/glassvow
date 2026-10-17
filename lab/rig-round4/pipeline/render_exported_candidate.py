# Blender: inspect an exported GLB with measured, uncropped camera projections.
# render_exported_candidate.py -- candidate spec.json [--worst|--death]
import ast
import json
import os
from pathlib import Path
import sys
import shutil

import bpy
from bpy_extras.object_utils import world_to_camera_view

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
args = sys.argv[sys.argv.index("--") + 1:]
assert len(args) in (2, 3) and (len(args) == 2 or args[2] in ("--worst", "--death"))
parts = args[0].split("/")
assert len(parts) == 3 and parts[0] in ("chars", "mobs")
assert all(part and part.replace("-", "").isalnum() for part in parts)
folder = lane.joinpath(*parts)
name = parts[1]
output = folder / ("exported-death" if args[-1] == "--death" else "exported-worst" if len(args) == 3 else "exported-views")
assert not output.exists(), "Preserve existing inspection images"
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
source = pipeline / "char_rig.py"
module = ast.parse(source.read_text(), filename=str(source))
assert module.body[-1].value.func.id == "main"
module.body.pop()
sys.argv = [str(source), "--", args[1]]
helpers = {"__file__": str(source)}
exec(compile(module, str(source), "exec"), helpers)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(folder / f"{name}.glb"), merge_vertices=True)
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
shapes = {bone.custom_shape for bone in arm.pose.bones if bone.custom_shape}
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj not in shapes]
assert meshes
helpers["stage"]()
scene = bpy.context.scene
# Preserve the importer's time base when framing the exported actions.
output.mkdir()


def points_at(action, frame):
    arm.animation_data_create()
    arm.animation_data.action = action
    scene.frame_set(int(frame), subframe=frame % 1)
    graph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in meshes:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        try:
            points.extend(evaluated.matrix_world @ vertex.co for vertex in mesh.vertices)
        finally:
            evaluated.to_mesh_clear()
    assert points
    return points


proof = []


def fit_camera(points, direction):
    helpers["frame_camera"](points, direction)
    bpy.context.view_layer.update()
    camera = scene.camera
    for _ in range(3):
        uv = [world_to_camera_view(scene, camera, point) for point in points]
        factor = max(max(abs(point.x - .5), abs(point.y - .5)) / .44 for point in uv)
        if factor <= 1.00001:
            break
        camera.data.ortho_scale *= factor * 1.01
        bpy.context.view_layer.update()
    uv = [world_to_camera_view(scene, camera, point) for point in points]
    bounds = [min(point.x for point in uv), min(point.y for point in uv),
              max(point.x for point in uv), max(point.y for point in uv)]
    assert bounds[0] >= .05 and bounds[1] >= .05 and bounds[2] <= .95 and bounds[3] <= .95, bounds
    assert min(point.z for point in uv) > 0
    return bounds


if args[-1] == "--death":
    action = bpy.data.actions["death"]
    scene.render.fps = 24
    first, last = action.frame_range
    all_points = [point for frame in (first, (first + last) / 2, last) for point in points_at(action, frame)]
    for index, direction in enumerate(((1, 0, .1), (1, 1, .1))):
        bounds = fit_camera(all_points, direction)
        for sample, frame in enumerate((first, (first + last) / 2, last)):
            points_at(action, frame)
            path = output / f"death-{index}-{sample}.png"
            helpers["shot"](str(path))
            proof.append({"file": path.name, "clip": "death", "frame": frame, "projected_bounds": bounds})
elif len(args) == 3:
    reports = json.loads((folder / "reimport-deformation.json").read_text())
    for report in reports:
        if not report["max_stretched_edges"]:
            continue
        action = bpy.data.actions[report["clip"]]
        # The deformation report was recorded at the factory import's 24 FPS.
        scene.render.fps = 24
        frame = report["worst_frame"]
        points = points_at(action, frame)
        for index, direction in enumerate(((2.2, -3.2, .42), (2.2, 3.2, .42))):
            bounds = fit_camera(points, direction)
            path = output / f"{action.name}-{index}.png"
            helpers["shot"](str(path))
            proof.append({"file": path.name, "clip": action.name, "frame": frame, "projected_bounds": bounds})
else:
    action = bpy.data.actions["idle"]
    points = points_at(action, action.frame_range[0])
    for index, direction in enumerate(((0, -1, .1), (1, 0, .1), (0, 1, .1), (-1, 0, .1))):
        bounds = fit_camera(points, direction)
        path = output / f"view-{index}.png"
        helpers["shot"](str(path))
        proof.append({"file": path.name, "clip": "idle", "projected_bounds": bounds})
(output / "projection.json").write_text(json.dumps(proof, indent=2) + "\n")
print("EXPORTED PROJECTION PASS", args[0], len(proof), flush=True)

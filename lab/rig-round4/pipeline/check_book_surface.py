# Blender: verify the exported book against the evaluated hand triangles.
import ast
import json
import os
from pathlib import Path
import shutil
import sys

import bpy
from mathutils.bvhtree import BVHTree

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["rig-grip-contact"]
assert len(args) == 1 and args[0] in ("rig-grip-contact", "rig-hold-contact")
folder = lane / "mobs/uncrossedSelf" / args[0]
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(folder / "uncrossedSelf.glb"), merge_vertices=True)
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
book = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.parent_bone == "LeftHand")
group = body.vertex_groups["LeftHand"].index
indices = {vertex.index for vertex in body.data.vertices
           if any(weight.group == group and weight.weight > .5 for weight in vertex.groups)}
faces = [tuple(polygon.vertices) for polygon in body.data.polygons if set(polygon.vertices) <= indices]
assert len(faces) >= 10


def gap():
    graph = bpy.context.evaluated_depsgraph_get()
    evaluated = body.evaluated_get(graph)
    mesh = evaluated.to_mesh()
    try:
        points = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
        tree = BVHTree.FromPolygons(points, faces)
        # Include book face centres as well as corners; a vertex-only test can miss a palm contact.
        samples = [vertex.co for vertex in book.data.vertices] + [face.center for face in book.data.polygons]
        return min(tree.find_nearest(book.matrix_world @ point)[3] for point in samples)
    finally:
        evaluated.to_mesh_clear()


reports = []
for action in bpy.data.actions:
    arm.animation_data_create()
    arm.animation_data.action = action
    first, last = action.frame_range
    distances = []
    for sample in range(33):
        frame = first + (last - first) * sample / 32
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        distances.append(gap())
    assert max(distances) < .01, (action.name, max(distances))
    reports.append({"clip": action.name, "samples": len(distances),
                    "min_distance_metres": min(distances), "max_distance_metres": max(distances)})
assert len(reports) == 6
original = book.matrix_world.copy()
shifted = original.copy()
shifted.translation.x += 1
book.matrix_world = shifted
bpy.context.view_layer.update()
assert gap() > .5, "Detached book control did not fail the contact threshold"
book.matrix_world = original
(folder / "grip-reimport.json").write_text(json.dumps(reports, indent=2) + "\n")
print("EXPORTED BOOK SURFACE PASS", json.dumps(reports), "detached control rejected", flush=True)
# Render one front and one oblique view of the exported grip at the attack midpoint.
settings = folder / "render.json"
source = pipeline / "char_rig.py"
module = ast.parse(source.read_text(), filename=str(source))
assert module.body[-1].value.func.id == "main"
module.body.pop()
sys.argv = [str(source), "--", str(settings)]
helpers = {"__file__": str(source)}
exec(compile(module, str(source), "exec"), helpers)
helpers["stage"]()
arm.animation_data.action = bpy.data.actions["attack"]
first, last = arm.animation_data.action.frame_range
bpy.context.scene.frame_set(round((first + last) / 2))
# The hand-only bounds would crop the book. Frame both using the evaluated hand and book points.
graph = bpy.context.evaluated_depsgraph_get()
evaluated = body.evaluated_get(graph)
mesh = evaluated.to_mesh()
points = [evaluated.matrix_world @ mesh.vertices[index].co for index in indices]
evaluated.to_mesh_clear()
points += [book.matrix_world @ vertex.co for vertex in book.data.vertices]
for index, direction in enumerate(((0, -1, .05), (1, -1, .1))):
    helpers["frame_camera"](points, direction)
    helpers["shot"](str(folder / f"grip-close-{index}.png"))

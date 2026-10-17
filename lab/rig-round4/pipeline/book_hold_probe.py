# Blender: compare two book placements around the open palm without changing the source.
import ast
import json
import os
from pathlib import Path
import sys
import shutil

import bpy
from mathutils import Vector

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
folder = lane / "mobs/uncrossedSelf/rig-grip-contact"
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
bpy.ops.wm.open_mainfile(filepath=str(folder / "uncrossedSelf.blend"))
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
book = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.parent_bone == "LeftHand")
source = pipeline / "char_rig.py"
module = ast.parse(source.read_text(), filename=str(source))
module.body.pop()
sys.argv = [str(source), "--", str(folder / "render.json")]
helpers = {"__file__": str(source)}
exec(compile(module, str(source), "exec"), helpers)
arm.animation_data.action = bpy.data.actions["idle"]
bpy.context.scene.frame_set(int(arm.animation_data.action.frame_range[0]))
original = book.matrix_world.copy()
group = body.vertex_groups["LeftHand"].index
graph = bpy.context.evaluated_depsgraph_get()
evaluated = body.evaluated_get(graph)
mesh = evaluated.to_mesh()
points = [evaluated.matrix_world @ mesh.vertices[vertex.index].co for vertex in body.data.vertices
          if any(weight.group == group and weight.weight > .5 for weight in vertex.groups)]
evaluated.to_mesh_clear()
print("HOLD HAND BOUNDS", [min(point[i] for point in points) for i in range(3)],
      [max(point[i] for point in points) for i in range(3)], flush=True)
print("HOLD BOOK BOUNDS", [min((book.matrix_world @ vertex.co)[i] for vertex in book.data.vertices) for i in range(3)],
      [max((book.matrix_world @ vertex.co)[i] for vertex in book.data.vertices) for i in range(3)], flush=True)
for label, shift in (("palm", (-.035, .018, .025)), ("palm-deep", (-.055, .025, .035))):
    matrix = original.copy()
    matrix.translation += Vector(shift)
    book.matrix_world = matrix
    bpy.context.view_layer.update()
    bounds = points + [book.matrix_world @ vertex.co for vertex in book.data.vertices]
    for index, direction in enumerate(((0, -1, .05), (1, -1, .1))):
        helpers["frame_camera"](bounds, direction)
        path = folder / f"hold-{label}-{index}.png"
        assert not path.exists()
        helpers["shot"](str(path))

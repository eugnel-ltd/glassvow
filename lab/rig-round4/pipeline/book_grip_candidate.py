# Blender: repair the book grip using the evaluated hand surface, preserving the source.
import ast
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy
from mathutils import kdtree

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
folder = lane / "mobs/uncrossedSelf"
output = folder / "rig-grip-contact"
assert not output.exists(), "Preserve an existing candidate"
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
bpy.ops.wm.open_mainfile(filepath=str(folder / "rig-smooth-contact/uncrossedSelf.blend"))
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
book = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.parent_bone == "LeftHand")
group = body.vertex_groups["LeftHand"].index
hand_vertices = [vertex.index for vertex in body.data.vertices
                 if any(weight.group == group and weight.weight > .5 for weight in vertex.groups)]
assert len(hand_vertices) > 10
scene = bpy.context.scene
arm.animation_data.action = bpy.data.actions["idle"]
scene.frame_set(int(arm.animation_data.action.frame_range[0]))


def nearest_contact():
    graph = bpy.context.evaluated_depsgraph_get()
    evaluated = body.evaluated_get(graph)
    mesh = evaluated.to_mesh()
    try:
        tree = kdtree.KDTree(len(hand_vertices))
        for index in hand_vertices:
            tree.insert(evaluated.matrix_world @ mesh.vertices[index].co, index)
        tree.balance()
        points = [book.matrix_world @ vertex.co for vertex in book.data.vertices]
        point = min(points, key=lambda value: tree.find(value)[2])
        hand_point, _, distance = tree.find(point)
        return hand_point - point, float(distance)
    finally:
        evaluated.to_mesh_clear()


shift, before = nearest_contact()
assert .001 < before < .08, ("Unexpected initial grip", before)
# Seat the nearest book surface 3 mm inside the hand surface; inspect the whole grip after export.
shift += shift.normalized() * .003
matrix = book.matrix_world.copy()
matrix.translation += shift
book.matrix_world = matrix
bpy.context.view_layer.update()
_, after = nearest_contact()
assert after < before and after < .008, (before, after)
output.mkdir()
report = {"source": "rig-smooth-contact", "hand_vertices": len(hand_vertices),
          "before_gap_metres": before, "after_gap_metres": after,
          "world_shift_metres": list(shift), "clips": []}
for name in ("idle", "walk", "attack", "cast", "hurt", "death"):
    action = bpy.data.actions[name]
    arm.animation_data.action = action
    first, last = action.frame_range
    gaps = []
    for sample in range(9):
        scene.frame_set(round(first + (last - first) * sample / 8))
        gaps.append(nearest_contact()[1])
    report["clips"].append({"clip": name, "min_gap_metres": min(gaps), "max_gap_metres": max(gaps)})
    assert max(gaps) < .015, (name, gaps)
(output / "grip.json").write_text(json.dumps(report, indent=2) + "\n")
arm.animation_data.action = bpy.data.actions["idle"]
scene.frame_set(int(arm.animation_data.action.frame_range[0]))
bpy.ops.wm.save_as_mainfile(filepath=str(output / "uncrossedSelf.blend"))
bpy.ops.export_scene.gltf(filepath=str(output / "uncrossedSelf.glb"), export_format="GLB",
                          export_animations=True, export_animation_mode="ACTIONS")
# Reuse the established cameras and sheet writer, with an explicit new output path.
settings = json.loads((folder / "smooth-contact.json").read_text())
settings["out_dir"] = str(output)
spec = output / "render.json"
spec.write_text(json.dumps(settings, indent=2) + "\n")
source = pipeline / "char_rig.py"
module = ast.parse(source.read_text(), filename=str(source))
module.body.pop()
sys.argv = [str(source), "--", str(spec)]
helpers = {"__file__": str(source)}
exec(compile(module, str(source), "exec"), helpers)
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
for name in ("idle", "walk", "attack", "cast", "hurt", "death"):
    action = bpy.data.actions[name]
    points = helpers["pose_bounds"](arm, action, meshes)
    first, last = action.frame_range
    paths = []
    for view, direction in enumerate(((2.2, -3.2, .42), (4, 0, .05))):
        helpers["frame_camera"](points, direction)
        for sample in range(8):
            scene.frame_set(round(first + (last - first) * sample / 7))
            paths.append(helpers["shot"](str(output / f"_grip-{name}-{view}-{sample}.png")))
    helpers["sheet"](paths, 8, str(output / f"clip-{name}.png"))
sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", "mobs/uncrossedSelf/rig-grip-contact"]
runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
print("BOOK GRIP PASS", json.dumps(report), flush=True)

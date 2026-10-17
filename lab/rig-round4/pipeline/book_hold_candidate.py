# Blender: save the inspected shallow palm placement as a separate candidate.
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy
from mathutils import Vector

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
folder = lane / "mobs/uncrossedSelf"
output = folder / "rig-hold-contact"
assert not output.exists(), "Preserve an existing candidate"
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
bpy.ops.wm.open_mainfile(filepath=str(folder / "rig-grip-contact/uncrossedSelf.blend"))
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
book = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.parent_bone == "LeftHand")
arm.animation_data.action = bpy.data.actions["idle"]
bpy.context.scene.frame_set(int(arm.animation_data.action.frame_range[0]))
shift = Vector((-.035, .018, .025))
matrix = book.matrix_world.copy()
matrix.translation += shift
book.matrix_world = matrix
bpy.context.view_layer.update()
output.mkdir()
settings = json.loads((folder / "rig-grip-contact/render.json").read_text())
settings["out_dir"] = str(output)
(output / "render.json").write_text(json.dumps(settings, indent=2) + "\n")
(output / "repair.json").write_text(json.dumps({"source": "rig-grip-contact", "world_shift_metres": list(shift),
                                                "selection": "Inspected shallow palm placement"}, indent=2) + "\n")
bpy.ops.wm.save_as_mainfile(filepath=str(output / "uncrossedSelf.blend"))
bpy.ops.export_scene.gltf(filepath=str(output / "uncrossedSelf.glb"), export_format="GLB",
                          export_animations=True, export_animation_mode="ACTIONS")
sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", "mobs/uncrossedSelf/rig-hold-contact"]
runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
report = json.loads((output / "reimport-deformation.json").read_text())
assert all(row["max_stretched_edges"] == 0 and row["min_z"] >= -.005 and row["max_min_z"] <= .015 for row in report)
print("PALM PLACEMENT EXPORT PASS", flush=True)

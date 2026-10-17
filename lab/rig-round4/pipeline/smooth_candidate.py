# Blender: save a measured smoothing variant from the original Blender candidate.
# smooth_candidate.py -- name repeats [name repeats ...]
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
smooth = runpy.run_path(str(pipeline / "smooth_probe.py"))["smooth_weights"]
args = sys.argv[sys.argv.index("--") + 1:]
assert args and len(args) % 2 == 0
for name, repeat in zip(args[::2], args[1::2]):
    assert name.isalnum() and 0 < int(repeat) <= 30
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    folder = lane / "mobs" / name
    source = folder / "rig" / f"{name}.blend"
    output = folder / "rig-smooth"
    assert not output.exists(), "Preserve an existing repair candidate"
    bpy.ops.wm.open_mainfile(filepath=str(source))
    arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
    smooth(body, int(repeat))
    output.mkdir()
    arm.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), export_format="GLB",
                              export_animations=True, export_animation_mode="ACTIONS")
    (output / "repair.json").write_text(json.dumps({"source": str(source), "smoothing_passes": int(repeat)}, indent=2) + "\n")
    sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", f"mobs/{name}/rig-smooth"]
    runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
    report = json.loads((output / "reimport-deformation.json").read_text())
    assert all(row["max_stretched_edges"] == 0 for row in report), report
    print("SMOOTH EXPORT PASS", name, repeat, flush=True)

# Blender: compare local cape weighting on the measured-centre hero candidates.
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
rear = runpy.run_path(str(pipeline / "rear_garment_probe.py"))["rear_garment"]
smooth = runpy.run_path(str(pipeline / "smooth_probe.py"))["smooth_weights"]
results = []
for name in ("duskblade", "ashwarden"):
    for passes in (0, 12):
        assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
        bpy.ops.wm.open_mainfile(filepath=str(lane / "chars" / name / "rig-centred" / f"{name}.blend"))
        arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
        body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
        rear(body, .20)
        smooth(body, passes)
        report = pipeline / f"{name}-centred-cloth-{passes}.json"
        assert not report.exists(), "Preserve a previous experiment"
        sys.argv = [str(pipeline / "check_deformation.py"), "--", str(report)]
        runpy.run_path(str(pipeline / "check_deformation.py"), run_name="__main__")
        clips = json.loads(report.read_text())
        row = {"name": name, "passes": passes,
               "stretch": {clip["clip"]: clip["max_stretched_edges"] for clip in clips}}
        results.append(row)
        print("CLOTH RESULT", json.dumps(row), flush=True)
(pipeline / "hero-cloth-results.json").write_text(json.dumps(results, indent=2) + "\n")

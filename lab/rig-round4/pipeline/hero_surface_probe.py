# Blender: compare the existing surface-distance weighting fallback on four hero rigs.
import ast
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
source = pipeline / "char_rig.py"
module = ast.parse(source.read_text(), filename=str(source))
assert module.body[-1].value.func.id == "main"
module.body.pop()
results = []
for name in ("duskblade", "ashwarden"):
    for variant in ("rig", "rig-centred"):
        assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
        spec = lane / "chars" / name / ("rig.json" if variant == "rig" else "centred.json")
        sys.argv = [str(source), "--", str(spec)]
        helpers = {"__file__": str(source)}
        exec(compile(module, str(source), "exec"), helpers)
        bpy.ops.wm.open_mainfile(filepath=str(lane / "chars" / name / variant / f"{name}.blend"))
        arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
        body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
        helpers["geodesic_weights"](body, arm, margin=.036, blend=30)
        helpers["only"]([body])
        bpy.ops.object.vertex_group_limit_total(limit=4)
        bpy.ops.object.vertex_group_normalize_all(lock_active=False)
        report = pipeline / f"{name}-{variant}-surface.json"
        assert not report.exists(), "Preserve a previous experiment"
        sys.argv = [str(pipeline / "check_deformation.py"), "--", str(report)]
        runpy.run_path(str(pipeline / "check_deformation.py"), run_name="__main__")
        clips = json.loads(report.read_text())
        row = {"name": name, "source": variant,
               "stretch": {clip["clip"]: clip["max_stretched_edges"] for clip in clips}}
        results.append(row)
        if all(clip["max_stretched_edges"] == 0 for clip in clips):
            output = lane / "chars" / name / f"{variant}-surface"
            assert not output.exists()
            output.mkdir()
            arm.animation_data.action = bpy.data.actions["idle"]
            bpy.context.scene.frame_set(1)
            bpy.ops.wm.save_as_mainfile(filepath=str(output / f"{name}.blend"))
            bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), export_format="GLB",
                                      export_animations=True, export_animation_mode="ACTIONS")
        print("SURFACE RESULT", json.dumps(row), flush=True)
(pipeline / "hero-surface-results.json").write_text(json.dumps(results, indent=2) + "\n")

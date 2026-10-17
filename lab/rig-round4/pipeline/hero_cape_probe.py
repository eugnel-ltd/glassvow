# Blender: compare a shoulder-supported cape with the existing surface-weighted solution.
import ast
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy
import numpy as np

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
source = pipeline / "char_rig.py"
module = ast.parse(source.read_text(), filename=str(source))
assert module.body[-1].value.func.id == "main"
module.body.pop()
smooth = runpy.run_path(str(pipeline / "smooth_probe.py"))["smooth_weights"]
results = []
for name in ("duskblade", "ashwarden"):
    for support in ("surface", "shoulders"):
        assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
        folder = lane / "chars" / name
        sys.argv = [str(source), "--", str(folder / "centred.json")]
        helpers = {"__file__": str(source)}
        exec(compile(module, str(source), "exec"), helpers)
        bpy.ops.wm.open_mainfile(filepath=str(folder / "rig-centred" / f"{name}.blend"))
        arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
        body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
        helpers["geodesic_weights"](body, arm, margin=.036, blend=30)
        if support == "shoulders":
            co = helpers["world_co"](body)
            # The cape hangs from the shoulders. A graded boundary avoids a weight step at its seam.
            blend = np.clip((co[:, 1] - (.20 - .19 * co[:, 2])) / .06, 0, 1)
            blend *= np.clip((1.52 - co[:, 2]) / .12, 0, 1)
            blend = blend * blend * (3 - 2 * blend)
            chest = body.vertex_groups["UpperChest"]
            for vertex, factor in zip(body.data.vertices, blend):
                if factor <= 0:
                    continue
                weights = {weight.group: weight.weight * (1 - factor) for weight in vertex.groups}
                weights[chest.index] = weights.get(chest.index, 0) + factor
                for group, value in weights.items():
                    body.vertex_groups[group].add([vertex.index], float(value), "REPLACE")
        smooth(body, 30)
        report = pipeline / f"{name}-cape-{support}.json"
        assert not report.exists()
        sys.argv = [str(pipeline / "check_deformation.py"), "--", str(report)]
        runpy.run_path(str(pipeline / "check_deformation.py"), run_name="__main__")
        clips = json.loads(report.read_text())
        row = {"name": name, "support": support,
               "stretch": {clip["clip"]: clip["max_stretched_edges"] for clip in clips}}
        results.append(row)
        output = folder / f"rig-cape-{support}"
        assert not output.exists()
        output.mkdir()
        arm.animation_data.action = bpy.data.actions["idle"]
        bpy.context.scene.frame_set(1)
        bpy.ops.wm.save_as_mainfile(filepath=str(output / f"{name}.blend"))
        bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), export_format="GLB",
                                  export_animations=True, export_animation_mode="ACTIONS")
        print("CAPE RESULT", json.dumps(row), flush=True)
(pipeline / "hero-cape-results.json").write_text(json.dumps(results, indent=2) + "\n")

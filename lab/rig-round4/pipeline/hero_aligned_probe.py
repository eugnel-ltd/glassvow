# Blender: align limb roots with the measured torso before comparing two weighting methods.
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
    for method in ("heat", "surface"):
        assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
        folder = lane / "chars" / name
        output = folder / f"rig-aligned-{method}"
        assert not output.exists(), "Preserve an existing experiment"
        settings = json.loads((folder / "centred.json").read_text())
        settings["out_dir"] = str(output)
        spec_path = folder / f"aligned-{method}.json"
        assert not spec_path.exists()
        spec_path.write_text(json.dumps(settings, indent=2) + "\n")
        sys.argv = [str(source), "--", str(spec_path)]
        helpers = {"__file__": str(source)}
        exec(compile(module, str(source), "exec"), helpers)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        body = helpers["import_glb"](settings["body_glb"])
        body.name = name
        helpers["fit"](body, settings["height"])
        vertices = helpers["verts"](body)
        joints = helpers["landmarks"](vertices, settings["joints"])
        for side in ("Left", "Right"):
            for suffix in ("ShoulderRoot", "UpperArm"):
                joints[side + suffix].y = joints["UpperChest"].y
            joints[side + "LowerArm"] = joints[side + "UpperArm"].lerp(joints[side + "Hand"], .5) + helpers["Vector"]((0, .018, 0))
            joints[side + "UpperLeg"].y = joints["Hips"].y
            joints[side + "LowerLeg"] = joints[side + "UpperLeg"].lerp(joints[side + "Foot"], .5) + helpers["Vector"]((0, -.0216, 0))
        assert all(abs(joints[side + "ShoulderRoot"].y - joints["UpperChest"].y) < 1e-6
                   and abs(joints[side + "UpperLeg"].y - joints["Hips"].y) < 1e-6 for side in ("Left", "Right"))
        settings["joints"] = {key: list(value) for key, value in joints.items()}
        spec_path.write_text(json.dumps(settings, indent=2) + "\n")
        helpers["spec"]["joints"] = settings["joints"]
        arm = helpers["build_armature"](joints, helpers["CHAIN"])
        helpers["skin"](body, arm)
        if method == "surface":
            helpers["geodesic_weights"](body, arm, margin=.036, blend=30)
        helpers["attach_prop"](arm, joints)
        helpers["only"]([body])
        bpy.ops.object.vertex_group_limit_total(limit=4)
        bpy.ops.object.vertex_group_normalize_all(lock_active=False)
        actions = helpers["clips"](arm)
        bpy.context.scene.render.fps = 30
        arm.animation_data.action = actions[0]
        bpy.context.scene.frame_set(1)
        bpy.ops.wm.save_as_mainfile(filepath=str(output / f"{name}.blend"))
        bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), export_format="GLB",
                                  export_animations=True, export_animation_mode="ACTIONS")
        sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", f"chars/{name}/rig-aligned-{method}"]
        runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
        clips = json.loads((output / "reimport-deformation.json").read_text())
        row = {"name": name, "method": method,
               "stretch": {clip["clip"]: clip["max_stretched_edges"] for clip in clips}}
        results.append(row)
        print("ALIGNED RESULT", json.dumps(row), flush=True)
(pipeline / "hero-aligned-results.json").write_text(json.dumps(results, indent=2) + "\n")

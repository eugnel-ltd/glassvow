# Blender: compare measured torso centres while preserving the original candidates.
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
assert isinstance(module.body[-1], ast.Expr) and module.body[-1].value.func.id == "main"
module.body.pop()
for name in ("duskblade", "ashwarden"):
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    folder = lane / "chars" / name
    output = folder / "rig-centred"
    assert not output.exists(), "Preserve an existing candidate"
    settings = json.loads((folder / "rig.json").read_text())
    settings["out_dir"] = str(output)
    spec_path = folder / "centred.json"
    assert not spec_path.exists()
    spec_path.write_text(json.dumps(settings, indent=2) + "\n")
    sys.argv = [str(source), "--", str(spec_path)]
    helpers = {"__file__": str(source)}
    exec(compile(module, str(source), "exec"), helpers)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = helpers["import_glb"](settings["body_glb"])
    body.name = name
    helpers["fit"](body, 1.8)
    vertices = helpers["verts"](body)
    joints = helpers["landmarks"](vertices, {})
    measured = {}
    for joint in ("Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "HeadTop"):
        height = joints[joint].z
        slab = vertices[(np.abs(vertices[:, 0]) < .10) & (np.abs(vertices[:, 2] - height) < .035)]
        near, far = np.percentile(slab[:, 1], (5, 95))
        measured[joint] = [0, float((near + far) / 2), height]
    helpers["spec"]["joints"] = measured
    settings["joints"] = measured
    spec_path.write_text(json.dumps(settings, indent=2) + "\n")
    joints = helpers["landmarks"](vertices, measured)
    arm = helpers["build_armature"](joints, helpers["CHAIN"])
    helpers["skin"](body, arm)
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
    sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", f"chars/{name}/rig-centred"]
    runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
    print("CENTRED EXPORT", name, json.dumps(measured), flush=True)

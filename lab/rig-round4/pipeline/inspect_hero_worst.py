# Blender: diagnose and render the worst poses of the two best cape experiments.
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
for name, support in (("duskblade", "shoulders"), ("ashwarden", "surface")):
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    folder = lane / "chars" / name
    bpy.ops.wm.open_mainfile(filepath=str(folder / f"rig-cape-{support}" / f"{name}.blend"))
    sys.argv = [str(source), "--", str(folder / "centred.json")]
    helpers = {"__file__": str(source)}
    exec(compile(module, str(source), "exec"), helpers)
    helpers["stage"]()
    reports = json.loads((pipeline / f"{name}-cape-{support}.json").read_text())
    for clip in ("attack", "death"):
        row = next(row for row in reports if row["clip"] == clip)
        sys.argv = [str(pipeline / "debug_stretch.py"), "--", clip, str(row["worst_frame"])]
        print("WORST", name, clip, row["worst_frame"], flush=True)
        runpy.run_path(str(pipeline / "debug_stretch.py"), run_name="__main__")
        graph = bpy.context.evaluated_depsgraph_get()
        points = [obj.evaluated_get(graph).matrix_world @ helpers["Vector"](corner)
                  for obj in bpy.context.scene.objects if obj.type == "MESH"
                  for corner in obj.evaluated_get(graph).bound_box]
        for index, direction in enumerate(((2.2, -3.2, .42), (2.2, 3.2, .42))):
            helpers["frame_camera"](points, direction)
            path = folder / f"rig-cape-{support}" / f"worst-lit-{clip}-{index}.png"
            assert not path.exists()
            helpers["shot"](str(path))

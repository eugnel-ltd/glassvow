# Blender: ground_batch.py -- source.blend spec.json [source.blend spec.json ...]
# Preserve each source and use a separate output directory for every repair candidate.
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy

pipeline = Path(__file__).resolve().parent
args = sys.argv[sys.argv.index("--") + 1:]
assert args and len(args) % 2 == 0
for source, settings in zip(args[::2], args[1::2]):
    spec = json.loads(Path(settings).read_text())
    output = Path(spec["out_dir"])
    assert Path(source).parent != output, "Preserve the source candidate"
    assert not (output / (spec["name"] + ".glb")).exists(), "Inspect an existing repair before replacing it"
    print("GROUND BATCH", spec["name"], "load", os.getloadavg()[0], flush=True)
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(pipeline).free / 2**30 >= 100
    bpy.ops.wm.open_mainfile(filepath=source)
    assert bpy.context.scene.render.fps == 30, "Use an original 30 FPS candidate"
    sys.argv = [str(pipeline / "ground_candidate.py"), "--", settings]
    runpy.run_path(str(pipeline / "ground_candidate.py"), run_name="__main__")
print("GROUND BATCH DONE", len(args) // 2, flush=True)

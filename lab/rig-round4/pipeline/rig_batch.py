# Run candidate specs sequentially in one Blender process.
# blender -b --factory-startup --python-exit-code 1 --python rig_batch.py -- spec.json ...
import os
from pathlib import Path
import runpy
import shutil
import sys

pipeline = Path(__file__).resolve().parent
specs = sys.argv[sys.argv.index("--") + 1:]
for spec in specs:
    load = os.getloadavg()[0]
    free = shutil.disk_usage(pipeline).free / 2**30
    print("BATCH", spec, "load", load, "free GiB", round(free, 2), flush=True)
    assert load < 50, "Wait for engine load below 50 before resuming this spec"
    assert free >= 100, "Keep 100 GiB free before resuming this spec"
    sys.argv = [str(pipeline / "char_rig.py"), "--", spec]
    runpy.run_path(str(pipeline / "char_rig.py"), run_name="__main__")
print("BATCH DONE", len(specs), flush=True)

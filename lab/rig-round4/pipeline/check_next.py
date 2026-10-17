# Engine-only sequential inspection of the current candidate batch.
# blender -b --factory-startup --python-exit-code 1 --python check_next.py
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy

pipeline = Path(__file__).resolve().parent
root = pipeline.parent
for name, directory in (("mirelurker", "rig-contact-final"), ("tidecaller", "rig"),
                        ("abyssalKnight", "rig"), ("obsidianGolem", "rig")):
    free = shutil.disk_usage(root).free / 2**30
    print("CHECK", name, "load", os.getloadavg()[0], "free GiB", round(free, 2), flush=True)
    assert os.getloadavg()[0] < 50 and free >= 100, "Resource floor reached"
    folder = root / "mobs" / name / directory
    sys.argv = [str(pipeline / "check_deformation.py"), "--", str(folder / "reimport-deformation.json"),
                str(folder / (name + ".glb"))]
    runpy.run_path(str(pipeline / "check_deformation.py"), run_name="__main__")
print("INSPECTION DONE", flush=True)

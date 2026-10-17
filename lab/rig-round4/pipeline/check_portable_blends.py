# Blender: inspect source-file dependencies without modifying any candidate.
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

import bpy

pipeline = Path(__file__).resolve().parent
round2 = sys.argv[-1] == "--round2"
inventory = pipeline / ("current-research-inventory-round2.json" if round2 else "current-research-inventory-cape-floor.json")
rows = json.loads(inventory.read_text())
output = pipeline / ("portable-blends-round2.json" if round2 else "portable-blends-check.json")
assert not output.exists(), "Preserve an existing dependency inspection"
assert len(rows) == 38
reports = []
for row in rows:
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(pipeline).free / 2**30 >= 100
    source = Path(row["glb"]).with_suffix(".blend")
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    images = []
    for image in bpy.data.images:
        if image.source != "FILE":
            continue
        packed = bool(image.packed_file or image.packed_files)
        images.append({"name": image.name, "packed": packed,
                       "path": image.filepath if not packed else None})
    libraries = [library.filepath for library in bpy.data.libraries]
    external = [str(path) for path in bpy.utils.blend_paths(absolute=True, packed=False)]
    report = {"candidate": row["candidate"], "source": str(source),
              "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "bytes": source.stat().st_size, "images": images,
              "libraries": libraries, "external_paths": external}
    reports.append(report)
    print("BLEND DEPENDENCIES", row["candidate"], "images", len(images),
          "unpacked", sum(not image["packed"] for image in images),
          "libraries", len(libraries), "external", len(external), flush=True)
output.write_text(json.dumps({"inventory_sha256": hashlib.sha256(inventory.read_bytes()).hexdigest(),
                              "candidates": reports}, indent=2) + "\n")
assert all(not row["libraries"] and not row["external_paths"]
           and all(image["packed"] for image in row["images"]) for row in reports), "External dependency found; inspect the report before packaging"
print("PORTABLE BLENDS PASS", len(reports), flush=True)

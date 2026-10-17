# Blender: apply the established body contact bake to the remaining research candidates.
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
completed = {"duskblade", "ashwarden", "mirelurker", "tidecaller", "shellback", "uncrossedSelf"}
rows = json.loads((pipeline / "candidate-selection.json").read_text())
assert len(rows) == 38 and len({row["candidate"] for row in rows}) == 38
selected = [row for row in rows if row["candidate"].split("/")[1] not in completed]
assert len(selected) == 32
specs = pipeline / "contact-rollout-specs"
assert not specs.exists(), "Inspect a previous rollout before restarting"
specs.mkdir()
results = []
for row in selected:
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    root, name, variant = row["candidate"].split("/")
    folder = lane / root / name
    source = folder / variant / f"{name}.blend"
    output = folder / "rig-contact-batch"
    assert source.is_file() and not output.exists(), name
    settings = json.loads((folder / "rig.json").read_text())
    hovering = settings.get("motion") in ("float", "swim")
    settings.update(out_dir=str(output), ground_clearance=.002, render_inspection=False)
    settings["ground_clips"] = ["death"] if hovering else ["idle", "walk", "attack", "cast", "hurt", "death"]
    settings.pop("pose_overrides", None)
    spec = specs / f"{name}.json"
    spec.write_text(json.dumps(settings, indent=2) + "\n")
    sys.argv = [str(pipeline / "ground_batch.py"), "--", str(source), str(spec)]
    runpy.run_path(str(pipeline / "ground_batch.py"), run_name="__main__")
    candidate = f"{root}/{name}/rig-contact-batch"
    sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", candidate]
    runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
    report = json.loads((output / "reimport-deformation.json").read_text())
    assert len(report) == 6 and {clip["clip"] for clip in report} == {"idle", "walk", "attack", "cast", "hurt", "death"}
    for clip in report:
        if clip["clip"] in settings["ground_clips"]:
            assert clip["min_z"] >= -.005 and clip["max_min_z"] <= .015, (name, clip)
    results.append({"candidate": candidate, "source": row["candidate"], "ground_clips": settings["ground_clips"],
                    "body_contact": "passed", "deformation": report,
                    "limitations": ["Body minimum height only; no foot locking, prop clearance or visual approval"]})
    (pipeline / "contact-rollout-results.json").write_text(json.dumps(results, indent=2) + "\n")
    print("CONTACT ROLLOUT PASS", len(results), "/", len(selected), name, flush=True)
print("CONTACT ROLLOUT DONE", len(results), flush=True)

# Engine only: verify exported contact candidates, then render continuous Godot previews.
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
candidates = sys.argv[1:]
assert candidates
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
command = ["/Applications/Blender.app/Contents/MacOS/Blender", "-b", "-t", "4", "--factory-startup",
           "--python-exit-code", "1", "--python", str(pipeline / "check_candidate_batch.py"), "--", *candidates]
result = subprocess.run(command, capture_output=True, text=True, timeout=180)
text = result.stdout + result.stderr
(pipeline / "contact-reimport.log").write_text(text)
assert result.returncode == 0, text
paths = []
for candidate in candidates:
    root, name, variant = candidate.split("/")
    folder = lane / root / name / variant
    report = json.loads((folder / "reimport-deformation.json").read_text())
    assert all(row["min_z"] >= -.005 and row["max_min_z"] <= .015 for row in report), report
    assert all(row["max_stretched_edges"] == 0 for row in report), report
    paths.append(str(folder / f"{name}.glb"))
    print("CONTACT REIMPORT PASS", candidate, flush=True)
for label, flags, script in (("contact-godot", ["--headless"], "godot_check.gd"),
                             ("contact-preview", ["--resolution", "640x640", "--position", "1500,60"], "godot_preview.gd")):
    args = paths if script == "godot_check.gd" else [str(pipeline / "godot-preview-contact"), *paths]
    result = subprocess.run(["godot", "--path", str(pipeline / "godot-inspect"), *flags,
                             "--script", str(pipeline / script), "--", *args],
                            capture_output=True, text=True, timeout=180)
    text = result.stdout + result.stderr
    (pipeline / f"{label}.log").write_text(text)
    assert result.returncode == 0 and "SCRIPT ERROR" not in text and "ERROR:" not in text, text
    print(label, text, flush=True)

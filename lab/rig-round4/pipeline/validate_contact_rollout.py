# Engine only: validate and capture the completed contact rollout without replacing prior evidence.
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
rows = json.loads((pipeline / "contact-rollout-results.json").read_text())
assert len(rows) == 32 and len({row["candidate"] for row in rows}) == 32
output = pipeline / "godot-preview-contact-rollout"
assert not output.exists(), "Preserve an existing capture"
paths = []
for row in rows:
    parts = row["candidate"].split("/")
    assert len(parts) == 3 and parts[0] == "mobs" and all(part.replace("-", "").isalnum() for part in parts)
    folder = lane.joinpath(*parts)
    report = json.loads((folder / "reimport-deformation.json").read_text())
    assert all(clip["min_z"] >= -.005 and clip["max_min_z"] <= .015
               for clip in report if clip["clip"] in row["ground_clips"])
    paths.append(str(folder / f"{parts[1]}.glb"))
for label, flags, script, args in (
        ("contact-rollout-godot", ["--headless"], "godot_check.gd", paths),
        ("contact-rollout-preview", ["--resolution", "640x640", "--position", "1500,60"],
         "godot_preview.gd", [str(output), *paths])):
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    result = subprocess.run(["/opt/homebrew/bin/godot", "--path", str(pipeline / "godot-inspect"),
                             *flags, "--script", str(pipeline / script), "--", *args],
                            capture_output=True, text=True, timeout=1200)
    text = result.stdout + result.stderr
    (pipeline / f"{label}.log").write_text(text)
    print(label, text, flush=True)
    assert result.returncode == 0 and "SCRIPT ERROR" not in text and "ERROR:" not in text, text
    if script == "godot_check.gd":
        assert "GD RESULT 32/32 passed" in text
inventory = []
for row, path in zip(rows, paths):
    model = Path(path)
    folder = model.parent
    preview = output / model.stem
    manifest = json.loads((preview / "frames.json").read_text())
    assert len(manifest) == 6 and sum(clip["frames"] for clip in manifest) == 223
    assert len(list(preview.glob("frame-*.png"))) == 223
    inventory.append({**row, "glb": path, "sha256": hashlib.sha256(model.read_bytes()).hexdigest(),
                      "bytes": model.stat().st_size, "structure": json.loads((folder / "structure.json").read_text()),
                      "godot_import_movement_idle_return": "passed", "preview": str(preview),
                      "captured_frames": 223, "approval": "Unapproved research candidate; visual review pending"})
(pipeline / "contact-rollout-inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
print("CONTACT VALIDATION DONE", len(inventory), flush=True)

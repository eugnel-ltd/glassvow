# Engine: run per-character motion-edit trials from one plan file, one character at a time.
#   python3 edit_queue.py <plan.json>
#   plan: {"suffix": "lunge", "characters": {"<name>": {"base": "rig-...", "spec": "round3-<x>.json", "edits": [...]}}}
# Zero-stretch results get the channel compare and a front Godot capture.
import json
from pathlib import Path
import subprocess
import sys

lab = Path("/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab")
pipeline = lab / "pipeline"
plan = json.loads(Path(sys.argv[1]).read_text())
suffix = plan["suffix"]
for name, job in plan["characters"].items():
    root = "mobs" if (lab / "mobs" / name).is_dir() else "chars"
    folder = lab / root / name
    spec = folder / f"round3-{suffix}.json"
    if not spec.exists():
        settings = json.loads((folder / job["spec"]).read_text())
        settings["out_dir"] = str(folder / f"rig-round3-{suffix}")
        settings["source_output"] = str(folder / f"rig-round3-{suffix}-source" / f"{name}.blend")
        settings["motion_edits"] = job["edits"]
        spec.write_text(json.dumps(settings, indent=2) + "\n")
    out = folder / f"rig-round3-{suffix}"
    if not (out / "reimport-deformation.json").exists():
        if subprocess.run(["python3", str(pipeline / "production_motion_run.py"), root, name, job["base"], suffix]).returncode:
            print("EDIT FAILED", name, flush=True)
            continue
    severe = {row["clip"]: row["max_stretched_edges"] for row in json.loads((out / "reimport-deformation.json").read_text())}
    print("EDIT", suffix, name, severe, flush=True)
    if any(severe.values()):
        continue
    allowed = sorted({f"{e['clip']}:{e['bone']}:{'scale' if 'scale' in e else 'rotation'}" for e in job["edits"]})
    subprocess.run(["python3", str(pipeline / "production_motion_compare.py"), str(folder / job["base"] / f"{name}.glb"),
                    str(out / f"{name}.glb"), *allowed], check=True)
    preview = pipeline / f"godot-preview-round3-{name}-{suffix}"
    if not preview.exists():
        subprocess.run(["python3", "/tmp/repair_evidence.py", f"round3-{name}-{suffix}", preview.name, str(out / f"{name}.glb")], check=True)
        subprocess.run(["python3", str(pipeline / "review_capture_sheets.py"), str(preview / name)], check=True)
print("EDIT QUEUE DONE", suffix, flush=True)

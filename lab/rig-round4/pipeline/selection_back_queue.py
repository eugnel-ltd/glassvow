# Engine: capture the rear view of every selected variant that has none yet, one at a time.
import json
from pathlib import Path
import subprocess

lab = Path("/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab")
pipeline = lab / "pipeline"
inventory = json.loads((pipeline / "current-research-inventory-round2.json").read_text())
changes = json.loads((pipeline / "production-round3-working-selection.json").read_text())["changes"]
for row in inventory:
    glb = lab / row["glb"]
    name = glb.stem
    if name in changes:
        glb = next(lab / root / name / changes[name] / f"{name}.glb" for root in ("mobs", "chars")
                   if (lab / root / name / changes[name]).is_dir())
    preview = f"godot-view-back-{name}-{glb.parent.name.removeprefix('rig-round3-')}"
    if (pipeline / preview).exists():
        continue
    result = subprocess.run(["python3", str(pipeline / "view_capture.py"), "-2.2,0.9,-3.2", preview, str(glb)],
                            capture_output=True, text=True)
    print("BACK", name, glb.parent.name, "ok" if result.returncode == 0 else "FAILED " + result.stdout[-300:], flush=True)
print("BACK QUEUE DONE", flush=True)

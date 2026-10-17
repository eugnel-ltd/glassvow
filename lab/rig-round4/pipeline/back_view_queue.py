# Engine: queue back-view captures of the side-fall death trials, plus the missing Knight front capture.
import os
from pathlib import Path
import shutil
import subprocess
import time

lab = Path("/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab")
pipeline = lab / "pipeline"


def wait():
    deadline = time.time() + 1200
    while os.getloadavg()[0] >= 30 or shutil.disk_usage(lab).free / 2**30 < 100:
        assert time.time() < deadline, "Resource wait expired"
        time.sleep(15)


knight = lab / "mobs/abyssalKnight/rig-round3-fine-fall/abyssalKnight.glb"
if not (pipeline / "godot-preview-round3-abyssalKnight-fine-fall").exists():
    wait()
    subprocess.run(["python3", "/tmp/repair_evidence.py", "round3-abyssalKnight-fine-fall",
                    "godot-preview-round3-abyssalKnight-fine-fall", str(knight)], check=True)
    subprocess.run(["python3", str(pipeline / "review_capture_sheets.py"),
                    str(pipeline / "godot-preview-round3-abyssalKnight-fine-fall/abyssalKnight")], check=True)
trials = [("mobs", "drownedOne", "rig-round3-fall"), ("mobs", "rootheart", "rig-round3-fall"),
          ("mobs", "sporeling", "rig-round3-fall"), ("mobs", "thornling", "rig-round3-fall"),
          ("mobs", "obsidianGolem", "rig-round3-fall"), ("mobs", "ashAcolyte", "rig-round3-fine-fall"),
          ("mobs", "abyssalKnight", "rig-round3-fine-fall"), ("chars", "ashwarden", "rig-round3-fall-long"),
          ("chars", "duskblade", "rig-round3-fall-long")]
for root, name, variant in trials:
    preview = f"godot-view-back-{name}-{variant.removeprefix('rig-round3-')}"
    if (pipeline / preview).exists():
        continue
    wait()
    model = lab / root / name / variant / f"{name}.glb"
    subprocess.run(["python3", str(pipeline / "view_capture.py"), "-2.2,0.9,-3.2", preview, str(model)], check=True)
print("BACK VIEW QUEUE DONE", flush=True)

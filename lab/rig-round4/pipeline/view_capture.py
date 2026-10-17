# Engine: capture one model from an extra camera angle, then build its temporal sheet.
#   python3 view_capture.py <x,y,z> <preview-dir-name> <model.glb>
# The camera keeps the standard fit; only its direction from the body centre changes.
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

pipeline = Path("/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab/pipeline")
direction, preview_root, model = sys.argv[1:]
model = str(Path(model).resolve())  # Godot runs from its project directory
assert len([float(v) for v in direction.split(",")]) == 3
script = pipeline / "godot_preview_view.gd"
if not script.exists():
    text = (pipeline / "godot_preview.gd").read_text()
    old = "Vector3(2.2, 0.9, 3.2)"
    assert text.count(old) == 1
    new = 'Vector3(OS.get_environment("GV_VIEW_DIR").split_floats(",")[0], OS.get_environment("GV_VIEW_DIR").split_floats(",")[1], OS.get_environment("GV_VIEW_DIR").split_floats(",")[2])'
    script.write_text("# Extra-angle copy of godot_preview.gd: GV_VIEW_DIR=x,y,z sets the camera direction.\n"
                      + text.replace(old, new))
output = pipeline / preview_root
log = pipeline / f"{preview_root}.log"
assert Path(model).is_file() and not output.exists() and not log.exists(), "Preserve an existing capture"
deadline = time.time() + 1200
while os.getloadavg()[0] >= 30 or shutil.disk_usage(pipeline).free / 2**30 < 100:
    assert time.time() < deadline, "Resource wait expired"
    time.sleep(15)
result = subprocess.run(["/opt/homebrew/bin/godot", "--path", str(pipeline / "godot-inspect"),
                         "--resolution", "640x640", "--position", "1500,60",
                         "--script", str(script), "--", str(output), model],
                        capture_output=True, text=True, timeout=600, env={**os.environ, "GV_VIEW_DIR": direction})
text = result.stdout + result.stderr
log.write_text(text)
assert result.returncode == 0 and "SCRIPT ERROR" not in text and "ERROR:" not in text, text
folder = output / Path(model).stem
subprocess.run(["python3", str(pipeline / "review_capture_sheets.py"), str(folder)], check=True)
print(preview_root, text.strip().splitlines()[-1], folder / "temporal-sheet-exact.png", flush=True)

# Engine: verify one motion trial and capture its front and back review evidence.
#   python3 trial_evidence.py <root> <name> <base-variant> <variant> <row> <clip:bone:property> ...
# Writes /tmp/<name>-<variant>-row<row>.png with the chosen sheet row from both views.
from pathlib import Path
import subprocess
import sys

lab = Path("/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab")
pipeline = lab / "pipeline"
root, name, base, variant, row, *allowed = sys.argv[1:]
short = variant.removeprefix("rig-round3-")
model = lab / root / name / variant / f"{name}.glb"
run = lambda *args: subprocess.run(["python3", *map(str, args)], check=True)
run(pipeline / "production_motion_compare.py", lab / root / name / base / f"{name}.glb", model, *allowed)
front = pipeline / f"godot-preview-round3-{name}-{short}"
if not front.exists():
    run("/tmp/repair_evidence.py", f"round3-{name}-{short}", front.name, model)
    run(pipeline / "review_capture_sheets.py", front / name)
back = pipeline / f"godot-view-back-{name}-{short}"
if not back.exists():
    run(pipeline / "view_capture.py", "-2.2,0.9,-3.2", back.name, model)
output = Path(f"/tmp/{name}-{short}-row{row}.png")
output.unlink(missing_ok=True)
run(pipeline / "death_rows.py", output, row, front / name / "temporal-sheet-exact.png", back / name / "temporal-sheet-exact.png")

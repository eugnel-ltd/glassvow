# Engine: report severe-edge counts for the provisional selection, read from each variant's own report.
import json
from pathlib import Path

lab = Path("/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab")
pipeline = lab / "pipeline"
inventory = json.loads((pipeline / "current-research-inventory-round2.json").read_text())
changes = json.loads((pipeline / "production-round3-working-selection.json").read_text())["changes"]
total = 0
for row in inventory:
    name = Path(row["glb"]).stem
    folder = (lab / row["glb"]).parent if name not in changes else next(
        (lab / root / name / changes[name] for root in ("mobs", "chars") if (lab / root / name / changes[name]).is_dir()))
    report = json.loads((folder / "reimport-deformation.json").read_text())
    severe = {r["clip"]: r["max_stretched_edges"] for r in report if r["max_stretched_edges"]}
    total += sum(severe.values())
    print(f"{name:16} {'R3 ' if name in changes else 'R2 '}{folder.name:28} {severe or 0}")
print("SELECTION SEVERE TOTAL", total)

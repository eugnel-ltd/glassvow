# Engine: silhouette-contrast trial for humanoid casters, run one character at a time.
# Attack leans the torso forward; cast arches it back and lifts the head. Both pulse sin^2.
import json
from pathlib import Path
import subprocess
import sys

lab = Path("/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab")
pipeline = lab / "pipeline"
bases = {"unlitSelf": "rig-round3-cast", "starCultist": "rig-round3-cast", "unopenedSelf": "rig-round3-cast",
         "unwalkedSelf": "rig-round3-cast", "voidColossus": "rig-round3-cast", "sovereign": "rig-round3-cast",
         "unobsidianSelf": "rig-round3-cast-low", "eternalKeeper": "rig-round3-cast-head",
         "ashAcolyte": "rig-round3-fine-fall", "ashwarden": "rig-round3-collapse", "duskblade": "rig-round3-collapse", "waylayer": "rig-round3-drop"}
# World +X tips the top of a bone towards the front (-Y).
edits = [("attack", "Spine", 8), ("attack", "Chest", 10), ("attack", "UpperChest", 6),
         ("cast", "Spine", -6), ("cast", "Chest", -8), ("cast", "UpperChest", -6), ("cast", "Head", -12)]
# Optional: <variant-suffix> <torso-factor> <name> ...  (the head lift keeps full strength)
suffix, factor = (sys.argv[1], float(sys.argv[2])) if len(sys.argv) > 2 else ("contrast", 1.0)
if len(sys.argv) > 3:
    bases = {name: bases[name] for name in sys.argv[3:]}
edits = [(clip, bone, degrees if bone == "Head" else round(degrees * factor, 2)) for clip, bone, degrees in edits]
allowed = [f"{clip}:{bone}:rotation" for clip, bone, _ in edits]
for name, base in bases.items():
    root = "mobs" if (lab / "mobs" / name).is_dir() else "chars"
    folder = lab / root / name
    spec = folder / f"round3-{suffix}.json"
    if not spec.exists():
        settings = json.loads((folder / f"round3-{base.removeprefix('rig-round3-')}.json").read_text())
        settings["out_dir"] = str(folder / f"rig-round3-{suffix}")
        settings["source_output"] = str(folder / f"rig-round3-{suffix}-source" / f"{name}.blend")
        settings["motion_edits"] = [{"clip": clip, "bone": bone, "axis": [1, 0, 0], "degrees": degrees}
                                    for clip, bone, degrees in edits]
        spec.write_text(json.dumps(settings, indent=2) + "\n")
    out = folder / f"rig-round3-{suffix}"
    if not (out / "reimport-deformation.json").exists():
        result = subprocess.run(["python3", str(pipeline / "production_motion_run.py"), root, name, base, suffix])
        if result.returncode:
            print("CONTRAST FAILED", name, flush=True)
            continue
    report = json.loads((out / "reimport-deformation.json").read_text())
    severe = {row["clip"]: row["max_stretched_edges"] for row in report}
    print("CONTRAST", suffix, name, severe, flush=True)
    if any(severe.values()):
        continue
    subprocess.run(["python3", str(pipeline / "production_motion_compare.py"), str(folder / base / f"{name}.glb"),
                    str(out / f"{name}.glb"), *allowed], check=True)
    preview = pipeline / f"godot-preview-round3-{name}-{suffix}"
    if not preview.exists():
        subprocess.run(["python3", "/tmp/repair_evidence.py", f"round3-{name}-{suffix}", preview.name, str(out / f"{name}.glb")], check=True)
        subprocess.run(["python3", str(pipeline / "review_capture_sheets.py"), str(preview / name)], check=True)
print("CONTRAST QUEUE DONE", flush=True)

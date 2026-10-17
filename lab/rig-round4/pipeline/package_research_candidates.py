# Engine only: package checked research assets with relative paths and verified archive hashes.
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import zipfile

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
round2 = sys.argv[1:] == ["--round2"]
assert sys.argv[1:] in ([], ["--round2"])
inventory_path = pipeline / ("current-research-inventory-round2.json" if round2 else "current-research-inventory-cape-floor.json")
inventory = json.loads(inventory_path.read_text())
portable = json.loads((pipeline / ("portable-blends-round2.json" if round2 else "portable-blends-check.json")).read_text())
assert portable["inventory_sha256"] == hashlib.sha256(inventory_path.read_bytes()).hexdigest()
assert len(inventory) == len(portable["candidates"]) == 38
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
root = lane / ("handoff-20261016-round2" if round2 else "handoff-20261015")
archive = lane / ("character-research-20261016-round2.zip" if round2 else "character-research-20261015.zip")
assert not root.exists() and not archive.exists(), "Preserve a previous handoff"
root.mkdir()
files = {}


def copy(source, relative):
    source = source.resolve()
    assert source.is_relative_to(lane) and source.is_file(), source
    target = root / relative
    assert target.is_relative_to(root) and not target.exists(), target
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    assert digest == hashlib.sha256(source.read_bytes()).hexdigest()
    files[relative] = {"sha256": digest, "bytes": target.stat().st_size}
    return relative


portable_by_name = {row["candidate"]: row for row in portable["candidates"]}
manifest = []
for row in inventory:
    candidate = row["candidate"]
    parts = candidate.split("/")
    assert len(parts) == 3 and parts[0] in ("chars", "mobs")
    assert all(part and part.replace("-", "").isalnum() for part in parts)
    name = parts[1]
    model = Path(row["glb"])
    assert hashlib.sha256(model.read_bytes()).hexdigest() == row["sha256"]
    source = model.with_suffix(".blend")
    dependency = portable_by_name[candidate]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == dependency["sha256"]
    assert not dependency["libraries"] and not dependency["external_paths"]
    assert all(image["packed"] for image in dependency["images"])
    prefix = f"characters/{name}"
    item = {"name": name, "source_candidate": candidate,
            "model": copy(model, f"{prefix}/{name}.glb"),
            "blender_source": copy(source, f"{prefix}/{name}.blend"),
            "preview": copy(Path(row["preview"]) / "temporal-sheet-exact.png", f"{prefix}/temporal-sheet.png"),
            "approval": "Unapproved research candidate",
            "structure": row["structure"], "deformation": row["deformation"],
            "ground_clips": row["ground_clips"], "captured_frames": row["captured_frames"],
            "known_limitations": list(row["known_limitations"]), "evidence": {}}
    for label, proof in row["evidence"].items():
        path = Path(proof["path"])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == proof["sha256"]
        relative = f"evidence/{path.name}"
        if relative not in files:
            copy(path, relative)
        item["evidence"][label] = relative
    for report in ("structure.json", "reimport-deformation.json", "contact.json", "support-contact.json"):
        path = model.parent / report
        if path.exists():
            item["evidence"][report] = copy(path, f"{prefix}/{report}")
    manifest.append(item)
assert len({row["name"] for row in manifest}) == 38
for name, note in {
    "shellback": "Cast has a subtle silhouette change",
    "uncrossedSelf": "Attack and cast have similar silhouettes",
}.items():
    next(row for row in manifest if row["name"] == name)["known_limitations"].append(note)
(root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
zero = sum(all(clip["max_stretched_edges"] == 0 for clip in row["deformation"]) for row in manifest)
losses = json.loads((pipeline / "baseline-losses.json").read_text())["candidates"]
lost_names = " and ".join(sorted(c.split("/")[1][:1].upper() + c.split("/")[1][1:] for c in losses))
ash = next(row for row in manifest if row["name"] == "ashwarden")
ash_edges = ", ".join(f"{clip['clip']} {clip['max_stretched_edges']}" for clip in ash["deformation"]
                      if clip["max_stretched_edges"]) or "none"
readme = f"""# Character research candidates

Prepared on {"16 October 2026" if round2 else "15 October 2026"}. This is an unapproved research handoff for Glassvow.
The models are not production assets and have not been integrated into combat.

## Contents

- {len(manifest)} characters: Duskblade, Ashwarden and all 36 enemies.
- Six named clips per character: idle, walk, attack, cast, hurt and death.
- Self-contained GLB models and Blender 5.2.2 source files with packed textures.
- A temporal sheet per character, sampled from actual Godot 4.7.2 renderer captures.
- Relative file paths, candidate hashes, validation reports and known limitations in manifest.json.
- SHA256SUMS.json covers every packaged file except itself. The ZIP is verified after creation.

Open a character's GLB in an isolated Godot inspection project, or open its Blender source.
The preserved lab contains the complete 223-frame capture per character and the failed research variants.
The archive contains sampled sheets rather than all 8,474 captured frames.

## Verified technical scope

All candidates pass skeleton and animation import, sampled movement for all six clips,
death-to-idle return, finite geometry, normalised skin weights and a maximum of four influences.
There are no unweighted body vertices. Designated contact clips pass a body minimum-height
range of -5 to +15 mm. Hovering and swimming characters retain intentional clearance outside death.
{38 - len(losses)} of 38 baseline model hashes remained unchanged when the inventory was collected.
Repair runs overwrote the {lost_names} baseline rigs. Their rebuilds match the original mesh,
skeleton and skin weights; the lab's pipeline/baseline-losses.json records both hashes.

{zero} candidates have no severe stretch signal in the sampled exported animation checks.
{len(manifest) - zero} candidates retain at least one severe stretch signal.
A severe edge is longer than three times its rest length and longer than 30 mm.
A per-recipe rig and animation repair pass reduced the summed severe-edge count of the 21 affected
candidates from 1,243 to {sum(c["max_stretched_edges"] for r in manifest for c in r["deformation"])}. Some repairs soften motion; the manifest names each one.
This is a deformation diagnostic. A zero count does not prove correct anatomy or cloth.

Duskblade's new baked cape fold keeps its death endpoint foot surface about 2 mm above the floor,
with the cape hem about 10 mm above it. The rejected hanging-cape variant lifted the feet by 253 mm.
Ashwarden's adjusted cape anchor removes the additional cape-boundary regression. Its attack, cast and
death bone rotations are softened to stop tearing; its remaining severe edges: {ash_edges}.
Duskblade keeps its authored body motion. Neither cape has cloth self-collision proof.

## Open quality work

- Several active clips have weak differentiation or a minimal stride.
- Several death clips read as a bow or a rigid body rotation.
- AbyssalKnight, AshAcolyte and DrownedOne death folds are reduced to stop tearing and read as shallow slumps.
- UncarvedSelf, UnsunkSelf and UnwoodedSelf use three-bone held poses without separate limb articulation.
- Gravewarden has a previously observed shoulder hole.
- UncrossedSelf's book reaches the palm, but the fingers remain open.
- Body contact does not prove foot locking, prop clearance or penetration depth.
- Continuous playback approval remains outstanding. The sheets are sampled visual evidence.

Use each manifest entry for the exact candidate-specific limitations. No owner art pick is recorded.
Do not promote a candidate into assets/ on the strength of a technical pass alone.

## Cost record

The last observed Studio wallet was 1,080 credits after the authorised generation queue completed.
The observed project spend was 2,120 credits. The account is shared with other projects.
No additional paid generation, paid rigging or paid animation was used for these repairs.
These figures are historical observations, not a live wallet reading.
"""
(root / "README.md").write_text(readme)
for relative in ("manifest.json", "README.md"):
    path = root / relative
    files[relative] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
(root / "SHA256SUMS.json").write_text(json.dumps(files, indent=2, sort_keys=True) + "\n")
with zipfile.ZipFile(archive, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
    for source in sorted(root.rglob("*")):
        if source.is_file():
            bundle.write(source, source.relative_to(root))
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
    assert set(bundle.namelist()) == {*files, "SHA256SUMS.json"}
    for relative, record in files.items():
        data = bundle.read(relative)
        assert hashlib.sha256(data).hexdigest() == record["sha256"] and len(data) == record["bytes"]
report = {"archive": str(archive), "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
          "bytes": archive.stat().st_size, "files": len(files) + 1, "candidates": len(manifest),
          "zero_severe_stretch": zero, "archive_crc_and_hashes": "passed",
          "free_gib_after": shutil.disk_usage(lane).free / 2**30}
(pipeline / ("handoff-package-round2.json" if round2 else "handoff-package-check.json")).write_text(json.dumps(report, indent=2) + "\n")
print("RESEARCH PACKAGE PASS", json.dumps(report), flush=True)

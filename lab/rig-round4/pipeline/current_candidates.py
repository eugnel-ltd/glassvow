# Engine only: collect measured research candidates without changing the preserved baseline.
import hashlib
import json
from pathlib import Path
import sys

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
assert sys.argv[1:] in ([], ["--cape-floor"])
cape_floor = sys.argv[1:] == ["--cape-floor"]
baseline = json.loads((pipeline / "candidate-selection.json").read_text())
rollout = json.loads((pipeline / "contact-rollout-inventory.json").read_text())
assert len(baseline) == 38 and len(rollout) == 32
losses = json.loads((pipeline / "baseline-losses.json").read_text())["candidates"]  # overwritten, then rebuilt
for row in json.loads((pipeline / "baseline-inventory.json").read_text()):
    lost = losses.get(row["candidate"])
    assert lost is None or lost["original_sha256"] == row["sha256"], row["candidate"]
    expected = lost["rebuilt_sha256"] if lost else row["sha256"]
    assert hashlib.sha256(Path(row["glb"]).read_bytes()).hexdigest() == expected, row["candidate"]
by_name = {row["candidate"].split("/")[1]: row for row in rollout}
repairs = {
    "duskblade": ("chars/duskblade/rig-fitted-contact", "godot-preview-heroes-fitted-contact", "heroes-fitted-contact"),
    "ashwarden": ("chars/ashwarden/rig-fitted-contact", "godot-preview-heroes-fitted-contact", "heroes-fitted-contact"),
    "shellback": ("mobs/shellback/rig-smooth-contact", "godot-preview-contact", "contact"),
    "uncrossedSelf": ("mobs/uncrossedSelf/rig-hold-contact", "godot-preview-hold", "hold"),
    "tidecaller": ("mobs/tidecaller/rig-robe-contact", "godot-preview-tidecaller-contact", "tidecaller-contact"),
    "mirelurker": ("mobs/mirelurker/rig-contact-classfade", "godot-preview-cape-and-mirelurker", "cape-mirelurker"),
}
notes = {
    "duskblade": ["Death cape follows the back as a rigid sheet", "Hood face design has no owner approval"],
    "ashwarden": ["Death cape follows the back as a rigid sheet", "Attack, cast and death retain severe stretch signals"],
    "uncrossedSelf": ["Book reaches the palm, but the fingers remain open", "No finger articulation or penetration-depth proof"],
    "shellback": ["Paired side views show a claw root connection; no topology clearance proof"],
    "abyssalKnight": ["Death fold reduced to stop tearing; it ends in a shallow forward slump with a weak defeat silhouette"],
    "ashAcolyte": ["Death fold reduced to stop tearing; it ends in a shallow forward slump with a weak defeat silhouette", "Raised-arm attack and cast swings reduced to stop chest tearing"],
    "drownedOne": ["Death fold reduced to stop tearing; it ends in a shallow forward slump with a weak defeat silhouette"],
    "gloomslime": ["Attack visibly compresses and distorts the surface"],
    "eternalKeeper": ["Several active clips have weak silhouette changes; death retains a rigid robe"],
    "gravewarden": ["A shoulder hole was visible in the rigid split mesh"],
    "obsidianGolem": ["Death ends in a forward lean with feet underneath; defeat reads weakly"],
    "rootheart": ["Walk has little readable stepping; death remains a rooted stoop"],
    "shade": ["Active clips are difficult to distinguish; death rotates a largely rigid silhouette"],
    "siren": ["Attack and cast lack distinct silhouettes; death reads as a whole-body roll"],
    "sovereign": ["Attack and cast are similar; death retains a stiff horizontal robe"],
    "sporeling": ["Death reads as a deep bow with feet underneath"],
    "starCultist": ["Attack and cast are similar; death retains rigid equipment and body alignment"],
    "thornling": ["Death is difficult to distinguish from a crouch"],
    "uncarvedSelf": ["Three-bone held pose; no independent limb articulation", "Active clips have weak differentiation"],
    "unlitSelf": ["Attack and cast are similar; lantern tilts rigidly with the hand"],
    "unobsidianSelf": ["Attack and cast are similar; death retains a stiff robe"],
    "unopenedSelf": ["Attack and cast are similar; wrist connection is partly hidden"],
    "unsunkSelf": ["Three-bone held pose; no independent limb articulation", "Active clips are almost indistinguishable"],
    "unwalkedSelf": ["Walk lacks a clear stride; death retains rigid body and staff alignment"],
    "unwoodedSelf": ["Three-bone held pose; no independent limb articulation", "Active clips have weak differentiation"],
    "voidColossus": ["Minimal stride change; attack and cast are difficult to distinguish"],
    "voidWisp": ["Active clips have weak differentiation; death rotates the whole assembly"],
    "voltEel": ["Attack, cast and hurt have weak silhouette changes"],
    "watcherEye": ["Attack and cast have weak differentiation; ornaments rotate rigidly during death"],
    "waylayer": ["Cast is subtle; heavy head and torso overlap during death needs close inspection"],
}
if cape_floor:
    for name, prefix in (("duskblade", "dusk"), ("ashwarden", "ash")):
        repairs[name] = (f"chars/{name}/rig-cape-floor-contact", f"godot-preview-{prefix}-cape-floor", f"{prefix}-cape-floor")
    notes["duskblade"] = ["Baked cape fold; no cloth self-collision proof", "Death remains a forward kneel", "Hood face design has no owner approval"]
    notes["ashwarden"] = ["Cape anchor moved to the measured attachment height; no cloth self-collision proof",
                          "Attack, cast and death bone rotations softened to stop tearing", "Death remains a softened forward kneel"]
for name, (candidate, preview_root, log_prefix) in repairs.items():
    folder = lane.joinpath(*candidate.split("/"))
    by_name[name] = {"candidate": candidate, "preview": str(pipeline / preview_root / name),
                     "ground_clips": ["idle", "walk", "attack", "cast", "hurt", "death"],
                     "log_prefix": log_prefix}
assert len(by_name) == 38
rows = []
clips = {"idle", "walk", "attack", "cast", "hurt", "death"}
for original in baseline:
    name = original["candidate"].split("/")[1]
    row = by_name[name]
    folder = lane.joinpath(*row["candidate"].split("/"))
    glb = folder / f"{name}.glb"
    prefix = row.pop("log_prefix", "contact-rollout")
    evidence = {}
    for kind in ("godot", "preview"):
        log = pipeline / f"{prefix}-{kind}.log"
        text = log.read_text()
        assert log.stat().st_mtime_ns >= glb.stat().st_mtime_ns, (name, "stale log", log)
        assert "SCRIPT ERROR" not in text and "ERROR:" not in text
        if kind == "godot":
            assert f"GD PASS {name}.glb " in text and "GD RESULT " in text and "passed" in text
        else:
            assert f"PREVIEW {name} frames 223 clips 6" in text and "PREVIEW RESULT failures 0" in text
        evidence[kind] = {"path": str(log), "sha256": hashlib.sha256(log.read_bytes()).hexdigest()}
    preview = Path(row["preview"])
    manifest = json.loads((preview / "frames.json").read_text())
    assert len(manifest) == 6 and {clip["clip"] for clip in manifest} == clips
    assert sum(clip["frames"] for clip in manifest) == len(list(preview.glob("frame-*.png"))) == 223
    deformation = json.loads((folder / "reimport-deformation.json").read_text())
    assert len(deformation) == 6 and {clip["clip"] for clip in deformation} == clips
    contact = [clip for clip in deformation if clip["clip"] in row["ground_clips"]]
    assert len(contact) == len(row["ground_clips"])
    assert all(clip["min_z"] >= -.005 and clip["max_min_z"] <= .015 for clip in contact)
    structure = json.loads((folder / "structure.json").read_text())
    assert structure["unweighted"] == 0 and structure["max_influences"] <= 4
    if cape_floor and name in ("duskblade", "ashwarden"):
        support_path = folder / "support-contact.json"
        support = json.loads(support_path.read_text())
        assert support["candidate"] == row["candidate"] and support["world_translation_control"] == "passed"
        death_samples = [sample for sample in support["samples"] if sample["clip"] == "death"]
        assert len(death_samples) == 33
        assert all(-.005 <= sample["minimum_z_m"]["feet"] <= .015 for sample in death_samples)
        row["support_contact_evidence"] = {"path": str(support_path), "sha256": hashlib.sha256(support_path.read_bytes()).hexdigest()}
    stretch = ", ".join(f"{clip['clip']} {clip['max_stretched_edges']}" for clip in deformation if clip["max_stretched_edges"])
    row.update(glb=str(glb), sha256=hashlib.sha256(glb.read_bytes()).hexdigest(), bytes=glb.stat().st_size,
               structure=structure, deformation=deformation, captured_frames=223, evidence=evidence,
               godot_import_movement_idle_return="passed", approval="Unapproved research candidate",
               known_limitations=[f"Severe stretch edges remain: {stretch}"] * bool(stretch) + notes.get(name, []) + ["Body contact does not prove foot locking or prop clearance",
                   "Sampled visual review is not full continuous playback approval"])
    rows.append(row)
output = pipeline / ("current-research-inventory-cape-floor.json" if cape_floor else "current-research-inventory.json")
assert not output.exists(), "Inspect an existing inventory before replacing it"
output.write_text(json.dumps(rows, indent=2) + "\n")
print("CURRENT RESEARCH SET", len(rows), "zero severe stretch",
      sum(all(clip["max_stretched_edges"] == 0 for clip in row["deformation"]) for row in rows))

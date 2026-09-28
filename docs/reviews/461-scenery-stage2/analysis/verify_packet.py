#!/usr/bin/env python3
"""Verify the locked #461 Stage 2 packet and write its evidence result."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path

from PIL import Image


HERE = Path(__file__).resolve().parent
PACKET = HERE.parent
ROOT = PACKET.parents[2]
BASELINE = ROOT / "docs/reviews/461-scenery-mobile"

EXPECTED_HEAD = "ca1057f2bbe25654c5f6add28f59e6b7e0115bc5"
EXPECTED_BASE = "c28ae38824f7ba2168b573002ab8b90dadd5bde1"
EXPECTED_COMMAND = "docs/reviews/461-scenery-stage2/run_capture.sh"
EXPECTED_TRACKED_DIFF = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
EXPECTED_COMPILER_SHA256 = "49002f94bb0a1ee16bfbe3a4b33e38ee12d5233d4c699ba478545e3ff9cdd3ca"
EXPECTED_LAYOUTS = {
    (1, 17634): ("5a7d6a435082707594c9ec56f6c321291fbba42133622a73997ed3fa298b3545", 15),
    (1, 717): ("9b182e7c36d840c8850d8df62dbb01485ce90eacab6d7ce3684a24319f0d8091", 21),
    (2, 717): ("6d5bd644c02867b8e316d4b0f0442d24720719e088a622ff0f9609ddd14089c7", 19),
    (3, 717): ("54341c63a16c278dc1e807aa0cf32800838437d9b340c79a3e8b800e848ae75d", 18),
    (4, 717): ("a995141403bf08da65221c1e2e0837884484508132123c0c51853a7b296dcf5c", 17),
}
HARD_ZERO_FIELDS = (
    "edge_scenery_corridor_penetration_m",
    "node_scenery_silhouette_overlap_area_px2",
    "node_touch_scenery_silhouette_overlap_area_px2",
    "vigil_protected_zone_intrusion_count",
    "terminus_protected_zone_intrusion_count",
)


def read_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frame_key(frame: dict[str, object]) -> tuple[object, ...]:
    return tuple(frame[key] for key in ("frame_id", "act", "seed", "shape", "zoom_stop", "pose", "locale"))


def input_map(manifest: dict[str, object]) -> dict[tuple[int, int], str]:
    return {
        (int(frame["act"]), int(frame["seed"])): str(frame["input_digest"])
        for frame in manifest["frames"]
    }


def layout_map(manifest: dict[str, object]) -> dict[tuple[int, int], tuple[str, int]]:
    return {
        (int(frame["act"]), int(frame["seed"])): (
            str(frame["layout_digest"]),
            int(frame["scenery_count"]),
        )
        for frame in manifest["frames"]
    }


def main() -> None:
    manifest = read_json(PACKET / "manifest.json")
    baseline = read_json(BASELINE / "manifest.json")
    t5 = read_json(HERE / "t5-inspection.json")
    t6 = read_json(HERE / "t6-luminance.json")
    t7 = read_json(HERE / "t7-capture.json")
    preflight = read_json(HERE / "preflight.json")

    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'^renderer/rendering_method="([^"]+)"$', project_text, re.MULTILINE)
    assert match is not None
    shipping_method = match.group(1)
    assert shipping_method == "mobile"
    assert manifest["stage"] == 2
    assert manifest["rendering_method"] == shipping_method
    assert manifest["shipping_rendering_method"] == shipping_method
    assert manifest["rendering_method_source"] == "RenderingServer.get_current_rendering_method()"

    assert manifest["capture_head"] == EXPECTED_HEAD
    assert manifest["base_head"] == EXPECTED_BASE
    assert manifest["capture_command"] == EXPECTED_COMMAND
    assert manifest["capture_command_rendering_override"] is False
    assert manifest["candidate_tracked_diff_sha256"] == EXPECTED_TRACKED_DIFF
    assert manifest["placement_compiler_sha256"] == EXPECTED_COMPILER_SHA256
    assert sha256(ROOT / "presentation/map/map_layout_compiler.gd") == EXPECTED_COMPILER_SHA256
    assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == EXPECTED_HEAD

    frames = manifest["frames"]
    assert manifest["frame_count"] == 12 == manifest["expected_frame_count"] == len(frames)
    assert manifest["compiler_input_count"] == 5 == len(manifest["compile_wall_clock"])
    assert [frame_key(frame) for frame in frames] == [frame_key(frame) for frame in baseline["frames"]]
    assert input_map(manifest) == input_map(baseline)
    assert layout_map(manifest) == layout_map(baseline) == EXPECTED_LAYOUTS
    for frame in frames:
        path = PACKET / str(frame["file"])
        assert path.is_file()
        with Image.open(path) as image:
            assert image.size == (int(frame["viewport"]["width"]), int(frame["viewport"]["height"]))

    baseline_hard = {
        (int(row["act"]), int(row["seed"])): row["hard_zero_metrics"]
        for row in baseline["compile_wall_clock"]
    }
    for row in manifest["compile_wall_clock"]:
        key = (int(row["act"]), int(row["seed"]))
        assert 14 <= int(row["scenery_count"]) <= 24
        assert row["hard_zero_metrics"] == baseline_hard[key]
        assert all(float(row["hard_zero_metrics"][field]) == 0.0 for field in HARD_ZERO_FIELDS)

    assert preflight["result"] == "pass"
    assert preflight["resource_class"] == "CompressedTexture2D"
    assert preflight["source_resolution"] == [512, 256]
    assert preflight["decoded_resolution"] == [512, 256]
    assert preflight["decoded_format"] == "FORMAT_RGBA8"
    assert manifest["grade_contact_coverage"]["compiled_origins"] == 21
    assert manifest["grade_contact_coverage"]["in_grade_rect_origins"] == 10
    assert manifest["grade_contact_coverage"]["out_of_grade_rect_origins"] == 11
    assert t5["orphan_contact_ellipses"] == 0
    assert t7["result"] == "frames_captured_owner_eye_pending"
    assert t7["owner_verdict"] is None
    assert t7["stage_3_started"] is False

    version_log = (PACKET / "logs/godot-version.log").read_text(encoding="utf-8")
    imports_log = (PACKET / "logs/check-imports.log").read_text(encoding="utf-8")
    scripts_log = (PACKET / "logs/check-scripts.log").read_text(encoding="utf-8")
    suite_log = (PACKET / "logs/run-all.log").read_text(encoding="utf-8")
    assert "4.7.2.stable.official.ed1daf0bf" in version_log
    assert "asset import OK" in imports_log
    assert "scripts OK (256 checked)" in scripts_log
    assert "ok   res://tests/test_map_grade_contact.gd" in suite_log
    assert "PASS (74 tests)" in suite_log

    result = {
        "schema": 1,
        "issue": 461,
        "stage": 2,
        "capture_manifest_sha256": sha256(PACKET / "manifest.json"),
        "comparison_manifest_sha256": {
            "docs/reviews/461-scenery-mobile/manifest.json": sha256(BASELINE / "manifest.json"),
        },
        "capture": {
            "head": EXPECTED_HEAD,
            "command": EXPECTED_COMMAND,
            "observed_exit_code": 0,
            "runtime_seconds": manifest["capture_runtime_seconds"],
            "frames": 12,
            "compiler_inputs": 5,
        },
        "T1": {
            "result": "pass",
            "runtime_rendering_method": manifest["rendering_method"],
            "shipping_rendering_method": shipping_method,
            "source": manifest["rendering_method_source"],
        },
        "T2": {
            "result": "pass",
            "command_executed": EXPECTED_COMMAND,
            "capture_head": EXPECTED_HEAD,
            "rendering_override": False,
        },
        "T3": {
            "result": "pass",
            "all_five_layout_digests_byte_equal_to_stage1": True,
            "layouts": [
                {"act": act, "seed": seed, "layout_digest": digest, "scenery_count": count}
                for (act, seed), (digest, count) in EXPECTED_LAYOUTS.items()
            ],
            "occupancy_range": [15, 21],
            "required_occupancy_range": [14, 24],
            "all_hard_zero_metrics_byte_equal_and_zero": True,
        },
        "T4": {
            "result": "pass",
            "clauses": [
                "contact floor under every in-grade placement",
                "far texels remain unity",
                "no orphan alpha texel",
                "compact bake is byte-equal to a full-image walk",
                "empty positions leave unity alpha",
            ],
            "act_1_seed_717_grade_domain": {"in_rect": 10, "out_of_rect": 11, "total": 21},
            "suite": "logs/run-all.log",
        },
        "T5": {
            "result": "pass",
            "orphan_contact_ellipses": 0,
            "overlay": t5["overlay"],
            "inspection": "analysis/t5-inspection.json",
        },
        "T6": {
            "result": "reported_not_graded",
            "prop_median": t6["prop_median"],
            "ground_median": t6["ground_median"],
            "ratio": t6["ratio"],
            "measurement": "analysis/t6-luminance.json",
        },
        "T7": {
            "result": t7["result"],
            "backend": t7["backend"],
            "frame_ids": t7["frame_ids"],
            "owner_verdict": t7["owner_verdict"],
            "observation": t7["observation"],
        },
    }
    (PACKET / "verification.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

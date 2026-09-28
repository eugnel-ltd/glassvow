#!/usr/bin/env python3
"""Verify the fixed #461 Stage 1 matrix and write its evidence result."""

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
PRIOR = ROOT / "docs/reviews/461-scenery"
BASELINE = ROOT / "docs/reviews/529"

EXPECTED_HEAD = "c28ae38824f7ba2168b573002ab8b90dadd5bde1"
EXPECTED_COMMAND = "tools/capture_build4_map_corpus.sh --output docs/reviews/461-scenery-mobile"
EXPECTED_CANDIDATE_DIFF = "9de47eef17c91b1b30991762e8c867fb074e243c1d66c41dd513654cbc8d642a"
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
T7_INSPECTED_FRAME_IDS = tuple(f"F{number:03d}" for number in range(1, 13))


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
    prior = read_json(PRIOR / "manifest.json")
    baseline = read_json(BASELINE / "manifest.json")
    t6 = read_json(HERE / "t6-luminance.json")

    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'^renderer/rendering_method="([^"]+)"$', project_text, re.MULTILINE)
    assert match is not None
    shipping_method = match.group(1)
    assert shipping_method == "mobile"
    assert manifest["rendering_method"] == shipping_method
    assert manifest["shipping_rendering_method"] == shipping_method
    assert manifest["rendering_method_source"] == "RenderingServer.get_current_rendering_method()"

    assert manifest["capture_head"] == EXPECTED_HEAD
    assert manifest["base_head"] == EXPECTED_HEAD
    assert manifest["capture_command"] == EXPECTED_COMMAND
    assert manifest["capture_command_rendering_override"] is False
    assert manifest["candidate_tracked_diff_sha256"] == EXPECTED_CANDIDATE_DIFF
    assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == EXPECTED_HEAD

    frames = manifest["frames"]
    assert manifest["frame_count"] == 12 == manifest["expected_frame_count"] == len(frames)
    assert manifest["compiler_input_count"] == 5 == len(manifest["compile_wall_clock"])
    assert [frame_key(frame) for frame in frames] == [frame_key(frame) for frame in prior["frames"]]
    assert [frame_key(frame) for frame in frames] == [frame_key(frame) for frame in baseline["frames"]]
    assert input_map(manifest) == input_map(prior) == input_map(baseline)
    assert layout_map(manifest) == layout_map(prior) == EXPECTED_LAYOUTS

    frame_ids = []
    for frame in frames:
        frame_ids.append(frame["frame_id"])
        path = PACKET / str(frame["file"])
        assert path.is_file()
        with Image.open(path) as image:
            assert image.size == (int(frame["viewport"]["width"]), int(frame["viewport"]["height"]))
    assert tuple(frame_ids) == T7_INSPECTED_FRAME_IDS

    for row in manifest["compile_wall_clock"]:
        assert 14 <= int(row["scenery_count"]) <= 24
        assert all(float(row["hard_zero_metrics"][field]) == 0.0 for field in HARD_ZERO_FIELDS)

    result = {
        "schema": 1,
        "issue": 461,
        "stage": 1,
        "capture_manifest_sha256": sha256(PACKET / "manifest.json"),
        "comparison_manifest_sha256": {
            "docs/reviews/529/manifest.json": sha256(BASELINE / "manifest.json"),
            "docs/reviews/461-scenery/manifest.json": sha256(PRIOR / "manifest.json"),
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
            "all_five_layout_digests_byte_equal_to_461_scenery": True,
            "layouts": [
                {
                    "act": act,
                    "seed": seed,
                    "layout_digest": digest,
                    "scenery_count": count,
                }
                for (act, seed), (digest, count) in EXPECTED_LAYOUTS.items()
            ],
            "occupancy_range": [15, 21],
            "required_occupancy_range": [14, 24],
            "all_hard_zero_metrics_zero": True,
        },
        "T4": {"result": "skipped", "reason": "Stage 2"},
        "T5": {"result": "skipped", "reason": "Stage 2"},
        "T6": {
            "result": "reported_not_graded",
            "prop_median": t6["prop_median"],
            "ground_median": t6["ground_median"],
            "ratio": t6["ratio"],
            "measurement": "analysis/t6-luminance.json",
        },
        "T7": {
            "result": "performed",
            "backend": "mobile",
            "inspected_frame_ids": list(T7_INSPECTED_FRAME_IDS),
            "shapes": ["pad-landscape", "phone-landscape"],
            "poses": ["opening", "focused", "travel-midpoint"],
            "observations": [
                "Forward Mobile preserves lit top, mid front and dark side facets on the compiled scenery.",
                "Routes and waystone silhouettes remained readable in the twelve inspected frames.",
                "Some phone-scale and Acts II-IV faces remain very dark; the owner-eye gate remains open.",
                "Fixed painted contact ellipses remain visibly detached from some compiled props; T5 belongs to Stage 2.",
            ],
        },
    }
    (PACKET / "verification.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

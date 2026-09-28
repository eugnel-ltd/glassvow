#!/usr/bin/env python3
"""Promote the unchanged Stage 1 harness manifest into the Stage 2 packet manifest."""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path


HERE = Path(__file__).resolve().parent
PACKET = HERE.parent
MANIFEST = PACKET / "manifest.json"
HARNESS_MANIFEST = PACKET / "harness-manifest.json"
BASE_HEAD = "c28ae38824f7ba2168b573002ab8b90dadd5bde1"
COMPILER_SHA256 = "49002f94bb0a1ee16bfbe3a4b33e38ee12d5233d4c699ba478545e3ff9cdd3ca"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    raw = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert raw["stage"] == 1, "expected the unchanged Stage 1 harness output"
    shutil.copyfile(MANIFEST, HARNESS_MANIFEST)
    preflight = json.loads((HERE / "preflight.json").read_text(encoding="utf-8"))
    projections = json.loads((HERE / "t5-projections.json").read_text(encoding="utf-8"))

    manifest = dict(raw)
    manifest.update(
        {
            "stage": 2,
            "base_head": BASE_HEAD,
            "comparison_source": "docs/reviews/461-scenery-mobile/manifest.json",
            "harness_manifest": {
                "path": "harness-manifest.json",
                "sha256": sha256(HARNESS_MANIFEST),
                "authored_stage": 1,
                "note": "Unchanged Stage 1 harness output retained verbatim.",
            },
            "placement_compiler_sha256": COMPILER_SHA256,
            "preflight": preflight,
            "grade_contact_coverage": {
                "act": 1,
                "seed": 717,
                "compiled_origins": projections["scenery_count"],
                "in_grade_rect_origins": projections["in_grade_rect_count"],
                "out_of_grade_rect_origins": projections["out_of_grade_rect_count"],
                "domain_rule": "Clause 1 applies only where world XZ has a containing texel in the locked grade rect.",
            },
        }
    )
    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"manifest.json {sha256(MANIFEST)}")
    print(f"harness-manifest.json {sha256(HARNESS_MANIFEST)}")


if __name__ == "__main__":
    main()

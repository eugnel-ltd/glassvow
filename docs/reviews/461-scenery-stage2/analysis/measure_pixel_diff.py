#!/usr/bin/env python3
"""Report diagnostic per-frame RGB deltas from Stage 1 to Stage 2."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


HERE = Path(__file__).resolve().parent
PACKET = HERE.parent
ROOT = PACKET.parents[2]
BASELINE = ROOT / "docs/reviews/461-scenery-mobile"
OUTPUT = HERE / "stage1-stage2-pixel-diff.json"


def main() -> None:
    current_manifest = json.loads((PACKET / "manifest.json").read_text(encoding="utf-8"))
    baseline_manifest = json.loads((BASELINE / "manifest.json").read_text(encoding="utf-8"))
    baseline = {str(row["frame_id"]): row for row in baseline_manifest["frames"]}
    rows: list[dict[str, object]] = []
    for current in current_manifest["frames"]:
        frame_id = str(current["frame_id"])
        prior = baseline[frame_id]
        with Image.open(PACKET / str(current["file"])) as image:
            after = np.asarray(image.convert("RGB"), dtype=np.int16)
        with Image.open(BASELINE / str(prior["file"])) as image:
            before = np.asarray(image.convert("RGB"), dtype=np.int16)
        assert after.shape == before.shape
        absolute = np.abs(after - before)
        changed = np.any(absolute != 0, axis=2)
        rows.append(
            {
                "frame_id": frame_id,
                "file": current["file"],
                "changed_pixels": int(changed.sum()),
                "total_pixels": int(changed.size),
                "changed_pixel_fraction": round(float(changed.mean()), 8),
                "mean_absolute_rgb_channel_delta": round(float(absolute.mean()), 6),
                "maximum_rgb_channel_delta": int(absolute.max()),
            }
        )
    payload = {
        "schema": 1,
        "issue": 461,
        "stage": 2,
        "diagnostic_only": True,
        "baseline": "docs/reviews/461-scenery-mobile",
        "frames": rows,
    }
    OUTPUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(payload, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

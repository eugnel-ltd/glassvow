#!/usr/bin/env python3
"""Focused Act I grade pixel/checker assertions (#294 candidate). Not a production scan."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools"))
from map_asset_checks import (  # noqa: E402
    check_grade, hue_distance, import_findings, low_frequency_residual, pixels_of,
)

PNG = ROOT / "assets/art/map/grades/act1-grade.png"
ROW = {
    "width": 512, "height": 256,
    "palette_arc": {"near": 0.95, "far": 0.88, "corridor": 0.98, "tolerance": 0.1},
}
# World (22,0) under GRADE_MIN=(-24,-12), GRADE_SIZE=(48,24), 512x256 texel centres.
TERMINUS_UV = ((22.0 + 24.0) / 48.0, (0.0 + 12.0) / 24.0)
GRADE_HF_MAX = 0.035


def _fail(errors: list[str], ok: bool, detail: str) -> None:
    if not ok:
        errors.append(detail)


def main() -> int:
    errors: list[str] = []
    if not PNG.is_file():
        print("FAIL missing", PNG.relative_to(ROOT), file=sys.stderr)
        return 1
    mode, w, h, px = pixels_of(PNG)
    _fail(errors, mode == "RGBA", f"mode {mode} != RGBA")
    _fail(errors, (w, h) == (512, 256), f"size {w}x{h} != 512x256")
    alpha = [p[3] for p in px]
    _fail(errors, min(alpha) < 250, f"contact empty min_a={min(alpha)}")
    _fail(errors, max(alpha) >= 250, f"open mask empty max_a={max(alpha)}")
    tx = min(w - 1, max(0, int(TERMINUS_UV[0] * w - 0.5)))
    ty = min(h - 1, max(0, int(TERMINUS_UV[1] * h - 0.5)))
    seat = min(px[y * w + x][3] for y in range(ty - 1, ty + 2) for x in range(tx - 1, tx + 2)
               if 0 <= x < w and 0 <= y < h)
    _fail(errors, seat < 250, f"terminus seat ({tx},{ty}) alpha {seat} is open")
    residual = low_frequency_residual(PNG)
    _fail(errors, residual <= GRADE_HF_MAX, f"RGB residual {residual:.4f} > {GRADE_HF_MAX}")
    found = check_grade(PNG, PNG.relative_to(ROOT).as_posix(), ROW)
    pixel_gates = {item.gate for item in found} - {"compression", "high-quality", "mipmaps"}
    _fail(errors, not pixel_gates, f"check_grade pixel {found}")
    sidecar = PNG.with_name(PNG.name + ".import")
    import_report = import_findings(PNG, PNG.relative_to(ROOT).as_posix()) if sidecar.is_file() else [
        type("F", (), {"gate": "sidecar", "detail": "generated .import absent"})()
    ]
    digest = hashlib.sha256(PNG.read_bytes()).hexdigest()
    report = {
        "path": str(PNG.relative_to(ROOT)),
        "sha256": digest,
        "mode": mode, "width": w, "height": h,
        "alpha_min": min(alpha), "alpha_max": max(alpha),
        "contact_texels": sum(a < 250 for a in alpha),
        "open_texels": sum(a >= 250 for a in alpha),
        "terminus_texel": [tx, ty], "terminus_alpha_min_3x3": seat,
        "low_frequency_residual": round(residual, 6),
        "check_grade": [f"{item.gate}: {item.detail}" for item in found],
        "import": [f"{item.gate}: {item.detail}" for item in import_report],
        "pixel_ok": not errors,
    }
    print(json.dumps(report, indent=2))
    if errors:
        print("FAIL", *errors, sep="\n", file=sys.stderr)
        return 1
    print("act1-grade pixel assertions OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

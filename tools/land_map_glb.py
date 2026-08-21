#!/usr/bin/env python3
"""Copy a Studio GLB onto a map-kit path and capture a 20-placement review.

Does not generate meshes. Does not call the Tripo API. Default landing does
not write canonical provenance. An accepted row is written only by an
explicit --accept-signed-capture + --reviewer step after the exact PNG exists.
"""
from __future__ import annotations

import argparse
import hashlib
import inspect
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "tools"))
from map_asset_checks import inspect_glb  # noqa: E402

HKT = timezone(timedelta(hours=8))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def dump_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n")


def manifest_row(asset_id: str) -> dict[str, Any]:
    data = load_json(REPO / "assets/art/map/map-assets.json")
    for row in data["assets"]:
        if row["id"] == asset_id:
            return row
    raise SystemExit(f"asset_id {asset_id} not in map-assets.json")


def run(cmd: list[str], timeout: int = 300) -> str:
    proc = subprocess.run(
        cmd, cwd=str(REPO), capture_output=True, text=True, timeout=timeout, check=False,
    )
    if proc.returncode != 0:
        tail = (proc.stderr or proc.stdout or "").strip()[-1200:]
        raise RuntimeError(f"{' '.join(cmd[:4])} rc={proc.returncode}: {tail}")
    return (proc.stdout or "") + (proc.stderr or "")


def should_append_provenance(accept_signed_capture: Path | None) -> bool:
    """Default landing never writes a canonical row."""
    return accept_signed_capture is not None


def validate_signed_acceptance(reviewer: str | None, capture: Path | None) -> tuple[str, Path]:
    """Refuse to invent a reviewer or accept a missing capture."""
    if reviewer is None or not str(reviewer).strip():
        raise ValueError(
            "--reviewer is required to write accepted provenance; refusing to default to fol2")
    if capture is None:
        raise ValueError("--accept-signed-capture is required to write provenance")
    if not capture.is_file():
        raise ValueError(f"signed capture missing: {capture}")
    return str(reviewer).strip(), capture


def append_provenance(
    asset_id: str,
    dest: Path,
    src: Path,
    concept: Path,
    task_id: str,
    extras: dict[str, Any],
    *,
    reviewer: str,
    signed_capture: Path,
    ledger: Path | None = None,
) -> None:
    reviewer, signed_capture = validate_signed_acceptance(reviewer, signed_capture)
    path = ledger or (REPO / "assets/art/map/provenance.json")
    data = load_json(path)
    paid = data.get("paid_product") or {}
    if paid.get("product") != "Studio" or paid.get("api_forbidden") is not True:
        raise RuntimeError("paid_product is not Studio with api_forbidden true")
    verdicts = (data.get("record_schema") or {}).get("verdicts")
    if verdicts != ["accepted", "rejected"]:
        raise RuntimeError("record_schema.verdicts is not accepted/rejected")
    source_sha = sha256(src)
    final_sha = sha256(dest)
    concept_sha = sha256(concept) if concept.is_file() else ""
    capture_rel = signed_capture
    try:
        capture_rel = signed_capture.resolve().relative_to(REPO)
    except ValueError:
        capture_rel = signed_capture
    edits = list(extras.get("edits") or [
        "land_map_glb.py copy; Studio Export GLB kept if it already meets the ordinary contract",
    ])
    edits.append(
        f"accepted after signed capture {capture_rel.as_posix()} sha256 {sha256(signed_capture)}"
    )
    record = {
        "asset_id": asset_id,
        "source": "Studio",
        "created_at": datetime.now(HKT).isoformat(timespec="seconds"),
        "license": "Tripo Studio Pro commercial grant (paid product Studio, not API)",
        "source_sha256": source_sha,
        "final_sha256": final_sha,
        "edits": edits,
        "reviewer": reviewer,
        "verdict": "accepted",
        "task_id": task_id,
        "face_limit": 1500,
        "texture": False,
        "pbr": False,
        "concept_path": str(concept.relative_to(REPO)) if concept.is_file() and concept.is_relative_to(REPO)
        else str(concept),
        "concept_sha256": concept_sha,
        "land_method": extras.get("land_method") or "studio_download",
        "polycount_target": 1500,
    }
    if extras.get("faces_reported") is not None:
        record["faces_reported"] = extras["faces_reported"]
    records = [row for row in data.get("records") or [] if row.get("asset_id") != asset_id]
    records.append(record)
    data["records"] = records
    dump_json(path, data)


def validate_review_ticket(ticket: str | None, no_review: bool) -> str | None:
    """Fail closed: no implicit #292. Explicit digits only, unless --no-review."""
    if no_review:
        return None
    if ticket is None or not str(ticket).strip():
        raise ValueError("--review-ticket is required; refusing to default to closed #292")
    text = str(ticket).strip()
    if not text.isdigit() or int(text) <= 0:
        raise ValueError(
            f"--review-ticket must be a positive issue number, not {ticket!r}")
    return text


def review_png(dest: Path, asset_id: str, ticket: str) -> Path:
    ticket = validate_review_ticket(ticket, False) or ticket
    png = REPO / "docs/reviews" / ticket / f"{asset_id}-20.png"
    png.parent.mkdir(parents=True, exist_ok=True)
    rel = dest.resolve().relative_to(REPO)
    cmd = [
        os.environ.get("GODOT", "godot"),
        "--path", str(REPO),
        "--position", os.environ.get("GLASSVOW_SHOT_POSITION", "-4000,-4000"),
        "-s", "res://tools/raster_map_silhouette.gd", "--",
        f"--glb=res://{rel.as_posix()}",
        "--out=/tmp/map-sil-review",
        f"--review=res://docs/reviews/{ticket}/{asset_id}-20.png",
    ]
    run(cmd, timeout=240)
    if not png.is_file():
        raise RuntimeError(f"20-placement PNG missing: {png}")
    return png


def gates() -> str:
    chunks: list[str] = []
    chunks.append(run(["bash", "tools/check_imports.sh"], timeout=180))
    chunks.append(run(["bash", "tools/check_scripts.sh"], timeout=180))
    suite = run(
        [os.environ.get("GODOT", "godot"), "--headless", "-s", "res://tests/run_all.gd"],
        timeout=180,
    )
    if "PASS" not in suite:
        raise RuntimeError("test suite did not print PASS")
    chunks.append(suite)
    chunks.append(run([sys.executable, "tools/check_map_assets.py"], timeout=180))
    chunks.append(run([sys.executable, "tools/check_anchors.py"], timeout=60))
    chunks.append(run([sys.executable, "tools/check_benchmark_freeze.py"], timeout=60))
    return "\n".join(chunks)


def main() -> int:
    if "--self-test" in sys.argv:
        return self_test()
    parser = argparse.ArgumentParser(description="Land a Studio GLB onto a map kit path")
    parser.add_argument("--asset", required=True)
    parser.add_argument("--src", required=True, type=Path)
    parser.add_argument("--concept", type=Path)
    parser.add_argument("--task-id", default="")
    parser.add_argument("--land-method", default="studio_download")
    parser.add_argument(
        "--edit",
        action="append",
        default=[],
        help="provenance edits[] row; repeatable. Default is an unmodified Studio Export copy.",
    )
    parser.add_argument("--gates", action="store_true")
    parser.add_argument("--no-review", action="store_true")
    parser.add_argument(
        "--review-ticket",
        default=None,
        help="docs/reviews/<ticket>/ for the 20-placement PNG. Required unless --no-review. No default.",
    )
    parser.add_argument(
        "--accept-signed-capture",
        type=Path,
        default=None,
        help="Existing signed 20-placement PNG. Required to write accepted provenance. No default.",
    )
    parser.add_argument(
        "--reviewer",
        default=None,
        help="Human who signed the capture. Required with --accept-signed-capture. No default.",
    )
    args = parser.parse_args()
    if args.accept_signed_capture is not None and not args.no_review:
        parser.error(
            "writing accepted provenance requires --no-review; capture first, then accept the signed PNG")
    if args.reviewer and args.accept_signed_capture is None:
        parser.error("--reviewer is only valid with --accept-signed-capture")
    if not args.no_review:
        try:
            args.review_ticket = validate_review_ticket(args.review_ticket, False)
        except ValueError as error:
            parser.error(str(error))
    os.chdir(REPO)
    row = manifest_row(args.asset)
    src = args.src if args.src.is_absolute() else Path(args.src)
    if not src.is_file():
        print(json.dumps({"ok": False, "summary": f"source GLB missing: {src}"}))
        return 2
    dest = REPO / "assets/art/map" / row["path"]
    concept = args.concept
    if concept is None:
        concept = REPO / "assets/art/map-concepts" / f"{args.asset}.jpg"
    elif not concept.is_absolute():
        concept = REPO / concept
    findings = inspect_glb(src, str(src), row)
    if findings:
        print(json.dumps({
            "ok": False,
            "summary": "; ".join(str(item) for item in findings),
        }))
        return 2
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.resolve() != dest.resolve():
        shutil.copy2(src, dest)
    provenance_written = False
    if should_append_provenance(args.accept_signed_capture):
        capture = args.accept_signed_capture
        if not capture.is_absolute():
            capture = REPO / capture
        reviewer, capture = validate_signed_acceptance(args.reviewer, capture)
        append_provenance(
            args.asset, dest, src, concept, args.task_id,
            {"land_method": args.land_method, "edits": args.edit or [
                "land_map_glb.py copy of Studio Export GLB; no blender pass",
            ]},
            reviewer=reviewer,
            signed_capture=capture,
        )
        provenance_written = True
    review = None if args.no_review else str(
        review_png(dest, args.asset, args.review_ticket).relative_to(REPO)
    )
    gate_out = ""
    if args.gates:
        gate_out = gates()
    print(json.dumps({
        "ok": True,
        "summary": f"landed {dest.relative_to(REPO)}" + ("; gates ran" if args.gates else ""),
        "glb_path": str(dest.relative_to(REPO)),
        "dest_path": str(dest.relative_to(REPO)),
        "land_method": args.land_method,
        "task_id": args.task_id,
        "review_path": review,
        "provenance_written": provenance_written,
        "gate_tail": gate_out[-400:] if gate_out else "",
    }))
    return 0


def self_test() -> int:
    errors: list[str] = []
    try:
        validate_review_ticket(None, False)
        errors.append("missing ticket did not fail")
    except ValueError:
        print("self-test review-ticket: correctly failed missing")
    try:
        validate_review_ticket("", False)
        errors.append("empty ticket did not fail")
    except ValueError:
        print("self-test review-ticket: correctly failed empty")
    try:
        validate_review_ticket("../292", False)
        errors.append("path ticket did not fail")
    except ValueError:
        print("self-test review-ticket: correctly failed non-digits")
    try:
        validate_review_ticket("292", False)
        print("self-test review-ticket: explicit 292 allowed")
    except ValueError as error:
        errors.append(f"explicit 292 rejected: {error}")
    if validate_review_ticket("293", False) != "293":
        errors.append("293 was not accepted")
    else:
        print("self-test review-ticket: 293 accepted")
    if validate_review_ticket(None, True) is not None:
        errors.append("--no-review still required a ticket")
    else:
        print("self-test review-ticket: --no-review skips ticket")
    if should_append_provenance(None):
        errors.append("default landing would write provenance")
    else:
        print("self-test default-land: does not write provenance")
    try:
        validate_signed_acceptance(None, Path("/tmp/missing-signed.png"))
        errors.append("missing reviewer did not fail")
    except ValueError:
        print("self-test accept: correctly failed missing reviewer")
    try:
        validate_signed_acceptance("", Path("/tmp/missing-signed.png"))
        errors.append("empty reviewer did not fail")
    except ValueError:
        print("self-test accept: correctly failed empty reviewer")
    try:
        validate_signed_acceptance("fol2", None)
        errors.append("missing capture did not fail")
    except ValueError:
        print("self-test accept: correctly failed missing capture")
    try:
        validate_signed_acceptance("fol2", Path("/tmp/does-not-exist-signed-capture.png"))
        errors.append("absent capture file did not fail")
    except ValueError:
        print("self-test accept: correctly failed absent capture file")
    try:
        append_provenance(
            "shared-standing-monument", REPO / "x.glb", REPO / "x.glb",
            REPO / "x.jpg", "", {},
        )
        errors.append("append_provenance without reviewer/capture did not fail")
    except TypeError:
        print("self-test append_provenance: missing human accept args fail-closed")
    live = REPO / "assets/art/map/provenance.json"
    live_before = live.read_text()
    with tempfile.TemporaryDirectory() as raw:
        tmp = Path(raw)
        capture = tmp / "signed.png"
        capture.write_bytes(b"png")
        glb = tmp / "mesh.glb"
        glb.write_bytes(b"glb")
        concept = tmp / "c.jpg"
        concept.write_bytes(b"jpg")
        ledger = tmp / "provenance.json"
        shutil.copy2(live, ledger)
        append_provenance(
            "shared-road-slab-a", glb, glb, concept, "t", {},
            reviewer="fol2", signed_capture=capture, ledger=ledger,
        )
        if live.read_text() != live_before:
            errors.append("accept path mutated live provenance.json")
        written = load_json(ledger)
        row = next(r for r in written["records"] if r["asset_id"] == "shared-road-slab-a")
        if row.get("reviewer") != "fol2" or row.get("verdict") != "accepted":
            errors.append(f"accept path wrote {row.get('reviewer')}/{row.get('verdict')}")
        elif "shared-standing-monument" in {r.get("asset_id") for r in written["records"]}:
            errors.append("temp ledger gained a monument row")
        else:
            print("self-test accept-path: writes accepted only to the supplied ledger")
    if live.read_text() != live_before:
        errors.append("self-test left live provenance.json changed")
    else:
        print("self-test live provenance.json unchanged")
    append_src = inspect.getsource(append_provenance)
    if '"reviewer": "fol2"' in append_src or "'reviewer': 'fol2'" in append_src:
        errors.append("append_provenance still hard-codes reviewer fol2")
    else:
        print("self-test append_provenance: reviewer is the explicit argument")
    main_src = inspect.getsource(main)
    if "append_provenance(" in main_src and "should_append_provenance" not in main_src:
        errors.append("main calls append_provenance without the accept gate")
    else:
        print("self-test main: provenance write is gated on --accept-signed-capture")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("self-test FAILED", file=sys.stderr)
        return 1
    print("self-test OK (review-ticket fail-closed; default land writes no provenance)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

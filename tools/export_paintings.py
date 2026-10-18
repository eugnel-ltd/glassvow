#!/usr/bin/env python3
"""Export a checked PCK; reject incomplete/remapped/oversized painting output.

Generated resources have no .import files. The cold-pack audit is mandatory;
the ordinary import walker and editor error messages cannot approve this build.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
INPUTS = ROOT / "tools/painting_upload_inputs.json"
CONTRACT = ROOT / "tests/test_painting_upload_pages.gd"
AUDIT = ROOT / "tools/audit_painting_pack.gd"


def run(command: list[str], cwd: Path, env: dict[str, str], log: Path) -> str:
    result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True)
    text = result.stdout + result.stderr
    log.write_text(text)
    if result.returncode or re.search(r"(?m)^SCRIPT ERROR:|^Parse Error:", text):
        raise ValueError(f"command failed ({result.returncode}); see {log}")
    return text


def preflight() -> list[dict]:
    for name in ("XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_CONFIG_HOME"):
        if not os.environ.get(name):
            raise ValueError(f"set isolated {name} before exporting")
    override = (ROOT / "override.cfg").read_text()
    if "[application]" not in override or "config/use_custom_user_dir=true" not in override:
        raise ValueError("source checkout needs its complete isolated application override")
    if not re.search(r'^config/custom_user_dir_name="glassvow-[^"\n]+"$', override, re.M):
        raise ValueError("source checkout needs its own custom user directory")
    rows = json.loads(INPUTS.read_text())
    if len(rows) != 21 or len({r["path"] for r in rows}) != 21:
        raise ValueError("expected exactly 21 distinct source paintings")
    for row in rows:
        path = ROOT / row["path"].removeprefix("res://")
        for file, key in ((path, "source_sha256"), (Path(str(path) + ".import"), "import_sha256")):
            if hashlib.sha256(file.read_bytes()).hexdigest() != row[key]:
                raise ValueError(f"immutable source/import mismatch: {file}")
    return rows


def audit(engine: str, pack: Path, temporary: Path, env: dict[str, str], log: Path) -> None:
    empty = temporary / "empty-resource-root"
    empty.mkdir()
    # Godot can read override.cfg beside --main-pack, independently of cwd.
    (pack.parent / "override.cfg").write_text((ROOT / "override.cfg").read_text())
    output = run([engine, "--headless", "--path", str(empty), "--main-pack", str(pack),
                  "--script", str(AUDIT), "--", str(CONTRACT), str(INPUTS)], empty, env, log)
    if "PAINTING_PACK_PASS logical=21 physical_leaves=42 limit=4194304" not in output:
        raise ValueError(f"pack audit has no complete success marker; see {log}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preset", default="iOS")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--audit-existing", type=Path)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    args = parser.parse_args()
    if bool(args.output) == bool(args.audit_existing):
        parser.error("choose --output NEW.pck or --audit-existing EXISTING.pck")
    target = (args.output or args.audit_existing).resolve()
    if target.suffix.lower() != ".pck":
        parser.error("the checked artifact must be a .pck")
    target.parent.mkdir(parents=True, exist_ok=True)
    if args.output and target.exists():
        parser.error("output already exists; preserve it and choose a new output")
    env = os.environ.copy()
    record = {"preset": args.preset, "pack": str(target), "passed": False,
              "contract_sha256": hashlib.sha256(CONTRACT.read_bytes()).hexdigest(),
              "inputs_sha256": hashlib.sha256(INPUTS.read_bytes()).hexdigest()}
    try:
        rows = preflight()
        version = subprocess.check_output([args.godot, "--version"], env=env, text=True).strip()
        stable = re.match(r"^(\d+)\.(\d+)\.(\d+)\.stable(?:\.|$)", version)
        if not stable or tuple(map(int, stable.groups())) < (4, 7, 2):
            raise ValueError(f"unsupported engine: {version}")
        record["engine"] = version
        with tempfile.TemporaryDirectory(prefix="glassvow-painting-export-") as scratch:
            temporary = Path(scratch)
            packdir = temporary / "pack"
            packdir.mkdir()
            packed = packdir / "paintings.pck"
            if args.audit_existing:
                shutil.copyfile(target, packed)
            else:
                receipt = temporary / "export-receipt.json"
                env["GLASSVOW_PAINTING_RECEIPT"] = str(receipt)
                run([args.godot, "--headless", "--editor", "--path", str(ROOT),
                     "--export-pack", args.preset, str(packed)], ROOT, env,
                    target.with_suffix(".export.log"))
                exported = json.loads(receipt.read_text())
                expected = {row["path"] for row in rows}
                if exported.get("failures") or set(exported.get("converted", {})) != expected:
                    raise ValueError("export plugin did not produce every bounded painting")
                record["export"] = exported
            audit(args.godot, packed, temporary, env, target.with_suffix(".audit.log"))
            preflight()  # Reject source/import drift while the editor was running.
            record["pack_sha256"] = hashlib.sha256(packed.read_bytes()).hexdigest()
            record["pack_bytes"] = packed.stat().st_size
            if args.output:
                shutil.move(str(packed), target)
            record["passed"] = True
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        record["error"] = str(error)
        print("PAINTING_BUILD_FAIL " + str(error), file=sys.stderr)
    target.with_suffix(".check.json").write_text(json.dumps(record, indent=2) + "\n")
    if record["passed"]:
        print("PAINTING_BUILD_PASS " + str(target))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

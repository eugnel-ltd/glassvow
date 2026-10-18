#!/usr/bin/env python3
"""Real export + independent cold-pack positives/negatives; no full suite."""
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
sys.path.insert(0, str(ROOT / "tests/support"))
import painting_pack as PCK


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preset", default="macOS")
    parser.add_argument("--reuse-export", type=Path)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    engine = env.get("GODOT", "godot")
    override = ROOT / "override.cfg"
    saved_override = override.read_bytes() if override.exists() else None
    results = []

    def run(name: str, command: list[str], expected: int = 0) -> str:
        completed = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True)
        text = completed.stdout + completed.stderr
        (out / (name + ".log")).write_text(text)
        results.append({"name": name, "command": command, "exit_code": completed.returncode,
                        "log_sha256": hashlib.sha256(text.encode()).hexdigest()})
        if completed.returncode != expected or re.search(r"(?m)^SCRIPT ERROR:", text):
            raise ValueError(f"{name} exit {completed.returncode}, expected {expected}; see {out}")
        return text

    try:
        with tempfile.TemporaryDirectory(prefix="glassvow-painting-contract-") as scratch:
            temp = Path(scratch)
            for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"),
                                ("XDG_STATE_HOME", "state"), ("XDG_CONFIG_HOME", "config")):
                folder = temp / suffix
                folder.mkdir()
                env[key] = str(folder)
            override.write_text('[application]\nconfig/use_custom_user_dir=true\n'
                                'config/custom_user_dir_name="glassvow-painting-contract"\n')
            pack = args.reuse_export.resolve() if args.reuse_export else out / "export.pck"
            if not args.reuse_export:
                run("export", [sys.executable, "tools/export_paintings.py", "--preset", args.preset,
                               "--output", str(pack), "--godot", engine])
            files = PCK.read(pack)
            prefix = "res://_paged_paintings/"
            runtime = "res://presentation/stage/paged_painting_texture.gd"
            script_remap = files[runtime + ".remap"].decode()
            compiled = re.search(r'^path="([^"]+)"$', script_remap, re.M)[1]
            inputs = json.loads((ROOT / "tools/painting_upload_inputs.json").read_text())
            minimal = {key: value for key, value in files.items()
                       if key.startswith(prefix) or key in {runtime + ".remap", compiled}
                       or key in {row["path"] + ".remap" for row in inputs}}
            minimal["res://project.godot"] = ('config_version=5\n[application]\n'
                'config/features=PackedStringArray("4.7")\n').encode()
            positive = temp / "positive.pck"
            PCK.write(positive, minimal)
            run("minimal-positive", [sys.executable, "tools/export_paintings.py", "--audit-existing",
                                     str(positive), "--godot", engine])
            shutil.copyfile(positive.with_suffix(".audit.log"), out / "minimal-positive.audit.log")
            shutil.copyfile(positive.with_suffix(".check.json"), out / "minimal-positive.check.json")
            negative_resources = temp / "negative-resources"
            run("negative-resources", [engine, "--headless", "-s",
                "res://tests/support/painting_pack_negative.gd", "--", str(negative_resources)])
            first = inputs[0]
            virtual = prefix + first["path"].removeprefix("res://assets/art/").removesuffix(".png") + ".res"
            cases = []
            for kind, marker in (("oversized", "uploads 6291456 bytes"),
                                 ("missing-page", "exactly two physical leaves"),
                                 ("broken-gutter", "top filter row matches original")):
                altered = dict(minimal)
                altered[virtual] = (negative_resources / (kind + ".res")).read_bytes()
                cases.append((kind, altered, marker))
            altered = dict(minimal)
            del altered[first["path"] + ".remap"]
            cases.append(("missing-remap", altered, "missing or wrong original-path remap"))
            altered = dict(minimal)
            altered[prefix + "unlisted.res"] = minimal[virtual]
            cases.append(("unexpected-leaf", altered, "generated namespace differs"))
            altered = dict(minimal)
            altered[first["artifact"]] = (ROOT / first["artifact"].removeprefix("res://")).read_bytes()
            cases.append(("source-exclusion-loophole", altered, "oversized source/import artifact remains packed"))
            altered = dict(minimal)
            altered[prefix + "manifest.json"] = b"{}"
            cases.append(("forged-empty-manifest", altered, "generated namespace differs"))
            legacy = {"res://project.godot": minimal["res://project.godot"]}
            for row in inputs:
                source = ROOT / row["path"].removeprefix("res://")
                legacy[row["path"] + ".import"] = Path(str(source) + ".import").read_bytes()
                legacy[row["artifact"]] = (ROOT / row["artifact"].removeprefix("res://")).read_bytes()
            cases.append(("legacy-single-upload", legacy, "uploads 6291456 bytes"))
            for kind, altered, marker in cases:
                negative = temp / (kind + ".pck")
                PCK.write(negative, altered)
                results.append({"negative": kind, "pack_sha256": hashlib.sha256(negative.read_bytes()).hexdigest()})
                run(kind, [sys.executable, "tools/export_paintings.py", "--audit-existing",
                           str(negative), "--godot", engine], 1)
                audit_log = negative.with_suffix(".audit.log").read_text()
                (out / (kind + ".audit.log")).write_text(audit_log)
                if marker not in audit_log:
                    raise ValueError(f"{kind} did not fail its named actual contract: {marker}")
                negative.unlink()
            print("PAINTING_EXPORT_CONTRACT_PASS positive=1 negatives=8")
    except (OSError, ValueError, KeyError) as error:
        results.append({"error": str(error)})
        print("PAINTING_EXPORT_CONTRACT_FAIL " + str(error), file=sys.stderr)
        return 1
    finally:
        if saved_override is None:
            override.unlink(missing_ok=True)
        else:
            override.write_bytes(saved_override)
        (out / "result.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

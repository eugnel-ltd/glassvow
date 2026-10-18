#!/usr/bin/env python3
"""A valid visible pair cannot hide a third oversized upload in its resource."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests/support"))
import painting_pack as PCK


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    engine = env.get("GODOT", "godot")
    override = ROOT / "override.cfg"
    saved = override.read_bytes() if override.exists() else None
    record = {}
    try:
        with tempfile.TemporaryDirectory(prefix="glassvow-hidden-texture-") as scratch:
            temporary = Path(scratch)
            for key, suffix in (("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache"),
                                ("XDG_STATE_HOME", "state"), ("XDG_CONFIG_HOME", "config")):
                directory = temporary / suffix
                directory.mkdir()
                env[key] = str(directory)
            override.write_text('[application]\nconfig/use_custom_user_dir=true\n'
                                'config/custom_user_dir_name="glassvow-hidden-texture-contract"\n')
            resources = temporary / "resources"
            generated = subprocess.run([engine, "--headless", "-s",
                "res://tests/support/painting_pack_negative.gd", "--", str(resources)],
                cwd=ROOT, env=env, capture_output=True, text=True)
            text = generated.stdout + generated.stderr
            (out / "factory.log").write_text(text)
            if generated.returncode or "SCRIPT ERROR:" in text:
                raise ValueError("negative resource did not generate")
            files = PCK.read(args.pack.resolve())
            prefix = "res://_paged_paintings/"
            runtime = "res://presentation/stage/paged_painting_texture.gd"
            compiled = re.search(r'^path="([^"]+)"$', files[runtime + ".remap"].decode(), re.M)[1]
            rows = json.loads((ROOT / "tools/painting_upload_inputs.json").read_text())
            selected = {key: value for key, value in files.items()
                        if key.startswith(prefix) or key in {runtime + ".remap", compiled}
                        or key in {row["path"] + ".remap" for row in rows}}
            selected["res://project.godot"] = b'config_version=5\n[application]\nconfig/features=PackedStringArray("4.7")\n'
            virtual = prefix + rows[0]["path"].removeprefix("res://assets/art/").removesuffix(".png") + ".res"
            selected[virtual] = (resources / "hidden-oversized.res").read_bytes()
            bad = out / "hidden-oversized.pck"
            PCK.write(bad, selected)
            record["pack_sha256"] = hashlib.sha256(bad.read_bytes()).hexdigest()
            checked = subprocess.run([sys.executable, "tools/export_paintings.py",
                "--audit-existing", str(bad), "--godot", engine], cwd=ROOT,
                env=env, capture_output=True, text=True)
            (out / "checked-build.log").write_text(checked.stdout + checked.stderr)
            record["checked_exit"] = checked.returncode
            audit = bad.with_suffix(".audit.log").read_text()
            if checked.returncode != 1:
                raise ValueError("hidden oversized ImageTexture passed the shipping guard")
            if "unexpected serialized texture resource graph" not in audit:
                raise ValueError("the hidden resource was not rejected by its actual resource graph")
            print("PAINTING_HIDDEN_TEXTURE_REJECTED")
            return 0
    except (OSError, ValueError, KeyError) as error:
        record["error"] = str(error)
        print("PAINTING_HIDDEN_TEXTURE_FAIL " + str(error), file=sys.stderr)
        return 1
    finally:
        if saved is None:
            override.unlink(missing_ok=True)
        else:
            override.write_bytes(saved)
        (out / "result.json").write_text(json.dumps(record, indent=2) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())

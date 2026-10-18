#!/usr/bin/env python3
"""Check the boot-only patch against both exact governed source pins; no build."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def check(patch: Path, manifest: Path, output: Path, offline: Path | None) -> None:
    spec = json.loads(manifest.read_text())
    patch_data = patch.read_bytes()
    for line in patch_data.decode().splitlines():
        if line.startswith("+") and not line.startswith("+++ "):
            if line[1:].rstrip() != line[1:]:
                raise ValueError("introduced native source has trailing whitespace")
    changed = [line[6:] for line in patch_data.decode().splitlines() if line.startswith("+++ b/")]
    permitted = set(next(iter(spec["pins"].values()))) | set(spec["new_paths"])
    if set(changed) != permitted or len(changed) != len(permitted):
        raise ValueError("patch paths differ from the bounded native boot surface")
    report = {"schema": 1, "status": "running", "scope": "source identity and clean application only",
              "patch_sha256": sha(patch_data), "manifest_sha256": sha(manifest.read_bytes()), "pins": {}}
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        for pin, files in spec["pins"].items():
            with tempfile.TemporaryDirectory(prefix="glassvow-boot-patch-") as temporary:
                tree = Path(temporary)
                input_hashes = {}
                for relative, expected in files.items():
                    if offline:
                        data = (offline / pin / relative).read_bytes()
                    else:
                        url = f"https://raw.githubusercontent.com/godotengine/godot/{pin}/{relative}"
                        with urllib.request.urlopen(url, timeout=30) as response:
                            data = response.read(1024 * 1024)
                    actual = sha(data)
                    if actual != expected:
                        raise ValueError(f"pinned source identity mismatch: {pin}:{relative}")
                    destination = tree / relative
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(data)
                    input_hashes[relative] = actual
                # git apply is a local file operation here, without a repository,
                # branch, index, remote or source checkout mutation.
                for flags in (["--check"], []):
                    subprocess.run(["git", "apply", *flags, str(patch.resolve())],
                                   cwd=tree, check=True, timeout=30, capture_output=True)
                report["pins"][pin] = {
                    "input_sha256": input_hashes,
                    "patched_sha256": {relative: sha((tree / relative).read_bytes()) for relative in changed},
                    "clean_application": True}
        report["status"] = "pass"
    except Exception as error:
        report["status"] = "failed"
        report["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        output.write_text(json.dumps(report, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--patch", type=Path, default=Path("tools/godot/patches/glassvow-661-native-boot-upload-cap.patch"))
    parser.add_argument("--manifest", type=Path, default=Path("tools/godot/native_boot_upload/source-manifest.json"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--offline-sources", type=Path)
    args = parser.parse_args()
    check(args.patch, args.manifest, args.output, args.offline_sources)


if __name__ == "__main__":
    main()

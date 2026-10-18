#!/usr/bin/env python3
"""Compile source-bound boot call controls without building or running Godot."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request

PIN = "ed1daf0bf001b61586d9930840f2f1394092c079"


def run(args):
    root = Path(__file__).resolve().parents[3]
    spec = json.loads((Path(__file__).with_name("source-manifest.json")).read_text())
    args.output.mkdir(parents=True, exist_ok=False)
    original = args.output / "original"
    expected = dict(spec["pins"][PIN])
    expected.update(spec["fixture_files"][PIN])
    for relative, digest in expected.items():
        if args.offline_sources:
            data = (args.offline_sources / PIN / relative).read_bytes()
        else:
            url = f"https://raw.githubusercontent.com/godotengine/godot/{PIN}/{relative}"
            with urllib.request.urlopen(url, timeout=30) as response:
                data = response.read(1024 * 1024)
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError("native fixture source identity mismatch: " + relative)
        target = original / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    defaults = (original / "core/config/project_settings.cpp").read_text()
    match = re.search(r'GLOBAL_DEF\(PropertyInfo\(Variant::INT, "rendering/rendering_device/staging_buffer/block_size_kb".*?\), (\d+)\);', defaults)
    if not match or int(match[1]) != 256:
        raise ValueError("capacity fixture requires the exact pinned 256 KiB default")
    patch = root / "tools/godot/patches/glassvow-661-native-boot-upload-cap.patch"
    subprocess.run([sys.executable, str(root / "tests/native/boot_upload_calls/run_gles_fixture.py"),
        "--source-root", str(original.resolve()), "--patch", str(patch),
        "--output", str((args.output / "gles").resolve()), "--sanitize"], check=True, timeout=100)
    relative = "servers/rendering/rendering_device.cpp"
    candidate = args.output / "candidate"
    destination = candidate / relative
    destination.parent.mkdir(parents=True)
    shutil.copyfile(original / relative, destination)
    subprocess.run(["git", "apply", "--include=" + relative, str(patch)],
                   cwd=candidate, check=True, timeout=20)
    result = subprocess.run([sys.executable, str(root / "tests/native/rd_boot_upload_capacity/run_fixture.py"),
        "--source", str(destination.resolve()), "--baseline-source", str((original / relative).resolve()),
        "--output", str((args.output / "rd.json").resolve())],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=150)
    (args.output / "rd.log").write_text(result.stdout)
    if result.returncode:
        print(result.stdout[-8000:])
        raise subprocess.CalledProcessError(result.returncode, result.args)
    report = json.loads((args.output / "rd.json").read_text())
    print("PASS native RD calls:", report["boot_cases"], "boot,", report["rejections"],
          "rejection,", report["normal_cases"], "ordinary cases; ordinary trace matches pinned original")
    (args.output / "result.json").write_text(json.dumps({
        "status": "pass", "source_pin": PIN, "source_sha256": expected,
        "patch_sha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
        "gles": "gles/result.json", "rd": "rd.json",
        "rd_fixture": "tests/native/rd_boot_upload_capacity",
        "superseded_rd_fixture": "tests/native/rd_boot_upload_calls (omitted finite capacity; preserved historical proposal)",
        "scope": "compiled exact native function bodies with recording backend; no engine/GPU/render proof"
    }, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--offline-sources", type=Path)
    run(parser.parse_args())

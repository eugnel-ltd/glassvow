#!/usr/bin/env python3
"""Bounded CI-only builds from one exact upstream archive; no installed engine changes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import time
import urllib.request

from verify import digest, require
from processes import run_logged

SOURCE_SHA = "ed1daf0bf001b61586d9930840f2f1394092c079"
SOURCE_URL = f"https://codeload.github.com/godotengine/godot/tar.gz/{SOURCE_SHA}"
SOURCE_ARCHIVE_SHA256 = "e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef"
FLAGS = ["platform=linuxbsd", "target=template_debug", "arch=x86_64", "optimize=speed",
         "debug_symbols=no", "tests=yes", "disable_path_overrides=no", "vulkan=yes", "opengl3=yes", "x11=yes",
         "wayland=no", "disable_3d=yes", "modules_enabled_by_default=no",
         "module_gdscript_enabled=yes", "module_glslang_enabled=yes",
         "module_text_server_fb_enabled=yes", "-j2"]


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def run(command, cwd, log, timeout):
    run_logged(command, log, timeout, cwd=cwd)


def tree_digest(directory):
    """Hash every extracted source path/byte before patching (not timestamps)."""
    hasher = hashlib.sha256()
    for path in sorted(directory.rglob("*")):
        relative = path.relative_to(directory).as_posix().encode()
        if path.is_symlink():
            data = b"link:" + os.readlink(path).encode()
        elif path.is_file():
            data = path.read_bytes()
        else:
            continue
        hasher.update(len(relative).to_bytes(8, "big") + relative)
        hasher.update(len(data).to_bytes(8, "big") + data)
    return hasher.hexdigest()


def download(path):
    deadline = time.monotonic() + 180
    with urllib.request.urlopen(SOURCE_URL, timeout=30) as response, path.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            require(time.monotonic() < deadline, "upstream source download exceeded 180 seconds")
            output.write(chunk)
            require(output.tell() <= 128 * 1024 * 1024, "source archive exceeded 128 MiB")


def extract(archive, directory):
    directory.mkdir(parents=True, exist_ok=False)
    with tarfile.open(archive) as source:
        members = source.getmembers()
        prefix = f"godot-{SOURCE_SHA}"
        for member in members:
            parts = Path(member.name).parts
            require(parts and parts[0] == prefix and ".." not in parts,
                    "unexpected archive root/path")
        # Ubuntu 24.04 supplies Python 3.12; data filtering refuses external
        # paths, device files and escaping links in the source archive.
        source.extractall(directory, filter="data")
    return directory / prefix


def build(args):
    require(not args.work.exists(), "build work directory must be new (no stale objects)")
    args.work.mkdir(parents=True)
    args.output.mkdir(parents=True, exist_ok=True)
    prerequisites = getattr(args, "prerequisite_patches", [])
    prerequisite_identity = [{"path": str(path.resolve()), "sha256": digest(path)}
                             for path in prerequisites]
    report = {"schema": 1, "status": "running", "source_sha": SOURCE_SHA,
              "source_url": SOURCE_URL, "flags": FLAGS,
              "runtime_test_configuration": {"purpose": "portable_component_proof",
                  "path_overrides": True, "scons_option": "disable_path_overrides=no",
                  "shipping_template_qualification": False},
              "product_ci_sha": os.environ.get("GITHUB_SHA"),
              "python_version": sys.version, "host": list(os.uname()),
              "scope": "Linux software-renderer component evidence, not shipping template proof",
              "patch_sha256": digest(args.patch), "observer_sha256": digest(args.observer),
              "prerequisite_patches": prerequisite_identity,
              "test_suite": args.test_suite, "builds": {}}
    if args.splash:
        report["splash_sha256"] = digest(args.splash)
    report_path = args.output / "build-manifest.json"
    write_json(report_path, report)
    try:
        report["compiler_version"] = subprocess.check_output(
            ["c++", "--version"], text=True, timeout=15).splitlines()[0]
        report["scons_version"] = subprocess.check_output(
            [sys.executable, "-m", "SCons", "--version"], text=True, timeout=15).splitlines()[0]
        archive = args.work / "upstream.tar.gz"
        if args.source_archive:
            archive.write_bytes(args.source_archive.read_bytes())
        else:
            download(archive)
        report["source_archive_sha256"] = digest(archive)
        require(report["source_archive_sha256"] == args.source_archive_sha256,
                "source archive hash differs from independently pinned download")
        write_json(report_path, report)
        original_tree = None
        for variant in ("baseline", "candidate"):
            tree = extract(archive, args.work / variant)
            version_source = (tree / "version.py").read_text()
            for field, expected in [("major", "4"), ("minor", "7"), ("patch", "2")]:
                require(re.search(rf"^{field}\s*=\s*{expected}\s*$", version_source, re.M),
                        "upstream version.py is not supported 4.7.2")
            require(re.search(r'^status\s*=\s*[\"\']stable[\"\']\s*$', version_source, re.M),
                    "upstream version.py is not stable")
            source_hash = tree_digest(tree)
            require(original_tree is None or original_tree == source_hash,
                    "baseline/candidate extracted sources differ")
            original_tree = source_hash
            variant_report = {"unmodified_source_tree_sha256": source_hash,
                              "version_py_sha256": digest(tree / "version.py"),
                              "applied_patches": []}
            report["builds"][variant] = variant_report
            for index, path in enumerate(prerequisites):
                require(digest(path) == prerequisite_identity[index]["sha256"],
                        "prerequisite patch changed after its identity was recorded")
                run(["patch", "--batch", "--forward", "--fuzz=0", "-p1", "--input", str(path.resolve())],
                    tree, args.output / f"{variant}-prerequisite-{index}.log", 30)
                variant_report["applied_patches"].append({"role": "prerequisite",
                    **prerequisite_identity[index], "source_tree_sha256": tree_digest(tree)})
            if variant == "candidate":
                run(["patch", "--batch", "--forward", "--fuzz=0", "-p1", "--input", str(args.patch.resolve())],
                    tree, args.output / "candidate-apply-patch.log", 30)
                variant_report["applied_patches"].append({"role": "production",
                    "path": str(args.patch.resolve()), "sha256": digest(args.patch),
                    "source_tree_sha256": tree_digest(tree)})
            variant_report["pre_observer_source_tree_sha256"] = tree_digest(tree)
            run([sys.executable, str(args.observer.resolve()), "--source-dir", str(tree.resolve())],
                tree, args.output / f"{variant}-instrument.log", 30)
            variant_report["instrumented_source_tree_sha256"] = tree_digest(tree)
            run([sys.executable, "-m", "SCons", *FLAGS], tree,
                args.output / f"{variant}-build.log", 1800)
            binaries = list((tree / "bin").glob("godot.linuxbsd.template_debug.x86_64*"))
            binaries = [path for path in binaries if path.is_file() and os.access(path, os.X_OK)
                        and not path.name.endswith((".debugsymbols", ".so"))]
            require(len(binaries) == 1, "cannot identify one newly built native executable")
            binary = binaries[0]
            version = subprocess.check_output([str(binary), "--version"], text=True, timeout=15).strip()
            require(version.startswith("4.7.2.stable.custom_build"), "unexpected built engine version")
            variant_report.update(binary=str(binary.resolve()), binary_sha256=digest(binary), version=version)
            write_json(report_path, report)
        candidate = report["builds"]["candidate"]["binary"]
        if args.test_suite:
            test_log = args.output / "native-contract-tests.log"
            run([candidate, "--test", "--test-suite=" + args.test_suite, "--no-skip"],
                args.work, test_log, 120)
            text = test_log.read_text(errors="replace")
            counts = re.search(r"test cases:\s*(\d+)\s*\|\s*(\d+) passed\s*\|\s*(\d+) failed", text)
            require(counts and int(counts[1]) > 0 and counts[1] == counts[2] and int(counts[3]) == 0,
                    "native filtered tests did not prove a nonempty passing suite")
            report["native_test_cases"] = int(counts[1])
            report["native_tests"] = {"status": "pass", "suite": args.test_suite}
        else:
            # Explicit library use by a component with a separate compiled test
            # protocol; an empty doctest filter must never run all engine tests.
            report["native_tests"] = {"status": "NOT RUN", "reason":
                "caller explicitly selected no doctest suite; separate component proof is required"}
        # Publish paths only after both fresh binaries and the selected gate exist.
        render_inputs = {
            "baseline": report["builds"]["baseline"]["binary"],
            "candidate": candidate}
        if args.splash:
            render_inputs["splash"] = str(args.splash.resolve())
        write_json(args.output / "render-inputs.json", render_inputs)
        report["status"] = "pass"
    except Exception as error:
        report["status"] = "failed_or_inconclusive"
        report["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        write_json(report_path, report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--production-patch", "--patch", dest="patch", type=Path,
                        default=Path("tools/godot/patches/glassvow-661-native-boot-upload-cap.patch"))
    parser.add_argument("--observer", type=Path,
                        default=Path("tools/godot/native_boot_upload/observer.py"))
    parser.add_argument("--prerequisite-patch", dest="prerequisite_patches", action="append",
                        type=Path, default=[], help="ordered patch applied identically to both variants")
    parser.add_argument("--test-suite", default="GlassvowBootUpload")
    parser.add_argument("--splash", type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source-archive", type=Path)
    parser.add_argument("--source-archive-sha256", default=SOURCE_ARCHIVE_SHA256)
    build(parser.parse_args())


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Compile only exact extracted upload methods against a recording backend."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def extract(source: str, signature: str) -> str:
    start = source.index(signature)
    opening = source.index("{", start)
    # These bounded methods contain no braces inside quoted messages/comments.
    level = 0
    for i in range(opening, len(source)):
        level += (source[i] == "{") - (source[i] == "}")
        if level == 0:
            return source[start:i + 1] + "\n"
    raise ValueError(f"unterminated method: {signature}")


def run(source_path: Path, mode: str, compiler: str) -> dict:
    source_bytes = source_path.read_bytes()
    source = source_bytes.decode()
    signatures = ["static _ALWAYS_INLINE_ void _copy_region(",
                  "static _ALWAYS_INLINE_ void _copy_region_block_or_regular(",
                  "Error RenderingDevice::texture_update("]
    candidate = "Error RenderingDevice::_texture_update(" in source
    if candidate:
        signatures += ["Error RenderingDevice::texture_update_boot_image(",
                       "Error RenderingDevice::_texture_update("]
    elif mode != "normal":
        raise ValueError("boot method absent; run original source with --mode normal")
    extracted = "\n".join(extract(source, signature) for signature in signatures)
    here = Path(__file__).resolve().parent
    metadata = {"source": str(source_path.resolve()),
                "source_sha256": hashlib.sha256(source_bytes).hexdigest(),
                "extracted_sha256": hashlib.sha256(extracted.encode()).hexdigest(),
                "exact_extracted_methods": signatures,
                "compiler": compiler, "sanitizers": ["address", "undefined"],
                "fixture_sha256": {
                    name: hashlib.sha256((here / name).read_bytes()).hexdigest()
                    for name in ("run_fixture.py", "rd_stub.h", "rd_cases.cpp")},
                "method_sha256": {
                    signature: hashlib.sha256(extract(source, signature).encode()).hexdigest()
                    for signature in signatures}}
    with tempfile.TemporaryDirectory(prefix="rd-recording-capacity-v2-") as folder:
        root = Path(folder)
        (root / "actual_source.inc").write_text(extracted)
        executable = root / "rd-recording"
        command = [compiler, "-std=c++17", "-O1", "-g", "-fsanitize=address,undefined",
                   "-fno-omit-frame-pointer", "-Wall", "-Wextra", "-Werror",
                   "-Wno-unused-parameter", f"-DFIXTURE_HAS_BOOT={int(candidate)}",
                   "-I", str(root), "-I", str(here), str(here / "rd_cases.cpp"),
                   "-o", str(executable)]
        compiled = subprocess.run(command, text=True, capture_output=True, timeout=60)
        metadata["compile_exit_code"] = compiled.returncode
        if compiled.returncode:
            return dict(metadata, status="compile_failure", stdout=compiled.stdout,
                        stderr=compiled.stderr)
        completed = subprocess.run([str(executable), mode], text=True,
                                   capture_output=True, timeout=60)
        metadata["runtime_exit_code"] = completed.returncode
        if completed.returncode:
            return dict(metadata, status="runtime_failure", stdout=completed.stdout,
                        stderr=completed.stderr)
        report = json.loads(completed.stdout)
        report.update(metadata)
        return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--baseline-source", type=Path)
    parser.add_argument("--mode", choices=("normal", "boot", "all"), default="all")
    parser.add_argument("--compiler", default="g++")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = run(args.source, args.mode, args.compiler)
    if args.baseline_source and result["status"] == "pass":
        baseline = run(args.baseline_source, "normal", args.compiler)
        if baseline["status"] != "pass":
            raise AssertionError(f"ordinary baseline failed: {baseline}")
        if result["normal_trace"] != baseline["normal_trace"]:
            raise AssertionError("ordinary texture_update trace differs from pinned original")
        result["ordinary_trace_matches_original"] = True
        result["baseline"] = baseline
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")
    if result["status"] != "pass":
        raise SystemExit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Fail cheaply if the source oracle rejects unchanged stock native boot.

This runs before paired compilation. It observes no patched upload calls and
does not qualify the native component, a shipping template or a device.
"""
import argparse
import glob
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

from capture import capture, matrix, write_json
from verify import require, verify_pixels

OFFICIAL_SHA256 = "8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e"
OFFICIAL_VERSION = "4.7.2.stable.official.ed1daf0bf"
BUDGET_SECONDS = 180


def run(binary, splash, output):
    began = time.monotonic()
    deadline = began + BUDGET_SECONDS
    output.mkdir(parents=True, exist_ok=False)
    report = {"status": "running", "scope": "stock native source-oracle preflight only",
              "candidate_native_qualification": False, "budget_seconds": BUDGET_SECONDS,
              "cases": []}
    try:
        with binary.open("rb") as stream:
            report["binary_sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
        require(report["binary_sha256"] == OFFICIAL_SHA256, "stock oracle binary identity differs")
        version = subprocess.run([str(binary.resolve()), "--version"], check=True,
                                 capture_output=True, text=True, timeout=5).stdout.strip()
        require(version == OFFICIAL_VERSION, "stock oracle version differs")
        report["version"] = version
        manifests = glob.glob('/usr/share/vulkan/icd.d/*lvp*.json')
        require(len(manifests) == 1, "stock oracle requires one unambiguous lavapipe ICD")
        os.environ['VK_DRIVER_FILES'] = str(Path(manifests[0]).resolve())
        cases = matrix(splash, output)
        for renderer in ("gles3", "rd"):
            for case in cases:
                remaining = deadline - time.monotonic()
                require(remaining > 0, "stock oracle preflight budget exhausted")
                report["active"] = {"renderer": renderer, "case": case["name"]}
                write_json(output / 'result.json', report)
                venue = output / renderer / case["name"]
                capture(binary, case, renderer, venue, stock_oracle=True,
                        timeout=min(40, remaining))
                # This self-pair invokes the unchanged pair/source verifier;
                # it is only a source-oracle check, never candidate evidence.
                result = verify_pixels(venue / 'boot.png', venue / 'boot.png', case, renderer)
                report["cases"].append(dict(renderer=renderer, case=case["name"],
                    source_oracle_max_channel_error=result['source_oracle_max_channel_error'],
                    nominal_max_channel_error=result['source_oracle_nominal_max_channel_error'],
                    nearest_exact_boundary_pixels=result['nearest_exact_boundary_pixels'],
                    screenshot_sha256=result['baseline_sha256']))
        require(time.monotonic() <= deadline, "stock oracle preflight budget exhausted")
        report.pop('active')
        report['status'] = 'pass'
    except Exception as error:
        report['status'] = 'failed_or_inconclusive'
        report['error'] = f'{type(error).__name__}: {error}'
        raise
    finally:
        report['elapsed_seconds'] = time.monotonic() - began
        write_json(output / 'result.json', report)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--splash', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    run(args.binary, args.splash, args.output)

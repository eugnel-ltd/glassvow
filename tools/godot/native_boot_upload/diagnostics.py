#!/usr/bin/env python3
"""Print bounded, curated capture failure logs without environment dumps."""
import argparse
import json
from pathlib import Path
import re
import sys

MAX_TAIL_BYTES = 8192
MAX_LINES = 80
MAX_REPORT_BYTES = 262144
LOG_NAMES = ("capture-worker.log", "native.log")


def safe_line(value):
    # Prefix every line, discard terminal controls, and omit URL/credential
    # values. Neither environment, spec.json nor command.json is ever read.
    value = "".join(char for char in str(value) if char == "\t" or char.isprintable())
    value = re.sub(r"https?://\S+", "[URL omitted]", value)
    value = re.sub(r"\b(?:gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+)\b",
                   "[credential omitted]", value)
    value = re.sub(r"(?i)\b(?:authorization|password|secret|token)\s*[:=]\s*.*",
                   "[credential field omitted]", value)
    return value[:1024]


def emit(root, stream=None):
    stream = stream or sys.stdout

    def line(value):
        print("native-boot diagnostic | " + safe_line(value), file=stream, flush=True)

    root = Path(root).resolve()
    report_path = root / "render-report.json"
    if not report_path.is_file():
        line("No render report: capture was not reached or no report was written.")
        return
    if not report_path.resolve().is_relative_to(root) or report_path.stat().st_size > MAX_REPORT_BYTES:
        line("Render report rejected: outside evidence root or larger than 256 KiB.")
        return
    try:
        report = json.loads(report_path.read_text())
        if not isinstance(report, dict):
            raise ValueError("report is not an object")
        line("status=" + str(report.get("status", "unknown")))
        line("error=" + str(report.get("error", "not recorded; outer job may have timed out")))
        active = report.get("active_capture", {})
        renderer, case, variant = (active.get(key, "") for key in ("renderer", "case", "variant"))
        if (renderer not in ("gles3", "rd") or variant not in ("baseline", "candidate") or
                not isinstance(case, str) or not re.fullmatch(r"[a-z0-9-]{1,64}", case)):
            line("No valid active capture; no other generated logs are selected.")
            return
        line(f"renderer={renderer} case={case} variant={variant} phase={active.get('phase', 'unknown')}")
        directory = (root / case if case == "negative-corrupt-source" else
                     root / renderer / case / variant)
        for name in LOG_NAMES:
            path = directory / name
            if not path.resolve().is_relative_to(root) or not path.is_file():
                line(name + ": unavailable within evidence root")
                continue
            size = path.stat().st_size
            line(f"{name}: last <= {MAX_TAIL_BYTES} bytes / {MAX_LINES} lines; file_bytes={size}")
            with path.open("rb") as log:
                log.seek(max(0, size - MAX_TAIL_BYTES))
                tail = log.read(MAX_TAIL_BYTES).decode(errors="replace")
            for entry in tail.splitlines()[-MAX_LINES:]:
                line(entry)
    except (OSError, ValueError, TypeError, AttributeError) as error:
        line("Diagnostics unavailable: " + type(error).__name__)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    emit(parser.parse_args().root)

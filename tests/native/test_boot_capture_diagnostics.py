#!/usr/bin/env python3
"""Failure visibility contract; synthetic child processes, no native engine."""
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] /
                       "tools/godot/native_boot_upload"))
import capture
import diagnostics
from processes import run_logged


class CaptureFailureDiagnosticsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "render"
        self.root.mkdir()

    def report(self, case="real-desktop"):
        value = {"status": "failed_or_inconclusive", "error": "synthetic worker exit 7",
                 "active_capture": {"renderer": "gles3", "case": case,
                                    "variant": "baseline", "phase": "native_capture"}}
        (self.root / "render-report.json").write_text(json.dumps(value))
        directory = self.root / "gles3" / case / "baseline"
        directory.mkdir(parents=True, exist_ok=True)
        return directory

    def output(self):
        stream = io.StringIO()
        diagnostics.emit(self.root, stream)
        return stream.getvalue()

    def test_actual_child_failure_keeps_context_and_surfaces_both_logs(self):
        case = {"name": "real-desktop", "source": "not-read", "size": [1180, 820]}
        args = SimpleNamespace(output=self.root, splash=Path("not-read"),
                               baseline=Path("not-run-baseline"), candidate=Path("not-run-candidate"))

        def synthetic_worker(command, log, timeout):
            self.assertEqual(command[0], "xvfb-run")
            (log.parent / "native.log").write_text("SYNTHETIC native startup failure\n")
            run_logged([sys.executable, "-c", "print('SYNTHETIC worker exit'); raise SystemExit(7)"],
                       log, 5)

        with patch.object(capture, "matrix", return_value=[case]), \
                patch.object(capture, "run_logged", side_effect=synthetic_worker):
            with self.assertRaises(subprocess.CalledProcessError) as failure:
                capture.run_matrix(args)
        self.assertEqual(failure.exception.returncode, 7)
        report = json.loads((self.root / "render-report.json").read_text())
        self.assertEqual(report["status"], "failed_or_inconclusive")
        self.assertEqual(report["active_capture"]["phase"], "native_capture")
        result = subprocess.run([sys.executable, "-B", diagnostics.__file__, "--root", str(self.root)],
                                check=True, capture_output=True, text=True)
        self.assertIn("renderer=gles3 case=real-desktop variant=baseline", result.stdout)
        self.assertIn("SYNTHETIC native startup failure", result.stdout)
        self.assertIn("SYNTHETIC worker exit", result.stdout)
        self.assertIn("CalledProcessError", result.stdout)

    def test_output_is_bounded_prefixed_and_omits_credentials_and_nonlogs(self):
        directory = self.report()
        for name in diagnostics.LOG_NAMES:
            (directory / name).write_text("OLD OMITTED\n" + "x" * 100000 +
                "\n::warning::not a workflow command\n" +
                "token=not-a-real-credential\nhttps://signed.invalid/private?token=not-real\nTAIL VISIBLE\n")
        (directory / "command.json").write_text("COMMAND MUST NOT BE PRINTED")
        (directory / "spec.json").write_text("SPEC MUST NOT BE PRINTED")
        output = self.output()
        self.assertLess(len(output), 24000)
        for value in ("OLD OMITTED", "not-a-real-credential", "signed.invalid",
                      "COMMAND MUST NOT", "SPEC MUST NOT"):
            self.assertNotIn(value, output)
        self.assertIn("TAIL VISIBLE", output)
        self.assertTrue(all(line.startswith("native-boot diagnostic | ") for line in output.splitlines()))

    def test_invalid_case_cannot_select_another_directory(self):
        self.report("real-desktop")
        report = json.loads((self.root / "render-report.json").read_text())
        report["active_capture"]["case"] = "../../outside"
        (self.root / "render-report.json").write_text(json.dumps(report))
        self.assertIn("No valid active capture", self.output())

    def test_symlinked_log_cannot_escape_evidence_root(self):
        directory = self.report()
        outside = self.root.parent / "outside.log"
        outside.write_text("OUTSIDE MUST NOT BE PRINTED")
        (directory / "native.log").symlink_to(outside)
        self.assertNotIn("OUTSIDE MUST NOT", self.output())
        self.assertIn("native.log: unavailable", self.output())

    def test_missing_report_and_missing_logs_are_explicit(self):
        self.assertIn("No render report", self.output())
        self.report()
        output = self.output()
        for name in diagnostics.LOG_NAMES:
            self.assertIn(name + ": unavailable", output)

    def test_oversized_report_is_not_read(self):
        (self.root / "render-report.json").write_text("x" * (diagnostics.MAX_REPORT_BYTES + 1))
        self.assertIn("larger than 256 KiB", self.output())


if __name__ == "__main__":
    unittest.main(verbosity=2)

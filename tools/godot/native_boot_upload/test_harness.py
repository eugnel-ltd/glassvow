#!/usr/bin/env python3
"""Tests of the evidence verifier only; these never claim native/GPU proof."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

import numpy as np
from PIL import Image

from verify import BACKGROUND, CAP, PREFIX, verify_pixels, verify_uploads
from processes import run_logged


class EvidenceVerifierTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def picture_case(self):
        source = self.root / "source.png"
        pixels = np.full((64, 64, 3), BACKGROUND, dtype=np.uint8)
        pixels[8:56, 12:52] = [191, 73, 127]
        pixels[20:34, 20:44] = [31, 219, 83]
        Image.fromarray(pixels).save(source)
        return {"source": str(source), "size": [64, 64], "filter": False, "stretch": 5}

    def test_exact_source_pair_passes(self):
        case = self.picture_case()
        result = verify_pixels(case["source"], case["source"], case, "gles3")
        self.assertTrue(result["pair_exact"])
        self.assertEqual(result["source_oracle_max_channel_error"], 0)

    def test_matching_blank_frames_are_rejected(self):
        case = self.picture_case()
        blank = self.root / "blank.png"
        Image.new("RGB", (64, 64), BACKGROUND).save(blank)
        with self.assertRaisesRegex(AssertionError, "blank"):
            verify_pixels(blank, blank, case, "gles3")

    def test_one_changed_pixel_is_rejected(self):
        case = self.picture_case()
        changed = self.root / "changed.png"
        image = Image.open(case["source"])
        image.putpixel((24, 24), (32, 219, 83))
        image.save(changed)
        with self.assertRaisesRegex(AssertionError, "pixels differ"):
            verify_pixels(case["source"], changed, case, "rd")

    def test_matching_wrong_source_is_rejected(self):
        case = self.picture_case()
        wrong = self.root / "wrong.png"
        image = Image.open(case["source"])
        image.putpixel((24, 24), (255, 255, 255))
        image.save(wrong)
        with self.assertRaisesRegex(AssertionError, "source oracle"):
            verify_pixels(wrong, wrong, case, "rd")

    def test_matching_shifted_picture_is_rejected(self):
        case = self.picture_case()
        shifted = self.root / "shifted.png"
        image = Image.new("RGB", (64, 64), BACKGROUND)
        image.paste(Image.open(case["source"]), (1, 0))
        image.save(shifted)
        with self.assertRaisesRegex(AssertionError, "bounding box"):
            verify_pixels(shifted, shifted, case, "gles3")

    def upload_log(self, oversized=False, script=False, draws=4):
        source = self.root / "real-sized-source.png"
        Image.new("RGB", (2360, 1640)).save(source)
        case = {"source": str(source), "size": [1180, 820], "filter": True, "stretch": 1}
        records = [{"event": "begin", "renderer": "rd", "source_width": 2360,
                    "source_height": 1640, "source_format": "RGB8", "source_bytes": 11611200,
                    "window_width": 1180, "window_height": 820, "filter": True, "stretch": 1}]
        heights = [1640] if oversized else [411, 412, 412, 411]
        for index, height in enumerate(heights):
            records.append({"event": "upload", "index": index, "width": 2360,
                            "height": height, "format": "RGBA8", "bytes": 2360 * height * 4})
        records.extend([{"event": "present", "uploads": len(heights), "draws": draws,
                         "clears": 1, "presents": 1}, {"event": "hold"}])
        log = self.root / "native.log"
        log.write_text("".join(PREFIX + json.dumps(dict(record, schema=1)) + "\n"
                               for record in records) + ("GV_BOOT_SCRIPT_STARTED\n" if script else ""))
        return log, case

    def test_observed_candidate_payloads_pass(self):
        log, case = self.upload_log()
        result = verify_uploads(log, case, "rd", "candidate")
        self.assertLessEqual(result["maximum_bytes"], CAP)

    def test_oversized_baseline_is_a_required_failure_control(self):
        log, case = self.upload_log(oversized=True, draws=1)
        self.assertEqual(verify_uploads(log, case, "rd", "baseline")["maximum_bytes"], 15481600)
        with self.assertRaisesRegex(AssertionError, "exceeds 4 MiB"):
            verify_uploads(log, case, "rd", "candidate")

    def test_script_execution_invalidates_the_capture(self):
        log, case = self.upload_log(script=True)
        with self.assertRaisesRegex(AssertionError, "script ran"):
            verify_uploads(log, case, "rd", "candidate")

    def test_missing_native_draw_cannot_pass(self):
        log, case = self.upload_log(draws=0)
        with self.assertRaisesRegex(AssertionError, "counters differ"):
            verify_uploads(log, case, "rd", "candidate")

    def test_group_cleanup_after_leader_exits(self):
        heartbeat = self.root / "heartbeat"
        child = "import pathlib,sys,time; p=pathlib.Path(sys.argv[1]); " + \
                "exec('while True:\\n p.open(\"a\").write(\"x\")\\n time.sleep(.01)')"
        leader = "import pathlib,subprocess,sys,time; " + \
                 "subprocess.Popen([sys.executable,'-c',sys.argv[1],sys.argv[2]]); " + \
                 "exec('while not pathlib.Path(sys.argv[2]).exists(): time.sleep(.01)')"
        run_logged([sys.executable, "-c", leader, child, str(heartbeat)],
                   self.root / "process.log", 5)
        before = heartbeat.stat().st_size
        time.sleep(0.1)
        self.assertEqual(heartbeat.stat().st_size, before)

    def test_timeout_kills_the_process_group(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            run_logged([sys.executable, "-c", "import time; time.sleep(30)"],
                       self.root / "timeout.log", 0.05)

    def test_wrapper_timeout_reaches_worker_and_engine(self):
        heartbeat = self.root / "engine-heartbeat"
        engine = self.root / "fake-engine.py"
        engine.write_text("import pathlib,sys,time\n"
                          "p=pathlib.Path(sys.argv[1])\n"
                          "while True:\n"
                          " with p.open('a') as stream: stream.write('x')\n"
                          " time.sleep(.01)\n")
        worker = self.root / "fake-worker.py"
        worker.write_text("import subprocess,sys\n"
                          "subprocess.Popen([sys.executable,sys.argv[1],sys.argv[2]]).wait()\n")
        wrapper = self.root / "fake-wrapper.py"
        wrapper.write_text("import subprocess,sys\n"
                           "subprocess.Popen([sys.executable,*sys.argv[1:]]).wait()\n")
        with self.assertRaises(subprocess.TimeoutExpired):
            run_logged([sys.executable, str(wrapper), str(worker), str(engine), str(heartbeat)],
                       self.root / "wrapper-timeout.log", 1.5)
        self.assertTrue(heartbeat.exists(), "fake engine never started; cleanup was not exercised")
        before = heartbeat.stat().st_size
        time.sleep(0.15)
        self.assertEqual(heartbeat.stat().st_size, before, "engine survived the wrapper timeout")


if __name__ == "__main__":
    unittest.main(verbosity=2)

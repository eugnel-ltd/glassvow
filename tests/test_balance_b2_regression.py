#!/usr/bin/env python3
"""Immutable B2 regression: wholly synthetic run clusters, never research evidence."""
from __future__ import annotations

import argparse
import contextlib
import copy
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT))

import balance_readout as readout  # noqa: E402
import balance_ways as bw  # noqa: E402
from tests.test_balance_readout import manifest, run_row  # noqa: E402


class WholeRunB2Regression(unittest.TestCase):
    def test_requested_sensitivity_retains_correlated_whole_runs(self) -> None:
        who = bw.roster("duskblade")
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            for pool in who.pools:
                for arm in who.committed + (bw.SKILLED,):
                    runs = []
                    for index in range(4):
                        row = run_row(13000 + index, True, who.arms[arm][0], expressed=index < 2)
                        # Two wholly expressed runs and two wholly unexpressed runs.
                        # Each has 100 won fights, exactly five ending below 20% HP.
                        row["fights"] = [copy.deepcopy(row["fights"][0]) for _ in range(100)]
                        flame = row["flame"]["fights"][0]
                        row["flame"]["fights"] = [dict(copy.deepcopy(flame), hp=10 if i < 5 else 80)
                                                  for i in range(100)]
                        runs.append(row)
                    path = directory / bw.report_name(0, pool, arm)
                    identity = manifest(0, pool, arm, who, seeds={"first": 13000, "last": 13003, "count": 4})
                    path.write_text(json.dumps({"manifest": identity, "runs": runs}), encoding="utf-8")
                    # These are valid report rows before the reporting behaviour is tested.
                    self.assertEqual(4, len(bw.load_report(path, None, who.rates)[1]))
            opts = argparse.Namespace(aspect="duskblade", content=None, dir=directory,
                                      vow=0, ref=None, b2_sensitivity=True, b2_seed=0)
            captured = io.StringIO()
            with contextlib.redirect_stdout(captured):
                self.assertEqual(0, readout.cmd_rowb(opts))
            # Resampling fights would give a narrow Wilson-like interval near 50%.
            # Four whole-run clusters have 2.5/97.5 percentiles of zero and one.
            self.assertIn("| 50.0% (0.0–100.0) | 5.0% (5.0–5.0) | UNDECIDED |",
                          captured.getvalue(),
                          "requested B2 sensitivity must report whole-run uncertainty beside Wilson")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Synthetic statistical invariants for B2 tooling; these fixtures are not balance evidence."""
from __future__ import annotations

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
import balance_readout_stats as stats  # noqa: E402
import balance_readout_tables as tables  # noqa: E402
import balance_ways as bw  # noqa: E402
from tests.test_balance_readout import manifest, run_row, write_table  # noqa: E402

DUSK = bw.roster("duskblade")


def cluster(seed: int, shown: int, fights: int, close: int = 0, wins: int | None = None,
            who: bw.Roster = DUSK, way: str | None = None) -> dict:
    """One synthetic run with explicitly counted fights, including wins inside a lost run."""
    way = who.ways[0] if way is None else way
    row = run_row(seed, False, way, who=who)
    yes = row["flame"]["fights"][0]
    no = run_row(seed, False, way, expressed=False, who=who)["flame"]["fights"][0]
    row["fights"] = [dict(row["fights"][0], result="win" if i < (fights if wins is None else wins) else "loss")
                     for i in range(fights)]
    row["flame"]["fights"] = [dict(copy.deepcopy(yes if i < shown else no), hp=10 if i < close else 80)
                              for i in range(fights)]
    return row


class ClusteredB2Tests(unittest.TestCase):
    def measure(self, rows: list[dict], **kwargs) -> stats.B2Sensitivity:
        return stats.b2_sensitivity(rows, DUSK.ways[0], DUSK.ways, **kwargs)

    def test_unequal_clusters_use_pooled_counts_and_analytic_extremes(self) -> None:
        result = self.measure([cluster(1, 1, 1, close=1), cluster(2, 0, 9)])
        # Equally likely samples (1,1), (1,2), (2,1), (2,2) yield 1, .1, .1, 0.
        # The mean run rate is .5 and would be the wrong estimator.
        self.assertEqual((0.1, 0.0, 1.0), result.expression.span)
        self.assertEqual((0.1, 0.0, 1.0), result.close.span)
        self.assertEqual((2, 2000, 0), (result.runs, result.resamples, result.seed))

    def test_correlated_fight_duplication_cannot_narrow_run_uncertainty(self) -> None:
        rows = [cluster(1, 3, 5, close=1), cluster(2, 1, 7, close=2), cluster(3, 8, 8)]
        doubled = copy.deepcopy(rows)
        for row in doubled:
            row["fights"] *= 20
            row["flame"]["fights"] *= 20
        self.assertEqual(self.measure(rows), self.measure(doubled))

    def test_shuffle_is_reproducible_and_seed_is_reported(self) -> None:
        rows = [cluster(10, 1, 1), cluster(30, 0, 9), cluster(20, 4, 7)]
        self.assertEqual(self.measure(rows, seed=19), self.measure(rows[::-1], seed=19))
        a, b = self.measure(rows, seed=0, resamples=7), self.measure(rows, seed=12, resamples=7)
        self.assertNotEqual(a.expression.span, b.expression.span)
        self.assertEqual(12, b.seed)

    def test_linear_percentile_convention(self) -> None:
        self.assertAlmostEqual(0.075, stats._percentile([0, 1, 2, 3], 0.025))
        self.assertAlmostEqual(2.925, stats._percentile([0, 1, 2, 3], 0.975))

    def test_sensitivity_grades_the_unchanged_inclusive_thresholds(self) -> None:
        for shown, close, verdict in ((60, 1, "PASS"), (60, 10, "PASS"), (59, 5, "FAIL"),
                                      (80, 0, "FAIL"), (80, 11, "FAIL")):
            with self.subTest(shown=shown, close=close):
                result = self.measure([cluster(1, shown, 100, close=close)])
                self.assertEqual(verdict, tables.clustered_b2_verdict(result))

    def test_only_won_fights_enter_close_denominator_even_in_lost_runs(self) -> None:
        result = self.measure([cluster(1, 10, 10, close=1, wins=2)])
        self.assertEqual((0.5, 0.5, 0.5), result.close.span)
        self.assertEqual((1.0, 1.0, 1.0), result.expression.span)

    def test_close_calls_keep_the_graders_strict_hp_boundary(self) -> None:
        row = cluster(1, 3, 3)
        row["flame"]["fights"][0].update(hp=19)
        row["flame"]["fights"][1].update(hp=20)
        row["flame"]["fights"][2].update(hp=0, maxHp=0)
        result = self.measure([row])
        expected = bw.feel([row], DUSK.ways[0], DUSK.ways)
        self.assertEqual(2, expected["close"])
        self.assertEqual(expected["close"] / expected["won"], result.close.point)

    def test_expression_reuses_class_way_and_adaptive_start_dominant_rules(self) -> None:
        for who in (DUSK, bw.roster("ashwarden")):
            row = cluster(1, 1, 2, who=who)
            row["flame"]["fights"][1]["dominant"] = who.ways[-1]
            row["flame"]["fights"][1]["plays"] = {who.ways[-1]: 1}
            fixed = stats.b2_sensitivity([row], who.ways[0], who.ways)
            adaptive = stats.b2_sensitivity([row], "none", who.ways)
            self.assertEqual(0.5, fixed.expression.point)
            self.assertEqual(1.0, adaptive.expression.point)
            row["flame"]["fights"][0]["plays"] = {way: 1 for way in who.ways}
            self.assertEqual(0.0, stats.b2_sensitivity([row], who.ways[0], who.ways).expression.point)

    def test_no_fights_or_no_wins_is_non_estimable_and_undecided(self) -> None:
        empty = self.measure([cluster(1, 0, 0)])
        self.assertIsNone(empty.expression.point)
        self.assertEqual(2000, empty.expression.undefined)
        self.assertIsNone(empty.close.span)
        self.assertEqual("UNDECIDED", tables.clustered_b2_verdict(empty))
        no_wins = self.measure([cluster(1, 10, 10, wins=0)])
        self.assertEqual((1.0, 1.0, 1.0), no_wins.expression.span)
        self.assertIsNone(no_wins.close.point)
        self.assertEqual("UNDECIDED", tables.clustered_b2_verdict(no_wins))

    def test_one_undefined_resample_invalidates_interval_without_dropping_it(self) -> None:
        result = self.measure([cluster(1, 1, 1), cluster(2, 0, 0)])
        self.assertEqual(1.0, result.expression.point)
        self.assertTrue(0 < result.expression.undefined < result.resamples)
        self.assertIsNone(result.expression.span)
        self.assertEqual("UNDECIDED", tables.clustered_b2_verdict(result))
        self.assertIn("zero-denominator resamples", tables._cluster_span(result.expression, result.resamples))

    def test_invalid_clusters_fail_with_a_label(self) -> None:
        original = [cluster(1, 1, 1), cluster(2, 1, 1)]
        changes = [lambda r: r[1].update(seed=1), lambda r: r[1].update(seed=True),
                   lambda r: r[0]["flame"].update(fights=[]), lambda r: r[0].update(fights=None),
                   lambda r: r[0]["fights"][0].update(result="unknown"),
                   lambda r: r[0]["flame"]["fights"][0].update(hp="10"),
                   lambda r: r[0]["flame"]["fights"][0].update(plays={"shatter": float("nan")}),
                   lambda r: r[0]["flame"]["fights"][0].update(plays={"shatter": -1})]
        for change in changes:
            rows = copy.deepcopy(original)
            change(rows)
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, "synthetic-report"):
                self.measure(rows, label="synthetic-report")
        for kwargs in ({"seed": True}, {"resamples": 0}, {"resamples": 1.5}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                self.measure(original, **kwargs)
        with self.assertRaisesRegex(ValueError, "no run clusters"):
            self.measure([])


class ClusteredB2ReportTests(unittest.TestCase):
    def reports(self, directory: Path, who: bw.Roster) -> dict:
        expected = {}
        for p, pool in enumerate(who.pools):
            for a, arm in enumerate(who.committed + (bw.SKILLED,)):
                shown = 1 + p * 4 + a
                runs = [cluster(13000 + i, shown, 10, close=1, who=who, way=who.arms[arm][0])
                        for i in range(3 + a)]
                (directory / bw.report_name(0, pool, arm)).write_text(
                    json.dumps({"manifest": manifest(0, pool, arm, who,
                               seeds={"first": 13000, "last": 13002 + a, "count": 3 + a}),
                                "runs": runs}), encoding="utf-8")
                expected[pool, arm] = (shown / 10, 3 + a)
        return expected

    def test_grouping_keeps_each_class_pool_and_arm_separate(self) -> None:
        for who in (DUSK, bw.roster("ashwarden")):
            with self.subTest(aspect=who.aspect), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp)
                expected = self.reports(directory, who)
                actual = tables.row_b_sensitivity(who, directory)
                self.assertEqual(set(expected), set(actual))
                for key, (point, runs) in expected.items():
                    self.assertEqual((point, point, point), actual[key].expression.span)
                    self.assertEqual(runs, actual[key].runs)

    def test_default_wilson_output_is_unchanged_and_cli_adds_sensitivity(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            self.reports(directory, DUSK)
            before = tables.row_b_table(DUSK, directory)
            captured = io.StringIO()
            with contextlib.redirect_stdout(captured):
                self.assertEqual(0, readout.main(["rowb", str(directory)]))
            self.assertEqual(before + "\n", captured.getvalue())
            after = tables.row_b_table(DUSK, directory, reference=directory, b2_sensitivity=True, b2_seed=71)
            self.assertIn("Before B1 / B2", after)
            self.assertIn("Python Random seed 71", after)
            self.assertIn("2,000 resamples", after)
            for line, extended in zip(before.splitlines()[2:], after.splitlines()[2:]):
                self.assertTrue(extended.startswith(line))

    def test_public_report_refuses_malformed_arrays_and_wrong_catalogue(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            self.reports(directory, DUSK)
            with self.assertRaisesRegex(ValueError, "content"):
                tables.row_b_sensitivity(DUSK._replace(content="synthetic-sha"), directory)
            path = directory / bw.report_name(0, DUSK.pools[0], DUSK.committed[0])
            data = json.loads(path.read_text())
            data["runs"][0]["flame"]["fights"] = []
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, "aligned fights"):
                tables.row_b_table(DUSK, directory, b2_sensitivity=True)

    def test_public_cli_refuses_foreign_cell_identity_even_with_matching_content(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            self.reports(directory, DUSK)
            content = ROOT / "content/full-content.json"
            who = bw.grading_roster("duskblade", content)
            for path in directory.glob("*.json"):
                data = json.loads(path.read_text())
                data["manifest"]["contentFileSha256"] = who.content
                path.write_text(json.dumps(data))
            path = directory / "v0-full-A_lit.json"
            data = json.loads(path.read_text())
            data["manifest"].update(aspect="ashwarden", vow=5, pool="entry", way="none", build="lit")
            ash = bw.roster("ashwarden")
            data["runs"] = [cluster(13000 + i, 4, 10, close=1, who=ash, way="none") for i in range(2)]
            path.write_text(json.dumps(data))
            captured = io.StringIO()
            with contextlib.redirect_stdout(captured), self.assertRaisesRegex(
                    ValueError, "v0-full-A_lit.json: manifest is not this cell and arm",
                    msg="B2 sensitivity must reject a foreign class/vow/pool manifest before labelling its figures"):
                readout.main(["rowb", str(directory), "--aspect", "duskblade", "--content", str(content),
                              "--b2-sensitivity"])
            self.assertEqual("", captured.getvalue())

    def test_sensitivity_requires_every_identity_field_to_match_exactly(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            self.reports(directory, DUSK)
            path = directory / "v0-fresh-C_shatter.json"
            original = json.loads(path.read_text())
            for key, wrong in (("aspect", "ashwarden"), ("vow", 5), ("pool", "full"),
                               ("way", "lantern"), ("build", "lit"), ("vow", False)):
                with self.subTest(key=key, wrong=wrong):
                    data = copy.deepcopy(original)
                    data["manifest"][key] = wrong
                    path.write_text(json.dumps(data))
                    with self.assertRaisesRegex(ValueError, "manifest is not this cell and arm"):
                        tables.row_b_sensitivity(DUSK, directory)
            for key in ("aspect", "vow", "pool", "way", "build"):
                with self.subTest(missing=key):
                    data = copy.deepcopy(original)
                    del data["manifest"][key]
                    path.write_text(json.dumps(data))
                    with self.assertRaisesRegex(ValueError, "manifest is not this cell and arm"):
                        tables.row_b_sensitivity(DUSK, directory)
            path.write_text(json.dumps(dict(original, manifest={})))
            with self.assertRaisesRegex(ValueError, "manifest is not this cell and arm"):
                tables.row_b_sensitivity(DUSK, directory)

    def test_table_exposes_same_sensitivity_and_tidy_cannot_silently_omit_it(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for vow in (0, 5):
                write_table(root / f"v{vow}", vows=(vow,))
            argv = ["table", str(root / "v0"), str(root / "v5"), "--v0-seeds", "13000-13009",
                    "--v5-seeds", "13000-13009", "--b2-sensitivity", "--b2-seed", "9"]
            captured = io.StringIO()
            with contextlib.redirect_stdout(captured):
                self.assertEqual(0, readout.main(argv))
            self.assertIn("B2 sensitivity", captured.getvalue())
            self.assertIn("Python Random seed 9", captured.getvalue())
            with self.assertRaisesRegex(ValueError, "tidy omits row B"):
                readout.main(argv + ["--tidy"])


if __name__ == "__main__":
    unittest.main()

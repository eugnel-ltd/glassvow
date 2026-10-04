#!/usr/bin/env python3
"""Self-test for tools/balance_readout*.py on synthetic fixtures; no Godot is launched.

Run: python3 -B tests/test_balance_readout.py
"""
from __future__ import annotations

import contextlib
import copy
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS))

import balance_readout as readout  # noqa: E402
import balance_readout_catalogue as catalogue  # noqa: E402
import balance_readout_compare as compare  # noqa: E402
import balance_readout_guard as guard  # noqa: E402
import balance_readout_run as runner  # noqa: E402
import balance_readout_stats as stats  # noqa: E402
import balance_readout_tables as tables  # noqa: E402
import balance_ways as bw  # noqa: E402

OVERRIDE = '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="glassvow-test"\n'


def outcomes(wins: set[int], n: int, first: int = 0) -> list[dict]:
    return [{"seed": first + i, "outcome": "win" if i in wins else "loss"} for i in range(n)]


class IsolationGuardTests(unittest.TestCase):
    def check(self, text: str | None) -> str:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            if text is not None:
                (root / "override.cfg").write_text(text, encoding="utf-8")
            return guard.require_isolated_user_dir(root)

    def refused(self, text: str | None, mention: str) -> None:
        with self.assertRaises(guard.IsolationError) as ctx:
            self.check(text)
        message = str(ctx.exception)
        self.assertIn("refusing to launch Godot", message)
        self.assertIn(mention, message)
        self.assertIn("real Godot profile", message)  # the error says why

    def test_both_keys_pass_and_return_the_name(self) -> None:
        self.assertEqual("glassvow-test", self.check(OVERRIDE))

    def test_refusals(self) -> None:
        self.refused(None, "does not exist")
        self.refused('[application]\nconfig/custom_user_dir_name="x"\n', "use_custom_user_dir=true")
        self.refused('[application]\nconfig/use_custom_user_dir=false\nconfig/custom_user_dir_name="x"\n',
                     "use_custom_user_dir=true")
        self.refused("[application]\nconfig/use_custom_user_dir=true\n", "custom_user_dir_name")
        self.refused('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=""\n',
                     "non-empty")

    def test_keys_outside_the_application_section_do_not_count(self) -> None:
        # Godot reads a header-less key as a different setting, so it would not isolate anything.
        self.refused('config/use_custom_user_dir=true\nconfig/custom_user_dir_name="x"\n', "use_custom_user_dir=true")
        self.refused('[display]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="x"\n',
                     "use_custom_user_dir=true")

    def test_the_launching_function_refuses_before_running_anything(self) -> None:
        calls: list = []
        with tempfile.TemporaryDirectory() as tmp:
            work = runner.plan(Path(tmp) / "out", (13000, 13003), ["v0-fresh"], ["A"], chunk=2)
            with self.assertRaises(guard.IsolationError):
                runner.run_chunks(work, {}, 1, runner=lambda command, log: calls.append(command) or 0, root=Path(tmp))
        self.assertEqual([], calls)

    def test_the_run_command_refuses_without_the_override(self) -> None:
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(readout, "REPO", Path(tmp)):
            err = io.StringIO()
            with contextlib.redirect_stderr(err), self.assertRaises(guard.IsolationError):
                readout.main(["run", str(Path(tmp) / "out"), "--seeds", "13000-13003"])
            self.assertFalse((Path(tmp) / "out").exists())


class StatisticsTests(unittest.TestCase):
    def test_exact_binomial_p_by_hand(self) -> None:
        self.assertAlmostEqual(352 / 1024, stats.binomial_p(3, 10))  # 2 * (1 + 10 + 45 + 120) / 2^10
        self.assertAlmostEqual(2 / 64, stats.binomial_p(6, 6))  # 2 * 1 / 2^6
        self.assertAlmostEqual(2 / 32, stats.binomial_p(0, 5))
        self.assertEqual(1.0, stats.binomial_p(5, 10))  # the tie caps at 1
        self.assertEqual(1.0, stats.binomial_p(0, 0))
        self.assertEqual(stats.binomial_p(2, 9), stats.binomial_p(7, 9))  # symmetric

    def test_paired_change_counts_and_p(self) -> None:
        new, base = outcomes(set(range(6)), 10), outcomes({6}, 10)
        change = stats.paired_change(new, base)
        self.assertEqual((10, 6, 1), (change.n, change.gained, change.lost))
        self.assertEqual(3, change.identical)  # seeds 7, 8, 9 are the same loss
        self.assertAlmostEqual(2 * (1 + 7) / 128, change.p)  # 6 of 7 discordant seeds
        self.assertAlmostEqual(0.5, change.points)
        none = stats.paired_change(outcomes({1}, 4), outcomes({1}, 4))
        self.assertEqual((0, 0, 1.0), (none.gained, none.lost, none.p))

    def test_paired_change_counts_a_whole_row_difference_as_not_identical(self) -> None:
        new, base = outcomes({0}, 3), outcomes({0}, 3)
        new[1]["gold"] = 5
        self.assertEqual(2, stats.paired_change(new, base).identical)

    def test_paired_change_refuses_different_seeds(self) -> None:
        with self.assertRaises(ValueError):
            stats.paired_change(outcomes({0}, 4), outcomes({0}, 4, first=1))

    def table(self, both: int, only_a: int, only_c: int, neither: int):
        a = outcomes(set(range(both + only_a)), both + only_a + only_c + neither)
        c_wins = set(range(both)) | set(range(both + only_a, both + only_a + only_c))
        return stats.paired_difference(a, outcomes(c_wins, len(a)))

    def test_paired_g3_interval_against_hand_computed_values(self) -> None:
        # Newcombe (1998) method 10 for paired proportions, solved by hand from the Wilson roots.
        d = self.table(4, 3, 1, 2)
        self.assertEqual((4, 3, 1, 2), (d.both, d.only_a, d.only_c, d.neither))
        self.assertAlmostEqual(0.2, d.delta)
        self.assertAlmostEqual(0.218218, d.phi, places=6)
        self.assertAlmostEqual(-0.155624, d.low, places=6)
        self.assertAlmostEqual(0.490226, d.high, places=6)
        d = self.table(20, 15, 5, 60)
        self.assertAlmostEqual(0.1, d.delta)
        self.assertAlmostEqual(0.544705, d.phi, places=6)
        self.assertAlmostEqual(0.014201, d.low, places=6)
        self.assertAlmostEqual(0.184500, d.high, places=6)

    def test_paired_interval_reduces_to_the_independent_one_when_phi_is_zero(self) -> None:
        d = self.table(1, 2, 2, 4)  # both * neither == only_a * only_c
        self.assertAlmostEqual(0.0, d.phi)
        independent = bw.difference((3, 9), (3, 9))
        self.assertAlmostEqual(independent[1], d.low)
        self.assertAlmostEqual(independent[2], d.high)
        self.assertAlmostEqual(-0.378016, d.low, places=6)

    def test_perfect_agreement_gives_a_zero_width_interval(self) -> None:
        d = self.table(5, 0, 0, 5)  # identical arms at 50%: nothing to estimate
        self.assertEqual((0.0, 0.0, 0.0), (d.delta, d.low, d.high))

    def test_pairing_is_never_wider_than_the_independent_interval_when_the_arms_agree(self) -> None:
        d = self.table(40, 5, 3, 52)
        _, low, high = bw.difference((45, 100), (43, 100))
        self.assertGreater(d.phi, 0)
        self.assertLess(d.high - d.low, high - low)

    def test_g3_verdicts(self) -> None:
        self.assertEqual("PASS", stats.g3_point(-0.03))
        self.assertEqual("PASS", stats.g3_point(0.15))
        self.assertEqual("FAIL", stats.g3_point(-0.031))
        self.assertEqual("FAIL", stats.g3_point(0.151))

        def span(low: float, high: float) -> stats.PairedDifference:
            return stats.PairedDifference((low + high) / 2, low, high, 0, 0, 0, 0, 0.0)
        self.assertEqual("PASS", stats.g3_interval(span(-0.02, 0.10)))
        self.assertEqual("FAIL", stats.g3_interval(span(0.16, 0.30)))  # wholly above +15 pp
        self.assertEqual("FAIL", stats.g3_interval(span(-0.20, -0.04)))  # wholly below -3 pp
        self.assertEqual("UNDECIDED", stats.g3_interval(span(-0.05, 0.10)))
        self.assertEqual("UNDECIDED", stats.g3_interval(span(0.0, 0.20)))

    def test_best_committed_takes_the_first_of_a_tie(self) -> None:
        rows = {arm: outcomes(set(range(wins)), 10) for arm, wins in zip(bw.COMMITTED, (4, 6, 6))}
        self.assertEqual(bw.COMMITTED[1], stats.best_committed(rows))


# ---------------------------------------------------------------- report fixtures

def reading(dominant: str, tier: str) -> dict:
    return {"aspect": 0, "dominant": dominant, "fringe": "", "tier": tier, "purity": 0.7, "shares": {}, "mass": 6.0}


def run_row(seed: int, win: bool, way: str, expressed: bool = True, close: bool = False,
            win_way: str | None = None) -> dict:
    """A run of one fight: `way` names the arm's way ("none" for the adaptive and random arms)."""
    dominant = win_way or (way if way != "none" else "shatter")
    play = dominant if expressed else ("edge" if dominant != "edge" else "lantern")
    return {"seed": seed, "outcome": "win" if win else "loss", "error": "",
            "fights": [{"result": "win" if win else "loss", "turns": 3, "hpLost": 5, "act": 1}],
            "flame": {"way": way, "end": reading(dominant, "STEADY"),
                      "acts": [reading(dominant, "STEADY"), reading(dominant, "TRUE")],
                      "rates": {key: 1.0 for key in bw.RATES},
                      "fights": [{"plays": {play: 1.0}, "hp": 10 if close else 80, "maxHp": 100,
                                  "dominant": dominant}]}}


def manifest(vow: int, pool: str, arm: str, **extra) -> dict:
    way, build = bw.ARMS[arm]
    return {"aspect": "duskblade", "vow": vow, "pool": pool, "way": way, "build": build, "commit": "abc",
            "contentFileSha256": "c0ffee", "driverSha256": "d00d", "pilot": "p8", "play": "search",
            "policy": {"wayCommit": None, "wayOff": None}, "godot": "4.7.2",
            "seeds": {"first": 13000, "last": 13009, "count": 10}, **extra}


WINS = {"C_shatter": 6, "C_lantern": 5, "C_edge": 5, "A": 6, "A_lit": 6, "R": 1}


def write_table(directory: Path, n: int = 10, wins: dict | None = None, vows=bw.VOWS, **extra) -> None:
    """A complete synthetic cell table (every vow, pool, arm and replay) in the grader's layout."""
    directory.mkdir(parents=True, exist_ok=True)
    wins = {**WINS, **(wins or {})}
    for vow in vows:
        for pool in bw.POOLS:
            for arm, (way, _) in bw.ARMS.items():
                runs = [run_row(13000 + i, i < wins[arm], way, win_way=("lantern", "edge", "shatter")[i % 3])
                        for i in range(n)]
                report = {"manifest": manifest(vow, pool, arm, **extra), "runs": runs}
                (directory / bw.report_name(vow, pool, arm)).write_text(json.dumps(report))
            replay = json.loads((directory / bw.report_name(vow, pool, "A")).read_text())
            replay["runs"] = replay["runs"][:bw.REPLAY]
            (directory / bw.replay_name(vow, pool)).write_text(json.dumps(replay))


class TableTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def test_paired_table_shape_and_cells(self) -> None:
        write_table(self.dir / "new", wins={"C_shatter": 8})
        write_table(self.dir / "base")
        text = tables.paired_table(self.dir / "new", self.dir / "base", ["v0-fresh", "v0-full"])
        lines = text.splitlines()
        self.assertEqual(4, len(lines))  # header, rule, two cells
        self.assertEqual(f"| Cell | {' | '.join(bw.ARMS)} |", lines[0])
        # C_shatter gains seeds 6 and 7 of ten: +20.0 pp, 2 / 0, p = 2 * 1 / 4 = 0.50; the others are identical.
        self.assertIn("+20.0 pp: 2 / 0, p = 0.50 (same 8)", lines[2])
        self.assertIn("+0.0 pp: 0 / 0, p = 1.00 (same 10)", lines[2])

    def test_paired_table_names_a_tiny_p(self) -> None:
        a, b = self.dir / "a", self.dir / "b"
        for d, wins in ((a, 20), (b, 0)):
            d.mkdir()
            report = {"manifest": {}, "runs": outcomes(set(range(wins)), 20)}
            (d / "v0-full-A.json").write_text(json.dumps(report))
        text = tables.paired_table(a, b, ["v0-full"], ["A"])
        self.assertIn("+100.0 pp: 20 / 0, p < 0.001", text)

    def test_g3_table_names_the_best_committed_arm_and_both_verdicts(self) -> None:
        d = self.dir / "g3"
        d.mkdir()
        wins = {"C_shatter": set(range(10)), "C_lantern": set(range(0, 10, 2)), "C_edge": set(range(4)),
                "A_lit": set(range(10)) - {9}}
        for arm in wins:
            (d / f"v5-full-{arm}.json").write_text(json.dumps({"manifest": {}, "runs": outcomes(wins[arm], 10)}))
        text = tables.g3_table(d, ["v5-full"])
        row = text.splitlines()[2]
        self.assertIn("| v5-full | C_shatter | -10.0 pp |", row)  # 9 of 10 against 10 of 10
        self.assertIn("FAIL / UNDECIDED", row)  # the point is below -3 pp; ten seeds cannot say it is
        self.assertIn("| 9 / 0 / 1 / 0 |", row)

    def test_row_b_verdicts_on_intervals(self) -> None:
        d = self.dir / "b"
        d.mkdir()
        plan = {  # (pool, arm): (win rate in 400, expressed share, close share of wins)
            ("full", "C_shatter"): (120, 1.0, 0.04),  # 30% win: B1 PASS; 4% close: B2 PASS
            ("full", "C_lantern"): (20, 1.0, 0.04),  # 5% win: interval wholly under 20%: B1 FAIL
            ("full", "C_edge"): (80, 1.0, 0.04),  # exactly 20% of 400: interval straddles 20%: UNDECIDED
            ("full", "A_lit"): (120, 0.3, 0.04),  # expression 30%: wholly under 60%: B2 FAIL
            ("fresh", "C_shatter"): (400, 1.0, 0.0),  # no close calls in 400 wins: upper 0.95% < 1%: B2 FAIL
            ("fresh", "C_lantern"): (120, 1.0, 0.20),  # 20% close: wholly over 10%: B2 FAIL
            ("fresh", "C_edge"): (80, 1.0, 0.04),  # 20% of 400 against a 10% floor: B1 PASS
            ("fresh", "A_lit"): (120, 1.0, 0.04),
        }
        for (pool, arm), (wins, expressed, close) in plan.items():
            way = bw.ARMS[arm][0]
            closes = round(close * wins)
            runs = [run_row(13000 + i, i < wins, way, expressed=(i % 10) < round(expressed * 10),
                            close=i < closes) for i in range(400)]
            (d / bw.report_name(0, pool, arm)).write_text(json.dumps({"manifest": {}, "runs": runs}))
        rows = tables.row_b(d)
        verdicts = {key: (value[1], value[4]) for key, value in rows.items()}
        self.assertEqual(("PASS", "PASS"), verdicts["full", "C_shatter"])
        self.assertEqual("FAIL", verdicts["full", "C_lantern"][0])
        self.assertEqual("UNDECIDED", verdicts["full", "C_edge"][0])
        self.assertEqual("FAIL", verdicts["full", "A_lit"][1])
        self.assertEqual("FAIL", verdicts["fresh", "C_shatter"][1])
        self.assertEqual("FAIL", verdicts["fresh", "C_lantern"][1])
        self.assertEqual("PASS", verdicts["fresh", "C_edge"][0])
        text = tables.row_b_table(d)
        self.assertEqual(2 + 8, len(text.splitlines()))
        self.assertIn("| V0 full | C_lantern |", text)

    def test_row_b_refuses_reports_without_per_fight_rows(self) -> None:
        d = self.dir / "old"
        d.mkdir()
        for pool in bw.POOLS:
            for arm in bw.COMMITTED + (bw.SKILLED,):
                runs = [run_row(13000 + i, True, bw.ARMS[arm][0]) for i in range(4)]
                for row in runs:
                    del row["fights"]
                (d / bw.report_name(0, pool, arm)).write_text(json.dumps({"manifest": {}, "runs": runs}))
        with self.assertRaises(ValueError):
            tables.row_b(d)

    def test_full_table_shape(self) -> None:
        write_table(self.dir / "v0", vows=(0,))
        write_table(self.dir / "v5", vows=(5,))
        write_table(self.dir / "r0", wins={"C_shatter": 4}, vows=(0,))
        write_table(self.dir / "r5", wins={"C_shatter": 4}, vows=(5,))
        seeds = (13000, 13009)
        text = tables.full_table(self.dir / "v0", self.dir / "v5", seeds, seeds,
                                 [(self.dir / "r0", self.dir / "r5")])
        win_rows = [ln for ln in text.splitlines() if ln.startswith("| V") and "%" in ln and "PASS" not in ln
                    and "FAIL" not in ln and "n/a" not in ln and "UNDECIDED" not in ln]
        self.assertEqual(4, len(win_rows))  # one win-rate row per cell
        self.assertIn(" 60.0% (", win_rows[0])
        gate_rows = [ln for ln in text.splitlines() if any(f"| {label} |" in ln for label in tables.GATE_LABELS)]
        self.assertEqual(4 * len(tables.GATE_LABELS), len(gate_rows))
        for row in gate_rows:  # cell, gate, measured, point, interval, verdict, one reference column
            self.assertEqual(7, len(row.strip("|").split("|")))
        self.assertIn("### Row B (V0, search player)", text)
        row_b_rows = text.split("### Row B (V0, search player)")[1].strip().splitlines()
        self.assertEqual(2 + 8, len(row_b_rows))
        self.assertTrue(row_b_rows[0].endswith("Before B1 / B2 |"))
        for label in tables.GATE_LABELS:
            self.assertEqual(4, sum(f"| {label} |" in ln for ln in gate_rows))

    def test_full_table_without_references_has_no_reference_columns(self) -> None:
        write_table(self.dir / "v0", vows=(0,))
        write_table(self.dir / "v5", vows=(5,))
        seeds = (13000, 13009)
        text = tables.full_table(self.dir / "v0", self.dir / "v5", seeds, seeds)
        self.assertNotIn("Ref 1", text)
        self.assertNotIn("Before B1", text)

    def test_tidy_marks_the_verdicts_that_moved_from_the_last_reference(self) -> None:
        write_table(self.dir / "v0", vows=(0,))
        write_table(self.dir / "v5", vows=(5,))
        write_table(self.dir / "r0", wins={"R": 5}, vows=(0,))
        write_table(self.dir / "r5", wins={"R": 5}, vows=(5,))
        seeds = (13000, 13009)
        full = tables.full_table(self.dir / "v0", self.dir / "v5", seeds, seeds, [(self.dir / "r0", self.dir / "r5")])
        tidy = tables.tidy_gates(full).splitlines()
        self.assertEqual(2 + 4 * len(tables.GATE_LABELS), len(tidy))
        g4 = [ln for ln in tidy if "| G4 |" in ln and "V0 full" in ln][0]
        self.assertIn("**PASS**", g4)  # random now loses; with five wins in ten it did not
        self.assertNotIn("**", [ln for ln in tidy if "| G2 |" in ln][0])
        with self.assertRaises(ValueError):
            tables.tidy_gates(tables.full_table(self.dir / "v0", self.dir / "v5", seeds, seeds))




if __name__ == "__main__":
    unittest.main()

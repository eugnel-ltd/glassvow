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

DUSK = bw.roster("duskblade")
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
            work = runner.plan(Path(tmp) / "out", DUSK, (13000, 13003), ["v0-fresh"], ["A"], chunk=2)
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
        rows = {arm: outcomes(set(range(wins)), 10) for arm, wins in zip(DUSK.committed, (4, 6, 6))}
        self.assertEqual(DUSK.committed[1], stats.best_committed(DUSK, rows))


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
    way, build = DUSK.arms[arm]
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
            for arm, (way, _) in DUSK.arms.items():
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
        text = tables.paired_table(DUSK, self.dir / "new", self.dir / "base", ["v0-fresh", "v0-full"])
        lines = text.splitlines()
        self.assertEqual(4, len(lines))  # header, rule, two cells
        self.assertEqual(f"| Cell | {' | '.join(DUSK.arms)} |", lines[0])
        # C_shatter gains seeds 6 and 7 of ten: +20.0 pp, 2 / 0, p = 2 * 1 / 4 = 0.50; the others are identical.
        self.assertIn("+20.0 pp: 2 / 0, p = 0.50 (same 8)", lines[2])
        self.assertIn("+0.0 pp: 0 / 0, p = 1.00 (same 10)", lines[2])

    def test_paired_table_names_a_tiny_p(self) -> None:
        a, b = self.dir / "a", self.dir / "b"
        for d, wins in ((a, 20), (b, 0)):
            d.mkdir()
            report = {"manifest": {}, "runs": outcomes(set(range(wins)), 20)}
            (d / "v0-full-A.json").write_text(json.dumps(report))
        text = tables.paired_table(DUSK, a, b, ["v0-full"], ["A"])
        self.assertIn("+100.0 pp: 20 / 0, p < 0.001", text)

    def test_g3_table_names_the_best_committed_arm_and_both_verdicts(self) -> None:
        d = self.dir / "g3"
        d.mkdir()
        wins = {"C_shatter": set(range(10)), "C_lantern": set(range(0, 10, 2)), "C_edge": set(range(4)),
                "A_lit": set(range(10)) - {9}}
        for arm in wins:
            (d / f"v5-full-{arm}.json").write_text(json.dumps({"manifest": {}, "runs": outcomes(wins[arm], 10)}))
        text = tables.g3_table(DUSK, d, ["v5-full"])
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
            way = DUSK.arms[arm][0]
            closes = round(close * wins)
            runs = [run_row(13000 + i, i < wins, way, expressed=(i % 10) < round(expressed * 10),
                            close=i < closes) for i in range(400)]
            (d / bw.report_name(0, pool, arm)).write_text(json.dumps({"manifest": {}, "runs": runs}))
        rows = tables.row_b(DUSK, d)
        verdicts = {key: (value[1], value[4]) for key, value in rows.items()}
        self.assertEqual(("PASS", "PASS"), verdicts["full", "C_shatter"])
        self.assertEqual("FAIL", verdicts["full", "C_lantern"][0])
        self.assertEqual("UNDECIDED", verdicts["full", "C_edge"][0])
        self.assertEqual("FAIL", verdicts["full", "A_lit"][1])
        self.assertEqual("FAIL", verdicts["fresh", "C_shatter"][1])
        self.assertEqual("FAIL", verdicts["fresh", "C_lantern"][1])
        self.assertEqual("PASS", verdicts["fresh", "C_edge"][0])
        text = tables.row_b_table(DUSK, d)
        self.assertEqual(2 + 8, len(text.splitlines()))
        self.assertIn("| V0 full | C_lantern |", text)

    def test_row_b_refuses_reports_without_per_fight_rows(self) -> None:
        d = self.dir / "old"
        d.mkdir()
        for pool in bw.POOLS:
            for arm in DUSK.committed + (bw.SKILLED,):
                runs = [run_row(13000 + i, True, DUSK.arms[arm][0]) for i in range(4)]
                for row in runs:
                    del row["fights"]
                (d / bw.report_name(0, pool, arm)).write_text(json.dumps({"manifest": {}, "runs": runs}))
        with self.assertRaises(ValueError):
            tables.row_b(DUSK, d)

    def test_full_table_shape(self) -> None:
        write_table(self.dir / "v0", vows=(0,))
        write_table(self.dir / "v5", vows=(5,))
        write_table(self.dir / "r0", wins={"C_shatter": 4}, vows=(0,))
        write_table(self.dir / "r5", wins={"C_shatter": 4}, vows=(5,))
        seeds = (13000, 13009)
        text = tables.full_table(DUSK, self.dir / "v0", self.dir / "v5", seeds, seeds,
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
        text = tables.full_table(DUSK, self.dir / "v0", self.dir / "v5", seeds, seeds)
        self.assertNotIn("Ref 1", text)
        self.assertNotIn("Before B1", text)

    def test_tidy_marks_the_verdicts_that_moved_from_the_last_reference(self) -> None:
        write_table(self.dir / "v0", vows=(0,))
        write_table(self.dir / "v5", vows=(5,))
        write_table(self.dir / "r0", wins={"R": 5}, vows=(0,))
        write_table(self.dir / "r5", wins={"R": 5}, vows=(5,))
        seeds = (13000, 13009)
        full = tables.full_table(DUSK, self.dir / "v0", self.dir / "v5", seeds, seeds, [(self.dir / "r0", self.dir / "r5")])
        tidy = tables.tidy_gates(full).splitlines()
        self.assertEqual(2 + 4 * len(tables.GATE_LABELS), len(tidy))
        g4 = [ln for ln in tidy if "| G4 |" in ln and "V0 full" in ln][0]
        self.assertIn("**PASS**", g4)  # random now loses; with five wins in ten it did not
        self.assertNotIn("**", [ln for ln in tidy if "| G2 |" in ln][0])
        with self.assertRaises(ValueError):
            tables.tidy_gates(tables.full_table(DUSK, self.dir / "v0", self.dir / "v5", seeds, seeds))


# ---------------------------------------------------------------- runner, chunks and merge

def fake_simulator(drop: set[str] | None = None, tweak=None):
    """A runner that writes the report `balance_sim.gd` would, from the command's own arguments."""
    calls: list[list[str]] = []

    def run(command: list[str], log: Path) -> int:
        args = dict(a[2:].split("=", 1) for a in command if a.startswith("--") and "=" in a)
        calls.append(command)
        first, count = int(args["seed0"]), int(args["runs"])
        arm = next(k for k, (way, build) in DUSK.arms.items() if (way, build) == (args["way"], args["build"]))
        report = {"manifest": manifest(int(args["vow"]), args["pool"], arm,
                                       seeds={"first": first, "last": first + count - 1, "count": count}),
                  "runs": [run_row(first + i, i % 2 == 0, args["way"]) for i in range(count)]}
        if tweak:
            tweak(args, report)
        Path(args["out"]).write_text(json.dumps(report))
        log.write_text("ok")
        return 0
    run.calls = calls
    return run


IDENTITY = {"content": "c0ffee", "tools": {"tools/balance_sim.gd": "aa"}}


class ChunkAndMergeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "override.cfg").write_text(OVERRIDE)
        self.out = self.root / "out"
        self.addCleanup(self.tmp.cleanup)

    def plan(self, **kwargs):
        defaults = dict(seeds=(13000, 13009), cells=["v0-fresh"], arms=["C_edge", "A"], chunk=4, play="search")
        defaults.update(kwargs)
        return runner.plan(self.out, DUSK, **defaults)

    def run_all(self, work, simulator=None, who=IDENTITY, jobs=2):
        simulator = simulator or fake_simulator()
        return runner.run_chunks(work, who, jobs, runner=simulator, root=self.root, progress=lambda text: None), simulator

    def test_plan_splits_each_arm_into_chunks_and_adds_the_replay(self) -> None:
        work = self.plan(replay=True)
        sizes = [(c.report, c.first, c.count) for c in work]
        self.assertEqual([("v0-fresh-C_edge", 13000, 4), ("v0-fresh-C_edge", 13004, 4), ("v0-fresh-C_edge", 13008, 2),
                          ("v0-fresh-A", 13000, 4), ("v0-fresh-A", 13004, 4), ("v0-fresh-A", 13008, 2),
                          ("v0-fresh-replay", 13000, bw.REPLAY)], sizes)
        command = work[0].command
        self.assertEqual(["godot", "--headless", "-s", "res://tools/balance_sim.gd", "--"], command[:5])
        for flag in ("--aspect=duskblade", "--vow=0", "--runs=4", "--seed0=13000", "--pool=fresh", "--way=edge",
                     "--build=adaptive", "--play=search"):
            self.assertIn(flag, command)
        self.assertIn("--way=none", work[-1].command)  # the replay is arm A
        self.assertNotIn("--play=search", self.plan(play="greedy")[0].command)
        for chunk in work:  # 1.0's bots unless named, and named in every command
            self.assertIn("--pilot=p8-d0-v3", chunk.command)
            self.assertIn("--search=s1", chunk.command)
        for chunk in self.plan(replay=True, pilot="p9", search="s2"):
            self.assertIn("--pilot=p9", chunk.command)
            self.assertIn("--search=s2", chunk.command)

    def test_plan_passes_weights_and_content_through_to_committed_arms_only(self) -> None:
        work = self.plan(weights=(2.0, 1.0), content=Path("/x/c.json"))
        self.assertIn("--wayCommit=2.0", work[0].command)
        self.assertIn("--content=/x/c.json", work[0].command)
        self.assertFalse(any(a.startswith("--wayCommit") for a in work[-1].command))

    def test_plan_refuses_bad_input(self) -> None:
        for kwargs in ({"arms": ["C_nope"]}, {"cells": ["v3-full"]}, {"cells": ["v0-mature"]}, {"cells": ["fresh"]},
                       {"chunk": 0}):
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                self.plan(**kwargs)

    def test_run_merge_and_resume(self) -> None:
        work = self.plan(replay=True)
        ran, simulator = self.run_all(work)
        self.assertEqual(len(work), ran)
        names = runner.merge_parts(self.out, work)
        self.assertEqual(["v0-fresh-A", "v0-fresh-C_edge", "v0-fresh-replay"], names)
        merged = json.loads((self.out / "v0-fresh-C_edge.json").read_text())
        self.assertEqual(list(range(13000, 13010)), [row["seed"] for row in merged["runs"]])
        self.assertEqual({"first": 13000, "last": 13009, "count": 10}, merged["manifest"]["seeds"])
        self.assertEqual(3, merged["manifest"]["chunks"])
        sidecar = json.loads(work[0].sidecar.read_text())
        self.assertEqual(IDENTITY, sidecar["identity"])
        self.assertEqual(([13000, 13003], "v0-fresh", "C_edge"), (sidecar["seeds"], sidecar["cell"], sidecar["arm"]))
        before = len(simulator.calls)
        ran, _ = self.run_all(work, simulator)  # resumable: everything is done
        self.assertEqual((0, before), (ran, len(simulator.calls)))

    def test_an_interrupted_run_resumes_only_the_missing_chunks(self) -> None:
        work = self.plan()
        self.run_all(work)
        work[2].sidecar.unlink()  # that chunk did not finish
        ran, simulator = self.run_all(work)
        self.assertEqual(1, ran)
        self.assertIn("--seed0=13008", simulator.calls[0])

    def test_resuming_with_other_content_or_tools_is_refused(self) -> None:
        work = self.plan()
        self.run_all(work)
        for who in ({"content": "other", "tools": IDENTITY["tools"]}, {"content": "c0ffee", "tools": {"tools/balance_sim.gd": "bb"}}):
            with self.subTest(who=who), self.assertRaises(RuntimeError) as ctx:
                self.run_all(work, who=who)
            self.assertIn("different content or simulator sources", str(ctx.exception))

    def test_resuming_with_other_parameters_is_refused(self) -> None:
        self.run_all(self.plan())
        for kwargs in ({"play": "greedy"}, {"weights": (2.0, 1.0)}, {"chunk": 5}):
            with self.subTest(kwargs=kwargs), self.assertRaises(RuntimeError) as ctx:
                self.run_all(self.plan(**kwargs))
            self.assertIn("other parameters", str(ctx.exception))

    def test_a_moved_output_directory_still_resumes(self) -> None:
        work = self.plan()
        self.run_all(work)
        moved = self.out.parent / "moved"
        self.out.rename(moved)
        self.out = moved
        ran, _ = self.run_all(self.plan())
        self.assertEqual(0, ran)

    def test_a_failing_or_silent_simulator_stops_the_run(self) -> None:
        work = self.plan()

        def fail(command, log):
            raise RuntimeError("exit 1")
        with self.assertRaises(RuntimeError):
            self.run_all(work, fail)
        with self.assertRaises(RuntimeError) as ctx:
            self.run_all(work, lambda command, log: 0)
        self.assertIn("wrote no report", str(ctx.exception))
        self.assertFalse(any(c.sidecar.exists() for c in work))

    def merge_after(self, tweak, **kwargs):
        work = self.plan(**kwargs)
        self.run_all(work, fake_simulator(tweak=tweak))
        return work

    def test_merge_refuses_chunks_from_different_content(self) -> None:
        def tweak(args, report):
            if args["seed0"] == "13004" and args["way"] == "edge":
                report["manifest"]["contentFileSha256"] = "other"
        with self.assertRaises(ValueError) as ctx:
            runner.merge_parts(self.out, self.merge_after(tweak))
        self.assertIn("contentFileSha256", str(ctx.exception))
        self.assertIn("refusing to merge", str(ctx.exception))

    def test_merge_refuses_chunks_from_different_tools_or_instruments(self) -> None:
        for key, value in (("driverSha256", "x"), ("pilot", "p9"), ("commit", "def"), ("godot", "4.8"),
                           ("play", "greedy"), ("policy", {"wayCommit": 2.0, "wayOff": 1.0})):
            with self.subTest(key=key), tempfile.TemporaryDirectory() as tmp:
                self.out = Path(tmp) / "out"
                def tweak(args, report, key=key, value=value):
                    if args["seed0"] == "13004" and args["way"] == "edge":
                        report["manifest"][key] = value
                with self.assertRaises(ValueError) as ctx:
                    runner.merge_parts(self.out, self.merge_after(tweak))
                self.assertIn(key, str(ctx.exception))

    def test_merge_refuses_chunk_sidecars_from_different_tools(self) -> None:
        work = self.plan()
        self.run_all(work)
        side = json.loads(work[1].sidecar.read_text())
        side["identity"]["tools"]["tools/balance_sim.gd"] = "zz"
        work[1].sidecar.write_text(json.dumps(side))
        with self.assertRaises(ValueError) as ctx:
            runner.merge_parts(self.out, work)
        self.assertIn("different content or tools", str(ctx.exception))

    def test_merge_refuses_a_gap_a_wrong_band_and_a_mislabelled_cell(self) -> None:
        work = self.plan()
        self.run_all(work)
        edge = [c for c in work if c.arm == "C_edge"]
        with self.assertRaises(ValueError):
            runner.merge_parts(self.out, [c for c in work if c is not edge[1]])  # a gap in the seeds
        with self.assertRaises(ValueError) as ctx:
            runner.merge_report("v0-fresh-C_edge", [c.part for c in edge[:2]], (13000, 13009))
        self.assertIn("not the planned", str(ctx.exception))
        self.out = self.root / "mislabelled"
        mislabelled = self.merge_after(lambda args, report: report["manifest"].update(pool="full"), arms=["A"])
        with self.assertRaises(ValueError) as ctx:
            runner.merge_parts(self.out, mislabelled)
        self.assertIn("not this cell and arm", str(ctx.exception))

    def test_merge_refuses_overlapping_chunks(self) -> None:
        work = self.plan(arms=["A"])
        self.run_all(work)
        copy_part = work[0].part.with_name("v0-fresh-A-13002.json")
        copy_part.write_text(work[0].part.read_text())
        with self.assertRaises(ValueError) as ctx:
            runner.merge_report("v0-fresh-A", [c.part for c in work] + [copy_part])
        self.assertIn("overlap", str(ctx.exception))

    def test_merge_directory_merges_an_archive_of_chunks_without_a_plan(self) -> None:
        work = self.plan()
        self.run_all(work)
        for c in work:
            c.sidecar.unlink()
        names = runner.merge_directory(self.out, self.root / "merged")
        self.assertEqual(["v0-fresh-A", "v0-fresh-C_edge"], names)
        self.assertEqual(10, len(json.loads((self.root / "merged/v0-fresh-A.json").read_text())["runs"]))
        with self.assertRaises(ValueError):
            runner.merge_directory(self.root / "merged")

    def band(self, name: str, first: int, last: int, **manifest_extra) -> Path:
        d = self.root / name
        d.mkdir()
        runs = [run_row(seed, seed % 2 == 0, "edge") for seed in range(first, last + 1)]
        m = manifest(0, "full", "C_edge", **manifest_extra)
        m["seeds"] = {"first": first, "last": last, "count": len(runs)}
        (d / "v0-full-C_edge.json").write_text(json.dumps({"manifest": m, "runs": runs}))
        return d

    def test_join_bands_concatenates_in_seed_order_and_refuses_mixed_instruments(self) -> None:
        lower, upper = self.band("lo", 13000, 13003), self.band("hi", 13004, 13007)
        summary = runner.join_bands(self.root / "joined", "v0-full", ["C_edge"], [upper, lower])
        self.assertEqual({"C_edge": (8, 13000, 13007)}, summary)
        joined = json.loads((self.root / "joined/v0-full-C_edge.json").read_text())
        self.assertEqual({"first": 13000, "last": 13007, "count": 8}, joined["manifest"]["seeds"])
        other = self.band("other", 13008, 13009, contentFileSha256="different")
        with self.assertRaises(ValueError) as ctx:
            runner.join_bands(self.root / "bad", "v0-full", ["C_edge"], [lower, other])
        self.assertIn("contentFileSha256", str(ctx.exception))
        again = self.band("again", 13002, 13005)
        with self.assertRaises(ValueError) as ctx:
            runner.join_bands(self.root / "bad2", "v0-full", ["C_edge"], [lower, again])
        self.assertIn("overlap", str(ctx.exception))

    def test_join_bands_refuses_bands_that_are_not_the_named_cell_and_arm(self) -> None:
        """Bands that agree with each other can still be the wrong report: C_shatter's, filed as C_edge."""
        for field, value in (("way", "shatter"), ("pool", "fresh"), ("vow", 5), ("build", "random")):
            with self.subTest(field=field):
                lower, upper = self.band(f"lo-{field}", 13000, 13003), self.band(f"hi-{field}", 13004, 13007)
                for band in (lower, upper):
                    path = band / "v0-full-C_edge.json"
                    report = json.loads(path.read_text())
                    report["manifest"][field] = value
                    path.write_text(json.dumps(report))
                with self.assertRaises(ValueError) as ctx:
                    runner.join_bands(self.root / f"bad-{field}", "v0-full", ["C_edge"], [lower, upper])
                self.assertIn("not this cell and arm", str(ctx.exception))

    def test_the_identity_digests_content_and_the_simulator_sources(self) -> None:
        (self.root / "content").mkdir()
        (self.root / "tools").mkdir()
        (self.root / "content/full-content.json").write_text("{}")
        (self.root / "tools/balance_sim.gd").write_text("a")
        first = runner.identity(self.root, None)
        self.assertEqual(["tools/balance_sim.gd"], list(first["tools"]))
        (self.root / "tools/balance_sim.gd").write_text("b")
        self.assertNotEqual(first, runner.identity(self.root, None))
        scratch = self.root / "scratch.json"
        scratch.write_text('{"x": 1}')
        self.assertNotEqual(first["content"], runner.identity(self.root, scratch)["content"])
        (self.root / "domain/rules").mkdir(parents=True)
        (self.root / "domain/rules/combat.gd").write_text("a")
        ruled = runner.identity(self.root, None)
        (self.root / "domain/rules/combat.gd").write_text("b")
        self.assertNotEqual(ruled["domain"], runner.identity(self.root, None)["domain"])


class CompareTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def write(self, name: str, mutate=None) -> Path:
        d = self.root / name
        d.mkdir()
        runs = [run_row(13000 + i, i % 2 == 0, "edge") for i in range(6)]
        report = {"manifest": manifest(0, "full", "C_edge"), "runs": runs}
        if mutate:
            mutate(report)
        (d / "v0-full-C_edge.json").write_text(json.dumps(report))
        return d

    def test_identical_rows_match_even_when_the_commit_differs(self) -> None:
        a, b = self.write("a"), self.write("b", lambda r: r["manifest"].update(commit="later"))
        results = compare.compare_directories(a, b)
        self.assertTrue(compare.identical(results))
        self.assertEqual((6, 6, ["commit"]), (results[0].rows, results[0].identical, results[0].manifest_differences))
        self.assertEqual(compare.digest_rows(json.loads((a / "v0-full-C_edge.json").read_text())["runs"]),
                         compare.digest_rows(json.loads((b / "v0-full-C_edge.json").read_text())["runs"]))

    def test_a_differing_field_and_a_missing_seed_are_reported(self) -> None:
        def mutate(report):
            report["runs"][2]["gold"] = 99
            del report["runs"][5]
        a, b = self.write("a"), self.write("b", mutate)
        result = compare.compare_directories(a, b)[0]
        self.assertFalse(compare.identical([result]))
        self.assertEqual([(13002, ["gold"])], result.differing)
        self.assertEqual([13005], result.missing)
        self.assertEqual(4, result.identical)
        self.assertIn("seed 13002 differs in: gold", compare.render([result]))

    def test_the_cli_exits_two_on_a_difference(self) -> None:
        a = self.write("a")
        b = self.write("b", lambda r: r["runs"][0].update(outcome="loss"))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(0, readout.main(["compare", str(a), str(a)]))
            self.assertEqual(2, readout.main(["compare", str(a), str(b)]))

    def test_chunks_are_merged_on_the_fly_when_no_merged_report_was_kept(self) -> None:
        d = self.root / "archive"
        (d / "parts").mkdir(parents=True)
        for first in (13000, 13003):
            runs = [run_row(seed, seed % 2 == 0, "edge") for seed in range(first, first + 3)]
            m = manifest(0, "full", "C_edge", seeds={"first": first, "last": first + 2, "count": 3})
            (d / "parts" / f"v0-full-C_edge-{first}.json").write_text(json.dumps({"manifest": m, "runs": runs}))
        result = compare.compare_directories(d, self.write("b"))[0]
        self.assertEqual((6, 6), (result.rows, result.identical))


# ---------------------------------------------------------------- candidate catalogues

CONTENT = json.dumps({
    "ways": [
        {"id": "shatter", "affinity": {"heavyBlow": 1.0, "cleave": 1.0}},
        {"id": "lantern", "affinity": {"aegis": 2.0, "preparation": 3.0}},
    ],
    "flame": {"trueMin": 0.8, "steadyFirstGain": 2},
    "cards": {
        "hearthfall": {
            "text": "Gain 4 block. Amber flame: gain 1 Ember.",
            "effects": [{"kind": "block", "n": 4}, {"kind": "ember", "n": 1, "lit": "lantern"}],
            "up": {"effects": [{"kind": "block", "n": 6}, {"kind": "ember", "n": 1, "lit": "lantern"}]},
        },
        "spall": {"text": "Deal 6.", "effects": [{"kind": "damage", "n": 6}]},
    },
}, indent=2)

SPEC = {
    "k1": [{"lever": "affinity", "way": "shatter", "card": "heavyBlow", "weight": 3.0},
           {"lever": "affinity", "way": "shatter", "card": "spall", "weight": 0.5}],
    "k2": [{"lever": "knob", "key": "trueMin", "old": "0.8", "new": "0.75"}],
    "k3": [{"lever": "affinity", "way": "lantern", "card": "aegis", "weight": None}],
    "k4": [{"lever": "strip_rider", "card": "hearthfall", "effect": {"kind": "ember", "n": 1, "lit": "lantern"},
            "text": " Amber flame: gain 1 Ember."}],
}


class CatalogueTests(unittest.TestCase):
    def test_each_lever_changes_only_what_it_names(self) -> None:
        base = json.loads(CONTENT)
        k1 = json.loads(catalogue.build(CONTENT, SPEC, "k1"))
        self.assertEqual({"heavyBlow": 3.0, "cleave": 1.0, "spall": 0.5}, k1["ways"][0]["affinity"])
        self.assertEqual(base["ways"][1], k1["ways"][1])
        k2 = json.loads(catalogue.build(CONTENT, SPEC, "k2"))
        self.assertEqual(0.75, k2["flame"]["trueMin"])
        self.assertEqual(base["cards"], k2["cards"])
        k3 = json.loads(catalogue.build(CONTENT, SPEC, "k3"))
        self.assertEqual({"preparation": 3.0}, k3["ways"][1]["affinity"])
        k4 = json.loads(catalogue.build(CONTENT, SPEC, "k4"))
        card = k4["cards"]["hearthfall"]
        self.assertEqual([{"kind": "block", "n": 4}], card["effects"])
        self.assertEqual([{"kind": "block", "n": 6}], card["up"]["effects"])
        self.assertEqual("Gain 4 block.", card["text"])
        self.assertEqual(base["cards"]["spall"], k4["cards"]["spall"])

    def test_levers_join_with_a_plus(self) -> None:
        both = json.loads(catalogue.build(CONTENT, SPEC, "k2+k3"))
        self.assertEqual(0.75, both["flame"]["trueMin"])
        self.assertEqual({"preparation": 3.0}, both["ways"][1]["affinity"])

    def test_levers_that_cannot_apply_exactly_are_refused(self) -> None:
        bad = {"nowhere": [{"lever": "affinity", "way": "edge", "card": "x", "weight": 1.0}],
               "missing": [{"lever": "affinity", "way": "shatter", "card": "absent", "weight": None}],
               "twice": [{"lever": "knob", "key": "n", "old": "1", "new": "2"}],
               "never": [{"lever": "knob", "key": "trueMin", "old": "0.9", "new": "1"}],
               "once": [{"lever": "strip_rider", "card": "spall", "effect": {"kind": "damage", "n": 6}}],
               "kind": [{"lever": "mystery"}]}
        for name in bad:
            with self.subTest(name=name), self.assertRaises(ValueError):
                catalogue.build(CONTENT, bad, name)
        with self.assertRaises(ValueError):
            catalogue.build(CONTENT, SPEC, "k9")

    def test_the_writer_writes_json_files_and_the_cli_lists_them(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "content.json").write_text(CONTENT)
            (root / "spec.json").write_text(json.dumps(SPEC))
            with contextlib.redirect_stdout(io.StringIO()) as out:
                self.assertEqual(0, readout.main(["candidates", str(root / "content.json"), str(root / "spec.json"),
                                                  str(root / "cat"), "--names", "k1,k2+k3"]))
            self.assertEqual(sorted(str(root / "cat" / n) for n in ("k1.json", "k2+k3.json")),
                             sorted(out.getvalue().split()))
            self.assertEqual(0.75, json.loads((root / "cat/k2+k3.json").read_text())["flame"]["trueMin"])


def other_class(directory: Path, ways_listed: tuple[str, ...]) -> bw.Roster:
    """A class whose way ids are not the Duskblade's (or, with none listed, one that declares no ways)."""
    content, class_file = directory / "content.json", directory / "classes.json"
    content.write_text(json.dumps({"aspects": [
        {"id": "duskblade", "ways": [{"id": "shatter"}, {"id": "lantern"}, {"id": "edge"}]},
        {"id": "ashwarden", "nameBare": "Ashwarden", "ways": [{"id": way} for way in ways_listed]}]}))
    class_file.write_text(json.dumps({"ashwarden": {"wayStats": {"smolder": "smolders", "hand": "cardsHeld"}}}))
    return bw.roster("ashwarden", content, class_file)


class OtherClassTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "override.cfg").write_text(OVERRIDE)
        self.addCleanup(self.tmp.cleanup)

    def test_the_plan_names_the_aspect_the_arms_and_the_entry_pool(self) -> None:
        ash = other_class(self.root, ("smolder", "hand"))
        work = runner.plan(self.root / "out", ash, (12000, 12003), ["v0-entry", "v0-full"], list(ash.arms), chunk=4)
        self.assertEqual(2 * len(ash.arms), len(work))
        self.assertEqual(["v0-entry-C_smolder", "v0-entry-C_hand"], [c.report for c in work[:2]])
        self.assertIn("--aspect=ashwarden", work[0].command)
        self.assertIn("--pool=entry", work[0].command)
        self.assertIn("--way=hand", work[1].command)
        self.assertEqual((0, "entry"), runner.parse_cell("v0-entry"))

    def test_chunks_of_another_class_run_merge_and_check_their_cell_and_arm(self) -> None:
        ash = other_class(self.root, ("smolder", "hand"))
        work = runner.plan(self.root / "out", ash, (12000, 12005), ["v0-entry"], ["C_hand", "A"], chunk=3)

        def simulate(command: list[str], log: Path) -> int:
            args = dict(a[2:].split("=", 1) for a in command if a.startswith("--") and "=" in a)
            first, count = int(args["seed0"]), int(args["runs"])
            manifest_ = {"aspect": args["aspect"], "vow": int(args["vow"]), "pool": args["pool"], "way": args["way"],
                         "build": args["build"], "commit": "abc", "seeds": {"first": first, "count": count}}
            Path(args["out"]).write_text(json.dumps(
                {"manifest": manifest_, "runs": [run_row(first + i, True, args["way"]) for i in range(count)]}))
            return 0
        runner.run_chunks(work, IDENTITY, 2, runner=simulate, root=self.root, progress=lambda text: None)
        self.assertEqual(["v0-entry-A", "v0-entry-C_hand"], runner.merge_parts(self.root / "out", work))
        merged = json.loads((self.root / "out/v0-entry-C_hand.json").read_text())
        self.assertEqual(("ashwarden", "hand"), (merged["manifest"]["aspect"], merged["manifest"]["way"]))

    def test_an_aspect_with_no_ways_has_no_committed_arms_and_says_so(self) -> None:
        bare = other_class(self.root, ())
        runner.plan(self.root / "out", bare, (12000, 12003), ["v0-entry"], list(bare.arms))  # A, A_lit and R run
        with self.assertRaisesRegex(ValueError, "ashwarden declares no ways in content, so it has no committed arms"):
            runner.plan(self.root / "out", bare, (12000, 12003), ["v0-entry"], ["C_smolder"])

    def test_the_commands_that_read_committed_arms_refuse_an_aspect_with_no_ways(self) -> None:
        bare = other_class(self.root, ())
        with mock.patch.object(readout, "REPO", self.root), mock.patch.object(bw, "roster", return_value=bare), \
                mock.patch.object(runner, "plan", wraps=runner.plan) as planned:
            with self.assertRaisesRegex(ValueError, "no committed arms"):
                readout.main(["run", str(self.root / "out"), "--aspect", "ashwarden", "--seeds", "13000-13003",
                              "--arms", "C_smolder"])
            self.assertFalse((self.root / "out").exists())  # refused before anything was written
            for argv in (["g3", str(self.root), "v0-full"], ["rowb", str(self.root)],
                         ["table", str(self.root), str(self.root), "--v0-seeds", "13000-13003",
                          "--v5-seeds", "13000-13003"]):
                with self.subTest(argv=argv), self.assertRaisesRegex(ValueError, "cannot be graded"):
                    readout.main([*argv, "--aspect", "ashwarden"])
            self.assertEqual(1, planned.call_count)

    def test_the_default_arms_of_a_class_are_its_own(self) -> None:
        bare = other_class(self.root, ())
        with mock.patch.object(readout, "REPO", self.root), mock.patch.object(bw, "roster", return_value=bare), \
                mock.patch.object(runner, "run_chunks", return_value=0), \
                mock.patch.object(runner, "merge_parts", return_value=[]), \
                mock.patch.object(runner, "identity", return_value={}), contextlib.redirect_stdout(io.StringIO()):
            readout.main(["run", str(self.root / "out"), "--aspect", "ashwarden", "--seeds", "13000-13003"])
        self.assertEqual({"A", "A_lit", "R"}, {c.arm for c in runner.plan(
            self.root / "x", bare, (13000, 13003), ["v0-entry"], list(bare.arms))})


class CommandLineTests(unittest.TestCase):
    def test_paired_g3_and_rowb_commands_print_their_tables(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_table(root / "new", wins={"C_shatter": 8})
            write_table(root / "base")
            with contextlib.redirect_stdout(io.StringIO()) as out:
                readout.main(["paired", str(root / "new"), str(root / "base"), "v0-full"])
                readout.main(["g3", str(root / "base"), "v0-full"])
            self.assertIn("+20.0 pp: 2 / 0", out.getvalue())
            self.assertIn("| v0-full | C_shatter |", out.getvalue())

    def test_the_parser_knows_every_documented_command(self) -> None:
        names = set(readout.build_parser()._subparsers._group_actions[0].choices)
        self.assertEqual({"run", "merge", "join", "paired", "g3", "rowb", "table", "compare", "candidates"}, names)

    def test_table_command_with_an_odd_reference_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            readout.cmd_table(mock.Mock(refs=[Path("a")], v0=Path("x"), v5=Path("y"), v0_seeds="13000-13009",
                                        v5_seeds="13000-13009", tidy=False))


if __name__ == "__main__":
    unittest.main()

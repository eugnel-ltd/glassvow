#!/usr/bin/env python3
"""Self-test for tools/balance_ways.py on a synthetic results fixture.

Run: python3 -B tests/test_balance_ways.py
"""
from __future__ import annotations

import contextlib
import copy
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "balance_ways", Path(__file__).resolve().parents[1] / "tools/balance_ways.py")
ways = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ways)

SEEDS = (13000, 13009)
N = SEEDS[1] - SEEDS[0] + 1


def reading(dominant: str, tier: str) -> dict:
    return {"aspect": 0, "dominant": dominant, "fringe": "", "tier": tier, "purity": 0.7,
            "shares": {}, "mass": 6.0}


def rows(wins: int, way: str, steady: int = N, true: int = N, win_ways: tuple = (),
         stalls: int = 0) -> list[dict]:
    """N runs: the first `wins` win; `steady` runs end Act 1 Steady and `true`
    end Act 2 True in `way`; winners end dominant in `win_ways` cyclically."""
    out = []
    for i in range(N):
        outcome = "win" if i < wins else ("stall" if i < wins + stalls else "loss")
        dominant = win_ways[i % len(win_ways)] if win_ways and i < wins else way
        acts = [reading(way, "STEADY" if i < steady else "KINDLING"),
                reading(way, "TRUE" if i < true else "STEADY")]
        out.append({"seed": SEEDS[0] + i, "outcome": outcome, "error": "",
                    "flame": {"way": way, "end": reading(dominant, "STEADY"), "acts": acts,
                              "rates": {key: 1.0 for key in ways.RATES}}})
    return out


# Cell -> arm -> rows. V0 full sits exactly on every threshold (all PASS);
# V0 fresh breaks every gate; the V5 cells are ordinary.
TABLE = {
    (0, "full"): {"C_shatter": rows(6, "shatter", 7, 4), "C_lantern": rows(6, "lantern", 7, 4),
                  "C_edge": rows(5, "edge", 7, 4),
                  "A": rows(6, "none", win_ways=("shatter", "lantern", "edge")),
                  "R": rows(2, "none")},
    (0, "fresh"): {"C_shatter": rows(5, "shatter", 3, 3), "C_lantern": rows(5, "lantern"),
                   "C_edge": rows(3, "edge"), "A": rows(9, "none", win_ways=("shatter",)),
                   "R": rows(4, "none", stalls=1)},
    (5, "full"): {"C_shatter": rows(3, "shatter"), "C_lantern": rows(3, "lantern"),
                  "C_edge": rows(3, "edge"), "A": rows(4, "none", win_ways=("lantern", "edge")),
                  "R": rows(0, "none")},
    (5, "fresh"): {"C_shatter": rows(2, "shatter"), "C_lantern": rows(2, "lantern"),
                   "C_edge": rows(2, "edge"), "A": rows(2, "none", win_ways=("shatter", "edge")),
                   "R": rows(0, "none")},
}
# The flame-aware adaptive arm plays as A in the fixture, so every gate it reads
# grades as A's floor row does; one test moves it apart.
for _arms in TABLE.values():
    _arms["A_lit"] = copy.deepcopy(_arms["A"])


def write_table(directory: Path, table: dict = TABLE, commit: str = "c0ffee") -> None:
    for (vow, pool), arms in table.items():
        for arm, runs in arms.items():
            way, build = ways.ARMS[arm]
            manifest = {"vow": vow, "pool": pool, "way": way, "build": build,
                        "aspect": "duskblade", "commit": commit, "contentFileSha256": "ab" * 32}
            (directory / ways.report_name(vow, pool, arm)).write_text(
                json.dumps({"manifest": manifest, "runs": runs}))
        replay = {"manifest": {"commit": commit}, "runs": arms["A"][:ways.REPLAY]}
        (directory / ways.replay_name(vow, pool)).write_text(json.dumps(replay))


def verdicts(result: dict, cell: tuple) -> list[str]:
    return [gate[-1] for gate in result["cells"][cell]["gates"]]


class BalanceWaysTest(unittest.TestCase):
    def test_seeds_default_quick_and_acceptance_guard(self) -> None:
        self.assertEqual((13000, 13199), ways.DEFAULT_SEEDS)
        self.assertEqual(40, ways.QUICK_SEEDS[1] - ways.QUICK_SEEDS[0] + 1)
        self.assertEqual((12000, 12099), ways.parse_seeds("12000-12099"))
        for bad in ("5000-5010", "4000-6000", "13199-13000", "13000", "a-b"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                ways.parse_seeds(bad)

    def test_commands_pair_every_arm_on_one_seed_range(self) -> None:
        work = ways.jobs("godot", (13000, 13199), Path("/out"))
        self.assertEqual(4 * (len(ways.ARMS) + 1), len(work))
        self.assertEqual(len(work), len({name for name, _ in work}))
        flags = dict(arg[2:].split("=", 1) for arg in
                     ways.sim_command("godot", 5, "fresh", "C_lantern", 13000, 200, Path("/o.json"))[5:])
        self.assertEqual({"aspect": "duskblade", "vow": "5", "runs": "200", "seed0": "13000",
                          "pool": "fresh", "way": "lantern", "build": "adaptive", "out": "/o.json"}, flags)
        random_arm = ways.sim_command("godot", 0, "full", "R", 13000, 3, Path("/r.json"))
        self.assertIn("--way=none", random_arm)
        self.assertIn("--build=random", random_arm)
        self.assertFalse(any(arg.startswith("--content=") for _, command in work for arg in command))
        swept = ways.jobs("godot", (13000, 13199), Path("/out"), Path("/sweep/point.json"))
        self.assertTrue(all(command[-1] == "--content=/sweep/point.json" for _, command in swept))
        self.assertFalse(any(arg.startswith("--way") and "=" in arg and not arg.startswith("--way=")
                             for _, command in work for arg in command))

    def test_way_weights_reach_only_the_committed_arms(self) -> None:
        self.assertEqual((2.0, 1.0), ways.parse_weights("2.0/1.0"))
        for bad in ("2.0", "2/0", "-1/1", "a/b", "2/1/1"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                ways.parse_weights(bad)
        for name, command in ways.jobs("godot", (13000, 13199), Path("/out"), None, (2.0, 1.0)):
            weighted = "--wayCommit=2.0" in command and "--wayOff=1.0" in command
            self.assertEqual(name.rsplit("-", 1)[-1] in ways.COMMITTED, weighted, name)

    def test_gates_pass_on_their_exact_thresholds_and_fail_beyond(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp))
            result = ways.grade(Path(temp), SEEDS)
        self.assertEqual(["PASS"] * 9, verdicts(result, (0, "full")))
        self.assertEqual(["FAIL"] * 9, verdicts(result, (0, "fresh")))
        self.assertEqual("n/a", verdicts(result, (5, "fresh"))[0])
        self.assertEqual("n/a", verdicts(result, (5, "fresh"))[4])
        stats = result["cells"][0, "full"]["stats"]
        self.assertEqual((0.7, 0.4), (float(stats["C_edge"]["steady1"]), float(stats["C_edge"]["true2"])))
        self.assertNotIn("steady1", stats["A"])
        self.assertNotIn("steady1", stats["A_lit"])

    def test_g3_and_g6_read_a_lit_and_keep_a_as_the_floor(self) -> None:
        self.assertEqual(("none", "lit"), ways.ARMS["A_lit"])
        lit = ways.sim_command("godot", 0, "full", "A_lit", 13000, 3, Path("/l.json"))
        self.assertIn("--way=none", lit)
        self.assertIn("--build=lit", lit)
        table = copy.deepcopy(TABLE)
        # A_lit wins 9 of 10, all Shatter: G3 (above +15 pp) and G6 fail on it;
        # A, unchanged, still passes both floor rows.
        table[0, "full"]["A_lit"] = rows(9, "none", win_ways=("shatter",))
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp), table)
            result = ways.grade(Path(temp), SEEDS)
            text = ways.render(result)
        gates = result["cells"][0, "full"]["gates"]
        self.assertEqual(["PASS", "PASS", "FAIL", "PASS", "PASS", "FAIL", "PASS", "PASS", "PASS"],
                         [gate[-1] for gate in gates])
        self.assertIn("A_lit 90.0%", gates[2][1])
        self.assertIn("A 60.0%", gates[7][1])
        self.assertIn("of 9 A_lit wins", gates[5][1])
        self.assertIn("of 6 A wins", gates[8][1])
        intervals = result["cells"][0, "full"]["intervals"]
        self.assertTrue(intervals[2][0].startswith("A_lit - ") and intervals[7][0].startswith("A - "))
        self.assertIn("| A_lit | 9/10 | 90.0% |", text)
        self.assertIn("| G3 floor: the commit-blind adaptive arm |", text)

    def test_g5_grades_the_fresh_pool_on_steady_alone(self) -> None:
        def g5(steady: int) -> str:
            table = copy.deepcopy(TABLE)
            for arm, way in (("C_shatter", "shatter"), ("C_lantern", "lantern"), ("C_edge", "edge")):
                table[0, "fresh"][arm] = rows(5, way, steady, 0)
            with tempfile.TemporaryDirectory() as temp:
                write_table(Path(temp), table)
                gate = ways.grade(Path(temp), SEEDS)["cells"][0, "fresh"]["gates"][4]
            self.assertIn("True not graded", gate[2])
            return gate[3]

        self.assertEqual("PASS", g5(4))
        self.assertEqual("FAIL", g5(3))

    def test_g5_grades_the_runs_alive_at_the_act_end(self) -> None:
        """Readout 13: a run that died before an act's end has no reading there and
        leaves G5's denominator; the all-runs figure is still printed beside it."""
        table = copy.deepcopy(TABLE)
        for arm, way in (("C_shatter", "shatter"), ("C_lantern", "lantern"), ("C_edge", "edge")):
            runs = rows(5, way, 7, 4)
            for row in runs[5:]:  # five die in Act 1; their acts are empty
                row["flame"]["acts"] = []
            table[0, "full"][arm] = runs
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp), table)
            result = ways.grade(Path(temp), SEEDS)
            text = ways.render(result)
        stats = result["cells"][0, "full"]["stats"]["C_edge"]
        self.assertEqual((5, 5), stats["steady1Alive"])
        self.assertEqual((4, 5), stats["true2Alive"])
        self.assertEqual((0.5, 0.4), (float(stats["steady1"]), float(stats["true2"])))
        gate = result["cells"][0, "full"]["gates"][4]
        self.assertEqual("PASS", gate[3])  # 100% and 80% of the alive, against 50% and 40% of all
        self.assertIn("100.0% of runs alive", gate[1])
        self.assertIn("all runs 50.0%", gate[1])
        self.assertIn("5 alive", result["cells"][0, "full"]["intervals"][4][0])
        self.assertIn("| 50.0% (100.0% of 5) | 40.0% (80.0% of 5) |", text)

    def test_render_prints_every_cell_and_gate(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp))
            text = ways.render(ways.grade(Path(temp), SEEDS), 12.3)
        for vow, pool in TABLE:
            self.assertIn(f"### V{vow}, {pool} pool", text)
        for gate in range(1, 8):
            self.assertIn(f"| G{gate} ", text)
        self.assertIn("| C_edge | 5/10 | 50.0% |", text)
        self.assertIn("Wall time 12 s.", text)

    def test_missing_metrics_unpaired_seeds_and_mixed_builds_fail_closed(self) -> None:
        def broken(mutate) -> str:
            table = copy.deepcopy(TABLE)
            mutate(table)
            with tempfile.TemporaryDirectory() as temp:
                write_table(Path(temp), table)
                with self.assertRaises(ValueError) as caught:
                    ways.grade(Path(temp), SEEDS)
            return str(caught.exception)

        self.assertIn("missing flame metrics", broken(lambda t: t[5, "full"]["C_edge"][3].pop("flame")))
        self.assertIn("per-fight rates", broken(lambda t: t[0, "full"]["A"][0]["flame"].update(rates={})))
        self.assertIn("do not pair", broken(lambda t: t[0, "full"]["A_lit"].pop()))
        self.assertIn("malformed flame reading",
                      broken(lambda t: t[0, "full"]["C_lantern"][2]["flame"]["acts"].append({})))
        self.assertIn("do not pair", broken(lambda t: t[0, "fresh"]["R"].pop()))
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp))
            other = Path(temp) / ways.report_name(5, "fresh", "A")
            report = json.loads(other.read_text())
            report["manifest"]["commit"] = "deadbeef"
            other.write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, "more than one build"):
                ways.grade(Path(temp), SEEDS)
            report["manifest"]["commit"] = "c0ffee"
            report["manifest"]["way"] = "edge"
            other.write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, "not this cell and arm"):
                ways.grade(Path(temp), SEEDS)

    def test_a_replay_that_differs_fails_g7(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp))
            path = Path(temp) / ways.replay_name(0, "full")
            replay = json.loads(path.read_text())
            replay["runs"][1]["outcome"] = "loss"
            path.write_text(json.dumps(replay))
            gates = ways.grade(Path(temp), SEEDS)["cells"][0, "full"]["gates"]
        self.assertEqual("FAIL", gates[6][-1])
        self.assertIn("replay 2/3 identical", gates[6][1])

    def test_play_reaches_every_command_and_must_agree_across_reports(self) -> None:
        searched = ways.jobs("godot", (13000, 13199), Path("/out"), play="search")
        self.assertTrue(all(command[-1] == "--play=search" for _, command in searched))
        self.assertFalse(any("--play" in arg for _, command in ways.jobs("godot", (13000, 13199), Path("/out"))
                             for arg in command))
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp))
            self.assertEqual("greedy", ways.grade(Path(temp), SEEDS)["play"])
            other = Path(temp) / ways.report_name(0, "full", "R")
            report = json.loads(other.read_text())
            report["manifest"]["play"] = "search"
            other.write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, "more than one player"):
                ways.grade(Path(temp), SEEDS)

    def test_a_split_table_runs_and_grades_one_vow(self) -> None:
        self.assertEqual((0,), ways.parse_vows("0"))
        self.assertEqual((0, 5), ways.parse_vows("5,0"))
        for bad in ("", "1", "0,x", "0,,5"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                ways.parse_vows(bad)
        work = ways.jobs("godot", (13000, 13399), Path("/out"), vows=(5,))
        self.assertEqual(2 * (len(ways.ARMS) + 1), len(work))
        self.assertTrue(all(name.startswith("v5-") for name, _ in work))
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp))
            for name in Path(temp).iterdir():
                if name.name.startswith("v0-"):
                    name.unlink()
            self.assertEqual([(5, "fresh"), (5, "full")],
                             list(ways.grade(Path(temp), SEEDS, (5,))["cells"]))
            with self.assertRaises(ValueError):
                ways.grade(Path(temp), SEEDS)

    def test_interval_verdicts_leave_a_straddled_threshold_undecided(self) -> None:
        low, high = ways.wilson(50, 100)
        self.assertEqual((0.5, low, high), ways.interval(50, 100))
        d, d_low, d_high = ways.difference((60, 100), (40, 100))
        self.assertAlmostEqual(0.2, d)
        self.assertTrue(d_low < 0.2 < d_high and d_high - d_low < 0.3)
        self.assertEqual(ways.difference((40, 100), (60, 100))[1], -d_high)
        self.assertEqual("PASS", ways.decided([True, True]))
        self.assertEqual("FAIL", ways.decided([True, None, False]))
        self.assertEqual("UNDECIDED", ways.decided([True, None]))
        self.assertIs(True, ways.at_least((0.6, 0.55, 0.65), 0.5))
        self.assertIsNone(ways.at_least((0.52, 0.45, 0.6), 0.5))
        self.assertIs(False, ways.at_most((0.8, 0.7, 0.9), 0.6))
        # V0 full sits exactly on each point threshold with 10 seeds: the intervals cannot decide.
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp))
            intervals = ways.grade(Path(temp), SEEDS)["cells"][0, "full"]["intervals"]
        self.assertEqual("UNDECIDED", intervals[0][1])
        self.assertIn("n=10", intervals[0][0])
        self.assertEqual("PASS", intervals[6][1])

    def test_feel_reads_the_per_fight_flame_rows(self) -> None:
        self.assertEqual("edge", ways.expressed({"edge": 2.0, "shatter": 1.0}))
        self.assertEqual("", ways.expressed({"edge": 1.0, "shatter": 1.0}))
        self.assertEqual("", ways.expressed({}))
        self.assertIsNone(ways.feel(rows(5, "edge"), "edge"))

        def fight(result: str, hp: int, plays: dict, act: int = 1) -> tuple[dict, dict]:
            return ({"act": act, "result": result, "turns": 4, "hpLost": 10},
                    {"dominant": "lantern", "tier": "STEADY", "plays": plays, "hp": hp, "maxHp": 80})

        won = [fight("win", 15, {"edge": 1.0}), fight("win", 60, {"lantern": 1.0}),
               fight("win", 70, {"edge": 0.5, "lantern": 0.5})]
        lost = [fight("win", 50, {"edge": 1.0}), fight("loss", 0, {"edge": 1.0}, act=2)]
        runs = [{"seed": 1, "outcome": "win", "fights": [f for f, _ in won],
                 "flame": {"fights": [g for _, g in won]}},
                {"seed": 2, "outcome": "loss", "fights": [f for f, _ in lost],
                 "flame": {"fights": [g for _, g in lost]}}]
        edge = ways.feel(runs, "edge")
        self.assertEqual((5, 4, 1, 3), (edge["fights"], edge["won"], edge["close"], edge["shown"]))
        self.assertEqual((0, 1, 0), edge["deaths"])
        self.assertEqual(4.0, edge["turns"])
        self.assertEqual(1, ways.feel(runs, "none")["shown"])  # A and R read the starting flame

    def test_cli_grades_saved_reports_and_rejects_bad_options(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            write_table(Path(temp))
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = ways.main(["--from-dir", temp, "--seeds", f"{SEEDS[0]}-{SEEDS[1]}"])
        self.assertEqual(0, code)
        self.assertIn("### V0, full pool", out.getvalue())
        for argv in (["--quick", "--seeds", "13000-13009"], ["--seeds", "4000-4100"], ["--jobs", "0"],
                     ["--content", "/no/such/catalogue.json"],
                     ["--from-dir", "/tmp", "--content", __file__]):
            with self.subTest(argv=argv), contextlib.redirect_stderr(io.StringIO()), \
                    self.assertRaises(SystemExit) as caught:
                ways.main(argv)
            self.assertEqual(2, caught.exception.code)


if __name__ == "__main__":
    unittest.main()

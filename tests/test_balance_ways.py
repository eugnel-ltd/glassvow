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
        self.assertEqual(["PASS"] * 7, verdicts(result, (0, "full")))
        self.assertEqual(["FAIL"] * 7, verdicts(result, (0, "fresh")))
        self.assertEqual("n/a", verdicts(result, (5, "fresh"))[0])
        self.assertEqual("n/a", verdicts(result, (5, "fresh"))[4])
        stats = result["cells"][0, "full"]["stats"]
        self.assertEqual((0.7, 0.4), (float(stats["C_edge"]["steady1"]), float(stats["C_edge"]["true2"])))
        self.assertNotIn("steady1", stats["A"])

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

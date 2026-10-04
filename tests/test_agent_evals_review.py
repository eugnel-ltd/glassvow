#!/usr/bin/env python3
"""Review-driven tests for the agent eval harness: parity, confirmation, graders, approvals."""
from __future__ import annotations

import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_agent_evals import (ROOT, SURFACE, FakeBackend, Workspace, diff_adding,  # noqa: E402
                              healthy_results, make_cases, model_script, proposer_script)

from agent_evals import approvals, cli  # noqa: E402
from agent_evals.backends import ClaudeCliBackend  # noqa: E402
from agent_evals.baseline import run_baseline  # noqa: E402
from agent_evals.decision import Deltas, Noise, decide  # noqa: E402
from agent_evals.diagnostics import TRIVIAL_LIMIT, trivial_answerer_scores  # noqa: E402
from agent_evals.evalspec import load_cases, load_eval  # noqa: E402
from agent_evals.hillclimb import ScoreCard, Version  # noqa: E402
from agent_evals.models import Case  # noqa: E402
from agent_evals.patching import added_text, find_injection  # noqa: E402

NOISE = Noise(train=0.05, test=0.05, cost=1.0)
PADDING = "x" * 2000


def card(test: float, cost: float, workspace: Workspace) -> ScoreCard:
    table = {c.id: [test] for c in workspace.cases}
    return ScoreCard(test, test, cost, table, table, [])


def finishing_climb(testcase: unittest.TestCase, goal: str, texts: list[str],
                    scores: list[tuple[float, float]]):
    workspace = Workspace(testcase)
    climb = workspace.climb(FakeBackend(model_script()), FakeBackend(proposer_script([])),
                            goal=goal)
    climb.noise = NOISE
    climb.work.parent.mkdir(parents=True)
    versions = [Version(n, text, card(t, c, workspace))
                for n, (text, (t, c)) in enumerate(zip(texts, scores))]
    climb.baseline = versions[0].card
    return workspace, climb, versions


class KeepRuleTests(unittest.TestCase):
    def test_a_gain_must_clear_the_min_gain_floor_as_well_as_the_noise(self) -> None:
        noise = Noise(0.01, 0.01, 1.0)
        self.assertEqual("improved", decide("accuracy", Deltas(0.2, 0.2, 0), noise, 0.05).reason)
        self.assertEqual("no-gain", decide("accuracy", Deltas(0.04, 0.04, 0), noise, 0.05).reason)
        self.assertEqual("overfit", decide("accuracy", Deltas(0.2, 0.04, 0), noise, 0.05).reason)
        self.assertTrue(decide("accuracy", Deltas(0.04, 0.04, 0), noise, 0.0).keep)

    def test_parity_is_judged_against_the_baseline_not_the_incumbent(self) -> None:
        cheaper = -500.0
        within = decide("cost-at-parity", Deltas(-0.04, -0.04, cheaper, -0.04, -0.04), NOISE)
        self.assertEqual((True, "cheaper"), (within.keep, within.reason))
        drifted = decide("cost-at-parity", Deltas(-0.04, -0.04, cheaper, -0.08, -0.08), NOISE)
        self.assertEqual((False, "regress"), (drifted.keep, drifted.reason))
        train_only = decide("cost-at-parity", Deltas(0.0, 0.0, cheaper, -0.08, 0.0), NOISE)
        self.assertEqual("regress", train_only.reason)

    def test_two_small_kept_steps_that_drift_past_parity_refuse_the_second(self) -> None:
        workspace, climb, versions = finishing_climb(
            self, "cost-at-parity", ["base", "step one", "step two"],
            [(0.50, 900.0), (0.46, 600.0), (0.42, 300.0)])
        self.assertEqual(1, climb._select_best(versions).round)
        step_two = versions[2].card
        deltas = Deltas(step_two.train - versions[1].card.train, step_two.test - versions[1].card.test,
                        step_two.cost - versions[1].card.cost,
                        step_two.train - climb.baseline.train, step_two.test - climb.baseline.test)
        self.assertFalse(decide("cost-at-parity", deltas, NOISE).keep)


class FinishTests(unittest.TestCase):
    def test_accuracy_restores_the_best_version_by_test_score(self) -> None:
        workspace, climb, versions = finishing_climb(
            self, "accuracy", ["v0", "GENERAL v1", "GENERAL v2"], [(0.5, 100), (0.9, 100), (0.7, 100)])
        summary = climb._finish(versions, "completed")
        self.assertEqual(1, summary["best_round"])
        self.assertEqual("GENERAL v1", climb.work.read_text())
        self.assertEqual("GENERAL v1", (workspace.root / "run" / "best_surface.md").read_text())
        self.assertEqual("merge recommended", summary["verdict"])

    def test_accuracy_gain_inside_the_noise_is_not_recommended(self) -> None:
        workspace, climb, versions = finishing_climb(
            self, "accuracy", ["v0", "GENERAL v1"], [(0.5, 100), (0.9, 100)])
        climb.noise = Noise(0.05, 1.5, 1.0)
        self.assertEqual("do not merge (within noise)", climb._finish(versions, "completed")["verdict"])

    def test_cost_at_parity_picks_the_cheapest_version_holding_parity(self) -> None:
        texts = ["base " + PADDING, "short", "tiny"]
        workspace, climb, versions = finishing_climb(
            self, "cost-at-parity", texts, [(0.50, 1000.0), (0.46, 400.0), (0.30, 100.0)])
        self.assertEqual(1, climb._select_best(versions).round)
        summary = climb._finish(versions, "completed")
        self.assertEqual("merge recommended", summary["verdict"])
        self.assertEqual("short", (workspace.root / "run" / "best_surface.md").read_text())
        accuracy = finishing_climb(self, "accuracy", texts, [(0.50, 1000.0), (0.46, 400.0), (0.30, 100.0)])
        self.assertEqual(0, accuracy[1]._select_best(accuracy[2]).round)

    def test_confirmation_reruns_both_versions_on_test_and_is_recorded(self) -> None:
        workspace, climb, versions = finishing_climb(
            self, "accuracy", ["v0", "GENERAL v1"], [(0.5, 100), (0.9, 100)])
        backend = climb.backend
        summary = climb._finish(versions, "completed")
        test_count = len(climb.test_cases)
        self.assertEqual(2 * test_count * climb.cfg.reps, len(backend.calls))
        confirmation = summary["confirmation"]
        self.assertEqual((0.0, 1.0), (confirmation["test_baseline"], confirmation["test_best"]))
        report = (workspace.root / "run" / "report.md").read_text()
        self.assertIn("Confirmatory rerun", report)
        self.assertIn("original 0.0%, best 100.0%", report)

    def test_the_rerun_gain_must_clear_min_gain_as_well_as_the_noise(self) -> None:
        for min_gain, verdict in ((0.3, "do not merge (within noise)"), (0.2, "merge recommended")):
            workspace = Workspace(self)
            one = sorted(workspace.split["test"])[0]
            climb = workspace.climb(FakeBackend(model_script()), FakeBackend(proposer_script([])),
                                    min_gain=min_gain)
            climb.noise = NOISE
            climb.work.parent.mkdir(parents=True)
            versions = [Version(0, "v0", card(0.0, 100, workspace)),
                        Version(1, f"v1 ONLY-{one}", card(0.9, 100, workspace))]
            climb.baseline = versions[0].card
            summary = climb._finish(versions, "completed")
            self.assertAlmostEqual(0.25, summary["confirmation"]["test_gain"])  # 1 of 4 test cases
            self.assertEqual(verdict, summary["verdict"], min_gain)

    def test_a_gain_the_rerun_does_not_reproduce_is_not_recommended(self) -> None:
        workspace, climb, versions = finishing_climb(
            self, "accuracy", ["v0", "v1 with no real effect"], [(0.5, 100), (0.9, 100)])
        summary = climb._finish(versions, "completed")
        self.assertEqual("do not merge (within noise)", summary["verdict"])
        self.assertEqual(0.0, summary["confirmation"]["test_gain"])


class PatchScreeningTests(unittest.TestCase):
    def test_a_plus_plus_plus_line_inside_a_hunk_is_screened(self) -> None:
        case = make_cases(1)[0]
        copied = "++" + case.prompt[5:70]
        diff = f"--- a/s\n+++ b/s\n@@ -1,2 +1,3 @@\n # Surface\n+{copied}\n line one\n"
        self.assertIn(case.prompt[5:70], added_text(diff))
        self.assertIsNotNone(find_injection(diff, [case.prompt]))
        header_only = "--- a/s\n+++ b/s\n@@ -1,1 +1,1 @@\n # Surface\n"
        self.assertEqual("", added_text(header_only))


class TrivialAnswererTests(unittest.TestCase):
    def lenient_cases(self) -> list[Case]:
        base = make_cases(1)[0]
        grader = {"type": "claims", "claims": [
            {"id": "no-bad-word", "field": "answer", "must_not_match": "forbidden"}]}
        return [Case(**{**base.__dict__, "id": "lenient-case", "grader": grader})]

    def test_a_lenient_grader_trips_the_diagnostic_and_the_baseline_warning(self) -> None:
        cases = self.lenient_cases()
        self.assertGreater(trivial_answerer_scores(cases)["max"], TRIVIAL_LIMIT)
        workspace = Workspace(self)
        results = run_baseline(workspace.spec, cases, FakeBackend(model_script()), ("haiku",), 1,
                               workspace.root / "b", run_id="b")
        self.assertTrue(any("trivial answerer" in w for w in results["warnings"]))
        self.assertGreater(results["diagnostics"]["trivial_answerers"]["max"], TRIVIAL_LIMIT)

    def test_a_demanding_grader_keeps_every_trivial_answerer_low(self) -> None:
        scores = trivial_answerer_scores(make_cases(10))
        self.assertLessEqual(scores["max"], TRIVIAL_LIMIT)
        fillers = ("echo", "soup", "compact_soup", "case_soup", "capped_soup", "keyword_run")
        self.assertEqual({"constant_false", "constant_true", "oracle_booleans", "empty"}
                         | {f"{filler}_{mode}" for filler in fillers for mode in ("false", "true", "oracle")},
                         set(scores) - {"max", "limit"})

    def test_repo_traps_graders_cannot_be_gamed_by_trivial_answerers(self) -> None:
        cases = load_cases(load_eval("repo_traps"))
        scores = trivial_answerer_scores(cases)
        self.assertLessEqual(scores["max"], TRIVIAL_LIMIT, scores)

    def test_repo_traps_expected_booleans_are_balanced(self) -> None:
        expected = [c["equals"] for case in load_cases(load_eval("repo_traps"))
                    for c in case.grader["claims"] if isinstance(c.get("equals"), bool)]
        share = sum(expected) / len(expected)
        self.assertTrue(0.4 <= share <= 0.6, share)


class ApprovalProvenanceTests(unittest.TestCase):
    CASES = ["c1", "c2"]

    def results(self, **changes) -> dict:
        return healthy_results(**{"case_ids": tuple(self.CASES), **changes})

    def test_approvals_refuse_without_a_tty(self) -> None:
        class Pipe:
            def isatty(self) -> bool: return False

        class Terminal:
            def isatty(self) -> bool: return True
        with self.assertRaisesRegex(approvals.ApprovalError, "TTY"):
            approvals.require_tty(Pipe())
        approvals.require_tty(Terminal())

    def test_cli_approvals_refuse_when_stdin_is_not_a_terminal(self) -> None:
        for command in (["approve-inputs", "repo_traps"],
                        ["approve-grader", "repo_traps", "--run", "x"]):
            done = subprocess.run([sys.executable, str(ROOT / "tools/agent_evals/cli.py"), *command],
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False)
            self.assertEqual(1, done.returncode, command)
            self.assertIn("interactive terminal", done.stderr)

    def test_the_backing_run_must_be_current_complete_healthy_and_strict(self) -> None:
        approvals.check_run_eligible(self.results(), "h1", "s1", self.CASES)
        ambient = {"backend": "claude-cli", "isolation": "ambient", "allow_ambient": True}
        allowed_but_isolated = {"backend": "claude-cli", "isolation": "safe-mode", "allow_ambient": True}
        bad = {
            "stale cases": (self.results(cases_sha256="old"), "stale cases_sha256"),
            "stale surface": (self.results(surface_sha256="old"), "stale surface_sha256"),
            "ambient run": (self.results(backend=ambient), "allow-ambient-context"),
            "ambient flag": (self.results(backend=allowed_but_isolated), "allow-ambient-context"),
            "no backend": (self.results(backend=None), "no backend"),
            "failed status": (self.results(status="failed"), "status"),
            "smoke run": (self.results(case_ids=["c1"]), "every case"),
            "infra": (self.results(diagnostics={**self.results()["diagnostics"],
                                                 "infra": {"rate": 0.5}}), "infrastructure"),
            "lenient grader": (self.results(diagnostics={**self.results()["diagnostics"],
                                                          "trivial_answerers": {"max": 0.6, "limit": 0.25}}),
                               "trivial answerer"),
        }
        for label, (results, needle) in bad.items():
            with self.subTest(label), self.assertRaisesRegex(approvals.ApprovalError, needle):
                approvals.check_run_eligible(results, "h1", "s1", self.CASES)

    def directory(self) -> Path:
        directory = Path(tempfile.mkdtemp(prefix="agent-evals-approvals-"))
        self.addCleanup(lambda: __import__("shutil").rmtree(directory, ignore_errors=True))
        return directory

    def test_grader_approval_is_withheld_for_an_ineligible_or_missing_run(self) -> None:
        directory = self.directory()
        ids = [f"transcripts/haiku/c{i}__r1.json" for i in range(6)]
        sample = approvals.sample_transcript_ids(ids, "run")
        for results, needle in ((self.results(status="failed"), "status"), (None, "no baseline results")):
            with self.subTest(needle), self.assertRaisesRegex(approvals.ApprovalError, needle):
                approvals.approve_grader(directory, "h1", "s1", ids, "run", sample, results, self.CASES)
        self.assertFalse((directory / "approvals.json").exists())

    def test_headroom_is_checked_for_the_model_being_climbed_only(self) -> None:
        directory = self.directory()
        ids = [f"transcripts/haiku/c{i}__r1.json" for i in range(6)]
        flagged = self.results(models={"haiku": {}, "opus": {}},
                               diagnostics={**self.results()["diagnostics"], "headroom_flagged": ["opus"]})
        approvals.approve_inputs(directory, "h1")
        approvals.approve_grader(directory, "h1", "s1", ids, "run",
                                 approvals.sample_transcript_ids(ids, "run"), flagged, self.CASES)
        approvals.require_approvals(directory, "h1", "s1", "haiku")  # opus's ceiling does not block haiku
        with self.assertRaisesRegex(approvals.ApprovalError, "no headroom for opus"):
            approvals.require_approvals(directory, "h1", "s1", "opus")
        approvals.require_approvals(directory, "h1", "s1", "opus", allow_no_headroom=True)
        with self.assertRaisesRegex(approvals.ApprovalError, "did not run 'sonnet'"):
            approvals.require_approvals(directory, "h1", "s1", "sonnet", allow_no_headroom=True)
        record = json.loads((directory / "approvals.json").read_text())["grader"]
        self.assertEqual((["haiku", "opus"], ["opus"]), (record["models"], record["headroom_flagged"]))

    def test_the_grader_approval_is_bound_to_the_surface(self) -> None:
        directory = self.directory()
        ids = [f"transcripts/haiku/c{i}__r1.json" for i in range(6)]
        approvals.approve_inputs(directory, "h1")
        record = approvals.approve_grader(directory, "h1", "s1", ids, "run",
                                          approvals.sample_transcript_ids(ids, "run"), self.results(),
                                          self.CASES)
        self.assertEqual("s1", record["surface_sha256"])
        approvals.require_approvals(directory, "h1", "s1", "sonnet")
        with self.assertRaisesRegex(approvals.ApprovalError, "surface changed"):
            approvals.require_approvals(directory, "h1", "s2", "sonnet")

    def test_hillclimb_and_the_backend_record_refuse_ambient_context(self) -> None:
        done = subprocess.run([sys.executable, str(ROOT / "tools/agent_evals/cli.py"), "hillclimb",
                               "repo_traps", "--allow-ambient-context"],
                              capture_output=True, text=True, check=False)
        self.assertEqual(1, done.returncode)
        self.assertIn("refuses --allow-ambient-context", done.stderr)
        self.assertNotIn("Traceback", done.stderr)

        def run(command, **kwargs):
            return subprocess.CompletedProcess(command, 0, "--safe-mode --setting-sources --tools "
                                               "--strict-mcp-config --system-prompt "
                                               "--disable-slash-commands --no-session-persistence", "")
        self.assertTrue(ClaudeCliBackend(allow_ambient=True, runner=run).describe()["allow_ambient"])
        self.assertFalse(ClaudeCliBackend(runner=run).describe()["allow_ambient"])

    def test_approve_grader_reports_a_missing_results_file_without_a_traceback(self) -> None:
        directory = self.directory()
        evidence = directory / "council.md"
        evidence.write_text("# report\n", encoding="utf-8")
        spec = SimpleNamespace(directory=directory, build_dir=directory / "build", cases_sha256="h1",
                               surface_sha256="s1")
        stderr = io.StringIO()
        with mock.patch.object(cli, "_load", return_value=(spec, [])), contextlib.redirect_stderr(stderr):
            code = cli.main(["approve-grader", "synthetic", "--run", "never-ran",
                             "--delegated", "test", "--evidence", str(evidence)])
        self.assertEqual(1, code)
        self.assertIn("results.json", stderr.getvalue())
        self.assertIn("run `baseline", stderr.getvalue())
        self.assertFalse((directory / "approvals.json").exists())


class IsolationCanaryTests(unittest.TestCase):
    def test_canaries_are_planted_in_the_workdir_and_a_throwaway_home_only(self) -> None:
        seen: dict = {}

        def run(command, **kwargs):
            if command[1:] == ["--help"]:
                return subprocess.CompletedProcess(command, 0, "--safe-mode --setting-sources --tools "
                    "--strict-mcp-config --system-prompt --disable-slash-commands "
                    "--no-session-persistence", "")
            seen["cwd_files"] = sorted(p.name for p in Path(kwargs["cwd"]).iterdir())
            seen["home"] = kwargs["env"]["HOME"]
            seen["home_canary"] = (Path(seen["home"]) / ".claude/CLAUDE.md").exists()
            return subprocess.CompletedProcess(command, 0, json.dumps({"result": "OK"}), "")
        backend = ClaudeCliBackend(runner=run, workdir_files={"CLAUDE.md": "canary"},
                                   home_files={".claude/CLAUDE.md": "canary"})
        self.assertEqual("OK", backend.complete("s", "p", "haiku", 5).text)
        self.assertIn("CLAUDE.md", seen["cwd_files"])
        self.assertTrue(seen["home_canary"])
        self.assertNotEqual(os.path.expanduser("~"), seen["home"])


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Offline tests for the agent eval and hill-climb harness. No test calls a model."""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import tempfile
import unittest
from dataclasses import asdict
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from agent_evals import approvals, split as splitting  # noqa: E402
from agent_evals.backends import (AnthropicApiBackend, ClaudeCliBackend, FakeBackend,  # noqa: E402
                                  IsolationUnavailable, parse_cli_output)
from agent_evals.baseline import run_baseline  # noqa: E402
from agent_evals.decision import Deltas, Noise, decide  # noqa: E402
from agent_evals.diagnostics import grader_consistency  # noqa: E402
from agent_evals.evalspec import EvalSpec, load_cases, load_eval, validate_cases  # noqa: E402
from agent_evals.graders import grade_claims, parse_json_answer  # noqa: E402
from agent_evals.hillclimb import Climb, HillclimbConfig  # noqa: E402
from agent_evals.models import Case, Completion, EvalError  # noqa: E402
from agent_evals.patching import PatchError, apply_unified_diff, find_injection  # noqa: E402
from agent_evals.proposer import (LeakError, assert_no_test_leak,  # noqa: E402
                                  build_proposer_prompt)
from agent_evals.report import review_html  # noqa: E402
from agent_evals.runner import InfraFailure, check_infra, infra_summary, run_set  # noqa: E402
from agent_evals.stats import noise_floor  # noqa: E402

SURFACE = "# Surface\nline one\nline two\n"


def make_cases(count: int = 10) -> list[Case]:
    cases = []
    for number in range(count):
        cid = f"synthetic-case-{number:02d}"
        digest = hashlib.sha256(cid.encode()).hexdigest()
        cases.append(Case(
            id=cid, source="CLAUDE.md", why_hard="synthetic case for the harness tests",
            prompt=f"Situation {cid}: token {digest[:24]} and {digest[24:48]} describe it.",
            reference=f"Reference for {cid}: {digest[48:]} is the intended answer.",
            grader={"type": "claims",
                    "claims": [{"id": "says-good", "field": "answer", "equals": "good"}]},
            answer_format='Reply with JSON {"answer": "..."}.'))
    return cases


def model_script(markers: tuple[str, ...] = ("GENERAL",)):
    """Answers well when the surface carries a marker or a per-case ONLY token."""
    def script(system: str, prompt: str, model: str) -> str:
        case_id = re.search(r"synthetic-case-\d+", prompt).group(0)
        good = any(marker in system for marker in markers) or f"ONLY-{case_id}" in system
        return json.dumps({"answer": "good" if good else "bad", "note": case_id})
    return script


def diff_adding(line: str, after: str = "line one") -> str:
    return f"--- a/s\n+++ b/s\n@@ -1,3 +1,4 @@\n # Surface\n {after}\n+{line}\n line two\n"


def diff_removing(line: str) -> str:
    return f"--- a/s\n+++ b/s\n@@ -1,4 +1,3 @@\n # Surface\n-{line}\n line two\n"


def proposal(patch: str, cause: str = "a missing general rule") -> str:
    return json.dumps({"root_cause": cause, "patch": patch, "expected_effect": "more correct"})


def proposer_script(patches: list[str]):
    queue = list(patches)

    def script(system: str, prompt: str, model: str) -> str:
        if "stalled hill-climbing run" in system:
            return "Reflection: the cases are fine."
        return proposal(queue.pop(0)) if queue else proposal(diff_adding("Neutral note."))
    return script


class Workspace:
    """A temporary eval: surface file, cases.jsonl and run directory."""

    def __init__(self, testcase: unittest.TestCase, surface: str = SURFACE, count: int = 10):
        self.root = Path(tempfile.mkdtemp(prefix="agent-evals-test-"))
        testcase.addCleanup(lambda: __import__("shutil").rmtree(self.root, ignore_errors=True))
        self.surface_path = self.root / "surface.md"
        self.surface_path.write_text(surface, encoding="utf-8")
        self.cases = make_cases(count)
        (self.root / "cases.jsonl").write_text(
            "".join(json.dumps(asdict(c)) + "\n" for c in self.cases), encoding="utf-8")
        self.spec = EvalSpec("synthetic", self.root, self.surface_path, "claims",
                             ("haiku", "sonnet", "opus"), "sonnet", "haiku")
        self.split = splitting.make_split([c.id for c in self.cases])
        self.split["cases_sha256"] = self.spec.cases_sha256

    def climb(self, model_backend: FakeBackend, proposer_backend: FakeBackend,
              run_name: str = "run", **config: object) -> Climb:
        defaults = dict(model="haiku", reps=3, rounds=6, stall=3, min_gain=0.05)
        defaults.update(config)
        return Climb(self.spec, self.cases, self.split, model_backend, proposer_backend,
                     HillclimbConfig(**defaults), self.root / run_name)


class SplitTests(unittest.TestCase):
    def test_split_is_deterministic_disjoint_and_sixty_forty(self) -> None:
        ids = [c.id for c in make_cases(30)]
        first = splitting.make_split(ids)
        self.assertEqual(first, splitting.make_split(list(reversed(ids))))
        self.assertFalse(set(first["train"]) & set(first["test"]))
        self.assertEqual(set(ids), set(first["train"]) | set(first["test"]))
        self.assertEqual((18, 12), (len(first["train"]), len(first["test"])))
        self.assertNotEqual(first, splitting.make_split(ids, seed="another-seed"))

    def test_persisted_split_is_refused_when_stale_or_missing(self) -> None:
        workspace = Workspace(self)
        path = workspace.root / "split.json"
        with self.assertRaises(EvalError):
            splitting.load_split(path, [c.id for c in workspace.cases], "abc")
        splitting.write_split(path, [c.id for c in workspace.cases], "hash-one")
        loaded = splitting.load_split(path, [c.id for c in workspace.cases], "hash-one")
        self.assertEqual(len(workspace.cases), len(loaded["train"]) + len(loaded["test"]))
        with self.assertRaises(EvalError):
            splitting.load_split(path, [c.id for c in workspace.cases], "hash-two")


class ProposerPromptTests(unittest.TestCase):
    def test_prompt_built_from_train_contains_no_test_data(self) -> None:
        workspace = Workspace(self)
        train = [c for c in workspace.cases if c.id in workspace.split["train"]]
        test = [c for c in workspace.cases if c.id in workspace.split["test"]]
        result = run_set(FakeBackend(model_script()), train, "haiku", SURFACE, 1)
        prompt = build_proposer_prompt(SURFACE, train, result.transcripts, "accuracy")
        assert_no_test_leak(prompt, SURFACE, test)
        self.assertIn(train[0].id, prompt)

    def test_guard_rejects_a_prompt_with_a_test_id_input_or_reference(self) -> None:
        workspace = Workspace(self)
        test = [c for c in workspace.cases if c.id in workspace.split["test"]]
        for leaked in (test[0].id, test[0].prompt, test[0].reference):
            with self.subTest(leaked=leaked[:30]), self.assertRaises(LeakError):
                assert_no_test_leak(f"notes\n{leaked}\nend", SURFACE, test)
        # An id that merely extends a train id is not a leak.
        assert_no_test_leak(f"{test[0].id}-extra and synthetic-case-9", SURFACE, test)

    def test_every_prompt_the_proposer_saw_is_free_of_test_data(self) -> None:
        workspace = Workspace(self)
        proposer = FakeBackend(proposer_script([diff_adding("GENERAL guidance.")]))
        climb = workspace.climb(FakeBackend(model_script()), proposer)
        climb.run()
        test = [c for c in workspace.cases if c.id in workspace.split["test"]]
        self.assertGreaterEqual(len(proposer.calls), 2)
        for call in proposer.calls:
            assert_no_test_leak(call["prompt"], SURFACE, test)
            self.assertNotIn("/test/", call["prompt"])

    def test_test_transcripts_are_written_apart_from_train_transcripts(self) -> None:
        workspace = Workspace(self)
        proposer = FakeBackend(proposer_script([diff_adding("GENERAL x.")]))
        workspace.climb(FakeBackend(model_script()), proposer).run()
        run = workspace.root / "run"
        test_ids = set(workspace.split["test"])
        for path in (run / "rounds" / "01" / "train").glob("*.json"):
            self.assertNotIn(json.loads(path.read_text())["case_id"], test_ids)
        self.assertTrue(list((run / "rounds" / "01" / "test").glob("*.json")))


class PatchingTests(unittest.TestCase):
    def test_diff_applies_by_context_even_with_wrong_line_numbers(self) -> None:
        patched = apply_unified_diff(SURFACE, diff_adding("New rule.").replace("-1,3", "-40,3"))
        self.assertEqual("# Surface\nline one\nNew rule.\nline two\n", patched)

    def test_diff_that_does_not_match_or_changes_nothing_is_an_error(self) -> None:
        with self.assertRaises(PatchError):
            apply_unified_diff(SURFACE, diff_adding("x", after="absent line"))
        with self.assertRaises(PatchError):
            apply_unified_diff(SURFACE, "just some prose")

    def test_injection_needs_a_forty_character_verbatim_span(self) -> None:
        case = make_cases(1)[0]
        copied = case.prompt[10:60]
        self.assertIsNotNone(find_injection(diff_adding(f"Rule: {copied}"), [case.prompt]))
        self.assertIsNotNone(find_injection(
            diff_adding(f"  {case.reference[:45].upper()}  "), [case.reference]))
        self.assertIsNone(find_injection(diff_adding(case.prompt[10:40]), [case.prompt]))

    def test_a_patch_copying_case_text_is_rejected_and_counts_as_a_round(self) -> None:
        workspace = Workspace(self)
        test_case = next(c for c in workspace.cases if c.id in workspace.split["test"])
        patches = [diff_adding(f"Rule: {test_case.reference[:60]}")] * 3
        climb = workspace.climb(FakeBackend(model_script(())), FakeBackend(proposer_script(patches)))
        summary = climb.run()
        self.assertEqual(["rejected-injection"] * 3, [r["reason"] for r in summary["rounds"]])
        self.assertEqual("stalled", summary["status"])
        self.assertEqual(SURFACE, (workspace.root / "run" / "best_surface.md").read_text())


class NoiseTests(unittest.TestCase):
    def test_identical_repetitions_have_zero_noise(self) -> None:
        table = {f"c{i}": [i % 2, i % 2, i % 2] for i in range(12)}
        self.assertEqual(0.0, noise_floor(table))

    def test_noise_matches_the_analytic_half_width_on_a_known_series(self) -> None:
        # Per-case differences alternate +0.2 and -0.2: sd 0.2025, n 40, so the
        # 95% CI half-width of the mean is about 1.96 * 0.2025 / sqrt(40) = 0.0628.
        table = {f"c{i}": ([0.6, 0.4] if i % 2 else [0.4, 0.6]) for i in range(40)}
        self.assertAlmostEqual(0.0628, noise_floor(table), delta=0.008)

    def test_one_repetition_cannot_give_a_noise_floor(self) -> None:
        with self.assertRaises(ValueError):
            noise_floor({"c0": [1.0], "c1": [0.0]})


class DecisionTableTests(unittest.TestCase):
    NOISE = Noise(train=0.05, test=0.05, cost=100.0)

    def check(self, goal: str, deltas: tuple[float, float, float], keep: bool, reason: str) -> None:
        decision = decide(goal, Deltas(*deltas), self.NOISE)
        self.assertEqual((keep, reason), (decision.keep, decision.reason), (goal, deltas))

    def test_accuracy_goal(self) -> None:
        self.check("accuracy", (0.20, 0.20, 0), True, "improved")
        self.check("accuracy", (0.20, 0.05, 0), False, "overfit")       # test gain not above noise
        self.check("accuracy", (0.20, -0.20, 0), False, "overfit")      # train up, test not up
        self.check("accuracy", (0.02, -0.20, 0), False, "regress")
        self.check("accuracy", (-0.20, 0.30, 0), False, "regress")
        self.check("accuracy", (0.02, 0.03, 0), False, "no-gain")
        self.check("accuracy", (0.0, 0.0, 0), False, "no-gain")

    def test_cost_at_parity_goal(self) -> None:
        self.check("cost-at-parity", (0.0, 0.0, -500.0), True, "cheaper")
        self.check("cost-at-parity", (0.04, -0.04, -500.0), True, "cheaper")
        self.check("cost-at-parity", (0.0, -0.20, -500.0), False, "regress")
        self.check("cost-at-parity", (-0.20, 0.0, -500.0), False, "regress")
        self.check("cost-at-parity", (0.0, 0.0, -50.0), False, "no-gain")
        self.check("cost-at-parity", (0.0, 0.0, 400.0), False, "no-gain")

    def test_unknown_goal_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            decide("speed", Deltas(0, 0, 0), self.NOISE)


class HillclimbLoopTests(unittest.TestCase):
    def run_climb(self, surface: str, patches: list[str], model=None, **config: object):
        workspace = Workspace(self, surface)
        climb = workspace.climb(FakeBackend(model or model_script()),
                                FakeBackend(proposer_script(patches)), **config)
        return workspace, climb.run()

    def test_improvement_is_kept_and_the_repo_surface_is_never_edited(self) -> None:
        workspace, summary = self.run_climb(SURFACE, [diff_adding("GENERAL guidance.")])
        self.assertTrue(summary["rounds"][0]["kept"])
        self.assertEqual("improved", summary["rounds"][0]["reason"])
        self.assertEqual("merge recommended", summary["verdict"])
        run = workspace.root / "run"
        self.assertIn("GENERAL guidance.", (run / "best_surface.md").read_text())
        self.assertIn("+GENERAL guidance.", (run / "best.diff").read_text())
        self.assertEqual(SURFACE, workspace.surface_path.read_text())
        report = (run / "report.md").read_text()
        for needle in ("baseline", "best", "95% CI", "improved", "merge recommended"):
            self.assertIn(needle, report)

    def test_overfit_and_no_gain_are_reverted_with_their_reason(self) -> None:
        workspace = Workspace(self)
        train_only = " ".join(f"ONLY-{cid}" for cid in workspace.split["train"])
        _, overfit = self.run_climb(SURFACE, [diff_adding(train_only)])
        self.assertEqual("overfit", overfit["rounds"][0]["reason"])
        self.assertEqual("do not merge (within noise)", overfit["verdict"])
        _, neutral = self.run_climb(SURFACE, [diff_adding("A neutral remark.")])
        self.assertEqual("no-gain", neutral["rounds"][0]["reason"])

    def test_regression_is_reported_as_regress(self) -> None:
        surface = "# Surface\nGENERAL guidance.\nline two\n"
        _, summary = self.run_climb(surface, [diff_removing("GENERAL guidance.")])
        self.assertEqual("regress", summary["rounds"][0]["reason"])
        self.assertFalse(summary["rounds"][0]["kept"])
        self.assertEqual("do not merge (within noise)", summary["verdict"])

    def test_stall_runs_reflection_and_stops(self) -> None:
        workspace, summary = self.run_climb(SURFACE, [], rounds=8, stall=3)
        self.assertEqual("stalled", summary["status"])
        self.assertEqual(3, len(summary["rounds"]))
        reflection = workspace.root / "run" / "reflection.md"
        self.assertIn("Reflection", reflection.read_text())

    def test_unmeasurable_noise_runs_reflection_before_any_round(self) -> None:
        counter = {"n": 0}

        def flaky(system: str, prompt: str, model: str) -> str:
            counter["n"] += 1
            return json.dumps({"answer": "good" if counter["n"] % 7 < 3 else "bad"})
        workspace, summary = self.run_climb(SURFACE, [diff_adding("GENERAL x.")], model=flaky)
        self.assertEqual("unmeasurable", summary["status"])
        self.assertEqual([], summary["rounds"])
        self.assertTrue((workspace.root / "run" / "reflection.md").exists())
        self.assertEqual("do not merge (within noise)", summary["verdict"])

    def test_cost_at_parity_keeps_a_cheaper_surface(self) -> None:
        bulky = "# Surface\nGENERAL guidance.\n" + ("padding " * 400).strip() + "\nline two\n"
        patch = "--- a/s\n+++ b/s\n@@ -1,4 +1,3 @@\n # Surface\n GENERAL guidance.\n-" \
                + ("padding " * 400).strip() + "\n line two\n"
        _, summary = self.run_climb(bulky, [patch], goal="cost-at-parity")
        self.assertEqual((True, "cheaper"), (summary["rounds"][0]["kept"], summary["rounds"][0]["reason"]))
        self.assertEqual("merge recommended", summary["verdict"])

    def test_infrastructure_failure_inside_a_round_stops_the_climb(self) -> None:
        workspace = Workspace(self)
        healthy = model_script()

        def breaks_after_noise_stage(system: str, prompt: str, model: str) -> Completion:
            if "GENERAL" in system:
                return Completion(error="HTTP 529 overloaded")
            return Completion(text=healthy(system, prompt, model))
        climb = workspace.climb(FakeBackend(breaks_after_noise_stage),
                                FakeBackend(proposer_script([diff_adding("GENERAL x.")])))
        summary = climb.run()
        self.assertEqual("infrastructure-failure", summary["status"])
        self.assertIn("run invalid", summary["verdict"])

    def test_infrastructure_failure_in_the_noise_stage_raises(self) -> None:
        workspace = Workspace(self)
        climb = workspace.climb(FakeBackend(lambda s, p, m: Completion(error="boom")),
                                FakeBackend(proposer_script([])))
        with self.assertRaises(InfraFailure):
            climb.run()


class BaselineTests(unittest.TestCase):
    def baseline(self, workspace: Workspace, script, models=("haiku", "sonnet", "opus"), reps=2):
        return run_baseline(workspace.spec, workspace.cases, FakeBackend(script), models, reps,
                            workspace.root / "base", run_id="base")

    def test_transcripts_results_json_and_html_are_written(self) -> None:
        workspace = Workspace(self)
        results = self.baseline(workspace, model_script(), models=("haiku",))
        base = workspace.root / "base"
        transcripts = sorted((base / "transcripts" / "haiku").glob("*.json"))
        self.assertEqual(len(workspace.cases) * 2, len(transcripts))
        item = json.loads(transcripts[0].read_text())
        for key in ("prompt", "surface_sha256", "model", "output", "grade", "error",
                    "elapsed_s", "usage", "cost_tokens", "backend", "rep", "case_id"):
            self.assertIn(key, item)
        self.assertEqual(hashlib.sha256(SURFACE.encode()).hexdigest(), item["surface_sha256"])
        self.assertIn("verdicts", item["grade"])
        saved = json.loads((base / "results.json").read_text())
        self.assertEqual(results["models"]["haiku"]["summary"], saved["models"]["haiku"]["summary"])
        page = (base / "results.html").read_text()
        self.assertIn(f"transcripts/haiku/{transcripts[0].name}", page)
        self.assertEqual(0.0, saved["models"]["haiku"]["summary"]["mean"])

    def test_headroom_warning_above_ninety_five_percent(self) -> None:
        workspace = Workspace(self)
        results = self.baseline(workspace, model_script(("line one",)), models=("haiku",))
        self.assertTrue(any("no headroom" in w for w in results["warnings"]))
        self.assertFalse(any("no headroom" in w for w in
                             self.baseline(Workspace(self), model_script(()), models=("haiku",))["warnings"]))

    def test_weaker_model_beating_a_stronger_one_is_flagged(self) -> None:
        def inverted(system: str, prompt: str, model: str) -> str:
            answer = "good" if model == "haiku" else "bad"
            return json.dumps({"answer": answer})
        results = self.baseline(Workspace(self), inverted, models=("haiku", "opus"))
        self.assertTrue(any("haiku beats the stronger opus" in w for w in results["warnings"]))

    def test_infrastructure_errors_above_the_threshold_fail_the_run(self) -> None:
        workspace = Workspace(self)
        state = {"n": 0}

        def failing_every_fifth(system: str, prompt: str, model: str) -> Completion:
            state["n"] += 1
            return Completion(error="HTTP 500") if state["n"] % 5 == 0 else Completion(text='{"answer": "good"}')
        results = self.baseline(workspace, failing_every_fifth, models=("haiku",))
        self.assertEqual("failed", results["status"])
        self.assertGreater(results["diagnostics"]["infra"]["rate"], 0.05)
        self.assertEqual("ok", self.baseline(Workspace(self), model_script(), models=("haiku",))["status"])

    def test_infra_summary_counts_errors_timeouts_and_truncation(self) -> None:
        def item(**flags) -> dict:
            return {"error": None, "timed_out": False, "truncated": False, **flags}
        summary = infra_summary([item(), item(error="x"), item(timed_out=True, error="t"),
                                 item(truncated=True)])
        self.assertEqual((1, 1, 1, 3), (summary["errors"], summary["timeouts"],
                                        summary["truncated"], summary["failed"]))
        with self.assertRaises(InfraFailure):
            check_infra(summary, 0.05)
        check_infra(summary, 0.9)


class GraderTests(unittest.TestCase):
    def judge_case(self) -> Case:
        base = make_cases(1)[0]
        return Case(**{**asdict(base), "grader": {"type": "judge", "claims": [
            {"id": "mentions-fix", "question": "Does the answer propose a fix?"}]}})

    def test_programmatic_grades_are_identical_on_regrading(self) -> None:
        workspace = Workspace(self)
        result = run_set(FakeBackend(model_script()), workspace.cases, "haiku", SURFACE, 2)
        report = grader_consistency(workspace.cases, result.transcripts)
        self.assertTrue(report["programmatic_identical"])
        self.assertIsNone(report["judge_disagreement_rate"])

    def test_judge_disagreement_rate_is_reported(self) -> None:
        case = self.judge_case()
        flips = {"n": 0}

        def judge(system: str, prompt: str, model: str) -> str:
            flips["n"] += 1
            return json.dumps({"verdicts": {"mentions-fix": flips["n"] % 2 == 0}})
        transcripts = [{"case_id": case.id, "output": "Apply the fix."}]
        report = grader_consistency([case], transcripts, FakeBackend(judge))
        self.assertEqual(1.0, report["judge_disagreement_rate"])

    def test_judge_prompt_is_blind_to_condition(self) -> None:
        case = self.judge_case()
        seen = FakeBackend(lambda s, p, m: '{"verdicts": {"mentions-fix": true}}')
        run_set(FakeBackend(lambda s, p, m: "answer"), [case], "haiku", "BASELINE-SURFACE", 1,
                judge=seen, judge_model="haiku")
        text = seen.calls[0]["system"] + seen.calls[0]["prompt"]
        for label in ("baseline", "candidate", "BASELINE-SURFACE", "haiku", "opus"):
            self.assertNotIn(label.lower(), text.lower().replace("answerer", ""))

    def test_claim_grader_handles_fences_regexes_and_missing_fields(self) -> None:
        case = Case(**{**asdict(make_cases(1)[0]), "grader": {"type": "claims", "claims": [
            {"id": "a", "field": "gate", "must_match": "check_scripts"},
            {"id": "b", "field": "gate", "must_not_match": "check-only"},
            {"id": "c", "field": "safe", "equals": False},
            {"id": "d", "field": "absent", "must_match": "x"}]}})
        reply = 'Sure.\n```json\n{"gate": "tools/check_scripts.sh", "safe": "false"}\n```'
        self.assertEqual({"a": True, "b": True, "c": True, "d": False},
                         {v.claim_id: v.passed for v in grade_claims(case, reply).verdicts})
        self.assertEqual(0.0, grade_claims(case, "no json here").score)
        self.assertEqual({"x": 1}, parse_json_answer('noise {broken} {"x": 1}'))


class ApprovalTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp(prefix="agent-evals-approvals-"))
        self.addCleanup(lambda: __import__("shutil").rmtree(self.dir, ignore_errors=True))

    def test_hillclimb_refuses_without_both_approvals_or_with_a_stale_hash(self) -> None:
        with self.assertRaises(approvals.ApprovalError):
            approvals.require_approvals(self.dir, "h1")
        approvals.approve_inputs(self.dir, "h1")
        with self.assertRaisesRegex(approvals.ApprovalError, "grader"):
            approvals.require_approvals(self.dir, "h1")
        ids = [f"transcripts/haiku/c{i}__r1.json" for i in range(9)]
        sample = approvals.sample_transcript_ids(ids, "run-1")
        approvals.approve_grader(self.dir, "h1", ids, "run-1", sample)
        approvals.require_approvals(self.dir, "h1")
        with self.assertRaisesRegex(approvals.ApprovalError, "stale"):
            approvals.require_approvals(self.dir, "h2")

    def test_grader_approval_requires_the_sampled_transcripts_to_be_read(self) -> None:
        ids = [f"transcripts/haiku/c{i}__r1.json" for i in range(9)]
        sample = approvals.sample_transcript_ids(ids, "run-1")
        self.assertEqual(approvals.SAMPLE_SIZE, len(sample))
        with self.assertRaises(approvals.ApprovalError):
            approvals.approve_grader(self.dir, "h1", ids, "run-1", sample[:-1])
        with self.assertRaises(approvals.ApprovalError):
            approvals.approve_grader(self.dir, "h1", [], "run-1", [])
        record = approvals.approve_grader(self.dir, "h1", ids, "run-1", sample)
        self.assertEqual("h1", record["cases_sha256"])
        self.assertTrue(record["by"] and record["at"])

    def test_cli_hillclimb_refuses_the_real_eval_without_approvals(self) -> None:
        recorded = ROOT / "tools/agent_evals/evals/repo_traps/approvals.json"
        if recorded.exists() and {"inputs", "grader"} <= set(json.loads(recorded.read_text())):
            self.skipTest("the repo_traps eval has both approvals recorded")
        done = subprocess.run([sys.executable, str(ROOT / "tools/agent_evals/cli.py"),
                               "hillclimb", "repo_traps"], capture_output=True, text=True, check=False)
        self.assertEqual(1, done.returncode)
        self.assertIn("not approved", done.stderr)


class BackendTests(unittest.TestCase):
    HELP = "--safe-mode --setting-sources --tools --strict-mcp-config --system-prompt --disable-slash-commands --no-session-persistence"

    def fake_run(self, help_text: str, calls: list):
        def run(command, **kwargs):
            calls.append((command, kwargs))
            if command[1:] == ["--help"]:
                return subprocess.CompletedProcess(command, 0, help_text, "")
            payload = {"result": '{"answer": "good"}', "usage": {"input_tokens": 12, "output_tokens": 5},
                       "total_cost_usd": 0.001, "stop_reason": "end_turn"}
            return subprocess.CompletedProcess(command, 0, json.dumps(payload), "")
        return run

    def test_cli_backend_disables_every_ambient_source_in_an_empty_cwd(self) -> None:
        calls: list = []
        backend = ClaudeCliBackend(runner=self.fake_run(self.HELP, calls))
        completion = backend.complete("SURFACE TEXT", "the case", "haiku", 30)
        command, kwargs = calls[-1]
        for flag in ("-p", "--safe-mode", "--strict-mcp-config", "--disable-slash-commands",
                     "--no-session-persistence"):
            self.assertIn(flag, command)
        self.assertEqual("", command[command.index("--tools") + 1])
        self.assertEqual("", command[command.index("--setting-sources") + 1])
        self.assertEqual("SURFACE TEXT", command[command.index("--system-prompt") + 1])
        self.assertEqual("json", command[command.index("--output-format") + 1])
        self.assertEqual("haiku", command[command.index("--model") + 1])
        self.assertEqual("the case", kwargs["input"])
        self.assertNotEqual(str(ROOT), kwargs["cwd"])
        self.assertEqual({"input_tokens": 12, "output_tokens": 5, "cost_usd": 0.001}, completion.usage)
        self.assertEqual("safe-mode", backend.describe()["isolation"])

    def test_cli_backend_refuses_without_isolation_unless_ambient_is_allowed(self) -> None:
        calls: list = []
        with self.assertRaises(IsolationUnavailable):
            ClaudeCliBackend(runner=self.fake_run("--tools", calls)).complete("s", "p", "haiku", 5)
        ambient = ClaudeCliBackend(allow_ambient=True, runner=self.fake_run("--tools", calls))
        self.assertTrue(ambient.complete("s", "p", "haiku", 5).text)
        self.assertEqual("ambient", ambient.describe()["isolation"])
        self.assertNotIn("--safe-mode", calls[-1][0])

    def test_cli_output_parsing_covers_errors_and_truncation(self) -> None:
        self.assertEqual("boom", parse_cli_output(1, json.dumps({"is_error": True, "result": "boom"}), "").error)
        self.assertIn("unparseable", parse_cli_output(0, "not json", "").error)
        self.assertTrue(parse_cli_output(0, json.dumps({"result": "x", "stop_reason": "max_tokens"}), "").truncated)

    def test_cli_timeout_is_reported_not_raised(self) -> None:
        def run(command, **kwargs):
            if command[1:] == ["--help"]:
                return subprocess.CompletedProcess(command, 0, self.HELP, "")
            raise subprocess.TimeoutExpired(command, 1)
        completion = ClaudeCliBackend(runner=run).complete("s", "p", "haiku", 1)
        self.assertTrue(completion.timed_out)
        self.assertTrue(completion.infra_failed)

    def test_api_backend_resolves_the_newest_model_of_a_family_alias(self) -> None:
        listing = [SimpleNamespace(id=name, created_at=at) for name, at in (
            ("claude-haiku-old", 1), ("claude-haiku-new", 9), ("claude-opus-x", 5))]
        client = SimpleNamespace(models=SimpleNamespace(list=lambda limit: SimpleNamespace(data=listing)))
        self.assertEqual("claude-haiku-new", AnthropicApiBackend(client=client).resolve("haiku"))


class RepoTrapsEvalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.spec = load_eval("repo_traps")
        cls.cases = load_cases(cls.spec)

    def test_cases_validate_with_unique_ids_real_sources_and_reasons(self) -> None:
        self.assertEqual([], validate_cases(self.cases))
        self.assertEqual(len(self.cases), len({c.id for c in self.cases}))
        self.assertTrue(24 <= len(self.cases) <= 36, len(self.cases))
        for case in self.cases:
            self.assertTrue((ROOT / case.source).is_file(), case.source)
            self.assertGreater(len(case.why_hard.split()), 8, case.id)
            self.assertTrue(case.reference.strip(), case.id)

    def test_eval_definition_points_at_the_skill_and_aliases_only(self) -> None:
        self.assertEqual(ROOT / ".claude/skills/glassvow-godot/SKILL.md", self.spec.surface)
        self.assertTrue(self.spec.surface.is_file())
        self.assertEqual(("haiku", "sonnet", "opus"), self.spec.default_models)
        raw = (self.spec.directory / "eval.json").read_text()
        self.assertNotRegex(raw, r"claude-[a-z]+-\d")

    def test_an_empty_answer_never_passes_any_case(self) -> None:
        for case in self.cases:
            fields = {claim["field"]: "" for claim in case.grader["claims"]}
            self.assertFalse(grade_claims(case, json.dumps(fields)).passed, case.id)
            self.assertFalse(grade_claims(case, "{}").passed, case.id)

    def test_every_case_prompt_is_self_contained_and_asks_for_json(self) -> None:
        for case in self.cases:
            self.assertIn("JSON", case.answer_format, case.id)
            for claim in case.grader["claims"]:
                self.assertIn(f'"{claim["field"]}"', case.answer_format, f"{case.id}/{claim['id']}")

    def test_review_page_shows_source_and_why_hard_for_every_case(self) -> None:
        page = review_html("repo_traps", self.cases, self.spec.cases_sha256)
        self.assertTrue(all(c.id in page and c.source in page for c in self.cases))


if __name__ == "__main__":
    unittest.main()

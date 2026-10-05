#!/usr/bin/env python3
"""Tests for the repo_traps grader. From the first council: the decision gate, trivial answerers
and delegated approval. From the second: the hybrid grader, with programmatic claims for
decisions, commands, paths, numbers and code, and judge claims for free text. No model is called:
the judge here is a fake that credits every claim, or none."""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
import re
import subprocess
import sys
import tempfile
import unittest
from argparse import Namespace
from dataclasses import asdict
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_agent_evals import ROOT, fake_judge, healthy_results, make_cases  # noqa: E402

from agent_evals import approvals, cli  # noqa: E402
from agent_evals.diagnostics import (TRIVIAL_LIMIT, case_soup, compact_soup,  # noqa: E402
                                     keyword_run, keyword_soup, trivial_answerer_scores,
                                     trivial_answers)
from agent_evals.evalspec import load_cases, load_eval  # noqa: E402
from agent_evals.graders import (MAX_FIELD_CHARS, check_claim, claim_keywords, grade,  # noqa: E402
                                 is_decision_claim, is_judge_claim, judge_questions_sha256,
                                 parse_json_answer, programmatic_verdicts, validate_grader_spec)
from agent_evals.models import Case, EvalError, sha256_text  # noqa: E402

FILLERS = ("echo", "soup", "compact_soup", "case_soup", "keyword_run", "hedge", "padded", "injected")
ANSWERERS = {"empty", "constant_false", "constant_true", "oracle_booleans"} | {
    f"{filler}_{mode}" for filler in FILLERS for mode in ("false", "true", "oracle")}
EVAL_DIR = ROOT / "tools/agent_evals/evals/repo_traps"
ANSWERS_FILE = EVAL_DIR / "answers.jsonl"
# The judge questions, frozen before any evaluation set is scored (council-2026-10-05.md). A change
# to any question changes this hash: the calibration and the grader approval must then be redone.
JUDGE_QUESTIONS_SHA256 = "3d805fadb9d088f687fc2b5cd4ce7279739d6d8aa0dbfdfaec0ed55c98cfe719"
# The fields programmatic claims may read besides booleans: a command, code, a citation, a number
# and a one-phrase owner. Every other field is free text and is judged.
STRUCTURED_FIELDS = {"gate", "fixed_code", "missing_call", "citation", "min_target_pt", "owner"}


def real_case(case_id: str) -> Case:
    return next(c for c in load_cases(load_eval("repo_traps")) if c.id == case_id)


def score(case_id: str, credit: bool = True, **answer: object) -> float:
    return grade(real_case(case_id), json.dumps(answer), fake_judge(credit)).score


def passed(case_id: str, credit: bool = True, **answer: object) -> dict[str, bool]:
    result = grade(real_case(case_id), json.dumps(answer), fake_judge(credit))
    return {v.claim_id: v.passed for v in result.verdicts}


def answers() -> dict[str, dict]:
    """answers.jsonl by case id: the reference answer field by field, and two correct answers."""
    lines = ANSWERS_FILE.read_text(encoding="utf-8").splitlines()
    return {row["id"]: row for row in map(json.loads, filter(None, lines))}


def independent_answers() -> list[dict]:
    """answers_independent.jsonl: the blind writer's file, byte for byte under a header note."""
    header, body = (EVAL_DIR / "answers_independent.jsonl").read_text(encoding="utf-8").split("\n", 1)
    note = json.loads(header)
    assert note["sha256"] == hashlib.sha256(body.encode("utf-8")).hexdigest(), "an answer was edited"
    return [json.loads(line) for line in body.splitlines() if line.strip()]


class DecisionGateTests(unittest.TestCase):
    CASE = "script-error-is-not-renderer-noise"

    def test_a_wrong_decision_scores_zero_and_the_judge_is_never_asked(self) -> None:
        judge = fake_judge(True)
        result = grade(real_case(self.CASE), json.dumps(
            {"failure_is_real": False, "next_step": "Fix the null guard in _return_checks."}), judge)
        self.assertTrue(result.decision_failed)
        self.assertEqual((0.0, []), (result.score, judge.calls))
        self.assertTrue(result.to_json()["decision_failed"])

    def test_a_right_decision_with_reasoning_the_judge_rejects_keeps_partial_credit(self) -> None:
        result = grade(real_case(self.CASE), json.dumps(
            {"failure_is_real": True, "next_step": "Look at it."}), fake_judge(False))
        self.assertFalse(result.decision_failed)
        self.assertEqual(0.5, result.score)

    def test_a_missing_decision_field_also_closes_the_gate(self) -> None:
        self.assertEqual(0.0, score(self.CASE, next_step="Fix the guard."))

    def test_a_case_without_a_boolean_claim_is_never_gated(self) -> None:
        case = make_cases(1)[0]
        text_only = Case(**{**asdict(case), "grader": {"type": "claims", "claims": [
            {"id": "a", "field": "answer", "must_match": "yes"},
            {"id": "b", "field": "answer", "must_match": "no"}]}})
        result = grade(text_only, json.dumps({"answer": "yes"}))
        self.assertFalse(result.decision_failed)
        self.assertEqual(0.5, result.score)

    def test_a_single_key_nested_answer_is_unwrapped(self) -> None:
        self.assertEqual({"verdicts": {"a": True}}, parse_json_answer('{"verdicts": {"a": true}}'))
        nested = {"answer": {"failure_is_real": True, "next_step": "Fix the guard."}}
        self.assertEqual(1.0, grade(real_case(self.CASE), json.dumps(nested), fake_judge(True)).score)
        fenced = "```json\n" + json.dumps(nested) + "\n```"
        self.assertEqual(1.0, grade(real_case(self.CASE), fenced, fake_judge(True)).score)


class TrivialAnswererTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = load_cases(load_eval("repo_traps"))
        cls.scores = trivial_answerer_scores(cls.cases, fake_judge(False))  # the judge credits nothing

    def test_every_answerer_is_reported_and_programmatic_claims_give_none_of_them_anything(self) -> None:
        self.assertTrue(ANSWERERS <= set(self.scores), ANSWERERS - set(self.scores))
        for name in ANSWERERS:
            self.assertLessEqual(self.scores[name], TRIVIAL_LIMIT, name)
            self.assertLessEqual(self.scores[name], self.scores["oracle_booleans"] + 1e-9, name)
        self.assertEqual(0.0, self.scores["empty"])
        self.assertEqual(0, self.scores["judge_errors"])

    def test_oracle_booleans_get_the_right_flags_and_empty_text(self) -> None:
        case = real_case("typed-array-ternary")
        answer = trivial_answers(case, "soup")["oracle_booleans"]
        self.assertEqual({"safe_to_ship": False, "fixed_code": ""}, answer)

    def test_the_judge_probes_fill_only_the_fields_the_judge_reads(self) -> None:
        case = real_case("check-only-exit-zero")
        made = trivial_answers(case, "soup", "compact")
        self.assertEqual("", made["hedge_oracle"]["gate"])  # a command field: the probe leaves it empty
        self.assertTrue(made["hedge_oracle"]["reason"].startswith(case.reference))
        self.assertIn("opposite", made["hedge_oracle"]["reason"])
        self.assertLessEqual(len(made["padded_true"]["reason"]), MAX_FIELD_CHARS)
        self.assertGreater(len(made["padded_true"]["reason"]), len(case.reference))
        judge = fake_judge(True)
        injected = grade(case, json.dumps(made["injected_oracle"]), judge)
        self.assertEqual((0.0, []), (injected.score, judge.calls))  # refused before any judge call

    def test_the_full_soup_is_defeated_by_the_field_cap_before_the_judge(self) -> None:
        soup = keyword_soup(self.cases)
        self.assertGreater(len(soup), MAX_FIELD_CHARS)
        case = real_case("check-only-exit-zero")
        judge = fake_judge(True)
        result = grade(case, json.dumps({"parse_error_is_real": True, "gate": soup, "reason": soup}), judge)
        self.assertEqual({"verdict-true": True, "names-the-repo-gate": False, "explains-stderr": False},
                         {v.claim_id: v.passed for v in result.verdicts})
        self.assertTrue(all("characters" in v.detail for v in result.verdicts[1:]))
        self.assertEqual([], judge.calls)

    def lenient(self) -> list[Case]:
        base = make_cases(1)[0]
        grader = {"type": "claims", "claims": [{"id": "word", "field": "answer", "must_match": "gate"}]}
        return [Case(**{**asdict(base), "id": "lenient", "grader": grader, "reference": "the gate"})]

    def test_a_grader_a_keyword_soup_can_pass_trips_the_diagnostic(self) -> None:
        scores = trivial_answerer_scores(self.lenient())
        self.assertEqual(1.0, scores["soup_false"])
        self.assertGreater(scores["max"], TRIVIAL_LIMIT)
        self.assertGreater(scores["oracle_margin"], scores["oracle_margin_limit"])


class SoupTests(unittest.TestCase):
    """The soups fit under the field cap and carry each case's vocabulary."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = load_cases(load_eval("repo_traps"))

    def test_both_soups_fit_under_the_cap_and_carry_the_case_vocabulary(self) -> None:
        generic = compact_soup(self.cases)
        self.assertLessEqual(len(generic), MAX_FIELD_CHARS)
        self.assertGreater(len(generic), MAX_FIELD_CHARS - 50)  # it fills the cap
        self.assertIn("answer", generic.split(" ")[:5])  # "The answer states" leads every question
        for case in self.cases:
            soup = case_soup(case).split(" ")
            self.assertLessEqual(len(" ".join(soup)), MAX_FIELD_CHARS, case.id)
            vocabulary = {w.casefold() for w in re.findall(r"[A-Za-z_]\w{2,}", case.reference)}
            for claim in case.grader["claims"]:
                vocabulary.update(claim_keywords(claim.get("must_match", "")))
                vocabulary.update(w.casefold() for w in re.findall(r"[A-Za-z_]\w{2,}", claim.get("question", "")))
            missing = vocabulary - set(soup)
            if missing:  # only the cap may leave words out, and then the soup fills it
                self.assertGreater(len(" ".join(soup)), MAX_FIELD_CHARS - 40, (case.id, sorted(missing)[:5]))

    def test_a_keyword_claim_is_caught_by_the_case_aware_soup(self) -> None:
        base = make_cases(1)[0]
        keyword = {"type": "claims", "claims": [
            {"id": "word", "field": "answer", "must_match": "tools/check_scripts\\.sh|stderr"}]}
        scores = trivial_answerer_scores([Case(**{**asdict(base), "grader": keyword})])
        self.assertEqual(1.0, scores["case_soup_false"])
        self.assertGreater(scores["max"], TRIVIAL_LIMIT)


class KeywordRunTests(unittest.TestCase):
    """The grader-searched keyword run, for programmatic claims only."""

    def claim(self, pattern: str) -> dict:
        return {"id": "c", "field": "answer", "must_match": pattern}

    def test_the_keyword_run_searches_both_orders_shortest_first(self) -> None:
        self.assertEqual("exit code", keyword_run(self.claim(r"stderr|exit code")))
        self.assertEqual("zebra apple", keyword_run(self.claim(r"zebra\s+apple")))  # reverse order
        glued = self.claim(r"apple\s+is\s+zebra")  # "is" is glue no keyword list holds
        self.assertEqual("apple zebra", keyword_run(glued))
        self.assertFalse(check_claim(glued, {"answer": keyword_run(glued)}).passed)

    def test_judge_claims_get_no_keyword_run(self) -> None:
        case = real_case("funplay-32000")
        self.assertEqual({"first_check": "", "likely_cause": ""},
                         trivial_answers(case)["keyword_run_false"])

    def test_no_scored_programmatic_claim_is_satisfied_by_a_keyword_list_or_the_prompt(self) -> None:
        cases = load_cases(load_eval("repo_traps"))
        compact = compact_soup(cases)
        for case in cases:
            boolean = any(isinstance(c.get("equals"), bool) for c in case.grader["claims"])
            for claim in case.grader["claims"]:
                if "must_match" not in claim or not (boolean or claim.get("gate")):
                    continue
                for text in (keyword_run(claim), case_soup(case), compact, case.prompt):
                    self.assertFalse(check_claim(claim, {claim["field"]: text}).passed,
                                     f"{case.id}/{claim['id']} accepts {text[:60]!r}")


class HybridClaimTests(unittest.TestCase):
    """The repo_traps claims under the second council's decision."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = load_cases(load_eval("repo_traps"))

    def test_free_text_is_judged_and_only_structured_fields_are_checked_by_program(self) -> None:
        judged = programmatic = 0
        for case in self.cases:
            for claim in case.grader["claims"]:
                if is_judge_claim(claim):
                    judged += 1
                    self.assertTrue(claim["question"].startswith("The answer states"), claim["id"])
                elif not isinstance(claim.get("equals"), bool):
                    programmatic += 1
                    self.assertIn(claim["field"], STRUCTURED_FIELDS, f"{case.id}/{claim['id']}")
        self.assertEqual((55, 14), (judged, programmatic))

    def test_the_judge_questions_are_frozen(self) -> None:
        self.assertEqual(JUDGE_QUESTIONS_SHA256, judge_questions_sha256(self.cases))

    def test_each_case_without_a_boolean_has_one_gate_by_program_or_by_judge(self) -> None:
        kinds = []
        for case in self.cases:
            claims = case.grader["claims"]
            gates = [c for c in claims if c.get("gate")]
            boolean = any(isinstance(c.get("equals"), bool) for c in claims)
            self.assertEqual(0 if boolean else 1, len(gates), case.id)
            kinds += ["judge" if is_judge_claim(g) else "program" for g in gates]
        self.assertEqual({"program": 7, "judge": 6}, {k: kinds.count(k) for k in ("program", "judge")})

    def test_a_judge_gate_zeroes_its_case_and_a_programmatic_gate_spares_the_judge(self) -> None:
        self.assertTrue(is_decision_claim({"gate": True, "question": "The answer states x."}))
        fields = {"first_check": "Curl the editor URL the relay points at.",
                  "likely_cause": "The Godot editor is not running."}
        self.assertEqual(0.0, score("funplay-32000", credit=False, **fields))
        judge = fake_judge(True)
        result = grade(real_case("paired-calls-hit-player"), json.dumps(
            {"missing_call": "_hero.ward_hit(Vector2.LEFT)", "reason": "It comes from the right."}), judge)
        self.assertEqual((0.0, []), (result.score, judge.calls))

    def test_a_claim_is_programmatic_or_judged_never_both(self) -> None:
        for bad in ({"id": "a", "field": "f", "equals": True, "gate": True},
                    {"id": "a", "field": "f", "must_match": "x", "gate": "yes"},
                    {"id": "a", "field": "f", "must_match": "x", "question": "The answer states x."},
                    {"id": "a", "question": "The answer states x."},
                    {"id": "a", "field": "f", "question": " "}):
            with self.assertRaises(EvalError):
                validate_grader_spec({"type": "claims", "claims": [bad]})
        validate_grader_spec({"type": "claims", "claims": [
            {"id": "a", "field": "f", "must_match": "x", "gate": True},
            {"id": "b", "field": "f", "question": "The answer states x.", "gate": True}]})

    def test_the_hit_area_floor_rejects_a_range_and_accepts_forty_four(self) -> None:
        for value, expected in ((44, True), ("44 pt", True), ("44 x 44 pt", True), ("44.5 or 48", False),
                                (48, False)):
            self.assertEqual(expected, passed("scaled-hit-area", min_target_pt=value, change="x",
                                              check_first="x")["floor"], value)

    def test_the_replaced_and_delead_cases_stay_neutral_and_sourced(self) -> None:
        by_id = {c.id: c for c in self.cases}
        self.assertNotIn("state-class-beats-centring", by_id)
        self.assertNotIn("every-number-matched-but-wrong", by_id)
        for case_id in ("lab-actor-without-profile", "mob-override-complete-entry"):
            case = by_id[case_id]
            self.assertTrue((ROOT / case.source).is_file(), case.source)
            self.assertTrue(case.why_hard and case.reference)
        for phrase, case_id in (("You have not looked at the filesystem", "exit-zero-is-not-an-artifact"),
                                ("exhibited no failing seed", "reviewer-hypothetical"),
                                ("You have not measured anything", "get-global-rect-is-not-the-trap"),
                                ("must the fixture be built another way", "hand-written-vigil-json"),
                                ("why can it never plant all four", "flat-shadow-four-paws")):
            self.assertNotIn(phrase.casefold(), by_id[case_id].prompt.casefold(), case_id)
        for case in by_id.values():
            self.assertNotIn("4.7.1", case.prompt, case.id)


class ReferenceAnswerTests(unittest.TestCase):
    """The programmatic side never rejects a known correct answer: the references, two answers in
    other words, and the blind writer's independent set."""

    CODE_RENDERINGS = {("typed-array-ternary", "fixed_code")}  # the reference states this fix in prose

    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = {c.id: c for c in load_cases(load_eval("repo_traps"))}
        rows = answers()
        cls.answers = rows
        cls.correct = [(cid, row["reference"]) for cid, row in rows.items()]
        cls.correct += [(cid, answer) for cid, row in rows.items() for answer in row["correct"]]
        cls.correct += [(row["id"], row["answer"]) for row in independent_answers()]

    def test_every_case_has_a_reference_answer_taken_from_its_reference(self) -> None:
        self.assertEqual(set(self.cases), set(self.answers))
        for case_id, row in self.answers.items():
            self.assertLessEqual({c["field"] for c in self.cases[case_id].grader["claims"]}, set(row["reference"]))
            for field, value in row["reference"].items():
                if isinstance(value, str) and (case_id, field) not in self.CODE_RENDERINGS:
                    self.assertIn(value, self.cases[case_id].reference, f"{case_id}/{field}")

    def test_the_independent_set_has_two_blind_answers_per_case(self) -> None:
        rows = independent_answers()
        self.assertEqual({case_id: 2 for case_id in self.cases},
                         {case_id: sum(r["id"] == case_id for r in rows) for case_id in self.cases})

    def test_no_programmatic_claim_rejects_a_known_correct_answer(self) -> None:
        self.assertEqual(35 * 5, len(self.correct))
        for case_id, answer in self.correct:
            _, settled, failure = programmatic_verdicts(self.cases[case_id], json.dumps(answer))
            self.assertIsNone(failure, (case_id, answer))
            self.assertEqual([], [v for v in settled.values() if not v.passed], (case_id, answer))

    def test_with_a_judge_that_agrees_every_known_correct_answer_scores_full_marks(self) -> None:
        for case_id, answer in self.correct:
            result = grade(self.cases[case_id], json.dumps(answer), fake_judge(True))
            self.assertEqual(1.0, result.score, (case_id, [v for v in result.verdicts if not v.passed]))


class DelegatedApprovalTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = Path(tempfile.mkdtemp(prefix="agent-evals-delegated-"))
        self.addCleanup(lambda: __import__("shutil").rmtree(self.dir, ignore_errors=True))
        self.report = self.dir / "council.md"
        self.report.write_text("# council report\n", encoding="utf-8")
        self.text = "James, 4 Oct 11:31: you design that for me"

    def delegation(self) -> dict:
        return approvals.delegation_record(self.text, self.report)

    def test_the_record_names_the_orchestrator_the_delegator_and_the_evidence_hash(self) -> None:
        record = approvals.approve_inputs(self.dir, "h1", self.delegation())
        self.assertEqual("orchestrator", record["by"])
        self.assertEqual(self.text, record["delegated_by"])
        self.assertEqual({"path": str(self.report), "sha256": sha256_text("# council report\n")},
                         record["evidence"])
        self.assertEqual("h1", record["cases_sha256"])
        self.assertTrue(record["at"])
        self.assertEqual(record, json.loads((self.dir / "approvals.json").read_text())["inputs"])

    def test_the_grader_approval_keeps_the_sampled_transcript_rule_when_delegated(self) -> None:
        ids = [f"transcripts/haiku/c{i}__r1.json" for i in range(9)]
        sample = approvals.sample_transcript_ids(ids, "run-1")
        def approve(read: list[str]) -> dict:
            return approvals.approve_grader(self.dir, "h1", "s1", ids, "run-1", read, healthy_results(),
                                            ["c1", "c2"], delegation=self.delegation())
        with self.assertRaises(approvals.ApprovalError):
            approve(sample[:-1])
        record = approve(sample)
        self.assertEqual("orchestrator", record["by"])
        self.assertEqual(self.text, record["delegated_by"])

    def test_a_blank_text_or_a_missing_evidence_file_is_refused(self) -> None:
        with self.assertRaises(approvals.ApprovalError):
            approvals.delegation_record("  ", self.report)
        with self.assertRaises(approvals.ApprovalError):
            approvals.delegation_record(self.text, self.dir / "missing.md")

    def cli_args(self, **changes: object) -> Namespace:
        return Namespace(**{"eval": "synthetic", "delegated": None, "evidence": None, **changes})

    def run_cli(self, args: Namespace, stdin_is_tty: bool):
        spec = SimpleNamespace(directory=self.dir, cases_sha256="h1")
        stdin = mock.Mock(isatty=mock.Mock(return_value=stdin_is_tty))
        with mock.patch.object(cli, "_load", return_value=(spec, [])), \
                mock.patch.object(cli.sys, "stdin", stdin), contextlib.redirect_stdout(io.StringIO()):
            return cli.cmd_approve_inputs(args)

    def test_the_tty_guard_stays_the_default_and_the_flag_replaces_it(self) -> None:
        with self.assertRaisesRegex(approvals.ApprovalError, "interactive terminal"):
            self.run_cli(self.cli_args(), stdin_is_tty=False)
        self.assertFalse((self.dir / "approvals.json").exists())
        self.assertEqual(0, self.run_cli(self.cli_args(delegated=self.text, evidence=str(self.report)),
                                         stdin_is_tty=False))
        entry = json.loads((self.dir / "approvals.json").read_text())["inputs"]
        self.assertEqual("orchestrator", entry["by"])

    def test_one_flag_without_the_other_is_refused(self) -> None:
        for changes in ({"delegated": self.text}, {"evidence": str(self.report)}):
            with self.assertRaisesRegex(approvals.ApprovalError, "together"):
                self.run_cli(self.cli_args(**changes), stdin_is_tty=True)

    def test_the_real_cli_still_refuses_a_pipe_and_a_half_given_delegation(self) -> None:
        script = str(ROOT / "tools/agent_evals/cli.py")
        recorded = ROOT / "tools/agent_evals/evals/repo_traps/approvals.json"
        before = recorded.read_bytes() if recorded.exists() else None
        for extra in ([], ["--delegated", "someone"]):
            done = subprocess.run([sys.executable, script, "approve-inputs", "repo_traps", *extra],
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False)
            self.assertEqual(1, done.returncode, extra)
        # A refusal writes nothing: the recorded approvals are byte for byte what they were.
        self.assertEqual(before, recorded.read_bytes() if recorded.exists() else None)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Tests for the repo_traps grader. From the first council: the decision gate, trivial answerers
and delegated approval. From the second: the hybrid grader, with programmatic claims for
decisions, commands, paths, numbers and code, and judge claims for free text. From the third: the
reference-guided judge arm, sibling targets, the frozen claims and the offline calibration
metrics. No model is called: the judge here is a fake that credits every claim, or none."""
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

from agent_evals import approvals, calibration, cli  # noqa: E402
from agent_evals.diagnostics import (TRIVIAL_LIMIT, case_soup, compact_soup,  # noqa: E402
                                     keyword_run, keyword_soup, trivial_answerer_scores,
                                     trivial_answers)
from agent_evals.evalspec import load_cases, load_eval  # noqa: E402
from agent_evals.graders import (JUDGE_SYSTEM, JUDGE_SYSTEM_REFERENCE, MAX_FIELD_CHARS,  # noqa: E402
                                 check_claim, claim_keywords, claims_sha256, grade, is_decision_claim,
                                 is_judge_claim, parse_json_answer, programmatic_verdicts,
                                 validate_grader_spec)
from agent_evals.runner import run_case  # noqa: E402
from agent_evals.backends import FakeBackend  # noqa: E402
from agent_evals.models import Case, EvalError, sha256_text  # noqa: E402

FILLERS = ("echo", "soup", "compact_soup", "case_soup", "keyword_run", "hedge", "padded", "injected")
ANSWERERS = {"empty", "constant_false", "constant_true", "oracle_booleans"} | {
    f"{filler}_{mode}" for filler in FILLERS for mode in ("false", "true", "oracle")}
EVAL_DIR = ROOT / "tools/agent_evals/evals/repo_traps"
ANSWERS_FILE = EVAL_DIR / "answers.jsonl"
# Every claim, programmatic and judge, frozen before the fresh sets are scored (round 3 of
# council-2026-10-05.md). Any change to a claim changes this hash: the calibration and the grader
# approval must then be redone.
CLAIMS_SHA256 = "0235c5bc81daa4e8ae1ce08109ce95a363631605b54ed8b7f87d85db81e374e8"
# The fields programmatic claims may read besides booleans: a command, code, a citation, a number
# and a one-phrase owner. Every other field is free text and is judged.
STRUCTURED_FIELDS = {"gate", "fixed_code", "missing_call", "citation", "min_target_pt", "owner"}
# Each programmatic target and siblings an answer could name in its place (round 3, item 2).
SIBLING_SWAPS = {
    "check-only-exit-zero": [("check_scripts.sh", s) for s in ("check_imports.sh", "check_anchors.py",
                                                               "check_benchmark_freeze.py")],
    "typed-array-ternary": [("_bequest_choices", s) for s in ("_reward_choices", "_shop_choices")]
                           + [("Array[Dictionary]", "Array[String]")],
    "typed-array-new-literal": [("_draw_pile", s) for s in ("_discard_pile", "_exhaust_pile")]
                               + [("Array[Card]", "Array[Dictionary]")],
    "borrowed-shader-const-markers": [("BODY_SHADER", s) for s in ("SHADOW_SHADER", "HUSK_SHADER")]
                                     + [("EnemyView", "HeroView")],
    "half-size-times-scale": [("from.get_center", s) for s in ("to.get_center", "view.get_center")]
                             + [("* 0.5", "* 0.5 * born"), ("* 0.5", "* 0.5 * view.scale")],
    "label-box-from-font-metrics": [("minus get_ascent", "minus get_descent"),
                                    ("- font.get_ascent", "- font.get_descent")],
    "paired-calls-hit-player": [("_hero.", s) for s in ("_enemy.", "_foe.")]
                               + [("Vector2.RIGHT", s) for s in ("Vector2.LEFT", "Vector2(-1, 0)")],
    "cite-the-symbol": [("enemy_view.gd", "hero_view.gd"), ("enemy_view.gd`", "enemy_view.gd:2418`")],
    "language-switch-owner": [("Main", s) for s in ("SettingsPanel", "ContentDB")],
    "lab-actor-without-profile": [("art.get", s) for s in ("locale.get", "def.get")],
    "scaled-hit-area": [("44", "24")],
}


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


def known_correct_answers() -> list[tuple[str, dict]]:
    """Every committed correct answer: the references, answers.jsonl, set A and calibration sets b and c."""
    rows = answers()
    correct = [(cid, row["reference"]) for cid, row in rows.items()]
    correct += [(cid, answer) for cid, row in rows.items() for answer in row["correct"]]
    correct += [(row["id"], row["answer"]) for row in independent_answers()]
    for name in ("b", "c"):
        lines = (EVAL_DIR / f"calibration/answers-{name}.jsonl").read_text(encoding="utf-8").splitlines()
        correct += [(row["id"], row["answer"]) for row in map(json.loads, filter(None, lines))]
    return correct


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
        self.assertEqual({"safe_to_ship": False, "fixed_code": "", "reason": ""}, answer)

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
        self.assertEqual((56, 14), (judged, programmatic))

    def test_every_claim_is_frozen(self) -> None:
        self.assertEqual(CLAIMS_SHA256, claims_sha256(self.cases))

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
    other words, the blind writer's independent set and calibration sets b and c."""

    CODE_RENDERINGS = {("typed-array-ternary", "fixed_code")}  # the reference states this fix in prose

    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = {c.id: c for c in load_cases(load_eval("repo_traps"))}
        rows = answers()
        cls.answers = rows
        cls.correct = known_correct_answers()

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
        self.assertEqual(35 * 9, len(self.correct))
        for case_id, answer in self.correct:
            _, settled, failure = programmatic_verdicts(self.cases[case_id], json.dumps(answer))
            self.assertIsNone(failure, (case_id, answer))
            self.assertEqual([], [v for v in settled.values() if not v.passed], (case_id, answer))

    def test_with_a_judge_that_agrees_every_known_correct_answer_scores_full_marks(self) -> None:
        for case_id, answer in self.correct:
            result = grade(self.cases[case_id], json.dumps(answer), fake_judge(True))
            self.assertEqual(1.0, result.score, (case_id, [v for v in result.verdicts if not v.passed]))


class SiblingTargetTests(unittest.TestCase):
    """Round 3: a programmatic target claim rejects a sibling target, whether it replaces the
    target or is offered beside it."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = {c.id: c for c in load_cases(load_eval("repo_traps"))}
        cls.correct = known_correct_answers()

    def fails(self, case_id: str, answer: dict) -> bool:
        _, settled, failure = programmatic_verdicts(self.cases[case_id], json.dumps(answer))
        return failure is not None or any(not v.passed for v in settled.values())

    def test_every_swapped_or_added_sibling_fails_a_known_correct_answer(self) -> None:
        self.assertEqual(35 * 9, len(self.correct))
        applied: dict[tuple[str, str, str], int] = {}
        for case_id, answer in self.correct:
            self.assertFalse(self.fails(case_id, answer), (case_id, answer))
            fields = {c["field"] for c in self.cases[case_id].grader["claims"] if not is_judge_claim(c)}
            for old, new in SIBLING_SWAPS.get(case_id, []):
                for field in fields:
                    text = answer.get(field)
                    if not isinstance(text, str) or old not in text:
                        continue
                    swapped = text.replace(old, new)
                    for mutant in (swapped, f"{text} or {swapped}"):
                        self.assertTrue(self.fails(case_id, {**answer, field: mutant}), (case_id, mutant))
                    applied[(case_id, old, new)] = applied.get((case_id, old, new), 0) + 1
        missing = [(c, o, n) for c, pairs in SIBLING_SWAPS.items() for o, n in pairs if (c, o, n) not in applied]
        self.assertEqual([], missing, "a sibling swap that touches no correct answer tests nothing")

    def test_no_programmatic_claim_looks_for_hedge_wording(self) -> None:
        hedges = re.compile(r"perhaps|maybe|might|possibly|or not|either", re.IGNORECASE)
        for case in self.cases.values():
            for claim in case.grader["claims"]:
                for key in ("must_match", "must_not_match"):
                    self.assertIsNone(hedges.search(claim.get(key, "")), f"{case.id}/{claim['id']}")


class ReferenceArmTests(unittest.TestCase):
    """Round 3: arm R shows the judge the case's reference, labelled as the expert's; arm P never
    does. The arm is recorded with every transcript."""

    CASE = "funplay-32000"
    ANSWER = {"first_check": "Probe the editor URL with curl.", "likely_cause": "The editor is not running."}

    def judged(self, arm: str) -> dict[str, str]:
        judge = fake_judge(True)
        result = grade(real_case(self.CASE), json.dumps(self.ANSWER), judge, judge_arm=arm)
        self.assertEqual(1.0, result.score)
        return judge.calls[0]

    def test_the_reference_arm_shows_the_labelled_reference_and_the_plain_arm_never_does(self) -> None:
        reference = real_case(self.CASE).reference
        plain, guided = self.judged("plain"), self.judged("reference")
        self.assertEqual((JUDGE_SYSTEM, JUDGE_SYSTEM_REFERENCE), (plain["system"], guided["system"]))
        self.assertNotIn(reference, plain["prompt"])
        self.assertNotIn("reference", plain["system"].casefold())
        self.assertIn(f"<<<REFERENCE\n{reference}\nREFERENCE>>>", guided["prompt"])
        self.assertIn("expert's reference", guided["prompt"])
        self.assertIn("never credit the answer for what only the reference says", guided["system"])
        self.assertLess(guided["prompt"].index("REFERENCE>>>"), guided["prompt"].index("<<<ANSWER"))

    def test_an_unknown_arm_is_refused(self) -> None:
        with self.assertRaisesRegex(EvalError, "unknown judge arm"):
            grade(real_case(self.CASE), json.dumps(self.ANSWER), fake_judge(True), judge_arm="lenient")

    def test_the_transcript_records_the_arm_and_the_judge(self) -> None:
        backend = FakeBackend(lambda system, prompt, model: json.dumps(self.ANSWER))
        record = run_case(backend, real_case(self.CASE), 1, "sonnet", "surface", "repo_traps",
                          fake_judge(True), "sonnet", judge_arm="reference")
        self.assertEqual(("sonnet", "reference", "fake-sonnet"),
                         (record["judge_model"], record["judge_arm"], record["judge_model_id"]))
        self.assertEqual("", run_case(backend, real_case("cite-the-symbol"), 1, "sonnet", "s")["judge_arm"])


class CalibrationMetricsTests(unittest.TestCase):
    """Round 3, item 4: the bars computed offline from two gradings of each set and a labels file."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = {c.id: c for c in load_cases(load_eval("repo_traps"))}
        refs = answers()
        correct = [{"id": cid, "answer": refs[cid]["reference"]} for cid in ("check-only-exit-zero", "funplay-32000")]
        correct.append({"id": "never-delete-the-real-save", "answer": refs["never-delete-the-real-save"]["reference"],
                        "hedged": True})
        wrong = [
            {"id": "paired-calls-hit-player", "kind": "wrong-target",
             "answer": {**refs["paired-calls-hit-player"]["reference"], "missing_call": "_enemy.ward_hit(Vector2.RIGHT)"}},
            {"id": "funplay-32000", "kind": "mechanism",
             "answer": {**refs["funplay-32000"]["reference"], "likely_cause": "A corrupted MCP package."}},
            {"id": "language-switch-owner", "kind": "negation",
             "answer": {**refs["language-switch-owner"]["reference"], "during_combat": "Switch at once."}},
            {"id": "dom-pile-keep-nodes", "kind": "hedge",
             "answer": {**refs["dom-pile-keep-nodes"]["reference"], "reason": "Keep them, or perhaps not."}},
        ]
        adversarial = [{"id": cid, "kind": "kitchen-sink", "answer": {"owner": "Main SettingsPanel"}}
                       for cid in ("language-switch-owner", "cite-the-symbol")]
        stingy = fake_judge(lambda claim_id: claim_id != "explains-stderr")

        def graded(rows, name, role, run, judge):
            meta = {"set": name, "role": role, "run": run, "claims_sha256": claims_sha256(cls.cases.values())}
            return calibration.grade_set(cls.cases, rows, judge, "sonnet", "plain", meta, workers=1)

        cls.gradings = (graded(correct, "d", "correct", 1, fake_judge(True)) + graded(correct, "d", "correct", 2, stingy)
                        + graded(wrong, "w", "wrong", 1, fake_judge(True))
                        + graded(adversarial, "x", "adversarial", 1, fake_judge(True)))
        cls.labels = {("w", 0, "right-heading-call"): "COVERED", ("w", 0, "direction-reason"): "COVERED",
                      ("w", 1, "editor-not-running"): "COVERED", ("w", 2, "main-owns"): "COVERED",
                      ("w", 2, "defers"): "AMBIGUOUS"}
        cls.report = calibration.metrics(cls.cases, cls.gradings, cls.labels)

    def test_wilson_matches_known_values(self) -> None:
        for (k, n), expected in (((0, 10), (0.0, 0.2775)), ((5, 10), (0.2366, 0.7634)), ((0, 0), (0.0, 1.0)),
                                 ((3, 140), (0.0073, 0.0611))):
            self.assertEqual(expected, tuple(round(x, 4) for x in calibration.wilson(k, n)), (k, n))

    def test_the_clustered_interval_resamples_whole_cases(self) -> None:
        self.assertEqual((0.0, 0.0), calibration.clustered_interval([(0, 4)] * 5))
        one_bad_case = calibration.rate([("a", True)] * 10 + [(c, False) for c in "bcdefghij" for _ in range(10)])
        low, high = one_bad_case["clustered"]
        self.assertEqual((10, 100, 0.1), (one_bad_case["k"], one_bad_case["n"], one_bad_case["rate"]))
        self.assertTrue(low == 0.0 and high > one_bad_case["wilson"][1], one_bad_case)

    def test_correct_sets_report_claim_failures_and_hedged_answers_apart(self) -> None:
        first, second = self.report["runs"]["plain/correct/run1"], self.report["runs"]["plain/correct/run2"]
        self.assertEqual((0, 3), (first["all"]["claim_failure"]["k"], first["all"]["answers"]))
        self.assertEqual(1, second["all"]["claim_failure"]["k"])
        self.assertEqual([{"set": "d", "index": 0, "id": "check-only-exit-zero", "failed": ["explains-stderr"]}],
                         second["all"]["under_100"])
        self.assertEqual((1, 2), (second["hedged"]["answers"], second["not_hedged"]["answers"]))
        self.assertEqual((0, 0), (second["all"]["decision_or_gate_failures"], second["judge_errors"]))

    def test_wrong_sets_count_covered_judge_passes_programmatic_passes_and_coverage(self) -> None:
        wrong = self.report["runs"]["plain/wrong/run1"]
        self.assertEqual((1, 1), (wrong["fp_covered_judge"]["k"], wrong["fp_covered_judge"]["n"]))
        self.assertEqual({"mechanism": (1, 1)}, {k: (v["k"], v["n"]) for k, v in
                                                  wrong["fp_covered_judge_by_kind"].items() if v["n"]})
        self.assertEqual(1, wrong["covered_judge_not_judged"])
        self.assertEqual([{"set": "w", "index": 2, "claim": "main-owns"}], wrong["covered_programmatic_passes"])
        self.assertEqual((3, 4), (wrong["wrong_at_100"]["k"], wrong["wrong_at_100"]["n"]))
        self.assertEqual((3, 4), (wrong["coverage"]["k"], wrong["coverage"]["n"]))
        self.assertEqual(1, wrong["ambiguous_labels"])

    def test_two_gradings_give_disagreement_splits_and_the_score_change(self) -> None:
        stable = self.report["stability"]["plain/d"]
        self.assertEqual((1, 5), (stable["majority_disagreement"]["k"], stable["majority_disagreement"]["n"]))
        self.assertAlmostEqual(1 / 3 / 3, stable["score_change"])
        self.assertFalse(stable["score_change_within_limit"])
        self.assertEqual([], stable["gate_splits"])
        self.assertNotIn("plain/w", self.report["stability"])

    def test_adversarial_sets_are_set_beside_the_oracle_booleans(self) -> None:
        adversarial = self.report["runs"]["plain/adversarial/run1"]
        self.assertEqual({"kitchen-sink": 0.0}, adversarial["mean_by_transform"])
        self.assertAlmostEqual(0.2381, adversarial["oracle_booleans"], places=4)

    def test_gradings_made_with_other_claims_are_refused(self) -> None:
        stale = [{**row, "claims_sha256": "0" * 64} for row in self.gradings[:1]]
        with self.assertRaisesRegex(ValueError, "other claims"):
            calibration.metrics(self.cases, stale, {})

    def test_the_command_line_grades_nothing_twice_and_reads_labels(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            gradings, labels, out = Path(tmp, "g.jsonl"), Path(tmp, "l.jsonl"), Path(tmp, "m.json")
            gradings.write_text("".join(json.dumps(row) + "\n" for row in self.gradings), encoding="utf-8")
            labels.write_text("".join(json.dumps({"set": s, "index": i, "claim_id": c, "label": label}) + "\n"
                                      for (s, i, c), label in self.labels.items()), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(0, calibration.main(["metrics", "--gradings", str(gradings), "--labels",
                                                      str(labels), "--out", str(out)]))
            self.assertEqual(json.loads(json.dumps(self.report)), json.loads(out.read_text(encoding="utf-8")))
            with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
                calibration.main(["grade", "--answers", str(labels), "--set", "d", "--role", "correct",
                                  "--run", "1", "--arm", "plain", "--out", str(out)])


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

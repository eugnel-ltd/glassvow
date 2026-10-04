#!/usr/bin/env python3
"""Tests for the repo_traps council changes: decision gate, trivial answerers, negation, delegation,
and the grader-readiness items (compact soups, structural gates, the hit-count limit, tightened claims)."""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
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
from test_agent_evals import ROOT, healthy_results, make_cases  # noqa: E402

from agent_evals import approvals, cli  # noqa: E402
from agent_evals.diagnostics import (TRIVIAL_LIMIT, capped_keywords, case_soup,  # noqa: E402
                                     compact_soup, keyword_run, keyword_soup,
                                     trivial_answerer_scores, trivial_answers)
from agent_evals.evalspec import load_cases, load_eval  # noqa: E402
from agent_evals.graders import (MAX_FIELD_CHARS, check_claim, claim_keywords,  # noqa: E402
                                 grade_claims, hit_limit, is_decision_claim, keyword_hits,
                                 parse_json_answer, validate_grader_spec)
from agent_evals.models import Case, EvalError, sha256_text  # noqa: E402

FILLERS = ("echo", "soup", "compact_soup", "case_soup", "capped_soup", "keyword_run")
ANSWERERS = {"empty", "constant_false", "constant_true", "oracle_booleans"} | {
    f"{filler}_{mode}" for filler in FILLERS for mode in ("false", "true", "oracle")}
EVAL_DIR = ROOT / "tools/agent_evals/evals/repo_traps"
ANSWERS_FILE = EVAL_DIR / "answers.jsonl"
# Wordings the re-review of PR #691 found zeroed or short of full marks; each, with the case's
# other fields taken from its reference answer, must score 100%.
REVIEW_WORDINGS = [
    ("language-switch-owner", "panel_does",
     "The panel does nothing but emit a language_changed signal asking Main to switch."),
    ("language-switch-owner", "panel_does", "It emits a language_changed request; Main does the work."),
    ("language-switch-owner", "panel_does", "The panel emits language_changed so Main can perform the change."),
    ("language-switch-owner", "panel_does", "The panel emits a language_changed signal and nothing else."),
    ("language-switch-owner", "panel_does", "It requests the change from Main by emitting a signal."),
    ("funplay-32000", "likely_cause", "The Godot editor or plugin has not been started."),
    ("funplay-32000", "likely_cause", "The plugin never loaded in the editor."),
    ("test-loop-over-suspect-container", "action_one", "Make sure FORMS[form] is not empty before the loop."),
    ("test-loop-over-suspect-container", "action_one", "Add a precondition that the container has at least one entry."),
    ("shared-helper-blast-radius", "default", "Defaults to an algebraic identity."),
    ("canary-pins-the-rule", "assertion", "The raw subscript result and LayoutBook.fields(built_key) disagree."),
    ("canary-pins-the-rule", "assertion", "raw never equals LayoutBook.fields(built_key)"),
    ("canary-pins-the-rule", "assertion", "The raw subscript output is not what fields() returns."),
    ("shared-doc-landed-already", "first_step", "Check origin/main for the entry."),
]


def real_case(case_id: str) -> Case:
    return next(c for c in load_cases(load_eval("repo_traps")) if c.id == case_id)


def score(case_id: str, **answer: object) -> float:
    return grade_claims(real_case(case_id), json.dumps(answer)).score


def passed(case_id: str, **answer: object) -> dict[str, bool]:
    grade = grade_claims(real_case(case_id), json.dumps(answer))
    return {v.claim_id: v.passed for v in grade.verdicts}


class DecisionGateTests(unittest.TestCase):
    CASE = "script-error-is-not-renderer-noise"

    def test_a_wrong_decision_scores_zero_even_when_the_reasoning_is_right(self) -> None:
        grade = grade_claims(real_case(self.CASE), json.dumps(
            {"failure_is_real": False, "next_step": "Fix the null guard in _return_checks."}))
        self.assertTrue(grade.decision_failed)
        self.assertEqual(0.0, grade.score)
        self.assertTrue(grade.to_json()["decision_failed"])

    def test_a_right_decision_with_poor_reasoning_keeps_partial_credit(self) -> None:
        grade = grade_claims(real_case(self.CASE), json.dumps(
            {"failure_is_real": True, "next_step": "Look at it."}))
        self.assertFalse(grade.decision_failed)
        self.assertEqual(0.5, grade.score)

    def test_a_missing_decision_field_also_closes_the_gate(self) -> None:
        self.assertEqual(0.0, score(self.CASE, next_step="Fix the guard."))

    def test_a_case_without_a_boolean_claim_is_never_gated(self) -> None:
        case = make_cases(1)[0]
        text_only = Case(**{**asdict(case), "grader": {"type": "claims", "claims": [
            {"id": "a", "field": "answer", "must_match": "yes"},
            {"id": "b", "field": "answer", "must_match": "no"}]}})
        grade = grade_claims(text_only, json.dumps({"answer": "yes"}))
        self.assertFalse(grade.decision_failed)
        self.assertEqual(0.5, grade.score)

    def test_a_single_key_nested_answer_is_unwrapped(self) -> None:
        self.assertEqual({"verdicts": {"a": True}}, parse_json_answer('{"verdicts": {"a": true}}'))
        nested = {"answer": {"failure_is_real": True, "next_step": "Fix the guard."}}
        self.assertEqual(1.0, grade_claims(real_case(self.CASE), json.dumps(nested)).score)
        self.assertEqual(1.0, grade_claims(real_case(self.CASE), "```json\n" + json.dumps(nested) + "\n```").score)


class TrivialAnswererTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = load_cases(load_eval("repo_traps"))
        cls.scores = trivial_answerer_scores(cls.cases)

    def test_every_answerer_is_reported_and_none_beats_the_limit(self) -> None:
        self.assertEqual(ANSWERERS, set(self.scores) - {"max", "limit"})
        for name in ANSWERERS:
            self.assertLessEqual(self.scores[name], TRIVIAL_LIMIT, name)
        self.assertEqual(0.0, self.scores["empty"])
        # No text filler earns anything beyond the booleans it is handed.
        for filler in ("echo", "soup", "compact_soup", "case_soup"):
            self.assertEqual(self.scores["oracle_booleans"], self.scores[f"{filler}_oracle"], filler)

    def test_oracle_booleans_get_the_right_flags_and_empty_text(self) -> None:
        case = real_case("typed-array-ternary")
        answer = trivial_answers(case, "soup")["oracle_booleans"]
        self.assertEqual({"safe_to_ship": False, "fixed_code": ""}, answer)

    def test_the_soup_holds_domain_words_and_is_defeated_only_by_the_field_cap(self) -> None:
        soup = keyword_soup(self.cases)
        for word in ("check_scripts.sh", "set_profile", "uniform", "draw_set_transform"):
            self.assertIn(word, soup)
        self.assertGreater(len(soup), MAX_FIELD_CHARS)
        case = real_case("check-only-exit-zero")
        stuffed = {"parse_error_is_real": True, "gate": soup, "reason": soup}
        grade = grade_claims(case, json.dumps(stuffed))
        self.assertEqual({"verdict-true": True, "names-the-repo-gate": False,
                          "explains-stderr": False}, {v.claim_id: v.passed for v in grade.verdicts})
        self.assertIn("characters", grade.verdicts[1].detail)

    def lenient(self) -> list[Case]:
        base = make_cases(1)[0]
        grader = {"type": "claims", "claims": [{"id": "word", "field": "answer", "must_match": "gate"}]}
        return [Case(**{**asdict(base), "id": "lenient", "grader": grader, "reference": "the gate"})]

    def test_a_grader_a_keyword_soup_can_pass_trips_the_diagnostic(self) -> None:
        scores = trivial_answerer_scores(self.lenient())
        self.assertEqual(1.0, scores["soup_false"])
        self.assertGreater(scores["max"], TRIVIAL_LIMIT)

    def test_approve_grader_refuses_when_the_current_cases_fail_the_soup_check(self) -> None:
        healthy = healthy_results(("c1",))
        live = trivial_answerer_scores(self.lenient())
        with self.assertRaisesRegex(approvals.ApprovalError, "too lenient"):
            approvals.check_run_eligible(healthy, "h1", "s1", ["c1"], live)
        approvals.check_run_eligible(healthy, "h1", "s1", ["c1"], self.scores)


class NegationSafetyTests(unittest.TestCase):
    def test_a_refusal_that_names_the_noise_word_is_not_credited_as_noise(self) -> None:
        wrong = passed("renderer-noise-is-not-a-failure", block_pr=False,
                       reason="This is not noise; the leaked RIDs matter.")
        right = passed("renderer-noise-is-not-a-failure", block_pr=False,
                       reason="Harmless leak noise from the dummy renderer; the suite passed.")
        self.assertFalse(wrong["cites-noise"])
        self.assertTrue(all(right.values()))

    def test_a_correct_refusal_may_name_the_forbidden_verb(self) -> None:
        result = passed("script-error-is-not-renderer-noise", failure_is_real=True,
                        next_step="Do not ignore it or push anyway; fix the null guard first.")
        self.assertTrue(all(result.values()), result)

    def test_non_interactive_reasoning_does_not_credit_keeping_the_nodes(self) -> None:
        case = "dom-pile-keep-nodes"
        self.assertFalse(passed(case, collapse_to_one_draw=False,
                                reason="The chips are non-interactive decoration.")["interactivity-reason"])
        good = passed(case, collapse_to_one_draw=False,
                      reason="Each chip owns its hover tooltip and press-to-pin input.")
        self.assertTrue(all(good.values()), good)

    def test_the_canary_must_compare_with_the_truth_not_pin_a_literal(self) -> None:
        wrong = passed("canary-pins-the-rule", assertion="assert raw != expected_24", why="platform rule")
        right = passed("canary-pins-the-rule", why="It is the invariant the workaround needs.",
                       assertion="raw output differs from the fields() workaround output")
        self.assertFalse(wrong["compares-to-truth"])
        self.assertTrue(all(right.values()))
        for literal in ("raw.size() != 0 and raw.size() != 24", "accept 0 or 24 against fields()"):
            self.assertFalse(passed("canary-pins-the-rule", assertion=literal, why="rule")["compares-to-truth"])


class CaseFixTests(unittest.TestCase):
    def test_the_hit_area_floor_rejects_a_range_and_accepts_forty_four(self) -> None:
        for value, expected in ((44, True), ("44 pt", True), ("44.5 or 48", False), (48, False)):
            self.assertEqual(expected, passed("scaled-hit-area", min_target_pt=value, change="x",
                                              check_first="x")["floor"], value)

    def test_the_two_replacement_cases_credit_a_correct_answer_and_gate_a_wrong_one(self) -> None:
        profile = dict(cause="The lab never calls set_profile, so every view idles as the humanoid.",
                       fixed_code='view.set_profile(str(art.get("kind", "humanoid")))')
        self.assertEqual(1.0, score("lab-actor-without-profile", idle_numbers_are_wrong=False, **profile))
        self.assertEqual(0.0, score("lab-actor-without-profile", idle_numbers_are_wrong=True, **profile))
        entry = dict(saved_entry="The complete duskfang definition, not a patch.",
                     after_revert="The duskfang entry is removed; the file returns to {}.")
        self.assertEqual(1.0, score("mob-override-complete-entry", complete_entry_required=True, **entry))
        self.assertEqual(0.0, score("mob-override-complete-entry", complete_entry_required=False, **entry))

    def test_widened_paraphrases_are_credited(self) -> None:
        cases = [
            ("typed-array-ternary", dict(safe_to_ship=False, reason="x", fixed_code=(
                "var choices: Array[Dictionary] = []\nif outcome == \"death\": choices.assign(_bequest_choices())"))),
            ("half-size-times-scale", dict(fixed_code="var start = from.get_center() - view.size / 2.0",
                                           rule="The centre does not move when you scale, whatever born is.")),
            ("paired-calls-hit-player", dict(missing_call="_hero.ward_hit(Vector2(1, 0))",
                                             reason="The heading points right, toward the enemy.")),
            ("funplay-32000", dict(first_check="Check the Godot editor plugin is running.",
                                   likely_cause="The editor backend is not reachable.")),
        ]
        for case_id, answer in cases:
            self.assertEqual(1.0, score(case_id, **answer), case_id)

    def test_the_replaced_and_delead_cases_stay_neutral_and_sourced(self) -> None:
        by_id = {c.id: c for c in load_cases(load_eval("repo_traps"))}
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


def answers() -> dict[str, dict]:
    """answers.jsonl by case id: the reference answer field by field, and two correct answers."""
    lines = ANSWERS_FILE.read_text(encoding="utf-8").splitlines()
    return {row["id"]: row for row in map(json.loads, filter(None, lines))}


def soup_answer(case: Case, text: str) -> str:
    """Every text field set to `text`, every boolean right: the strongest form of a soup."""
    return json.dumps({c["field"]: c["equals"] if isinstance(c.get("equals"), bool) else text
                       for c in case.grader["claims"]})


class CompactSoupTests(unittest.TestCase):
    """Item 1: soups that fit under the field cap, generic and case-aware."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = load_cases(load_eval("repo_traps"))

    def test_both_soups_fit_under_the_cap_and_carry_the_claim_keywords(self) -> None:
        generic = compact_soup(self.cases)
        self.assertLessEqual(len(generic), MAX_FIELD_CHARS)
        self.assertGreater(len(generic), MAX_FIELD_CHARS - 50)  # it fills the cap
        self.assertIn("not", generic.split(" ")[:5])  # the most widely used keyword leads
        for case in self.cases:
            soup = case_soup(case)
            self.assertLessEqual(len(soup), MAX_FIELD_CHARS, case.id)
            for claim in case.grader["claims"]:
                for word in claim_keywords(claim.get("must_match", "")):
                    self.assertIn(word, soup, f"{case.id}/{claim['id']}")

    def test_every_filler_is_paired_with_false_true_and_oracle_booleans(self) -> None:
        case = real_case("typed-array-ternary")
        made = trivial_answers(case, "full soup", "compact soup")
        self.assertEqual(ANSWERERS, set(made))
        self.assertEqual({"safe_to_ship": False, "fixed_code": case_soup(case)}, made["case_soup_oracle"])
        self.assertEqual({"safe_to_ship": True, "fixed_code": "compact soup"}, made["compact_soup_true"])
        self.assertEqual(case.prompt, made["echo_oracle"]["fixed_code"])

    def test_a_keyword_claim_is_caught_by_the_case_aware_soup(self) -> None:
        base = make_cases(1)[0]
        keyword = {"type": "claims", "claims": [
            {"id": "word", "field": "answer", "must_match": "tools/check_scripts\\.sh|stderr"}]}
        scores = trivial_answerer_scores([Case(**{**asdict(base), "grader": keyword})])
        self.assertEqual(1.0, scores["case_soup_false"])
        self.assertGreater(scores["max"], TRIVIAL_LIMIT)


class HitCountLimitTests(unittest.TestCase):
    """Item 3: one alternative a keyword list happens to contain does not complete a claim."""

    PATTERN = r"stderr|exit (code|status)|zero exit|exits 0|check_scripts\.sh|parse error|ignored|misleading"

    def claim_case(self, pattern: str = PATTERN) -> Case:
        grader = {"type": "claims", "claims": [{"id": "why", "field": "answer", "must_match": pattern}]}
        return Case(**{**asdict(make_cases(1)[0]), "grader": grader})

    def test_keywords_are_the_plain_text_runs_of_the_pattern(self) -> None:
        self.assertEqual(("check_scripts.sh", "code", "exit", "exits 0", "ignored", "misleading",
                          "parse error", "status", "stderr", "zero exit"), claim_keywords(self.PATTERN))
        self.assertEqual(("_hero.ward_hit(", "right", "vector2."),
                         claim_keywords(r"_hero\.ward_hit\(\s*Vector2\.(?:RIGHT)\s*\)"))
        # Whole words only: "stderrs" and "decode" name neither "stderr" nor "code".
        self.assertEqual({"stderr", "parse error"},
                         keyword_hits(self.PATTERN, "A parse error on STDERR; stderrs and a decode step aside."))

    def test_the_limit_is_five_or_three_quarters_of_the_keywords(self) -> None:
        self.assertEqual(5, hit_limit("a1x|b2x|c3x"))
        self.assertEqual(7, hit_limit(self.PATTERN))  # 10 keywords
        self.assertEqual(9, hit_limit("|".join(f"w{n}xx" for n in range(12))))

    def test_a_field_that_names_most_keywords_fails_though_its_regex_matches(self) -> None:
        case = self.claim_case()
        statement = "check-only exits 0 with the parse error on stderr, so the exit code is misleading"
        self.assertEqual(6, len(keyword_hits(self.PATTERN, statement)))
        self.assertEqual(1.0, grade_claims(case, json.dumps({"answer": statement})).score)
        listing = " ".join(claim_keywords(self.PATTERN))
        grade = grade_claims(case, json.dumps({"answer": listing}))
        self.assertEqual(0.0, grade.score)
        self.assertIn("keyword list", grade.verdicts[0].detail)
        self.assertIn("10 of its 10", grade.verdicts[0].detail)

    def test_a_real_claim_rejects_its_own_vocabulary_but_not_a_statement(self) -> None:
        case = real_case("funplay-32000")
        claim = next(c for c in case.grader["claims"] if c["id"] == "curl-or-listener")
        listed = check_claim(claim, {"first_check": case_soup(case)})
        self.assertFalse(listed.passed)
        self.assertIn("keyword list", listed.detail)
        self.assertTrue(check_claim(claim, {"first_check": "Curl the editor URL the relay points at."}).passed)


class KeywordListTests(unittest.TestCase):
    """Re-review blocking 1: keyword lists kept under the hit limit, and the strongest of them."""

    def claim(self, pattern: str) -> dict:
        return {"id": "c", "field": "answer", "must_match": pattern}

    def test_the_capped_list_is_the_first_keywords_up_to_the_hit_limit(self) -> None:
        words = [f"w{n}xx" for n in range(12)]  # 12 keywords, so the hit limit is 9
        self.assertEqual(" ".join(sorted(words)[:9]), capped_keywords(self.claim("|".join(words))))

    def test_the_keyword_run_searches_both_orders_shortest_first(self) -> None:
        self.assertEqual("exit code", keyword_run(self.claim(r"stderr|exit code")))
        self.assertEqual("zebra apple", keyword_run(self.claim(r"zebra\s+apple")))  # reverse order
        glued = self.claim(r"apple\s+is\s+zebra")  # "is" is glue no keyword list holds
        self.assertEqual(capped_keywords(glued), keyword_run(glued))
        self.assertFalse(check_claim(glued, {"answer": keyword_run(glued)}).passed)

    def test_no_keyword_list_satisfies_a_scored_claim(self) -> None:
        for case in load_cases(load_eval("repo_traps")):
            boolean = any(isinstance(c.get("equals"), bool) for c in case.grader["claims"])
            for claim in case.grader["claims"]:
                if "must_match" not in claim or not (boolean or claim.get("gate")):
                    continue
                for text in (keyword_run(claim), capped_keywords(claim)):
                    self.assertFalse(check_claim(claim, {claim["field"]: text}).passed,
                                     f"{case.id}/{claim['id']} accepts {text!r}")

    def test_one_word_no_longer_completes_a_claim(self) -> None:
        self.assertEqual(0.5, score("reviewer-hypothetical", measure_before_changing=True, first_step="rate"))
        self.assertEqual(0.5, score("dom-pile-keep-nodes", collapse_to_one_draw=False, reason="interactive"))
        self.assertEqual(1.0, score("dom-pile-keep-nodes", collapse_to_one_draw=False,
                                    reason="The chips are interactive: each needs its own input."))


class StructuralGateTests(unittest.TestCase):
    """Item 2: every case with no boolean has one structural claim that gates it."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = load_cases(load_eval("repo_traps"))

    def test_each_case_without_a_boolean_has_exactly_one_gate(self) -> None:
        gated = 0
        for case in self.cases:
            claims = case.grader["claims"]
            gates = [c["id"] for c in claims if c.get("gate")]
            has_boolean = any(isinstance(c.get("equals"), bool) for c in claims)
            self.assertEqual(0 if has_boolean else 1, len(gates), case.id)
            gated += len(gates)
        self.assertEqual(13, gated)

    def test_a_failed_gate_scores_the_case_zero_and_a_passed_one_keeps_partial_credit(self) -> None:
        case = "paired-calls-hit-player"
        self.assertTrue(is_decision_claim({"gate": True, "must_match": "x"}))
        wrong = score(case, missing_call="_hero.ward_hit(Vector2.LEFT)", reason="The blow comes from the right.")
        self.assertEqual(0.0, wrong)
        self.assertEqual(0.5, score(case, missing_call="_hero.ward_hit(Vector2.RIGHT)", reason="Mirror it."))

    def test_no_gate_is_satisfied_by_a_keyword_list_or_the_prompt(self) -> None:
        compact = compact_soup(self.cases)
        for case in self.cases:
            gate = next((c for c in case.grader["claims"] if c.get("gate")), None)
            if gate is None:
                continue
            for label, text in (("case soup", case_soup(case)), ("compact soup", compact),
                                ("echo", case.prompt)):
                grade = grade_claims(case, json.dumps({gate["field"]: text}))
                verdict = next(v for v in grade.verdicts if v.claim_id == gate["id"])
                self.assertFalse(verdict.passed, f"{case.id} gate passes the {label}")

    # Other correct forms each gate must accept, and wrong statements it must refuse.
    GATE_FORMS = {
        "typed-array-new-literal": ["var empty: Array[Card] = []", "HandPanel.new(hand, Array[Card]())"],
        "test-loop-over-suspect-container": ["assert(not LayoutBook.FORMS[form].is_empty())",
                                             "Make the test fail if the form's field list is empty.",
                                             "Check that the loop runs at least once."],
        "canary-pins-the-rule": ["The raw subscript should not equal LayoutBook.fields(built_key).",
                                 "raw is different from the trusted fields() output"],
        "borrowed-shader-const-markers": ["sh.code = EnemyView.with_tint(EnemyView.with_erode(src))",
                                          "sh.code = EnemyView.with_erode(EnemyView.BODY_SHADER)"],
        "half-size-times-scale": ["var start: Vector2 = from.get_center() - 0.5 * view.size"],
        "scaled-hit-area": ["44 x 44 pt", "44.0"],
        "paired-calls-hit-player": ["_hero.ward_hit(Vector2(1.0, 0.0))"],
        "shared-helper-blast-radius": ["Default 0.0, so the other finishes are untouched.", "It defaults to zero."],
        "language-switch-owner": ["It emits language_changed to Main and nothing else.", "It asks Main to switch.",
                                  "It does not set Locale.active itself."],
        "funplay-32000": ["Godot isn't running with the plugin enabled.", "Nothing is listening on that port.",
                          "The editor is down."],
        "shared-doc-landed-already": ["Drop my edit and keep the upstream entry.", "Nothing to add; link to it.",
                                      "Avoid a duplicate entry."],
    }
    WRONG_GATE_FORMS = {"funplay-32000": ["The editor is running.", "The MCP package is corrupt."],
                        "language-switch-owner": ["It sets Locale.active and re-hydrates ContentDB."],
                        "half-size-times-scale": ["view.size * 0.5 * born"]}

    def gate_passes(self, case_id: str, text: str) -> bool:
        case = real_case(case_id)
        gate = next(c for c in case.grader["claims"] if c.get("gate"))
        grade = grade_claims(case, json.dumps({gate["field"]: text}))
        return next(v.passed for v in grade.verdicts if v.claim_id == gate["id"])

    def test_each_gate_accepts_other_correct_forms_and_refuses_wrong_ones(self) -> None:
        for case_id, texts in self.GATE_FORMS.items():
            for text in texts:
                self.assertTrue(self.gate_passes(case_id, text), (case_id, text))
        for case_id, texts in self.WRONG_GATE_FORMS.items():
            for text in texts:
                self.assertFalse(self.gate_passes(case_id, text), (case_id, text))

    def test_a_gate_must_be_true_and_never_on_a_boolean(self) -> None:
        for bad in ({"id": "a", "field": "f", "equals": True, "gate": True},
                    {"id": "a", "field": "f", "must_match": "x", "gate": "yes"}):
            with self.assertRaises(EvalError):
                validate_grader_spec({"type": "claims", "claims": [bad]})
        validate_grader_spec({"type": "claims", "claims": [
            {"id": "a", "field": "f", "must_match": "x", "gate": True}]})


class TightenedClaimTests(unittest.TestCase):
    """Item 4: the four cases whose claims a keyword or a wrong answer used to satisfy."""

    def test_funplay_needs_the_statement_that_the_editor_is_not_running(self) -> None:
        case = "funplay-32000"
        for cause in ("editor plugin backend unreachable", "The editor config is corrupt."):
            self.assertEqual(0.0, score(case, first_check="Curl the editor URL.", likely_cause=cause), cause)
        self.assertEqual(1.0, score(case, first_check="Curl the editor URL the relay targets.",
                                    likely_cause="The Godot editor or its plugin is not running."))
        self.assertFalse(passed(case, first_check="editor plugin running", likely_cause="x")["curl-or-listener"])

    def test_canary_needs_raw_compared_with_the_trusted_output(self) -> None:
        case = "canary-pins-the-rule"
        for listing in ("raw differ fields() truth workaround", "differs from fields(); raw subscript"):
            self.assertEqual(0.0, score(case, assertion=listing, why="the rule"), listing)
        self.assertEqual(1.0, score(case, assertion="raw != LayoutBook.fields(built_key)",
                                    why="It pins the invariant the workaround needs."))

    def test_scaled_hit_area_needs_the_hit_rect_grown_and_draw_checked_for_size(self) -> None:
        case = "scaled-hit-area"
        wrong = passed(case, min_target_pt=44, change="Scale the picture up until the touch rect is 44 pt.",
                       check_first="size _draw")
        self.assertEqual({"floor": True, "grow-rect": False, "check-draw-reads-size": False}, wrong)
        right = passed(case, min_target_pt="44 pt", change="Pad the hit rect out to 44 pt around the drawing.",
                       check_first="Check whether _draw measures from size or from its own constants.")
        self.assertTrue(all(right.values()), right)

    def test_shared_doc_gates_on_not_landing_a_duplicate(self) -> None:
        case = "shared-doc-landed-already"
        for landed in ("skip", "follow-up", "duplicate land skip follow-up"):
            self.assertEqual(0.0, score(case, first_step="git fetch", if_already_landed=landed), landed)
        self.assertFalse(passed(case, first_step="origin/main", if_already_landed="x")["fetches-upstream"])
        self.assertEqual(1.0, score(case, first_step="git fetch, then read the file on origin/main.",
                                    if_already_landed="Do not add it again; note extra wording as a follow-up."))


class ReferenceAnswerTests(unittest.TestCase):
    """Acceptance: the grader credits every reference answer and every known correct answer."""

    CODE_RENDERINGS = {("typed-array-ternary", "fixed_code")}  # the reference states this fix in prose

    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = {c.id: c for c in load_cases(load_eval("repo_traps"))}
        cls.answers = answers()

    def test_every_case_has_a_reference_answer_taken_from_its_reference(self) -> None:
        self.assertEqual(set(self.cases), set(self.answers))
        for case_id, row in self.answers.items():
            self.assertLessEqual({c["field"] for c in self.cases[case_id].grader["claims"]}, set(row["reference"]))
            for field, value in row["reference"].items():
                if isinstance(value, str) and (case_id, field) not in self.CODE_RENDERINGS:
                    self.assertIn(value, self.cases[case_id].reference, f"{case_id}/{field}")

    def test_every_reference_answer_scores_full_marks(self) -> None:
        for case_id, row in self.answers.items():
            grade = grade_claims(self.cases[case_id], json.dumps(row["reference"]))
            self.assertEqual(1.0, grade.score, (case_id, [v for v in grade.verdicts if not v.passed]))

    def test_independent_answers_written_blind_to_the_grader_score_full_marks(self) -> None:
        header, body = (EVAL_DIR / "answers_independent.jsonl").read_text(encoding="utf-8").split("\n", 1)
        note = json.loads(header)
        self.assertIn("without sight of any grader", note["note"])
        # The writer's file, byte for byte: an edited answer changes the hash.
        self.assertEqual(note["sha256"], hashlib.sha256(body.encode("utf-8")).hexdigest())
        rows = [json.loads(line) for line in body.splitlines() if line.strip()]
        self.assertEqual({case_id: 2 for case_id in self.cases},
                         {case_id: sum(r["id"] == case_id for r in rows) for case_id in self.cases})
        for row in rows:
            grade = grade_claims(self.cases[row["id"]], json.dumps(row["answer"]))
            self.assertEqual(1.0, grade.score, (row["id"], [v for v in grade.verdicts if not v.passed]))

    def test_the_wordings_the_re_review_found_zeroed_score_full_marks(self) -> None:
        for case_id, field, text in REVIEW_WORDINGS:
            answer = {**self.answers[case_id]["reference"], field: text}
            grade = grade_claims(self.cases[case_id], json.dumps(answer))
            self.assertEqual(1.0, grade.score, (case_id, text, [v for v in grade.verdicts if not v.passed]))

    def test_correct_answers_in_other_words_score_full_marks(self) -> None:
        for case_id, row in self.answers.items():
            self.assertEqual(2, len(row["correct"]), case_id)
            for answer in row["correct"]:
                grade = grade_claims(self.cases[case_id], json.dumps(answer))
                self.assertEqual(1.0, grade.score, (case_id, [v for v in grade.verdicts if not v.passed]))


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

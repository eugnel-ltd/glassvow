#!/usr/bin/env python3
"""Tests for the repo_traps council changes: decision gate, trivial answerers, negation, delegation."""
from __future__ import annotations

import contextlib
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
from test_agent_evals import ROOT, make_cases  # noqa: E402

from agent_evals import approvals, cli  # noqa: E402
from agent_evals.diagnostics import (TRIVIAL_LIMIT, keyword_soup, trivial_answerer_scores,  # noqa: E402
                                     trivial_answers)
from agent_evals.evalspec import load_cases, load_eval  # noqa: E402
from agent_evals.graders import MAX_FIELD_CHARS, grade_claims, parse_json_answer  # noqa: E402
from agent_evals.models import Case, sha256_text  # noqa: E402

ANSWERERS = {"constant_false", "constant_true", "echo_false", "echo_true", "soup_false",
             "soup_true", "oracle_booleans", "empty"}


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
        healthy = {"cases_sha256": "h1", "status": "ok", "case_ids": ["c1"],
                   "diagnostics": {"infra": {"rate": 0.0}, "infra_threshold": 0.05,
                                   "trivial_answerers": {"max": 0.1, "limit": 0.25},
                                   "headroom_flagged": []}}
        live = trivial_answerer_scores(self.lenient())
        with self.assertRaisesRegex(approvals.ApprovalError, "too lenient"):
            approvals.check_run_eligible(healthy, "h1", ["c1"], live)
        approvals.check_run_eligible(healthy, "h1", ["c1"], self.scores)


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
        with self.assertRaises(approvals.ApprovalError):
            approvals.approve_grader(self.dir, "h1", ids, "run-1", sample[:-1], delegation=self.delegation())
        record = approvals.approve_grader(self.dir, "h1", ids, "run-1", sample, delegation=self.delegation())
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
        for extra in ([], ["--delegated", "someone"]):
            done = subprocess.run([sys.executable, script, "approve-inputs", "repo_traps", *extra],
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False)
            self.assertEqual(1, done.returncode, extra)
        self.assertFalse((ROOT / "tools/agent_evals/evals/repo_traps/approvals.json").exists())


if __name__ == "__main__":
    unittest.main()

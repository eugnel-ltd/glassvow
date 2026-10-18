#!/usr/bin/env python3
"""Source-audited DEVELOPMENT fixtures; never consume blind/calibration answers."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from agent_evals.evalspec import load_cases, load_eval  # noqa: E402
from agent_evals.graders import grade, is_decision_claim  # noqa: E402


class StructuredDecisionGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        spec = load_eval("repo_traps_structured")
        cls.cases = {case.id: case for case in load_cases(spec)}
        cls.answers = {row["id"]: row["answer"] for row in (
            json.loads(line) for line in
            (spec.directory / "development_answers.jsonl").read_text().splitlines())}
        cls.audit = [json.loads(line) for line in
                     (spec.directory / "decision_gate_audit.jsonl").read_text().splitlines()]

    def test_audit_covers_each_scored_field_once_with_source_and_reason(self) -> None:
        self.assertEqual(set(self.cases), {row["case_id"] for row in self.audit})
        self.assertEqual(80, len(self.audit))
        audited = []
        for row in self.audit:
            case = self.cases[row["case_id"]]
            self.assertEqual(case.source, row["source"])
            self.assertRegex(row["source_freeze"], r"\A[0-9a-f]{40}\Z")
            self.assertRegex(row["source_sha256"], r"\A[0-9a-f]{64}\Z")
            self.assertTrue(row["source_locator"])
            scored = {(claim["id"], claim["field"]) for claim in case.grader["claims"]
                      if not claim.get("report_only")}
            self.assertEqual(scored, {(claim["claim_id"], claim["field"])
                                      for claim in row["claims"]})
            for claim in row["claims"]:
                self.assertIs(type(claim["decision"]), bool)
                self.assertTrue(claim["why"].strip())
                audited.append((case.id, claim["claim_id"], claim["decision"]))
        self.assertEqual(138, len(audited))
        self.assertEqual(137, sum(decision for _, _, decision in audited))
        self.assertEqual([("funplay-32000", "likely-cause", False)],
                         [entry for entry in audited if not entry[2]])

    def wrong_value(self, case, claim, expected):
        """Use source-declared sibling choices, not post-score transform examples."""
        if "equals" not in claim:
            self.assertEqual("citation-form", claim["id"])
            return "``presentation/combat/enemy_view.gd`` (``_draw``)"
        match = re.search(r"\b" + re.escape(claim["field"])
                          + r": exactly one of (\[[^;\n]*\])", case.answer_format)
        self.assertIsNotNone(match, (case.id, claim["id"]))
        choices = json.loads(match.group(1))
        return next(value for value in choices
                    if type(value) is not type(expected) or value != expected)

    def test_every_required_selected_decision_caps_wrong_or_missing_output_at_zero(self) -> None:
        checked = 0
        for row in self.audit:
            case = self.cases[row["case_id"]]
            original = self.answers[case.id]
            self.assertEqual(1.0, grade(case, json.dumps(original)).score, case.id)
            claims = {claim["id"]: claim for claim in case.grader["claims"]}
            for audited in row["claims"]:
                if not audited["decision"]:
                    continue
                claim = claims[audited["claim_id"]]
                for mutation in ("wrong", "missing"):
                    with self.subTest(case=case.id, claim=claim["id"], mutation=mutation):
                        answer = copy.deepcopy(original)
                        if mutation == "missing":
                            del answer[claim["field"]]
                        else:
                            answer[claim["field"]] = self.wrong_value(
                                case, claim, answer[claim["field"]])
                        # Correct prose cannot rescue an erroneous selected decision.
                        result = grade(case, json.dumps(answer))
                        self.assertEqual(0.0, result.score, row["source"])
                        self.assertTrue(result.decision_failed)
                checked += 1
        self.assertEqual(137, checked)

    def test_optional_funplay_cause_does_not_override_the_correct_first_check(self) -> None:
        case = self.cases["funplay-32000"]
        cause = next(claim for claim in case.grader["claims"]
                     if claim["id"] == "likely-cause")
        self.assertFalse(is_decision_claim(cause))
        answer = copy.deepcopy(self.answers[case.id])
        answer["likely_cause"] = "wrong_export_template"
        result = grade(case, json.dumps(answer))
        self.assertGreater(result.score, 0.0)
        self.assertFalse(result.decision_failed)
        self.assertFalse(next(v for v in result.verdicts if v.claim_id == "likely-cause").passed)

    def test_font_offset_names_its_baseline_to_label_top_coordinate_relation(self) -> None:
        case = self.cases["label-box-from-font-metrics"]
        self.assertIn("intended glyph baseline NUM_BASELINE", case.prompt)
        self.assertIn("Label.position.y - NUM_BASELINE", case.answer_format)
        # Source example: ascent 13, descent 5, height 18, intended baseline 33.
        # The Label top is 20; subtracting descent or zero does not locate it.
        baseline, ascent, descent = 33, 13, 5
        for offset, top in ((-ascent, 20), (-descent, 28), (0, 33)):
            self.assertEqual(top, baseline + offset)
            self.assertEqual(offset == -ascent, top + ascent == baseline)


if __name__ == "__main__":
    unittest.main()

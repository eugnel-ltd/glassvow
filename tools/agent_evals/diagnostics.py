"""Diagnostics every baseline reports: headroom, model ordering and grader consistency."""
from __future__ import annotations

import json
from typing import Any, Mapping, Sequence

from .backends import Backend
from .graders import grade, grade_claims
from .models import MODEL_ALIASES, Case
from .stats import paired_difference_ci

HEADROOM_LIMIT = 0.95


def headroom_warnings(model_means: Mapping[str, float]) -> list[str]:
    return [f"{model} scores {score:.1%}: above {HEADROOM_LIMIT:.0%}, so the eval has no "
            "headroom for it; add harder cases before trusting differences"
            for model, score in model_means.items() if score > HEADROOM_LIMIT]


def ordering_warnings(case_means: Mapping[str, Mapping[str, float]],
                      order: Sequence[str] = MODEL_ALIASES) -> list[str]:
    """Warn when a weaker model beats a stronger one beyond the paired 95% bootstrap CI."""
    present = [model for model in order if model in case_means]
    warnings = []
    for weaker_at, weaker in enumerate(present):
        for stronger in present[weaker_at + 1:]:
            mean_gap, low, _ = paired_difference_ci(case_means[weaker], case_means[stronger])
            if low > 0:
                warnings.append(f"{weaker} beats the stronger {stronger} by {mean_gap:.1%} "
                                "beyond noise; suspect the grader or the cases")
    return warnings


def grader_consistency(cases: Sequence[Case], transcripts: Sequence[Mapping[str, Any]],
                       judge: Backend | None = None, judge_model: str = "haiku") -> dict[str, Any]:
    """Grade every stored output twice; programmatic grades must be identical."""
    by_id = {case.id: case for case in cases}
    programmatic_mismatches = judge_flips = judge_verdicts = 0
    for item in transcripts:
        case = by_id[item["case_id"]]
        first = grade(case, item["output"], judge, judge_model)
        second = grade(case, item["output"], judge, judge_model)
        if case.grader["type"] == "claims":
            programmatic_mismatches += first != second
        else:
            judge_verdicts += len(first.verdicts)
            judge_flips += sum(a.passed != b.passed for a, b in zip(first.verdicts, second.verdicts))
    return {
        "programmatic_identical": programmatic_mismatches == 0,
        "programmatic_mismatches": programmatic_mismatches,
        "judge_disagreement_rate": judge_flips / judge_verdicts if judge_verdicts else None,
    }


TRIVIAL_LIMIT = 0.25


def _boolean_fields(case: Case) -> set[str]:
    return {c["field"] for c in case.grader["claims"] if isinstance(c.get("equals"), bool)}


def trivial_answers(case: Case) -> dict[str, dict[str, Any]]:
    """Answers that need no understanding: a constant, and an echo of the prompt."""
    booleans = _boolean_fields(case)
    fields = {c["field"] for c in case.grader["claims"]}
    answers = {}
    for flag in (False, True):
        constant = {f: (flag if f in booleans else "") for f in fields}
        echo = {f: (flag if f in booleans else case.prompt) for f in fields}
        answers[f"constant_{str(flag).lower()}"] = constant
        answers[f"echo_{str(flag).lower()}"] = echo
    return answers


def trivial_answerer_scores(cases: Sequence[Case]) -> dict[str, Any]:
    """Mean score of each trivial answerer through the real grader; no model is called."""
    graded = [c for c in cases if c.grader["type"] == "claims"]
    totals: dict[str, list[float]] = {}
    for case in graded:
        for name, answer in trivial_answers(case).items():
            totals.setdefault(name, []).append(grade_claims(case, json.dumps(answer)).score)
    scores = {name: sum(v) / len(v) for name, v in totals.items()} if graded else {}
    return {**scores, "max": max(scores.values(), default=0.0), "limit": TRIVIAL_LIMIT}

"""Diagnostics every baseline reports: headroom, model ordering and grader consistency."""
from __future__ import annotations

from typing import Any, Mapping, Sequence

from .backends import Backend
from .graders import grade
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

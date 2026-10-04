"""Diagnostics every baseline reports: headroom, model ordering and grader consistency."""
from __future__ import annotations

import json
import re
from collections import Counter
from typing import Any, Mapping, Sequence

from .backends import Backend
from .graders import MAX_FIELD_CHARS, claim_keywords, grade, grade_claims
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
REFERENCE_TOKEN = re.compile(r"[\w./()\[\]=-]+")
PATTERN_WORD = re.compile(r"[A-Za-z_]\w{2,}")
BOOLEAN_MODES = ("false", "true", "oracle")


def _boolean_fields(case: Case) -> dict[str, bool]:
    return {c["field"]: c["equals"] for c in case.grader["claims"] if isinstance(c.get("equals"), bool)}


def _fit(words: Sequence[str], limit: int = MAX_FIELD_CHARS) -> str:
    """Join words with spaces, stopping before the text would pass the field cap."""
    kept: list[str] = []
    for word in words:
        if len(" ".join(kept + [word])) > limit:
            break
        kept.append(word)
    return " ".join(kept)


def keyword_soup(cases: Sequence[Case]) -> str:
    """One fixed list of domain words from every case's reference and keyword claims."""
    words: set[str] = set()
    for case in cases:
        words.update(REFERENCE_TOKEN.findall(case.reference))
        for claim in case.grader["claims"]:
            words.update(PATTERN_WORD.findall(claim.get("must_match", "")))
    return " ".join(sorted(words, key=str.casefold))


def compact_soup(cases: Sequence[Case]) -> str:
    """A generic soup under the cap: the claim keywords most claims use, most widely used first."""
    uses = Counter(word for case in cases for claim in case.grader["claims"]
                   for word in claim_keywords(claim.get("must_match", "")))
    return _fit(sorted(uses, key=lambda word: (-uses[word], word)))


def case_soup(case: Case) -> str:
    """A case-aware soup under the cap: every keyword of this case's claims, sorted."""
    keywords = {word for claim in case.grader["claims"]
                for word in claim_keywords(claim.get("must_match", ""))}
    return _fit(sorted(keywords))


def _flag(correct: bool, mode: str) -> bool:
    return correct if mode == "oracle" else mode == "true"


def trivial_answers(case: Case, soup: str = "", compact: str = "") -> dict[str, dict[str, Any]]:
    """Answers that need no understanding: every text filler with every boolean mode.

    Text fillers: empty text (constant), the case prompt (echo), the full soup, the compact
    generic soup and this case's soup. Boolean modes: all false, all true and the correct
    values (oracle). Constant text with oracle booleans keeps its old name, oracle_booleans.
    """
    booleans = _boolean_fields(case)
    fields = {c["field"] for c in case.grader["claims"]}
    fillers = {"constant": "", "echo": case.prompt, "soup": soup, "compact_soup": compact,
               "case_soup": case_soup(case)}
    answers: dict[str, dict[str, Any]] = {"empty": {}}
    for filler, text in fillers.items():
        for mode in BOOLEAN_MODES:
            name = "oracle_booleans" if (filler, mode) == ("constant", "oracle") else f"{filler}_{mode}"
            answers[name] = {f: (_flag(booleans[f], mode) if f in booleans else text) for f in fields}
    return answers


def trivial_answerer_scores(cases: Sequence[Case]) -> dict[str, Any]:
    """Mean score of each trivial answerer through the real grader; no model is called."""
    graded = [c for c in cases if c.grader["type"] == "claims"]
    soup, compact = keyword_soup(graded), compact_soup(graded)
    totals: dict[str, list[float]] = {}
    for case in graded:
        for name, answer in trivial_answers(case, soup, compact).items():
            totals.setdefault(name, []).append(grade_claims(case, json.dumps(answer)).score)
    scores = {name: sum(v) / len(v) for name, v in totals.items()} if graded else {}
    return {**scores, "max": max(scores.values(), default=0.0), "limit": TRIVIAL_LIMIT}

"""Graders: programmatic claim checks first, a blind yes/no judge only when needed."""
from __future__ import annotations

import json
import re
from functools import lru_cache
from typing import Any

from .backends import Backend
from .models import Case, EvalError, Grade, Verdict

CLAIM_KEYS = ("must_match", "must_not_match", "equals")
MAX_FIELD_CHARS = 1000  # answer fields are a sentence or a code line; more is a keyword dump
MIN_HIT_LIMIT = 5  # a field may always name this many of a claim's keywords (see hit_limit)
HIT_SHARE = 3 / 4  # or this share of them, when that is more
REGEX_FLAGS = re.IGNORECASE | re.DOTALL
# One token of a pattern: a literal character (or escaped punctuation), else regex syntax.
REGEX_TOKEN = re.compile(r"(?P<literal>\\[^A-Za-z0-9]|[^\\\[{(|)?*+.^$])|\\.|\[(?:\\.|[^\]\\])*\]"
                         r"|\{\d*,?\d*\}|\(\?(?:P<\w+>|<[=!]|[:=!]|[a-zA-Z]+\))|.", re.DOTALL)
JUDGE_SYSTEM = (
    "You grade one answer against a list of checkable yes/no claims. Judge each claim "
    "independently from the answer text alone. Reply with only a JSON object of the "
    'form {"verdicts": {"<claim id>": true or false}}.')


def validate_grader_spec(spec: dict[str, Any]) -> None:
    """Raise EvalError unless the grader spec is well formed."""
    kind = spec.get("type")
    claims = spec.get("claims")
    if kind not in ("claims", "judge"):
        raise EvalError(f"unknown grader type {kind!r}")
    if not isinstance(claims, list) or not claims:
        raise EvalError("grader needs a non-empty claims list")
    seen: set[str] = set()
    for claim in claims:
        claim_id = claim.get("id")
        if not claim_id or claim_id in seen:
            raise EvalError(f"claim id missing or duplicated: {claim_id!r}")
        seen.add(claim_id)
        if kind == "judge":
            if not claim.get("question"):
                raise EvalError(f"judge claim {claim_id!r} needs a yes/no question")
            continue
        if not claim.get("field"):
            raise EvalError(f"claim {claim_id!r} needs a field")
        if not any(key in claim for key in CLAIM_KEYS):
            raise EvalError(f"claim {claim_id!r} needs one of {CLAIM_KEYS}")
        if "gate" in claim and (claim["gate"] is not True or isinstance(claim.get("equals"), bool)):
            raise EvalError(f"claim {claim_id!r}: gate must be true, on a claim that is not a boolean")
        for key in ("must_match", "must_not_match"):
            if key in claim:
                try:
                    re.compile(claim[key])
                except re.error as error:
                    raise EvalError(f"claim {claim_id!r} has a bad regex: {error}") from error


def is_decision_claim(claim: dict[str, Any]) -> bool:
    """A claim that carries the case's call; failing it caps the whole case at 0.

    That is a boolean decision (`equals` true or false) or, in a case with no boolean, the
    structural claim marked `"gate": true`, which a keyword list cannot satisfy.
    """
    return isinstance(claim.get("equals"), bool) or claim.get("gate") is True


@lru_cache(maxsize=None)
def claim_keywords(pattern: str) -> tuple[str, ...]:
    """The keywords of a pattern: its runs of plain text between regex syntax.

    Escaped punctuation is plain text (`check_scripts\\.sh` gives `check_scripts.sh`); runs are
    case-folded, and runs shorter than three characters are dropped.
    """
    runs, run = [], ""
    for token in REGEX_TOKEN.finditer(pattern):
        if token.group("literal") is None:
            runs.append(run)
            run = ""
        else:
            run += token.group("literal")[-1]
    runs.append(run)
    return tuple(sorted({text.strip().casefold() for text in runs if len(text.strip()) >= 3}))


def _whole(keyword: str) -> str:
    """A regex for the keyword as whole words: no word character may extend it at either end."""
    head = r"(?<!\w)" if re.match(r"\w", keyword) else ""
    tail = r"(?!\w)" if re.search(r"\w$", keyword) else ""
    return head + re.escape(keyword) + tail


def keyword_hits(pattern: str, text: str) -> set[str]:
    """The pattern's keywords that the text names, each as whole words, ignoring case."""
    return {word for word in claim_keywords(pattern) if re.search(_whole(word), text, re.IGNORECASE)}


def hit_limit(pattern: str) -> int:
    """How many of its keywords one field may name: five, or three quarters of them if more.

    A statement names one alternative per slot, so even a thorough one names few of a claim's
    synonyms; a field that names nearly all of them is listing the claim's vocabulary, and the
    one alternative it happens to contain does not complete the claim.
    """
    return max(MIN_HIT_LIMIT, int(len(claim_keywords(pattern)) * HIT_SHARE))


def _unwrap(value: dict[str, Any]) -> dict[str, Any]:
    """Unwrap a single-key nested object such as {"answer": {...}}."""
    while len(value) == 1 and isinstance(next(iter(value.values())), dict):
        value = next(iter(value.values()))
    return value


def parse_json_answer(text: str) -> dict[str, Any]:
    """Extract the first JSON object from a reply (bare, fenced or embedded)."""
    decoder = json.JSONDecoder()
    for start in (match.start() for match in re.finditer(r"\{", text)):
        try:
            value, _ = decoder.raw_decode(text, start)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            return value
    raise ValueError("no JSON object found in the reply")


def _field_text(value: Any) -> str:
    return value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)


def _equals(value: Any, expected: Any) -> bool:
    if isinstance(expected, bool) and isinstance(value, str):
        return value.strip().casefold() == str(expected).casefold()
    if isinstance(value, str) and isinstance(expected, str):
        return value.strip().casefold() == expected.strip().casefold()
    return value == expected


def _check_claim(claim: dict[str, Any], answer: dict[str, Any]) -> Verdict:
    claim_id = claim["id"]
    if claim["field"] not in answer:
        return Verdict(claim_id, False, f"field {claim['field']!r} missing")
    value = answer[claim["field"]]
    text = _field_text(value)
    if len(text) > MAX_FIELD_CHARS:
        return Verdict(claim_id, False, f"field {claim['field']!r} is over {MAX_FIELD_CHARS} characters")
    if "must_match" in claim:
        pattern = claim["must_match"]
        if not re.search(pattern, text, REGEX_FLAGS):
            return Verdict(claim_id, False, f"does not match /{pattern}/")
        hits, limit = keyword_hits(pattern, text), hit_limit(pattern)
        if len(hits) > limit:
            return Verdict(claim_id, False, f"names {len(hits)} of its {len(claim_keywords(pattern))} "
                           f"keywords, over {limit}: a keyword list, not a statement")
    if "must_not_match" in claim and re.search(claim["must_not_match"], text, REGEX_FLAGS):
        return Verdict(claim_id, False, f"matches forbidden /{claim['must_not_match']}/")
    if "equals" in claim and not _equals(value, claim["equals"]):
        return Verdict(claim_id, False, f"is not {claim['equals']!r}")
    return Verdict(claim_id, True)


def grade_claims(case: Case, output: str) -> Grade:
    """Deterministic grader: the same output always yields the same grade.

    Decision gate: a wrong boolean decision, or a failed gate claim, scores the case 0, so a
    coin-flip boolean or a keyword list cannot carry partial credit; a right call with weak
    reasoning keeps partial credit.
    """
    claims = case.grader["claims"]
    try:
        answer = _unwrap(parse_json_answer(output))
    except ValueError as error:
        return Grade(tuple(Verdict(c["id"], False, "unparseable reply") for c in claims),
                     parse_error=str(error))
    verdicts = tuple(_check_claim(claim, answer) for claim in claims)
    decision_failed = any(is_decision_claim(claim) and not verdict.passed
                          for claim, verdict in zip(claims, verdicts))
    return Grade(verdicts, decision_failed=decision_failed)


def judge_prompt(case: Case, output: str) -> str:
    """The judge sees the task, the answer and the claims, never a condition label."""
    lines = [f"Task given to the answerer:\n{case.user_prompt()}", "",
             f"Answer to grade:\n{output}", "", "Claims:"]
    lines += [f"- {claim['id']}: {claim['question']}" for claim in case.grader["claims"]]
    return "\n".join(lines)


def grade_judge(case: Case, output: str, backend: Backend, model: str,
                timeout_s: float = 120.0) -> Grade:
    claims = case.grader["claims"]
    reply = backend.complete(JUDGE_SYSTEM, judge_prompt(case, output), model, timeout_s)
    if reply.infra_failed:
        return Grade(tuple(Verdict(c["id"], False, "judge failed") for c in claims),
                     parse_error=reply.error or "judge timed out or truncated")
    try:
        verdicts = parse_json_answer(reply.text).get("verdicts", {})
    except ValueError as error:
        return Grade(tuple(Verdict(c["id"], False, "judge reply unparseable") for c in claims),
                     parse_error=str(error))
    return Grade(tuple(Verdict(c["id"], verdicts.get(c["id"]) is True) for c in claims))


def grade(case: Case, output: str, judge: Backend | None = None,
          judge_model: str = "haiku") -> Grade:
    if case.grader["type"] == "claims":
        return grade_claims(case, output)
    if judge is None:
        raise EvalError(f"case {case.id!r} needs a judge backend")
    return grade_judge(case, output, judge, judge_model)

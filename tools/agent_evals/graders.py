"""Graders: programmatic claim checks first, a blind yes/no judge only when needed."""
from __future__ import annotations

import json
import re
from typing import Any

from .backends import Backend
from .models import Case, EvalError, Grade, Verdict

CLAIM_KEYS = ("must_match", "must_not_match", "equals")
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
        for key in ("must_match", "must_not_match"):
            if key in claim:
                try:
                    re.compile(claim[key])
                except re.error as error:
                    raise EvalError(f"claim {claim_id!r} has a bad regex: {error}") from error


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
    flags = re.IGNORECASE | re.DOTALL
    if "must_match" in claim and not re.search(claim["must_match"], text, flags):
        return Verdict(claim_id, False, f"does not match /{claim['must_match']}/")
    if "must_not_match" in claim and re.search(claim["must_not_match"], text, flags):
        return Verdict(claim_id, False, f"matches forbidden /{claim['must_not_match']}/")
    if "equals" in claim and not _equals(value, claim["equals"]):
        return Verdict(claim_id, False, f"is not {claim['equals']!r}")
    return Verdict(claim_id, True)


def grade_claims(case: Case, output: str) -> Grade:
    """Deterministic grader: the same output always yields the same grade."""
    claims = case.grader["claims"]
    try:
        answer = parse_json_answer(output)
    except ValueError as error:
        return Grade(tuple(Verdict(c["id"], False, "unparseable reply") for c in claims),
                     parse_error=str(error))
    return Grade(tuple(_check_claim(claim, answer) for claim in claims))


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

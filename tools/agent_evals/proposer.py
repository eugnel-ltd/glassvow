"""Proposer prompts. Built from train data only, with a structural leak guard."""
from __future__ import annotations

import re
from typing import Any, Mapping, Sequence

from .graders import parse_json_answer
from .models import Case, EvalError
from .patching import DEFAULT_MIN_SPAN, find_shared_span

MAX_FAILURES_SHOWN = 12

PROPOSER_SYSTEM = """You improve one agent-instruction file (the surface) so an agent \
using it makes the right call on a set of hidden situations. You see only the surface and \
transcripts from a training set.

Rules:
- Find the ROOT CAUSE of the failures: a section that misleads or a rule that is missing. \
Rewrite that section or add the missing rule. Do not merely reword a line.
- Propose exactly ONE targeted patch, as a unified diff against the surface text shown.
- State general rules and the reason for them. Never copy a situation, a command output or \
an expected answer from the transcripts into the surface: a patch that does is rejected.
- Reply with only a JSON object: {"root_cause": "...", "patch": "<unified diff>", \
"expected_effect": "..."}."""

REFLECTION_SYSTEM = """You review a stalled hill-climbing run on one agent-instruction file. \
Do not edit the surface. Write a short Markdown analysis covering: ambiguous cases, harness \
errors, run-to-run variance and grader flaws, then what to change before running again."""

GOAL_TEXT = {
    "accuracy": "Goal: raise the share of correct decisions.",
    "cost-at-parity": "Goal: make the surface cheaper (fewer tokens) with no loss of accuracy.",
}


class LeakError(EvalError):
    """A proposer prompt contained test-set data."""


def _failing(train_cases: Sequence[Case], transcripts: Sequence[Mapping[str, Any]]):
    by_id = {case.id: case for case in train_cases}
    failing = [t for t in transcripts if t["grade"]["score"] < 1.0]
    failing.sort(key=lambda t: (t["grade"]["score"], t["id"]))
    return [(by_id[t["case_id"]], t) for t in failing[:MAX_FAILURES_SHOWN]]


def _transcript_block(case: Case, item: Mapping[str, Any]) -> str:
    failed = [v for v in item["grade"]["verdicts"] if not v["passed"]]
    notes = "; ".join(f"{v['claim']} ({v['detail']})" for v in failed) or "none"
    return (f"### {case.id} (score {item['grade']['score']:.0%})\n"
            f"Situation:\n{item['prompt']}\n\nAgent reply:\n{item['output'][:2000]}\n\n"
            f"Intended answer: {case.reference}\nFailed claims: {notes}\n")


def _history_lines(history: Sequence[Mapping[str, str]]) -> str:
    if not history:
        return "No earlier rounds."
    return "\n".join(f"- round {h['round']}: {h['root_cause']} -> {h['outcome']}" for h in history)


def build_proposer_prompt(surface_text: str, train_cases: Sequence[Case],
                          train_transcripts: Sequence[Mapping[str, Any]], goal: str,
                          history: Sequence[Mapping[str, str]] = ()) -> str:
    """The only function that assembles the proposer's prompt; its inputs are train data."""
    scores = "\n".join(
        f"- {t['id']}: {t['grade']['score']:.0%}" for t in sorted(train_transcripts, key=lambda t: t["id"]))
    failures = "\n".join(_transcript_block(case, item)
                         for case, item in _failing(train_cases, train_transcripts))
    return (f"{GOAL_TEXT[goal]}\n\n## Surface\n<<<SURFACE\n{surface_text}\nSURFACE>>>\n\n"
            f"## Training scores\n{scores}\n\n## Failing training transcripts\n"
            f"{failures or 'None: every training case passed.'}\n\n"
            f"## Earlier rounds\n{_history_lines(history)}\n")


def build_reflection_prompt(surface_text: str, train_cases: Sequence[Case],
                            train_transcripts: Sequence[Mapping[str, Any]],
                            train_noise: float, unstable_case_ids: Sequence[str],
                            history: Sequence[Mapping[str, str]], why: str) -> str:
    return (f"The run stopped because: {why}\n\n"
            f"Training noise floor: {train_noise:.3f}. Training cases whose score varied "
            f"between repetitions: {', '.join(unstable_case_ids) or 'none'}.\n\n"
            + build_proposer_prompt(surface_text, train_cases, train_transcripts, "accuracy", history))


def assert_no_test_leak(prompt: str, surface_text: str, test_cases: Sequence[Case],
                        min_chars: int = DEFAULT_MIN_SPAN) -> None:
    """Raise LeakError if a test case id, input or expected answer appears in the prompt."""
    body = prompt.replace(surface_text, "")
    for case in test_cases:
        if re.search(rf"(?<![\w-]){re.escape(case.id)}(?![\w-])", body):
            raise LeakError(f"test case id {case.id!r} appears in the proposer prompt")
        shared = find_shared_span(body, [case.prompt, case.reference], min_chars)
        if shared:
            raise LeakError(f"text of test case {case.id!r} appears in the proposer prompt: {shared!r}")


def parse_proposal(text: str) -> dict[str, str]:
    """Extract {root_cause, patch, expected_effect}; raise EvalError when unusable."""
    try:
        data = parse_json_answer(text)
    except ValueError as error:
        raise EvalError(f"proposal is not JSON: {error}") from error
    missing = [key for key in ("root_cause", "patch", "expected_effect")
               if not isinstance(data.get(key), str) or not data[key].strip()]
    if missing:
        raise EvalError(f"proposal lacks {missing}")
    return {key: data[key] for key in ("root_cause", "patch", "expected_effect")}

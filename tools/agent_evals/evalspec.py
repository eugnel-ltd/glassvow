"""Load an eval directory (eval.json + cases.jsonl) and validate its cases."""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

from .graders import validate_grader_spec
from .patching import DEFAULT_MIN_SPAN, find_shared_span
from .models import (BUILD_ROOT, EVALS_DIR, REPO_ROOT, Case, EvalError, case_from_json,
                     read_json, sha256_file)

REFERENCE_PATTERN = re.compile(r"^(?:#\d+|PR #\d+|issue #\d+)$")


@dataclass(frozen=True)
class EvalSpec:
    name: str
    directory: Path
    surface: Path
    grader_type: str
    default_models: tuple[str, ...]
    hillclimb_model: str
    judge_model: str

    @property
    def cases_path(self) -> Path:
        return self.directory / "cases.jsonl"

    @property
    def cases_sha256(self) -> str:
        return sha256_file(self.cases_path)

    @property
    def build_dir(self) -> Path:
        return BUILD_ROOT / self.name


def load_eval(name: str, evals_dir: Path = EVALS_DIR, repo_root: Path = REPO_ROOT) -> EvalSpec:
    directory = evals_dir / name
    config_path = directory / "eval.json"
    if not config_path.exists():
        raise EvalError(f"no eval named {name!r} under {evals_dir}")
    raw = read_json(config_path)
    return EvalSpec(
        name=name, directory=directory, surface=repo_root / raw["surface"],
        grader_type=raw["grader_type"], default_models=tuple(raw["default_models"]),
        hillclimb_model=raw.get("hillclimb_model", raw["default_models"][0]),
        judge_model=raw.get("judge_model", "haiku"))


def load_cases(spec: EvalSpec) -> list[Case]:
    cases = []
    for number, line in enumerate(spec.cases_path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            cases.append(case_from_json(json.loads(line)))
        except json.JSONDecodeError as error:
            raise EvalError(f"cases.jsonl line {number} is not JSON: {error}") from error
    return cases


def validate_cases(cases: list[Case], repo_root: Path = REPO_ROOT) -> list[str]:
    """Return every problem found; an empty list means the cases are valid."""
    problems: list[str] = []
    seen: set[str] = set()
    for case in cases:
        if case.id in seen:
            problems.append(f"duplicate case id {case.id!r}")
        seen.add(case.id)
        if not REFERENCE_PATTERN.match(case.source) and not (repo_root / case.source).is_file():
            problems.append(f"{case.id}: source {case.source!r} is neither a repo file nor an issue/PR ref")
        if not case.why_hard.strip():
            problems.append(f"{case.id}: why_hard is empty")
        try:
            validate_grader_spec(case.grader)
        except EvalError as error:
            problems.append(f"{case.id}: {error}")
    problems += _shared_span_problems(cases)
    return problems


def _shared_span_problems(cases: list[Case]) -> list[str]:
    """Cases must not share long verbatim text, or the leak guard could not tell them apart."""
    problems = []
    for index, case in enumerate(cases):
        others = [text for other in cases[index + 1:] for text in (other.prompt, other.reference)]
        span = find_shared_span(case.prompt + "\n" + case.reference, others, DEFAULT_MIN_SPAN) if others else None
        if span:
            problems.append(f"{case.id}: shares a verbatim span with a later case: {span!r}")
    return problems


def require_valid(cases: list[Case]) -> None:
    problems = validate_cases(cases)
    if problems:
        raise EvalError("invalid cases:\n  " + "\n  ".join(problems))

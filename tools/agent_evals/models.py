"""Plain data types and small helpers shared by the harness modules."""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

EVALS_DIR = Path(__file__).resolve().parent / "evals"
REPO_ROOT = Path(__file__).resolve().parents[2]
BUILD_ROOT = REPO_ROOT / "build" / "agent_evals"
MODEL_ALIASES = ("haiku", "sonnet", "opus")  # weakest to strongest; never pin ids


class EvalError(ValueError):
    """An eval definition or run is malformed."""


@dataclass(frozen=True)
class Completion:
    """One backend reply. `error` is set for any infrastructure failure."""

    text: str = ""
    error: str | None = None
    timed_out: bool = False
    truncated: bool = False
    usage: dict[str, Any] = field(default_factory=dict)

    @property
    def infra_failed(self) -> bool:
        return bool(self.error) or self.timed_out or self.truncated


@dataclass(frozen=True)
class Case:
    id: str
    source: str
    why_hard: str
    prompt: str
    reference: str
    grader: dict[str, Any]
    answer_format: str = ""

    def user_prompt(self) -> str:
        """The exact text the model under test sees as the user turn."""
        return self.prompt + ("\n\n" + self.answer_format if self.answer_format else "")


@dataclass(frozen=True)
class Verdict:
    claim_id: str
    passed: bool
    detail: str = ""


@dataclass(frozen=True)
class Grade:
    verdicts: tuple[Verdict, ...]
    parse_error: str | None = None

    @property
    def score(self) -> float:
        if not self.verdicts:
            return 0.0
        return sum(v.passed for v in self.verdicts) / len(self.verdicts)

    @property
    def passed(self) -> bool:
        return bool(self.verdicts) and all(v.passed for v in self.verdicts)

    def to_json(self) -> dict[str, Any]:
        return {
            "score": self.score,
            "passed": self.passed,
            "parse_error": self.parse_error,
            "verdicts": [
                {"claim": v.claim_id, "passed": v.passed, "detail": v.detail}
                for v in self.verdicts],
        }


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalise_space(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip().casefold()


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
                    encoding="utf-8")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def case_from_json(raw: dict[str, Any]) -> Case:
    missing = [key for key in ("id", "source", "why_hard", "prompt", "reference", "grader")
               if not raw.get(key)]
    if missing:
        raise EvalError(f"case {raw.get('id', '?')!r} lacks required field(s): {missing}")
    return Case(
        id=raw["id"], source=raw["source"], why_hard=raw["why_hard"],
        prompt=raw["prompt"], reference=raw["reference"], grader=raw["grader"],
        answer_format=raw.get("answer_format", ""))

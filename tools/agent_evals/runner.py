"""Run cases against a backend, grade them and write one transcript per case x repetition."""
from __future__ import annotations

import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Sequence

from .backends import Backend
from .graders import grade
from .models import Case, Completion, EvalError, sha256_text, write_json

DEFAULT_TIMEOUT_S = 180.0
DEFAULT_INFRA_THRESHOLD = 0.05


class InfraFailure(EvalError):
    """Too many timeouts, API errors or truncated outputs for the scores to mean anything."""


@dataclass
class SetResult:
    """Graded transcripts of one surface on one set of cases."""

    transcripts: list[dict[str, Any]]

    def table(self, key: str = "score") -> dict[str, list[float]]:
        """case id -> value of `key` per repetition, in repetition order."""
        rows: dict[str, list[tuple[int, float]]] = {}
        for item in self.transcripts:
            value = item["grade"]["score"] if key == "score" else item[key]
            rows.setdefault(item["case_id"], []).append((item["rep"], value))
        return {case_id: [value for _, value in sorted(pairs)] for case_id, pairs in rows.items()}

    def infra(self) -> dict[str, Any]:
        return infra_summary(self.transcripts)


def transcript_id(case_id: str, rep: int) -> str:
    return f"{case_id}__r{rep}"


def estimate_tokens(text: str) -> int:
    return max(1, len(text) // 4)


def call_cost_tokens(system: str, prompt: str, completion: Completion) -> int:
    """Measured input plus output tokens, else a four-characters-per-token estimate."""
    usage = completion.usage
    if "input_tokens" in usage and "output_tokens" in usage:
        extra = usage.get("cache_creation_input_tokens", 0) + usage.get("cache_read_input_tokens", 0)
        return int(usage["input_tokens"] + usage["output_tokens"] + extra)
    return estimate_tokens(system) + estimate_tokens(prompt) + estimate_tokens(completion.text)


def run_case(backend: Backend, case: Case, rep: int, model: str, surface_text: str,
             eval_name: str = "", judge: Backend | None = None, judge_model: str = "haiku",
             timeout_s: float = DEFAULT_TIMEOUT_S) -> dict[str, Any]:
    prompt = case.user_prompt()
    started = time.monotonic()
    completion = backend.complete(surface_text, prompt, model, timeout_s)
    elapsed = time.monotonic() - started
    result = grade(case, completion.text, judge, judge_model)
    return {
        "id": transcript_id(case.id, rep), "eval": eval_name, "case_id": case.id, "rep": rep,
        "model": model, "surface_sha256": sha256_text(surface_text), "prompt": prompt,
        "output": completion.text, "grade": result.to_json(),
        "error": completion.error, "timed_out": completion.timed_out,
        "truncated": completion.truncated, "elapsed_s": round(elapsed, 3),
        "usage": completion.usage, "cost_tokens": call_cost_tokens(surface_text, prompt, completion),
        "backend": backend.describe(),
    }


def run_set(backend: Backend, cases: Sequence[Case], model: str, surface_text: str,
            reps: int, out_dir: Path | None = None, eval_name: str = "",
            judge: Backend | None = None, judge_model: str = "haiku",
            timeout_s: float = DEFAULT_TIMEOUT_S, workers: int = 1,
            first_rep: int = 1) -> SetResult:
    """Run every case `reps` times; write each transcript to `out_dir` when given."""
    jobs = [(case, rep) for rep in range(first_rep, first_rep + reps) for case in cases]

    def execute(job: tuple[Case, int]) -> dict[str, Any]:
        case, rep = job
        item = run_case(backend, case, rep, model, surface_text, eval_name, judge,
                        judge_model, timeout_s)
        if out_dir is not None:
            write_json(out_dir / f"{item['id']}.json", item)
        return item

    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        return SetResult(list(pool.map(execute, jobs)))


def infra_summary(transcripts: Sequence[dict[str, Any]]) -> dict[str, Any]:
    total = len(transcripts)
    errors = sum(1 for t in transcripts if t["error"] and not t["timed_out"])
    timeouts = sum(1 for t in transcripts if t["timed_out"])
    truncated = sum(1 for t in transcripts if t["truncated"] and not t["error"])
    failed = sum(1 for t in transcripts if t["error"] or t["timed_out"] or t["truncated"])
    return {"total": total, "errors": errors, "timeouts": timeouts, "truncated": truncated,
            "failed": failed, "rate": failed / total if total else 0.0}


def check_infra(summary: dict[str, Any], threshold: float = DEFAULT_INFRA_THRESHOLD) -> None:
    if summary["rate"] > threshold:
        raise InfraFailure(
            f"infrastructure failure rate {summary['rate']:.1%} exceeds {threshold:.1%} "
            f"({summary['errors']} errors, {summary['timeouts']} timeouts, "
            f"{summary['truncated']} truncated of {summary['total']})")

"""The baseline run: every case x repetition x model, plus the diagnostics."""
from __future__ import annotations

from pathlib import Path
from typing import Any, Sequence

from .backends import Backend
from .diagnostics import grader_consistency, headroom_warnings, ordering_warnings
from .evalspec import EvalSpec
from .models import Case, sha256_text, write_json
from .report import results_html
from .runner import (DEFAULT_INFRA_THRESHOLD, DEFAULT_TIMEOUT_S, infra_summary, run_set)
from .stats import noise_floor, per_case_means, score_summary


def _model_block(model: str, transcripts: list[dict[str, Any]],
                 table: dict[str, list[float]]) -> dict[str, Any]:
    by_case: dict[str, list[dict[str, Any]]] = {}
    for item in transcripts:
        by_case.setdefault(item["case_id"], []).append(item)
    per_case = {}
    for case_id, items in sorted(by_case.items()):
        items.sort(key=lambda item: item["rep"])
        per_case[case_id] = {
            "mean": sum(i["grade"]["score"] for i in items) / len(items),
            "scores": [i["grade"]["score"] for i in items],
            "transcripts": [f"transcripts/{model}/{i['id']}.json" for i in items]}
    reps = min(len(scores) for scores in table.values())
    return {"summary": score_summary(table), "per_case": per_case,
            "noise": noise_floor(table) if reps >= 2 else None,
            "infra": infra_summary(transcripts)}


def run_baseline(spec: EvalSpec, cases: Sequence[Case], backend: Backend,
                 models: Sequence[str], reps: int, run_dir: Path,
                 judge: Backend | None = None, timeout_s: float = DEFAULT_TIMEOUT_S,
                 infra_threshold: float = DEFAULT_INFRA_THRESHOLD, workers: int = 1,
                 run_id: str = "") -> dict[str, Any]:
    """Run the baseline, write transcripts, results.json and results.html, return results."""
    surface_text = spec.surface.read_text(encoding="utf-8")
    all_transcripts: list[dict[str, Any]] = []
    model_blocks: dict[str, Any] = {}
    tables: dict[str, dict[str, list[float]]] = {}
    for model in models:
        result = run_set(backend, cases, model, surface_text, reps,
                         run_dir / "transcripts" / model, spec.name, judge, spec.judge_model,
                         timeout_s, workers)
        all_transcripts += result.transcripts
        tables[model] = result.table()
        model_blocks[model] = _model_block(model, result.transcripts, tables[model])
    infra = infra_summary(all_transcripts)
    warnings = headroom_warnings({m: b["summary"]["mean"] for m, b in model_blocks.items()})
    warnings += ordering_warnings({m: per_case_means(t) for m, t in tables.items()})
    if infra["rate"] > infra_threshold:
        warnings.append(f"infrastructure failure rate {infra['rate']:.1%} exceeds "
                        f"{infra_threshold:.1%}; the run is invalid")
    results = {
        "eval": spec.name, "run_id": run_id, "status": "failed" if infra["rate"] > infra_threshold else "ok",
        "surface_sha256": sha256_text(surface_text), "cases_sha256": spec.cases_sha256,
        "reps": reps, "backend": backend.describe(), "models": model_blocks,
        "diagnostics": {"infra": infra, "infra_threshold": infra_threshold,
                        "grader_consistency": grader_consistency(
                            cases, all_transcripts, judge, spec.judge_model)},
        "warnings": warnings,
    }
    write_json(run_dir / "results.json", results)
    (run_dir / "results.html").write_text(results_html(spec.name, results), encoding="utf-8")
    return results


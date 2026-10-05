"""Human checkpoints: recorded approvals bound to the sha256 of the cases."""
from __future__ import annotations

import getpass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence, TextIO

from .models import EvalError, read_json, sha256_file, sha256_text, write_json

SAMPLE_SIZE = 5
APPROVALS_FILE = "approvals.json"


class ApprovalError(EvalError):
    """A required human approval is missing or stale."""


def _load(eval_dir: Path) -> dict:
    path = eval_dir / APPROVALS_FILE
    return read_json(path) if path.exists() else {}


def _record(eval_dir: Path, kind: str, cases_sha256: str, **extra: object) -> dict:
    approvals = _load(eval_dir)
    approvals[kind] = {
        "by": getpass.getuser(), "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "cases_sha256": cases_sha256, **extra}
    write_json(eval_dir / APPROVALS_FILE, approvals)
    return approvals[kind]


def delegation_record(delegated_by: str, evidence: Path) -> dict:
    """The extra fields of an approval an orchestrator gives on an owner's explicit delegation."""
    if not delegated_by.strip():
        raise ApprovalError("--delegated needs the text: who delegated, when and why")
    if not evidence.is_file():
        raise ApprovalError(f"--evidence {evidence} is not a file")
    return {"by": "orchestrator", "delegated_by": delegated_by.strip(),
            "evidence": {"path": str(evidence), "sha256": sha256_file(evidence)}}


def approve_inputs(eval_dir: Path, cases_sha256: str, delegation: Mapping[str, Any] | None = None) -> dict:
    return _record(eval_dir, "inputs", cases_sha256, **(delegation or {}))


def sample_transcript_ids(transcript_ids: Sequence[str], seed: str,
                          size: int = SAMPLE_SIZE) -> list[str]:
    """A deterministic sample the approver must open before the grader is approved."""
    ranked = sorted(transcript_ids, key=lambda tid: sha256_text(f"{seed}:{tid}"))
    return sorted(ranked[:size])


def require_tty(stream: TextIO) -> None:
    """Approvals are human acts: refuse unless the input is an interactive terminal."""
    if not stream.isatty():
        raise ApprovalError("approvals need an interactive terminal (stdin is not a TTY)")


def check_run_eligible(results: Mapping[str, Any], cases_sha256: str, surface_sha256: str,
                       case_ids: Sequence[str], trivial_fingerprint: str | None = None,
                       judge_needed: bool = False) -> None:
    """The run behind a grader approval must be a complete, healthy, isolated run of the current
    cases and surface, with its trivial answerers scored on the current frozen answer set and,
    when the eval has judge claims, one known judge model throughout."""
    diagnostics = results.get("diagnostics", {})
    backend = results.get("backend") or {}
    problems = []
    if results.get("cases_sha256") != cases_sha256:
        problems.append("the run was made on different cases (stale cases_sha256)")
    if results.get("surface_sha256") != surface_sha256:
        problems.append("the run was made on a different surface (stale surface_sha256)")
    if not backend:
        problems.append("the run records no backend, so its isolation is unknown")
    elif backend.get("isolation") == "ambient" or backend.get("allow_ambient"):
        problems.append("the run was made with --allow-ambient-context, so CLAUDE.md, memory and "
                        "settings may have reached the model")
    if results.get("status") != "ok":
        problems.append(f"the run status is {results.get('status')!r}, not 'ok'")
    if set(results.get("case_ids", [])) != set(case_ids):
        problems.append("the run does not cover every case (an --only smoke run?)")
    if diagnostics.get("infra", {}).get("rate", 1.0) > diagnostics.get("infra_threshold", 0.05):
        problems.append("the infrastructure failure rate is above its threshold")
    stored = diagnostics.get("trivial_answerers", {})
    if stored.get("max", 1.0) > stored.get("limit", 0.25):
        problems.append(f"a trivial answerer scores {stored.get('max', 1.0):.1%}, above "
                        f"{stored.get('limit', 0.25):.0%}: the grader is too lenient")
    if stored.get("oracle_margin", 1.0) > stored.get("oracle_margin_limit", 0.02):
        problems.append(f"a trivial answerer beats the correct booleans alone by "
                        f"{stored.get('oracle_margin', 1.0):.1%}, more than "
                        f"{stored.get('oracle_margin_limit', 0.02):.0%}: the grader is too lenient")
    if stored.get("judge_errors", 0):
        problems.append(f"the judge failed on {stored['judge_errors']} trivial answers, so that "
                        "check is incomplete")
    # Rescoring through the judge would cost calls, so a stale answer set is refused instead.
    if trivial_fingerprint is not None and stored.get("fingerprint") != trivial_fingerprint:
        problems.append("the trivial answerers were scored on another answer set; run `baseline` again")
    judge = results.get("judge") or {}
    if judge_needed and not (judge.get("model") and judge.get("model_id") and judge.get("arm")):
        problems.append(f"the judge model id or arm is unknown, or the id changed during the run "
                        f"({judge.get('model_ids', [])})")
    if problems:
        raise ApprovalError("this run cannot back a grader approval: " + "; ".join(problems))


def approve_grader(eval_dir: Path, cases_sha256: str, surface_sha256: str,
                   transcript_ids: Sequence[str], seed: str, read: Sequence[str],
                   results: Mapping[str, Any] | None, case_ids: Sequence[str],
                   delegation: Mapping[str, Any] | None = None,
                   trivial_fingerprint: str | None = None, judge_needed: bool = False) -> dict:
    """Record grader approval only for a healthy full run and if every sampled transcript was read.

    The record is bound to the cases, the surface and the judge model (alias and resolved id)
    the run used, and names the models it ran.
    """
    if results is None:
        raise ApprovalError("no baseline results to check; run `baseline` first")
    check_run_eligible(results, cases_sha256, surface_sha256, case_ids, trivial_fingerprint,
                       judge_needed)
    if not transcript_ids:
        raise ApprovalError("no scored transcripts to sample; run `baseline` first")
    required = sample_transcript_ids(transcript_ids, seed)
    unread = sorted(set(required) - set(read))
    if unread:
        raise ApprovalError(f"open these transcripts, then pass them via --read: {unread}")
    flagged = results.get("diagnostics", {}).get("headroom_flagged", [])
    judge = results.get("judge") or {}
    return _record(eval_dir, "grader", cases_sha256, surface_sha256=surface_sha256,
                   read=sorted(required), run=seed, models=sorted(results.get("models", {})),
                   headroom_flagged=flagged, judge_model=judge.get("model", ""),
                   judge_arm=judge.get("arm", ""),
                   judge_model_id=judge.get("model_id", ""), **(delegation or {}))


COMMANDS = {"inputs": "approve-inputs", "grader": "approve-grader"}


def require_approvals(eval_dir: Path, cases_sha256: str, surface_sha256: str, model: str,
                      allow_no_headroom: bool = False, judge_model: str = "",
                      judge_arm: str = "") -> dict:
    """Both approvals must match the current cases; the grader's must match the surface, the judge
    alias and the judge arm too, and its baseline must have run the model being climbed with
    headroom left.

    Returns the grader approval, whose `judge_model_id` the climb then holds every judge call to.
    """
    approvals = _load(eval_dir)
    for kind, command in COMMANDS.items():
        entry = approvals.get(kind)
        if entry is None:
            raise ApprovalError(f"the {kind} are not approved; run `{command}`")
        if entry["cases_sha256"] != cases_sha256:
            raise ApprovalError(f"the {kind} approval is stale: cases.jsonl changed since it was given")
    grader = approvals["grader"]
    if grader.get("surface_sha256") != surface_sha256:
        raise ApprovalError("the grader approval is stale: the surface changed since its baseline "
                            "ran; run `baseline` and `approve-grader` again")
    if model not in grader.get("models", []):
        raise ApprovalError(f"the approved baseline did not run {model!r}, so its headroom is "
                            "unknown; run `baseline` with that model")
    if model in grader.get("headroom_flagged", []) and not allow_no_headroom:
        raise ApprovalError(f"the approved baseline had no headroom for {model} (above 95%); "
                            "pass --allow-no-headroom to climb it anyway")
    if (grader.get("judge_model", ""), grader.get("judge_arm", "")) != (judge_model, judge_arm):
        raise ApprovalError(f"the grader was approved with judge {grader.get('judge_model', '')!r} "
                            f"(arm {grader.get('judge_arm', '')!r}), not {judge_model!r} (arm "
                            f"{judge_arm!r}); recalibrate and approve the grader again")
    return grader

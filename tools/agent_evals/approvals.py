"""Human checkpoints: recorded approvals bound to the sha256 of the cases."""
from __future__ import annotations

import getpass
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

from .models import EvalError, read_json, sha256_text, write_json

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


def approve_inputs(eval_dir: Path, cases_sha256: str) -> dict:
    return _record(eval_dir, "inputs", cases_sha256)


def sample_transcript_ids(transcript_ids: Sequence[str], seed: str,
                          size: int = SAMPLE_SIZE) -> list[str]:
    """A deterministic sample the approver must open before the grader is approved."""
    ranked = sorted(transcript_ids, key=lambda tid: sha256_text(f"{seed}:{tid}"))
    return sorted(ranked[:size])


def approve_grader(eval_dir: Path, cases_sha256: str, transcript_ids: Sequence[str],
                   seed: str, read: Sequence[str]) -> dict:
    """Record grader approval only if every sampled transcript was reported as read."""
    if not transcript_ids:
        raise ApprovalError("no scored transcripts to sample; run `baseline` first")
    required = sample_transcript_ids(transcript_ids, seed)
    unread = sorted(set(required) - set(read))
    if unread:
        raise ApprovalError(f"open these transcripts, then pass them via --read: {unread}")
    return _record(eval_dir, "grader", cases_sha256, read=sorted(required))


COMMANDS = {"inputs": "approve-inputs", "grader": "approve-grader"}


def require_approvals(eval_dir: Path, cases_sha256: str) -> None:
    approvals = _load(eval_dir)
    for kind, command in COMMANDS.items():
        entry = approvals.get(kind)
        if entry is None:
            raise ApprovalError(f"the {kind} are not approved; run `{command}`")
        if entry["cases_sha256"] != cases_sha256:
            raise ApprovalError(f"the {kind} approval is stale: cases.jsonl changed since it was given")

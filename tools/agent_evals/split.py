"""Deterministic, seeded, disjoint train/test split of the cases."""
from __future__ import annotations

from pathlib import Path
from typing import Sequence

from .models import EvalError, read_json, sha256_text, write_json

DEFAULT_SEED = "agent-evals-1"
DEFAULT_TRAIN_FRACTION = 0.6


def make_split(case_ids: Sequence[str], seed: str = DEFAULT_SEED,
               train_fraction: float = DEFAULT_TRAIN_FRACTION) -> dict[str, list[str]]:
    """Rank cases by sha256(seed:id) and cut; the same inputs always give the same split."""
    ranked = sorted(case_ids, key=lambda case_id: sha256_text(f"{seed}:{case_id}"))
    cut = round(len(ranked) * train_fraction)
    return {"train": sorted(ranked[:cut]), "test": sorted(ranked[cut:])}


def write_split(path: Path, case_ids: Sequence[str], cases_sha256: str,
                seed: str = DEFAULT_SEED, train_fraction: float = DEFAULT_TRAIN_FRACTION) -> dict:
    split = make_split(case_ids, seed, train_fraction)
    payload = {"seed": seed, "train_fraction": train_fraction,
               "cases_sha256": cases_sha256, **split}
    write_json(path, payload)
    return payload


def load_split(path: Path, case_ids: Sequence[str], cases_sha256: str) -> dict:
    """Load split.json and refuse a stale or inconsistent one."""
    if not path.exists():
        raise EvalError("split.json is missing; run `init` first")
    split = read_json(path)
    if split["cases_sha256"] != cases_sha256:
        raise EvalError("split.json is stale: the cases changed since `init`")
    train, test = set(split["train"]), set(split["test"])
    if train & test or (train | test) != set(case_ids):
        raise EvalError("split.json is not a disjoint partition of the cases")
    return split

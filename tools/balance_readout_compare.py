"""Compare two run directories run for run: the proof that a re-run reproduces an earlier readout.

Every run row (outcome, deck, fights, flame, rng and all) of every report both directories
hold is compared for equality, seed by seed. Manifests are compared separately and reported:
the commit may legitimately differ, content, tools and instrument should not.
"""
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from pathlib import Path

import balance_readout_run as run


@dataclass
class ReportComparison:
    name: str
    rows: int = 0
    identical: int = 0
    differing: list[tuple[int, list[str]]] = field(default_factory=list)  # (seed, differing fields)
    missing: list[int] = field(default_factory=list)
    manifest_differences: list[str] = field(default_factory=list)


def digest_rows(rows: list[dict]) -> str:
    """A digest of a report's run rows, independent of key order and of the manifest."""
    return hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def read_report(directory: Path, name: str) -> dict:
    """A directory's merged report, or the merge of its chunks when no merged file was kept."""
    path = directory / f"{name}.json"
    if path.is_file():
        return run._read(path)
    parts = sorted((directory / "parts").glob(f"{name}-[0-9]*.json"))
    parts = [p for p in parts if not p.name.endswith(run.SIDECAR)]
    if not parts:
        raise ValueError(f"{directory}: no report or chunks named {name}")
    return run.merge_report(name, parts)


def report_names(directory: Path) -> set[str]:
    names = {p.stem for p in directory.glob("v*-*.json") if not p.name.endswith(run.SIDECAR)}
    parts = directory / "parts"
    if parts.is_dir():
        names |= {p.stem.rsplit("-", 1)[0] for p in parts.glob("v*-*.json") if not p.name.endswith(run.SIDECAR)}
    return names


def compare_report(name: str, a: dict, b: dict) -> ReportComparison:
    result = ReportComparison(name)
    other = {row["seed"]: row for row in b["runs"]}
    for row in a["runs"]:
        result.rows += 1
        twin = other.pop(row["seed"], None)
        if twin is None:
            result.missing.append(row["seed"])
        elif row == twin:
            result.identical += 1
        else:
            result.differing.append((row["seed"], sorted(k for k in row.keys() | twin.keys() if row.get(k) != twin.get(k))))
    result.missing += sorted(other)
    ca, cb = run.manifest_core(a["manifest"]), run.manifest_core(b["manifest"])
    result.manifest_differences = sorted(k for k in ca.keys() | cb.keys() if ca.get(k) != cb.get(k))
    return result


def compare_directories(a: Path, b: Path, names: list[str] | None = None) -> list[ReportComparison]:
    shared = sorted(report_names(a) & report_names(b)) if names is None else names
    if not shared:
        raise ValueError("the two directories hold no report in common")
    return [compare_report(name, read_report(a, name), read_report(b, name)) for name in shared]


def render(results: list[ReportComparison]) -> str:
    lines = ["| Report | Rows | Identical | Different | Missing | Manifest differences |", "|---|---:|---:|---:|---:|---|"]
    for r in results:
        lines.append(f"| {r.name} | {r.rows} | {r.identical} | {len(r.differing)} | {len(r.missing)} | "
                     f"{', '.join(r.manifest_differences) or 'none'} |")
    rows, same = sum(r.rows for r in results), sum(r.identical for r in results)
    lines += ["", f"{len(results)} reports, {rows} rows compared, {same} identical, "
                  f"{sum(len(r.differing) for r in results)} different, {sum(len(r.missing) for r in results)} missing."]
    for r in results:
        for seed, keys in r.differing[:5]:
            lines.append(f"- {r.name} seed {seed} differs in: {', '.join(keys)}")
    return "\n".join(lines)


def identical(results: list[ReportComparison]) -> bool:
    return all(r.rows == r.identical and not r.missing for r in results)

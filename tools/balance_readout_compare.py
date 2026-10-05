"""Compare two run directories run for run: the proof that a re-run reproduces an earlier readout.

`compare`: every run row (outcome, deck, fights, flame, rng and all) of every report both
directories hold is compared for equality, seed by seed. Manifests are compared separately and
reported: the commit may legitimately differ, content, tools and instrument should not.

`equivalence`: docs/rc-bar.md P9's content equivalence for the class. A candidate whose content
SHA-256 differs from the reading of record's plays the reading's cell table again, and every run
must match the reading's on the graded fields (`balance_ways.GRADED_FIELDS`), with each replay
still identical to its arm-A run (G7). Every report of either directory is read, so a run or a
report one side lacks is missing, and the manifests must name the same instrument (the bots, the
player, the Godot version, the cell and arm, and the arm's `policy`, its way weights among them).
Given `commit`, every report of the candidate's directory must name that commit, the RC commit the
exam binds. Any other field that differs is listed with the number of runs it differs in, for the
exam packet to explain.
"""
from __future__ import annotations

import hashlib
import json
import re
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import balance_readout_run as run
import balance_ways as bw

# What a manifest names of the instrument and the cell: equivalence needs them all identical. `policy` is the
# arm's resolved policy, its way weights (`wayCommit`, `wayOff`) among them.
INSTRUMENT = ("aspect", "vow", "pool", "way", "build", "play", "pilot", "search", "godot", "policy")
FULL_SHA = re.compile(r"[0-9a-f]{40}")
# G7's replay reads whole rows: for a replay run, whether it is identical to arm A's run on its seed.
REPLAY_FIELD = "replay identical to arm A"
_ABSENT = object()  # what `project` returns where a row has no such field


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


# ---------------------------------------------------------------- content equivalence

def project(row: Any, path: str) -> Any:
    """The value at a field path of a row: a dot descends into an object, `[]` maps over a list."""
    parts = path.split(".")
    node = row
    for i, part in enumerate(parts):
        many = part.endswith("[]")
        node = node.get(part[:-2] if many else part, _ABSENT) if isinstance(node, dict) else _ABSENT
        if node is _ABSENT or (many and not isinstance(node, list)):
            return _ABSENT
        if many:
            rest = ".".join(parts[i + 1:])
            return [project(item, rest) if rest else item for item in node]
    return node


def field_paths(node: Any, prefix: str = "") -> set[str]:
    """Every leaf field of a row in `project`'s notation; a list of scalars, or an empty object or list,
    is a leaf."""
    if isinstance(node, dict) and node:
        paths: set[str] = set()
        for key, value in node.items():
            paths |= field_paths(value, f"{prefix}.{key}" if prefix else key)
        return paths
    if isinstance(node, list) and node and all(isinstance(item, dict) for item in node):
        return set().union(*(field_paths(item, prefix + "[]") for item in node))
    return {prefix}


def _same_run(row: dict, other: dict | None) -> bool:
    """Whole-row identity, exactly as the grader's G7 replay check reads it."""
    return json.dumps(row, sort_keys=True) == json.dumps(other, sort_keys=True)


def _replay_agreement(directory: Path, name: str, rows: list[dict]) -> dict[int, bool]:
    """For a replay report, whether each run is identical to arm A's run on its seed in the same directory."""
    try:
        arm_a = {row["seed"]: row for row in read_report(directory, name[:-len("replay")] + "A")["runs"]}
    except ValueError:
        arm_a = {}
    return {row["seed"]: _same_run(row, arm_a.get(row["seed"])) for row in rows}


@dataclass
class ReportEquivalence:
    name: str
    new_runs: int = 0
    reference_runs: int = 0
    paired: int = 0
    graded: list[tuple[int, list[str]]] = field(default_factory=list)  # (seed, graded fields that differ)
    other: Counter = field(default_factory=Counter)  # any other field -> the runs it differs in
    missing_new: list[int] = field(default_factory=list)  # seeds only the reference holds
    missing_reference: list[int] = field(default_factory=list)  # seeds only the new directory holds
    instrument: list[tuple[str, Any, Any]] = field(default_factory=list)  # (key, new, reference)
    manifest: list[str] = field(default_factory=list)  # other manifest keys that differ
    commit: Any = None  # the commit the new report's manifest names


@dataclass
class Equivalence:
    new: Path
    reference: Path
    fields: tuple[str, ...]
    reports: list[ReportEquivalence]
    named: dict[str, Any]  # the reference's instrument, as its first report names it
    commit: str | None = None  # the commit every report of the candidate must name (`--commit`), if given

    @property
    def graded_identical(self) -> bool:
        return not any(r.graded for r in self.reports)

    @property
    def same_runs(self) -> bool:
        return not any(r.missing_new or r.missing_reference for r in self.reports)

    @property
    def same_instrument(self) -> bool:
        return not any(r.instrument for r in self.reports)

    @property
    def other_commits(self) -> list[tuple[str, Any]]:
        """(report, commit) for every report of the candidate that names another commit than `--commit`."""
        if self.commit is None:
            return []
        return [(r.name, r.commit) for r in self.reports if r.new_runs and r.commit != self.commit]

    @property
    def equivalent(self) -> bool:
        return self.graded_identical and self.same_runs and self.same_instrument and not self.other_commits


def report_equivalence(name: str, new: dict | None, reference: dict | None, fields: tuple[str, ...],
                       new_dir: Path, reference_dir: Path) -> ReportEquivalence:
    """One report's runs paired by seed: graded fields, other fields, missing runs and the manifests."""
    result = ReportEquivalence(name)
    rows, twins = (new or {}).get("runs", []), {row["seed"]: row for row in (reference or {}).get("runs", [])}
    result.new_runs, result.reference_runs = len(rows), len(twins)
    replay = name.endswith("-replay")
    agree = _replay_agreement(new_dir, name, rows) if replay else {}
    agree_reference = _replay_agreement(reference_dir, name, list(twins.values())) if replay else {}
    for row in rows:
        seed, twin = row["seed"], twins.pop(row["seed"], None)
        if twin is None:
            result.missing_reference.append(seed)
            continue
        result.paired += 1
        graded = [REPLAY_FIELD] if replay and agree[seed] != agree_reference[seed] else []
        if row != twin:
            graded = [path for path in fields if project(row, path) != project(twin, path)] + graded
            result.other.update(path for path in field_paths(row) | field_paths(twin)
                                if path not in fields and project(row, path) != project(twin, path))
        if graded:
            result.graded.append((seed, graded))
    result.missing_new = sorted(twins)
    if new is not None:
        result.commit = new["manifest"].get("commit")
    if new is not None and reference is not None:
        mine, theirs = run.manifest_core(new["manifest"]), run.manifest_core(reference["manifest"])
        for key in sorted(mine.keys() | theirs.keys()):
            if mine.get(key) != theirs.get(key):
                if key in INSTRUMENT:
                    result.instrument.append((key, mine.get(key), theirs.get(key)))
                else:
                    result.manifest.append(key)
    return result


def equivalence(new: Path, reference: Path, who: bw.Roster, commit: str | None = None) -> Equivalence:
    """Every report of either directory, run for run, on the class's graded fields; given `commit` (a full SHA),
    every report of `new` must name it."""
    if commit is not None and not FULL_SHA.fullmatch(commit):
        raise ValueError(f"--commit must be a full 40-character SHA (git rev-parse <commit>), got {commit!r}")
    for directory in (new, reference):
        if not directory.is_dir():
            raise ValueError(f"{directory} is not a directory")
    have_new, have_reference = report_names(new), report_names(reference)
    if not have_new | have_reference:
        raise ValueError("neither directory holds a report")
    fields, reports, named = bw.graded_fields(who), [], {}
    for name in sorted(have_new | have_reference):
        mine = read_report(new, name) if name in have_new else None
        theirs = read_report(reference, name) if name in have_reference else None
        if theirs is not None and not named:
            named = {key: theirs["manifest"].get(key) for key in ("pilot", "search", "play", "godot")}
        reports.append(report_equivalence(name, mine, theirs, fields, new, reference))
    return Equivalence(new, reference, fields, reports, named, commit)


def _seed_spans(seeds: list[int]) -> str:
    spans: list[list[int]] = []
    for seed in sorted(seeds):
        if spans and seed == spans[-1][1] + 1:
            spans[-1][1] = seed
        else:
            spans.append([seed, seed])
    return ", ".join(str(a) if a == b else f"{a}–{b}" for a, b in spans)


def render_equivalence(result: Equivalence) -> str:
    def yes(ok: bool) -> str:
        return "yes" if ok else "no"

    reports = result.reports
    paired, graded = sum(r.paired for r in reports), sum(len(r.graded) for r in reports)
    lines = [f"Content equivalence for the class: `{result.new}` against the reading of record `{result.reference}`.",
             "", "Graded fields: " + ", ".join(result.fields) + f"; and, for a replay run, {REPLAY_FIELD}.", "",
             "| Report | Runs (new / reference) | Paired | Differ on a graded field | Missing in new | "
             "Missing in reference | Instrument |", "|---|---|---:|---:|---:|---:|---|"]
    lines += [f"| {r.name} | {r.new_runs} / {r.reference_runs} | {r.paired} | {len(r.graded)} | {len(r.missing_new)} | "
              f"{len(r.missing_reference)} | {'differs' if r.instrument else 'same'} |" for r in reports]
    named = ", ".join(f"{key} {value.get('version') if isinstance(value, dict) else value}"
                      for key, value in result.named.items())
    lines += ["", f"- Identical on all graded fields: {yes(result.graded_identical)} "
                  f"({graded} of {paired} paired runs differ on a graded field).",
              f"- The same runs on both sides: {yes(result.same_runs)}.",
              f"- The same instrument as the reading of record ({named}): {yes(result.same_instrument)}."]
    if result.commit is not None:
        lines.append(f"- Every report of the candidate names commit `{result.commit}`: "
                     f"{yes(not result.other_commits)}.")
    lines.append(f"- Equivalent for the class: {yes(result.equivalent)}.")
    if result.other_commits:
        lines += ["", "Reports of the candidate that name another commit:"]
        lines += [f"- {name}: {commit!r}" for name, commit in result.other_commits]
    lines += ["", "Runs that differ on a graded field:" + ("" if graded else " none.")]
    lines += [f"- {r.name} seed {seed}: {', '.join(fields)}" for r in reports for seed, fields in r.graded]
    other = sum((r.other for r in reports), Counter())
    lines += ["", "Other fields that differ (the exam packet names the commit that caused each):"
              + ("" if other else " none.")]
    if other:
        lines += ["", "| Field | Runs |", "|---|---:|"]
        lines += [f"| {key} | {count} |" for key, count in sorted(other.items())]
    missing = [(r.name, side, seeds) for r in reports
               for side, seeds in (("new", r.missing_new), ("the reference", r.missing_reference)) if seeds]
    lines += ["", "Runs missing:" + ("" if missing else " none.")]
    lines += [f"- {name}, missing in {side}: seeds {_seed_spans(seeds)} ({len(seeds)})" for name, side, seeds in missing]
    lines += ["", "Instrument differences:" + ("" if not result.same_instrument else " none.")]
    lines += [f"- {r.name}: {key} {mine!r} in new against {theirs!r} in the reference"
              for r in reports for key, mine, theirs in r.instrument]
    keys = Counter(key for r in reports for key in r.manifest)
    listed = ", ".join(f"{key} ({count} reports)" for key, count in sorted(keys.items()))
    lines += ["", f"Other manifest differences: {listed or 'none'}."]
    return "\n".join(lines)

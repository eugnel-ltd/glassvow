"""Chunked, resumable, parallel readout runs and the merge of their chunks.

A readout cell table is cells x arms x a seed band. Each (cell, arm) is split into seed
chunks that run in parallel, each chunk being one `balance_ways.sim_command`. Next to every
chunk's report (`parts/<report>-<first seed>.json`) the runner writes a sidecar manifest
(`.chunk.json`) with the cell, arm, seeds, command and the digests of the content file, the
simulator sources and the game rules under `domain/`. A chunk with a valid sidecar is never run
again, so an interrupted run resumes; a chunk whose sidecar names different content, tools or
rules, or a different command (play, weights, chunking; the report path aside), is refused,
never reused.

`merge_parts` joins chunks into one report per cell and arm, in seed order, and refuses
unless every chunk carries the same simulator manifest (content, tools, pilot, search
version, policy, commit and so on; only the seeds differ) and the seeds join without a
gap or overlap. `join_bands` does the same across directories for a longer seed band.
"""
from __future__ import annotations

import hashlib
import json
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

import balance_ways as bw
from balance_exam import REPO, run_command
from balance_readout_guard import require_isolated_user_dir

CONTENT = Path("content/full-content.json")
# The simulator and its bots: any change to these makes a chunk a different instrument.
TOOL_SOURCES = tuple(Path("tools") / name for name in (
    "balance_sim.gd", "balance_search.gd", "balance_pilot.gd", "balance_policy.gd", "balance_metrics.gd"))
# The game rules the simulator runs: an edit here is a different instrument too.
DOMAIN = Path("domain")
SIDECAR = ".chunk.json"
Runner = Callable[[list[str], Path], int]


@dataclass(frozen=True)
class Chunk:
    report: str  # merged report name without ".json"
    cell: str  # "v0-fresh"
    arm: str
    first: int
    count: int
    part: Path
    command: list[str]

    @property
    def sidecar(self) -> Path:
        return self.part.with_name(self.part.stem + SIDECAR)

    @property
    def log(self) -> Path:
        return self.part.with_suffix(".log")


def parse_cell(cell: str) -> tuple[int, str]:
    """`v0-fresh` -> (0, "fresh"); anything outside the grader's vows and pools is an error."""
    head, sep, pool = cell.partition("-")
    if not sep or not head.startswith("v") or not head[1:].isdigit() or int(head[1:]) not in bw.VOWS \
            or pool not in bw.POOLS:
        raise ValueError(f"cell must be v<vow>-<pool> with vow in {bw.VOWS} and pool in {bw.POOLS}, got {cell!r}")
    return int(head[1:]), pool


def plan(out: Path, seeds: tuple[int, int], cells: list[str], arms: list[str], play: str = "greedy",
         chunk: int = 50, replay: bool = False, content: Path | None = None,
         weights: tuple[float, float] | None = None, godot: str = "godot") -> list[Chunk]:
    """Every chunk of the table, in cell, arm, seed order (replays after their cell's arms)."""
    if chunk < 1:
        raise ValueError("--chunk must be at least 1")
    unknown = [arm for arm in arms if arm not in bw.ARMS]
    if unknown:
        raise ValueError(f"unknown arms {unknown}; known arms are {list(bw.ARMS)}")
    first, last = seeds
    parts = out / "parts"
    work: list[Chunk] = []
    for cell in cells:
        vow, pool = parse_cell(cell)
        for arm in arms:
            name = bw.report_name(vow, pool, arm)[:-5]
            for start in range(first, last + 1, chunk):
                count = min(chunk, last + 1 - start)
                part = parts / f"{name}-{start}.json"
                work.append(Chunk(name, cell, arm, start, count, part,
                                  bw.sim_command(godot, vow, pool, arm, start, count, part, content, weights, play)))
        if replay:
            name = bw.replay_name(vow, pool)[:-5]
            count = min(bw.REPLAY, last - first + 1)
            part = parts / f"{name}-{first}.json"
            work.append(Chunk(name, cell, "A", first, count, part,
                              bw.sim_command(godot, vow, pool, "A", first, count, part, content, None, play)))
    return work


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_digest(root: Path, sub: Path) -> str:
    """One digest over every GDScript file under `sub`, by relative path and content."""
    combined = hashlib.sha256()
    for path in sorted((root / sub).rglob("*.gd")):
        combined.update(str(path.relative_to(root)).encode("utf-8"))
        combined.update(digest(path).encode("ascii"))
    return combined.hexdigest()


def identity(root: Path, content: Path | None) -> dict[str, Any]:
    """What a chunk's sidecar must agree on to be reused: the content file, the simulator sources and the
    game rules under `domain/` (committed or not)."""
    content_path = content if content is not None else root / CONTENT
    return {"content": digest(content_path),
            "tools": {str(p): digest(root / p) for p in TOOL_SOURCES if (root / p).is_file()},
            "domain": tree_digest(root, DOMAIN)}


def _without_out(command: list[str]) -> list[str]:
    """A chunk's command without its report path, so a moved output directory still resumes."""
    return [arg for arg in command if not arg.startswith("--out=")]


def sidecar_of(chunk: Chunk, who: dict[str, Any], seconds: float) -> dict[str, Any]:
    return {"report": chunk.report, "cell": chunk.cell, "arm": chunk.arm, "seeds": [chunk.first, chunk.first + chunk.count - 1],
            "command": chunk.command, "identity": who, "seconds": round(seconds, 1)}


def is_done(chunk: Chunk, who: dict[str, Any]) -> bool:
    """Whether the chunk ran to completion under this very instrument; a stale one is an error."""
    if not (chunk.part.is_file() and chunk.sidecar.is_file()):
        return False
    done = json.loads(chunk.sidecar.read_text(encoding="utf-8"))
    if done.get("identity") != who:
        raise RuntimeError(f"{chunk.part.name} was produced from different content or simulator sources; "
                           "use a new output directory rather than mixing instruments")
    if _without_out(done.get("command", [])) != _without_out(chunk.command):
        raise RuntimeError(f"{chunk.part.name} was run with other parameters than this plan "
                           "(play, weights, chunking or arm); use a new output directory")
    return True


def run_chunks(work: list[Chunk], who: dict[str, Any], jobs: int, runner: Runner = run_command,
               root: Path = REPO,
               progress: Callable[[str], None] = lambda text: print(text, flush=True)) -> int:
    """Run every chunk that is not done, `jobs` at a time; returns how many ran.

    The one place Godot is launched from: it refuses unless `root` is isolated from the owner's profile."""
    require_isolated_user_dir(root)
    todo = [chunk for chunk in work if not is_done(chunk, who)]
    started, finished = time.monotonic(), [0]

    def run(chunk: Chunk) -> None:
        chunk.part.parent.mkdir(parents=True, exist_ok=True)
        chunk.part.unlink(missing_ok=True)
        begin = time.monotonic()
        runner(chunk.command, chunk.log)
        if not chunk.part.is_file():
            raise RuntimeError(f"{chunk.part.name}: the simulator wrote no report, see {chunk.log}")
        chunk.sidecar.write_text(json.dumps(sidecar_of(chunk, who, time.monotonic() - begin)), encoding="utf-8")
        finished[0] += 1
        if finished[0] % 10 == 0 or finished[0] == len(todo):
            progress(f"{finished[0]}/{len(todo)} chunks, {time.monotonic() - started:.0f} s")

    with ThreadPoolExecutor(max_workers=jobs) as pool:
        for future in [pool.submit(run, chunk) for chunk in todo]:
            future.result()
    return len(todo)


def manifest_core(manifest: dict[str, Any]) -> dict[str, Any]:
    """A manifest without its seeds: what chunks and bands must share to be merged."""
    return {k: v for k, v in manifest.items() if k not in ("seeds", "chunks")}


def _check_cell_and_arm(name: str, manifest: dict[str, Any]) -> None:
    vow, pool, arm = name.split("-", 2)
    way, build = bw.ARMS[arm] if arm in bw.ARMS else ("none", "adaptive")  # the replay is arm A
    if (manifest.get("vow"), manifest.get("pool"), manifest.get("way"), manifest.get("build")) != \
            (int(vow[1:]), pool, way, build):
        raise ValueError(f"{name}: the manifest is not this cell and arm")


def _join(name: str, reports: list[dict[str, Any]], origin: str) -> dict[str, Any]:
    """One report from reports of disjoint, ascending seed bands that share one manifest."""
    core = manifest_core(reports[0]["manifest"])
    for report in reports[1:]:
        if manifest_core(report["manifest"]) != core:
            differing = sorted(k for k in core.keys() | manifest_core(report["manifest"]).keys()
                               if core.get(k) != manifest_core(report["manifest"]).get(k))
            raise ValueError(f"{name}: {origin} differ in content, tools or instrument ({', '.join(differing)}); "
                             "refusing to merge")
    rows = [row for report in reports for row in report["runs"]]
    seeds = [row["seed"] for row in rows]
    if seeds != sorted(set(seeds)):
        raise ValueError(f"{name}: the seeds of {origin} overlap or are out of order")
    manifest = dict(core)
    manifest["seeds"] = {"first": seeds[0], "last": seeds[-1], "count": len(rows)}
    manifest["chunks"] = len(reports)
    return {"manifest": manifest, "runs": rows}


def _read(path: Path) -> dict[str, Any]:
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc
    if not isinstance(report.get("manifest"), dict) or not isinstance(report.get("runs"), list) or not report["runs"]:
        raise ValueError(f"{path.name}: no manifest or no runs")
    return report


def merge_report(name: str, paths: list[Path], expected: tuple[int, int] | None = None) -> dict[str, Any]:
    """One report from the chunk reports of one cell and arm.

    Refuses on differing manifests, differing sidecar identities (where sidecars exist), rows that
    are not consecutive seeds, or seeds other than `expected` (first, last) when it is given."""
    reports = sorted((_read(path) for path in paths), key=lambda r: r["runs"][0]["seed"])
    for report in reports:
        _check_cell_and_arm(name, report["manifest"])
    sidecars = [path.with_name(path.stem + SIDECAR) for path in paths]
    identities = {json.dumps(json.loads(s.read_text(encoding="utf-8"))["identity"], sort_keys=True)
                  for s in sidecars if s.is_file()}
    if len(identities) > 1:
        raise ValueError(f"{name}: chunk sidecars name different content or tools; refusing to merge")
    merged = _join(name, reports, "its chunks")
    seeds = [row["seed"] for row in merged["runs"]]
    if seeds != list(range(seeds[0], seeds[-1] + 1)):
        raise ValueError(f"{name}: the chunks leave a gap in the seeds")
    if expected is not None and (seeds[0], seeds[-1]) != expected:
        raise ValueError(f"{name}: seeds {seeds[0]}-{seeds[-1]} are not the planned {expected[0]}-{expected[1]}")
    return merged


def merge_parts(out: Path, work: list[Chunk]) -> list[str]:
    """Merge a plan's chunks into one report per cell and arm in `out`; returns the report names."""
    by_report: dict[str, list[Chunk]] = {}
    for chunk in work:
        by_report.setdefault(chunk.report, []).append(chunk)
    for name, chunks in by_report.items():
        planned = (min(c.first for c in chunks), max(c.first + c.count - 1 for c in chunks))
        merged = merge_report(name, [c.part for c in chunks], planned)
        (out / f"{name}.json").write_text(json.dumps(merged), encoding="utf-8")
    return sorted(by_report)


def merge_directory(directory: Path, out: Path | None = None) -> list[str]:
    """Merge every `parts/<report>-<first seed>.json` of a run directory (the same checks, no plan).

    For run directories whose merged reports were not kept, e.g. an archive of chunks."""
    out = out or directory
    groups: dict[str, list[Path]] = {}
    for path in sorted((directory / "parts").glob("*.json")):
        if not path.name.endswith(SIDECAR):
            groups.setdefault(path.stem.rsplit("-", 1)[0], []).append(path)
    if not groups:
        raise ValueError(f"{directory}: no chunk reports under parts/")
    out.mkdir(parents=True, exist_ok=True)
    for name, paths in groups.items():
        (out / f"{name}.json").write_text(json.dumps(merge_report(name, paths)), encoding="utf-8")
    return sorted(groups)


def join_bands(out: Path, cell: str, arms: list[str], directories: list[Path]) -> dict[str, tuple[int, int, int]]:
    """Join one cell's arms across merged directories of disjoint seed bands (the longer G3 band).

    Refuses unless each arm's manifests agree across directories apart from the seeds."""
    out.mkdir(parents=True, exist_ok=True)
    summary = {}
    for arm in arms:
        reports = sorted((_read(d / f"{cell}-{arm}.json") for d in directories),
                         key=lambda r: r["runs"][0]["seed"])
        joined = _join(f"{cell}-{arm}", reports, "the bands")
        (out / f"{cell}-{arm}.json").write_text(json.dumps(joined), encoding="utf-8")
        seeds = joined["manifest"]["seeds"]
        summary[arm] = (seeds["count"], seeds["first"], seeds["last"])
    return summary

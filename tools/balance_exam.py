#!/usr/bin/env python3
"""Run the #556 exam on this machine; preserve seeds, roots and row order.

Usage: nice -n 10 python3 tools/balance_exam.py --out-dir /path/to/new-exam --jobs 8
No exam is started by importing this module or by --dry-run.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import shutil
import subprocess
import sys

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from balance_readout_guard import require_isolated_user_dir  # noqa: E402

REPO = Path(__file__).resolve().parent.parent


def sweep_jobs(out: Path, shard_size: int = 50) -> list[tuple[str, list[str]]]:
    jobs = []
    for first in range(0, 2000, shard_size):
        name = f"shard-{first:04d}"
        jobs.append((name, ["res://tools/balance_sweep.gd", "--mode=sweep", "--stage=exam",
                           "--rootSeed=215", f"--policyFirst={first}",
                           f"--policyCount={min(shard_size, 2000-first)}", "--seeds=40",
                           "--seed0=3000", f"--out={out / (name + '.ndjson')}"]))
    return jobs


def controls_job(out: Path) -> tuple[str, list[str]]:
    return "controls", ["res://tools/balance_sweep.gd", "--mode=controls", "--stage=exam",
                        "--seeds=200", "--seed0=4000", f"--out={out}"]


def cem_job(out: Path, seeds: Path, island: int) -> tuple[str, list[str]]:
    return f"island-{island}", ["res://tools/balance_cem.gd", f"--island={island}",
        "--stage=exam", f"--seedsJson={seeds}", "--samplerRoot=215", "--rootSeed=216",
        "--trainSeed0=4200", "--holdoutSeed0=5000", "--holdoutCount=200", f"--out={out}"]


def merge_shards(shards: list[Path], out: Path) -> None:
    """Keep the first manifest, then copy run bytes in policy order, as #556 did."""
    with out.open("wb") as dest:
        for index, path in enumerate(shards):
            with path.open("rb") as source:
                header = source.readline()
                if not header or "manifest" not in json.loads(header):
                    raise ValueError(f"missing manifest: {path}")
                if index == 0:
                    dest.write(header)
                shutil.copyfileobj(source, dest)


def aggregate_controls(src: Path) -> list[dict]:
    # Keep #556's error-field handling (the Phase A aggregator differs here).
    agg = defaultdict(lambda: dict(wins=0, runs=0, stalls=0, errors=0))
    with src.open() as stream:
        for line in stream:
            for row in json.loads(line).get("runs", []):
                counts = agg[row["arm"], row["aspect"], row["vow"]]
                counts["runs"] += 1
                counts["wins"] += row["outcome"] == "win"
                counts["stalls"] += row["outcome"] == "stall"
                counts["errors"] += bool(row.get("error")) or row["outcome"] == "error"
    return [dict(arm=key[0], aspect=key[1], vow=key[2], wins=value["wins"],
                 runs=value["runs"], winRate=value["wins"] / value["runs"],
                 stalls=value["stalls"], errors=value["errors"])
            for key, value in sorted(agg.items(), key=lambda kv: (kv[0][0], kv[0][1] != "duskblade", kv[0][2]))]


def cell_of(row: dict, analysis: dict) -> str:
    fights = row["fights"]
    n = len(fights)
    med = analysis["medians"][row["aspect"]]
    shatter = sum(f["shatters"] for f in fights) / n > med["shattersPerFight"]
    smolder = sum(f["smolderKills"] for f in fights) / n > med["smolderKillsPerFight"]
    lean = "shatter" if shatter else "smolder" if smolder else "attrition"
    cuts = analysis["deckCuts"]
    tier = "thin" if row["deck"] <= cuts["thinMax"] else "mid" if row["deck"] <= cuts["midMax"] else "fat"
    return f"{lean}:{tier}"


def select_islands(merged: Path, analysis: dict) -> tuple[dict, list[int]]:
    """2026-08-14 rule: six cells/grid, >=20 policies, best in-cell policy.

    Stable cell ties retain landscape grid insertion order; policy ties choose
    the lower index. Scheduling uses representative mean fight turns as a cost
    proxy only, and never changes island identity or RNG.
    """
    counts = defaultdict(lambda: [0, 0])
    turns = defaultdict(lambda: [0, 0])
    with merged.open() as stream:
        next(stream)
        for line in stream:
            row = json.loads(line)
            if row["aspect"] != "duskblade":
                continue
            grid = f"duskblade:v{row['vow']}"
            policy = row["policyIndex"]
            counts[grid, cell_of(row, analysis), policy][0] += row["outcome"] == "win"
            counts[grid, cell_of(row, analysis), policy][1] += 1
            turns[grid, policy][0] += sum(f["turns"] for f in row["fights"])
            turns[grid, policy][1] += 1
    result, costs = {}, []
    for grid_name in ("duskblade:v0", "duskblade:v5"):
        grid = analysis["grids"].get(grid_name, analysis["grids"].get(grid_name.replace(":v", ":")))
        candidates = [(cell, values) for cell, values in grid.items() if values["policies"] >= 20]
        candidates.sort(key=lambda item: -item[1]["winRate"])
        if len(candidates) < 6:
            raise ValueError(f"{grid_name}: need six cells with >=20 policies, got {len(candidates)}")
        selected = []
        for cell, _ in candidates[:6]:
            best = max((wins / runs, -policy, policy)
                       for (g, c, policy), (wins, runs) in counts.items() if g == grid_name and c == cell)
            policy = best[2]
            selected.append(dict(cell=cell, policyIndex=policy))
            total, runs = turns[grid_name, policy]
            costs.append(total / runs)
        result[grid_name] = selected
    return result, sorted(range(12), key=lambda island: (-costs[island], island))


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=1))


def run_command(command: list[str], log: Path, allowed=(0,)) -> int:
    with log.open("w") as stream:
        code = subprocess.run(command, cwd=REPO, stdout=stream, stderr=subprocess.STDOUT).returncode
    diagnostics = log.read_text()
    if code not in allowed or any(line.startswith(("SCRIPT ERROR:", "ERROR:"))
                                  for line in diagnostics.splitlines()):
        raise RuntimeError(f"exit {code}: {command[0]}; see {log}")
    return code


def run_jobs(jobs: list[tuple[str, list[str]]], directory: Path, workers: int,
             godot: str, niceness: int) -> None:
    require_isolated_user_dir(REPO)  # every job is a Godot run

    def run(job):
        name, args = job
        command = ["nice", "-n", str(niceness), godot, "--headless", "-s", args[0], "--", *args[1:]]
        run_command(command, directory / f"{name}.log")
        print(f"completed {name}", flush=True)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(run, job) for job in jobs]
        try:
            for future in as_completed(futures):
                future.result()
        except Exception:
            for future in futures:
                future.cancel()
            raise


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--jobs", type=int, default=8)
    parser.add_argument("--shard-size", type=int, default=50)
    parser.add_argument("--nice", type=int, default=10, dest="niceness")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--dry-run", action="store_true")
    opts = parser.parse_args(argv)
    if not 1 <= opts.jobs <= 8 or not 1 <= opts.shard_size <= 2000 or not 10 <= opts.niceness <= 19:
        parser.error("require jobs 1..8, shard-size 1..2000, nice 10..19")
    out = opts.out_dir.resolve()
    phase, layer1, layer2 = (out / name for name in ("phase-a", "layer1", "layer2"))
    sweeps = sweep_jobs(layer1, opts.shard_size)
    seeds = layer2 / "island-seeds.json"
    phase_jobs = [controls_job(phase / "controls.json")]
    for vow in (0, 5):
        phase_jobs.append((f"holdout-vow{vow}", ["res://tools/balance_sim.gd", "--stage=exam",
            f"--vow={vow}", "--runs=200", "--seed0=5000", "--aspect=all", "--mix=none",
            f"--out={phase / f'holdout-vow{vow}.json'}"]))
    if opts.dry_run:
        print(json.dumps({"phaseA": phase_jobs, "layer1": [controls_job(layer1 / "controls.ndjson"), *sweeps],
            "layer2": [cem_job(layer2 / f"island-{i}.ndjson", seeds, i) for i in range(12)],
            "jobs": opts.jobs, "nice": opts.niceness}, indent=2))
        return 0
    require_isolated_user_dir(REPO)  # before anything is written
    if out.exists() and any(out.iterdir()):
        parser.error("out-dir must be empty; existing exams are never overwritten")
    for directory in (phase, layer1, layer2):
        directory.mkdir(parents=True, exist_ok=True)
    py = ["nice", "-n", str(opts.niceness), sys.executable]
    run_jobs(phase_jobs, phase, opts.jobs, opts.godot, opts.niceness)
    # #556 records Phase A verdicts and continues the full measurement for NO-GO
    # or VETO. An execution error (1) must stop instead of producing partial data.
    phase_code = run_command([*py, "tools/balance_phase_a.py", "--out-dir", str(phase),
        "--controls-json", str(phase / "controls.json"),
        "--holdout-vow0", str(phase / "holdout-vow0.json"),
        "--holdout-vow5", str(phase / "holdout-vow5.json")], out / "phase-a.log", (0, 2, 3))
    print(f"Phase A exit {phase_code}; full exam measurement continues", flush=True)
    run_jobs([controls_job(layer1 / "controls.ndjson"), *sweeps], layer1, opts.jobs, opts.godot, opts.niceness)
    merged = layer1 / "merged.ndjson"
    merge_shards([layer1 / f"{name}.ndjson" for name, _ in sweeps], merged)
    controls = layer1 / "controls-analysis.json"
    write_json(controls, aggregate_controls(layer1 / "controls.ndjson"))
    analysis_path = layer1 / "layer1-analysis.json"
    run_command([*py, "tools/balance_landscape.py", str(merged), str(controls), str(analysis_path)],
                layer1 / "landscape.log")
    selected, order = select_islands(merged, json.loads(analysis_path.read_text()))
    write_json(seeds, selected)
    write_json(layer2 / "schedule.json", {"islands": order, "estimate": "representative mean fight turns"})
    run_jobs([cem_job(layer2 / f"island-{i}.ndjson", seeds, i) for i in order],
             layer2, opts.jobs, opts.godot, opts.niceness)
    run_command([*py, "tools/balance_cem_report.py", str(layer2), str(analysis_path),
                 str(layer2 / "layer2-analysis.json")], layer2 / "report.log")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"balance_exam: {exc}", file=sys.stderr)
        sys.exit(1)

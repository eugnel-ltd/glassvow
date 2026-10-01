#!/usr/bin/env python3
"""Flame lock readout: the section-11 cell table and gates G1-G7.

docs/design/2026-09-29-dusk-flame/README.md, section 11. Runs the Duskblade
over vows {0, 5} x pool states {fresh, full} x paired seeds, with common random
numbers across five arms: C_shatter, C_lantern and C_edge (committed pilots),
A (adaptive, today's arm 1) and R (random build, today's arm 2). Prints one
Markdown table per cell and the G1-G7 rows with PASS/FAIL against the initial
thresholds. A run without its flame metrics, arms whose seeds do not pair,
mixed builds or any Godot error stop the readout (exit 1): nothing is graded
on incomplete data.

Usage (repo root):
  python3 tools/balance_ways.py [--quick | --seeds 13000-13199] [--jobs 4] [--out-dir DIR]
                                [--content FILE]   # a scratch catalogue, e.g. one sweep point
                                [--way-weights 2.0/1.0]   # committed arms' own/other glass weights
                                [--play search]   # readout 8's search player on the board
                                [--vows 0]   # one vow's cells only (a split table: V0 and V5 on their own seeds)
  python3 tools/balance_ways.py --from-dir DIR [--quick | --seeds A-B]   # re-grade saved reports

Every gate is graded twice: on the point estimate (the verdict readouts 1-7 used)
and on its 95% interval (Wilson for a rate, Newcombe's hybrid score interval,
built from two Wilson intervals, for a difference). An interval that straddles
the threshold is UNDECIDED. The feel table reads the per-fight flame rows the
simulator writes from readout 8 on; older reports print "-" there.
"""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from fractions import Fraction
from pathlib import Path
from typing import Any

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from balance_exam import run_command  # noqa: E402
from balance_score import wilson  # noqa: E402

ARMS = {  # arm -> (policy way, build)
    "C_shatter": ("shatter", "adaptive"),
    "C_lantern": ("lantern", "adaptive"),
    "C_edge": ("edge", "adaptive"),
    "A": ("none", "adaptive"),
    "R": ("none", "random"),
}
COMMITTED = ("C_shatter", "C_lantern", "C_edge")
WAYS = ("shatter", "lantern", "edge")
VOWS = (0, 5)
POOLS = ("fresh", "full")
DEFAULT_SEEDS = (13000, 13199)
QUICK_SEEDS = (13000, 13039)
ACCEPTANCE = (3000, 5199)  # lock section 11: acceptance seeds stay otherwise untouched
REPLAY = 3  # arm A seeds re-run per cell: G7's deterministic replay
RATES = ("shatters", "kindles", "embersSpent", "cracked", "embersGained")
STEADY_OR_TRUE = ("STEADY", "TRUE")

# Initial thresholds of lock section 11, signed after the first readout.
G1_FLOOR = {(0, "full"): Fraction(50, 100), (5, "full"): Fraction(25, 100),
            (0, "fresh"): Fraction(40, 100)}
G2_SPREAD = Fraction(10, 100)
G3_BELOW, G3_ABOVE = Fraction(3, 100), Fraction(15, 100)
G4_GAP = Fraction(25, 100)
G4_CEILING = {0: Fraction(35, 100), 5: Fraction(15, 100)}
# G5: (Steady by the end of Act 1, True by the end of Act 2) over every run; None is
# not graded. The fresh-pool figure is readout 5's; like G1, fresh is graded at V0 only.
G5_FLOOR = {(0, "full"): (Fraction(70, 100), Fraction(40, 100)),
            (5, "full"): (Fraction(70, 100), Fraction(40, 100)),
            (0, "fresh"): (Fraction(40, 100), None)}
G6_MAX, G6_HELD, G6_WAYS = Fraction(60, 100), Fraction(20, 100), 2
PLAYS = ("greedy", "search")
# Readout 8's feel proxies: a won fight the hero leaves under this share of max HP
# is a close call.
CLOSE_CALL = Fraction(20, 100)


def parse_seeds(text: str) -> tuple[int, int]:
    first, sep, last = text.partition("-")
    if not sep or not first.isdigit() or not last.isdigit() or int(first) > int(last):
        raise ValueError(f"--seeds must be FIRST-LAST with FIRST <= LAST, got {text!r}")
    seeds = int(first), int(last)
    if seeds[0] <= ACCEPTANCE[1] and seeds[1] >= ACCEPTANCE[0]:
        raise ValueError(f"seeds {text} touch the acceptance band {ACCEPTANCE[0]}-{ACCEPTANCE[1]}")
    return seeds


def report_name(vow: int, pool: str, arm: str) -> str:
    return f"v{vow}-{pool}-{arm}.json"


def replay_name(vow: int, pool: str) -> str:
    return f"v{vow}-{pool}-replay.json"


def parse_weights(text: str) -> tuple[float, float]:
    commit, sep, off = text.partition("/")
    try:
        weights = float(commit), float(off)
    except ValueError:
        weights = (0.0, 0.0)
    if not sep or min(weights) <= 0:
        raise ValueError(f"--way-weights must be COMMIT/OFF, two positive numbers, got {text!r}")
    return weights


def sim_command(godot: str, vow: int, pool: str, arm: str, first: int, count: int,
                out: Path, content: Path | None = None,
                weights: tuple[float, float] | None = None, play: str = "greedy") -> list[str]:
    way, build = ARMS[arm]
    return [godot, "--headless", "-s", "res://tools/balance_sim.gd", "--", "--aspect=duskblade",
            f"--vow={vow}", f"--runs={count}", f"--seed0={first}", f"--pool={pool}",
            f"--way={way}", f"--build={build}", f"--out={out}"] \
        + ([f"--wayCommit={weights[0]}", f"--wayOff={weights[1]}"]
           if weights is not None and way != "none" else []) \
        + ([f"--content={content}"] if content is not None else []) \
        + ([f"--play={play}"] if play != "greedy" else [])


def jobs(godot: str, seeds: tuple[int, int], directory: Path, content: Path | None = None,
         weights: tuple[float, float] | None = None,
         play: str = "greedy", vows: tuple[int, ...] = VOWS) -> list[tuple[str, list[str]]]:
    first, count = seeds[0], seeds[1] - seeds[0] + 1
    out: list[tuple[str, list[str]]] = []
    for vow in vows:
        for pool in POOLS:
            for arm in ARMS:
                out.append((report_name(vow, pool, arm)[:-5], sim_command(
                    godot, vow, pool, arm, first, count, directory / report_name(vow, pool, arm),
                    content, weights, play)))
            out.append((replay_name(vow, pool)[:-5], sim_command(
                godot, vow, pool, "A", first, min(REPLAY, count), directory / replay_name(vow, pool),
                content, None, play)))
    return out


def run_jobs(work: list[tuple[str, list[str]]], directory: Path, workers: int) -> None:
    def run(job: tuple[str, list[str]]) -> None:
        name, command = job
        run_command(command, directory / f"{name}.log")
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for future in [pool.submit(run, job) for job in work]:
            future.result()


def _require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def _check_row(row: Any, name: str) -> None:
    _require(isinstance(row, dict) and isinstance(row.get("seed"), int)
             and row.get("outcome") in ("win", "loss", "stall", "error"),
             f"{name}: a run row has no seed or outcome")
    where = f"{name} seed {row['seed']}"
    flame = row.get("flame")
    _require(isinstance(flame, dict), f"{where}: missing flame metrics")
    readings = [flame.get("end")] + (flame.get("acts") if isinstance(flame.get("acts"), list) else [None])
    for reading in readings:
        _require(isinstance(reading, dict) and isinstance(reading.get("dominant"), str)
                 and isinstance(reading.get("tier"), str)
                 and isinstance(reading.get("purity"), (int, float)),
                 f"{where}: missing or malformed flame reading")
    rates = flame.get("rates")
    _require(isinstance(rates, dict) and all(isinstance(rates.get(key), (int, float)) for key in RATES),
             f"{where}: missing per-fight rates")


def load_report(path: Path, seeds: tuple[int, int] | None) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc
    rows = report.get("runs") if isinstance(report, dict) else None
    _require(isinstance(rows, list) and bool(rows), f"{path.name}: no runs")
    for row in rows:
        _check_row(row, path.name)
    if seeds is not None:
        _require([row["seed"] for row in rows] == list(range(seeds[0], seeds[1] + 1)),
                 f"{path.name}: seeds do not pair with {seeds[0]}-{seeds[1]}")
    manifest = report.get("manifest")
    _require(isinstance(manifest, dict), f"{path.name}: no manifest")
    return manifest, rows


def _fraction(rows: list[dict[str, Any]], test) -> Fraction:
    return Fraction(sum(1 for row in rows if test(row)), len(rows))


def _reached(row: dict[str, Any], act: int, tiers: tuple[str, ...], way: str) -> bool:
    acts = row["flame"]["acts"]
    return len(acts) > act and acts[act]["tier"] in tiers and acts[act]["dominant"] == way


def expressed(plays: dict[str, Any]) -> str:
    """The way a fight's coloured plays favour (affinity weight per way), or "" for a tie or none."""
    weights = {way: float(plays.get(way, 0.0)) for way in WAYS}
    top = max(weights.values())
    leaders = [way for way, weight in weights.items() if weight == top]
    return leaders[0] if top > 0 and len(leaders) == 1 else ""


def feel(rows: list[dict[str, Any]], way: str) -> dict[str, Any] | None:
    """Readout 8's per-way feel proxies, or None for reports without per-fight flame rows.

    Expression is the share of fights whose coloured plays favour the arm's way
    (a committed arm's own, else the way the deck reads at the fight's start)."""
    if not all(isinstance(row["flame"].get("fights"), list) and isinstance(row.get("fights"), list)
               and len(row["flame"]["fights"]) == len(row["fights"]) for row in rows):
        return None
    fights = [(fight, flame) for row in rows for fight, flame in zip(row["fights"], row["flame"]["fights"])]
    won = [flame for fight, flame in fights if fight["result"] == "win"]
    close = sum(Fraction(int(flame["hp"]), max(1, int(flame["maxHp"]))) < CLOSE_CALL for flame in won)
    shown = sum(expressed(flame["plays"]) == (way if way != "none" else flame["dominant"])
                for _, flame in fights)
    deaths = Counter(row["fights"][-1]["act"] for row in rows if row["outcome"] != "win" and row["fights"])
    return {"fights": len(fights), "turns": sum(fight["turns"] for fight, _ in fights) / max(1, len(fights)),
            "hpLost": sum(fight["hpLost"] for fight, _ in fights) / max(1, len(fights)),
            "won": len(won), "close": close, "shown": shown,
            "deaths": tuple(deaths.get(act, 0) for act in (1, 2, 3))}


def arm_stats(rows: list[dict[str, Any]], way: str) -> dict[str, Any]:
    wins = sum(row["outcome"] == "win" for row in rows)
    stats = {
        "feel": feel(rows, way),
        "n": len(rows), "wins": wins, "rate": Fraction(wins, len(rows)),
        "wilson": wilson(wins, len(rows)),
        "stalls": sum(row["outcome"] == "stall" for row in rows),
        "errors": sum(row["outcome"] == "error" or bool(row.get("error")) for row in rows),
        "rates": {key: sum(row["flame"]["rates"][key] for row in rows) / len(rows) for key in RATES},
    }
    if way != "none":
        stats["own"] = _fraction(rows, lambda row: row["flame"]["end"]["dominant"] == way)
        stats["steady1"] = _fraction(rows, lambda row: _reached(row, 0, STEADY_OR_TRUE, way))
        stats["true2"] = _fraction(rows, lambda row: _reached(row, 1, ("TRUE",), way))
    return stats


def pct(value: Fraction | float) -> str:
    return f"{float(value) * 100:.1f}%"


def pp(value: Fraction, sign: bool = True) -> str:
    return f"{float(value) * 100:{'+' if sign else ''}.1f} pp"


def verdict(ok: bool) -> str:
    return "PASS" if ok else "FAIL"


def interval(k: int, n: int) -> tuple[float, float, float]:
    """A rate with its Wilson 95% interval: (estimate, low, high)."""
    low, high = wilson(k, n)
    return (k / n if n else 0.0), low, high


def difference(a: tuple[int, int], b: tuple[int, int]) -> tuple[float, float, float]:
    """a - b with Newcombe's hybrid score 95% interval (method 10, from the two Wilson intervals).

    It treats the arms as independent; paired seeds make the true interval narrower,
    so an UNDECIDED here is conservative."""
    pa, la, ua = interval(*a)
    pb, lb, ub = interval(*b)
    d = pa - pb
    return d, d - ((pa - la) ** 2 + (ub - pb) ** 2) ** 0.5, d + ((ua - pa) ** 2 + (pb - lb) ** 2) ** 0.5


def decided(passes: list[bool | None]) -> str:
    """Combine sub-verdicts: True decided pass, False decided fail, None straddles."""
    if any(ok is False for ok in passes):
        return "FAIL"
    return "PASS" if all(ok is True for ok in passes) else "UNDECIDED"


def at_least(span: tuple[float, float, float], floor: float) -> bool | None:
    return True if span[1] >= floor else (False if span[2] < floor else None)


def at_most(span: tuple[float, float, float], ceiling: float) -> bool | None:
    return True if span[2] <= ceiling else (False if span[1] > ceiling else None)


def below(span: tuple[float, float, float], ceiling: float) -> bool | None:
    return True if span[2] < ceiling else (False if span[1] >= ceiling else None)


def show(span: tuple[float, float, float], *ns: int, points: bool = False, unit: str = "") -> str:
    """An estimate with its interval and the N behind it (one N per rate in a difference)."""
    n = "n=" + "+".join(str(k) for k in ns) + unit
    if points:
        return f"{span[0] * 100:+.1f} pp ({span[1] * 100:+.1f} to {span[2] * 100:+.1f}, {n})"
    return f"{pct(span[0])} ({pct(span[1])}-{pct(span[2])}, {n})"


def _count(stats: dict[str, Any], key: str) -> tuple[int, int]:
    return int(stats[key] * stats["n"]), stats["n"]


def cell_intervals(vow: int, pool: str, stats: dict[str, dict[str, Any]],
                   adaptive_rows: list[dict[str, Any]], point_g7: str) -> list[tuple[str, str]]:
    """Each gate of `cell_gates` on its 95% interval: (measured with interval and N, verdict)."""
    rate = {arm: (stats[arm]["wins"], stats[arm]["n"]) for arm in ARMS}
    committed = {arm: stats[arm]["rate"] for arm in COMMITTED}
    best, worst = max(committed, key=committed.get), min(committed, key=committed.get)  # as cell_gates
    rows: list[tuple[str, str]] = []
    floor = G1_FLOOR.get((vow, pool))
    spans = {arm: interval(*rate[arm]) for arm in COMMITTED}
    rows.append((f"worst {worst} {show(spans[worst], rate[worst][1])}",
                 "n/a" if floor is None else decided([at_least(spans[arm], float(floor)) for arm in COMMITTED])))
    pairs = [(a, b) for i, a in enumerate(COMMITTED) for b in COMMITTED[i + 1:]]
    spread = {pair: difference(rate[pair[0]], rate[pair[1]]) for pair in pairs}
    widest = difference(rate[best], rate[worst])
    rows.append((f"{best} - {worst} {show(widest, rate[best][1], rate[worst][1], points=True)}",
                 decided([True if max(abs(d[1]), abs(d[2])) <= G2_SPREAD
                          else (False if d[1] > G2_SPREAD or d[2] < -G2_SPREAD else None)
                          for d in spread.values()])))
    skill = difference(rate["A"], rate[best])
    rows.append((f"A - {best} {show(skill, rate['A'][1], rate[best][1], points=True)}",
                 decided([at_least(skill, -float(G3_BELOW)), at_most(skill, float(G3_ABOVE))])))
    gap, random_rate = difference(rate["R"], rate[worst]), interval(*rate["R"])
    rows.append((f"R - {worst} {show(gap, rate['R'][1], rate[worst][1], points=True)}; "
                 f"R {show(random_rate, rate['R'][1])}",
                 decided([at_most(gap, -float(G4_GAP)), below(random_rate, float(G4_CEILING[vow]))])))
    reach = G5_FLOOR.get((vow, pool))
    steady = {arm: interval(*_count(stats[arm], "steady1")) for arm in COMMITTED}
    true = {arm: interval(*_count(stats[arm], "true2")) for arm in COMMITTED}
    low_arm = min(COMMITTED, key=lambda arm: steady[arm][0])
    text = f"Steady min {low_arm} {show(steady[low_arm], stats[low_arm]['n'])}"
    if reach is None:
        rows.append((text, "n/a"))
    else:
        checks = [at_least(steady[arm], float(reach[0])) for arm in COMMITTED]
        if reach[1] is not None:
            true_arm = min(COMMITTED, key=lambda arm: true[arm][0])
            text += f"; True min {true_arm} {show(true[true_arm], stats[true_arm]['n'])}"
            checks += [at_least(true[arm], float(reach[1])) for arm in COMMITTED]
        rows.append((text, decided(checks)))
    wins = Counter(row["flame"]["end"]["dominant"] for row in adaptive_rows if row["outcome"] == "win")
    total = sum(wins.values())
    if total == 0:
        rows.append(("no A wins", "FAIL"))
    else:
        shares = {way: interval(wins.get(way, 0), total) for way in WAYS}
        lead = max(WAYS, key=lambda way: shares[way][0])
        held_sure = sum(share[1] >= G6_HELD for share in shares.values())
        held_maybe = sum(share[2] >= G6_HELD for share in shares.values())
        rows.append((f"lead {lead} {show(shares[lead], total, unit=' A wins')}",
                     decided([at_most(share, float(G6_MAX)) for share in shares.values()]
                             + [True if held_sure >= G6_WAYS else (False if held_maybe < G6_WAYS else None)])))
    rows.append(("counts (no interval)", point_g7))
    return rows


def cell_gates(vow: int, pool: str, stats: dict[str, dict[str, Any]],
               adaptive_rows: list[dict[str, Any]], replay: tuple[int, int]) -> list[tuple[str, ...]]:
    committed = {arm: stats[arm]["rate"] for arm in COMMITTED}
    best_arm, worst_arm = max(committed, key=committed.get), min(committed, key=committed.get)
    best, worst = committed[best_arm], committed[worst_arm]
    adaptive, random_arm = stats["A"]["rate"], stats["R"]["rate"]
    floor = G1_FLOOR.get((vow, pool))
    steady = min(COMMITTED, key=lambda arm: stats[arm]["steady1"])
    true = min(COMMITTED, key=lambda arm: stats[arm]["true2"])
    reach = G5_FLOOR.get((vow, pool))
    reach_text = "no threshold for this cell" if reach is None else (
        f">= {pct(reach[0])} and >= {pct(reach[1])} for every committed way" if reach[1] is not None
        else f">= {pct(reach[0])} Steady for every committed way; True not graded")
    wins = Counter(row["flame"]["end"]["dominant"] for row in adaptive_rows if row["outcome"] == "win")
    total = sum(wins.values())
    shares = {way: Fraction(wins.get(way, 0), total) for way in WAYS} if total else {}
    stalls = sum(stats[arm]["stalls"] for arm in ARMS)
    errors = sum(stats[arm]["errors"] for arm in ARMS)
    same, replayed = replay
    return [
        ("G1 viability: each committed way wins", f"worst {worst_arm} {pct(worst)}",
         f">= {pct(floor)}" if floor is not None else "no threshold for this cell",
         verdict(worst >= floor) if floor is not None else "n/a"),
        ("G2 parity: the ways are comparable", f"{pp(best - worst, False)} ({best_arm} - {worst_arm})",
         f"<= {pp(G2_SPREAD, False)}", verdict(best - worst <= G2_SPREAD)),
        ("G3 skill: reading offers pays, commitment is no trap",
         f"A {pct(adaptive)} vs best {pct(best)} ({pp(adaptive - best)})", "-3 pp to +15 pp",
         verdict(best - G3_BELOW <= adaptive <= best + G3_ABOVE)),
        ("G4 random loses: scattering cannot win",
         f"R {pct(random_arm)} vs worst {pct(worst)} ({pp(random_arm - worst)})",
         f"R <= worst - 25 pp and R < {pct(G4_CEILING[vow])}",
         verdict(random_arm <= worst - G4_GAP and random_arm < G4_CEILING[vow])),
        ("G5 reachability: insisting gets there",
         f"Steady by end of Act 1 min {pct(stats[steady]['steady1'])} ({steady}); "
         f"True by end of Act 2 min {pct(stats[true]['true2'])} ({true})", reach_text,
         "n/a" if reach is None else verdict(stats[steady]["steady1"] >= reach[0]
                                            and (reach[1] is None or stats[true]["true2"] >= reach[1]))),
        ("G6 diversity: different adaptive runs are different",
         ", ".join(f"{way} {pct(shares[way])}" for way in WAYS) + f" of {total} A wins"
         if total else "no A wins", "no way > 60%, >= 2 ways >= 20%",
         verdict(bool(shares) and max(shares.values()) <= G6_MAX
                 and sum(share >= G6_HELD for share in shares.values()) >= G6_WAYS)),
        ("G7 guards: nothing stalls, errors or replays differently",
         f"{stalls} stalls, {errors} errors; replay {same}/{replayed} identical",
         "zero, zero, all identical", verdict(stalls == 0 and errors == 0 and same == replayed)),
    ]


def parse_vows(text: str) -> tuple[int, ...]:
    vows = tuple(sorted({int(part) for part in text.split(",") if part.strip().isdigit()}))
    if not vows or any(vow not in VOWS for vow in vows) or len(vows) != len(text.split(",")):
        raise ValueError(f"--vows must name some of {VOWS} separated by commas, got {text!r}")
    return vows


def grade(directory: Path, seeds: tuple[int, int], vows: tuple[int, ...] = VOWS) -> dict[str, Any]:
    """Load every report of the cell table, check pairing and provenance, grade."""
    cells: dict[tuple[int, str], Any] = {}
    identity: set[tuple[str, str]] = set()
    weights: set[tuple[Any, Any]] = set()
    plays: set[str] = set()
    for vow in vows:
        for pool in POOLS:
            stats: dict[str, dict[str, Any]] = {}
            adaptive_rows: list[dict[str, Any]] = []
            for arm, (way, build) in ARMS.items():
                manifest, rows = load_report(directory / report_name(vow, pool, arm), seeds)
                _require(manifest.get("vow") == vow and manifest.get("pool") == pool
                         and manifest.get("way") == way and manifest.get("build") == build
                         and manifest.get("aspect") == "duskblade",
                         f"{report_name(vow, pool, arm)}: manifest is not this cell and arm")
                identity.add((str(manifest.get("commit")), str(manifest.get("contentFileSha256"))))
                plays.add(str(manifest.get("play", "greedy")))
                if arm in COMMITTED:
                    policy = manifest.get("policy") if isinstance(manifest.get("policy"), dict) else {}
                    weights.add((policy.get("wayCommit"), policy.get("wayOff")))
                stats[arm] = arm_stats(rows, way)
                if arm == "A":
                    adaptive_rows = rows
            _, replayed = load_report(directory / replay_name(vow, pool), None)
            by_seed = {row["seed"]: row for row in adaptive_rows}
            same = sum(json.dumps(row, sort_keys=True) == json.dumps(by_seed.get(row["seed"]), sort_keys=True)
                       for row in replayed)
            gates = cell_gates(vow, pool, stats, adaptive_rows, (same, len(replayed)))
            cells[vow, pool] = {"stats": stats, "gates": gates,
                                "intervals": cell_intervals(vow, pool, stats, adaptive_rows, gates[-1][-1])}
    _require(len(identity) == 1, f"reports come from more than one build: {sorted(identity)}")
    _require(len(weights) == 1, f"committed arms weigh their glass differently: {sorted(map(str, weights))}")
    _require(len(plays) == 1, f"reports come from more than one player: {sorted(plays)}")
    commit, content = identity.pop()
    commit_weight, off_weight = weights.pop()
    return {"seeds": seeds, "commit": commit, "content": content, "cells": cells, "play": plays.pop(),
            "weights": None if commit_weight is None and off_weight is None else (commit_weight, off_weight)}


def render(result: dict[str, Any], wall: float | None = None) -> str:
    first, last = result["seeds"]
    lines = [f"Head `{result['commit']}`, content SHA-256 `{result['content'][:12]}...`; "
             f"Duskblade, seeds {first}-{last} ({last - first + 1} paired per arm), shipping incentives, "
             f"{result.get('play', 'greedy')} player."
             + (" Committed arms weigh their own glass x{} and other coloured glass x{} (--way-weights)."
                .format(*result["weights"]) if result.get("weights") is not None else "")
             + (f" Wall time {wall:.0f} s." if wall is not None else "")]
    for (vow, pool), cell in result["cells"].items():
        stats = cell["stats"]
        lines += ["", f"### V{vow}, {pool} pool", "",
                  "| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1 "
                  "| True by end of Act 2 | Stalls | Errors |",
                  "|---|---:|---:|---|---:|---:|---:|---:|---:|"]
        for arm, row in stats.items():
            low, high = row["wilson"]
            reach = [pct(row[key]) if key in row else "-" for key in ("own", "steady1", "true2")]
            lines.append(f"| {arm} | {row['wins']}/{row['n']} | {pct(row['rate'])} | "
                         f"{pct(low)}-{pct(high)} | {' | '.join(reach)} | {row['stalls']} | {row['errors']} |")
        lines += ["", "| Per fight | Shatters | Kindles | Embers spent | Cracked | Embers gained |",
                  "|---|---:|---:|---:|---:|---:|"]
        for arm, row in stats.items():
            lines.append(f"| {arm} | " + " | ".join(f"{row['rates'][key]:.2f}" for key in RATES) + " |")
        if all(row["feel"] is not None for row in stats.values()):
            lines += ["", "| Feel | Fights | Turns per fight | HP lost per fight | Close calls (won fights "
                      "ending under 20% HP) | Way expression (fights) | Deaths Act 1 / 2 / 3 |",
                      "|---|---:|---:|---:|---:|---:|---|"]
            for arm, row in stats.items():
                f = row["feel"]
                close, shown = interval(f["close"], f["won"]), interval(f["shown"], f["fights"])
                lines.append(f"| {arm} | {f['fights']} | {f['turns']:.2f} | {f['hpLost']:.2f} | "
                             f"{show(close, f['won'])} | {show(shown, f['fights'])} | "
                             + " / ".join(str(d) for d in f["deaths"]) + " |")
        lines += ["", "| Gate | Measured | Threshold | Verdict | 95% interval | 95% verdict |",
                  "|---|---|---|---|---|---|"]
        lines += [f"| {gate} | {measured} | {threshold} | {outcome} | {span} | {sure} |"
                  for (gate, measured, threshold, outcome), (span, sure)
                  in zip(cell["gates"], cell["intervals"])]
    lines += ["", "G7 here covers stalls, errors and a replay of arm A's first "
              f"{REPLAY} seeds per cell. The CEM stress and the save-lineage check belong to the "
              "exam; B, the bot round, reads this table played by the search player (--play search)."]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--seeds", help=f"FIRST-LAST inclusive (default {DEFAULT_SEEDS[0]}-{DEFAULT_SEEDS[1]})")
    parser.add_argument("--quick", action="store_true",
                        help=f"{QUICK_SEEDS[1] - QUICK_SEEDS[0] + 1} seeds, {QUICK_SEEDS[0]}-{QUICK_SEEDS[1]}")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--out-dir", type=Path, help="new or empty directory for reports and logs")
    parser.add_argument("--from-dir", type=Path, help="grade the reports an earlier run saved")
    parser.add_argument("--content", type=Path,
                        help="run on this catalogue instead of content/full-content.json")
    parser.add_argument("--play", choices=PLAYS, default="greedy",
                        help="who plays the fights: the greedy pilot or readout 8's search player")
    parser.add_argument("--vows", default="0,5",
                        help="the vows whose cells to run or grade (default 0,5): a split table runs "
                             "each vow on its own seed range")
    parser.add_argument("--way-weights",
                        help="COMMIT/OFF: the committed arms' weights for their own and other coloured "
                             "glass instead of the pilot's 3.0/0.5, e.g. 2.0/1.0 (a splash arm)")
    opts = parser.parse_args(argv)
    if opts.quick and opts.seeds:
        parser.error("--quick and --seeds are exclusive")
    if opts.content is not None and (opts.from_dir is not None or not opts.content.is_file()):
        parser.error("--content must name an existing file and cannot re-grade saved reports")
    if opts.way_weights is not None and opts.from_dir is not None:
        parser.error("--way-weights cannot re-grade saved reports")
    try:
        seeds = QUICK_SEEDS if opts.quick else parse_seeds(opts.seeds) if opts.seeds else DEFAULT_SEEDS
        weights = parse_weights(opts.way_weights) if opts.way_weights is not None else None
        vows = parse_vows(opts.vows)
    except ValueError as exc:
        parser.error(str(exc))
    if not 1 <= opts.jobs <= 16:
        parser.error("--jobs must be 1..16")
    wall = None
    directory = opts.from_dir
    if directory is None:
        directory = opts.out_dir or Path(tempfile.mkdtemp(prefix="glassvow-ways-"))
        if directory.exists() and any(directory.iterdir()):
            parser.error("--out-dir must be new or empty; saved readouts are never overwritten")
        directory.mkdir(parents=True, exist_ok=True)
        print(f"reports: {directory}", file=sys.stderr)
        start = time.monotonic()
        content = opts.content.resolve() if opts.content is not None else None
        run_jobs(jobs(opts.godot, seeds, directory.resolve(), content, weights, opts.play, vows), directory,
                 opts.jobs)
        wall = time.monotonic() - start
    print(render(grade(directory, seeds, vows), wall))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"balance_ways: {exc}", file=sys.stderr)
        sys.exit(1)

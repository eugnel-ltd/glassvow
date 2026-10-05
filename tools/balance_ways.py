#!/usr/bin/env python3
"""Flame lock readout: the section-11 cell table and gates G1-G7.

docs/design/2026-09-29-dusk-flame/README.md, section 11. Runs a class (--aspect,
default the Duskblade) over vows {0, 5} x pool states {fresh, full} x paired
seeds (a class that unlocks later, one whose content row names an `unlock`, reads
`entry` in `fresh`'s place, at fresh's thresholds: the Ashwarden lock's section 10),
with common random numbers across its arms: one committed pilot C_<way>
for each way the aspect declares in content (the Duskblade's C_shatter,
C_lantern and C_edge), A (adaptive, today's arm 1), A_lit (adaptive and reading
its own flame, readout 10) and R (random build, today's arm 2). An aspect that
declares no ways has no committed arms, so nothing here can grade it: it is
refused with a message, and the commit-blind arms run through
`balance_readout.py`. Prints one Markdown table per cell and
the G1-G7 rows with PASS/FAIL against the initial thresholds; G3 and G6 read
A_lit, and are shown again against A, the commit-blind floor. A run without its flame metrics, arms whose seeds do not pair,
mixed builds or any Godot error stop the readout (exit 1): nothing is graded
on incomplete data. From readout 13, G5 is graded over the runs alive at the end of the
act in question (Steady by the end of Act 1 among runs that reach it, True by the end
of Act 2 likewise), the all-runs figure printed beside it.

Usage (repo root):
  python3 tools/balance_ways.py [--quick | --seeds 13000-13199] [--jobs 4] [--out-dir DIR]
                                [--aspect duskblade]   # the class; its ways come from content
                                [--content FILE]   # a scratch catalogue, e.g. one sweep point
                                [--way-weights 2.0/1.0]   # committed arms' own/other glass weights
                                [--play search]   # readout 8's search player on the board
                                [--pilot p9 --search s2]   # the 1.1 bots (default: 1.0's p8-d0-v3 and s1)
                                [--vows 0]   # one vow's cells only (a split table: V0 and V5 on their own seeds)
  python3 tools/balance_ways.py --from-dir DIR [--quick | --seeds A-B] [--content FILE]   # re-grade saved reports

A class's ways and pools come from content/full-content.json, or from --content when
it is given. With --content every report graded must name that file's SHA-256 in its
manifest, so a candidate catalogue that adds ways is graded by its own ways; without
it, a directory that holds a committed arm the class does not have is refused.

Seeds never touch the acceptance band 3000-5199, nor the 1.1 holdout 17000-18999
unless --holdout-1-1 is given (the A9 exam only): the simulator then records
`"holdout": "1.1"` in every manifest. A run (no --from-dir) launches Godot, so it
refuses unless the project root's override.cfg isolates the user directory
(`balance_readout_guard.py`).

Every gate is graded twice: on the point estimate (the verdict readouts 1-7 used)
and on its 95% interval (Wilson for a rate, Newcombe's hybrid score interval,
built from two Wilson intervals, for a difference). An interval that straddles
the threshold is UNDECIDED. The feel table reads the per-fight flame rows the
simulator writes from readout 8 on; older reports print "-" there.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import tempfile
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from fractions import Fraction
from pathlib import Path
from typing import Any, NamedTuple

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from balance_classes import CLASS_FILE, ClassRow, read_class  # noqa: E402
from balance_exam import REPO, run_command  # noqa: E402
from balance_readout_guard import require_isolated_user_dir  # noqa: E402
from balance_score import wilson  # noqa: E402

COMMIT_BLIND = {  # arm -> (policy way, build): the arms every class has
    "A": ("none", "adaptive"),
    "A_lit": ("none", "lit"),
    "R": ("none", "random"),
}
# Lock section 11 from readout 10: G3 and G6 read the flame-aware adaptive arm;
# the commit-blind A stays in the table as their floor.
SKILLED, FLOOR = "A_lit", "A"
VOWS = (0, 5)
POOLS = ("fresh", "full")  # the cells the gates grade for a class playable from a new Vigil
LATER_POOLS = ("entry", "full")  # a class that unlocks later reads `entry` in `fresh`'s place (template section 3)
RUN_POOLS = ("fresh", "entry", "full")  # the pools the simulator runs (`entry`: a later class's unlock)
DEFAULT_SEEDS = (13000, 13199)
QUICK_SEEDS = (13000, 13039)
ACCEPTANCE = (3000, 5199)  # lock section 11: acceptance seeds stay otherwise untouched
# The 1.1 holdout (#544 decision 7): read once, by the A9 exam, and only under --holdout-1-1. The simulator
# refuses it too unless told `--holdout=1.1` (`BalanceCatalogue.HOLDOUT_FIRST` to `HOLDOUT_LAST`), and
# records it in the manifest.
HOLDOUT_1_1 = (17000, 18999)
HOLDOUT_ID = "1.1"
REPLAY = 3  # arm A seeds re-run per cell: G7's deterministic replay
RATES = ("shatters", "kindles", "embersSpent", "cracked", "embersGained")  # as the simulator's RATE_STATS
STEADY_OR_TRUE = ("STEADY", "TRUE")


def _entry_as_fresh(floors: dict[tuple[int, str], Any]) -> dict[tuple[int, str], Any]:
    """The Ashwarden lock's section 10: the `entry` pool takes `fresh`'s place wherever the Duskblade's lock
    grades `fresh`, at fresh's thresholds; so V5 `entry` is ungraded wherever V5 `fresh` is."""
    return floors | {(vow, "entry"): floor for (vow, pool), floor in floors.items() if pool == "fresh"}


# Initial thresholds of lock section 11, signed after the first readout.
G1_FLOOR = _entry_as_fresh({(0, "full"): Fraction(50, 100), (5, "full"): Fraction(25, 100),
                            (0, "fresh"): Fraction(40, 100)})
G2_SPREAD = Fraction(10, 100)
G3_BELOW, G3_ABOVE = Fraction(3, 100), Fraction(15, 100)
G4_GAP = Fraction(25, 100)
G4_CEILING = {0: Fraction(35, 100), 5: Fraction(15, 100)}
# G5: (Steady by the end of Act 1, True by the end of Act 2); None is not graded. From
# readout 13 each is graded over the runs alive at that act's end (reachability is a
# question about the flame, not survival). The fresh-pool figure is readout 5's; like
# G1, fresh is graded at V0 only.
G5_FLOOR = _entry_as_fresh({(0, "full"): (Fraction(70, 100), Fraction(40, 100)),
                            (5, "full"): (Fraction(70, 100), Fraction(40, 100)),
                            (0, "fresh"): (Fraction(40, 100), None)})
G6_MAX, G6_HELD, G6_WAYS = Fraction(60, 100), Fraction(20, 100), 2
PLAYS = ("greedy", "search")
# The bots (#544 P6): the pilot that builds every run, and the search player that plays its fights
# under --play search. The first of each is 1.0's instrument of record (docs/rc-bar.md P9) and the
# default; the second is the 1.1 instrument. Every simulator command names them.
PILOTS = ("p8-d0-v3", "p9")
SEARCHES = ("s1", "s2", "s3")
# Readout 8's feel proxies: a won fight the hero leaves under this share of max HP
# is a close call.
CLOSE_CALL = Fraction(20, 100)


def arm_policy(arm: str) -> tuple[str, str]:
    """The (policy way, build) an arm name stands for: C_<way> commits to a way; the replay is arm A."""
    if arm.startswith("C_"):
        return arm[2:], "adaptive"
    if arm == "replay":
        return COMMIT_BLIND["A"]
    if arm not in COMMIT_BLIND:
        raise ValueError(f"unknown arm {arm!r}")
    return COMMIT_BLIND[arm]


class Roster(NamedTuple):
    """One class's arms: a committed pilot for each way it declares, then the commit-blind arms."""
    aspect: str
    name: str
    ways: tuple[str, ...]
    rates: tuple[str, ...]  # the per-fight stats every run row carries
    pools: tuple[str, ...] = POOLS  # the pools its gates grade: POOLS, or LATER_POOLS for a class that unlocks later
    content: str | None = None  # the SHA-256 of a given catalogue (--content): every report read must name it

    @property
    def arms(self) -> dict[str, tuple[str, str]]:
        """arm -> (policy way, build), committed arms first."""
        return {arm: arm_policy(arm) for arm in self.committed} | COMMIT_BLIND

    @property
    def committed(self) -> tuple[str, ...]:
        return tuple(f"C_{way}" for way in self.ways)

    def require_ways(self) -> None:
        if not self.ways:
            raise ValueError(
                f"{self.aspect} declares no ways in content, so it has no committed arms, and the gates that "
                f"read them cannot be graded; its commit-blind arms ({', '.join(COMMIT_BLIND)}) run with "
                "`balance_readout.py run --aspect`")

    def check_arms(self, arms: list[str]) -> None:
        unknown = [arm for arm in arms if arm not in self.arms]
        if unknown:
            if not self.ways and any(arm.startswith("C_") for arm in unknown):
                self.require_ways()
            raise ValueError(f"unknown arms {unknown}; {self.aspect}'s arms are {list(self.arms)}")

    def cell(self, cell: str) -> tuple[int, str]:
        """`v0-entry` -> (0, "entry"), refused unless it is one of this class's graded cells."""
        head, _, pool = cell.partition("-")
        if not (head.startswith("v") and head[1:].isdigit() and int(head[1:]) in VOWS and pool in self.pools):
            raise ValueError(f"{cell!r} is not a cell of {self.aspect}: v<vow>-<pool> with vow in {VOWS} and pool "
                             f"in {self.pools}")
        return int(head[1:]), pool

    def unbound(self) -> "Roster":
        """The class without its catalogue's SHA-256, for reports read beside it on other content: a reference
        table, or the base of a paired change."""
        return self._replace(content=None)

    def check_content(self, name: str, manifest: dict[str, Any]) -> None:
        """With a given catalogue, a report that names other content was not played on it: refused."""
        if self.content is not None and manifest.get("contentFileSha256") != self.content:
            raise ValueError(f"{name}: its manifest names content {manifest.get('contentFileSha256')!r}, not "
                             f"--content's {self.content}; grade reports with the catalogue they ran on")

    def check_cell_arms(self, directory: Path, vow: int, pool: str) -> None:
        """Refuses a directory holding a committed arm of the cell that this class does not have: its reports
        ran on a catalogue with other ways, and grading them by these ways would leave one out."""
        prefix = f"v{vow}-{pool}-"
        held = {path.name[len(prefix):-len(".json")] for path in directory.glob(f"{prefix}C_*.json")}
        extra = sorted(held - set(self.committed))
        if extra:
            raise ValueError(f"{directory}: {', '.join(prefix + arm for arm in extra)} are not arms of "
                             f"{self.aspect} ({', '.join(self.committed) or 'no committed arms'}); grade them with "
                             "--content <the catalogue they ran on>")


def roster(aspect: str = "duskblade", content: Path | None = None, class_file: Path | None = None) -> Roster:
    """The arms of `aspect`: way ids and pools from content (`--content` if given), way stats from the class file
    (`CLASS_FILE` unless named)."""
    row: ClassRow = read_class(aspect, content, class_file or CLASS_FILE)
    return Roster(aspect, row.name, row.ways, RATES + tuple(stat for stat in row.stats if stat not in RATES),
                  LATER_POOLS if row.unlock else POOLS)


def grading_roster(aspect: str, content: Path | None = None) -> Roster:
    """The class as the graders read it. Its ways come from the catalogue the reports ran on, named with --content,
    and the reports' manifests check it: each must name that file's SHA-256. Without --content, the ways are
    content/full-content.json's, as `roster` reads them."""
    who = roster(aspect, content)
    return who if content is None else who._replace(content=hashlib.sha256(content.read_bytes()).hexdigest())


def check_holdout(first: int, last: int, holdout: bool = False) -> None:
    """Seeds `first`..`last` touch the 1.1 holdout only under `holdout` (--holdout-1-1, the A9 exam's), and then
    lie wholly inside it."""
    low, high = HOLDOUT_1_1
    if not holdout and first <= high and last >= low:
        raise ValueError(f"seeds {first}-{last} touch the 1.1 holdout {low}-{high} (#544 decision 7); "
                         "only the A9 exam reads it, with --holdout-1-1")
    if holdout and not low <= first <= last <= high:
        raise ValueError(f"--holdout-1-1 reads the 1.1 holdout only, and seeds {first}-{last} are not inside "
                         f"{low}-{high}")


def parse_seeds(text: str, holdout: bool = False) -> tuple[int, int]:
    """FIRST-LAST, refused where it touches the acceptance band, and where it touches the 1.1 holdout unless
    `holdout` (`check_holdout`)."""
    first, sep, last = text.partition("-")
    if not sep or not first.isdigit() or not last.isdigit() or int(first) > int(last):
        raise ValueError(f"--seeds must be FIRST-LAST with FIRST <= LAST, got {text!r}")
    seeds = int(first), int(last)
    if seeds[0] <= ACCEPTANCE[1] and seeds[1] >= ACCEPTANCE[0]:
        raise ValueError(f"seeds {text} touch the acceptance band {ACCEPTANCE[0]}-{ACCEPTANCE[1]}")
    check_holdout(*seeds, holdout)
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


def check_bots(play: str, pilot: str, search: str) -> None:
    """Refuses an unknown pilot or search player, and a search player named for greedy play."""
    if pilot not in PILOTS or search not in SEARCHES:
        raise ValueError(f"--pilot must be one of {PILOTS} and --search one of {SEARCHES}")
    if play != "search" and search != SEARCHES[0]:
        raise ValueError(f"--search {search} needs --play search")


def sim_command(godot: str, who: Roster, vow: int, pool: str, arm: str, first: int, count: int,
                out: Path, content: Path | None = None,
                weights: tuple[float, float] | None = None, play: str = "greedy",
                pilot: str = PILOTS[0], search: str = SEARCHES[0], holdout: bool = False) -> list[str]:
    """One simulator run; under `holdout` it reads the 1.1 holdout, and the simulator records it in the manifest."""
    check_bots(play, pilot, search)
    check_holdout(first, first + count - 1, holdout)
    way, build = who.arms[arm]
    return [godot, "--headless", "-s", "res://tools/balance_sim.gd", "--", f"--aspect={who.aspect}",
            f"--vow={vow}", f"--runs={count}", f"--seed0={first}", f"--pool={pool}",
            f"--way={way}", f"--build={build}", f"--pilot={pilot}", f"--out={out}"] \
        + ([f"--wayCommit={weights[0]}", f"--wayOff={weights[1]}"]
           if weights is not None and way != "none" else []) \
        + ([f"--content={content}"] if content is not None else []) \
        + ([f"--search={search}", f"--play={play}"] if play != "greedy" else []) \
        + ([f"--holdout={HOLDOUT_ID}"] if holdout else [])


def jobs(godot: str, who: Roster, seeds: tuple[int, int], directory: Path, content: Path | None = None,
         weights: tuple[float, float] | None = None,
         play: str = "greedy", vows: tuple[int, ...] = VOWS, pilot: str = PILOTS[0],
         search: str = SEARCHES[0], holdout: bool = False) -> list[tuple[str, list[str]]]:
    first, count = seeds[0], seeds[1] - seeds[0] + 1
    out: list[tuple[str, list[str]]] = []
    for vow in vows:
        for pool in who.pools:
            for arm in who.arms:
                out.append((report_name(vow, pool, arm)[:-5], sim_command(
                    godot, who, vow, pool, arm, first, count, directory / report_name(vow, pool, arm),
                    content, weights, play, pilot, search, holdout)))
            out.append((replay_name(vow, pool)[:-5], sim_command(
                godot, who, vow, pool, "A", first, min(REPLAY, count), directory / replay_name(vow, pool),
                content, None, play, pilot, search, holdout)))
    return out


def run_jobs(work: list[tuple[str, list[str]]], directory: Path, workers: int, root: Path | None = None) -> None:
    """Runs every simulator command, `workers` at a time; refuses unless `root` (the repository unless named) is
    isolated from the owner's profile."""
    require_isolated_user_dir(root or REPO)

    def run(job: tuple[str, list[str]]) -> None:
        name, command = job
        run_command(command, directory / f"{name}.log")
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for future in [pool.submit(run, job) for job in work]:
            future.result()


def _require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def _check_row(row: Any, name: str, rates_kept: tuple[str, ...]) -> None:
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
    _require(isinstance(rates, dict) and all(isinstance(rates.get(key), (int, float)) for key in rates_kept),
             f"{where}: missing per-fight rates")


def load_report(path: Path, seeds: tuple[int, int] | None,
                rates: tuple[str, ...] = RATES) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """A report's manifest and rows; every row must carry the per-fight `rates` of its class."""
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc
    rows = report.get("runs") if isinstance(report, dict) else None
    _require(isinstance(rows, list) and bool(rows), f"{path.name}: no runs")
    for row in rows:
        _check_row(row, path.name, rates)
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
    return _alive(row, act) and acts[act]["tier"] in tiers and acts[act]["dominant"] == way


def _alive(row: dict[str, Any], act: int) -> bool:
    """Whether the run lived to the end of act `act` + 1 (it has that act's reading)."""
    return len(row["flame"]["acts"]) > act


def reach(stats: dict[str, Any], key: str) -> tuple[int, int]:
    """G5's count: (runs that reached the tier, runs alive at that act's end)."""
    return stats[key + "Alive"]


def survivor_rate(count: tuple[int, int]) -> Fraction:
    return Fraction(count[0], count[1]) if count[1] else Fraction(0)


def expressed(plays: dict[str, Any], ways: tuple[str, ...]) -> str:
    """The way a fight's coloured plays favour (affinity weight per way), or "" for a tie or none."""
    weights = {way: float(plays.get(way, 0.0)) for way in ways}
    top = max(weights.values())
    leaders = [way for way, weight in weights.items() if weight == top]
    return leaders[0] if top > 0 and len(leaders) == 1 else ""


def feel(rows: list[dict[str, Any]], way: str, ways: tuple[str, ...]) -> dict[str, Any] | None:
    """Readout 8's per-way feel proxies, or None for reports without per-fight flame rows.

    Expression is the share of fights whose coloured plays favour the arm's way
    (a committed arm's own, else the way the deck reads at the fight's start)."""
    if not all(isinstance(row["flame"].get("fights"), list) and isinstance(row.get("fights"), list)
               and len(row["flame"]["fights"]) == len(row["fights"]) for row in rows):
        return None
    fights = [(fight, flame) for row in rows for fight, flame in zip(row["fights"], row["flame"]["fights"])]
    won = [flame for fight, flame in fights if fight["result"] == "win"]
    close = sum(Fraction(int(flame["hp"]), max(1, int(flame["maxHp"]))) < CLOSE_CALL for flame in won)
    shown = sum(expressed(flame["plays"], ways) == (way if way != "none" else flame["dominant"])
                for _, flame in fights)
    deaths = Counter(row["fights"][-1]["act"] for row in rows if row["outcome"] != "win" and row["fights"])
    return {"fights": len(fights), "turns": sum(fight["turns"] for fight, _ in fights) / max(1, len(fights)),
            "hpLost": sum(fight["hpLost"] for fight, _ in fights) / max(1, len(fights)),
            "won": len(won), "close": close, "shown": shown,
            "deaths": tuple(deaths.get(act, 0) for act in (1, 2, 3))}


def arm_stats(rows: list[dict[str, Any]], way: str, who: Roster) -> dict[str, Any]:
    wins = sum(row["outcome"] == "win" for row in rows)
    stats = {
        "feel": feel(rows, way, who.ways),
        "n": len(rows), "wins": wins, "rate": Fraction(wins, len(rows)),
        "wilson": wilson(wins, len(rows)),
        "stalls": sum(row["outcome"] == "stall" for row in rows),
        "errors": sum(row["outcome"] == "error" or bool(row.get("error")) for row in rows),
        "rates": {key: sum(row["flame"]["rates"][key] for row in rows) / len(rows) for key in who.rates},
    }
    if way != "none":
        stats["own"] = _fraction(rows, lambda row: row["flame"]["end"]["dominant"] == way)
        stats["steady1"] = _fraction(rows, lambda row: _reached(row, 0, STEADY_OR_TRUE, way))
        stats["true2"] = _fraction(rows, lambda row: _reached(row, 1, ("TRUE",), way))
        for key, act, tiers in (("steady1", 0, STEADY_OR_TRUE), ("true2", 1, ("TRUE",))):
            stats[key + "Alive"] = (sum(_reached(row, act, tiers, way) for row in rows),
                                    sum(_alive(row, act) for row in rows))
    return stats


# The fields of a run row that the verdict's evidence reads (docs/rc-bar.md P9, content equivalence):
# the per-cell tables and gates here (`arm_stats`, `feel`, `cell_gates`, `cell_intervals`, `render`),
# row B (`balance_readout_tables.row_b`) and the paired G3 (`balance_readout_stats`). A dot descends
# into an object and `[]` maps over every element of a list, so a list's length is read with its
# elements; `{rate}` and `{way}` stand for each of the class's per-fight rates and ways. The seed
# pairs runs and is not a field. `_check_row` checks only the type of a flame reading's tier and
# purity, and no figure reads their values. G7's replay compares whole rows, which no list of fields
# can name, so the equivalence comparer grades whether each replay equals its arm-A run instead.
# tests/test_balance_readout.py perturbs each field in a complete cell table: a listed field must move
# a figure and an unlisted one must move none, so a grader that reads a new field fails it.
GRADED_FIELDS = (
    "outcome", "error",  # every win rate and gate; stalls and errors (G7)
    "fights[].result", "fights[].turns", "fights[].hpLost", "fights[].act",  # the feel table; deaths by act
    "flame.end.dominant",  # own way at the end; G6
    "flame.acts[].dominant", "flame.acts[].tier",  # G5, over the runs alive at each act's end
    "flame.rates.{rate}",  # the per-fight table
    "flame.fights[].dominant", "flame.fights[].plays.{way}",  # expression (row B, the feel table)
    "flame.fights[].hp", "flame.fights[].maxHp",  # close calls (row B, the feel table)
)


def graded_fields(who: Roster) -> tuple[str, ...]:
    """GRADED_FIELDS for one class, `{rate}` and `{way}` expanded to its own rates and ways."""
    out: list[str] = []
    for path in GRADED_FIELDS:
        if "{rate}" in path:
            out += [path.format(rate=rate) for rate in who.rates]
        elif "{way}" in path:
            out += [path.format(way=way) for way in who.ways]
        else:
            out.append(path)
    return tuple(out)


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


def _g3_interval(rate: dict[str, tuple[int, int]], arm: str, best: str) -> tuple[str, str]:
    skill = difference(rate[arm], rate[best])
    return (f"{arm} - {best} {show(skill, rate[arm][1], rate[best][1], points=True)}",
            decided([at_least(skill, -float(G3_BELOW)), at_most(skill, float(G3_ABOVE))]))


def _g6_interval(adaptive_rows: list[dict[str, Any]], arm: str, ways: tuple[str, ...]) -> tuple[str, str]:
    wins = Counter(row["flame"]["end"]["dominant"] for row in adaptive_rows if row["outcome"] == "win")
    total = sum(wins.values())
    if total == 0:
        return (f"no {arm} wins", "FAIL")
    shares = {way: interval(wins.get(way, 0), total) for way in ways}
    lead = max(ways, key=lambda way: shares[way][0])
    held_sure = sum(share[1] >= G6_HELD for share in shares.values())
    held_maybe = sum(share[2] >= G6_HELD for share in shares.values())
    return (f"lead {lead} {show(shares[lead], total, unit=f' {arm} wins')}",
            decided([at_most(share, float(G6_MAX)) for share in shares.values()]
                    + [True if held_sure >= G6_WAYS else (False if held_maybe < G6_WAYS else None)]))


def cell_intervals(who: Roster, vow: int, pool: str, stats: dict[str, dict[str, Any]],
                   adaptive_rows: dict[str, list[dict[str, Any]]], point_g7: str) -> list[tuple[str, str]]:
    """Each gate of `cell_gates` on its 95% interval: (measured with interval and N, verdict)."""
    committed_arms = who.committed
    rate = {arm: (stats[arm]["wins"], stats[arm]["n"]) for arm in who.arms}
    committed = {arm: stats[arm]["rate"] for arm in committed_arms}
    best, worst = max(committed, key=committed.get), min(committed, key=committed.get)  # as cell_gates
    rows: list[tuple[str, str]] = []
    floor = G1_FLOOR.get((vow, pool))
    spans = {arm: interval(*rate[arm]) for arm in committed_arms}
    rows.append((f"worst {worst} {show(spans[worst], rate[worst][1])}",
                 "n/a" if floor is None else decided([at_least(spans[arm], float(floor)) for arm in committed_arms])))
    pairs = [(a, b) for i, a in enumerate(committed_arms) for b in committed_arms[i + 1:]]
    spread = {pair: difference(rate[pair[0]], rate[pair[1]]) for pair in pairs}
    widest = difference(rate[best], rate[worst])
    rows.append((f"{best} - {worst} {show(widest, rate[best][1], rate[worst][1], points=True)}",
                 decided([True if max(abs(d[1]), abs(d[2])) <= G2_SPREAD
                          else (False if d[1] > G2_SPREAD or d[2] < -G2_SPREAD else None)
                          for d in spread.values()])))
    rows.append(_g3_interval(rate, SKILLED, best))
    gap, random_rate = difference(rate["R"], rate[worst]), interval(*rate["R"])
    rows.append((f"R - {worst} {show(gap, rate['R'][1], rate[worst][1], points=True)}; "
                 f"R {show(random_rate, rate['R'][1])}",
                 decided([at_most(gap, -float(G4_GAP)), below(random_rate, float(G4_CEILING[vow]))])))
    floors = G5_FLOOR.get((vow, pool))
    steady = {arm: interval(*reach(stats[arm], "steady1")) for arm in committed_arms}
    true = {arm: interval(*reach(stats[arm], "true2")) for arm in committed_arms}
    low_arm = min(committed_arms, key=lambda arm: steady[arm][0])
    text = f"Steady min {low_arm} {show(steady[low_arm], reach(stats[low_arm], 'steady1')[1], unit=' alive')}"
    if floors is None:
        rows.append((text, "n/a"))
    else:
        checks = [at_least(steady[arm], float(floors[0])) for arm in committed_arms]
        if floors[1] is not None:
            true_arm = min(committed_arms, key=lambda arm: true[arm][0])
            text += (f"; True min {true_arm} "
                     f"{show(true[true_arm], reach(stats[true_arm], 'true2')[1], unit=' alive')}")
            checks += [at_least(true[arm], float(floors[1])) for arm in committed_arms]
        rows.append((text, decided(checks)))
    rows.append(_g6_interval(adaptive_rows[SKILLED], SKILLED, who.ways))
    rows.append(("counts (no interval)", point_g7))
    rows.append(_g3_interval(rate, FLOOR, best))
    rows.append(_g6_interval(adaptive_rows[FLOOR], FLOOR, who.ways))
    return rows


def _g3(stats: dict[str, dict[str, Any]], arm: str, best_arm: str, gate: str) -> tuple[str, ...]:
    adaptive, best = stats[arm]["rate"], stats[best_arm]["rate"]
    return (gate, f"{arm} {pct(adaptive)} vs best {pct(best)} ({pp(adaptive - best)})", "-3 pp to +15 pp",
            verdict(best - G3_BELOW <= adaptive <= best + G3_ABOVE))


def _g6(adaptive_rows: list[dict[str, Any]], arm: str, gate: str, ways: tuple[str, ...]) -> tuple[str, ...]:
    wins = Counter(row["flame"]["end"]["dominant"] for row in adaptive_rows if row["outcome"] == "win")
    total = sum(wins.values())
    shares = {way: Fraction(wins.get(way, 0), total) for way in ways} if total else {}
    return (gate, ", ".join(f"{way} {pct(shares[way])}" for way in ways) + f" of {total} {arm} wins"
            if total else f"no {arm} wins", "no way > 60%, >= 2 ways >= 20%",
            verdict(bool(shares) and max(shares.values()) <= G6_MAX
                    and sum(share >= G6_HELD for share in shares.values()) >= G6_WAYS))


def cell_gates(who: Roster, vow: int, pool: str, stats: dict[str, dict[str, Any]],
               adaptive_rows: dict[str, list[dict[str, Any]]], replay: tuple[int, int]) -> list[tuple[str, ...]]:
    """G1-G7, G3 and G6 on the flame-aware A_lit, then G3 and G6 again on A, the floor."""
    committed_arms = who.committed
    committed = {arm: stats[arm]["rate"] for arm in committed_arms}
    best_arm, worst_arm = max(committed, key=committed.get), min(committed, key=committed.get)
    best, worst = committed[best_arm], committed[worst_arm]
    random_arm = stats["R"]["rate"]
    floor = G1_FLOOR.get((vow, pool))
    alive = {arm: {key: survivor_rate(reach(stats[arm], key)) for key in ("steady1", "true2")}
             for arm in committed_arms}
    steady = min(committed_arms, key=lambda arm: alive[arm]["steady1"])
    true = min(committed_arms, key=lambda arm: alive[arm]["true2"])
    floors = G5_FLOOR.get((vow, pool))
    reach_text = "no threshold for this cell" if floors is None else (
        f">= {pct(floors[0])} and >= {pct(floors[1])} for every committed way, of runs alive"
        if floors[1] is not None
        else f">= {pct(floors[0])} Steady for every committed way, of runs alive; True not graded")
    stalls = sum(stats[arm]["stalls"] for arm in who.arms)
    errors = sum(stats[arm]["errors"] for arm in who.arms)
    same, replayed = replay
    return [
        ("G1 viability: each committed way wins", f"worst {worst_arm} {pct(worst)}",
         f">= {pct(floor)}" if floor is not None else "no threshold for this cell",
         verdict(worst >= floor) if floor is not None else "n/a"),
        ("G2 parity: the ways are comparable", f"{pp(best - worst, False)} ({best_arm} - {worst_arm})",
         f"<= {pp(G2_SPREAD, False)}", verdict(best - worst <= G2_SPREAD)),
        _g3(stats, SKILLED, best_arm, "G3 skill: reading offers and flame pays, commitment is no trap"),
        ("G4 random loses: scattering cannot win",
         f"R {pct(random_arm)} vs worst {pct(worst)} ({pp(random_arm - worst)})",
         f"R <= worst - 25 pp and R < {pct(G4_CEILING[vow])}",
         verdict(random_arm <= worst - G4_GAP and random_arm < G4_CEILING[vow])),
        ("G5 reachability: insisting gets there",
         f"Steady by end of Act 1 min {pct(alive[steady]['steady1'])} of runs alive ({steady}; "
         f"all runs {pct(stats[steady]['steady1'])}); True by end of Act 2 min "
         f"{pct(alive[true]['true2'])} of runs alive ({true}; all runs {pct(stats[true]['true2'])})",
         reach_text,
         "n/a" if floors is None else verdict(alive[steady]["steady1"] >= floors[0]
                                             and (floors[1] is None or alive[true]["true2"] >= floors[1]))),
        _g6(adaptive_rows[SKILLED], SKILLED, "G6 diversity: different adaptive runs are different", who.ways),
        ("G7 guards: nothing stalls, errors or replays differently",
         f"{stalls} stalls, {errors} errors; replay {same}/{replayed} identical",
         "zero, zero, all identical", verdict(stalls == 0 and errors == 0 and same == replayed)),
        _g3(stats, FLOOR, best_arm, "G3 floor: the commit-blind adaptive arm"),
        _g6(adaptive_rows[FLOOR], FLOOR, "G6 floor: the commit-blind adaptive arm", who.ways),
    ]


def parse_vows(text: str) -> tuple[int, ...]:
    vows = tuple(sorted({int(part) for part in text.split(",") if part.strip().isdigit()}))
    if not vows or any(vow not in VOWS for vow in vows) or len(vows) != len(text.split(",")):
        raise ValueError(f"--vows must name some of {VOWS} separated by commas, got {text!r}")
    return vows


def grade(who: Roster, directory: Path, seeds: tuple[int, int], vows: tuple[int, ...] = VOWS) -> dict[str, Any]:
    """Load every report of the class's cell table, check pairing and provenance, grade.

    Refused for an aspect with no ways: the gates read its committed arms."""
    who.require_ways()
    cells: dict[tuple[int, str], Any] = {}
    identity: set[tuple[str, str]] = set()
    weights: set[tuple[Any, Any]] = set()
    plays: set[str] = set()
    bots: set[tuple[str, str]] = set()
    for vow in vows:
        for pool in who.pools:
            who.check_cell_arms(directory, vow, pool)
            stats: dict[str, dict[str, Any]] = {}
            adaptive_rows: dict[str, list[dict[str, Any]]] = {}
            for arm, (way, build) in who.arms.items():
                manifest, rows = load_report(directory / report_name(vow, pool, arm), seeds, who.rates)
                who.check_content(report_name(vow, pool, arm), manifest)
                _require(manifest.get("vow") == vow and manifest.get("pool") == pool
                         and manifest.get("way") == way and manifest.get("build") == build
                         and manifest.get("aspect") == who.aspect,
                         f"{report_name(vow, pool, arm)}: manifest is not this cell and arm")
                identity.add((str(manifest.get("commit")), str(manifest.get("contentFileSha256"))))
                plays.add(str(manifest.get("play", "greedy")))
                search = manifest.get("search") if isinstance(manifest.get("search"), dict) else {}
                bots.add((str(manifest.get("pilot")), str(search.get("version", "-"))))
                if arm in who.committed:
                    policy = manifest.get("policy") if isinstance(manifest.get("policy"), dict) else {}
                    weights.add((policy.get("wayCommit"), policy.get("wayOff")))
                stats[arm] = arm_stats(rows, way, who)
                if arm in (SKILLED, FLOOR):
                    adaptive_rows[arm] = rows
            replay_manifest, replayed = load_report(directory / replay_name(vow, pool), None, who.rates)
            who.check_content(replay_name(vow, pool), replay_manifest)
            by_seed = {row["seed"]: row for row in adaptive_rows[FLOOR]}
            same = sum(json.dumps(row, sort_keys=True) == json.dumps(by_seed.get(row["seed"]), sort_keys=True)
                       for row in replayed)
            gates = cell_gates(who, vow, pool, stats, adaptive_rows, (same, len(replayed)))
            cells[vow, pool] = {"stats": stats, "gates": gates,
                                "intervals": cell_intervals(who, vow, pool, stats, adaptive_rows, gates[6][-1])}
    _require(len(identity) == 1, f"reports come from more than one build: {sorted(identity)}")
    _require(len(weights) == 1, f"committed arms weigh their glass differently: {sorted(map(str, weights))}")
    _require(len(plays) == 1, f"reports come from more than one player: {sorted(plays)}")
    _require(len(bots) == 1, f"reports come from more than one pilot or search player: {sorted(bots)}")
    commit, content = identity.pop()
    commit_weight, off_weight = weights.pop()
    pilot, search = bots.pop()
    return {"roster": who, "seeds": seeds, "commit": commit, "content": content, "cells": cells, "play": plays.pop(),
            "pilot": pilot, "search": search,
            "weights": None if commit_weight is None and off_weight is None else (commit_weight, off_weight)}


def bots_label(result: dict[str, Any]) -> str:
    """`search player s2, pilot p9`: who played the table's fights and who built its runs."""
    play = result.get("play", "greedy")
    search = f" {result['search']}" if play == "search" and result.get("search") not in (None, "-") else ""
    pilot = f", pilot {result['pilot']}" if result.get("pilot") not in (None, "None") else ""
    return f"{play} player{search}{pilot}"


def render(result: dict[str, Any], wall: float | None = None) -> str:
    first, last = result["seeds"]
    lines = [f"Head `{result['commit']}`, content SHA-256 `{result['content'][:12]}...`; "
             f"{result['roster'].name}, seeds {first}-{last} ({last - first + 1} paired per arm), shipping incentives, "
             f"{bots_label(result)}."
             + (" Committed arms weigh their own glass x{} and other coloured glass x{} (--way-weights)."
                .format(*result["weights"]) if result.get("weights") is not None else "")
             + (f" Wall time {wall:.0f} s." if wall is not None else "")]
    for (vow, pool), cell in result["cells"].items():
        stats = cell["stats"]
        lines += ["", f"### V{vow}, {pool} pool", "",
                  "| Arm | Wins | Win rate | Wilson 95% | Own way at end | Steady by end of Act 1, "
                  "all runs (of runs alive) | True by end of Act 2, all runs (of runs alive) | Stalls | Errors |",
                  "|---|---:|---:|---|---:|---:|---:|---:|---:|"]
        for arm, row in stats.items():
            low, high = row["wilson"]
            cells = [pct(row["own"]) if "own" in row else "-"] + [
                f"{pct(row[key])} ({pct(survivor_rate(reach(row, key)))} of {reach(row, key)[1]})"
                if key in row else "-" for key in ("steady1", "true2")]
            lines.append(f"| {arm} | {row['wins']}/{row['n']} | {pct(row['rate'])} | "
                         f"{pct(low)}-{pct(high)} | {' | '.join(cells)} | {row['stalls']} | {row['errors']} |")
        rates = result["roster"].rates
        lines += ["", "| Per fight | " + " | ".join(re.sub(r"(?=[A-Z])", " ", key).capitalize() for key in rates) + " |",
                  "|---|" + "---:|" * len(rates)]
        for arm, row in stats.items():
            lines.append(f"| {arm} | " + " | ".join(f"{row['rates'][key]:.2f}" for key in rates) + " |")
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


def bots_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--pilot", choices=PILOTS, default=PILOTS[0],
                        help="the pilot that builds every run (default p8-d0-v3, 1.0's; p9 is 1.1's)")
    parser.add_argument("--search", choices=SEARCHES, default=SEARCHES[0],
                        help="the search player under --play search (default s1, 1.0's; s2 and s3 are 1.1's)")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--aspect", default="duskblade",
                        help="the class to run or grade; its ways are the content's (default duskblade)")
    parser.add_argument("--seeds", help=f"FIRST-LAST inclusive (default {DEFAULT_SEEDS[0]}-{DEFAULT_SEEDS[1]})")
    parser.add_argument("--quick", action="store_true",
                        help=f"{QUICK_SEEDS[1] - QUICK_SEEDS[0] + 1} seeds, {QUICK_SEEDS[0]}-{QUICK_SEEDS[1]}")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--out-dir", type=Path, help="new or empty directory for reports and logs")
    parser.add_argument("--from-dir", type=Path, help="grade the reports an earlier run saved")
    parser.add_argument("--content", type=Path,
                        help="run on this catalogue instead of content/full-content.json, or re-grade reports "
                             "run on it: the class's ways come from it, and every report must name its SHA-256")
    parser.add_argument("--play", choices=PLAYS, default="greedy",
                        help="who plays the fights: the greedy pilot or readout 8's search player")
    bots_options(parser)
    parser.add_argument("--vows", default="0,5",
                        help="the vows whose cells to run or grade (default 0,5): a split table runs "
                             "each vow on its own seed range")
    parser.add_argument("--way-weights",
                        help="COMMIT/OFF: the committed arms' weights for their own and other coloured "
                             "glass instead of the pilot's 3.0/0.5, e.g. 2.0/1.0 (a splash arm)")
    parser.add_argument("--holdout-1-1", action="store_true",
                        help="the A9 exam only: --seeds lie inside the 1.1 holdout 17000-18999, which is "
                             "otherwise refused; the simulator records it in every manifest")
    opts = parser.parse_args(argv)
    if opts.quick and opts.seeds:
        parser.error("--quick and --seeds are exclusive")
    if opts.content is not None and not opts.content.is_file():
        parser.error("--content must name an existing file")
    if opts.way_weights is not None and opts.from_dir is not None:
        parser.error("--way-weights cannot re-grade saved reports")
    if opts.holdout_1_1 and not opts.seeds:
        parser.error("--holdout-1-1 needs --seeds inside the 1.1 holdout")
    try:
        seeds = QUICK_SEEDS if opts.quick else parse_seeds(opts.seeds, opts.holdout_1_1) if opts.seeds \
            else DEFAULT_SEEDS
        weights = parse_weights(opts.way_weights) if opts.way_weights is not None else None
        vows = parse_vows(opts.vows)
        check_bots(opts.play, opts.pilot, opts.search)
        who = grading_roster(opts.aspect, opts.content)
        who.require_ways()
    except ValueError as exc:
        parser.error(str(exc))
    if not 1 <= opts.jobs <= 16:
        parser.error("--jobs must be 1..16")
    wall = None
    directory = opts.from_dir
    if directory is None:
        require_isolated_user_dir(REPO)  # before anything is written
        directory = opts.out_dir or Path(tempfile.mkdtemp(prefix="glassvow-ways-"))
        if directory.exists() and any(directory.iterdir()):
            parser.error("--out-dir must be new or empty; saved readouts are never overwritten")
        directory.mkdir(parents=True, exist_ok=True)
        print(f"reports: {directory}", file=sys.stderr)
        start = time.monotonic()
        content = opts.content.resolve() if opts.content is not None else None
        run_jobs(jobs(opts.godot, who, seeds, directory.resolve(), content, weights, opts.play, vows, opts.pilot,
                      opts.search, opts.holdout_1_1), directory,
                 opts.jobs)
        wall = time.monotonic() - start
    print(render(grade(who, directory, seeds, vows), wall))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"balance_ways: {exc}", file=sys.stderr)
        sys.exit(1)

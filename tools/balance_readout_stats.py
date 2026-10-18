"""Readout statistics: paired seeds and whole-run B2 sensitivity.

Pure functions over run rows; B2 also reads aligned per-fight arrays. No Godot, no files.

Paired change: of the seeds on which two configurations disagree, how many does the new
one win and lose. The p-value is the exact two-sided binomial (McNemar) test on those
discordant seeds at p = 0.5, capped at 1.

Paired G3: P(A_lit wins) - P(best committed wins) on common seeds, with Newcombe's (1998)
method 10 hybrid score interval for a difference of paired proportions: the two marginal
Wilson intervals combined through the phi correlation of the 2x2 table. The grader's own
G3 interval (`balance_ways.difference`, Newcombe method 10 for independent samples) ignores
that every arm plays the same seeds, so the paired interval is never wider.
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass
from fractions import Fraction
from typing import Any

import balance_ways as bw

Rows = list[dict[str, Any]]


def won(row: dict[str, Any]) -> bool:
    return row["outcome"] == "win"


def binomial_p(k: int, n: int) -> float:
    """Exact two-sided p of k of n at p = 0.5 (twice the smaller tail, at most 1)."""
    if n == 0:
        return 1.0
    return min(1.0, 2 * sum(math.comb(n, i) for i in range(0, min(k, n - k) + 1)) / 2 ** n)


def _by_seed(rows: Rows) -> dict[int, dict[str, Any]]:
    return {row["seed"]: row for row in rows}


def require_same_seeds(new: Rows, base: Rows, label: str) -> None:
    if [row["seed"] for row in new] != [row["seed"] for row in base]:
        raise ValueError(f"{label}: the two runs do not play the same seeds")


@dataclass(frozen=True)
class PairedChange:
    n: int
    gained: int  # seeds the new run wins and the base loses
    lost: int  # seeds the new run loses and the base wins
    identical: int  # seeds whose whole row is identical
    p: float

    @property
    def points(self) -> float:
        return (self.gained - self.lost) / self.n


def paired_change(new: Rows, base: Rows, label: str = "paired") -> PairedChange:
    require_same_seeds(new, base, label)
    old = _by_seed(base)
    gained = sum(won(row) and not won(old[row["seed"]]) for row in new)
    lost = sum(not won(row) and won(old[row["seed"]]) for row in new)
    identical = sum(row == old[row["seed"]] for row in new)
    return PairedChange(len(new), gained, lost, identical, binomial_p(gained, gained + lost))


@dataclass(frozen=True)
class PairedDifference:
    delta: float
    low: float
    high: float
    both: int
    only_a: int
    only_c: int
    neither: int
    phi: float


def paired_difference(a_rows: Rows, c_rows: Rows, label: str = "paired") -> PairedDifference:
    """P(A wins) - P(C wins) on common seeds, with Newcombe's paired 95% interval."""
    require_same_seeds(a_rows, c_rows, label)
    c_won = {row["seed"]: won(row) for row in c_rows}
    both = only_a = only_c = neither = 0
    for row in a_rows:
        x, y = won(row), c_won[row["seed"]]
        both += x and y
        only_a += x and not y
        only_c += y and not x
        neither += not x and not y
    n = both + only_a + only_c + neither
    p1, p2 = (both + only_a) / n, (both + only_c) / n
    l1, u1 = bw.wilson(both + only_a, n)
    l2, u2 = bw.wilson(both + only_c, n)
    den = (both + only_a) * (only_c + neither) * (both + only_c) * (only_a + neither)
    phi = (both * neither - only_a * only_c) / math.sqrt(den) if den > 0 else 0.0
    delta = p1 - p2
    low = delta - math.sqrt(max(0.0, (p1 - l1) ** 2 - 2 * phi * (p1 - l1) * (u2 - p2) + (u2 - p2) ** 2))
    high = delta + math.sqrt(max(0.0, (u1 - p1) ** 2 - 2 * phi * (u1 - p1) * (p2 - l2) + (p2 - l2) ** 2))
    return PairedDifference(delta, low, high, both, only_a, only_c, neither, phi)


def g3_point(delta: float) -> str:
    """G3's point verdict, from the grader's own thresholds."""
    eps = 1e-12
    return "PASS" if -float(bw.G3_BELOW) - eps <= delta <= float(bw.G3_ABOVE) + eps else "FAIL"


def g3_interval(diff: PairedDifference) -> str:
    """G3's interval verdict: the interval wholly inside the band passes, wholly outside fails."""
    below, above = -float(bw.G3_BELOW), float(bw.G3_ABOVE)
    if diff.low >= below and diff.high <= above:
        return "PASS"
    if diff.high < below or diff.low > above:
        return "FAIL"
    return "UNDECIDED"


def best_committed(who: bw.Roster, rows_by_arm: dict[str, Rows]) -> str:
    """The committed arm with the most wins; the first of a tie, as the grader picks it."""
    return max(who.committed, key=lambda arm: sum(won(row) for row in rows_by_arm[arm]))


B2_RESAMPLES = 2000
B2_SEED = 0


@dataclass(frozen=True)
class ClusteredRate:
    """A pooled point and whole-run percentile interval; undefined draws invalidate the interval."""
    point: float | None
    low: float | None
    high: float | None
    undefined: int

    @property
    def span(self) -> tuple[float, float, float] | None:
        if self.point is None or self.low is None or self.high is None:
            return None
        return self.point, self.low, self.high


@dataclass(frozen=True)
class B2Sensitivity:
    expression: ClusteredRate
    close: ClusteredRate
    runs: int
    resamples: int
    seed: int


def _finite_number(value: Any) -> bool:
    return ((type(value) is int and value >= 0)
            or (type(value) is float and math.isfinite(value) and value >= 0))


def _b2_counts(rows: Rows, way: str, ways: tuple[str, ...], label: str) -> list[tuple[int, int, int, int]]:
    """Validate B2's aligned arrays and return (shown, fights, close, won) per unique run seed."""
    if not rows:
        raise ValueError(f"{label}: no run clusters")
    seeds: set[int] = set()
    for row in rows:
        seed = row.get("seed") if isinstance(row, dict) else None
        if type(seed) is not int or seed in seeds:
            raise ValueError(f"{label}: every run cluster needs a unique integer seed")
        seeds.add(seed)
    counts = []
    for row in sorted(rows, key=lambda item: item["seed"]):
        where = f"{label} seed {row['seed']}"
        fights, flame = row.get("fights"), row.get("flame")
        readings = flame.get("fights") if isinstance(flame, dict) else None
        if not isinstance(fights, list) or not isinstance(readings, list) or len(fights) != len(readings):
            raise ValueError(f"{where}: B2 needs aligned fights and flame.fights arrays")
        shown = close = wins = 0
        for fight, reading in zip(fights, readings):
            if not isinstance(fight, dict) or fight.get("result") not in ("win", "loss", "stall"):
                raise ValueError(f"{where}: malformed fight result")
            if not isinstance(reading, dict):
                raise ValueError(f"{where}: malformed per-fight flame reading")
            plays = reading.get("plays")
            if (not isinstance(plays, dict) or not all(_finite_number(value) for value in plays.values())
                    or not isinstance(reading.get("dominant"), str)
                    or any(type(reading.get(key)) is not int or reading[key] < 0 for key in ("hp", "maxHp"))):
                raise ValueError(f"{where}: malformed B2 plays, dominant or HP")
            shown += bw.expressed(plays, ways) == (way if way != "none" else reading["dominant"])
            if fight["result"] == "win":
                wins += 1
                close += Fraction(reading["hp"], max(1, reading["maxHp"])) < bw.CLOSE_CALL
        counts.append((shown, len(fights), close, wins))
    return counts


def _percentile(values: list[float], p: float) -> float:
    """Linear interpolation at (n - 1) * p, with sorted non-empty values."""
    position = (len(values) - 1) * p
    left = math.floor(position)
    right = min(left + 1, len(values) - 1)
    return values[left] + (position - left) * (values[right] - values[left])


def b2_sensitivity(rows: Rows, way: str, ways: tuple[str, ...], *, seed: int = B2_SEED,
                   resamples: int = B2_RESAMPLES, label: str = "B2") -> B2Sensitivity:
    """Resample n whole runs with replacement within ONE report; pool counts in each draw.

    Sort by the simulation seed before indexing, so report order cannot change the result.
    This prospective method uses Python Random(seed), 2,000 draws by default, and linear
    2.5/97.5 percentiles. A zero denominator in ANY draw makes that metric's interval
    non-estimable: no undefined draw is discarded or replaced with an invented zero.
    """
    if type(seed) is not int or type(resamples) is not int or resamples < 1:
        raise ValueError(f"{label}: bootstrap seed must be an integer and resamples a positive integer")
    clusters = _b2_counts(rows, way, ways, label)
    totals = tuple(sum(cluster[i] for cluster in clusters) for i in range(4))
    draws: tuple[list[float], list[float]] = ([], [])
    undefined = [0, 0]
    rng = random.Random(seed)
    for _ in range(resamples):
        pooled = [0, 0, 0, 0]
        for _ in clusters:
            cluster = clusters[rng.randrange(len(clusters))]
            for i in range(4):
                pooled[i] += cluster[i]
        for metric, offset in enumerate((0, 2)):
            if pooled[offset + 1]:
                draws[metric].append(pooled[offset] / pooled[offset + 1])
            else:
                undefined[metric] += 1
    rates = []
    for metric, offset in enumerate((0, 2)):
        point = totals[offset] / totals[offset + 1] if totals[offset + 1] else None
        values = sorted(draws[metric])
        low, high = ((None, None) if undefined[metric] else
                     (_percentile(values, 0.025), _percentile(values, 0.975)))
        rates.append(ClusteredRate(point, low, high, undefined[metric]))
    return B2Sensitivity(rates[0], rates[1], len(clusters), resamples, seed)

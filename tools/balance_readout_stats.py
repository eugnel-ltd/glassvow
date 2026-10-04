"""Readout statistics on paired seeds: the exact McNemar test and the paired G3 interval.

Pure functions over run rows (dicts with `seed` and `outcome`); no Godot, no files.

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
from dataclasses import dataclass
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


def best_committed(rows_by_arm: dict[str, Rows]) -> str:
    """The committed arm with the most wins; the first of a tie, as the grader picks it."""
    return max(bw.COMMITTED, key=lambda arm: sum(won(row) for row in rows_by_arm[arm]))

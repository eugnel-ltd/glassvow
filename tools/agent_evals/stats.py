"""Seeded bootstrap statistics. Pure functions over per-case score tables."""
from __future__ import annotations

import itertools
import random
from typing import Mapping, Sequence

BOOTSTRAP_RESAMPLES = 2000
STATS_SEED = 20261004

# case id -> score of each repetition, in repetition order
ScoreTable = Mapping[str, Sequence[float]]


def mean(values: Sequence[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def bootstrap_ci(values: Sequence[float], resamples: int = BOOTSTRAP_RESAMPLES,
                 seed: int = STATS_SEED) -> tuple[float, float]:
    """95% percentile bootstrap CI of the mean, resampling cases with replacement."""
    if not values:
        return (0.0, 0.0)
    rng = random.Random(seed)
    n = len(values)
    means = sorted(mean([values[rng.randrange(n)] for _ in range(n)]) for _ in range(resamples))
    return (means[int(0.025 * resamples)], means[int(0.975 * resamples) - 1])


def half_width(values: Sequence[float], **kwargs: float) -> float:
    low, high = bootstrap_ci(values, **kwargs)
    return (high - low) / 2.0


def per_case_means(table: ScoreTable) -> dict[str, float]:
    return {case_id: mean(scores) for case_id, scores in table.items()}


def score_summary(table: ScoreTable) -> dict[str, float]:
    """Mean over cases of the per-case mean over repetitions, with its 95% CI."""
    means = list(per_case_means(table).values())
    low, high = bootstrap_ci(means)
    return {"mean": mean(means), "ci_low": low, "ci_high": high}


def noise_floor(table: ScoreTable) -> float:
    """Half-width of the 95% bootstrap CI of the paired per-case repetition difference.

    For every pair of repetitions (i, j) the per-case differences s_i - s_j are
    bootstrapped over cases; the noise is the mean of those half-widths. It is the
    scatter of the accuracy difference between two runs of an unchanged surface.
    """
    runs = min((len(scores) for scores in table.values()), default=0)
    if runs < 2:
        raise ValueError("a noise floor needs at least two repetitions")
    widths = []
    for i, j in itertools.combinations(range(runs), 2):
        diffs = [scores[i] - scores[j] for scores in table.values()]
        widths.append(half_width(diffs))
    return mean(widths)


def paired_difference_ci(first: Mapping[str, float],
                         second: Mapping[str, float]) -> tuple[float, float, float]:
    """Mean and 95% CI of the per-case difference first - second (shared case ids)."""
    diffs = [first[case_id] - second[case_id] for case_id in sorted(set(first) & set(second))]
    low, high = bootstrap_ci(diffs)
    return (mean(diffs), low, high)

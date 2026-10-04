"""The keep/revert rules for a candidate surface."""
from __future__ import annotations

from dataclasses import dataclass

GOALS = ("accuracy", "cost-at-parity")


@dataclass(frozen=True)
class Deltas:
    """Candidate minus incumbent. Positive train/test is better; negative cost is better."""

    train: float
    test: float
    cost: float


@dataclass(frozen=True)
class Noise:
    train: float
    test: float
    cost: float


@dataclass(frozen=True)
class Decision:
    keep: bool
    reason: str


def improved(delta: float, noise: float) -> bool:
    return delta > noise


def decide(goal: str, deltas: Deltas, noise: Noise) -> Decision:
    train_up = improved(deltas.train, noise.train)
    test_up = improved(deltas.test, noise.test)
    accuracy_dropped = deltas.train < -noise.train or deltas.test < -noise.test
    if goal == "accuracy":
        if train_up and test_up:
            return Decision(True, "improved")
        if train_up:
            return Decision(False, "overfit")
        if accuracy_dropped:
            return Decision(False, "regress")
        return Decision(False, "no-gain")
    if goal == "cost-at-parity":
        if accuracy_dropped:
            return Decision(False, "regress")
        if improved(-deltas.cost, noise.cost):
            return Decision(True, "cheaper")
        return Decision(False, "no-gain")
    raise ValueError(f"unknown goal {goal!r}; choose from {GOALS}")

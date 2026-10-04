"""The keep/revert rules for a candidate surface."""
from __future__ import annotations

from dataclasses import dataclass

GOALS = ("accuracy", "cost-at-parity")


@dataclass(frozen=True)
class Deltas:
    """Candidate minus incumbent. Positive train/test is better; negative cost is better.

    `base_train` and `base_test` are candidate minus the ORIGINAL baseline; the
    cost-at-parity goal judges parity against them, so drift cannot accumulate.
    """

    train: float
    test: float
    cost: float
    base_train: float | None = None
    base_test: float | None = None


@dataclass(frozen=True)
class Noise:
    train: float
    test: float
    cost: float


@dataclass(frozen=True)
class Decision:
    keep: bool
    reason: str


def improved(delta: float, noise: float, min_gain: float = 0.0) -> bool:
    """A gain counts only above both the noise floor and the smallest gain worth having."""
    return delta > max(noise, min_gain)


def decide(goal: str, deltas: Deltas, noise: Noise, min_gain: float = 0.0) -> Decision:
    if goal == "accuracy":
        train_up = improved(deltas.train, noise.train, min_gain)
        test_up = improved(deltas.test, noise.test, min_gain)
        if train_up and test_up:
            return Decision(True, "improved")
        if train_up:
            return Decision(False, "overfit")
        if deltas.train < -noise.train or deltas.test < -noise.test:
            return Decision(False, "regress")
        return Decision(False, "no-gain")
    if goal == "cost-at-parity":
        base_train = deltas.train if deltas.base_train is None else deltas.base_train
        base_test = deltas.test if deltas.base_test is None else deltas.base_test
        if base_train < -noise.train or base_test < -noise.test:
            return Decision(False, "regress")
        if improved(-deltas.cost, noise.cost):
            return Decision(True, "cheaper")
        return Decision(False, "no-gain")
    raise ValueError(f"unknown goal {goal!r}; choose from {GOALS}")

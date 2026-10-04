"""The hill-climbing loop: one patch per round, kept only when it beats the noise."""
from __future__ import annotations

import difflib
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Sequence

from .backends import Backend
from .decision import Deltas, Noise, decide, improved
from .evalspec import EvalSpec
from .models import Case, EvalError, write_json
from .patching import DEFAULT_MIN_SPAN, PatchError, apply_unified_diff, find_injection
from .proposer import (PROPOSER_SYSTEM, REFLECTION_SYSTEM, assert_no_test_leak,
                       build_proposer_prompt, build_reflection_prompt, parse_proposal)
from .runner import (DEFAULT_INFRA_THRESHOLD, DEFAULT_TIMEOUT_S, InfraFailure, SetResult,
                     check_infra, run_set)
from .stats import mean, noise_floor, per_case_means, score_summary


@dataclass(frozen=True)
class HillclimbConfig:
    goal: str = "accuracy"
    model: str = "sonnet"
    proposer_model: str = "opus"
    reps: int = 3
    round_reps: int = 1
    rounds: int = 8
    stall: int = 3
    min_gain: float = 0.05
    min_span: int = DEFAULT_MIN_SPAN
    timeout_s: float = DEFAULT_TIMEOUT_S
    infra_threshold: float = DEFAULT_INFRA_THRESHOLD
    workers: int = 1


@dataclass
class ScoreCard:
    """Mean accuracy on each set and mean tokens per call over both."""

    train: float
    test: float
    cost: float
    train_table: dict[str, list[float]]
    test_table: dict[str, list[float]]
    train_transcripts: list[dict[str, Any]]


def scorecard(train: SetResult, test: SetResult) -> ScoreCard:
    costs = [t["cost_tokens"] for t in train.transcripts + test.transcripts]
    return ScoreCard(
        train=mean(list(per_case_means(train.table()).values())),
        test=mean(list(per_case_means(test.table()).values())),
        cost=mean(costs), train_table=train.table(), test_table=test.table(),
        train_transcripts=train.transcripts)


def cost_noise(train: SetResult, test: SetResult) -> float:
    return noise_floor({**train.table("cost_tokens"), **test.table("cost_tokens")})


@dataclass
class Version:
    round: int
    text: str
    card: ScoreCard


def _unified(original: str, text: str) -> str:
    return "".join(difflib.unified_diff(
        original.splitlines(keepends=True), text.splitlines(keepends=True),
        "surface.md (original)", "surface.md (best)"))


def _case_texts(cases: Sequence[Case]) -> list[str]:
    return [text for case in cases for text in (case.prompt, case.reference)]


class Climb:
    """State of one hill-climbing run."""

    def __init__(self, spec: EvalSpec, cases: Sequence[Case], split: dict[str, Any],
                 backend: Backend, proposer: Backend, config: HillclimbConfig,
                 run_dir: Path, judge: Backend | None = None):
        self.spec, self.backend, self.proposer, self.cfg = spec, backend, proposer, config
        self.run_dir, self.judge = run_dir, judge
        self.all_cases = list(cases)
        self.train_cases = [c for c in cases if c.id in set(split["train"])]
        self.test_cases = [c for c in cases if c.id in set(split["test"])]
        self.original = spec.surface.read_text(encoding="utf-8")
        self.work = run_dir / "work" / "surface.md"
        self.history: list[dict[str, str]] = []
        self.rounds: list[dict[str, Any]] = []
        self.notes: list[str] = []
        self.noise = Noise(0.0, 0.0, 0.0)
        self.baseline: ScoreCard | None = None

    def _evaluate(self, text: str, label: str, reps: int) -> tuple[SetResult, SetResult]:
        results = []
        for name, cases in (("train", self.train_cases), ("test", self.test_cases)):
            # Test transcripts go to their own directory, which no prompt builder reads.
            result = run_set(self.backend, cases, self.cfg.model, text, reps,
                             self.run_dir / label / name, self.spec.name, self.judge,
                             self.spec.judge_model, self.cfg.timeout_s, self.cfg.workers)
            check_infra(result.infra(), self.cfg.infra_threshold)
            results.append(result)
        return results[0], results[1]

    def _prompt(self, builder: Callable[..., str], surface_text: str, *args: Any) -> str:
        """Build a proposer prompt (train data only) and prove it holds no test data."""
        prompt = builder(surface_text, *args)
        assert_no_test_leak(prompt, surface_text, self.test_cases, self.cfg.min_span)
        return prompt

    def _reflect(self, incumbent: Version, noise: Noise, baseline: ScoreCard, why: str) -> None:
        unstable = sorted(cid for cid, scores in baseline.train_table.items() if len(set(scores)) > 1)
        prompt = self._prompt(build_reflection_prompt, incumbent.text, self.train_cases,
                              incumbent.card.train_transcripts, noise.train, unstable,
                              self.history, why)
        reply = self.proposer.complete(REFLECTION_SYSTEM, prompt, self.cfg.proposer_model,
                                       self.cfg.timeout_s)
        text = reply.text if not reply.infra_failed else f"Reflection failed: {reply.error}"
        (self.run_dir / "reflection.md").write_text(text.strip() + "\n", encoding="utf-8")

    def _propose(self, number: int, incumbent: Version) -> dict[str, Any]:
        """One round: propose, screen, apply, evaluate, decide. Returns the round record."""
        prompt = self._prompt(build_proposer_prompt, incumbent.text, self.train_cases,
                              incumbent.card.train_transcripts, self.cfg.goal, self.history)
        reply = self.proposer.complete(PROPOSER_SYSTEM, prompt, self.cfg.proposer_model,
                                       self.cfg.timeout_s)
        record: dict[str, Any] = {"round": number, "kept": False, "root_cause": ""}
        if reply.infra_failed:
            return {**record, "reason": "proposer-error", "detail": reply.error or "timeout"}
        try:
            proposal = parse_proposal(reply.text)
        except EvalError as error:
            return {**record, "reason": "bad-proposal", "detail": str(error)}
        record.update(proposal)
        span = find_injection(proposal["patch"], _case_texts(self.all_cases), self.cfg.min_span)
        if span:
            return {**record, "reason": "rejected-injection", "detail": span}
        try:
            candidate = apply_unified_diff(incumbent.text, proposal["patch"])
        except PatchError as error:
            return {**record, "reason": "rejected-patch", "detail": str(error)}
        if candidate == incumbent.text:
            return {**record, "reason": "rejected-patch", "detail": "the patch changes nothing"}
        label = f"rounds/{number:02d}"
        (self.run_dir / label).mkdir(parents=True, exist_ok=True)
        (self.run_dir / label / "candidate.md").write_text(candidate, encoding="utf-8")
        train, test = self._evaluate(candidate, label, self.cfg.round_reps)
        card = scorecard(train, test)
        base = self.baseline
        deltas = Deltas(card.train - incumbent.card.train, card.test - incumbent.card.test,
                        card.cost - incumbent.card.cost, card.train - base.train,
                        card.test - base.test)
        decision = decide(self.cfg.goal, deltas, self.noise, self.cfg.min_gain)
        record.update(kept=decision.keep, reason=decision.reason, train=card.train,
                      test=card.test, cost=card.cost, delta_train=deltas.train,
                      delta_test=deltas.test, delta_cost=deltas.cost)
        record["_version"] = Version(number, candidate, card) if decision.keep else None
        return record

    def run(self) -> dict[str, Any]:
        self.work.parent.mkdir(parents=True, exist_ok=True)
        self.work.write_text(self.original, encoding="utf-8")
        base_train, base_test = self._evaluate(self.original, "noise", self.cfg.reps)
        baseline = self.baseline = scorecard(base_train, base_test)
        self.noise = Noise(noise_floor(base_train.table()), noise_floor(base_test.table()),
                           cost_noise(base_train, base_test))
        versions = [Version(0, self.original, baseline)]
        incumbent = versions[0]
        stalled = 0
        status = "completed"
        unmeasurable = max(self.noise.train, self.noise.test) > self.cfg.min_gain
        if unmeasurable:
            why = (f"the noise floor (train {self.noise.train:.3f}, test {self.noise.test:.3f}) "
                   f"exceeds --min-gain {self.cfg.min_gain}; a gain that small cannot be measured. "
                   "Use more repetitions or more cases.")
            self.notes.append(why)
            self._reflect(incumbent, self.noise, baseline, why)
            status = "unmeasurable"
        planned = () if unmeasurable else range(1, self.cfg.rounds + 1)
        for number in planned:
            try:
                record = self._propose(number, incumbent)
            except InfraFailure as error:
                self.notes.append(f"round {number} aborted: {error}")
                status = "infrastructure-failure"
                break
            version = record.pop("_version", None)
            self.rounds.append(record)
            write_json(self.run_dir / "rounds" / f"{number:02d}" / "round.json", record)
            outcome = "kept" if record["kept"] else "reverted"
            self.history.append({"round": str(number), "root_cause": record["root_cause"],
                                 "outcome": outcome})
            if version is not None:
                incumbent = version
                versions.append(version)
                self.work.write_text(incumbent.text, encoding="utf-8")
                stalled = 0
            else:
                stalled += 1
            if stalled >= self.cfg.stall:
                why = f"{stalled} consecutive rounds were not kept"
                self.notes.append(why)
                self._reflect(incumbent, self.noise, baseline, why)
                status = "stalled"
                break
        return self._finish(versions, status)

    def _holds_parity(self, card: ScoreCard) -> bool:
        base = self.baseline
        return (card.train - base.train >= -self.noise.train
                and card.test - base.test >= -self.noise.test)

    def _select_best(self, versions: list[Version]) -> Version:
        """Accuracy: best test score. Cost-at-parity: cheapest version holding parity."""
        if self.cfg.goal == "accuracy":
            # Ties go to the cheaper surface, then the earlier round.
            return max(versions, key=lambda v: (v.card.test, -v.card.cost, -v.round))
        eligible = [v for v in versions if v.round == 0 or self._holds_parity(v.card)]
        return min(eligible, key=lambda v: (v.card.cost, -v.card.test, v.round))

    def _confirm(self, best: Version) -> dict[str, Any]:
        """Re-run the original and the best version on test, then judge the paired runs."""
        if best.round == 0:
            return {"ran": False, "ok": False, "why": "the best version is the original"}
        runs = {}
        for name, text in (("baseline", self.original), ("best", best.text)):
            result = run_set(self.backend, self.test_cases, self.cfg.model, text, self.cfg.reps,
                             self.run_dir / "confirm" / name, self.spec.name, self.judge,
                             self.spec.judge_model, self.cfg.timeout_s, self.cfg.workers)
            check_infra(result.infra(), self.cfg.infra_threshold)
            runs[name] = result
        score = {n: mean(list(per_case_means(r.table()).values())) for n, r in runs.items()}
        cost = {n: mean([t["cost_tokens"] for t in r.transcripts]) for n, r in runs.items()}
        gain, drop = score["best"] - score["baseline"], cost["baseline"] - cost["best"]
        if self.cfg.goal == "accuracy":
            ok = improved(gain, self.noise.test, self.cfg.min_gain)
        else:
            ok = (drop > self.noise.cost and gain >= -self.noise.test
                  and best.card.train - self.baseline.train >= -self.noise.train)
        return {"ran": True, "ok": ok, "reps": self.cfg.reps, "test_baseline": score["baseline"],
                "test_best": score["best"], "test_gain": gain, "cost_baseline": cost["baseline"],
                "cost_best": cost["best"], "cost_drop": drop}

    def _finish(self, versions: list[Version], status: str) -> dict[str, Any]:
        baseline = versions[0].card
        best = self._select_best(versions)
        self.work.write_text(best.text, encoding="utf-8")  # restore the best version
        (self.run_dir / "best_surface.md").write_text(best.text, encoding="utf-8")
        (self.run_dir / "best.diff").write_text(_unified(self.original, best.text), encoding="utf-8")
        confirmation: dict[str, Any] = {"ran": False, "ok": False, "why": "not reached"}
        if status == "infrastructure-failure":
            verdict = "do not merge (run invalid: infrastructure failures)"
        else:
            try:
                confirmation = self._confirm(best)
                verdict = ("merge recommended" if confirmation["ok"]
                           else "do not merge (within noise)")
            except InfraFailure as error:
                self.notes.append(f"confirmatory rerun aborted: {error}")
                verdict = "do not merge (run invalid: infrastructure failures)"
        summary = {
            "status": status, "verdict": verdict, "best_round": best.round,
            "noise": {"train": self.noise.train, "test": self.noise.test, "cost": self.noise.cost},
            "baseline": {"train": score_summary(baseline.train_table),
                         "test": score_summary(baseline.test_table), "cost": baseline.cost},
            "best": {"train": score_summary(best.card.train_table),
                     "test": score_summary(best.card.test_table), "cost": best.card.cost},
            "confirmation": confirmation, "rounds": self.rounds, "notes": self.notes,
        }
        write_json(self.run_dir / "summary.json", summary)
        (self.run_dir / "report.md").write_text(render_report(self.spec, self.cfg, summary),
                                                encoding="utf-8")
        return summary


def _score_cell(block: dict[str, float]) -> str:
    return f"{block['mean']:.1%} (95% CI {block['ci_low']:.1%} to {block['ci_high']:.1%})"


def render_report(spec: EvalSpec, cfg: HillclimbConfig, summary: dict[str, Any]) -> str:
    noise, base, best = summary["noise"], summary["baseline"], summary["best"]
    lines = [
        f"# Hill-climb report: {spec.name}", "",
        f"- surface: `{spec.surface.name}`; goal `{cfg.goal}`; model `{cfg.model}`; "
        f"proposer `{cfg.proposer_model}`",
        f"- status: {summary['status']}; best version: round {summary['best_round']}",
        f"- noise floor: train {noise['train']:.3f}, test {noise['test']:.3f}, "
        f"cost {noise['cost']:.1f} tokens; minimum gain worth having {cfg.min_gain}", "",
        "## Scores", "", "| | train | test | tokens per call |", "|---|---|---|---|",
        f"| baseline | {_score_cell(base['train'])} | {_score_cell(base['test'])} | {base['cost']:.0f} |",
        f"| best | {_score_cell(best['train'])} | {_score_cell(best['test'])} | {best['cost']:.0f} |",
        "", "## Rounds", "",
        "| round | decision | reason | train delta | test delta | root cause |", "|---|---|---|---|---|---|"]
    for item in summary["rounds"]:
        dtrain = f"{item['delta_train']:+.3f}" if "delta_train" in item else "-"
        dtest = f"{item['delta_test']:+.3f}" if "delta_test" in item else "-"
        cause = item["root_cause"].replace("|", "/").replace("\n", " ")[:120]
        lines.append(f"| {item['round']} | {'kept' if item['kept'] else 'reverted'} | "
                     f"{item['reason']} | {dtrain} | {dtest} | {cause} |")
    if not summary["rounds"]:
        lines.append("| - | no rounds ran | - | - | - | - |")
    lines += ["", "## Notes", ""] + [f"- {note}" for note in summary["notes"]] if summary["notes"] else []
    lines += ["", "## Confirmatory rerun (test set, original against best)", ""]
    check = summary["confirmation"]
    if check["ran"]:
        lines += [f"- {check['reps']} repetitions each: original {check['test_baseline']:.1%}, "
                  f"best {check['test_best']:.1%}, gain {check['test_gain']:+.3f} "
                  f"(test noise {noise['test']:.3f})",
                  f"- tokens per call: original {check['cost_baseline']:.0f}, best "
                  f"{check['cost_best']:.0f}, drop {check['cost_drop']:+.0f} "
                  f"(cost noise {noise['cost']:.1f})",
                  f"- confirmed: {'yes' if check['ok'] else 'no'}"]
    else:
        lines.append(f"- not run: {check['why']}")
    lines += ["", "## Verdict", "", f"**{summary['verdict']}**", ""]
    return "\n".join(lines)

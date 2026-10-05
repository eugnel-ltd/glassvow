#!/usr/bin/env python3
"""Grader calibration: grade answer sets once, then compute the bars offline.

`grade` is the only step that calls the judge: it grades every answer in one set with the frozen
claims and writes one grading (a JSONL file). `metrics` reads gradings and the adjudicator's labels
and computes the round-3 bars (council-2026-10-05.md) with no model call:

- false negatives on correct sets: claim failures, decision and gate failures, answers under 100%,
  with hedged correct answers reported apart;
- false positives on wrong sets: passes of COVERED judge claims (overall and per kind), passes of
  COVERED programmatic claims, wrong answers that score 100%, and coverage from the labels;
- adversarial sets: mean score per transform beside the oracle-booleans score;
- stability: two gradings of a set give the majority disagreement, the raw split share, gate
  splits and the test-retest change in the total score.

Rates carry a Wilson interval and a case-clustered bootstrap interval.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from agent_evals.backends import Backend, ClaudeCliBackend  # noqa: E402
from agent_evals.diagnostics import oracle_booleans_score  # noqa: E402
from agent_evals.evalspec import load_cases, load_eval  # noqa: E402
from agent_evals.graders import JUDGE_ARMS, claims_sha256, grade, is_judge_claim  # noqa: E402
from agent_evals.models import Case  # noqa: E402
from agent_evals.stats import BOOTSTRAP_RESAMPLES, STATS_SEED, mean  # noqa: E402

ROLES = ("correct", "wrong", "adversarial")
LABELS = ("COVERED", "AMBIGUOUS", "UNCOVERED")
Z95 = 1.959963984540054
DEFAULT_MIN_GAIN = 0.05


def wilson(k: int, n: int, z: float = Z95) -> tuple[float, float]:
    """Wilson score interval of k successes in n trials."""
    if n == 0:
        return (0.0, 1.0)
    p = k / n
    scale = 1 + z * z / n
    centre = (p + z * z / (2 * n)) / scale
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / scale
    return (max(0.0, centre - half), min(1.0, centre + half))


def clustered_interval(clusters: Sequence[tuple[int, int]], resamples: int = BOOTSTRAP_RESAMPLES,
                       seed: int = STATS_SEED) -> tuple[float, float]:
    """95% percentile bootstrap of a pooled rate, resampling (hits, trials) clusters (cases)."""
    if not clusters:
        return (0.0, 1.0)
    rng = random.Random(seed)
    size = len(clusters)
    rates = []
    for _ in range(resamples):
        sample = [clusters[rng.randrange(size)] for _ in range(size)]
        trials = sum(n for _, n in sample)
        rates.append(sum(k for k, _ in sample) / trials if trials else 0.0)
    rates.sort()
    return (rates[int(0.025 * resamples)], rates[int(0.975 * resamples) - 1])


def rate(events: Iterable[tuple[str, bool]]) -> dict[str, Any]:
    """Pooled rate of (case id, hit) events with its Wilson and case-clustered intervals."""
    by_case: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for case_id, hit in events:
        by_case[case_id][0] += int(hit)
        by_case[case_id][1] += 1
    k = sum(hits for hits, _ in by_case.values())
    n = sum(trials for _, trials in by_case.values())
    return {"k": k, "n": n, "rate": k / n if n else 0.0, "wilson": wilson(k, n),
            "clustered": clustered_interval([tuple(v) for v in by_case.values()])}


# ---------------------------------------------------------------- grading (the judge is called)

def read_answers(path: Path) -> list[dict[str, Any]]:
    """Answer rows {"id", "answer", optional "kind" and "hedged"}; a row without an answer, such as a
    header note, is skipped."""
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return [row for row in rows if isinstance(row.get("answer"), dict)]


def grade_set(cases: Mapping[str, Case], rows: Sequence[Mapping[str, Any]], judge: Backend | None,
              judge_model: str, arm: str, meta: Mapping[str, Any], workers: int = 6) -> list[dict[str, Any]]:
    """One grading of a set: every row graded as the eval grades it, in row order."""
    def one(item: tuple[int, Mapping[str, Any]]) -> dict[str, Any]:
        index, row = item
        result = grade(cases[row["id"]], json.dumps(row["answer"]), judge, judge_model, judge_arm=arm)
        return {**meta, "arm": arm, "judge_model": judge_model, "judge_model_id": result.judge_model_id,
                "index": index, "id": row["id"], "kind": row.get("kind", ""),
                "hedged": bool(row.get("hedged", False)), "score": result.score,
                "decision_failed": result.decision_failed, "judge_error": result.judge_error,
                "verdicts": [[v.claim_id, v.passed, list(v.votes)] for v in result.verdicts]}
    with ThreadPoolExecutor(max(1, workers)) as pool:
        return list(pool.map(one, enumerate(rows)))


# ---------------------------------------------------------------- metrics (offline)

def _claim_index(cases: Mapping[str, Case]) -> dict[tuple[str, str], Mapping[str, Any]]:
    return {(case_id, claim["id"]): claim
            for case_id, case in cases.items() for claim in case.grader["claims"]}


def _scored(rows: Iterable[Mapping[str, Any]]) -> list[Mapping[str, Any]]:
    return [row for row in rows if not row.get("judge_error")]


def _verdicts(row: Mapping[str, Any]) -> Iterable[tuple[str, bool, list[bool]]]:
    return ((claim_id, passed, votes) for claim_id, passed, votes in row["verdicts"])


def correct_metrics(rows: Sequence[Mapping[str, Any]], claims: Mapping[tuple[str, str], Mapping[str, Any]]
                    ) -> dict[str, Any]:
    def summary(subset: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
        events = [(row["id"], not passed, is_judge_claim(claims[(row["id"], cid)]))
                  for row in subset for cid, passed, _ in _verdicts(row)]
        return {"answers": len(subset),
                "claim_failure": rate((c, hit) for c, hit, _ in events),
                "judge_claim_failure": rate((c, hit) for c, hit, judged in events if judged),
                "programmatic_claim_failure": rate((c, hit) for c, hit, judged in events if not judged),
                "decision_or_gate_failures": sum(bool(row["decision_failed"]) for row in subset),
                "under_100": [{"set": row["set"], "index": row["index"], "id": row["id"],
                               "failed": [cid for cid, passed, _ in _verdicts(row) if not passed]}
                              for row in subset if row["score"] < 1.0]}
    scored = _scored(rows)
    return {"all": summary(scored), "hedged": summary([r for r in scored if r["hedged"]]),
            "not_hedged": summary([r for r in scored if not r["hedged"]]),
            "judge_errors": len(rows) - len(scored)}


def wrong_metrics(rows: Sequence[Mapping[str, Any]], claims: Mapping[tuple[str, str], Mapping[str, Any]],
                  labels: Mapping[tuple[str, int, str], str]) -> dict[str, Any]:
    scored = _scored(rows)
    fp, not_judged, programmatic_passes = [], 0, []
    for row in scored:
        for cid, passed, votes in _verdicts(row):
            if labels.get((row["set"], row["index"], cid)) != "COVERED":
                continue
            if not is_judge_claim(claims[(row["id"], cid)]):
                if passed:
                    programmatic_passes.append({"set": row["set"], "index": row["index"], "claim": cid})
            elif votes:
                fp.append((row["id"], row["kind"], passed))
            else:
                not_judged += 1  # a decision or gate already failed the answer
    covered = {(row["set"], row["index"]) for row in scored
               for cid, _, _ in _verdicts(row) if labels.get((row["set"], row["index"], cid)) == "COVERED"}
    kinds = sorted({row["kind"] for row in scored})
    return {
        "answers": len(scored), "judge_errors": len(rows) - len(scored),
        "fp_covered_judge": rate((c, hit) for c, _, hit in fp),
        "fp_covered_judge_by_kind": {k: rate((c, hit) for c, kind, hit in fp if kind == k) for k in kinds},
        "covered_judge_not_judged": not_judged,
        "covered_programmatic_passes": programmatic_passes,
        "wrong_at_100": rate((row["id"], row["score"] >= 1.0) for row in scored),
        "wrong_at_100_by_kind": {
            k: rate((row["id"], row["score"] >= 1.0) for row in scored if row["kind"] == k) for k in kinds},
        "coverage": rate((row["id"], (row["set"], row["index"]) in covered) for row in scored),
        "ambiguous_labels": sum(1 for row in scored for cid, _, _ in _verdicts(row)
                                if labels.get((row["set"], row["index"], cid)) == "AMBIGUOUS"),
    }


def adversarial_metrics(rows: Sequence[Mapping[str, Any]], oracle: float) -> dict[str, Any]:
    scored = _scored(rows)
    by_kind: dict[str, list[float]] = defaultdict(list)
    for row in scored:
        by_kind[row["kind"]].append(row["score"])
    return {"oracle_booleans": oracle, "judge_errors": len(rows) - len(scored),
            "mean_by_transform": {kind: mean(scores) for kind, scores in sorted(by_kind.items())},
            "max_mean": max((mean(s) for s in by_kind.values()), default=0.0)}


def stability(first: Sequence[Mapping[str, Any]], second: Sequence[Mapping[str, Any]],
              claims: Mapping[tuple[str, str], Mapping[str, Any]], min_gain: float) -> dict[str, Any]:
    """Two gradings of one set, matched by answer index."""
    paired = {row["index"]: row for row in _scored(second)}
    pairs = [(row, paired[row["index"]]) for row in _scored(first) if row["index"] in paired]
    flips, splits, gate_splits = [], [], []
    for one, two in pairs:
        votes_two = {cid: (passed, votes) for cid, passed, votes in _verdicts(two)}
        for cid, passed, votes in _verdicts(one):
            passed_two, votes_two_cast = votes_two[cid]
            if not (votes and votes_two_cast):
                continue
            flips.append((one["id"], passed != passed_two))
            splits += [(one["id"], len(set(votes)) > 1), (one["id"], len(set(votes_two_cast)) > 1)]
            if claims[(one["id"], cid)].get("gate") and (passed != passed_two or len(set(votes)) > 1
                                                          or len(set(votes_two_cast)) > 1):
                gate_splits.append({"index": one["index"], "id": one["id"], "claim": cid})
    change = abs(mean([o["score"] for o, _ in pairs]) - mean([t["score"] for _, t in pairs]))
    return {"answers": len(pairs), "majority_disagreement": rate(flips), "raw_split_share": rate(splits),
            "gate_splits": gate_splits, "score_change": change, "score_change_limit": min_gain / 2,
            "score_change_within_limit": change <= min_gain / 2}


def metrics(cases: Mapping[str, Case], gradings: Sequence[Mapping[str, Any]],
            labels: Mapping[tuple[str, int, str], str], min_gain: float = DEFAULT_MIN_GAIN) -> dict[str, Any]:
    """Every bar per arm and grading run, pooled over the sets of each role, plus per-set stability."""
    current = claims_sha256(cases.values())
    stale = sorted({row.get("claims_sha256", "") for row in gradings} - {current})
    if stale:
        raise ValueError(f"gradings made with other claims {stale}; the frozen claims are {current}")
    claims = _claim_index(cases)
    groups: dict[tuple[str, str, int], list[Mapping[str, Any]]] = defaultdict(list)
    for row in gradings:
        groups[(row["arm"], row["role"], row["run"])].append(row)
    oracle = oracle_booleans_score(list(cases.values()))
    model_ids = sorted({row["judge_model_id"] for row in gradings if row["judge_model_id"]})
    report: dict[str, Any] = {"claims_sha256": current, "judge_model_ids": model_ids, "runs": {}, "stability": {}}
    for (arm, role, run), rows in sorted(groups.items()):
        if role == "correct":
            body = correct_metrics(rows, claims)
        elif role == "wrong":
            body = wrong_metrics(rows, claims, labels)
        else:
            body = adversarial_metrics(rows, oracle)
        report["runs"][f"{arm}/{role}/run{run}"] = body
    by_set: dict[tuple[str, str], dict[int, list[Mapping[str, Any]]]] = defaultdict(lambda: defaultdict(list))
    for row in gradings:
        by_set[(row["arm"], row["set"])][row["run"]].append(row)
    for (arm, name), runs in sorted(by_set.items()):
        if len(runs) >= 2:
            first, second = sorted(runs)[:2]
            report["stability"][f"{arm}/{name}"] = stability(runs[first], runs[second], claims, min_gain)
    return report


def read_labels(path: Path | None) -> dict[tuple[str, int, str], str]:
    """Labels {"set", "index", "claim_id", "label"}: one per pair of wrong answer and claim."""
    if path is None:
        return {}
    labels = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            row = json.loads(line)
            if row["label"] not in LABELS:
                raise ValueError(f"unknown label {row['label']!r}")
            labels[(row["set"], int(row["index"]), row["claim_id"])] = row["label"]
    return labels


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--eval", default="repo_traps")
    sub = parser.add_subparsers(dest="command", required=True)
    g = sub.add_parser("grade", help="grade one answer set once (calls the judge)")
    g.add_argument("--answers", type=Path, required=True)
    g.add_argument("--set", required=True, help="the set's name, as the labels file uses it")
    g.add_argument("--role", choices=ROLES, required=True)
    g.add_argument("--run", type=int, required=True, help="1 or 2: each set is graded twice")
    g.add_argument("--arm", choices=JUDGE_ARMS, required=True)
    g.add_argument("--judge-model", help="default: eval.json judge_model")
    g.add_argument("--workers", type=int, default=6)
    g.add_argument("--out", type=Path, required=True)
    m = sub.add_parser("metrics", help="compute the bars from gradings (no model call)")
    m.add_argument("--gradings", type=Path, nargs="+", required=True)
    m.add_argument("--labels", type=Path)
    m.add_argument("--min-gain", type=float, default=DEFAULT_MIN_GAIN)
    m.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    spec = load_eval(args.eval)
    cases = {case.id: case for case in load_cases(spec)}
    if args.command == "grade":
        if args.out.exists():
            parser.error(f"{args.out} exists; a grading is written once")
        meta = {"set": args.set, "role": args.role, "run": args.run,
                "claims_sha256": claims_sha256(cases.values()),
                "answers_sha256": hashlib.sha256(args.answers.read_bytes()).hexdigest()}
        rows = grade_set(cases, read_answers(args.answers), ClaudeCliBackend(),
                         args.judge_model or spec.judge_model, args.arm, meta, args.workers)
        args.out.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")
        print(f"graded {len(rows)} answers into {args.out}")
        return 0
    gradings = [json.loads(line) for path in args.gradings
                for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    report = metrics(cases, gradings, read_labels(args.labels), args.min_gain)
    text = json.dumps(report, indent=1)
    if args.out:
        args.out.write_text(text + "\n", encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())

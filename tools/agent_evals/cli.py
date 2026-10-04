#!/usr/bin/env python3
"""Command line for the eval design and hill-climbing harness."""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from agent_evals import approvals, split as splitting  # noqa: E402
from agent_evals.backends import (AnthropicApiBackend, Backend, ClaudeCliBackend,  # noqa: E402
                                  IsolationUnavailable)
from agent_evals.baseline import run_baseline  # noqa: E402
from agent_evals.evalspec import EvalSpec, load_cases, load_eval, require_valid  # noqa: E402
from agent_evals.hillclimb import Climb, HillclimbConfig  # noqa: E402
from agent_evals.models import EvalError, MODEL_ALIASES, write_json  # noqa: E402
from agent_evals.report import review_html  # noqa: E402
from agent_evals.runner import DEFAULT_INFRA_THRESHOLD, DEFAULT_TIMEOUT_S  # noqa: E402


def _run_id(prefix: str = "") -> str:
    return prefix + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _backend(args: argparse.Namespace) -> Backend:
    if args.backend == "api":
        return AnthropicApiBackend()
    return ClaudeCliBackend(allow_ambient=args.allow_ambient_context)


def _load(args: argparse.Namespace) -> tuple[EvalSpec, list]:
    spec = load_eval(args.eval)
    cases = load_cases(spec)
    require_valid(cases)
    return spec, cases


def cmd_init(args: argparse.Namespace) -> int:
    spec, cases = _load(args)
    payload = splitting.write_split(spec.directory / "split.json", [c.id for c in cases],
                                    spec.cases_sha256, args.seed, args.train_fraction)
    print(f"{len(cases)} cases valid; split {len(payload['train'])} train / "
          f"{len(payload['test'])} test (seed {args.seed}); cases sha256 {spec.cases_sha256}")
    return 0


def cmd_review(args: argparse.Namespace) -> int:
    spec, cases = _load(args)
    path = spec.build_dir / "review.html"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(review_html(spec.name, cases, spec.cases_sha256), encoding="utf-8")
    print(f"wrote {path}; read every case, then run approve-inputs")
    return 0


def cmd_approve_inputs(args: argparse.Namespace) -> int:
    spec, _ = _load(args)
    entry = approvals.approve_inputs(spec.directory, spec.cases_sha256)
    print(f"inputs approved by {entry['by']} at {entry['at']}")
    return 0


def _run_transcripts(run_dir: Path) -> list[str]:
    return sorted(str(p.relative_to(run_dir)) for p in (run_dir / "transcripts").glob("*/*.json"))


def cmd_approve_grader(args: argparse.Namespace) -> int:
    spec, _ = _load(args)
    run_dir = spec.build_dir / args.run
    ids = _run_transcripts(run_dir)
    sample = approvals.sample_transcript_ids(ids, args.run)
    try:
        entry = approvals.approve_grader(spec.directory, spec.cases_sha256, ids, args.run,
                                         args.read.split(",") if args.read else [])
    except approvals.ApprovalError as error:
        print(f"not approved: {error}", file=sys.stderr)
        print("Open these scored transcripts and check each verdict is right:", file=sys.stderr)
        for item in sample:
            print(f"  {run_dir / item}", file=sys.stderr)
        print("Then re-run with --read " + ",".join(sample), file=sys.stderr)
        return 1
    print(f"grader approved by {entry['by']} at {entry['at']} after reading {len(sample)} transcripts")
    return 0


def cmd_baseline(args: argparse.Namespace) -> int:
    spec, cases = _load(args)
    if args.only:
        wanted = set(args.only.split(","))
        cases = [c for c in cases if c.id in wanted]
        if not cases:
            raise EvalError(f"--only matched no case: {args.only}")
    run_id = args.run_id or _run_id()
    run_dir = spec.build_dir / run_id
    backend = _backend(args)
    judge = backend if spec.grader_type == "judge" else None
    models = args.models.split(",") if args.models else list(spec.default_models)
    results = run_baseline(spec, cases, backend, models, args.reps, run_dir, judge, args.timeout,
                           args.infra_threshold, args.workers, run_id)
    for model, block in results["models"].items():
        print(f"{model}: {block['summary']['mean']:.1%} over {len(block['per_case'])} cases")
    for warning in results["warnings"]:
        print(f"WARNING: {warning}", file=sys.stderr)
    print(f"results: {run_dir / 'results.html'}")
    return 2 if results["status"] == "failed" else 0


def cmd_hillclimb(args: argparse.Namespace) -> int:
    spec, cases = _load(args)
    approvals.require_approvals(spec.directory, spec.cases_sha256)
    split = splitting.load_split(spec.directory / "split.json", [c.id for c in cases],
                                 spec.cases_sha256)
    config = HillclimbConfig(
        goal=args.goal, model=args.model or spec.hillclimb_model,
        proposer_model=args.proposer_model, reps=args.reps, round_reps=args.round_reps,
        rounds=args.rounds, stall=args.stall, min_gain=args.min_gain, timeout_s=args.timeout,
        infra_threshold=args.infra_threshold, workers=args.workers)
    run_dir = spec.build_dir / (args.run_id or _run_id("hc-"))
    backend = _backend(args)
    judge = backend if spec.grader_type == "judge" else None
    write_json(run_dir / "config.json", config.__dict__)
    summary = Climb(spec, cases, split, backend, backend, config, run_dir, judge).run()
    print(f"{summary['status']}: {summary['verdict']}\nreport: {run_dir / 'report.md'}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    def command(name: str, handler, help_text: str) -> argparse.ArgumentParser:
        sub = commands.add_parser(name, help=help_text)
        sub.add_argument("eval", help="eval name under tools/agent_evals/evals/")
        sub.set_defaults(handler=handler)
        return sub

    def backend_flags(sub: argparse.ArgumentParser) -> None:
        sub.add_argument("--backend", choices=("cli", "api"), default="cli")
        sub.add_argument("--allow-ambient-context", action="store_true",
                         help="run even if the CLI cannot isolate the model from CLAUDE.md, "
                              "memory and hooks (results are then contaminated)")
        sub.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT_S)
        sub.add_argument("--workers", type=int, default=2)
        sub.add_argument("--infra-threshold", type=float, default=DEFAULT_INFRA_THRESHOLD)
        sub.add_argument("--run-id")

    init = command("init", cmd_init, "validate cases and write split.json")
    init.add_argument("--seed", default=splitting.DEFAULT_SEED)
    init.add_argument("--train-fraction", type=float, default=splitting.DEFAULT_TRAIN_FRACTION)
    command("review", cmd_review, "write review.html: every input with source and why_hard")
    command("approve-inputs", cmd_approve_inputs, "record the human approval of the inputs")
    grader = command("approve-grader", cmd_approve_grader,
                     "record grader approval after reading sampled scored transcripts")
    grader.add_argument("--run", required=True, help="baseline run id to sample transcripts from")
    grader.add_argument("--read", help="comma-separated sampled transcripts you have opened")
    base = command("baseline", cmd_baseline, "run every case for each model")
    backend_flags(base)
    base.add_argument("--models", help=f"comma-separated aliases, e.g. {','.join(MODEL_ALIASES)}")
    base.add_argument("--reps", type=int, default=3)
    base.add_argument("--only", help="comma-separated case ids (smoke runs)")
    climb = command("hillclimb", cmd_hillclimb, "hill-climb the surface (needs both approvals)")
    backend_flags(climb)
    climb.add_argument("--goal", choices=("accuracy", "cost-at-parity"), default="accuracy")
    climb.add_argument("--model", help="model under test (default: eval.json hillclimb_model)")
    climb.add_argument("--proposer-model", default="opus")
    climb.add_argument("--reps", type=int, default=3, help="repetitions for the noise floor")
    climb.add_argument("--round-reps", type=int, default=1)
    climb.add_argument("--rounds", type=int, default=8)
    climb.add_argument("--stall", type=int, default=3)
    climb.add_argument("--min-gain", type=float, default=0.05)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.handler(args)
    except (EvalError, IsolationUnavailable, RuntimeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

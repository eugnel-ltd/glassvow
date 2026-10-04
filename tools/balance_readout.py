#!/usr/bin/env python3
"""The readout runner and graders: run a cell table in chunks, merge it, and read it.

Everything a Flame readout does between `balance_sim.gd` and the readout document, so any
class's pipeline can be rerun from the repository (docs/design/2026-09-29-dusk-flame/README.md,
section 11). `balance_ways.py` stays the grader of one table (G1-G7 on point and interval);
this adds what readouts 9-13 kept in scratch:

  run         chunked, resumable, parallel runs of cells x arms x a seed band, merged with a manifest check
              (--aspect names the class; pools fresh, entry and full; an aspect with no ways has only A, A_lit, R)
  merge       merge a run directory's chunk reports (for a directory whose merged files were not kept)
  join        join one cell's arms across directories of disjoint seed bands (the longer G3 band)
  paired      paired change of every arm between two runs on the same seeds (exact binomial / McNemar)
  g3          paired G3 on common seeds (Newcombe 1998, method 10 for paired proportions)
  rowb        row B (B1 win rate, B2 expression and close calls) on 95% intervals
  table       the complete section 11 table with reference columns (--tidy for the readout's gate table)
  compare     two run directories, run for run
  candidates  scratch content catalogues for --content, from a lever spec

Every command that launches Godot (`run`) refuses unless the project root's override.cfg sets
`config/use_custom_user_dir=true` and a non-empty `config/custom_user_dir_name`.

Usage (repo root), readout 13's finals:
  python3 -B tools/balance_readout.py run s/final-v0 --seeds 13000-13999 --cells v0-fresh,v0-full --play search --replay --jobs 8
  python3 -B tools/balance_readout.py run s/final-v5 --seeds 13000-14999 --cells v5-fresh,v5-full --play search --replay --jobs 8
  python3 -B tools/balance_readout.py run s/ext-v5 --seeds 15000-16999 --cells v5-full \\
      --arms C_shatter,C_lantern,C_edge,A_lit --play search --jobs 8
  python3 -B tools/balance_readout.py table s/final-v0 s/final-v5 --v0-seeds 13000-13999 --v5-seeds 13000-14999
  python3 -B tools/balance_readout.py join s/g3-4000 v5-full C_shatter,C_lantern,C_edge,A_lit s/final-v5 s/ext-v5
  python3 -B tools/balance_readout.py g3 s/g3-4000 v5-full
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import balance_ways as bw
import balance_readout_catalogue as catalogue
import balance_readout_compare as compare
import balance_readout_run as runner
import balance_readout_tables as tables
from balance_exam import REPO
from balance_readout_guard import require_isolated_user_dir


def _csv(text: str) -> list[str]:
    return [part for part in text.split(",") if part]


def cmd_run(opts: argparse.Namespace) -> int:
    require_isolated_user_dir(REPO)  # before anything is planned or written
    who = bw.roster(opts.aspect, opts.content)
    seeds = bw.parse_seeds(opts.seeds)
    weights = bw.parse_weights(opts.way_weights) if opts.way_weights else None
    content = opts.content.resolve() if opts.content else None
    if content is not None and not content.is_file():
        raise ValueError(f"--content {content} is not a file")
    if opts.play not in bw.PLAYS:
        raise ValueError(f"--play must be one of {bw.PLAYS}")
    if not 1 <= opts.jobs <= 16:
        raise ValueError("--jobs must be 1..16")
    out = opts.out.resolve()
    work = runner.plan(out, who, seeds, _csv(opts.cells), _csv(opts.arms) or list(who.arms), opts.play, opts.chunk, opts.replay,
                       content, weights, opts.godot)
    out.mkdir(parents=True, exist_ok=True)  # only once the plan is accepted
    who = runner.identity(REPO, content)
    start = time.monotonic()
    ran = runner.run_chunks(work, who, opts.jobs)
    names = runner.merge_parts(out, work)
    print(f"merged {len(names)} reports into {out} ({ran} of {len(work)} chunks run, "
          f"{time.monotonic() - start:.0f} s)")
    return 0


def cmd_merge(opts: argparse.Namespace) -> int:
    names = runner.merge_directory(opts.dir, opts.out)
    print(f"merged {len(names)} reports into {opts.out or opts.dir}")
    return 0


def cmd_join(opts: argparse.Namespace) -> int:
    for arm, (count, first, last) in runner.join_bands(opts.out, opts.cell, _csv(opts.arms), opts.dirs).items():
        print(arm, count, first, last)
    return 0


def cmd_paired(opts: argparse.Namespace) -> int:
    print(tables.paired_table(bw.roster(opts.aspect), opts.new, opts.base, _csv(opts.cells), _csv(opts.arms) or None))
    return 0


def cmd_g3(opts: argparse.Namespace) -> int:
    who = bw.roster(opts.aspect)
    who.require_ways()  # G3 reads the best committed arm
    print(tables.g3_table(who, opts.dir, _csv(opts.cells), opts.adaptive))
    return 0


def cmd_rowb(opts: argparse.Namespace) -> int:
    who = bw.roster(opts.aspect)
    who.require_ways()  # row B reads each committed arm
    print(tables.row_b_table(who, opts.dir, opts.vow, opts.ref))
    return 0


def cmd_table(opts: argparse.Namespace) -> int:
    refs = list(zip(opts.refs[::2], opts.refs[1::2]))
    if len(opts.refs) % 2:
        raise ValueError("--ref takes a V0 and a V5 directory, in pairs")
    who = bw.roster(opts.aspect)
    who.require_ways()
    text = tables.full_table(who, opts.v0, opts.v5, bw.parse_seeds(opts.v0_seeds), bw.parse_seeds(opts.v5_seeds), refs)
    print(tables.tidy_gates(text) if opts.tidy else text)
    return 0


def cmd_compare(opts: argparse.Namespace) -> int:
    results = compare.compare_directories(opts.a, opts.b, _csv(opts.reports) or None)
    print(compare.render(results))
    return 0 if compare.identical(results) else 2


def cmd_candidates(opts: argparse.Namespace) -> int:
    for path in catalogue.write_candidates(opts.source, opts.spec, opts.out_dir, _csv(opts.names) or None):
        print(path)
    return 0


def aspect_option(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--aspect", default="duskblade",
                        help="the class: its ways, and so its arms C_<way>, come from content (default duskblade)")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def add(name: str, handler, help_text: str) -> argparse.ArgumentParser:
        p = sub.add_parser(name, help=help_text)
        p.set_defaults(handler=handler)
        return p

    p = add("run", cmd_run, "run, resume and merge a cell table")
    p.add_argument("out", type=Path, help="run directory (parts/ holds the chunks); reruns resume in it")
    aspect_option(p)
    p.add_argument("--seeds", required=True, help="FIRST-LAST inclusive")
    p.add_argument("--cells", default="v0-fresh,v0-full", help="comma list of v<vow>-<pool>")
    p.add_argument("--arms", default="", help="comma list; default every arm of the aspect")
    p.add_argument("--play", default="greedy", choices=bw.PLAYS)
    p.add_argument("--replay", action="store_true", help=f"also run the grader's arm A replay ({bw.REPLAY} seeds) per cell")
    p.add_argument("--chunk", type=int, default=50, help="seeds per chunk")
    p.add_argument("--jobs", type=int, default=4)
    p.add_argument("--content", type=Path, help="a scratch catalogue instead of content/full-content.json")
    p.add_argument("--way-weights", help="COMMIT/OFF, as balance_ways.py")
    p.add_argument("--godot", default="godot")

    p = add("merge", cmd_merge, "merge a directory's parts/ into one report per cell and arm")
    p.add_argument("dir", type=Path)
    p.add_argument("--out", type=Path, help="write the merged reports here instead of into DIR")

    p = add("join", cmd_join, "join one cell's arms across directories of disjoint seed bands")
    p.add_argument("out", type=Path)
    p.add_argument("cell")
    p.add_argument("arms", help="comma list")
    p.add_argument("dirs", nargs="+", type=Path)

    p = add("paired", cmd_paired, "paired change between two runs on the same seeds")
    aspect_option(p)
    p.add_argument("new", type=Path)
    p.add_argument("base", type=Path)
    p.add_argument("cells", help="comma list, e.g. v0-fresh,v0-full")
    p.add_argument("--arms", default="")

    p = add("g3", cmd_g3, "paired G3 on common seeds")
    aspect_option(p)
    p.add_argument("dir", type=Path)
    p.add_argument("cells")
    p.add_argument("--adaptive", default=bw.SKILLED)

    p = add("rowb", cmd_rowb, "row B on intervals")
    aspect_option(p)
    p.add_argument("dir", type=Path)
    p.add_argument("--vow", type=int, default=tables.B_VOW)
    p.add_argument("--ref", type=Path, help="a reference directory for the Before column")

    p = add("table", cmd_table, "the complete section 11 table")
    aspect_option(p)
    p.add_argument("v0", type=Path)
    p.add_argument("v5", type=Path)
    p.add_argument("--v0-seeds", required=True)
    p.add_argument("--v5-seeds", required=True)
    p.add_argument("--ref", dest="refs", action="append", nargs=2, type=Path, default=[],
                   metavar=("V0_DIR", "V5_DIR"), help="a reference table's directories (repeatable)")
    p.add_argument("--tidy", action="store_true", help="the readout's gate table, bold where the last reference moved")

    p = add("compare", cmd_compare, "compare two run directories run for run (exit 2 on any difference)")
    p.add_argument("a", type=Path)
    p.add_argument("b", type=Path)
    p.add_argument("--reports", default="", help="comma list of report names; default every shared report")

    p = add("candidates", cmd_candidates, "write scratch content catalogues from a lever spec")
    p.add_argument("source", type=Path, help="the catalogue to edit, e.g. content/full-content.json")
    p.add_argument("spec", type=Path, help="JSON {name: [lever, ...]}")
    p.add_argument("out_dir", type=Path)
    p.add_argument("--names", default="", help="comma list; default every candidate in the spec")
    return parser


def main(argv: list[str] | None = None) -> int:
    opts = build_parser().parse_args(argv)
    if opts.command == "table":
        opts.refs = [path for pair in opts.refs for path in pair]
    return opts.handler(opts)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError) as exc:
        print(f"balance_readout: {exc}", file=sys.stderr)
        sys.exit(1)

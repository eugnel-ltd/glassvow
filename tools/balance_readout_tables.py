"""Readout tables as Markdown: paired changes, paired G3, row B and the complete section 11 table.

Reads merged report directories (`balance_ways.report_name` layout) and returns text; the
statistics live in `balance_readout_stats`, the graders in `balance_ways`. Ways, arms, gate
order and gate thresholds come from `balance_ways`; row B's thresholds (lock section 11) are
named here once.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import balance_ways as bw
import balance_readout_stats as stats

# Lock section 11, row B (it replaced the old row H on 1 October).
B1_FLOOR = {"full": 0.20, "fresh": 0.10}  # win rate of each committed way, V0, search player
B2_EXPRESSION = 0.60  # share of a way's fights that express it, lower bound
B2_CLOSE = (0.01, 0.10)  # close calls as a share of won fights, band
B_VOW = 0
# Short labels for the nine gate rows `balance_ways.cell_gates` returns, in its order.
GATE_LABELS = ("G1", "G2", "G3", "G4", "G5", "G6", "G7", "G3 floor (A)", "G6 floor (A)")
CELL_ORDER = ((0, "fresh"), (0, "full"), (5, "fresh"), (5, "full"))


def load_rows(directory: Path, cell: str, arm: str) -> list[dict[str, Any]]:
    path = directory / f"{cell}-{arm}.json"
    try:
        return json.loads(path.read_text(encoding="utf-8"))["runs"]
    except (OSError, KeyError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc


def paired_table(who: bw.Roster, new: Path, base: Path, cells: list[str], arms: list[str] | None = None) -> str:
    """Paired change of every arm between two directories on the same seeds."""
    arms = arms or list(who.arms)
    lines = ["| Cell | " + " | ".join(arms) + " |", "|---|" + "---|" * len(arms)]
    for cell in cells:
        out = []
        for arm in arms:
            c = stats.paired_change(load_rows(new, cell, arm), load_rows(base, cell, arm), f"{cell} {arm}")
            p = "< 0.001" if c.p < 0.001 else f"= {c.p:.2f}"
            out.append(f"{100 * c.points:+.1f} pp: {c.gained} / {c.lost}, p {p} (same {c.identical})")
        lines.append(f"| {cell} | " + " | ".join(out) + " |")
    return "\n".join(lines)


def g3_table(who: bw.Roster, directory: Path, cells: list[str], adaptive: str = bw.SKILLED) -> str:
    """G3 on common seeds: the adaptive arm minus the best committed arm, with Newcombe's paired interval."""
    lines = ["| Cell | Best committed | Point | Paired 95% interval | Verdict (point / paired) | "
             "Both / only A_lit / only best / neither | phi |", "|---|---|---|---|---|---|---:|"]
    for cell in cells:
        rows = {arm: load_rows(directory, cell, arm) for arm in who.committed + (adaptive,)}
        best = stats.best_committed(who, rows)
        d = stats.paired_difference(rows[adaptive], rows[best], cell)
        counts = " / ".join(str(x) for x in (d.both, d.only_a, d.only_c, d.neither))
        lines.append(f"| {cell} | {best} | {100 * d.delta:+.1f} pp | {100 * d.low:+.1f} to {100 * d.high:+.1f} pp | "
                     f"{stats.g3_point(d.delta)} / {stats.g3_interval(d)} | {counts} | {d.phi:.2f} |")
    return "\n".join(lines)


def row_b(who: bw.Roster, directory: Path, vow: int = B_VOW) -> dict[tuple[str, str], tuple]:
    """B1 and B2 per pool and arm (each committed arm and the skilled arm), on 95% intervals."""
    out = {}
    for pool in bw.POOLS:
        for arm in who.committed + (bw.SKILLED,):
            _, runs = bw.load_report(directory / bw.report_name(vow, pool, arm), None, who.rates)
            way = who.arms[arm][0]
            rate = bw.interval(sum(stats.won(r) for r in runs), len(runs))
            f = bw.feel(runs, way, who.ways)
            if f is None:
                raise ValueError(f"{bw.report_name(vow, pool, arm)}: no per-fight flame rows for row B")
            expression = bw.interval(f["shown"], f["fights"])
            close = bw.interval(int(f["close"]), f["won"])
            b1 = bw.decided([bw.at_least(rate, B1_FLOOR[pool])])
            b2 = bw.decided([bw.at_least(expression, B2_EXPRESSION), bw.at_least(close, B2_CLOSE[0]),
                             bw.at_most(close, B2_CLOSE[1])])
            out[pool, arm] = (rate, b1, expression, close, b2, len(runs), f)
    return out


def _span(span: tuple[float, float, float]) -> str:
    return f"{bw.pct(span[0])} ({100 * span[1]:.1f}–{100 * span[2]:.1f})"


def row_b_table(who: bw.Roster, directory: Path, vow: int = B_VOW, reference: Path | None = None) -> str:
    rows, before = row_b(who, directory, vow), row_b(who, reference, vow) if reference else None
    head = "| Cell | Arm | Win rate (95%) | B1 | Expression (95%) | Close calls (95%) | B2 |"
    lines = [head + (" Before B1 / B2 |" if before else ""), "|---|---|---|---|---|---|---|" + ("---|" if before else "")]
    for pool in bw.POOLS:
        for arm in who.committed + (bw.SKILLED,):
            rate, b1, expression, close, b2, _, _ = rows[pool, arm]
            extra = f" {before[pool, arm][1]} / {before[pool, arm][4]} |" if before else ""
            lines.append(f"| V{vow} {pool} | {arm} | {_span(rate)} | {b1} | {_span(expression)} | "
                         f"{_span(close)} | {b2} |{extra}")
    return "\n".join(lines)


def graded(who: bw.Roster, v0: Path, v5: Path, v0_seeds: tuple[int, int], v5_seeds: tuple[int, int]) -> dict:
    """Both vows' graded cells: {(vow, pool): {"stats", "gates", "intervals"}}."""
    cells: dict = {}
    cells.update(bw.grade(who, v0, v0_seeds, (0,))["cells"])
    cells.update(bw.grade(who, v5, v5_seeds, (5,))["cells"])
    return cells


def full_table(who: bw.Roster, v0: Path, v5: Path, v0_seeds: tuple[int, int], v5_seeds: tuple[int, int],
               references: list[tuple[Path, Path]] | None = None) -> str:
    """The complete section 11 table: win rates, every gate in every cell on point and 95% interval,
    row B, and the verdicts of each reference table (a previous readout's or a baseline's) beside it."""
    references = references or []
    cells = graded(who, v0, v5, v0_seeds, v5_seeds)
    refs = [graded(who, a, b, v0_seeds, v5_seeds) for a, b in references]
    lines = ["### Win rates", "", "| Cell | " + " | ".join(who.arms) + " |", "|---|" + "---|" * len(who.arms)]
    for cell in CELL_ORDER:
        st = cells[cell]["stats"]
        lines.append(f"| V{cell[0]} {cell[1]} | " + " | ".join(
            f"{bw.pct(st[a]['rate'])} ({100 * st[a]['wilson'][0]:.1f}–{100 * st[a]['wilson'][1]:.1f})"
            for a in who.arms) + " |")
    lines += ["", "### Gates", "", "| Cell | Gate | Measured | Point | 95% interval | Interval verdict |"
              + "".join(f" Ref {k + 1} (point / interval) |" for k in range(len(refs))),
              "|---|---|---|---|---|---|" + "---|" * len(refs)]
    for cell in CELL_ORDER:
        c = cells[cell]
        if not len(GATE_LABELS) == len(c["gates"]) == len(c["intervals"]):
            raise ValueError("balance_ways returns a different set of gates than GATE_LABELS names")
        for i, name in enumerate(GATE_LABELS):
            gate, interval = c["gates"][i], c["intervals"][i]
            before = "".join(f" {r[cell]['gates'][i][3]} / {r[cell]['intervals'][i][1]} |" for r in refs)
            lines.append(f"| V{cell[0]} {cell[1]} | {name} | {gate[1]} | {gate[3]} | {interval[0]} | "
                         f"{interval[1]} |{before}")
    lines += ["", f"### Row B (V{B_VOW}, search player)", "",
              row_b_table(who, v0, B_VOW, references[0][0] if references else None)]
    return "\n".join(lines)


def tidy_gates(full: str) -> str:
    """The gate table of `full_table` for a readout: en dashes in ranges, minus signs, and a bold
    verdict wherever it moved from the last reference column. Needs at least one reference."""
    block = full.split("### Gates\n\n")[1].split("\n\n### Row B")[0].strip().splitlines()
    head = [c.strip() for c in block[0].strip("|").split("|")]
    if len(head) < 7:
        raise ValueError("tidy needs a reference table in the full table")
    out = ["| " + " | ".join(head[:5] + ["Interval"] + [h.replace("Ref ", "Reference ") for h in head[6:]]) + " |",
           "|" + "---|" * len(head)]
    for line in block[2:]:
        cells = [c.strip() for c in line.strip("|").split("|")]
        point, sure = cells[3], cells[5]
        last_point, last_sure = [x.strip() for x in cells[-1].split(" / ")]
        span = re.sub(r"(\d)%-(\d)", r"\1–\2", cells[4])
        span = span.replace(" - ", " − ")
        measured = cells[2].replace(" - ", " − ").replace("(-", "(−")
        out.append("| " + " | ".join([cells[0], cells[1], measured, point if point == last_point else f"**{point}**",
                                      span, sure if sure == last_sure else f"**{sure}**"] + cells[6:]) + " |")
    return "\n".join(out)

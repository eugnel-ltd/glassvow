"""Static HTML pages: the input review page and the per-case results page."""
from __future__ import annotations

import html
from typing import Any, Mapping, Sequence

from .models import Case

STYLE = """
:root{--bg:#fff;--fg:#1b1b1b;--muted:#666;--line:#ddd;--bad:#b3261e;--ok:#1b6e3c}
@media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#e8e8e8;--muted:#999;--line:#333;
--bad:#ff8a80;--ok:#7bd88f}}
body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;margin:0 auto;
max-width:62rem;padding:1rem 16px 3rem}
table{border-collapse:collapse;width:100%}th,td{border-bottom:1px solid var(--line);
padding:.35rem .5rem;text-align:left;vertical-align:top}
pre{white-space:pre-wrap;background:transparent;border:1px solid var(--line);padding:.6rem}
.muted{color:var(--muted)}.bad{color:var(--bad)}.ok{color:var(--ok)}
"""


def _page(title: str, body: str) -> str:
    return (f'<!doctype html><html lang="en-GB"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f"<title>{html.escape(title)}</title><style>{STYLE}</style></head>"
            f"<body><h1>{html.escape(title)}</h1>{body}</body></html>")


def review_html(eval_name: str, cases: Sequence[Case], cases_sha256: str) -> str:
    """Every case input with its source and why_hard, for the input checkpoint."""
    parts = [f'<p class="muted">cases sha256 <code>{cases_sha256}</code>; {len(cases)} cases. '
             "Approve with <code>approve-inputs</code> once every case is realistic, "
             "unambiguous and chosen for a stated reason.</p>"]
    for case in cases:
        parts.append(
            f"<section><h2>{html.escape(case.id)}</h2>"
            f"<p><b>source</b> <code>{html.escape(case.source)}</code></p>"
            f"<p><b>why hard</b> {html.escape(case.why_hard)}</p>"
            f"<pre>{html.escape(case.user_prompt())}</pre>"
            f"<p><b>reference answer</b> {html.escape(case.reference)}</p></section>")
    return _page(f"Review: {eval_name}", "".join(parts))


def results_html(eval_name: str, results: Mapping[str, Any]) -> str:
    """Per-case scores for every model, each linking to its transcripts."""
    parts = []
    for warning in results["warnings"]:
        parts.append(f'<p class="bad">{html.escape(warning)}</p>')
    for model, data in results["models"].items():
        summary = data["summary"]
        parts.append(
            f"<h2>{html.escape(model)}: {summary['mean']:.1%} "
            f'<span class="muted">(95% CI {summary["ci_low"]:.1%} to {summary["ci_high"]:.1%})'
            "</span></h2><table><tr><th>case</th><th>mean</th><th>repetitions</th></tr>")
        for case_id, row in data["per_case"].items():
            links = " ".join(f'<a href="{html.escape(path)}">r{n}: {score:.0%}</a>'
                             for n, (path, score) in enumerate(zip(row["transcripts"], row["scores"]), 1))
            klass = "ok" if row["mean"] >= 1 else ("bad" if row["mean"] == 0 else "")
            parts.append(f'<tr><td>{html.escape(case_id)}</td><td class="{klass}">'
                         f'{row["mean"]:.0%}</td><td>{links}</td></tr>')
        parts.append("</table>")
    return _page(f"Results: {eval_name} {results['run_id']}", "".join(parts))

"""Apply a proposer's unified diff to a surface copy and screen it for failure injection."""
from __future__ import annotations

import re
from typing import Sequence

from .models import EvalError, normalise_space

DEFAULT_MIN_SPAN = 40
HUNK_HEADER = re.compile(r"^@@ -(\d+)(?:,\d+)? \+\d+(?:,\d+)? @@")


class PatchError(EvalError):
    """The diff is malformed or does not apply to the surface."""


def _parse_hunks(diff: str) -> list[tuple[int, list[tuple[str, str]]]]:
    hunks: list[tuple[int, list[tuple[str, str]]]] = []
    for line in diff.splitlines():
        header = HUNK_HEADER.match(line)
        if header:
            hunks.append((int(header.group(1)), []))
        elif hunks and line[:1] in (" ", "-", "+"):
            hunks[-1][1].append((line[0], line[1:]))
        elif hunks and line == "":
            hunks[-1][1].append((" ", ""))  # a blank context line stripped by the proposer
    if not hunks or not any(tag in "+-" for _, body in hunks for tag, _ in body):
        raise PatchError("the diff has no hunk that changes anything")
    return hunks


def _locate(lines: list[str], old: list[str], start: int, hint: int) -> int:
    """Index where `old` occurs at or after `start`, nearest to the header's line hint."""
    if not old:
        return min(max(start, hint - 1), len(lines))
    matches = [i for i in range(start, len(lines) - len(old) + 1)
               if all(lines[i + k].rstrip() == old[k].rstrip() for k in range(len(old)))]
    if not matches:
        raise PatchError("a hunk's context and removed lines do not occur in the surface")
    return min(matches, key=lambda i: abs(i - (hint - 1)))


def apply_unified_diff(text: str, diff: str) -> str:
    """Apply hunks by matching their old lines; header line numbers are only a hint."""
    lines = text.split("\n")
    cursor = 0
    for hint, body in _parse_hunks(diff):
        old = [content for tag, content in body if tag in " -"]
        new = [content for tag, content in body if tag in " +"]
        at = _locate(lines, old, cursor, hint)
        lines[at:at + len(old)] = new
        cursor = at + len(new)
    return "\n".join(lines)


def added_text(diff: str) -> str:
    """Every added line. `+++` is skipped only in the file header before the first hunk."""
    added, in_hunk = [], False
    for line in diff.splitlines():
        if HUNK_HEADER.match(line):
            in_hunk = True
        elif line.startswith("+") and (in_hunk or not line.startswith("+++")):
            added.append(line[1:])
    return "\n".join(added)


def find_shared_span(candidate: str, sources: Sequence[str],
                     min_chars: int = DEFAULT_MIN_SPAN) -> str | None:
    """A verbatim span of >= min_chars (whitespace normalised, case folded) shared with a source."""
    needle = normalise_space(candidate)
    haystack = "\x00".join(normalise_space(source) for source in sources)
    for start in range(len(needle) - min_chars + 1):
        window = needle[start:start + min_chars]
        if window in haystack:
            return window
    return None


def find_injection(diff: str, case_texts: Sequence[str],
                   min_chars: int = DEFAULT_MIN_SPAN) -> str | None:
    """The span a patch copied from a case input or expected answer, if any."""
    return find_shared_span(added_text(diff), case_texts, min_chars)

"""Candidate content catalogues: a lever or two applied to content/full-content.json as text edits.

The output is a scratch catalogue for `--content`; because every lever is a minimal text edit
the diff against the source is exactly the lever. A candidate is a list of levers, read from a
JSON spec `{"name": [lever, ...]}`:

  {"lever": "affinity", "way": "shatter", "card": "heavyBlow", "weight": 1.0}   # weight null removes the card
  {"lever": "knob", "key": "trueMin", "old": "0.8", "new": "0.75"}              # a unique `"key": old` literal
  {"lever": "strip_rider", "card": "hearthfall", "effect": {"kind": "ember", "n": 1, "lit": "lantern"},
   "text": " Amber flame: gain 1 Ember."}   # drop that effect from the base and upgraded effects and its text

Candidate names may join specs with `+` (all their levers apply). Nothing here names a class or a way.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


def set_affinity(text: str, way: str, card: str, weight: float | None) -> str:
    """Set (or add, or with None remove) a card's weight in a way's affinity block."""
    m = re.search(r'"id": "%s",.*?"affinity": \{(.*?)\n(\s*)\}' % re.escape(way), text, re.S)
    if not m:
        raise ValueError(f"no affinity block for way {way!r}")
    body = m.group(1)
    indent = re.search(r"\n(\s*)\"", body).group(1)
    entries = [list(re.match(r'\s*"(\w+)": ([0-9.]+),?', ln).groups()) for ln in body.split("\n") if ln.strip()]
    found = [e for e in entries if e[0] == card]
    if weight is None:
        if not found:
            raise ValueError(f"{card!r} is not in {way!r}'s affinity block")
        entries = [e for e in entries if e[0] != card]
    elif found:
        found[0][1] = f"{weight}"
    else:
        entries.append([card, f"{weight}"])
    new_body = "\n" + ",\n".join(f'{indent}"{k}": {v}' for k, v in entries)
    return text[:m.start(1)] + new_body + text[m.end(1):]


def set_knob(text: str, key: str, old: str, new: str) -> str:
    """Replace the one `"key": old` literal (a constant of the content file) with `"key": new`."""
    needle = f'"{key}": {old}'
    if text.count(needle) != 1:
        raise ValueError(f"{needle!r} must occur exactly once, found {text.count(needle)}")
    return text.replace(needle, f'"{key}": {new}')


def _block(text: str, card: str) -> tuple[int, int]:
    start = text.index(f'\n    "{card}": {{') + 1
    depth, i = 0, text.index("{", start)
    while True:
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        if depth == 0:
            return start, i + 1
        i += 1


def strip_rider(text: str, card: str, effect: dict[str, Any], printed: str = "") -> str:
    """Remove `effect` from the card's base and upgraded effect lists (exactly once each) and `printed` from its text."""
    start, end = _block(text, card)
    block = text[start:end]
    fields = r",\s*".join(rf'"{re.escape(k)}":\s*{re.escape(json.dumps(v))}' for k, v in effect.items())
    block, count = re.subn(rf",\s*\{{\s*{fields}\s*\}}", "", block)
    if count != 2:
        raise ValueError(f"{card!r}: expected the effect in base and upgrade, found it {count} time(s)")
    return text[:start] + block.replace(printed, "") + text[end:]


def apply_lever(text: str, lever: dict[str, Any]) -> str:
    kind = lever.get("lever")
    if kind == "affinity":
        return set_affinity(text, lever["way"], lever["card"], lever["weight"])
    if kind == "knob":
        return set_knob(text, lever["key"], lever["old"], lever["new"])
    if kind == "strip_rider":
        return strip_rider(text, lever["card"], lever["effect"], lever.get("text", ""))
    raise ValueError(f"unknown lever {kind!r}")


def build(source: str, spec: dict[str, list[dict[str, Any]]], name: str) -> str:
    """The source text with every lever of the (possibly `+`-joined) candidate `name` applied; must stay JSON."""
    text = source
    for part in name.split("+"):
        if part not in spec:
            raise ValueError(f"candidate {part!r} is not in the spec ({sorted(spec)})")
        for lever in spec[part]:
            text = apply_lever(text, lever)
    json.loads(text)
    return text


def write_candidates(source: Path, spec_path: Path, out_dir: Path, names: list[str] | None = None) -> list[Path]:
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    text = source.read_text(encoding="utf-8")
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for name in names or list(spec):
        path = out_dir / f"{name}.json"
        path.write_text(build(text, spec, name), encoding="utf-8")
        paths.append(path)
    return paths

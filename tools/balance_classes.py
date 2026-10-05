"""What the balance tools know about a class: its ways and its unlock, from content, and their stats.

The Python half of `balance_classes.gd`. An aspect's way ids come from content
(`aspects[i].ways`, in content order), and so does its `unlock`, which marks a class
that unlocks later (the template's section 3: it reads the `entry` pool in `fresh`'s
place); the run stat each way's play produces comes
from `tools/balance_classes.json`, the one file that holds what content does not
(`content/full-content.json` is bound to the 1.0 verdict by SHA-256, docs/rc-bar.md
P9, and stays untouched). A class that declares no ways needs no entry; a later
class is one entry plus its content ways. A way the file gives no stat is an error.
"""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from balance_exam import REPO

CLASS_FILE = Path(__file__).resolve().with_name("balance_classes.json")
CONTENT = REPO / "content" / "full-content.json"


@dataclass(frozen=True)
class ClassRow:
    aspect: str
    name: str  # the class's bare name, for headings
    ways: tuple[str, ...]  # way ids in content order
    stats: tuple[str, ...]  # each way's run stat, in the same order
    unlock: str = ""  # the content unlock id of a class that unlocks later; empty for one playable at once


def _read_json(path: Path) -> dict:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {path}: {exc}") from exc
    if not isinstance(raw, dict):
        raise ValueError(f"{path} is not a JSON object")
    return raw


def aspect_ids(content: Path | None = None) -> tuple[str, ...]:
    return tuple(str(row.get("id")) for row in _read_json(content or CONTENT).get("aspects", []))


def read_class(aspect: str, content: Path | None = None, class_file: Path = CLASS_FILE) -> ClassRow:
    """The class of aspect id `aspect`: way ids and unlock from `content`, way stats from the class file."""
    rows = {str(row.get("id")): row for row in _read_json(content or CONTENT).get("aspects", [])}
    if aspect not in rows:
        raise ValueError(f"--aspect must be one of {', '.join(rows)}, got {aspect!r}")
    ways = tuple(str(way["id"]) for way in rows[aspect].get("ways", []))
    listed = _read_json(class_file).get(aspect, {}).get("wayStats", {})
    missing = [way for way in ways if way not in listed]
    if missing:
        raise ValueError(f"{class_file.name} has no wayStats entry for way {', '.join(missing)} of {aspect}")
    return ClassRow(aspect, str(rows[aspect].get("nameBare", aspect)), ways, tuple(str(listed[w]) for w in ways),
                    str(rows[aspect].get("unlock", "")))

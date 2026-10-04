"""Isolation guard for every readout command that launches Godot.

Godot ignores `config/custom_user_dir_name` unless `config/use_custom_user_dir` is also
true, and then the run writes into the owner's real profile under app_userdata. The
project root's `override.cfg` must therefore carry, under `[application]`, both
`config/use_custom_user_dir=true` and a non-empty `config/custom_user_dir_name`.
`override.cfg` is never committed (it is local to a worktree).
"""
from __future__ import annotations

from pathlib import Path

OVERRIDE = "override.cfg"
SECTION = "application"
USE_KEY = "config/use_custom_user_dir"
NAME_KEY = "config/custom_user_dir_name"


class IsolationError(RuntimeError):
    """The project root is not provably isolated from the owner's real profile."""


def parse_override(text: str) -> dict[str, str]:
    """A Godot config file as {"section/key": value}; values are unquoted, comments dropped."""
    values: dict[str, str] = {}
    section = ""
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            continue
        key, sep, value = line.partition("=")
        if sep:
            values[f"{section}/{key.strip()}" if section else key.strip()] = value.strip().strip('"')
    return values


def require_isolated_user_dir(root: Path) -> str:
    """The isolated user-dir name, or an IsolationError saying exactly what is missing."""
    path = root / OVERRIDE
    why = ("a run without it writes into the owner's real Godot profile "
           "(~/Library/Application Support/Godot/app_userdata). Create it with:\n"
           f"[{SECTION}]\n{USE_KEY}=true\n{NAME_KEY}=\"glassvow-<purpose>\"")
    if not path.is_file():
        raise IsolationError(f"refusing to launch Godot: {path} does not exist; {why}")
    values = parse_override(path.read_text(encoding="utf-8"))
    use, name = values.get(f"{SECTION}/{USE_KEY}"), values.get(f"{SECTION}/{NAME_KEY}", "")
    if use != "true":
        raise IsolationError(f"refusing to launch Godot: {path} does not set {USE_KEY}=true under "
                             f"[{SECTION}] (Godot ignores the name without it); {why}")
    if not name:
        raise IsolationError(f"refusing to launch Godot: {path} sets no non-empty {NAME_KEY} under "
                             f"[{SECTION}]; {why}")
    return name

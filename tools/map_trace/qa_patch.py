#!/usr/bin/env python3
"""Arm a measuring worktree with the map trace probe (developer tool).

The probe (tools/map_trace/probe.gd) lives under `tools/map_*`, which every
store preset excludes, and QA builds export the store "iOS" preset. So the
probe is never committed into `main.gd`: this script copies it into the target
worktree as `tools/qa_map_trace_probe.gd` (a name the presets pack) and adds
two flags to that worktree's `application/main.gd`, uncommitted:

  --map-trace-probe   hand the `--map` boot to the probe
  --map-lean          the lean profile (phones and tablets) on any machine

Run it on a detached worktree made for measuring, never on a branch you
commit from; `--check` reports whether a worktree is armed.

Usage:
  python3 tools/map_trace/qa_patch.py <worktree>
  python3 tools/map_trace/qa_patch.py <worktree> --check
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

PROBE = Path(__file__).resolve().parent / "probe.gd"
TARGET = "tools/qa_map_trace_probe.gd"
EDITS = (
    ('''		elif arg == "--map-rest":
			map_rest = true''',
     '''		elif arg == "--map-rest":
			map_rest = true
		elif arg == "--map-trace-probe":
			map_trace_probe = true
		elif arg == "--map-lean":
			MapScene.lean_override = 1'''),
    ('''	var map_rest: bool = false''',
     '''	var map_rest: bool = false
	var map_trace_probe: bool = false'''),
    ('''		if map_rest:
			_attach_map_rest_bench()''',
     '''		if map_trace_probe:
			var trace_probe: Variant = (load("res://%s") as GDScript).new()
			if trace_probe is Node:
				var trace_node: Node = trace_probe
				add_child(trace_node)
			return
		if map_rest:
			_attach_map_rest_bench()''' % TARGET),
)


def armed(worktree: Path) -> bool:
    return "--map-trace-probe" in (worktree / "application/main.gd").read_text()


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 64
    worktree = Path(argv[1]).resolve()
    if "--check" in argv[2:]:
        print("armed" if armed(worktree) else "not armed")
        return 0
    if armed(worktree):
        shutil.copyfile(PROBE, worktree / TARGET)
        print("already armed; probe refreshed: %s" % (worktree / TARGET))
        return 0
    branch = subprocess.run(["git", "-C", str(worktree), "symbolic-ref", "-q", "HEAD"],
                            capture_output=True, text=True).stdout.strip()
    if branch:
        print("refusing: %s is on %s; arm a detached measuring worktree" % (worktree, branch))
        return 2
    path = worktree / "application/main.gd"
    text = path.read_text()
    for before, after in EDITS:
        if text.count(before) != 1:
            print("refusing: main.gd anchor not found once:\n%s" % before)
            return 2
        text = text.replace(before, after)
    path.write_text(text)
    shutil.copyfile(PROBE, worktree / TARGET)
    print("armed: %s (+ %s)" % (path, TARGET))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

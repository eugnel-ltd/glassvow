#!/usr/bin/env python3
"""CI-negative check: an exported script may not load a path the export drops.

A store export omits everything in a preset's `exclude_filter`, and Godot never
packs a folder that holds a `.gdignore`. A `preload()` of such a path is a
compile-time dependency, so the script fails to parse and every script that
depends on it fails with it; a `load()` returns null at runtime.

Limitation: only string literals inside the call are seen. A path held in a
constant and loaded later is out of reach of a text check.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath

from check_store_dev_exclusion import STORE, csv, hits, parse_presets

# Never packed whatever the presets say, so a deleted filter cannot open them.
ALWAYS_UNEXPORTED = ("docs/", "tests/", "port_fixtures/", "presentation/dev/")
GDIGNORE = ".gdignore"
LOAD_RE = re.compile(
    r"\b(?:preload|load|ResourceLoader\.load|FileAccess\.get_file_as_string"
    r"|FileAccess\.open)\(\s*[\"']res://([^\"']+)[\"']"
)
# Guarded runtime lookups: each is a `load()` that is null-checked and reports
# through push_error(), reached only by an explicit developer launch flag. The
# Dev Review presets pack these scripts; a store build never asks for them.
RUNTIME_ALLOW = frozenset({
    ("application/main.gd", "tools/bench_map_assets.gd"),
    ("application/main.gd", "tools/bench_map_scene.gd"),
    ("application/main.gd", "tools/bench_combat.gd"),
    ("application/main.gd", "tools/bench_map_open.gd"),
})


def tracked_paths(root: Path) -> list[str]:
    out = subprocess.check_output(["git", "ls-files"], cwd=root, text=True)
    return [ln for ln in out.splitlines() if ln]


def ignored_dirs(tracked: list[str]) -> tuple[str, ...]:
    dirs = []
    for path in tracked:
        pure = PurePosixPath(path)
        if pure.name == GDIGNORE:
            parent = "" if str(pure.parent) == "." else str(pure.parent) + "/"
            dirs.append(parent)
    return tuple(dirs)


def store_filters(presets_text: str) -> list[list[str]]:
    by_name = {item["name"]: item for item in parse_presets(presets_text)}
    return [csv(by_name[name]["exclude_filter"]) for name in STORE if name in by_name]


def is_unexported(rel: str, filters: list[list[str]], ignored: tuple[str, ...]) -> bool:
    """True when at least one store preset would not pack `rel`."""
    if rel.startswith(ALWAYS_UNEXPORTED) or rel.startswith(ignored):
        return True
    return any(hits(globs, rel) for globs in filters)


def blank_comments(text: str) -> str:
    """Blank full-line comments, keeping line numbers, so a note cannot trip the scan."""
    return "\n".join("" if ln.lstrip().startswith("#") else ln for ln in text.splitlines())


def check_tree(
    root: Path,
    tracked: list[str],
    presets_text: str,
    allow: frozenset[tuple[str, str]] = RUNTIME_ALLOW,
) -> list[str]:
    errors: list[str] = []
    filters = store_filters(presets_text)
    if len(filters) != len(STORE):
        errors.append("export presets missing one of %s" % ", ".join(STORE))
        return errors
    ignored = ignored_dirs(tracked)
    scripts = [p for p in tracked if p.endswith(".gd") and not is_unexported(p, filters, ignored)]
    if not scripts:
        errors.append("no exported .gd script found (vacuous scan)")
    for path in scripts:
        text = blank_comments((root / path).read_text(errors="replace"))
        for match in LOAD_RE.finditer(text):
            target = match.group(1)
            if not is_unexported(target, filters, ignored) or (path, target) in allow:
                continue
            line = text.count("\n", 0, match.start()) + 1
            errors.append("%s:%d: exported script loads res://%s, which the export drops"
                          % (path, line, target))
    return errors


def report(errors: list[str]) -> int:
    for msg in errors:
        print(msg, file=sys.stderr)
    return 1 if errors else 0


def self_test() -> int:
    presets = "\n".join(
        '[preset.%d]\nname="%s"\ncustom_features=""\nexclude_filter="tests/*,tools/check_*,tools/bench_*,'
        'presentation/dev/*,port_fixtures/*"' % (i, name) for i, name in enumerate(STORE))
    files = {
        "application/ok.gd": 'const A = preload("res://tools/vow_incentives.gd")\n',
        "application/comment.gd": '# preload("res://docs/note.json")\n',
        "application/docs.gd": 'const A = preload("res://docs/map/x.json")\n',
        "application/multi.gd": 'var a = load(\n\t"res://tests/t.gd")\n',
        "application/filter.gd": 'var a = load("res://tools/check_x.py")\n',
        "application/hidden.gd": 'var a = FileAccess.open("res://site/x.json", 1)\n',
        "application/lab.gd": 'var a = load("res://port_fixtures/c.json")\n',
        "application/bench.gd": 'var a = load("res://tools/bench_x.gd")\n',
        "tests/test_skip.gd": 'const A = preload("res://docs/x.json")\n',
        "docs/.gdignore": "",
        "docs/x.json": "{}",
        "site/.gdignore": "",
        "tools/vow_incentives.gd": "extends RefCounted\n",
    }
    cases = (
        ("clean runtime path", "application/ok.gd", None),
        ("comment ignored", "application/comment.gd", None),
        ("docs preload", "application/docs.gd", "res://docs/map/x.json"),
        ("multi-line load", "application/multi.gd", "res://tests/t.gd"),
        ("filter glob", "application/filter.gd", "res://tools/check_x.py"),
        ("gdignore folder", "application/hidden.gd", "res://site/x.json"),
        ("port fixture load", "application/lab.gd", "res://port_fixtures/c.json"),
        ("unexported file not scanned", "tests/test_skip.gd", None),
    )
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for rel, body in files.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(body)
        tracked = sorted(files)
        errors = check_tree(root, tracked, presets, frozenset())
        for name, path, want in cases:
            got = [e for e in errors if e.startswith(path + ":")]
            ok = (not got) if want is None else (len(got) == 1 and want in got[0])
            print("%s - %s" % ("ok" if ok else "not ok", name))
            failures += 0 if ok else 1
        allowed = check_tree(root, tracked, presets,
                             frozenset({("application/bench.gd", "tools/bench_x.gd")}))
        ok = not any(e.startswith("application/bench.gd:") for e in allowed)
        print("%s - allow-list entry" % ("ok" if ok else "not ok"))
        failures += 0 if ok else 1
        bad = check_tree(root, tracked, "", frozenset())
        ok = any("missing" in e for e in bad)
        print("%s - missing presets fail closed" % ("ok" if ok else "not ok"))
        failures += 0 if ok else 1
    if failures:
        print("%d export-paths self-test case(s) failed" % failures, file=sys.stderr)
        return 1
    print("export-paths self-test OK (10 cases)")
    return 0


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv == ["--self-test"]:
        return self_test()
    if argv:
        print("usage: check_export_paths.py [--self-test]", file=sys.stderr)
        return 2
    root = Path(os.environ.get("EXPORT_PATHS_ROOT", Path(__file__).resolve().parent.parent))
    presets = (root / "export_presets.cfg").read_text()
    rc = report(check_tree(root, tracked_paths(root), presets))
    if rc == 0:
        print("export-paths OK")
    return rc


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Payload report: how many bytes a store export packs, per asset group.

Walks every `*.import` sidecar, sums the imported artefacts under
`.godot/imported/` that the chosen export preset would pack (only the texture
variants for the preset's platform), adds files that have no importer at their
raw size, drops everything the preset's `exclude_filter` matches, and compares
the totals with `tools/payload_budget.json`. The exit status is non-zero when
any budget is exceeded.

It estimates the `.pck` payload; it does not read the `.pck`, so run the
import first (`godot --headless --import`) so the artefacts exist.

Usage:
  python3 tools/payload_report.py [--preset iOS] [--budget FILE] [--root DIR]
  python3 tools/payload_report.py --self-test
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
import tempfile
from pathlib import Path

MIB = 1024 * 1024
DEFAULT_PRESET = "iOS"
DEFAULT_BUDGET = "tools/payload_budget.json"
IMPORTED_DIR = ".godot/imported"
# Texture remap keys (`path.<feature>`) that each platform's export keeps.
PLATFORM_FEATURES = {
    "iOS": {"etc2", "astc"},
    "Android": {"etc2", "astc"},
    "macOS": {"s3tc", "bptc"},
    "Windows": {"s3tc", "bptc"},
    "Linuxbsd": {"s3tc", "bptc"},
}
# `export_filter="all_resources"` packs resources only. A file with no importer
# counts when it is one of these kinds; scripts are counted at source size
# (the pack stores smaller bytecode), so the estimate errs high. Markdown,
# Python, headers and GDExtension native libraries are never packed.
RAW_PACKED_SUFFIXES = (
    ".gd", ".tscn", ".tres", ".res", ".scn", ".json", ".cfg", ".gdextension",
    ".gdshader", ".icns", ".svg", ".bin",
)
UNPACKED_BUNDLES = (".xcframework", ".framework")
UNPACKED_FILES = ("export_presets.cfg", "override.cfg")
UNPACKED_DIRS = (".godot", ".git", ".github", ".claude", "build", "export", "artifacts")
GROUP_DEPTH = 3  # assets/<kind>/<group>


def parse_presets(text: str) -> list[dict[str, str]]:
    """Return one dict of top-level key/values per `[preset.N]` section."""
    presets: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    for line in text.splitlines():
        section = re.fullmatch(r"\[(.+)\]", line.strip())
        if section:
            current = {} if re.fullmatch(r"preset\.\d+", section.group(1)) else None
            if current is not None:
                presets.append(current)
            continue
        if current is not None and "=" in line and not line.lstrip().startswith(";"):
            key, _, value = line.partition("=")
            current[key.strip()] = value.strip().strip('"')
    return presets


def preset_named(text: str, name: str) -> dict[str, str]:
    for preset in parse_presets(text):
        if preset.get("name") == name:
            return preset
    raise SystemExit(f"payload_report: no export preset named {name!r}")


def split_filter(value: str) -> list[str]:
    return [part.strip().lower() for part in value.split(",") if part.strip()]


def is_excluded(rel: str, filters: list[str]) -> bool:
    """Godot matches each filter, case-insensitively, against the res:// path
    and the bare relative path; `*` also crosses `/`."""
    lowered = rel.lower()
    return any(
        fnmatch.fnmatchcase(lowered, pattern) or fnmatch.fnmatchcase("res://" + lowered, pattern)
        for pattern in filters
    )


def group_of(rel: str) -> str:
    parts = rel.split("/")
    if parts[0] == "assets" and len(parts) > GROUP_DEPTH:
        return "/".join(parts[:GROUP_DEPTH])
    if len(parts) > 1:
        return "/".join(parts[:2]) if parts[0] == "assets" else parts[0]
    return "(root)"


def packed_artefacts(import_file: Path, features: set[str]) -> list[str]:
    """res:// paths of the imported artefacts the platform packs."""
    text = import_file.read_text(encoding="utf-8")
    remap = text.split("[deps]", 1)[0]
    chosen: list[str] = []
    variant_seen = False
    for key, value in re.findall(r'^(path(?:\.\w+)?)="([^"]+)"', remap, re.MULTILINE):
        if key == "path":
            chosen.append(value)
        else:
            variant_seen = True
            if key.split(".", 1)[1] in features:
                chosen.append(value)
    if chosen or variant_seen:
        return chosen
    dests = re.search(r"^dest_files=\[(.*)\]", text, re.MULTILINE)
    return re.findall(r'"([^"]+)"', dests.group(1)) if dests else []


def source_of(import_file: Path, root: Path) -> str:
    return import_file.relative_to(root).as_posix()[: -len(".import")]


def walk_files(root: Path) -> list[str]:
    """Project files, skipping hidden, native-bundle and `.gdignore` trees."""
    found: list[str] = []
    stack = [root]
    while stack:
        folder = stack.pop()
        if (folder / ".gdignore").exists():
            continue
        for entry in folder.iterdir():
            rel = entry.relative_to(root).as_posix()
            if entry.is_dir():
                hidden = entry.name.startswith(".") or entry.name.endswith(UNPACKED_BUNDLES)
                if hidden or (folder == root and entry.name in UNPACKED_DIRS):
                    continue
                stack.append(entry)
            elif not entry.name.startswith("."):
                found.append(rel)
    return sorted(found)


def measure(root: Path, preset: dict[str, str]) -> tuple[dict[str, int], list[str]]:
    """Return ({group: packed bytes}, [problems]) for the preset."""
    filters = split_filter(preset.get("exclude_filter", ""))
    features = PLATFORM_FEATURES.get(preset.get("platform", ""), set())
    sizes: dict[str, int] = {}
    problems: list[str] = []
    files = walk_files(root)
    imported_sources = {f[: -len(".import")] for f in files if f.endswith(".import")}
    for rel in files:
        if rel.endswith(".import"):
            source = rel[: -len(".import")]
            if is_excluded(source, filters):
                continue
            for res_path in packed_artefacts(root / rel, features):
                artefact = root / res_path.removeprefix("res://")
                if artefact.is_file():
                    sizes[group_of(source)] = sizes.get(group_of(source), 0) + artefact.stat().st_size
                else:
                    problems.append(f"missing artefact {res_path} (run godot --headless --import)")
        elif not rel.endswith(RAW_PACKED_SUFFIXES) or rel in imported_sources or rel in UNPACKED_FILES:
            continue
        elif not is_excluded(rel, filters):
            sizes[group_of(rel)] = sizes.get(group_of(rel), 0) + (root / rel).stat().st_size
    return sizes, problems


def load_budget(path: Path) -> dict:
    if not path.is_file():
        return {"total_mb": None, "groups_mb": {}}
    return json.loads(path.read_text(encoding="utf-8"))


def over_budget(sizes: dict[str, int], budget: dict) -> list[str]:
    breaches = []
    for group, limit in sorted(budget.get("groups_mb", {}).items()):
        if sizes.get(group, 0) > limit * MIB:
            breaches.append(f"{group}: {sizes[group] / MIB:.1f} MiB > {limit} MiB")
    total = sum(sizes.values())
    limit = budget.get("total_mb")
    if limit is not None and total > limit * MIB:
        breaches.append(f"TOTAL: {total / MIB:.1f} MiB > {limit} MiB")
    return breaches


def render(sizes: dict[str, int], budget: dict, top: int) -> str:
    limits = budget.get("groups_mb", {})
    rows = sorted(sizes.items(), key=lambda item: -item[1])
    lines = [f"{'group':<34}{'MiB':>9}{'budget':>9}  status"]
    for group, size in rows[:top]:
        limit = limits.get(group)
        status = "" if limit is None else ("OVER" if size > limit * MIB else "ok")
        lines.append(f"{group:<34}{size / MIB:>9.1f}{'-' if limit is None else limit:>9}  {status}")
    rest = sum(size for _, size in rows[top:])
    if rest:
        lines.append(f"{f'({len(rows) - top} smaller groups)':<34}{rest / MIB:>9.1f}")
    total_limit = budget.get("total_mb")
    total = sum(sizes.values())
    status = "" if total_limit is None else ("OVER" if total > total_limit * MIB else "ok")
    lines.append(f"{'TOTAL (pck estimate)':<34}{total / MIB:>9.1f}{'-' if total_limit is None else total_limit:>9}  {status}")
    return "\n".join(lines)


def run(root: Path, preset_name: str, budget_path: Path, top: int) -> int:
    preset = preset_named((root / "export_presets.cfg").read_text(encoding="utf-8"), preset_name)
    sizes, problems = measure(root, preset)
    budget = load_budget(budget_path)
    print(f"payload report: preset {preset_name!r}, platform {preset.get('platform')}")
    print(render(sizes, budget, top))
    for problem in problems:
        print(f"  warning: {problem}", file=sys.stderr)
    breaches = over_budget(sizes, budget)
    for breach in breaches:
        print(f"OVER BUDGET  {breach}")
    return 1 if breaches else 0


def self_test() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)

        def put(rel: str, size: int, text: str | None = None) -> None:
            target = root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(text.encode() if text is not None else b"x" * size)

        def texture(rel: str, variants: dict[str, int]) -> None:
            put(rel, 10)
            remap = "".join(f'path.{k}="res://.godot/imported/{rel}.{k}.ctex"\n' for k in variants)
            dests = ", ".join(f'"res://.godot/imported/{rel}.{k}.ctex"' for k in variants)
            put(rel + ".import", 0, f"[remap]\n\nimporter=\"texture\"\n{remap}\n[deps]\n\ndest_files=[{dests}]\n")
            for key, size in variants.items():
                put(f".godot/imported/{rel}.{key}.ctex", size)

        put("export_presets.cfg", 0, (
            '[preset.0]\n\nname="iOS"\nplatform="iOS"\nexclude_filter="tests/*,assets/art/ref/*"\n\n'
            '[preset.0.options]\n\nname="not a preset"\n'))
        texture("assets/art/cards/a.jpg", {"etc2": 1000, "s3tc": 5000})
        texture("assets/art/ref/b.png", {"etc2": 7000})
        put("assets/audio/music/loop.tres", 200)
        put("assets/_attic/old.png", 999_999)
        put("assets/_attic/.gdignore", 0)
        put("tests/t.gd", 400)
        put("content/c.json", 50)
        put("README.md", 5)
        put("addons/lib/include/x.h", 777)

        preset = preset_named((root / "export_presets.cfg").read_text(), "iOS")
        sizes, problems = measure(root, preset)
        expected = {"assets/art/cards": 1000, "assets/audio/music": 200, "content": 50}
        assert sizes == expected, sizes
        assert not problems, problems
        assert over_budget(sizes, {"total_mb": 1, "groups_mb": {"content": 1}}) == []
        tight = {"total_mb": 0.0001, "groups_mb": {"assets/art/cards": 0.0005}}
        assert len(over_budget(sizes, tight)) == 2, over_budget(sizes, tight)
        assert "OVER" in render(sizes, tight, 10)
        # An unimported texture variant is reported rather than ignored.
        (root / ".godot/imported/assets/art/cards/a.jpg.etc2.ctex").unlink()
        assert measure(root, preset)[1], "missing artefact must be reported"
    print("payload_report self-test: PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preset", default=DEFAULT_PRESET)
    parser.add_argument("--budget", default=DEFAULT_BUDGET)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument("--top", type=int, default=25, help="groups to list (default 25)")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    root = Path(args.root)
    budget = Path(args.budget)
    return run(root, args.preset, budget if budget.is_absolute() else root / budget, args.top)


if __name__ == "__main__":
    sys.exit(main())

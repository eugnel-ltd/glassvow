#!/usr/bin/env bash
#
# The iOS export with the shader bake (#682). Both scripts/ios_release.sh and the
# QA export call it in place of `godot --headless --export-release` whenever the
# preset bakes (`shader_baker/enabled=true`). Background, the patched editor and
# when to rebuild it: tools/godot/patches/README.md.
#
# Usage:
#   tools/godot/bake_export.sh --enabled <preset>
#       exit 0 when the preset bakes, 1 when it does not
#   tools/godot/bake_export.sh <preset> <output path> <export log>
#       run from the root of a Glassvow worktree
#
# Environment:
#   GLASSVOW_BAKE_EDITOR  (required) the patched 4.7.3-rc editor binary
#   DEVELOPER_DIR         Xcode (default /Applications/Xcode.app/Contents/Developer);
#                         the baker calls its `metal` tool
#
# Steps: removes the worktree's own stale bake caches (each path printed first),
# writes the bake manifest, exports windowed with the target's `mobile` features
# (the baker needs a rendering device, and its guard refuses a bake whose
# features differ), restores project.godot byte for byte (the editor rewrites it),
# and fails unless baked scene and canvas shaders, and nothing else, were stored
# and the guard was silent.

set -euo pipefail

PIN="4.7.3.rc.custom_build.83dec14d5"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

die() { echo "bake_export: $*" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
PRESETS="$ROOT/export_presets.cfg"

# 0 when the preset named $1 sets shader_baker/enabled=true in its options.
preset_bakes() {
  python3 - "$PRESETS" "$1" <<'PY'
import re
import sys

path, name = sys.argv[1:3]
parts = re.split(r"^(\[[^\]\n]+\])[ \t]*$", open(path, encoding="utf-8").read(), flags=re.M)
ids = [m.group(1) for head, body in zip(parts[1::2], parts[2::2])
       if (m := re.fullmatch(r"\[preset\.(\d+)\]", head))
       and re.search(r'^name="%s"$' % re.escape(name), body, re.M)]
if len(ids) != 1:
    sys.exit("expected one preset named %s, found %d" % (name, len(ids)))
for head, body in zip(parts[1::2], parts[2::2]):
    if head == "[preset.%s.options]" % ids[0]:
        sys.exit(0 if re.search(r"^shader_baker/enabled=true$", body, re.M) else 1)
sys.exit(1)
PY
}

if [[ "${1:-}" == "--enabled" ]]; then
  [[ $# -eq 2 ]] || die "usage: $0 --enabled <preset>"
  preset_bakes "$2"
  exit $?
fi
[[ $# -eq 3 ]] || die "usage: $0 <preset> <output path> <export log>"
PRESET="$1"
OUT="$2"
LOG="$3"

preset_bakes "$PRESET" || die "preset \"$PRESET\" does not bake (shader_baker/enabled=true)"
EDITOR="${GLASSVOW_BAKE_EDITOR:-}"
[[ -n "$EDITOR" && -x "$EDITOR" ]] \
  || die "GLASSVOW_BAKE_EDITOR must name the patched editor (tools/godot/patches/README.md)"
VERSION="$("$EDITOR" --headless --version 2>/dev/null | tail -n 1)"
[[ "$VERSION" == "$PIN" ]] || die "$EDITOR is '$VERSION', not $PIN"
[[ -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]] || die "no Xcode at DEVELOPER_DIR=$DEVELOPER_DIR"

# The baker re-adds every bake its cache still lists: start from none. Only this
# worktree's own export caches, each resolved inside it and printed first.
for dir in "$ROOT"/.godot/exported/*/; do
  [[ -d "$dir/shader_baker" ]] || continue
  real="$(cd "$dir" && pwd -P)"
  [[ "$real" == "$ROOT/.godot/exported/"* ]] || die "refusing $real (outside $ROOT/.godot/exported)"
  echo "bake_export: removing the stale bake cache $real"
  rm -rf -- "$real"
done

KEEP="$(mktemp "${TMPDIR:-/tmp}/bake_export_project.XXXXXX")"
cp "$ROOT/project.godot" "$KEEP"
restore() {
  cp "$KEEP" "$ROOT/project.godot" && rm -f "$KEEP"
}
trap restore EXIT

mkdir -p "$(dirname "$LOG")"
"$EDITOR" --headless --path "$ROOT" -s res://tools/shader_bake_manifest.gd > "$LOG.manifest" 2>&1 \
  || die "the bake manifest failed, see $LOG.manifest"
grep -E "^SHADER_BAKE_MANIFEST .* err=0$" "$LOG.manifest" || die "the bake manifest failed, see $LOG.manifest"

GODOT_EDITOR_CUSTOM_FEATURES=mobile "$EDITOR" --path "$ROOT" --export-release "$PRESET" "$OUT" > "$LOG" 2>&1 \
  || die "the baked export failed, see $LOG"
if grep -F "Shader baker:" "$LOG"; then
  die "the shader baker refused this export (above); nothing was baked"
fi
stored() { grep -c "Storing File: res://.godot/shader_cache/$1" "$LOG" || true; }
ALL="$(stored "")"
SCENE="$(stored SceneForwardMobileShaderRD/)"
CANVAS="$(stored CanvasShaderRD/)"
[[ "$SCENE" -gt 0 && "$CANVAS" -gt 0 ]] \
  || die "the export stored $SCENE baked scene and $CANVAS canvas shader files; see $LOG"
# Only the game's groups: the engine's own shaders stay out of the bake
# (tools/godot/patches/README.md), and an editor from an older patch would add them.
[[ "$ALL" -eq $((SCENE + CANVAS)) ]] \
  || die "the export stored $((ALL - SCENE - CANVAS)) baked engine shader files; rebuild the editor from tools/godot/patches/"
echo "bake_export: $ALL baked shader files stored ($SCENE scene, $CANVAS canvas) by $VERSION"

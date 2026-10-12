#!/usr/bin/env bash
#
# Self-test of tools/godot/bake_export.sh (#682), with a fake editor in a
# scratch repository, so it needs no patched editor and touches no worktree.
# The fake emulates the patched editor's guard: unless the export runs with
# GODOT_EDITOR_CUSTOM_FEATURES=mobile it prints the guard's refusal and bakes
# nothing, as the real baker does (tools/godot/patches/README.md). The guard
# itself is C++ in the editor and out of reach of any repository test.
#
#   tools/godot/test_bake_export.sh     (exit 0 when every case holds)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/test_bake_export.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
FAILS=0
check() {  # what, condition result
  if [[ "$2" == 0 ]]; then echo "ok    $1"; else echo "FAIL  $1"; FAILS=$((FAILS + 1)); fi
}

REPO="$SCRATCH/repo"
# A stand-in Xcode, so the self-test runs without one.
mkdir -p "$SCRATCH/xcode/usr/bin"
printf '#!/bin/sh\nexit 0\n' > "$SCRATCH/xcode/usr/bin/xcodebuild"
chmod +x "$SCRATCH/xcode/usr/bin/xcodebuild"
export DEVELOPER_DIR="$SCRATCH/xcode"
mkdir -p "$REPO/tools/godot" "$REPO/.godot/exported/stale/shader_baker" "$REPO/.godot/exported/kept"
cp "$HERE/bake_export.sh" "$REPO/tools/godot/bake_export.sh"
printf 'config_version=5\n' > "$REPO/project.godot"
cat > "$REPO/export_presets.cfg" <<'CFG'
[preset.0]

name="iOS"
platform="iOS"

[preset.0.options]

shader_baker/enabled=true

[preset.1]

name="Unbaked"
platform="iOS"

[preset.1.options]

application/version="1"
CFG

# The fake editor. FAKE_VERSION and FAKE_STORE shape it; it rewrites
# project.godot as the windowed 4.7.3 editor does.
FAKE="$SCRATCH/editor"
cat > "$FAKE" <<'SH'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    --version) echo "${FAKE_VERSION:-4.7.3.rc.custom_build.83dec14d5}"; exit 0 ;;
    res://tools/shader_bake_manifest.gd) echo "SHADER_BAKE_MANIFEST res://tools/shader_bake_manifest.tscn spatial=2 canvas=1 err=0"; exit 0 ;;
    --export-release)
      echo "rewritten" >> project.godot 2>/dev/null || true
      if [[ "${GODOT_EDITOR_CUSTOM_FEATURES:-}" != "mobile" ]]; then
        echo "ERROR: Shader baker: \"rendering/reflections/sky_reflections/texture_array_reflections\" differs for this export target; set GODOT_EDITOR_CUSTOM_FEATURES to its features. Shaders not baked."
        exit 0
      fi
      if [[ "${FAKE_STORE:-yes}" != no ]]; then
        echo "Storing File: res://.godot/shader_cache/SceneForwardMobileShaderRD/a/b.metal.cache"
        echo "Storing File: res://.godot/shader_cache/CanvasShaderRD/c/d.metal.cache"
      fi
      if [[ "${FAKE_STORE:-yes}" == engine ]]; then
        echo "Storing File: res://.godot/shader_cache/SkyShaderRD/e/f.metal.cache"
      fi
      exit 0 ;;
  esac
done
exit 0
SH
chmod +x "$FAKE"

run() {  # preset, then env assignments; prints the output, returns the status
  (cd "$REPO" && env GLASSVOW_BAKE_EDITOR="$FAKE" "${@:2}" tools/godot/bake_export.sh "$1" out.ipa "$SCRATCH/log/export.log" 2>&1)
}

(cd "$REPO" && tools/godot/bake_export.sh --enabled iOS); check "a preset with shader_baker/enabled=true bakes" $?
(cd "$REPO" && tools/godot/bake_export.sh --enabled Unbaked); [[ $? -eq 1 ]]; check "a preset without it does not" $?

out="$(run iOS)"; status=$?
check "a baked export with the mobile features stores scene and canvas shaders" "$([[ $status -eq 0 && "$out" == *"2 baked shader files stored (1 scene, 1 canvas)"* ]]; echo $?)"
check "it removes the stale bake cache, saying so, and keeps the other caches" "$([[ "$out" == *"removing the stale bake cache"*"/.godot/exported/stale"* && ! -e "$REPO/.godot/exported/stale" && -d "$REPO/.godot/exported/kept" ]]; echo $?)"
check "it puts project.godot back byte for byte" "$([[ "$(cat "$REPO/project.godot")" == "config_version=5" ]]; echo $?)"

# The guard: an editor run without the target's features refuses, and the
# export must fail saying so. Emulated by stripping the variable the script sets.
sed 's/^GODOT_EDITOR_CUSTOM_FEATURES=mobile //' "$HERE/bake_export.sh" > "$REPO/tools/godot/bake_export.sh"
out="$(run iOS)"; status=$?
check "an export the guard refuses fails and shows the refusal" "$([[ $status -ne 0 && "$out" == *"the shader baker refused this export"* ]]; echo $?)"
cp "$HERE/bake_export.sh" "$REPO/tools/godot/bake_export.sh"

out="$(run iOS FAKE_STORE=no)"; status=$?
check "an export that stores no baked scene shader fails" "$([[ $status -ne 0 && "$out" == *"0 baked scene and 0 canvas"* ]]; echo $?)"
out="$(run iOS FAKE_STORE=engine)"; status=$?
check "an export that stores an engine shader (an older patch) fails" "$([[ $status -ne 0 && "$out" == *"1 baked engine shader files"* ]]; echo $?)"
out="$(run iOS FAKE_VERSION=4.7.2.stable.official.ed1daf0bf)"; status=$?
check "an editor other than the pinned one is refused" "$([[ $status -ne 0 && "$out" == *"not 4.7.3.rc.custom_build.83dec14d5"* ]]; echo $?)"
out="$(run Unbaked)"; status=$?
check "a preset that does not bake is refused" "$([[ $status -ne 0 && "$out" == *"does not bake"* ]]; echo $?)"
out="$(cd "$REPO" && env -u GLASSVOW_BAKE_EDITOR tools/godot/bake_export.sh iOS out.ipa "$SCRATCH/log/export.log" 2>&1)"; status=$?
check "no GLASSVOW_BAKE_EDITOR is refused" "$([[ $status -ne 0 && "$out" == *"GLASSVOW_BAKE_EDITOR must name"* ]]; echo $?)"

if [[ $FAILS -eq 0 ]]; then echo "bake_export self-test: PASS"; else echo "bake_export self-test: $FAILS FAILED"; fi
exit $(( FAILS > 0 ))

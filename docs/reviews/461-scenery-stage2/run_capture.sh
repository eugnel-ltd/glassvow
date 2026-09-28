#!/usr/bin/env bash
# Execute the locked #461 five-input/twelve-frame matrix through the unchanged
# Stage 1 GDScript harness, on the project's shipping renderer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUTPUT="$ROOT/docs/reviews/461-scenery-stage2"
EXPECTED_HEAD="ca1057f2bbe25654c5f6add28f59e6b7e0115bc5"
EXPECTED_GODOT="4.7.2.stable"
CAPTURE_COMMAND="docs/reviews/461-scenery-stage2/run_capture.sh"

cd "$ROOT"
ACTUAL_HEAD="$(git rev-parse HEAD)"
[[ "$ACTUAL_HEAD" == "$EXPECTED_HEAD" ]] || {
  printf 'stage2 capture head drifted: %s\n' "$ACTUAL_HEAD" >&2
  exit 2
}
git diff --quiet HEAD -- || {
  printf 'stage2 capture has tracked working-tree drift\n' >&2
  exit 2
}
GODOT_VERSION="$(godot --version | head -n 1 | tr -d '\r')"
[[ "$GODOT_VERSION" == "$EXPECTED_GODOT"* ]] || {
  printf 'expected Godot %s.*, got %s\n' "$EXPECTED_GODOT" "$GODOT_VERSION" >&2
  exit 2
}

ASSET_SHA256="$(shasum -a 256 assets/art/map/map-assets.json | awk '{print $1}')"
TRACKED_DIFF_SHA256="$(git diff HEAD --binary | shasum -a 256 | awk '{print $1}')"
rm -rf "$OUTPUT/raw"
rm -f "$OUTPUT/manifest.json"
mkdir -p "$OUTPUT/logs"

command=(
  godot
  --path "$ROOT"
  --resolution 1180x820
  --position "${GLASSVOW_SHOT_POSITION:--4000,-4000}"
  -s res://tools/capture_461_scenery.gd
  --
  "--output=$OUTPUT"
  "--capture-head=$ACTUAL_HEAD"
  "--asset-manifest-sha256=$ASSET_SHA256"
  "--candidate-diff-sha256=$TRACKED_DIFF_SHA256"
  "--capture-command=$CAPTURE_COMMAND"
)

printf 'capture head: %s\n' "$ACTUAL_HEAD"
printf 'Godot: %s\n' "$GODOT_VERSION"
printf 'command: %s\n' "$CAPTURE_COMMAND"
"${command[@]}" 2>&1 | tee "$OUTPUT/logs/capture.log"

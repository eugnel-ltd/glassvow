#!/usr/bin/env bash
# Render one concept mock to PNG with headless Chrome.
# Usage: render.sh <concept.html> <out.png> <w> <h> [query]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
profile="$(mktemp -d)"
timeout 25 "$chrome" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
  --user-data-dir="$profile" --force-device-scale-factor=1 --virtual-time-budget=4000 \
  --window-size="$3,$4" --screenshot="$2" "file://$here/$1?w=$3&h=$4&${5:-}" >/dev/null 2>&1 || true
rm -rf "$profile"

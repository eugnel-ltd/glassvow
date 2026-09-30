#!/bin/zsh
# Build glassvow.icns from the 1024px macOS master via sips + iconutil (macOS only).
# The master is the picked candidate seated on the macOS grid by
# tools/make_icon_master.py; swapping the icon is a replace of
# assets/icon/glassvow-icon.png followed by this script. iOS has its own
# full-bleed master, assets/icon/glassvow-icon-ios.png, which needs no build.
#   tools/make_icon.sh
set -eu
ROOT="${0:A:h:h}"
MASTER="$ROOT/assets/icon/glassvow-icon.png"
SET="$ROOT/assets/icon/glassvow.iconset"
mkdir -p "$SET"
for side in 16 32 128 256 512; do
	sips -z $side $side "$MASTER" --out "$SET/icon_${side}x${side}.png" >/dev/null
	double=$((side * 2))
	sips -z $double $double "$MASTER" --out "$SET/icon_${side}x${side}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o "$ROOT/assets/icon/glassvow.icns"
rm -r "$SET"
print "wrote assets/icon/glassvow.icns"

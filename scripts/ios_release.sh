#!/usr/bin/env bash
#
# One-script iOS release: export, archive, sign, install on the iPad, upload to
# TestFlight, upload dSYMs to Sentry, wait for processing, attach the build to
# the beta group. Proven end to end on 2026-10-01 (TestFlight 1.0.0 build 11).
# Background, preconditions and the manual recipe: docs/release-signing.md.
#
# Usage:
#   scripts/ios_release.sh <build-number> <expected-head-sha> [--no-upload] [--no-device]
#
#   --no-upload  stop after the signed App Store .ipa (no asc upload, Sentry
#                dSYMs, processing wait or group attach)
#   --no-device  skip the development export and the iPad install
#
# Credentials are read from the environment and never stored in the repository:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH   (App Store Connect team key)
# Optional overrides:
#   ASC_APP_ID, ASC_BETA_GROUP_ID, DEVELOPER_DIR, SENTRY_ORG, SENTRY_PROJECT,
#   PROCESSING_POLL_LIMIT, PROCESSING_POLL_SECONDS
# Required unless --no-device (the repository is public, so no default is committed):
#   IOS_DEVICE_UDID                                   (the iPad's UDID; from
#                                                      `xcrun devicectl list devices`)
# Sentry dSYM upload also needs SENTRY_AUTH_TOKEN (or a sentry-cli login).
#
# Logs: build/ios/logs/<step><build-number>.log (kept between runs).

set -euo pipefail

# Not secrets: the App Store Connect app and its internal beta group.
ASC_APP_ID="${ASC_APP_ID:-6803851427}"
ASC_BETA_GROUP_ID="${ASC_BETA_GROUP_ID:-ac0496a3-70a9-4385-9eff-d3db7f9eac0d}"
IOS_DEVICE_UDID="${IOS_DEVICE_UDID:-}"
SENTRY_ORG="${SENTRY_ORG:-pgnetwork}"
SENTRY_PROJECT="${SENTRY_PROJECT:-glassvow}"
PROCESSING_POLL_LIMIT="${PROCESSING_POLL_LIMIT:-60}"
PROCESSING_POLL_SECONDS="${PROCESSING_POLL_SECONDS:-45}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# Matches "Godot Engine v4.7.3.rc.custom_build"; grep -a reads the binary
# directly, so there is no pipe to raise SIGPIPE under pipefail.
ENGINE_PATTERN='Godot Engine v[0-9][A-Za-z0-9._-]*'
TEMPLATE_ZIP="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/ios.zip"

die() { echo "ios_release: $*" >&2; exit 1; }
step() { echo "== $* $(date)"; }

# Checked first: with a bad path even the system git shim fails with an opaque xcrun error.
[[ -d "$DEVELOPER_DIR" ]] || die "DEVELOPER_DIR does not exist: $DEVELOPER_DIR"

usage() {
  sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
  exit 64
}

# ---- arguments ---------------------------------------------------------------

DO_UPLOAD=1
DO_DEVICE=1
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --no-upload) DO_UPLOAD=0 ;;
    --no-device) DO_DEVICE=0 ;;
    -h|--help) usage ;;
    -*) die "unknown option $arg" ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
[[ ${#POSITIONAL[@]} -eq 2 ]] || usage
BUILD="${POSITIONAL[0]}"
EXPECTED_SHA="${POSITIONAL[1]}"
[[ "$BUILD" =~ ^[0-9]+$ ]] || die "build number must be an integer, got '$BUILD'"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ---- pre-flight: refuse before spending twenty minutes -------------------------

HEAD_SHA="$(git rev-parse HEAD)"
EXPECTED_FULL="$(git rev-parse --verify --quiet "${EXPECTED_SHA}^{commit}" || true)"
[[ -n "$EXPECTED_FULL" && "$HEAD_SHA" == "$EXPECTED_FULL" ]] \
  || die "HEAD is $HEAD_SHA, not $EXPECTED_SHA"

# .wrangler/ is the machine-local Cloudflare cache, the only tolerated litter.
DIRTY="$(git status --porcelain | grep -v '^?? \.wrangler/' || true)"
[[ -z "$DIRTY" ]] || die "dirty tree:"$'\n'"$DIRTY"

# The pin must sit inside the store "iOS" preset, not the Dev Review one.
PRESET_PIN="$(awk -v want="application/version=\"$BUILD\"" '
  /^\[preset\.[0-9]+\]$/ { in_ios = 0 }
  $0 == "name=\"iOS\"" { in_ios = 1 }
  in_ios && $0 == want { found = 1 }
  END { print found ? "yes" : "no" }' export_presets.cfg)"
[[ "$PRESET_PIN" == yes ]] || die "export_presets.cfg \"iOS\" preset pin is not $BUILD"

if [[ $DO_UPLOAD -eq 1 ]]; then
  for name in ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY_PATH; do
    [[ -n "${!name:-}" ]] \
      || die "$name is not set (App Store Connect key; see docs/release-signing.md, One-script release)"
  done
  [[ -f "$ASC_PRIVATE_KEY_PATH" ]] || die "ASC_PRIVATE_KEY_PATH does not point at a file: $ASC_PRIVATE_KEY_PATH"
  command -v asc >/dev/null 2>&1 || die "asc is not on PATH"
  command -v sentry-cli >/dev/null 2>&1 || die "sentry-cli is not on PATH"
  # Fail now, not after the TestFlight upload: this makes an authenticated request.
  sentry-cli info --no-defaults --quiet >/dev/null 2>&1 \
    || die "sentry-cli is not authenticated (source ~/.config/glassvow/sentry.sh or set SENTRY_AUTH_TOKEN)"
  python3 -c 'import jwt, cryptography' 2>/dev/null \
    || die "python3 needs PyJWT and cryptography: pip install pyjwt cryptography"
else
  # xcodebuild -exportArchive still signs with the team key, so the key stays mandatory.
  for name in ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY_PATH; do
    [[ -n "${!name:-}" ]] || die "$name is not set (App Store Connect key; needed to sign the export)"
  done
  [[ -f "$ASC_PRIVATE_KEY_PATH" ]] || die "ASC_PRIVATE_KEY_PATH does not point at a file: $ASC_PRIVATE_KEY_PATH"
fi
command -v godot >/dev/null 2>&1 || die "godot is not on PATH"

if [[ $DO_DEVICE -eq 1 ]]; then
  [[ -n "$IOS_DEVICE_UDID" ]] \
    || die "IOS_DEVICE_UDID is not set (see xcrun devicectl list devices), or pass --no-device"
  # Captured, not piped: grep -q closing early would SIGPIPE devicectl under pipefail.
  DEVICES="$(xcrun devicectl list devices 2>/dev/null || true)"
  grep -qF "$IOS_DEVICE_UDID" <<<"$DEVICES" \
    || die "device $IOS_DEVICE_UDID is not known to devicectl (pair and unlock it, or pass --no-device)"
fi

# The patched template carries a note; print it so the log shows which engine slice shipped.
unzip -p "$TEMPLATE_ZIP" GLASSVOW-TEMPLATE-NOTE.txt 2>/dev/null \
  || echo "ios_release: warning: no GLASSVOW-TEMPLATE-NOTE.txt in the iOS template (official zip?)" >&2

# ---- build -------------------------------------------------------------------

LOGS="build/ios/logs"
mkdir -p "$LOGS"
trap 'echo "ios_release: step failed near line $LINENO; logs in $REPO_ROOT/$LOGS" >&2' ERR
# Clean everything except the logs, which outlive a run.
find build/ios -mindepth 1 -maxdepth 1 ! -name logs -exec rm -rf {} +

engine_version() { grep -a -o -m1 "$ENGINE_PATTERN" "$1" 2>/dev/null || true; }

step "export build $BUILD"
godot --headless --export-release "iOS" build/ios/glassvow.ipa > "$LOGS/export$BUILD.log" 2>&1
engine_version "build/ios/glassvow.xcframework/ios-arm64/libgodot.a"

step "archive"
xcodebuild -project build/ios/glassvow.xcodeproj -scheme glassvow \
  -destination "generic/platform=iOS" archive -archivePath build/ios/glassvow.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > "$LOGS/archive$BUILD.log" 2>&1
grep -q "ARCHIVE SUCCEEDED" "$LOGS/archive$BUILD.log" || die "archive failed, see $LOGS/archive$BUILD.log"
ENGINE_VERSION="$(engine_version build/ios/glassvow.xcarchive/Products/Applications/glassvow.app/glassvow)"
[[ -n "$ENGINE_VERSION" ]] || echo "ios_release: warning: no engine version string in the archive binary" >&2

step "app-store export"
xcodebuild -exportArchive -archivePath build/ios/glassvow.xcarchive \
  -exportPath build/ios/export -exportOptionsPlist scripts/ios_export_options.plist \
  -allowProvisioningUpdates -authenticationKeyPath "$ASC_PRIVATE_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  > "$LOGS/export-ipa$BUILD.log" 2>&1
grep -q "EXPORT SUCCEEDED" "$LOGS/export-ipa$BUILD.log" || die "export failed, see $LOGS/export-ipa$BUILD.log"
IPA_SHA256="$(shasum -a 256 build/ios/export/glassvow.ipa)"
echo "$IPA_SHA256" | tee "$LOGS/ipa$BUILD.sha256"

# ---- iPad --------------------------------------------------------------------

CLEAN=1
DEVICE_STATUS="skipped"
if [[ $DO_DEVICE -eq 1 ]]; then
  step "development export"
  xcodebuild -exportArchive -archivePath build/ios/glassvow.xcarchive \
    -exportPath build/ios/export-dev \
    -exportOptionsPlist scripts/ios_export_options_development.plist \
    > "$LOGS/export-dev$BUILD.log" 2>&1
  grep -q "EXPORT SUCCEEDED" "$LOGS/export-dev$BUILD.log" || die "development export failed, see $LOGS/export-dev$BUILD.log"
  step "install on $IOS_DEVICE_UDID"
  if xcrun devicectl device install app --device "$IOS_DEVICE_UDID" \
      build/ios/export-dev/glassvow.ipa > "$LOGS/install$BUILD.log" 2>&1; then
    DEVICE_STATUS="installed"
  else
    DEVICE_STATUS="FAILED (see $LOGS/install$BUILD.log)"
    CLEAN=0
  fi
  echo "iPad install: $DEVICE_STATUS"
fi

# ---- TestFlight --------------------------------------------------------------

BUILD_ID="n/a"
ATTACH_STATUS="skipped (--no-upload)"
if [[ $DO_UPLOAD -eq 1 ]]; then
  step "upload"
  asc builds upload --app "$ASC_APP_ID" --ipa build/ios/export/glassvow.ipa > "$LOGS/upload$BUILD.log" 2>&1
  tail -n 2 "$LOGS/upload$BUILD.log"

  step "dSYMs to Sentry"
  sentry-cli debug-files upload --org "$SENTRY_ORG" --project "$SENTRY_PROJECT" \
    build/ios/glassvow.xcarchive/dSYMs > "$LOGS/dsym$BUILD.log" 2>&1
  tail -n 1 "$LOGS/dsym$BUILD.log"

  step "wait for processing"
  BUILD_ID=""
  UUID_PATTERN='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
  for ((i = 1; i <= PROCESSING_POLL_LIMIT; i++)); do
    LISTING="$(asc builds list --app "$ASC_APP_ID" --build-number "$BUILD" 2>/dev/null || true)"
    # -w: INVALID must not satisfy the VALID match.
    if grep -qw INVALID <<<"$LISTING"; then
      BUILD_ID="INVALID"
      break
    fi
    VALID_LINE="$(grep -w -m1 VALID <<<"$LISTING" || true)"
    if [[ -n "$VALID_LINE" ]]; then
      echo "$VALID_LINE"
      BUILD_ID="$(grep -o -E -m1 "$UUID_PATTERN" <<<"$VALID_LINE" || true)"
      break
    fi
    sleep "$PROCESSING_POLL_SECONDS"
  done

  if [[ "$BUILD_ID" == INVALID ]]; then
    BUILD_ID="invalid"
    ATTACH_STATUS="NOT ATTEMPTED (App Store Connect marked build $BUILD INVALID; see the upload log and your email)"
    CLEAN=0
  elif [[ -z "$BUILD_ID" ]]; then
    BUILD_ID="not found"
    ATTACH_STATUS="NOT ATTEMPTED (build not VALID after $PROCESSING_POLL_LIMIT polls)"
    CLEAN=0
  else
    step "attach to beta group"
    if ATTACH_STATUS="$(python3 scripts/asc_attach_build.py "$BUILD_ID" "$ASC_BETA_GROUP_ID" 2>&1)"; then
      :
    else
      CLEAN=0
    fi
  fi
fi

# ---- summary -----------------------------------------------------------------

step "summary"
echo "build:           $BUILD ($HEAD_SHA)"
echo "ipa sha256:      ${IPA_SHA256%% *}"
echo "engine version:  ${ENGINE_VERSION:-not found}"
echo "iPad install:    $DEVICE_STATUS"
echo "build id:        $BUILD_ID"
echo "group attach:    $ATTACH_STATUS"
echo "logs:            $REPO_ROOT/$LOGS"
[[ $CLEAN -eq 1 ]] || exit 2

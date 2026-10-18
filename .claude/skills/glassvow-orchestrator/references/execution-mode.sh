#!/usr/bin/env sh
# Explicit, provider-independent selection; an unknown host never means local.
set -eu
case "${GLASSVOW_EXECUTION_MODE:-}" in
    cloud|local) printf '%s\n' "$GLASSVOW_EXECUTION_MODE" ;;
    *) echo 'Set GLASSVOW_EXECUTION_MODE=cloud or local from the session environment contract.' >&2; exit 2 ;;
esac

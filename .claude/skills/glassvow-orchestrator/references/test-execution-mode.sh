#!/usr/bin/env sh
# The execution mode must come from an explicit session setting, never a guess.
set -eu
script="$(dirname "$0")/execution-mode.sh"
for mode in cloud local; do
    actual=$(GLASSVOW_EXECUTION_MODE="$mode" sh "$script") || { echo "explicit $mode mode could not be resolved" >&2; exit 1; }
    [ "$actual" = "$mode" ] || { echo "explicit $mode mode was not preserved" >&2; exit 1; }
done
if env -u GLASSVOW_EXECUTION_MODE sh "$script" >/dev/null 2>&1; then
    echo 'an unset mode must fail instead of guessing from the host' >&2
    exit 1
fi
for mode in '' claude CLOUD seat engine; do
    if GLASSVOW_EXECUTION_MODE="$mode" sh "$script" >/dev/null 2>&1; then
        echo 'an unsupported mode must fail instead of selecting local rules' >&2
        exit 1
    fi
done
echo 'execution mode contract OK'

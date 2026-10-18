#!/bin/sh
# Bound only the child Godot process; failed writes reach FileAccess as errors.
trap '' XFSZ
ulimit -f 8 || exit 2
exec "$@"

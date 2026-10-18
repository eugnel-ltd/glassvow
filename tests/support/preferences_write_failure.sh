#!/bin/sh
# Simulate exhausted storage only in the child. Existing files remain readable.
trap '' XFSZ
ulimit -f 0 || exit 2
exec "$@"

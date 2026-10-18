#!/bin/sh
# Repo-local route named by .claude/hooks/guard-edits.sh. Records supplied owner
# decisions only; it never creates a document, invents a decision, or rewrites one.
# Based on eugnel-ltd/ai-sdlc scripts/record_decision.sh at 8540f543e2795407fef9d542df51c77778c53eb5.
# Usage: record_decision.sh title decision why scope [file]
# The existing document must contain ## Decisions; why quotes the owner or starts
# with Paraphrased:. Each single-line entry is inserted newest first.
set -eu
case $# in
  4|5) ;;
  *) echo 'usage: record_decision.sh title decision why scope [file]' >&2; exit 1 ;;
esac
title=$1
decision=$2
why=$3
scope=$4
file=${5:-docs/owner-decisions.md}
[ -f "$file" ] || { echo "record_decision: $file not found" >&2; exit 1; }
for value in "$title" "$decision" "$why" "$scope"; do
  case "$value" in *"
"*) echo 'record_decision: arguments must be single lines' >&2; exit 1 ;; esac
  [ -n "$value" ] || { echo 'record_decision: empty argument' >&2; exit 1; }
done
case "$why" in
  *\"*|*“*|Paraphrased:*) ;;
  *) echo 'record_decision: Why must quote the owner or begin with Paraphrased:' >&2; exit 1 ;;
esac
[ "$(grep -c '^## Decisions$' "$file")" = 1 ] || {
  echo "record_decision: $file must have exactly one '## Decisions' heading" >&2
  exit 1
}
# awk would add a missing final newline and therefore rewrite existing content.
last_byte=$(tail -c 1 "$file" | od -An -tu1 | tr -d '[:space:]')
[ "$last_byte" = 10 ] || {
  echo "record_decision: $file must end with a newline" >&2
  exit 1
}
decision_date=$(date -u +%F)
tmp=$(mktemp "${file}.tmp.XXXXXX")
trap 'rm -f "$tmp"' 0 1 2 15
# Environment values preserve literal backslashes, unlike awk -v assignments.
D="$decision_date" T="$title" DEC="$decision" WHY="$why" SC="$scope" awk '
  { print }
  /^## Decisions$/ && !inserted {
    print ""
    print "## " ENVIRON["D"] ": " ENVIRON["T"]
    print "- Decision: " ENVIRON["DEC"]
    print "- Why: " ENVIRON["WHY"]
    print "- Scope: " ENVIRON["SC"]
    inserted = 1
  }' "$file" > "$tmp"
mv "$tmp" "$file"
echo "recorded: ## $decision_date: $title"

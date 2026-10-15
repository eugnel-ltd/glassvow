#!/bin/zsh
# Orchestrator housekeeping (owner-authorised 14 Oct 2026): prune Glassvow's own
# orphaned Xcode DerivedData, prune stale git worktree records, print free disk.
# The orchestrator runs this after every lane cleanup or merge. Lanes never run it.
set -u

# Engine only: on the seat, the repo is an SMB mount and git must not run over it.
if [[ -n "${GLASSVOW_ENGINE_HOST_NAME:-}" && "$(scutil --get LocalHostName 2>/dev/null)" != "$GLASSVOW_ENGINE_HOST_NAME" ]]; then
  print "housekeeping runs on the engine; use: mbp zsh $0"; exit 1
fi

# The main checkout, found from git rather than hard-coded, so this works from
# any worktree on any machine.
common_dir=$(git -C "${0:A:h}" rev-parse --path-format=absolute --git-common-dir) || exit 1
repo=${common_dir:h}
[[ -d "$repo/.git" ]] || { print "not a main checkout: $repo"; exit 1; }

[[ -n "${HOME:-}" && "$HOME" == /* && "$HOME" != / ]] || { print "HOME is unusable"; exit 1; }
dd="$HOME/Library/Developer/Xcode/DerivedData"

orch="$repo/.claude/worktrees/orch"
mkdir -p "$orch"
list="$orch/deriveddata-stale.txt"
: > "$list"

# A folder is orphaned when the workspace it was built from no longer exists.
for d in "$dd"/glassvow-*(N/); do
  wp=$(/usr/libexec/PlistBuddy -c "Print :WorkspacePath" "$d/info.plist" 2>/dev/null)
  [[ -n "$wp" && ! -e "$wp" ]] && print -r -- "$d" >> "$list"
done

n=0
while IFS= read -r d; do
  # Strict check: a direct child of DerivedData named glassvow-<something>,
  # with no path traversal. Anything else is reported and left alone.
  case "$d" in
    */../*|*/./*) print -r -- "SKIP $d";;
    "$dd"/glassvow-?*)
      if [[ "${d:h}" == "$dd" ]]; then
        rm -rf -- "$d"; n=$((n+1))
      else
        print -r -- "SKIP $d"
      fi;;
    *) print -r -- "SKIP $d";;
  esac
done < "$list"
print "pruned $n orphaned DerivedData folder(s)"

# Metadata only: drops records of worktrees whose directory has been gone a day,
# so a lane's folder caught mid-move is never pruned.
git -C "$repo" worktree prune --expire=1.day
df -h / | tail -1 | awk '{print $4" free"}'

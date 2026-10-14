#!/bin/zsh
# Run a shell command on the engine host (the MacBook Pro) from the seat (the
# Mac mini), in the same absolute directory. Output streams; the remote exit
# code is kept (255 means ssh itself failed).
#
#   mbp <cmd> [args...]     each argument is quoted, then run in $PWD on the engine
#   mbp -c '<shell line>'   the line runs as written (pipes, globs, &&), in $PWD
#   mbp --where             prints "seat" or "engine" for this machine
#   mbp --check             proves the engine is reachable and the SMB mount is live
#
# Install on the seat: symlink this file to a directory on PATH as `mbp`.
# The engine is an ssh config alias, default `mbp`; override with
# GLASSVOW_ENGINE_HOST. Host names and keys live in ~/.ssh/config, never here.
set -u

host=${GLASSVOW_ENGINE_HOST:-mbp}
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=15)

remote() { ssh "${ssh_opts[@]}" "$host" "$1"; }

case "${1:-}" in
  "")
    print -u2 "usage: mbp <cmd> [args...] | mbp -c '<shell line>' | mbp --where | mbp --check"
    exit 2;;
  --where)
    here=$(scutil --get LocalHostName 2>/dev/null)
    there=$(remote 'scutil --get LocalHostName') || { print -u2 "mbp: engine unreachable"; exit 255; }
    [[ "$here" == "$there" ]] && print engine || print seat
    exit 0;;
  --check)
    repo=${GLASSVOW_REPO:-$PWD}
    [[ -f "$repo/AGENTS.md" ]] || { print -u2 "mbp: $repo/AGENTS.md not visible here; is the SMB mount live?"; exit 1; }
    local_sum=$(shasum -a 256 "$repo/AGENTS.md" | cut -d' ' -f1)
    remote_sum=$(remote "shasum -a 256 ${(q)repo}/AGENTS.md | cut -d' ' -f1") || { print -u2 "mbp: engine unreachable or repo missing there"; exit 255; }
    if [[ "$local_sum" == "$remote_sum" ]]; then
      # The same contents could be a second local clone: the seat's copy must be the mount.
      mp=$(df -P "${repo:A}" 2>/dev/null | awk 'NR==2 {print $NF}')
      mount | grep -F " on $mp (" | grep -q smbfs \
        || { print -u2 "mbp: $repo is not on the SMB mount here; a local clone would be a second tree"; exit 1; }
      remote 'for t in godot gh rg python3 tmux; do command -v $t >/dev/null || echo "missing on engine PATH: $t"; done' \
        | grep . >&2 && { print -u2 "mbp: export the engine PATH in its ~/.zshenv (see machine-setup.md 9.3)"; exit 1; }
      print "mbp: engine reachable; $repo is the same tree on both machines; tools on PATH"
      exit 0
    fi
    print -u2 "mbp: $repo differs between seat and engine; remount the share"
    exit 1;;
  -c)
    shift
    (( $# == 1 )) || { print -u2 "mbp -c takes exactly one shell line"; exit 2; }
    line=$1;;
  *)
    line=${(j: :)"${(@q)@}"};;
esac

exec ssh "${ssh_opts[@]}" "$host" "cd ${(q)PWD} && $line"

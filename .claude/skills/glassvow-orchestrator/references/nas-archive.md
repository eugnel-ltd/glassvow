# Archiving a lane folder to the NAS

The NAS is a Synology reached only by ssh, through the host alias `ds1819-clawdbot` in `~/.ssh/config` on the engine host. It is not an SMB mount, so an empty `/Volumes` says nothing about it. Before saying the NAS is unavailable, try:

```bash
timeout 20 ssh -o BatchMode=yes ds1819-clawdbot hostname
```

A post-quantum key-exchange warning on stderr is harmless. On the seat, run every command here through `mbp`.

## Layout

```
~/Archives/glassvow-scratch-YYYY-MM-DD/
    <lane>.tar                         one tar per lane folder
    <lane>.tar.sha256                  optional: the remote sha256 line
    MANIFEST-YYYY-MM-DD.txt            what went in, sizes, hashes
    orch-YYYY-MM-DD.tar                the orchestrator folder (briefs, run plan)
    claude-memory-YYYY-MM-DD.tar       Claude's per-machine memory, top-level folder memory/
    glassvow-all-branches-YYYY-MM-DD.bundle   every local branch (git bundle)
```

`~` on the NAS is the user's Synology home. `scp` cannot see these paths; stream with `ssh ... cat` instead.

## Recipe: stream, hash both ends, then delete

Run from the orchestrator folder's parent, with literal names. Nothing touches local disk except the hash file.

```bash
D=glassvow-scratch-$(date +%Y-%m-%d)
L=<lane>                                    # literal folder name under .claude/worktrees/
cd <repo>/.claude/worktrees

ssh -o BatchMode=yes ds1819-clawdbot "mkdir -p ~/Archives/$D"

tar -cf - "$L" \
  | tee >(shasum -a 256 | cut -d' ' -f1 > "orch/$L.local.sha") \
  | ssh -o BatchMode=yes ds1819-clawdbot "cat > ~/Archives/$D/$L.tar && sha256sum ~/Archives/$D/$L.tar" \
  | tee "orch/$L.remote.sha"

sleep 1   # let the process substitution finish writing
cat "orch/$L.local.sha"; cut -d' ' -f1 "orch/$L.remote.sha"
```

Then, as separate steps:

1. **Compare.** The two hashes must be identical. If not, delete nothing and re-run.
2. **Optional entry check.** `tar -tf` locally against `ssh ... 'tar -tf ~/Archives/$D/$L.tar | wc -l'`. macOS tar may add AppleDouble `._` entries; count them separately rather than calling it a mismatch.
3. **Record.** Append the name, byte size and sha256 to `MANIFEST-<date>.txt` on the NAS and to the run log.
4. **Remove the worktree** first if the folder holds one: `git worktree remove <literal path>` (add `--force` only after archiving any untracked work you mean to keep).
5. **Delete** the lane folder by literal absolute path: `ls -d <path>` first, then `rm -rf <path>` as a separate command. Never a variable you have not just printed.
6. **Housekeeping**: run `references/housekeeping.sh`.

## Restoring

```bash
ssh -o BatchMode=yes ds1819-clawdbot 'sha256sum ~/Archives/<D>/<name>.tar'
ssh -o BatchMode=yes ds1819-clawdbot 'cat ~/Archives/<D>/<name>.tar' | tar -xf - -C <target dir>
```

Compare the NAS sha256 with the `.local.sha` recorded at archive time, which is inside the archived orchestrator folder. A branch bundle restores with `git fetch <file>.bundle 'refs/heads/*:refs/remotes/bundle/*'`.

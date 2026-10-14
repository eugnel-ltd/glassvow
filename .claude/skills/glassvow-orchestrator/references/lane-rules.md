# Hard rules for every product lane

Generalised from the orchestrator's `product-lane-rules.md` of 14 Oct 2026. Before linking it from a brief, copy it into the orchestrator folder and fill in `<repo>` and the session trailer for the current session. Every brief says "read the lane rules first; they bind."

- **Lean.** The owner asked for fewer tokens and less time. Read only the sections you need; one background wait per long job, no polling; short notes. Evidence is proportional to the decision. Before setting or chasing any frame or VRAM bar, ask "can the player see or feel this?". Keep three-plus-three device reads for release-level claims; a lane's iPad read is one interleaved batch unless the first is ambiguous.
- **Contract.** `<repo>/CLAUDE.md` and `.claude/skills/glassvow-godot/SKILL.md` bind. One branch, one ordinary PR; the core local gate once on the final candidate before the first push (stage new `.gd` files first), plus `python3 -B tools/check_anchors.py` whenever a code file moved lines (docs cite file:line and CI fails on drift; re-anchor only after reading the prose each anchor names). Visual changes need stills you have looked at, at the three shapes. Do not merge: report the PR and its head to the orchestrator, who commissions review and merges.
- **Worktree.** Your own git worktree under `<repo>/.claude/worktrees/<lane>/` (not `/tmp`). Each worktree gets an untracked, never-committed `override.cfg`:
  ```
  [application]
  config/use_custom_user_dir=true
  config/custom_user_dir_name="glassvow-<lane>"
  ```
  Run `godot --headless --import` in a fresh worktree first. Never touch `~/Library/Application Support/Godot/app_userdata/`. A run of an exported pck or a second engine binary reads `override.cfg` beside the pck or the binary, so put the same block there too, and check the real profile's mtimes after the first run.
- **Seat and engine.** All shell commands run on the engine host via `mbp ...` (`.claude/skills/glassvow-orchestrator/references/mbp.sh`). File reads and edits go through the mounted path. Never run git, Godot or the test suite on the seat machine. Check first with `mbp --where` (it compares `scutil --get LocalHostName` here with the engine's): "seat" means prefix every command with `mbp`; "engine" means run commands directly. Run `mbp --check` once before work to prove the mount is live.
- **Shared Mac (ks2's CI runs on it).** Wait while load is over 50 before a full test run or batch; one Godot run at a time in your lane; never kill a process you did not start. After any killed Godot run, check `git status -- project.godot` and `wc -l project.godot`. Balance batches at `--jobs 4` or fewer. Keep at least 100 GB free on disk; stop and tell the orchestrator if it falls below.
- **Deletes.** Only inside your worktree and lane folder, by literal absolute path, check then delete as separate commands. Never derive a path from `OS.get_cache_dir()`, `OS.get_user_data_dir()`, `OS.get_data_dir()`, `$HOME`, `~/Library` or any system path. A fresh install on the iPad means a build the device has never compiled, never clearing caches.
- **iPad.** QA app only (`io.fol2.glassvow.qa`, via `qa_export.sh`); never the production bundle, never uninstall from the owner's iPad, never touch real saves. Hold the shared lock (`<repo>/.claude/worktrees/device13-flow/ipad_lock.sh acquire|release <owner>`) for a device batch and never break another holder's live lock. Device UDID from the environment only, never echoed or committed. Wrap `devicectl` copies in `timeout 300`. No installs on the owner's iPhone without asking.
- **Content.** No player-facing copy except through the story skill; nothing new into `assets/` art without the owner's pick, unless it is a recorded lane pick with the owner's re-pick left open; no new music. `domain/` stays pure; no save-schema or internal-ID change (stop and report if one is needed). The stop conditions in `CLAUDE.md` apply (more than 600 changed lines in one code file in one commit, and the rest).
- **Git.** Stage by name, never `git add -A`; never `git reset` a shared index. UK English. Commits end with:
  ```
  Co-Authored-By: <model attribution for this session>
  Claude-Session: <session URL for this session>
  ```
  PR bodies end with:
  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  <session URL for this session>
  ```
  Pushes: use `gh auth git-credential` as the helper if the keychain errors (-25308). Lanes do not post on issues; the orchestrator does.
- **Secrets.** Never print, commit or paste any token, key, key id, issuer id, DSN, password, account id or device id. Read them into a variable inside the command that needs them.
- **Report** to the orchestrator: PR number and exact head SHA, what changed, the gate results, the stills or device figures, open risks; then a short Hong Kong Cantonese paragraph. Then stop.

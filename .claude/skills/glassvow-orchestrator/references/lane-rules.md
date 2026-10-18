# Hard rules for every product lane

Generalised from the orchestrator's `product-lane-rules.md` of 14 Oct 2026. Before linking it from a brief, fill in `<repo>` and the session trailer for the current session. Every brief says "read the lane rules first; they bind."

- **Execution mode.** Read `docs/agents/cloud-environment.md` and run its explicit mode check first. Cloud commands run directly in the assigned checkout. Seat/engine, shared-Mac, NAS and iPad clauses apply only to local mode. At a local-only step, report the exact handoff to the orchestrator for a `needs-local-machine` issue and continue independent work; never claim the step passed.

- **Lean.** The owner asked for fewer tokens and less time. Read only the sections you need; one background wait per long job, no polling; short notes. Evidence is proportional to the decision. Before setting or chasing any frame or VRAM bar, ask "can the player see or feel this?". Keep three-plus-three device reads for release-level claims; a lane's iPad read is one interleaved batch unless the first is ambiguous.
- **Contract.** `<repo>/CLAUDE.md` and the relevant domain skill bind. One branch, one ordinary PR; scope-selected gates follow `tools/ci_scope.py`. Production Godot delivery runs the core local gate once on the final candidate before the first push (stage new `.gd` files first); docs-only work uses its matching checks. Run `python3 -B tools/check_anchors.py` whenever a code file moved lines (docs cite file:line and CI fails on drift; re-anchor only after reading the prose each anchor names). Visual changes need stills you have looked at, at the three shapes. Do not merge: report the PR and its head to the orchestrator, who commissions review and merges.
- **Worktree.** One branch and isolated checkout per lane. Local mode uses `<repo>/.claude/worktrees/<lane>/` (not `/tmp`); cloud mode uses its assigned checkout or a separate worktree, without a fixed parent directory. Every mode needs an untracked, never-committed `override.cfg`:
  ```
  [application]
  config/use_custom_user_dir=true
  config/custom_user_dir_name="glassvow-<lane>"
  ```
  Run `godot --headless --import` in a fresh checkout first. In either mode run one Godot process at a time per lane and never kill a process you did not start. Never touch `~/Library/Application Support/Godot/app_userdata/`. A run of an exported pck or a second engine binary reads `override.cfg` beside the pck or the binary, so put the same block there too, and check the real profile's mtimes after the first run.
- **Seat and engine (local mode only).** All shell commands run on the engine host via `mbp ...` (`.claude/skills/glassvow-orchestrator/references/mbp.sh`). File reads and edits go through the mounted path. Never run git, Godot or the test suite on the seat machine. Check first with `mbp --where` (it compares `scutil --get LocalHostName` here with the engine's): "seat" means prefix every command with `mbp`; "engine" means run commands directly. On the seat, run `mbp --check` once before work to prove the mount is live.
- **Shared Mac (local mode only; ks2's CI runs on it).** Wait while load is over 50 before a full test run or batch; one Godot run at a time in your lane; never kill a process you did not start. After any killed Godot run, check `git status -- project.godot` and `wc -l project.godot`. Balance batches at `--jobs 4` or fewer. Keep at least 100 GB free on disk; stop and tell the orchestrator if it falls below.
- **Deletes.** Only inside your worktree and lane folder, by literal absolute path, check then delete as separate commands. Never derive a path from `OS.get_cache_dir()`, `OS.get_user_data_dir()`, `OS.get_data_dir()`, `$HOME`, `~/Library` or any system path. A fresh install on the iPad means a build the device has never compiled, never clearing caches.
- **iPad (local mode only).** QA app only (`io.fol2.glassvow.qa`, via `qa_export.sh`); never the production bundle, never uninstall from the owner's iPad, never touch real saves. Hold the shared lock (`<repo>/.claude/worktrees/device13-flow/ipad_lock.sh acquire|release <owner>`) for a device batch and never break another holder's live lock. Device UDID from the environment only, never echoed or committed. Wrap `devicectl` copies in `timeout 300`. No installs on the owner's iPhone without asking.
- **Content.** No player-facing copy except through the story skill; nothing new into `assets/` art without the owner's pick, unless it is a recorded lane pick with the owner's re-pick left open; no new music. `domain/` stays pure; no save-schema or internal-ID change (stop and report if one is needed). The stop conditions in `CLAUDE.md` apply (more than 600 changed lines in one code file in one commit, and the rest).
- **Git.** Stage by name, never `git add -A`; never `git reset` a shared index. UK English. Use truthful attribution for the active tool and model. For a Claude Code session with a real session URL, commits end with:
  ```
  Co-Authored-By: <model attribution for this session>
  Claude-Session: <session URL for this session>
  ```
  Claude Code PR bodies end with:
  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  <session URL for this session>
  ```
  Other tools name their actual authoring agent; never invent a Claude session URL or claim Claude Code generated their work.
  Pushes: use `gh auth git-credential` as the helper if the keychain errors (-25308). Lanes do not post on issues; the orchestrator does.
- **Secrets.** Never print, commit or paste any token, key, key id, issuer id, DSN, password, account id or device id. Read them into a variable inside the command that needs them.
- **Report** to the orchestrator: PR number and exact head SHA, what changed, the gate results, the stills or device figures, open risks; then a short Hong Kong Cantonese paragraph. Then stop.

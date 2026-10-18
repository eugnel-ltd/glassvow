# Lane brief template

In local mode save each brief as `<repo>/.claude/worktrees/orch/<lane>-brief.md`; in cloud mode use the orchestrator's task-owned `work/` directory. Hand the agent one line: "Read and follow `<path>` exactly." Keep it under about 60 lines. State facts and decisions; do not restate the lane rules.

```markdown
You own **#<issue> <short outcome>** (Glassvow, `<repo>`, GitHub `<owner>/<repo-name>`). Lane name `<lane>`; branch `<type>/<slug>`, from `origin/main` (`<short sha>` or newer). Worktree: `<repo>/.claude/worktrees/<lane>/wt`.

Execution mode: `<cloud|local>`; set `GLASSVOW_EXECUTION_MODE` accordingly and run the mode check in `docs/agents/cloud-environment.md`.
Rules: read `<path-to-lane-rules.md>` first; it binds. Cloud lanes use the assigned isolated checkout; local lanes use the worktree path above.

**Read (only these):**
- <plan of record, with the sections that are the contract>
- <the code on main this lane builds on>
- <the north star or reference stills, if visual>

**Owner decisions already made (<date>):**
- <D1 ...>
- <D2 ...>
<Say which of them are out of this lane's scope, and where they will land.>

**Scope:** exactly <plan section>.
- <deliverable 1>
- <deliverable 2>

**Non-scope:** <what the next lane does; leave a hook and say where>.

**Carried-over acceptance** (from the previous review, if any):
1. <finding and the probe that proves it fixed>

**Acceptance, proof and device:**
- unit tests for <decision functions>, mutation-checked;
- stills you have looked at, at the three shapes (plus <extra views>);
- <one interleaved iPad 8 batch against main, QA app, shared lock: the bar is "no visible hitch", with any VRAM budget pre-registered in the PR body before the batch>;
- the A12 Mac repro with no shader error, if any spatial shader changed;
- the core gate once on the final candidate, plus `check_anchors` and <payload / export-path checks if assets or presets change>.

Perf bars must be player-visible. The stop conditions apply: under 600 changed lines per code file per commit.

Report as the lane rules say.
```

Variants:

- **Research only** (candidates for an owner pick, a balance reading): "Research only: no branch, no PR, nothing into `assets/` until the owner picks." Give a lane folder instead of a worktree, say which lane rules bind (lean, delete, disk, secrets), and end with the exact report the orchestrator needs (paths, one line per candidate, a recommendation and why).
- **Review brief** for `ai-sdlc-reviewer`: only the task contract, base SHA, exact head SHA, active constraints, the deterministic evidence already run and the head it covered, and up to three priorities. Never the author's transcript or rationale.
- **Resume brief** after a stall or a handoff: the task capsule, the exact head and diff, the failing command, and the next action. Not the transcript.

Before sending, check that the brief names: the exact base SHA, the worktree path, the full `override.cfg` block if anything runs Godot outside the worktree's root, the `--jobs` cap if it runs balance batches, and the iPad lock if it touches the device.

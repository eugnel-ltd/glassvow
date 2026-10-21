# Engineering lessons

A digest of the orchestrator's per-machine memory as of 14 Oct 2026. Each section keeps what happened, why it matters and how to apply it. Paste the relevant ones into briefs; do not paste this whole file.

## Godot engine

### 3D and canvas traps
- **Front faces wind clockwise** in Godot. Hand-built `SurfaceTool` geometry wound anticlockwise is back-face culled with no error: the mesh is invisible while a cull-disabled surface on it still shows.
- **A SubViewport does not re-rasterise fonts under canvas scale**; a 2x-scaled Control tree draws stretched 1x glyphs. Set `SubViewport.oversampling_override` to the scale.
- **Writing one offset of an anchored Control resizes it.** `offset_left = home + dx` grows the box; a later `offset_right = offset_left + size.x` reads the changed size. Cache the width and set both offsets from it. Tweening `position` on an anchored Control rewrites offsets too; re-run placement in the tween's finish callback.
- Debug hooks in `card_view.gd`: `GLASSVOW_TILT="nx,ny"` poses slabs for captures; `GLASSVOW_DUMP=<prefix>` saves each card's 2D face and 3D stage textures, so a defect can be pinned to a pipeline stage.

### `--check-only` exits 0 always
`godot --headless --check-only -s <file>` prints parse errors to stderr and exits 0, so any gate on `$?` has never been able to fail. Use `tools/check_scripts.sh`, or grep the output for `SCRIPT ERROR|Parse Error|ERROR: Failed to load script`. In reports, name the check that produced the evidence: "check-only ok" is not evidence.

### Typed arrays do not convert through `.new()`
A method call converts an untyped array literal to an `Array[Dictionary]` parameter; `.new()` does not, and construction fails at runtime (a dead button; `--check-only` is blind to it). A ternary with a bare `[]` branch assigned to a typed variable fails the same way. Bind the literal to a typed local first, and assign typed arrays under an `if`, not a ternary. A smoke test that constructs every modal is the systemic guard.

### TextureRect size is clamped before `expand_mode`
Setting `size` before `expand_mode = EXPAND_IGNORE_SIZE` floors the write to the texture's natural size, and changing `expand_mode` later does not shrink it back (nine "5 px" pips rendered at 256 px). Order: texture, expand_mode, stretch_mode, size. When properties all read clean but pixels are wrong, bisect layers by toggling visibility and pixel-measure the victim region.

### One backbuffer copy per frame
Godot takes one screen copy, before the first canvas item that reads `hint_screen_texture`. A later opaque full-screen screen-reader restores the frame as at the copy, silently erasing everything between. Have exactly one screen-reading layer and fold every effect into its shader. To prove a shader draws, use an opaque constant-colour plate that declares the same uniform.

### The A12 Metal sampler limit (and its Mac repro)
Godot 4.7.2's Mobile renderer exceeds the 16-sampler limit of A12/A13 GPUs (classic binding, no argument buffers) for any shaded spatial material: the object is simply not drawn (a "raw map", black cutscenes). Fixed upstream for 4.7.3; Glassvow ships a locally built template until then. Reproduce on the Mac in about ten seconds before every engine upgrade or new spatial shader:

```bash
GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 tools/shot.sh --rendering-driver metal --rendering-method mobile \
  --onboard=map-select --seed=1 --shape=pad --shot=<scratch>/a12.png
```

Both renderer flags are needed (`--rendering-driver metal` alone runs Forward+). On the device: engine args go before `devicectl`'s `--`, game args after; Godot's log flushes only on error or exit, so probes write their own rows with `FileAccess.flush()` and are pulled from the app container. `-s <script>` does not work in an exported iOS app; attach a probe Node behind a QA-only boot argument. A `devicectl install` tunnel error 4000 is usually cured by a retry.

### GPU lifetime traps
- **A `BaseMaterial3D`'s generated shader dies with its last ready material**, with all its pipelines; the next use recompiles mid-play. Hold one initialised copy (`get_rid()`) for the scene's life, and check that pipeline-compile counters stay flat after a load.
- **RD transfer staging never shrinks.** Each worker's buffer grows to the next power of two over its largest upload; overlapping uploads spawn more workers. A VRAM delta in exact 8, 12 or 16 MiB steps in the untracked part is staging, not content. Keep single uploads under 4 MiB; `tests/test_texture_uploads.gd` ratchets the old ones.

### A killed Godot truncates `project.godot`
A run killed by a timeout under heavy load left a 17-line `project.godot`. After any kill, run `git status -- project.godot` and `wc -l project.godot` before the next build or test, check every IPA was built after any restore, and never overlap background Godot runs.

### An isolated user dir needs both keys
`override.cfg` must be exactly the `[application]` header plus `config/use_custom_user_dir=true` and `config/custom_user_dir_name="glassvow-<purpose>"`. With the name alone, or without the header, the run uses the real profile under `app_userdata`. Paste the three-line block verbatim in every brief. An exported pck run with `--main-pack` reads the `override.cfg` beside the pck or binary, not the worktree's. Every editor run, including exports, briefly creates `.recovery_mode_lock` in the real profile because the editor ignores `override.cfg`; run export editors with a scratch `HOME` if that matters. Verify isolation by listing the custom folder and checking the real save's hash and mtimes after the first run.

### Capture steals focus on macOS
Every Godot boot takes the frontmost slot for about 0.6 s; nothing in the engine or bundle flags prevents it, and `--position` off-screen is clamped back onto the screen. Use one hot-reloading host (`tools/live.sh start <args>`, then `shot`, `reload`, `key`, `click`) instead of a process per shot; `tools/shot.sh` for a single one-off. The host must `free()` (not `queue_free()`) before reload, set `source_code` from disk before `Script.reload()`, and wait about 30 frames after a rebuild before capturing. A new `class_name` still needs a restart. Focus is no longer a reason to defer a launch.

## Measurement and proof

### Verify the screen before measuring it
`--map` starts a new run on the boon choice screen, not the map, and `live.sh reload` restarts from the boot args. Forty minutes of clean metrics once measured the boon screen's starfield. The first thing done with any capture is to view the whole frame at a legible scale; only then crop or measure. If a metric refuses to move, suspect the frame first. Match full constants when patching probes; a prefix replace hits other curves.

### Matching constants prove nothing
A function existing, called from the right place, with every constant matching, is not evidence it renders: the reference's call may draw nothing (NaN coordinates), and the port's may never run (an update called only at build time, measuring the wrong quantity). Only the screen is evidence. Grep the update function's call sites and ask what its inputs physically measure. To sample an animation over time, fire repeated `live.sh shot`s on one host; a fresh `shot.sh` lands on the same phase every time.

### Assert the decision, not the rule
A pure predicate with green assertions guarded nothing because `_draw` never asked it. Put the decision in a function the draw code calls and does nothing else with (`seats(frame_w)`), assert against real generated geometry, and check every assertion's inputs are reachable by a shipped shape, seed or route. Prove a new gate by mutating the fix out and watching the named assertion fail.

### Mutation proofs restore from a backup
`git checkout -- <file>` after a mutation destroyed five unstaged fixes in that file. Copy the file aside first, restore by copy, and confirm `git diff --stat` still shows your changes (or `shasum` for data files). Staging first is the other valid guard.

### Anchor annotation certifies drift
Bulk-adding `(symbol)` annotations to `file:line` anchors makes `check_anchors.py` pass on citations that had already drifted (at least 30 of 225). Annotate only where the structural enclosing symbol and a symbol the paragraph's prose names agree; where they disagree, repair the number first. Skip anchors inside link labels, code spans with trailing characters and en-dash ranges. Re-anchor only after reading the prose each anchor names.

### Per-recipe knobs, never the shared model
Tuning one card finish by editing the shared `confetti()` moved every sparkle finish, including a shipping tier; five commits were reverted. "The collateral is small" is not a defence. Add a uniform whose default is algebraically the identity, add the key to every `FINISH` entry, set it only on the named recipes, and prove the others unchanged with RMSE = 0 renders.

### The card angular budget
The card slab presents only about 4 to 14 degrees of specular half-angle at rest. So specular exponents must be in the hundreds (under about 100 is a flat wash), micro-relief is specified in degrees of normal tilt (about 3 degrees, not a height amplitude), grain finer than about 1.8 card px is below Nyquist at the 2x render, and additive terms are in linear light where the card stock sits near 0.006. Measure with `GLASSVOW_DUMP`, not a cropped lab screenshot.

### Optimise after visual approval
Measure budgets early, but turn no visual-cost knob (MSAA, oversample, texture compression) until the screen exists and the owner has approved it. Record priced options in writing so another session does not take them as an invitation; pre-restructure numbers are a floor, so re-run the probe when the gate opens.

### Perf bars must be player-visible
#682 Part 2 spent about a day, three iPad reads and roughly 0.9M tokens to shave 30 to 45 ms off loading frames a player may never see; only the first card play (413 to 83 ms) was felt. Before any perf bar, ask whether the frame is visible (covered by a transition, behind a launch screen, mid-animation). Size evidence to the decision, validate the probe on the Mac before a device hold, and stop at diminishing returns.

### Floor and ceiling devices
The iPad 8 (A12) is the floor every budget must hold on, not the only target. Release-path changes (such as the iOS shader bake) are checked on the ceiling device too (the iPhone 16 Pro Max): accepted containers, identical picture, no regression. Visual gains come through quality tiers above the floor. Ask before installing on the owner's iPhone.

## Machine and process

### The scratchpad dies on reboot
`/private/tmp` is wiped by a reboot: on 5 Oct that took every lane worktree, the handoffs, the device scripts and a 10-hour balance batch. Durable lane work, long runs and orchestrator notes live under `<repo>/.claude/worktrees/` (git-ignored); the scratchpad is for throwaway files. Commit work in progress locally before a wind-down. Lost scratch files can be replayed from the session `.jsonl` Write and Edit calls (the recovery kit is in the orchestrator folder's `recover/`).

### The keychain after a reboot
A reboot leaves the dedicated build keychain locked for agent shells; codesign then fails with errSecInternalComponent and every signed export stops. Run `~/.config/eugnel-build/bin/unlock-build-keychain.sh` on the engine. Never unlock the login keychain for Glassvow signing. Lanes never handle the password.

### git push keychain error -25308
Scripted pushes intermittently fail with osxkeychain -25308 ("failed to push some refs"); it is not a GitHub refusal. Push with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push ...`, one second apart. In zsh write refspecs as `"${sha}:refs/heads/x"`; `$sha:r...` is parsed as a modifier.

### Merge races and CI
`gh pr checks --watch` returns at once if no check is registered yet, so a merge straight after `gh pr create` can race CI. Poll until the required `test` check reports SUCCESS on the head, and pass the full SHA to `--match-head-commit`.

### Batch issue posts: strip drafting wrappers
Applying an audit agent's proposed comments verbatim posted fifteen public comments still wrapped in `Comment: "..."` with an instruction to the orchestrator visible. Before a batch post, assert no body starts with `Comment`, `Close`, `Retitle` or a quote mark; read every body yourself (agents reintroduce superseded rulings, such as the owner's play as a gate); read back the first characters after posting; when adding a banner to an issue body, diff the retained text against the previous version.

### External workers and shared trees
External CLI workers edit the working tree they are given. Give each its own worktree; never switch branches under one that is running. Treat a wrapper's verdict as of record only once it is posted on the PR; if it stalls twice, start a fresh one with "do everything with your own tool calls in this task".

## Historical (kept for context only)

- **The web benchmark** (`roguecardv2-benchmark` at its pre-Pixi commit, served on a local port) and its parity-reading tricks: superseded since the 16 Aug 2026 detachment; `tools/check_benchmark_freeze.py` forbids new citations.
- **The in-app browser pane hides the document** (`visibilityState` hidden throttles rAF): only relevant to that benchmark.
- **Six parallel sessions on one tree** (`docs/session-ownership.md`): superseded by one worktree per lane; the per-file gate it prescribed is replaced by the core gate on each lane's worktree.
- **GitHub governance P3 to P8** and the guardrail reviewers: superseded by `docs/agents/ai-sdlc.md`.
- **Desktop session recovery** (CLI transcripts the app never indexed): a one-off diagnosis of July 2026.
- **The Flame authority, the Ash programme and the map revival records**: programme state, now in the repo's design docs, readouts and issues (#544, #657, #660, #661). The owner rulings that still bind are in SKILL.md section 3.

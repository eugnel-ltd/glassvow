# #682 Part 1: the title-time warm and the patched shader bake

Issue #682 asks that no first-use frame on the iPad 8 (A12, Apple GPU family 5)
stalls on a shader or pipeline compile with a cold cache. Part 1 ships the
candidate the Phase B device read (B7) measured, with the fixes its gates
required. It does not close #682: the first map open and the fight's load frame
still run over 100 ms, and Part 2 (B9) takes them on.

## What ships

- **PathWarm** (`presentation/ui/path_warm.gd`), hooked in `Main._show_title`:
  - behind the launch screen, the fight's 3D materials drawn once on stages of
    the targets the fight draws them on (4x MSAA, transparent);
  - while the title rests, after RoomWarm, the 2D materials made and each drawn
    once, and frame 0's stages drawn again after the floor bake's soft key
    switches free them;
  - every material held for the process; every view and sample let go once
    drawn.
- **`EnemyView.stage_environment()`**: the fight stage's light as a static
  builder, so the warm's foe stage is lit exactly as the fight's.
- **The floor bake's two waits** (`presentation/map/landscape/floor_bake.gd`): a
  paced bake (the title's prefetch) lets the land's pipelines compile before its
  soft key switch, and its first tile waits for the soft key's own pipelines.
  Neither wait holds a frame.
- **The iOS shader bake of the game's own shaders**: the preset bakes
  (`shader_baker/enabled=true`), through `tools/godot/bake_export.sh` with a
  patched 4.7.3-rc editor (`tools/godot/patches/`, whose README says how to build
  it, the pinned engine, the guard, the template path, and when to rebake), the
  generated manifest (`tools/shader_bake_manifest.gd`), the stale-bake clean-up,
  and `scripts/ios_release.sh`'s baked path, which stops rather than falls back.
  The bake holds 74 files: the game's 47 shaders as 46 distinct versions (two
  string shaders share one), 28 scene versions in each of the two scene groups
  and 18 canvas versions.
- **The engine's own shaders stay out of the bake** (canvas, sky, tonemap, copy,
  blit and the rest), and so do materials whose shader the engine generates (a
  BaseMaterial3D in an imported scene): the patch bakes ShaderMaterials only. On the iPad 8 the QA app's user cache, which the engine
  reads first, always held their runtime compile, so B7's rows never used their
  bake and their baked picture could not be tested there: iOS keeps `user://` in
  the app's Documents whatever the project names
  (`drivers/apple_embedded/os_apple_embedded.mm:396-404` at godot
  `83dec14d549108e1f314f57c1ce7e932c65370dd`). A fresh install compiles them as
  main does today. Bringing them back waits on an identity test on a fresh app
  container (tracker follow-up).

## The B7 read (11 October, three fresh installs each, the iPad 8 QA app)

| Row | Main | H | Bar | Result |
|---|---|---|---|---|
| Frame 0 since engine start | 11.9–13.9 s (median 12.4) | 5.0–5.2 s | ≤ main + 1 s | pass; watchdog margin 14.9 s |
| Worst title frame | 3.7–4.5 s | 42 ms | ≤ 100 ms | pass |
| RoomWarm's frames | – | 16–17 ms | ≤ 100 ms | pass |
| First map open, worst frame | 6.2–6.3 s | 181–185 ms | ≤ 100 ms | not met (Part 2) |
| Fight load, worst of three frames | 5.8–7.1 s | 399–412 ms | ≤ 100 ms | not met (Part 2) |
| Back to the Road | 8.0–8.1 s | 714–731 ms | < 1 s | pass |
| Settings, first opening | 46.5–48.7 ms | 41.1–41.9 ms | ≤ 32.4 ms | not met by either; pre-existing |
| Shader compiles on the device (title / open / fight) | 17 / 22 / 8 | 0 / 0 / 0, 0 rejected | – | – |
| IPA | 306.5 MB | 345.1 MB | – | +38.6 MB |
| VRAM at the title's rest | 326.6–340.6 MiB | 345.5–353.5 MiB | – | see Gate 2.3 |

B7 measured the lane's `be614ded`. Part 1 adds the first lit tile's wait (Gate
2.2) and keeps the engine's shaders out of the bake; the confirmation installs
below measure the final head.

### Confirmation installs (12 October, one fresh install each, descriptive)

MF is main `ca4ed2c5` with B7's probe; HF is this branch's head, baked. Each has
its own never-compiled nonce. On this iPad the engine's own shaders are warm in
the QA app's cache, so neither arm's frame 0 includes their compile; a real fresh
install of main or of this branch compiles them too.

| Row | MF (main) | HF (this branch) |
|---|---|---|
| Frame 0 since engine start | 11,489 ms (watchdog margin 8.5 s) | 5,825 ms (margin 14.2 s) |
| Worst title frame | 3,605 ms | 76 ms (frame 1) |
| RoomWarm's frames | – | 16 ms |
| First map open, worst frame | 6,195 ms | 192 ms |
| Fight load, worst of three frames | 6,324 ms | 409 ms |
| Back to the Road | 7,842 ms | 731 ms |
| Rooms' first openings (settings / help / credits) | 41 / 51 / 52 ms | 40 / 35 / 30 ms |
| Shader compiles on the device (title / open / fight) | 17 / 22 / 8 | 0 / 0 / 0, 0 rejected |
| VRAM at the title's rest | 325.1 MiB | 339.4 MiB |
| IPA | 306.5 MB | 341.0 MB |

HF was built one commit before the bake dropped its engine-generated material
versions (it shipped 82 files); those versions were never loaded on this iPad,
whose cache held them, so its rows stand for the head.

## Gate 1: per-shader picture identity

The animated B7 captures could not decide whether the baked binaries render as
the runtime compile does, so a deterministic test replaced them.

- **The scene** (QA only, `tools/qa_identity.gd.txt`): every material the bake
  manifest bakes, each in its own tile, on fixed geometry with fixed inputs; 2D
  through a canvas, 3D on a stage with the MSAA and background its use has; one
  view running the fight's post chain; `Engine.time_scale = 0` before any frame,
  which holds the renderer's TIME at 0. Every tile is read back once the scene
  has settled, and again until two reads match.
- **Mac determinism:** two runs of one build under the A12 condition gave
  byte-identical tiles (48 of 48) and root pictures; a cold run and a cached run
  agree too.
- **The device run** (12 October, iPad 8): IB2 (baked, this branch) and IU (the
  same code with the baker off), one install each, two launches each, each with
  its own never-compiled nonce.
  - **K:** IU's first launch compiled the 46 game versions (28 scene, 18 canvas);
    IB2 compiled none of them and rejected none: they came from the bake. IB2's
    one compiled file was the scene's own background card, an engine-generated
    material outside the bake.
  - **The rule, as registered: PASS.** No tile, nor the root picture, nor the
    device screenshot after the blit, exceeds the larger of its launch-to-launch
    difference and one level.
  - **Stronger than the rule:** IB2's two launches and IU's second launch are
    byte-identical on all 48 tiles. IU's first launch, the cold runtime compile,
    differs from all three on 13 lit tiles (by 1–185 levels), so the bake
    reproduces the runtime compile as the device draws it from its cache.
  - No shader is excluded.

The engine's own shaders could not be tested from a bake on this iPad: the QA
app keeps their runtime-compiled cache entries across installs, the engine reads
the user cache before the baked one (`shader_rd.cpp:618-623` at godot
`83dec14d549108e1f314f57c1ce7e932c65370dd`), and iOS ignores a custom user dir.
So they are not baked (see What ships), and their picture is the runtime
compile's by construction.

## Gate 2

### `check_floor_bake`

Two rounds of six runs each, interleaved with `origin/main`, every run started
under a load of 50 (`tools/floor_runs.zsh.txt`): the candidate passed 12 of 12,
main 10 of 12. Main's two failures were the same step, the paced bake's step 6
(the last tile's copy and the soft key's restore switch, which waits for every
compile under way): 420.8 ms and 120.5 ms. The candidate's 1 px start draw took
2.5–3.7 ms in every run, as main's start step did.

### The floor bake's lit picture

Six main runs and three candidate runs per seed, the paced bake's output dumped
(`tools/lit_band.py.txt`):

- the mask is byte-identical at every seed;
- with the lane's single wait, two candidate runs fell outside main's noise (1.4%
  of the lit picture's bytes moved, against 0.09% between main runs): a tile
  drawn before the soft key's pipelines compiled was drawn by the engine's
  ubershader stand-in. The first tile's wait removed it;
- now the candidate's identical-byte share and mean difference sit inside main's
  15-pair band at every seed (0 to 3 of 18 pairs at an edge, against about 1.1 by
  chance per seed and metric). The maximum difference and the count over 8 levels
  follow single texels that flip between runs in either arm (at 717 one texel by
  96 levels in two of three candidate runs; main has its own, by 84).

**As registered (every metric of every pair inside main's min–max band): FAIL.**
The orchestrator then registered one analysis-only check: split main's six runs
into every 3+3 partition and grade one half against the band of the other with
the same max and over-8 bar. Main fails its own bar in 8, 10, 8 and 9 of the 10
splits at seeds 717, 1, 2 and 3, so the bar cannot discriminate, and the gate
passes on the bulk criteria (identical share and mean), where the candidate sits
at main's level. On the flipping texels: at 717 the candidate's texel (1355, 448)
is dark in all six main runs and lit in two of three candidate runs; main's own
runs differ by 96 levels at seed 2 and by 84–86 at seeds 717 and 3.

### VRAM

- On the Mac (the B7 probe, the A12 condition, three runs each) the title's VRAM
  at rest is equal: main 287.4 MiB, the candidate 287.2.
- On the device the rise follows the bake, not the warm: the warm-only arm of the
  four-arm read had 330.3 MiB (main's range 326.6–340.6), the warm with the bake
  345.8, and H 345.5–353.5.
- The reason: a baked shader loads as a binary Metal library at once, every
  variant of its group; an unbaked one compiles lazily on iOS, so variants never
  drawn never cost memory (`rendering_device_driver_metal.cpp:1150-1167` and
  `metal_objects_shared.cpp:878-900` at godot `83dec14d549108e1f314f57c1ce7e932c65370dd`).
  The orchestrator accepted the rise as Part 1's cost, against frame 0 falling
  from 12.4 to 5.1 s. With the engine's shaders out of the bake, HF read 339.4 MiB
  against MF's 325.1 (one install each). Trimming rarely drawn game shaders or
  groups from the bake is a tracker follow-up.
- The warm's own render targets are let go once drawn (`tests/test_path_warm.gd`).

### The A12 condition on the Mac

With the 4.7.3-rc engine (`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1`, Metal, mobile)
the title, the settings, help and credits rooms, the map and a fight show no
"Error compiling shader", and every picture reads as it should. (The stock 4.7.2
binary fails this condition with the 16-sampler errors the template fixes, so it
is not the check.)

## Tests

Each decision has a test, each mutation-proved (backed up, broken, run, copied
back):

| Decision | Test | Mutations that fail it |
|---|---|---|
| The warm holds its materials | `tests/test_path_warm.gd` | no hold in `_keep`; the sky material unheld |
| The warm frees its targets | `tests/test_path_warm.gd` | the stages never let go; the 2D samples kept |
| The floor bake waits for its gate | `tests/test_floor_bake_gate.gd` | no gate; the first tile not gated; the second wait not started afresh |
| The baked export refuses a feature mismatch, and never reads an error as "does not bake" | `tools/godot/test_bake_export.sh` (fake editor) | the refusal unchecked; no `mobile` features; stale caches kept; project.godot not restored; engine groups let through; python3's exit status trusted; an odd answer or a missing preset read as unbaked; an unreadable preset ignored |

The guard itself is C++ in the editor and out of reach of a repository test: the
real patched editor, run without the `mobile` features, printed the refusal and
baked nothing.

## The release path

`scripts/ios_release.sh 21 1f732e20 --no-upload --no-device` from a clean
worktree of the final code (the head differs from it only in this README), with
nothing uploaded or installed (lane log `census/part1-release-dryrun2.log`):

- the baked export ran under a fresh scratch HOME inside `build/ios`; Godot only
  writes the Xcode project (`export_project_only`), so it never calls
  `xcodebuild` there, and the archive and signing ran under the real HOME;
- the bake stored 74 files, game groups only: 28 in each of the two
  `SceneForwardMobileShaderRD` groups and 18 `CanvasShaderRD`; the guard printed
  nothing;
- the App Store IPA (324.8 MiB, sha256 `83402092386650ab…`) is signed "Apple
  Distribution" for team V45S7U2LZB, and its `DTXcodeBuild` is 27A266a (a
  release Xcode, no beta suffix);
- the owner's Godot profile was untouched (no file newer, the folder's own time
  unchanged).

The script stops, never falls back. `bake_export.sh --enabled` answers 0 (bakes),
1 (does not bake) or 2 (any error: no such preset, no python3, a python3 that
fails or answers neither word), and the release stops on anything but 0 or 1: a
python3 that exits 1 stopped it in its pre-flight ("cannot tell whether the iOS
preset bakes its shaders"). With `GLASSVOW_BAKE_EDITOR` unset it stops in its
pre-flight too, and with an unpinned editor `bake_export.sh` refuses and the
release stops at its export.

## Payload

`tools/payload_report.py` estimates 283.1 MiB (it does not see the bake) against
its 400 MiB total; every group is within its budget. The baked pack measures
318.2 MiB, 35.1 MiB (36.8 MB) more than the unbaked one (IB2's export against
IU's, 82 baked files; the head bakes 74), within the 400 MiB ceiling.

## Reproduce

The lane's tools are copied under `tools/` as `.txt`: the identity scene
(`qa_identity.gd.txt`, armed by `arm_identity.py.txt`), its device batch and
grader (`identity_batch.zsh.txt`, `identity_compare.py.txt`), the floor bake's
interleaved runs (`floor_runs.zsh.txt`, which runs `check_floor_bake.gd` with
two extra prints of its step arrays), and the lit picture's dumps and band
(`lane_bake_hash.gd.txt`, `lit_band.py.txt`). They need the lane's QA probe and
nonce tool from #682 Phase B to build the device IPAs.

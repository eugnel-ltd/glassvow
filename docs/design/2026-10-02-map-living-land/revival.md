# Reviving the journey rebuild: audit and plan

Written 3 October 2026 by the map design lane. Owner decision (00:57): "Yes it is
this version. I want you to revive it and based on this, we do the
redesign/upgrade/polish." This file audits the September journey rebuild and
plans how to revive it on top of `MapLayoutFast` on main. It supersedes the
three concepts in [README.md](README.md) §2 as the direction (see the note at the
top of that file).

Sources: `origin/archive/superseded-20260929/jamesto/map-journey-rebuild` at
`7d64678b` (8 Sep; TestFlight build 5 ran `d6c83fb9`), which contains
`origin/archive/superseded-20260929/jamesto/map-act3-step3-approved` at
`72f96b04`. Base of the archive: main at `2ed6cdb0` (5 Sep, #539). It is 69
commits on top of that base and was never merged. PR #540 stayed a draft.

## Headline

- **It renders today.** It runs on Godot 4.7.2 stable and on the Mac's Metal
  Mobile renderer. Under the A12 condition (`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1
  --rendering-driver metal`), pad and phone report **0 shader errors**.
- **`MapLayoutFast` can feed it** with no change to the layout contract, its
  digests or the quality registry. On main's seed 1, Act I, the archived woodland
  terrain, river, bridges, waystones, kit and pilgrim build from the fast
  layout's own `node_anchors` and `edges`, with deck heights in the centreline Y.
  One adapter is needed in the landscape layer: the fast layout's cubic roads
  arrive as dense short segments, so the gateway chooser finds no straight
  3 m passage. Simplifying the centrelines on read (Ramer–Douglas–Peucker at
  0.12 m) fixes it for seeds 1 and 717.
- **The journey camera contract passes on the fast layout.** Seeds 4, 42, 717,
  17634 and 543001 pass all 195–210 contexts at three shapes. Seed 4 is the one
  the compiler could not lay out at all. Seed 1 fails one phone context with the
  rebuild's own bottom panel; with main's chrome (a top HUD, no bottom panel) it
  passes every context.
- **What breaks is cost.** On the M1 Max the Act I build takes 4.2–4.5 s on the
  main thread, against a 0.5 s first-open budget. The stage draws 100k–250k
  primitives plus 190k–660k shadow primitives, renders continuously (the river
  animates), and holds 140–191 MiB of texture memory for the whole process.
  Build 5 shipped with "loading time and physical-device performance remain
  open". No device number exists for it.
- **Plan: 7 PRs for Act I** (§6). Port the Act I landscape modules and kit
  (about 2,300 lines plus 1,100 of journey helpers) and the pilgrim. Rebuild the
  seam into `MapScene` and `WorldMapScreen` against main, plus the camera
  adapter. Drop the compiler-facing recipe, the spatial profile, the workshop
  host and the trials.

## 1. Inventory

**Code on the archive.** Counts below are GDScript plus shaders.

| Area | Files | Lines | What it is |
|---|---|---|---|
| `presentation/map/landscape/` | 25 | 2,288 | Act I: `terrain.gd` (land from route topology), `landform.gd` (upland, incised river, dry passes under upper roads), `terrain_paint` (painted ground shader), `river.gd`/`river.gdshader` (filled channel, depth tint, refraction, sky sheen, shore wash, wakes), `bridge_*` (supported arched bridges with real openings), `road_paths`/`road_details` (graded rounded roads, buried flags), `kit.gd` (placement of the imported woodland kit), `journey.gd` (3D waystones seated on eight measured contacts, footings, engraved glass, states), `pilgrim.gd` (82 lines: anonymous cloaked walker with a lamp) |
| `presentation/map/map_journey_*.gd`, `map_spatial_*`, `map_horizon`, route helpers | 22 | 1,672 | Realisation (`map_journey_realisation.gd`: real heights into the result), camera contract and registry (55°, adaptive zoom), navigation (`map_journey_navigation.gd`: Journey / Whole act, area inspection, context-only pins), framing, derived cache, assets. Recipe and spatial profile feed the compiler. |
| `presentation/map/chapters/{common,stone_bridge,water,act2,act3,act4}` | 75 | 4,823 | Acts II–IV: drowned library and causeways, obsidian courts and stairs, the Act IV void procession; shared stone bridge and water modules |
| `presentation/map/map_scene.gd`, `world_map_screen.gd`, `glass_waystone.gd`, `map_camera_rig.gd` | 4 | +600 / −60 | The integration seam (journey mode, async bind, traveller) |
| `tools/map_workshop/` | 110 | 7,789 | Isolated workshop host, audits (routes, grounding, river, bridges, camera), capture and film tools |
| `tools/map_atelier/journey/*.py` | 6 | 699 | Blender recipes: `build_kit.py`, `foliage.py`, `natural_variants.py`, `stone_finish.py` |
| `tests/` | 60 new, 13 edited | about 2,000 | Journey camera, navigation, cache, realisation, routes, river course, stairs, courts, and others |

**Assets.** `assets/art/map-journey/` (60 MB): 15 production GLBs
(conifer ×3 plus snag, ash copse, heath, bramble and fern, four slate forms, the
amber arch, bridge bay, memorial, waystone, lamp pair), each 1–2 MB because
every GLB embeds its own copy of a 1254² texture. The three source textures are
`ash-stone-colour`, `ash-twigs` and `conifer-sprays`, generated by image-gen on
5 Sep. There are also envelopes, a manifest, runtime fingerprints and a geometry
catalogue. `trials/` holds 15 MB of Tripo trials, which are not used.
`assets/map/act3` and `act4` hold 6 MB of Acts III–IV architecture GLBs. Every
texture imports with `compress/mode=0` (lossless): no VRAM compression.

**Docs.** `docs/map/visual-renovation-rough-plan.md`, `workshop-reuse.md`,
`concepts/` (approved chapter paintings: Act I v2, II v3, III v5, IV v6), and
`studies/` (1,618 files: native workshop reviews 01–10, step3-review,
production-section, act2/3/4-step3, campaign-review). There is also `PLAN.md`
(1,314 lines: the Steps 4–8 execution log).

**State when it stopped.** Step 3 (coherent asset sample) was owner-approved for
all four acts: Act I after Review 10 ("not perfect"), Act II scenery-v2,
Act III precinct-v4, and Act IV void-v1. Steps 4–8 ran autonomously on 7–8
September. The final checkpoint reads 4/5/6/7/8 = 80/100/100/100/20%, 80%
weighted. Still owed:

- Step 4: first construction is still slow. Act I took 6.4–7.6 s early on; the
  Act II async city took 32.3 s first and 36 s with Main.
- Step 8: device performance, the M4 release matrix (bundle never retrieved),
  final independent review, PR merge, and cleanup.

Build 5 went to the internal RC Beta group as "provisional; loading time and
physical-device performance remain open". The programme was superseded on
29–30 September, when Map Compiler v2 (which it consumed) left the player path:
build 8 was killed by the iPad's launch watchdog inside a compile (#619,
`docs/map/production-layout.md`).

## 2. Dependency on Map Compiler v2

What the Act I landscape actually consumes (`MapJourneyLandscape.build`):

- `node_anchors`: id to `[x, y, z]`. Y is 0 on the ground and is used only as a
  tag.
- `edges`: id to `{from, to, centerline, corridor_width}`. Centreline Y above
  0.3 m marks the deck of an upper road. `landform.identify_passages` turns each
  upper/lower crossing into a dry pass under a crowned bridge, with abutments.
- `hero_placements`, through `source_heroes`. The kit places the woodland
  gateway itself, on a straight dry passage it chooses.
- The realisation stage (`map_journey_realisation.finish`) writes realised
  heights back into a new `MapLayoutResult` and runs the camera audit.

What it took from the compiler path, and the gap with `MapLayoutFast`:

| Input | Compiler path (archive) | `MapLayoutFast` on main | Gap and fix (landscape layer only) |
|---|---|---|---|
| Packet shape | `MapLayoutResult` | Same shape (`production-layout.md`) | None |
| Deck tags | Compiler grade separation, deck 0.384 m | Same `MapGradeSeparation` span option: 0.384 m deck, 1.09 m ramps; a plain 0.45 m deck where short | None for the governed span. The 0.45 m plain deck must also read as an upper road (it does: > 0.3 m). |
| Centreline sampling | Long straight polyline legs | Cubics sampled at ≤ 1.94 m; 0 segments ≥ 3 m | Gateway chooser finds no passage. **Fix:** simplify the centreline on read (RDP 0.12 m; seed 1: 790 to 285 points, 68 legs ≥ 3 m) or score passages over 3 m windows. Proven on seeds 1 and 717. |
| Elevation | None. The rebuild derives all relief itself (`landform`), never from the compiler | None | None: the "elevation from the route topology" is the landscape's own derivation |
| River | Its own adaptive course (`river_course.choose`) clear of dry passes | Two fixed ravines (`MapRavine`, x = −20.5 and 10.5); the seating keeps waystones off them or stands them on piers | The journey ignores `MapRavine` and places its river near x ≈ −5. Nodes the fast layout put in that column stand on bridge piers (`RIVER_PIERS`). The ravines become ordinary land. **Decision for R1:** keep the journey's own river (approved look), and keep `MapRavine` as a layout input only. |
| Heroes | Recipe put a memorial at boss + 8 m and passed it to the compiler as the terminus | Main's hero contract: the Vigil (−41.3, 6.5) and the amber tower (43, 0), unchanged | Keep main's contract as layout input (digest unchanged). Dress the two protected zones with journey kit landmarks of the same footprint class (the memorial or a lamp-lit gate for the terminus, a hearth chapel for the Vigil) inside the zones. |
| Quality registry | The recipe added `journey_camera` and `spatial_profile` to the registry, so they entered the compiler input | Main's registry, unchanged, in the layout input | The journey camera contract becomes a **presentation** contract audited at bind; it never enters the layout input. The registry stays the layout's governed authority. |
| Camera contract | `audit_surface` at realisation; failure fails the map | — | Passes 5 of 6 fast seeds with the rebuild's panel; 6 of 6 with main's chrome (see the headline). A failing context falls back to the governed 40° framing for that context, never to a failed map. |

**Verdict:** feeding the rebuild from `MapLayoutFast` needs no change to the
layout contract, its digests or the quality registry. Of the coordinator's stop
conditions, (c) is not hit.

Evidence (all Act I, `--assets --steps=2`): main's seed 1 through the archive
landscape at pad, Journey and Whole act, in
[`frames/journey/fast1-1180x820.png`](frames/journey/fast1-1180x820.png) and
[`frames/journey/fast1-whole-1180x820.png`](frames/journey/fast1-whole-1180x820.png).
Before the adapter the same run failed with "No clear gateway passage in this
workshop sample".

## 3. Running it on Godot 4.7.2

| Run | Result |
|---|---|
| Workshop, approved seed-717 sample, pad and phone (`tools/map_workshop/run.gd --assets`) | Renders. Build plus capture takes 6–11 s per process. |
| Same, Whole act (`--survey`) | Renders: river, bridges, woodland, the gateway arch, all waystone engravings |
| Same, under the A12 condition, pad and phone | 0 `Error compiling shader`, 0 errors |
| Fast seed 1 and seed 717 through the RDP adapter, pad, Journey and Whole act | Renders. 568 and 523 placements, 70 and 76 edges. |
| Production path at the archive head (`preview_map.gd` act 0) | Not run: it dispatches Map Compiler v2 (160–300 s per Act I compile, and seed 1 is infeasible). This is the reason for the revival, not a defect of the landscape. |

Stills in `frames/journey/`:

- `archive-717-1180x820.png`, `archive-717-844x390.png`,
  `archive-717-whole-1180x820.png`: the archive as approved.
- `fast1-1180x820.png`, `fast1-whole-1180x820.png`: main's fast layout through
  the archive landscape.
- `archive-717-a12-1180x820.png`: the A12 condition.

## 4. Performance on the Mac (M1 Max, Metal, Mobile, debug)

Measured with a scratch runner on the workshop host
(`scratch_audit/measure.gd` in the throwaway checkout): two steps in, a 30-frame
settle, then 120 frames at rest and 120 frames while the pilgrim walks, vsync
off.

| Sample, shape | Build (main thread) | Rest p50 / p95 | Walking p50 / p95 | Stage calls / prims | Shadow calls / prims | Texture memory (process) |
|---|---|---|---|---|---|---|
| Archive 717, pad | 4,502 ms | 8.2 / 9.8 ms | 8.3 / 10.7 ms | 63 / 203k | 39 / 291k | 191 MiB |
| Archive 717, phone | 4,488 ms | 8.4 / 14.9 ms | 8.3 / 12.8 ms | 95 / 237k | 73 / 397k | 140 MiB |
| Fast seed 1, pad | 4,169 ms | 8.5 / 12.1 ms | 8.5 / 13.6 ms | 65 / 101k | 45 / 194k | 191 MiB |
| Fast seed 1, phone | 4,214 ms | 8.6 / 12.4 ms | 8.7 / 14.9 ms | 96 / 253k | 53 / 662k | 140 MiB |

For comparison, main today: first open 0.30–0.46 s warmed, reopen 6–54 ms. The
stage is frozen at rest; forced live it draws 38 calls and 78k primitives, plus
10 calls and 46k in the shadow pass. The frame interval on this Mac is pinned
near the 120 Hz display, so p50 does not rank GPU cost; the primitive counts do.

**Build 5's device evidence.** There is none. `testflight-build.json`: "Loading
time and physical-device performance remain open." `PLAN.md` records the iPad 8
tunnel as connected, but no measurement. It also records an M4 release canary of
p95 4.4 ms and a 401 MiB renderer peak (Act II, desktop), and a 24-case M4 matrix
whose bundle was never retrieved. No later build carried the rebuild (builds
6–17 come from main).

## 5. What main has that the rebuild lacks, and must keep

| Main capability | Where | What R1 must do |
|---|---|---|
| `MapLayoutFast`, 30–45 ms, deterministic, no failure path | `map_layout_fast*.gd`, `tests/test_map_layout_fast.gd` | Feed the landscape from it; golden geometry unchanged |
| Kept screen | `MapScreenKeep`, `WorldMapScreen.reopen`; stage parked at 2×2 off the tree | The journey landscape lives in the kept screen. The reopen applies state only (glass states, pilgrim seat), never a rebuild. The river's continuous render stops while parked. |
| Prefetch | `MapLandscapeAssets.prefetch` on a worker; `Image` imports | Warm the journey kit (GLBs) and, once the layout is known, the terrain and kit geometry on a worker; publish nodes on the main thread (the archive's Act II `geometry_job.gd` pattern) |
| Bind cache | `MapScene._bound` keyed by layout, catalogue and salt digests | Holds the built journey geometry, so a rebuilt screen in the same act costs no terrain build |
| RunHud and the act title bar | `RunHud`, `_title_label` (#578) | Keep. The rebuild's own top/bottom panels and buttons are dropped. Journey / Whole act becomes the existing zoom control (wheel, pinch, keyboard), not new chrome. |
| First-run hints | `HintGuide` in `application/main.gd`, `MAP_SELECT` | The hint anchors on the first live waystone's projected seat; the journey pins must keep `first_live_waystone()` truthful |
| The Flame lantern on the map | `_seat_marker`, `marker_world_position`, the glide in `choose` | The pilgrim carries it: the lamp takes the run's flame colour, and the pilgrim's position is the marker position, sampled from the walking route |
| Save/resume | `_continue_run`; nothing about layout is saved | Unchanged. The archive's derived disk cache is not ported in R1 (no new file in `user://`). |
| Quality registry and tappability tests | `content/map/map-quality-v2.json`, `tests/test_map_pins.gd`, `test_map_quality*.gd`, `test_map_layout_fast.gd` | Unchanged and still passing. Act I additionally passes the journey camera contract at bind (a presentation test is added, none weakened). |
| Landscape-only shapes | `StageShape.SHIPPING` | The camera contract already audits all three shipping shapes |
| `--onboard=map-select`, `tools/shot.sh`, `tools/preview_map.gd` | `application/main.gd`, `tools/` | Act I captures come from the real boot |
| Acts II–IV | `MapLandscapeAssets` cards | Stay on the current dressing in R1; the act switch selects the landscape class |

## 6. Revival plan (R1: Act I on main)

**Port as-is, in their own "port" commits:**

- `presentation/map/landscape/*` (25 files).
- The `assets/art/map-journey/` production GLBs, textures, envelopes, manifest,
  fingerprints and catalogue (not `trials/`).
- `tools/map_atelier/journey/*.py`, as the Blender recipes for the art ledger.

**Port with edits:**

- `map_journey_landscape.gd`: drop `realise()`'s write-back into a new layout
  result and keep realised heights presentation-side.
- `map_journey_camera_contract.gd`: the safe rect follows main's chrome.
- `map_journey_navigation.gd`: reduced to Journey / Whole act framing driven by
  main's zoom input; no bottom panel.
- `map_journey_assets.gd` and `map_journey_framing.gd`.

**Rebuild against main:**

- The `MapScene` seam: the landscape class per act, a centreline adapter, glass
  and pilgrim state, and live-at-rest throttling (D2: 30 Hz, 15 Hz under Reduce
  Motion, stopped while parked).
- The `WorldMapScreen` seam: the pilgrim as the Flame marker, travel along the
  walking route, Journey / Whole act on the existing zoom stops, pins only for
  context nodes in Journey and non-interactive in Whole act.

**Drop:**

- The compiler-facing recipe, spatial profile and ordering/spacing (they fed the
  compiler).
- The derived disk cache, the workshop host and audits (keep the audits as
  references in the archive).
- Acts II–IV chapters, until R2–R4.
- Tripo trials, the rebuild's chrome panels, and `content/map-quality-v2.json`
  moves (main already moved it to `content/map/`).

**PR order** (one branch per PR off main, each ≤ 600 adds+dels per code file per
commit):

1. Port the Act I landscape modules and kit, with no caller (dead code behind a
   test that builds the terrain and kit from a fast layout).
2. Seam: `MapScene` builds the journey landscape for Act I from `MapLayoutFast`
   (centreline adapter, heroes into the protected zones, glass states), with the
   governed 40° camera unchanged. Scenery acceptance digests updated in its own
   commit.
3. Camera: 55° Journey and Whole act on the existing zoom input, with the
   presentation camera contract test and a fallback to 40° for any infeasible
   context.
4. The pilgrim as the Flame marker: walk on travel, seat at the current
   waystone, Reduce Motion places it.
5. Cost: worker build plus kept-screen reuse, VRAM-compressed (ASTC) textures,
   de-duplicated GLB textures, shadow-caster LOD, and the D2 rest cadence.
6. Evidence: three shapes, both locales, fresh and mid-act; A12 Metal check;
   Mac numbers; device run on the iPad 8 (QA export flow).
7. Docs and ledgers: art-ledger rows, `production-layout.md`, the retirement
   note.

The coordinator asked for R1 on one branch; there, these become ordered commits
on `map/living-land-2026-10-02` with the same boundaries.

**A12 risks and how each is measured:**

| Risk | Measure |
|---|---|
| First open: 4.2 s main-thread build on the M1 Max, likely several times that on the A12 | Worker build started at routing (layout is 30–45 ms, so known early); `MAP_OPEN` rows (`tools/shot.sh --map --map-timing`); device `--map-timing` rows via the QA flow. Budget: warmed first open ≤ 0.5 s, reopen ≤ 50 ms. |
| Texture memory: lossless 1254² textures embedded per GLB | `MAP_KEPT` `kept_mib`/`act_mib`; `Performance.RENDER_TEXTURE_MEM_USED`. Target ≤ 80 MiB kept per act after ASTC and de-duplication. |
| Shadow pass: 190k–660k primitives | `viewport_get_render_info(SHADOW)` in `tools/bench_map_rest.gd`; target ≤ 60k at the default framing, via caster LOD and a fitted shadow distance |
| Continuous render (river, pilgrim) at rest | `bench_map_rest.gd` p95 at the 30 Hz cadence; device frame pacing p95 ≤ 16.67 ms |
| Sampler limit | The A12 Metal capture on each new or changed shader. Today: 0 errors. |
| Refraction or screen read in the river shader | Count `hint_screen_texture` readers per frame: one allowed |

## 7. Not decided here

- Whether the journey's own river replaces `MapRavine`'s two ravines visually for
  good. R1 says yes, because the approved look has one river. The ravines remain
  a layout input, so the seating still keeps waystones off them, and some
  waystones will stand slightly off the river's actual course. This is the main
  visible cost of not changing the layout contract. A later layout PR could
  align `MapRavine` with the journey river, but that changes digests and needs
  the owner's call.
- Acts II–IV revival (R2–R4) order and scope, after Act I is reviewed.

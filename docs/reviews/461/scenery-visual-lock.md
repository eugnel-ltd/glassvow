# #461 — scenery visual lock (reading slice)

**Status: design lock only. No production code written. #461 stays OPEN. Nothing
here claims commercial-grade.**

Owner signal (James, 17:22 BST 31 Aug 2026), still standing after Stage 1:
*"scenery is black now; I see multiple shadows instead of scenery."*

This lock covers the slice that makes **already-placed scenery read as scenery**.
It adds no density and no art. The placement slice locked in
`remaining-commercial-gap.md` is solved, landed, and untouched.

**Stage 1 is done and must not be re-run. Stage 2 is the active stage.**
Core Stage 2 eye: **rock reads as rock, shadow reads as shadow.**

| | |
| --- | --- |
| Base | `origin/main` `c28ae388` (fetched; 0 behind) |
| Candidate under review | `/Users/jamesto/Research/glassvow-461-scenery`, branch `jamesto/issue-461-scenery-compiler` |
| This lock | authored in a native worktree; the candidate holds a copy beside its exhibits |
| Exhibits | `/Users/jamesto/Research/glassvow-461-scenery/docs/reviews/461/evidence/` |

---

## 1. Diagnosis (settled — do not re-derive)

### Cause A — capture backend. **Closed by Stage 1.**

`project.godot:54` ships `renderer/rendering_method="mobile"` (Forward Mobile).
The `461-scenery` packet was captured on GL Compatibility. Measured at `c28ae388`,
same seed, same camera, only the backend flag changed:

| | prop median | ground median | prop/ground |
| --- | ---: | ---: | ---: |
| `mobile` (ships) | 37.4 | 77.0 | **0.486** |
| `gl_compatibility` | 6.2 | 48.7 | **0.128** |

Exhibit `evidence/backend-ab-same-prop.png`: the same rock keeps its lit top, mid
front and dark side faces on Mobile and collapses to a black cutout on
Compatibility. Stage 1 recaptured on Mobile and reproduced the ratio
independently at **0.486723**. Cause A is understood and no longer in play.

### Cause B — contact shadows are painted at fixed positions and no longer match the compiled placements. **This is Stage 2.**

`assets/art/map/grades/act1-grade.png` alpha is a fixed constellation of **21 soft
round contact blobs** at authored world positions (`evidence/act1-grade-alpha.png`;
alpha min 102, 11.4% of texels below 220). Every act ships one: 21 / 22 / 18 / 20
for Acts I–IV.

`MapMaterials.bind_act` builds the placement-derived grade and then throws it away:

- `presentation/map/map_materials.gd:117-118` — `procedural_grade = grade_for(region, positions)`, then `bind_region(region, procedural_grade)`.
- `presentation/map/map_materials.gd:192-193` — `if painted_grade != null: bind_region(region, painted_grade)` **replaces it wholesale**, discarding the placement-derived alpha.

And the positions it was given were the wrong set anyway:

- `presentation/map/map_scene.gd:342` — `_materials.bind_act(region, _all_prop_positions())`, the 25-seat deal.
- `presentation/map/map_scene.gd:818` — the candidate's own comment: the dealt seats are no longer where ordinary scenery goes.
- `bind_layout` / `_place_scenery` receive `scenery_instances` and never rebind the grade.

So one frame carries two unrelated position sets. Visible result, confirmed again
by Stage 1 T7 on Forward Mobile: **ground ellipses in open ground with no prop
standing in them, and props standing on ground with no contact blob.**

This also removes the prop's own grounding term. `map_prop.gdshader` reads the same
alpha (`nl -= (1.0 - g.a) * contact`, `contact = 0.55`) and its header names that
darkening as *"the ONLY mechanism in the whole design that can see a neighbour"* —
the stand-in for the cast shadow this renderer does not have. Today a prop is
graded by whichever stranger's blob it happens to stand near, or by none at all.

### Cause C — value gap and band count. **Conditional. Stage 3. Do not start.**

`PROP_VALUE 0.100` vs `GROUND_VALUE 0.420`, and with `bands = 3` most prop faces
resolve into two ramp steps. Whether that still reads as a silhouette after
Stage 2 is **not yet known and must not be guessed at.**

### Not implicated

The Vigil: the chapel measures 0.92 of ground median; the prop shader would put it
at ~0.49, so its baked albedo bound correctly. All eight Act I kits resolve, so
`FlatWedges` / `StackedSlabs` / `DabMasses` are hidden and are not what is on
screen. Compiler scale is `helper.default_scale(profile)` times a bounded
variation — no size blow-up.

---

## 2. Stage 1 — DONE. Do not re-run.

Packet: `/Users/jamesto/Research/glassvow-461-scenery/docs/reviews/461-scenery-mobile/`

| Check | Result |
| --- | --- |
| T1 runtime rendering method from `RenderingServer.get_current_rendering_method()` | **PASS** — `mobile`, equals shipping method |
| T2 recorded capture command actually executed at that head, no override | **PASS** — exit 0, 846.211 s |
| T3 all five layout digests byte-equal to `461-scenery`; hard-zero metrics zero; occupancy 15–21 inside 14–24 | **PASS** |
| T4 grade-alpha contract | SKIPPED — Stage 2 |
| T5 orphan contact ellipses | SKIPPED — Stage 2 |
| T6 prop/ground median luminance ratio | **REPORTED, NOT GRADED** — prop 36.6578, ground 75.3156, ratio **0.486723** |
| T7 visual inspection, 12 frames, pad + phone, opening/focused/travel-midpoint, on `mobile` | **PERFORMED** |

**Stage 1 stop rule FAILED. The owner eye did not clear.** Stage 1 T7 recorded:
Forward Mobile preserves the facets, but *"fixed painted contact ellipses remain
visibly detached from some compiled props"* — Cause B, still visible. Proceed to
Stage 2.

Stage 1 changed no candidate production file. It moved the capture harness's
source guard off the stale `52a56e72` snapshot, dropped the forced GL
Compatibility override, and recorded the runtime method — `tools/capture_461_scenery.gd`
and `tools/capture_build4_map_corpus.sh` in the candidate tree. Reuse that harness.

---

## 3. Stage 2 — implementable spec

**Goal:** keep the painted grade's RGB (corridor + aerial ramp — that is the art)
and bake its **alpha** from the compiled `scenery_instances` origins, re-baking when
placements land. One change removes the orphan ellipses *and* restores the
prop-vs-ground grounding term.

### 3.1 Files Codex may touch, and the one-line job of each

| File | Job |
| --- | --- |
| `presentation/map/map_materials.gd` | Own the composite. Cache the act's painted RGB; add one public method that rebinds the grade with a placement-derived alpha. Stop letting the painted grade replace the bake wholesale. |
| `presentation/map/map_scene.gd` | Call that method from `_place_scenery` with the compiled origins. Stop feeding `_all_prop_positions()` as the live contact set at line 342. |
| `tests/test_map_grade_contact.gd` (new) | The T4 contract. Auto-discovered by `tests/run_all.gd` (it globs `res://tests/test_*.gd`) — no runner edit. `git add` it before `tools/check_scripts.sh`, which uses `git ls-files`. |
| `tests/test_map_scene.gd` | Only if an existing assertion pins the old grade behaviour. Do not broaden it. |

**Nothing else.** Not `map_layout_compiler.gd`, not `map_layout_compiler_routes.gd`,
not the shaders, not the assets, not `tools/map_scene_proxy.gd` (see §3.7).

### 3.2 The composite

Put the whole composite inside `MapMaterials`. It already owns the painted grade,
`bind_region`, and the bake; `MapScene` does not currently keep the painted texture.

New public method, one job:

```
func bind_scenery_contact(region: MapRegions, positions: PackedVector3Array) -> void
```

It rebinds the single `grade` sampler with **painted RGB + alpha baked from
`positions`**. Both shaders read RGB and A from that one sampler at one UV, so this
must stay one texture — do not add a second sampler. `map_ground.gdshader` does
exactly two fetches over ~85% of the frame and its header argues that budget
explicitly; a third fetch is out of scope.

Construction:

1. **RGB source.** If the act shipped a painted grade, use its decoded pixels,
   unresampled, at the painted image's own resolution (Act I is 512×256). If the act
   shipped none, fall back to the existing procedural RGB at `GRADE_RESOLUTION`
   (256×128). `GRADE_MIN` / `GRADE_SIZE` are unchanged, so the world mapping is
   resolution-independent.
2. **Alpha.** Start at `1.0` everywhere. For each position, min-blend the existing
   falloff, constants unchanged:
   `alpha = minf(alpha, lerpf(0.18, 1.0, smoothstep(0.35, 1.75, distance)))`
   where `distance` is the world XZ distance from the texel centre to the position.
   This is the same expression `_grade_image` already uses at
   `presentation/map/map_materials.gd:306-321`. Do not write a second falloff.
3. **Bake only inside each position's compact support.** `smoothstep(0.35, 1.75, d)`
   returns exactly `1.0` at `d >= 1.75`, and `minf(a, 1.0)` is the identity, so
   texels beyond 1.75 m of every position are provably untouched. Walk a bounded
   texel box of radius `1.75` m per position instead of the full image. This is
   **exactly** equivalent to the full walk, not an approximation — T4 asserts the
   equivalence.
4. Wrap in `ImageTexture.create_from_image(...)` and call the existing
   `bind_region(region, composite)`, which fans the grade out to ground, road, prop
   and (when present) vigil in one call.

**Do not** change `GRADE_MIN`, `GRADE_SIZE`, `GRADE_RESOLUTION`, the `0.18` floor,
the `0.35` / `1.75` radii, or `contact = 0.55` in either shader.

### 3.3 Preflight — settle this BEFORE writing the composite

The grade PNGs import VRAM-compressed: `assets/art/map/grades/act1-grade.png.import`
has `compress/mode=2` with `imported_formats: ["s3tc_bptc", "etc2_astc"]`, so the
runtime resource is a `CompressedTexture2D` in BPTC or ASTC, not RGBA8.

Run one bounded check: does `painted.get_image()` followed by `Image.decompress()`
yield a usable `FORMAT_RGBA8` image at the source resolution, in this project, on
this Godot build?

- **Yes** → decode once per `bind_act`, cache the decoded RGB `Image` on
  `MapMaterials`, and let each re-bake rewrite only the alpha channel of a duplicate.
  No asset change, no `.import` change.
- **No** → **STOP and escalate the import-mode question.** Do not silently fall back
  to procedural RGB (that discards the art), do not load the source `.png` by path
  (source files are not shipped in an export), and do not invent a GPU readback.

State the preflight result in the packet either way.

### 3.4 When it runs

`MapScene._place_scenery(placements)` (`presentation/map/map_scene.gd:648`) is the
single funnel: it is called from `bind_layout` with the compiled `scenery_instances`
and from `_fail_layout` with `{}`. Hook there and both cases are correct with one
call site.

- **`_place_scenery`** — collect the origins in the loop that already walks
  `MapLayoutCanonical.sorted_keys(placements)` to build `pieces`, then call
  `_materials.bind_scenery_contact(MapRegions.for_act(_act), origins)`.
  `MapRegions.for_act` is static and pure, so no new state is needed on `MapScene`.
- **`_fail_layout`** — already calls `_place_scenery({})`; an empty set bakes alpha
  `1.0` everywhere, so a failed layout has no scenery and correctly shows no contact
  shadows. No extra handling.
- **`bind_act`, before the compiler has run** — call the same composite with an
  **empty** `PackedVector3Array`. The painted RGB lands from the first frame, and
  there are **no orphan blobs** at any point. This replaces the
  `if painted_grade != null: bind_region(region, painted_grade)` shortcut at
  `map_materials.gd:192-193`.
- **`map_scene.gd:342`** — `_materials.bind_act(region, _all_prop_positions())` must
  stop supplying the live contact set. The dealt seats remain the placeholder and
  road-kit layout and keep that job; they are no longer a contact source.

Confirm no frame is presented between `_deal_act` and the first `bind_layout` that
would show un-contacted ground. If one is, say so and hold the previous grade rather
than flashing.

### 3.5 Extracting the origins

Build a `PackedVector3Array` of the compiled placement origins only:

```
for placement_id in MapLayoutCanonical.sorted_keys(placements):
    origin = _v3(placements[placement_id]["transform"]["origin"])
```

- Only `transform.origin`. Yaw, scale, profile and AABB are irrelevant to the bake —
  the falloff is a fixed world-space radius.
- Only `scenery_instances`. **Never** `_all_prop_positions()`, `_dealt_seats()`,
  `_wedge_positions()`, `_slab_positions()` or `_dab_positions()`.
- **Do not gate origin collection on `_active_profiles.has(profile_id)`.** The
  existing `pieces` loop skips placements with no active profile; the contact set
  must not, or a missing profile silently drops a blob and re-creates the same
  mismatch in the other direction.
- Iterate in `sorted_keys` order so the bake is deterministic.

### 3.6 Cost ceiling

A full-image walk at the painted resolution would be 512 × 256 × 21 ≈ **2.75 M**
distance terms per layout bind — about 3.4× what the current per-act 256 × 128 × 25
bake pays, and it would run on every layout bind rather than once per act. The
compact-support bake in §3.2 step 3 replaces it with roughly 25 × 25 texels per
placement, ≈ **13 k** writes for 21 placements — same result, ~200× less work, and
less code than the nested full walk.

Leave a `ponytail:`-style comment naming the ceiling: CPU bake, O(N · r²) texels,
once per layout bind. **Do not move it off the CPU without a bench that says it
matters.**

### 3.7 Leave the proxy alone

`tools/map_scene_proxy.gd:239-261` is a twin of the same bake with the identical
`lerpf(0.18, 1.0, smoothstep(0.35, 1.75, distance))` falloff. It is a #291-era
research probe over its own synthetic positions and answers a different question.
**Do not "fix" it to match.** Stage 2 does not move the falloff constants, so the
two do not drift. If a later stage ever moves them, both files move in one edit.

---

## 4. Stage 2 pass / fail

Report every number at the exact final head, on Forward Mobile.

| # | Check | Pass |
| --- | --- | --- |
| **T1** | Packet manifest records the runtime rendering method from `RenderingServer.get_current_rendering_method()` | equals the `project.godot` shipping method (`mobile`) |
| **T2** | Packet manifest records a capture command that actually ran at that head, with no rendering-method override | true and reproducible |
| **T3** | All five layout digests vs the `461-scenery` / `461-scenery-mobile` packets | **byte-equal** (see §4.1) |
| **T4** | `tests/test_map_grade_contact.gd` — grade-alpha contract | all four clauses in §4.2 |
| **T5** | Orphan contact ellipses, Act I seed 717 opening frame, Forward Mobile | **0** — every ground contact ellipse has a compiled kit standing in it |
| **T6** | Prop / ground median luminance ratio, Act I seed 717, same fixed ROIs as Stage 1 | **reported, not graded.** Baselines: 0.486723 (Stage 1 Mobile), 0.393 (#529 packet), 0.137 (`461-scenery` Compatibility). Do not invent a numeric bar and call it a pass |
| **T7** | Owner eye, on the running result at the shipping backend | **rock reads as rock, shadow reads as shadow.** Not satisfiable from source or from numbers |

### 4.1 Layout digests — must stay byte-equal

Stage 2 is presentation-only. Any change here proves it leaked into placement.

```
Act I   17634  5a7d6a435082707594c9ec56f6c321291fbba42133622a73997ed3fa298b3545
Act I     717  9b182e7c36d840c8850d8df62dbb01485ce90eacab6d7ce3684a24319f0d8091
Act II    717  6d5bd644c02867b8e316d4b0f0442d24720719e088a622ff0f9609ddd14089c7
Act III   717  54341c63a16c278dc1e807aa0cf32800838437d9b340c79a3e8b800e848ae75d
Act IV    717  a995141403bf08da65221c1e2e0837884484508132123c0c51853a7b296dcf5c
```

### 4.2 T4 contract — `tests/test_map_grade_contact.gd`

`extends RefCounted`, `static func run(fails: Array[String]) -> void`, matching the
convention in `tests/test_map_layout_scenery.gd`. Test the **alpha bake in
isolation**, as a pure function of a position set — not the RGB composite, which is
a copy and whose decoded bytes are platform-dependent.

Over a synthetic position set and over the real Act I seed 717 compiled origins:

1. **Minimum under each placement.** For every compiled placement, the alpha at the
   texel containing its world XZ is the floor: `<= 0.19`. (A texel half-diagonal is
   ≈0.099 m at 512×256 over `GRADE_SIZE`, well inside the 0.35 m plateau, so the
   value is exactly the `0.18` floor up to 8-bit quantisation.)
2. **Unity far from every placement.** Any texel whose world XZ is `>= 1.75` m from
   every placement has alpha `== 1.0`.
3. **No orphan minimum.** Every texel with alpha `< 1.0` lies within `1.75` m of at
   least one compiled placement. *This is the clause that kills the painted
   constellation.*
4. **Compact support is exact.** The bounded-box bake is per-texel equal to a
   reference full-image walk over the same positions.

Also assert the empty case: an empty position set yields alpha `== 1.0` everywhere.

### 4.3 T5 procedure

T4 proves it analytically at the texture level; T5 confirms it in the frame.
Project the compiled placement origins to screen with the existing
`MapScene.project_anchors(...)` and overlay them on the Act I seed 717 opening frame.
Every distinct ground contact ellipse must contain a projected placement. Report the
overlay in the packet.

### 4.4 Capture matrix

Identical to `#529` / `461-scenery` / `461-scenery-mobile`: 5 compiler inputs
(Act I seeds 17634 and 717; Acts II, III, IV seed 717), 12 frames, shapes
pad-landscape and phone-landscape, poses opening / focused / travel-midpoint,
locale `en`, **Forward Mobile**, runtime method from
`RenderingServer.get_current_rendering_method()`. Reuse the Stage 1 harness. Publish
before/after against `docs/reviews/461-scenery-mobile/` so Stage 2's effect is
isolated from Stage 1's backend correction.

### 4.5 Core gate

On the coherent final candidate, before the first push:

```bash
godot --version
tools/check_imports.sh
tools/check_scripts.sh
godot --headless -s res://tests/run_all.gd
```

Stage every new `.gd` first — the sweep uses `git ls-files`. Never grade
`godot --check-only` by exit status. If screenshots were taken before the suite,
clear the run save first (`~/Library/Application Support/Godot/app_userdata/Glassvow/glassvow_run_v2.json`),
or you will collect failures with no cause in the diff.

### 4.6 Hard invariants — unchanged, not merely still passing

Stage 2 changes no placement, so show these are **identical** to
`461-scenery-mobile`, not just green:

| Metric | Required |
| --- | --- |
| `edge_scenery_corridor_penetration_m` | `== 0.0` |
| `node_scenery_silhouette_overlap_area_px2` | `== 0.0` |
| `node_touch_scenery_silhouette_overlap_area_px2` | `== 0.0` |
| `vigil_protected_zone_intrusion_count` | `== 0` |
| `terminus_protected_zone_intrusion_count` | `== 0` |

Occupancy stays 15–21, inside the locked 14–24 band, unchanged.

---

## 5. Stage 2 stop rule

Recapture on Forward Mobile and re-judge. **If the orphan ellipses are gone and the
props read as grounded masses, STOP.** Do not start Stage 3 speculatively; do not
tune a uniform "while you are in there".

Stage 3 stays conditional and remains limited to the prop material's `bands` or
`contact` uniforms, with a fresh measurement and an owner call first. **Never
`PROP_VALUE`, never `GROUND_VALUE`** — that is #234's decision.

---

## 6. Do not

- Do not add scenery density or touch `SCENERY_MIN_INSTANCES` / `SCENERY_MAX_INSTANCES` / zone caps.
- Do not touch `map_layout_compiler.gd` or `map_layout_compiler_routes.gd`. Placement is solved and stays landed.
- Do not commission, add, or regenerate art assets. If the §3.3 preflight fails, escalate the `.import` question — do not change asset bytes.
- Do not touch routes, waylights, the camera, or ground/terrain art.
- Do not add a second grade sampler or a third fetch to `map_ground.gdshader`.
- Do not touch `tools/map_scene_proxy.gd`.
- Do not reopen the PathBand 2D overlay.
- Do not touch P9 / #108 (frozen) or Emberglass (sealed). No balance work.
- Do not move `PROP_VALUE`, `GROUND_VALUE`, or the anchor value gap in this slice.
- Do not regenerate `port_fixtures/`.
- Do not re-run Stage 1.
- Do not close #461. Do not claim commercial-grade. Do not merge on your own reading of the frames — the owner's eye is the gate for T6 and T7.
- Do not record a capture command, head, or renderer that did not run.

---

## 7. Provenance of this lock

| Item | Value |
| --- | --- |
| Author | Claude (design only; no production code changed, no commit, no push) |
| Date | 2026-08-31 |
| Base | `origin/main` `c28ae388` (fetched; worktree 0 behind) |
| Candidate read (not mutated) | `/Users/jamesto/Research/glassvow-461-scenery` @ `jamesto/issue-461-scenery-compiler` |
| A/B captures | `godot --path . --rendering-method {mobile,gl_compatibility} -- --map --seed=717 --act=0 --settle=1 --shot=…` at `c28ae388`, Godot 4.7.2.stable.official.ed1daf0bf, macOS |
| Stage 1 packet | `docs/reviews/461-scenery-mobile/` (Codex; evidence only) |
| Prior slice lock | `remaining-commercial-gap.md` (placement; unchanged) |

Note on `--act`: the flag is 0-based. `--act=0` is Act I.

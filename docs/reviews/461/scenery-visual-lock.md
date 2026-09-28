# #461 — scenery visual lock (reading slice)

**Status: design lock only. Not implemented. #461 stays OPEN. Nothing here claims
commercial-grade.**

Owner signal (James, 17:22 BST 31 Aug 2026): *"scenery is black now; I see multiple
shadows instead of scenery."* Treated as a regression against #529.

This lock covers the slice that makes **already-placed scenery read as scenery**.
It does not add density, art, terrain, routes, waylights or camera work. The
placement slice locked in `remaining-commercial-gap.md` is unchanged and stays
landed.

---

## 1. Diagnosis

Three separate causes produce the owner's frame. Two are measured and settled;
the third is deliberately left open until the first two are cleared.

### Cause A — the candidate packet was rendered on a backend the game does not ship

`project.godot:54` sets `renderer/rendering_method="mobile"` (Forward Mobile).
That is what ships and what #529 was captured on (`docs/reviews/529/README.md`:
*"macOS Metal, Forward Mobile"*). The candidate packet's README says
*"macOS Metal, Compatibility"*.

Measured, same commit `c28ae388`, same seed 717, same act, same camera, only the
`--rendering-method` flag changed:

| | prop median | ground median | prop/ground |
| --- | ---: | ---: | ---: |
| `--rendering-method mobile` (ships) | 37.4 | 77.0 | **0.486** |
| `--rendering-method gl_compatibility` | 6.2 | 48.7 | **0.128** |

Whole-frame: median luminance 70.2 → 44.4; per-pixel delta median −23.0; open
ground cells −28; road and waystone cells −9 to −13; 88.8% of pixels move.

The two packets carry the same signature:

| Packet | prop median | ground median | prop/ground |
| --- | ---: | ---: | ---: |
| `docs/reviews/529/` Act I s717 rock | 37.7 | 95.9 | **0.393** |
| `docs/reviews/461-scenery/` Act I s717 monolith | 7.1 | 52.2 | **0.137** |

The candidate packet matches the GL Compatibility capture; #529 matches Forward
Mobile. Exhibits: `evidence/backend-ab-same-prop.png` (same rock, Mobile left,
Compatibility right — the facets survive on the left and collapse on the right),
`evidence/main-c28ae388-forward-mobile.png`,
`evidence/main-c28ae388-gl-compatibility.png`.

**A large share of "scenery is black now" is the capture backend, not the slice.**
Under the backend the game ships, the same geometry keeps its lit top face, mid
front face and dark side face.

Provenance note, separate from the pixels: the candidate manifest records
`capture_command: tools/capture_build4_map_corpus.sh --output docs/reviews/461-scenery`.
That script hard-codes `--rendering-method gl_compatibility`
(`tools/capture_build4_map_corpus.sh:206`) and refuses to run on a drifted tree;
96 production files differ between its `BUILD4_SOURCE_COMMIT` `52a56e72` and
`c28ae388`, so at that head it exits 2 and produces no frames. The manifest also
records `rendering_method: "mobile"`, but that field is a ProjectSettings echo
(`tools/capture_build4_map_corpus.gd:255-256`), not the runtime backend, so it
agrees with neither the README nor the pixels. **Trust the packet's pixels, not
its provenance rows.** The backend claim above rests on the measurement, which
stands regardless of which script actually ran.

### Cause B — the ground's contact shadows are painted at fixed positions and no longer match the compiled placements

This one is real, backend-independent, and is literally the "multiple shadows".

`assets/art/map/grades/act1-grade.png` alpha is a fixed constellation of **21 soft
round contact blobs** at authored world positions (`evidence/act1-grade-alpha.png`;
alpha min 102, 11.4% of texels below 220). Every act ships one: 21 / 22 / 18 / 20
blobs for Acts I–IV. `MapMaterials.bind_act` loads it and, when a painted grade
exists, **replaces** the procedural grade outright
(`presentation/map/map_materials.gd`, `if painted_grade != null: bind_region(...)`).

Meanwhile geometry is seated from `scenery_instances` by
`MapScene._place_scenery`, while the grade is still fed the old 25-seat deal:
`presentation/map/map_scene.gd:342` — `_materials.bind_act(region, _all_prop_positions())`.
The candidate's own comment at `map_scene.gd:818` states the dealt seats are no
longer where ordinary scenery goes.

So one frame carries two unrelated position sets. The visible result, already
present on `main` before this slice and visible in
`evidence/main-c28ae388-forward-mobile.png`: **ground ellipses in open ground with
no prop standing in them**, and props standing on ground with no contact blob.

This also removes the prop's own grounding term. `map_prop.gdshader` reads the
same alpha (`nl -= (1.0 - g.a) * contact`, `contact = 0.55`) and its header names
that darkening as *"the ONLY mechanism in the whole design that can see a
neighbour"* — the stand-in for the cast shadow this renderer does not have. Today
a prop is graded by whichever stranger's blob it happens to stand near, or by
none at all.

### Cause C — value gap and band count, left open on purpose

Even correctly rendered and correctly grounded, a prop sits at ~0.49 of ground
median luminance (`PROP_VALUE 0.100` vs `GROUND_VALUE 0.420`), and with
`bands = 3` most prop faces resolve into only two ramp steps. Whether that still
reads as a silhouette **after A and B are cleared is not yet known and must not be
guessed at.** Stage 3 below is conditional and requires a fresh measurement plus
the owner's eye before any uniform moves.

### Not implicated

The Vigil is not a contributor. In every frame under review the chapel measures
0.92 of ground median luminance; the prop shader would put it at ~0.49. Its baked
albedo bound correctly in these captures. Do not chase the
`"Vigil has no baked albedo"` warning as part of this slice.

Kit geometry is not implicated either: all eight Act I kits resolve
(`manifest.json` `active_asset_paths`), so `FlatWedges` / `StackedSlabs` /
`DabMasses` are hidden and are not what is on screen. The compiler's scale is
`helper.default_scale(profile)` times a bounded variation — no size blow-up.

---

## 2. Scope

### In scope

- `tools/capture_build4_map_corpus.sh` / `.gd` — capture on the shipping backend
  and record the **runtime** rendering method.
- `presentation/map/map_scene.gd` — feed the grade from compiled placements
  instead of `_all_prop_positions()`.
- `presentation/map/map_materials.gd` — composite the painted grade's RGB with a
  placement-derived alpha instead of replacing the procedural grade wholesale.
- `tests/test_map_scene.gd`, `tests/test_map_layout_scenery.gd` — the contract test
  for the above.
- Stage 3 only if Stage 2 fails its re-judge: `map_prop.gdshader` uniforms via
  `MapMaterials`, prop material only.

### Out of scope

`map_layout_compiler.gd` and `map_layout_compiler_routes.gd` (no placement,
density, count or zone change), routes, waylights, camera, ground/terrain art, new
or regenerated art assets, `port_fixtures/`, the four composition soft scores,
PathBand 2D overlay, P9/#108, Emberglass, balance.

**All five layout digests must come out byte-equal to the candidate's**
(`5a7d6a43…`, `9b182e7c…`, `6d5bd644…`, `54341c63…`, `a9951414…`). That is the
cheap proof this slice is presentation-only.

---

## 3. The change, staged with stop rules

Stop at the first stage that clears. Do not run a later stage speculatively.

### Stage 1 — capture on the shipping backend (blocking, no production code)

1. Capture the same 5 compiler inputs / 12 frames as #529 and `461-scenery`, on
   **Forward Mobile** (the `project.godot` default — do not pass
   `--rendering-method gl_compatibility`).
2. Record the **runtime** method: `RenderingServer.get_current_rendering_method()`,
   not `ProjectSettings.get_setting("rendering/renderer/rendering_method")`.
   Fail the capture if it does not equal the project's shipping method.
3. Record the real capture command and the real head. If
   `capture_build4_map_corpus.sh` cannot run at this head because of its build-4
   drift guard, say so in the packet and name the harness that did run. Do not
   record a command that did not execute.

**Stop rule:** publish the Mobile packet against `docs/reviews/529/` and re-judge.
If the owner reads the frames as scenery, the slice is done — do not touch a
shader.

### Stage 2 — ground each prop with its own contact shadow (only if Stage 1 does not clear)

The machinery already exists; nothing new is introduced.

- `MapMaterials._grade_image(region, positions)` already bakes exactly this alpha
  from a `PackedVector3Array`, and `grade_for()` is already public.
- Keep the painted grade's **RGB** (the corridor and aerial ramp — that is the
  art). Take the **alpha** from the compiled `scenery_instances` origins.
- Re-bake when placements land (`bind_layout` / `_place_scenery`), not only at
  `bind_act`, because at `bind_act` time the compiler has not run.
- Stop feeding `_all_prop_positions()` to the grade at `map_scene.gd:342`.

Known ceiling to note in the code: the bake is an O(W·H·N) CPU loop —
256 × 128 × ~21 ≈ 690k distance terms, once per layout bind, the same cost the
per-act bake already pays. Leave a `ponytail:`-style comment naming it; move it
off the CPU only if a bench says it matters.

**Stop rule:** recapture on Forward Mobile and re-judge. If the orphan ellipses are
gone and props read as grounded masses, stop.

### Stage 3 — conditional, requires evidence and an owner call

Only if Stages 1–2 are done, recaptured on Forward Mobile, and the frames still
read as silhouettes. Measure first, then propose **one** lever, prop material only:

- `bands` on the prop material (already a uniform; the shader header sanctions
  "3 or 4 in production"). Raising it splits the step that currently swallows both
  the top and the lit side face. Note that it breaks ground/prop banding parity —
  that is a design call, not a tuning job.
- `contact` on the prop material, or attenuating it by height so a prop's body is
  not dragged down the ramp by its own footprint at full strength.

`PROP_VALUE` / the anchor value gap is **#234's decision and is not in this slice.**
Do not move it here. Do not move `GROUND_VALUE`. Do not add an outline, a rim, or a
second prop material — `map_prop.gdshader`'s header already records those as
declined with reasons.

---

## 4. Pass / fail

Report every number at the exact final head, on the shipping backend.

| # | Check | Pass |
| --- | --- | --- |
| T1 | Packet manifest records the runtime rendering method, from `RenderingServer.get_current_rendering_method()` | equals the `project.godot` shipping method |
| T2 | Packet manifest records a capture command that actually ran at that head | true, and reproducible |
| T3 | All five layout digests vs the `461-scenery` packet | byte-equal |
| T4 | Unit test: grade alpha built for a placement set | minimum under each compiled placement XZ; ≈1.0 at ≥1.75 m from every placement; no minimum where there is no placement |
| T5 | Orphan contact ellipses in the Act I seed 717 opening frame | 0 — every ground ellipse has a prop standing in it |
| T6 | Prop / ground median luminance ratio, Act I seed 717, shipping backend | **reported, not graded.** Baselines: 0.486 (`main` Mobile), 0.393 (#529 packet), 0.137 (`461-scenery` packet). The owner's eye decides; do not invent a numeric bar and call it a pass |
| T7 | Visual inspection at the affected reference shapes (pad-landscape, phone-landscape; opening, focused, travel-midpoint) | performed on the running result, on the shipping backend, not from source or from numbers |

Capture matrix — identical to #529 and `461-scenery`: 5 compiler inputs
(Act I seeds 17634 and 717; Acts II, III, IV seed 717), 12 frames, locale `en`.
Publish before/after against `docs/reviews/529/` **and** against
`docs/reviews/461-scenery/`, so the backend correction is visible as its own step.

Core gate, on the coherent final candidate before the first push:

```bash
godot --version
tools/check_imports.sh
tools/check_scripts.sh
godot --headless -s res://tests/run_all.gd
```

Stage every new `.gd` first — the sweep uses `git ls-files`. Never grade
`godot --check-only` by exit status. If you took screenshots before running the
suite, clear the run save first, or you will collect failures with no cause in the
diff.

### Hard-constraint invariants — must stay green, unchanged

| Metric | Required |
| --- | --- |
| `edge_scenery_corridor_penetration_m` | `== 0.0` |
| `node_scenery_silhouette_overlap_area_px2` | `== 0.0` |
| `node_touch_scenery_silhouette_overlap_area_px2` | `== 0.0` |
| `vigil_protected_zone_intrusion_count` | `== 0` |
| `terminus_protected_zone_intrusion_count` | `== 0` |

Occupancy stays inside the locked 14–24 band. This slice changes no placement, so
all of the above should be unchanged rather than merely still passing — show that.

---

## 5. Do not

- Do not add scenery density, raise the instance count, or touch
  `SCENERY_MIN_INSTANCES` / `SCENERY_MAX_INSTANCES` / zone caps.
- Do not commission or regenerate art. Cause C is unproven; new kits are not the
  answer to a backend mismatch.
- Do not touch ground or terrain art, routes, waylights, or the camera unless a
  measurement shows the visual cannot be proven without it — and say so first.
- Do not reopen the PathBand 2D overlay.
- Do not touch P9 / #108 (frozen) or Emberglass (sealed). No balance work.
- Do not move `PROP_VALUE`, `GROUND_VALUE`, or the anchor value gap in this slice.
- Do not regenerate `port_fixtures/`.
- Do not close #461. Do not claim commercial-grade. Do not merge on your own
  reading of the frames — the owner's eye is the gate for T6 and T7.
- Do not record a capture command, head, or renderer that did not run. That is
  what produced this round trip.

---

## 6. Provenance of this lock

| Item | Value |
| --- | --- |
| Author | Claude (design only; no production code changed) |
| Date | 2026-08-31 |
| Base | `origin/main` `c28ae388` (fetched; worktree is 0 behind) |
| Candidate under review | `/Users/jamesto/Research/glassvow-461-scenery`, branch `jamesto/issue-461-scenery-compiler`, working tree on `c28ae388` |
| A/B captures | `godot --path . --rendering-method {mobile,gl_compatibility} -- --map --seed=717 --act=0 --settle=1 --shot=…` at `c28ae388`, Godot 4.7.2.stable.official.ed1daf0bf, macOS |
| Exhibits | `evidence/` beside this file |
| Prior slice lock | `remaining-commercial-gap.md` (placement; unchanged) |

Note on `--act`: the flag is 0-based. `--act=0` is Act I.

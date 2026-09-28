# #461 — remaining commercial-grade gap and the next implementation slice

Design review only. Nothing in this document is implemented. It names one
slice, not a programme.

| Item | Value |
| --- | --- |
| Reviewed head | `c28ae38824f7ba2168b573002ab8b90dadd5bde1` (main after #475/#528 and #529/#530) |
| Godot | `4.7.2.stable.official.ed1daf0bf` |
| Evidence read | `docs/reviews/475/`, `docs/reviews/529/`, issue #461 body, comments 5469726013 and 5470834707 |
| Evidence measured | Live `bind_layout` scenery accounting, headless, pad-landscape, this head |
| Verdict | **Engineering delta confirmed. Does not fail closed.** |

## 1. Fail-closed test, applied first

The instruction is to fail closed if the only remaining gap is owner-eye
sign-off with no engineering delta.

It does not fail closed. The gap is a measured generator defect with a number,
reproducible headlessly, independent of taste: **generated acts publish 2–4
scenery instances out of a 25-candidate pool. 84–92% of the world's dressing is
deleted at bind time.** The authored act, on the same code path, publishes 21.

An owner looking at `docs/reviews/529/act-01-seed-717-after.jpg` is not being
asked for a preference. He is looking at an empty world, and the emptiness is
computed, not chosen.

## 2. What is already true, and must not be reopened

Verified at this head, not assumed:

- **The 2D `PathBand` route graph is genuinely retired.** `presentation/map/map_band.gd`
  has no `_draw_graph`; `tests/test_map_compose.gd:368-370` asserts that
  `_path_band` has no `_draw_graph` method and the screen exposes no
  `edge_control` route authority. Route topology is world-space and
  depth-tested. **Do not reopen this.**
- **Nodes and routes are compiler-owned.** `MapLayoutCompiler.compile` emits
  `node_anchors`, `edges` with routed centerlines and corridor widths, and
  `hero_placements`. The renderer consumes them and no longer re-derives them.
- **The cold/open/walked hierarchy exists and reads.** #529 separated the cold
  waylight from the road surface. Visible in all three contact sheets.
- **The hard-constraint evaluator is real.** `MapQualityEvaluator` implements
  all 18 `hard` ids from `docs/map/map-quality-v2.json`, including
  `edge_scenery_corridor_penetration_m` and `node_scenery_silhouette_overlap_area_px2`.

Owner findings from the #461 body that these already answer: the 2D overlay,
and the faint dotted state line. The remaining findings — *scenery consumes the
route*, *waystones repaired weakly*, *looks procedurally assembled* — all
reduce to the single defect in §3.

## 3. The defect

`MapLayoutCompiler` never places scenery. `presentation/map/map_layout_compiler.gd:1071`
hardcodes:

```gdscript
"scenery_instances": {},
```

Scenery is still the pre-#526 scatter: `_dealt_seats()` deals 25 seats from
family RNG streams and `_separate()` relaxes them along X only
(`presentation/map/map_scene.gd:1227`, `:1273`, `:1294`). Those seats are dealt
**before** anything knows where the routes went.

`MapScene.bind_layout()` then does the only thing it can. Its own comment,
`presentation/map/map_scene.gd:910-911`, states the architecture plainly:

> The existing dealt seats remain the only candidate pool; this pass can only
> remove unsafe instances.

So the compiled route arrives, and every seat that fouls it is **deleted**.
Composition is achieved by subtraction from a pool that was never route-aware.
There is no second chance, no relocation, and no resampling.

Two further consequences, both load-bearing:

- **The semantic-zone contract is stubbed.** `presentation/map/map_scene.gd:676`
  tags every candidate `"semantic_zone": "existing-seat"`.
  `docs/map/map-quality-v2.json` already authors five real zones — `hero`,
  `foreground-frame`, `road-bank`, `midground`, `vista` — each with an
  `occupancy_ratio` band. Nothing reads them.
- **The compiler cannot rank by composition.** `MapQualityEvaluator` implements
  2 of the 12 authored `soft` scores — `route_length_ratio` and
  `bend_angle_deg_per_edge` (`presentation/map/map_quality_evaluator.gd:611-612`).
  `zone_density_error_ratio`, `negative_space_error_ratio`,
  `asset_family_diversity_ratio` and `asset_repetition_distance_m` are absent.
  The selection function contains no composition term at all, which is
  precisely why the result "looks procedurally assembled rather than
  deliberately composed" — nothing in the code has an opinion about composition.

### Measurement

Headless, this head, pad-landscape, live `bind_layout` diagnostics
(`candidate_count` / `accepted_count` / `rejected_count` and rejection reasons):

| Act | Seed | Candidates | Published | Rejected | Rejection reasons |
| --- | --- | --- | --- | --- | --- |
| I (generated) | 717 | 25 | **2** | 23 | road/waylight corridor 11, node reserve 12 |
| I (generated) | 17634 | 25 | **4** | 21 | node reserve 11, corridor 8, peer footprint 2 |
| II (generated) | 717 | 25 | **2** | 23 | corridor 13, node reserve 10 |
| III (generated) | 717 | 25 | **2** | 23 | corridor 9, node reserve 13, peer 1 |
| IV (authored) | 717 | 25 | **21** | 4 | peer footprint 4 |

Act IV is the control. Same renderer, same predicate, same asset pool — but its
route is authored and short, so the scatter rarely fouls it and the world stays
furnished. That is the visible difference between the dense Act IV strip and the
empty Acts I–III in `docs/reviews/529/acts-02-04-seed-717-after.jpg`.

This also settles the asset question #461 asked to defer. The library is not the
bottleneck: the same library furnishes Act IV. **No new art is justified by this
evidence.**

### Reproduce

The measurement used a throwaway probe, deliberately not committed. To repeat
it, place this at `tools/probe_461_scenery.gd`, run it, then delete it:

```gdscript
extends SceneTree
const SEEDS: Array[int] = [717, 17634]

func _initialize() -> void:
	var content: ContentDB = ContentDB.load_full()
	for act: int in [0, 1, 2, 3]:
		for s: int in SEEDS:
			var run: RunState = RunState.new_run(content, s, "probe-461")
			run.act = act
			var screen: WorldMapScreen = WorldMapScreen.new(
				WorldMap.for_run(run, content), content)
			root.add_child(screen)
			screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
			screen.size = Vector2(StageShape.REFERENCES[&"pad-landscape"])
			screen.set_shape(&"pad-landscape")
			var scene: MapScene = screen._map_scene
			if scene != null:
				scene.size = screen.size
				scene._fit()
			screen.set_act_scenery(act)
			screen.refresh(run)
			var live: Dictionary = screen.layout_diagnostics().get("live_binding", {})
			var reasons: Dictionary = {}
			for r: Dictionary in live.get("rejections", []):
				var k: String = str(r.get("reason", "?"))
				reasons[k] = MapLayoutCanonical.int_value(reasons.get(k, 0)) + 1
			print("act=%d seed=%-6d candidates=%s published=%s rejected=%s %s" % [
				act + 1, s, str(live.get("candidate_count", "-")),
				str(live.get("accepted_count", "-")),
				str(live.get("rejected_count", "-")), str(reasons)])
			root.remove_child(screen)
			screen.free()
	quit(0)
```

```bash
tools/check_imports.sh                                   # fresh worktree only
godot --headless -s res://tools/probe_461_scenery.gd
```

A fresh worktree must be imported first; a bare headless run hangs silently
otherwise.

## 4. The slice

**Move scenery placement into the compiler, after routes, and generate
candidates in free space instead of filtering a pre-route scatter.**

One slice. It does not touch routing, waylights, node selection, the camera, the
save schema, or the asset library.

Everything expensive already exists and is reused, not rewritten:

| Already in the tree | Reuse as |
| --- | --- |
| `MapScene._scenery_rejection()` (`map_scene.gd:1009`) | The placement predicate, unchanged. It already covers node reserve, road/waylight corridor, hero protected zones and peer footprints. |
| `MapScene._placement_footprint()` (`map_scene.gd:682`) | Footprint transform, unchanged. |
| `MapLayoutResult` scenery schema (`domain/map_layout/map_layout_result.gd:168-186`) | Already validates `asset_id`, `profile_id`, `transform`, and a non-empty `semantic_zone`. No schema change. |
| `docs/map/map-quality-v2.json` `zones[]` | The five zone ids and their `occupancy_ratio` bands. Already authored. Do not invent new ones. |
| `assets` bundle passed to `compile()` (`world_map_screen.gd:429`, `map_scene.layout_asset_bundle()`) | The compiler already holds the profile/footprint authority. No new plumbing. |

### Changes

1. **`presentation/map/map_layout_compiler.gd`** — add a scenery step after
   routes and heroes are fixed, and fill the hole at line 1071. The compiler
   already holds every input it needs: `quality` (zone bands, clearances),
   `assets` (profiles and footprints), the chosen anchors, the routed edges and
   the hero contract.

2. **Candidate supply** — replace "25 seats dealt before routing" with
   deterministic sampling of the governed area *after* routing. Derive the five
   zone masks geometrically from what the compiler already has, rather than
   authoring new region data:
   - `hero` — the existing hero protected zones;
   - `road-bank` — the annulus outside each edge's reserve, out to a bounded
     distance;
   - `foreground-frame` — the camera-near band at the frame edge, from the
     shipping camera profiles already in `quality`;
   - `vista` — beyond the last row envelope;
   - `midground` — the governed remainder.
   Sample per zone until its realized footprint occupancy enters the contract's
   `occupancy_ratio` band, or a bounded attempt budget is spent. Tag each
   placement with its real zone id.

3. **Predicate placement, not deletion** — run `_scenery_rejection` at
   *sample* time so a fouling sample is resampled rather than published-then-
   deleted. The predicate stays zero-tolerance; only the moment it is applied
   changes.

4. **`presentation/map/map_scene.gd`** — net deletion. `bind_layout()` renders
   `compiled.scenery_instances` directly; `_scenery_candidates()` (`:651-680`)
   and its `_all_prop_positions()` dependency for scenery go away. Keep
   `_dealt_seats()` / `SEAT_GAP` — the road wedge and slab kits still index off
   them (`tests/test_map_scene.gd:279-295`), and that is not this slice.

5. **Determinism** — sampling is seeded from the existing layout input digest
   and generator version, and `scenery_instances` enters the layout digest.
   Same inputs must still produce a byte-equal result.

### Explicitly out of this slice

State these as follow-ups; do not widen into them.

- The four composition **soft scores** (`zone_density_error_ratio`,
  `negative_space_error_ratio`, `asset_family_diversity_ratio`,
  `asset_repetition_distance_m`) and restart ranking by composition. This slice
  uses the occupancy bands as a *sampler stopping rule*, not as a *ranking
  term*.
- Any new art asset. §3 shows the library is not the constraint.
- Ground plane, terrain or region masses. The frames read as props on a
  gradient with no ground, which is a real finding — but #461 binds the order:
  fix the generator, measure, and only then justify assets. That order is not
  discretionary here.
- Route shape, branch fan-out, waylight appearance, camera.

## 5. Pass/fail test for Codex

Every check is deterministic and headless. Checks 1–4 are **red at
`c28ae38`** — if any is green before the change, the slice is misaimed and
Codex must stop and report rather than proceed.

Corpus: generated acts I, II, III at seeds 717 and 17634; authored act IV at
717; pad-landscape, phone-landscape and desktop-landscape.

| # | Check | Pass condition | Today |
| --- | --- | --- | --- |
| 1 | **Compiler owns scenery** | `MapLayoutCompiler.compile(...).scenery_instances` is non-empty for every corpus entry, before any renderer pass | RED — hardcoded `{}` |
| 2 | **Density floor** | Every generated act publishes **≥ 14** scenery instances at every corpus seed | RED — 2–4 |
| 3 | **Clutter ceiling** | Every act publishes **≤ 24** instances, and no single `semantic_zone` holds more than 60% of them | RED — vacuously; one zone holds 100% |
| 4 | **Real zones** | Every published `semantic_zone` is one of the five ids in `docs/map/map-quality-v2.json` `zones[]`. The literal `existing-seat` appears nowhere in the tree, and **≥ 3** distinct zones appear per generated act | RED — single literal `existing-seat` |
| 5 | **Hard constraints hold** | Across the corpus and all three shapes: `edge_scenery_corridor_penetration_m == 0.0`, `node_scenery_silhouette_overlap_area_px2 == 0.0`, `node_touch_scenery_silhouette_overlap_area_px2 == 0.0`, and every hero protected-zone intrusion count `== 0` | GREEN — **must stay green** |
| 6 | **Determinism** | Two separate processes compiling the same input produce identical `layout_digest`, identical `scenery_instances` key order and identical transforms | GREEN — **must stay green** |
| 7 | **No renderer authority** | `MapScene` has no `_scenery_candidates`; `bind_layout` contains no scenery rejection loop; no test asserts a renderer-side scenery candidate pool | RED |

Checks 1–4 and 7 belong in a new `tests/test_map_layout_scenery.gd` registered
in `tests/run_all.gd`. Checks 5–6 extend the existing assertions in
`tests/test_map_scene.gd:403-436` and `tests/test_map_layout_compiler.gd`.

The floor of 14 and the ceiling of 24 are anchored to the measured authored
control: Act IV publishes 21 and reads as a furnished world, generated acts
publish 2–4 and read as empty. 14 is below the control so it cannot force
clutter, and unreachable by the current subtractive pass so it cannot pass by
accident. **Do not move these thresholds to make an implementation pass** —
#461 forbids weakening an acceptance threshold because the implementation
fails.

### Gate

```bash
godot --version
tools/check_imports.sh
tools/check_scripts.sh
godot --headless -s res://tests/run_all.gd
```

Stage new `.gd` files before running the script sweep; it uses `git ls-files`.

### Owner-eye evidence

Deterministic gates do not settle a composition change. Repeat the #529 capture
matrix exactly — read `docs/reviews/529/manifest.json` for the five compiler
inputs, three shapes, zoom stops and poses — via
`tools/capture_build4_map_corpus.sh`, and publish a before/after packet under
`docs/reviews/<slice-issue>/` in the shape of `docs/reviews/529/README.md`.

The before/after must show the same seeds and poses. Expect the layout digest
to change: scenery now enters layout identity. That is intended, and any
affected `port_fixtures/` golden must be updated in an explicit commit that
says why, per the port-owned goldens rule.

## 6. Risk

- **Generation time.** Rejection sampling with an attempt budget replaces a
  fixed 25-seat deal. Bound the attempt budget and keep the existing cache
  keyed by graph hash, act, seed, generator version and asset digest. Capture
  compile wall-clock in the packet.
- **Occupancy versus footprint.** The contract's `occupancy_ratio` is an area
  ratio. Compute realized occupancy from actual transformed footprints, not
  instance counts, or the bands will not mean what they say.
- **Act IV.** The authored act already publishes 21 and looks correct. It must
  not regress; keep it in the corpus specifically as the control.
- **Scope creep into scoring.** The pull toward implementing the four soft
  scores while in this code is strong. It is a separate slice.

## 7. Status

#461 stays open. No commercial-grade claim is made or implied by this document.
No implementation, no branch, no PR, no Codex run has been started.

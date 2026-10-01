# Production map layout

Status: **production since 2026-09-30**. Owner decision: production must not depend on Map Compiler v2.

Code: [`MapLayoutPolicy`](../../presentation/map/map_layout_policy.gd) chooses the generator, and [`MapLayoutFast`](../../presentation/map/map_layout_fast.gd) is the production generator. It delegates to [`MapLayoutFastSeating`](../../presentation/map/map_layout_fast_seating.gd) (where each waystone stands), [`MapLayoutFastRoads`](../../presentation/map/map_layout_fast_roads.gd) (each road) and [`MapLayoutFastBridges`](../../presentation/map/map_layout_fast_bridges.gd) (where two roads cross); [`MapRavine`](../../presentation/map/map_ravine.gd) holds the ravine's geometry for both the layout and the landscape.
Proof: [`tests/test_map_layout_fast.gd`](../../tests/test_map_layout_fast.gd) and [`tools/probe_map_fast_layout.gd`](../../tools/probe_map_fast_layout.gd).
Captures: [`docs/reviews/map-fast-layout-2026-09-30/`](../reviews/map-fast-layout-2026-09-30/) and, for the polish of #621, [`docs/reviews/map-polish-2026-10-01/`](../reviews/map-polish-2026-10-01/).

## Why the compiler is opt-in

Map Compiler v2 (#526, #527) is a bounded constraint solver over the governed quality contract ([`map-quality-v2.md`](map-quality-v2.md)). On the M1 Max debug VM, one Act I compile takes 160–300 s and peaks at 1.5–2 GB RSS. Three of five Act I seeds tried on 2026-09-30 (1, 42 and 543001) end in `NO_FEASIBLE_NODE_ROUTE_LAYOUT`, which leaves those runs with no map. On the iPad 8 (A12, 3 GB), TestFlight build 8 was killed by the launch watchdog inside this compile. Moving it to a worker thread behind the charting veil (#614) removes the kill, but the player would then wait minutes, and a seed the compiler cannot solve would still have no map.

The compiler is therefore an authoring tool. It never runs on the player's path, and it cannot run at all on a mobile build.

## What the fast layout guarantees

`MapLayoutFast.compile(input, quality, assets)` returns the compiler's packet shape and a `MapLayoutResult` that satisfies the same identity contract (`generator_version = map-layout-fast-v1`). `WorldMapScreen`, `MapScene`, the waylights, the camera resolver and the quality registry consume it unchanged.

- **Complete.** Every node and edge of the canonical live input has an anchor and a routed centreline, and every centreline starts and ends exactly on its anchors. A valid input has no failure path.
- **Bounded and fast.** There is no search: a fixed number of lane sweeps per row, a fixed 7×7 grid for a node moved off a landmark, and one bounding-box-filtered crossing test per pair of roads leaving the same row. Measured on the M1 Max for seeds 1, 42, 717, 17634 and 543001 in Acts I–IV, generation took 27–31 ms for Acts I–III and about 2 ms for Act IV; after the polish of #621 it takes 43–44 ms for Acts I–III (the minimum of nine runs of a debug build, headless, against 30–32 ms for the build before, on the same machine) and the same 2 ms for Act IV. The probe fails above 200 ms.
- **Deterministic.** The result is a pure function of the canonical input: nodes, edges, act, run and scenery seeds, and the asset, camera, hero and quality identities. The geometry uses only IEEE arithmetic and square roots, never a transcendental function, and the two derived constants are literals held to the registry by the test. Two processes print identical digests for all 20 probe cases, and the test compares the geometry against digests recorded in another process.
- **Playable.** Each node stands on its authored lattice seat (row, column and the run's own jitter) inside its governed row and lane envelope, and in journey order. A node that would stand in a hero's protected zone, behind the silhouette of the Vigil or the gate, or in a ravine where the landscape would hold its waystone on a pier, steps to the nearest open point of a 7×7 grid over its envelope. Then every pair of waystones in the same or adjacent rows is pushed apart, inside both envelopes, until their inks keep the governed clearance and their hit regions do not overlap at the farthest zoom stop (28 m) on the phone, the tightest the map is drawn (390 px / 28 m = 13.93 px per metre along the journey and 8.95 across it). A pair that a ravine's banks leave on top of each other may then use the ravine too: a waystone on a pier reads better than two on one another. Every node has a safe focused camera pose at every shipping shape, and every reachable waystone is tappable where it projects.
- **Readable roads.** Each edge is a cubic whose end tangents bisect the chord and the journey axis, so roads fanning into one node meet only at its seal. Roads leaving one node that would read as one at the branch sample distance (4 m) on the phone at the farthest zoom lean towards their chords until they part by 33 px. A road that passes within its corridor (1.6 m) of a waystone it does not serve, or within 2.5 m of another road it does not cross, is bumped away over a few points. Where two roads between the same two rows cross, the one bound for a lower lane rises over the other, and the lower is routed through the middle of the upper and then moved once to the middle of the room the deck leaves. The upper takes the governed span (`MapGradeSeparation.span_option`): level with its nodes at both ends, a 1.09 m ramp (grade 0.353) up short of the whole 2.5 m corridor overlap, the 0.384 m deck across it, and a ramp down past it. The renderer draws bridge masonry wherever a road stands above 0.15 m, so a crossing reads as a bridge, not as a junction where the player could turn. A crossing whose upper road is too short for two ramps and the overlap (a perpendicular crossing needs 7.2 m of road, a slanted one more) gets a plain 0.45 m deck instead, which still reads as a bridge but does not meet the governed clearance.

Scenery, the Vigil and the gate are placed exactly as before: `MapScene.bind_layout` filters the seeded scenery candidates against node reserves, road corridors and hero zones. That filter now skips each exact polygon test when the two bounding boxes are already too far apart for it to fire. The accepted set is unchanged: all 20 probe layouts have the same digest with and without the skip, and 2,908 candidates compared rule by rule gave zero mismatches. Binding now takes about 175 ms instead of about 2 s.

## Opening the map

Every return to the map (after a fight, event, shop or rest) builds a fresh `WorldMapScreen`. What it builds from is kept for the act instead of being made again (#621):

- **The act's catalogue.** `MapLandscapeAssets.for_act` decodes the act's artwork once and keeps that one catalogue until another act is asked for, so the previous act's artwork is released on an act change. The screen binds its opening act first, so it no longer decodes Act I's artwork and then the act it shows.
- **The canonical input.** `WorldMapScreen` keeps the last `MapLayoutInput` it built and what it was built from; pricing the camera poses for every shape is most of what the input costs. `Main` already kept the generated layout for that input.
- **The binding.** `MapScene` keeps the last scenery binding and the landscape geometry it generated (ground, strata, ledges and road meshes), keyed by the layout digest, the catalogue digest and the salt, with the quality registry compared in full.

Everything kept is shared by later screens and never edited. A fresh bind and a kept one draw the same frame: pad captures of seeds 1 and 717 in Acts I and II are pixel-identical to the build before, and so is a reopened map (`tests/test_map_open_cache.gd` checks the same at the node level).

The road's bridge masonry used to append a box mesh by `SurfaceTool.append_from`, which reads the box back from the renderer on every call, a GPU stall each time. It now reads the box once (`MapLandscape.HeldSurface`); the road meshes are identical and take about 25 ms instead of about 0.4 s.

Measured on the M1 Max with a real renderer (debug, pad shape, `--map --map-timing`, seeds 1 and 717), from the `_show_map` call to a bound map: the first open of an act takes about 0.62 s in Act I and 0.48–0.50 s in Act II (it was 1.2–1.4 s and 1.1 s), and every later open of that act takes 47–54 ms (it was 1.1–1.2 s). Timed by phase while this was built (a temporary clock, since removed), about 0.18–0.28 s of a first open is decoding the catalogue (almost all of it the lossless texture loads), about 0.13–0.17 s is the scenery filter, about 30 ms is layout generation and another 30 ms is the camera registry. Keeping the act costs video memory while another screen is up: 60 MB for Act I and 44 MB for Act II, measured; `tools/probe_map_seeds.gd` counts the catalogue's mipmapped textures at 50, 35, 19 and 43 MiB for Acts I–IV. The A12 has not been measured.

## What it does not guarantee

Measured against the governed hard rules with `tools/preview_map.gd --compile-only --quality=…` (Act I, seeds 1, 717 and 17634), the fast layout keeps journey order, the row and lane envelopes, both protected zones, the node, scenery and hero silhouette rules, the touch-target minimum, the focused safe frame and, since #621, node spacing at every zoom, the road corridor around every waystone and the road corridors between every pair of roads that do not cross. Distinct violations before and after the polish of #621 (the same seeds and rules; [`docs/reviews/map-polish-2026-10-01/`](../reviews/map-polish-2026-10-01/) has the captures):

| Rule | Seed 1 | Seed 717 | Seed 17634 |
|---|---|---|---|
| Waystone ink clearance, farthest zoom, phone | 29 → 0 | 23 → 0 | 28 → 0 |
| Waystone ink overlap, farthest zoom, phone | 17 → 0 | 15 → 0 | 14 → 0 |
| Waystone hit-region overlap, farthest zoom, phone | 22 → 0 | 16 → 0 | 18 → 0 |
| Road within its corridor of a waystone it does not serve | 7 → 0 | 7 → 0 | 6 → 0 |
| Pairs of roads in conflict (crossing without clearance, or close without crossing) | 13 → 1 | 11 → 1 | 8 → 1 |
| Branch fan-out under 32 px | 6 → 0 | 4 → 1 | 3 → 0 |

It still does not pass the whole contract, and never claims to:

- **Short crossings.** One crossing per map (Act I, seeds 1, 717 and 17634; the other two probe seeds have none or one) lacks the governed 0.384 m clearance: its upper road is a ravine row's, where the banks have drawn the waystones together and left 7.2–7.4 m of road for two ramps and a 5 m overlap. It carries the plain deck.
- **Ravine piers.** The lattice puts seven to eleven waystones a map in a ravine. The guard leaves one to four, where a pair of waystones would otherwise stand on each other (`tests/test_map_layout_fast.gd` allows four) or where no point of a node's envelope is open.
- **Branch fan-out.** Seed 717 has one pair of roads leaving a node that stand 30.4 px apart at the farthest zoom: their chords are too close for any lean to part them further.
- **Price tags.** A shop's price tag stands to the right of its waystone and is no part of the governed spacing. At the farthest zoom on the phone a tag can touch the next waystone along the journey (seed 17634, the shop beside the boss).

The compiler's search exists to remove these. If a later release needs them removed on device, the options are to precompute layouts offline, or to make the compiler fast enough for mobile. Re-enabling the solver on the player's path is not one of them.

## Turning the compiler on for authoring

The compiler runs only on a desktop build, and only when asked:

```bash
# One boot or tool run
tools/shot.sh --map --map-compiler --shot=/tmp/map.png
godot --headless -s res://tools/preview_map.gd -- --act-index=0 --seed=717 \
  --map-compiler --compile-only --quality=/tmp/map-quality.json
```

To keep it on for an editor session, set the project setting `glassvow/map/layout_compiler = true` in a local `override.cfg`. Never commit that setting to `project.godot`. `OS.has_feature("mobile")` forces the fast layout whatever the flag or setting says.

The generator is written into the canonical input (`generator_schema`, `generator_version`), so a compiled layout and a fast layout never share an input digest or a cache entry. On a boot without arguments, the #614 worker job and the **CHARTING THE ROAD** veil still carry the opt-in compile. A boot with arguments compiles synchronously, as before. `tests/test_map_layout_compiler.gd` still exercises the compiler, and nothing on the production path depends on it.

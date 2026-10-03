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

**Act I is drawn as the journey land (3 Oct 2026).** `MapScene` binds `MapJourneyLandscape` for Act I: the September journey rebuild's woodland, revived on this layout ([revival](../design/2026-10-02-map-living-land/revival.md)). It reads the record and changes nothing in it: the same input, layout and scenery digests bind, and the painted landscape still draws Acts II–IV. The land builds on the worker pool behind the charting veil (Main prefetches it when it routes a run into Act I), its water runs in `MapRavine`'s ravines, and its camera is the rebuild's 55° Journey / Whole act framing (`MapJourneyView`), with the governed 40° rig restored outside Act I. `tests/test_map_journey.gd` holds its contract.

Scenery, the Vigil and the gate are placed exactly as before: `MapScene.bind_layout` filters the seeded scenery candidates against node reserves, road corridors and hero zones. That filter now skips each exact polygon test when the two bounding boxes are already too far apart for it to fire. The accepted set is unchanged: all 20 probe layouts have the same digest with and without the skip, and 2,908 candidates compared rule by rule gave zero mismatches. Binding now takes about 175 ms instead of about 2 s.

## Opening the map

The first open of an act builds a `WorldMapScreen`; every return to the map within the act (after a fight, event, shop or rest) re-attaches that same screen (see [Keeping the screen](#keeping-the-screen)). What a screen is built from is kept for the act instead of being made again (#621):

- **The act's catalogue.** `MapLandscapeAssets.for_act` decodes the act's artwork once and keeps that one catalogue until another act is asked for, so the previous act's artwork is released on an act change. The screen binds its opening act first, so it no longer decodes Act I's artwork and then the act it shows.
- **The canonical input.** `WorldMapScreen` keeps the last `MapLayoutInput` it built and what it was built from; pricing the camera poses for every shape is most of what the input costs. `Main` already kept the generated layout for that input.
- **The binding.** `MapScene` keeps the last scenery binding and the landscape geometry it generated (ground, strata, ledges and road meshes), keyed by the layout digest, the catalogue digest and the salt, with the quality registry compared in full.

Everything kept is shared by later screens and never edited. A fresh bind and a kept one draw the same frame: pad captures of seeds 1 and 717 in Acts I and II are pixel-identical to the build before, and so is a reopened map (`tests/test_map_open_cache.gd` checks the same at the node level).

The road's bridge masonry used to append a box mesh by `SurfaceTool.append_from`, which reads the box back from the renderer on every call, a GPU stall each time. It now reads the box once (`MapLandscape.HeldSurface`); the road meshes are identical and take about 25 ms instead of about 0.4 s.

Measured on the M1 Max with a real renderer (debug, pad shape, `--map --map-timing`, seeds 1 and 717), from the `_show_map` call to a bound map: the first open of an act takes about 0.62 s in Act I and 0.48–0.50 s in Act II (it was 1.2–1.4 s and 1.1 s), and every later open of that act takes 47–54 ms (it was 1.1–1.2 s). Timed by phase while this was built (a temporary clock, since removed), about 0.18–0.28 s of a first open is decoding the catalogue (almost all of it the lossless texture loads), about 0.13–0.17 s is the scenery filter, about 30 ms is layout generation and another 30 ms is the camera registry. Keeping the act costs video memory while another screen is up: 60 MB for Act I and 44 MB for Act II, measured; `tools/probe_map_seeds.gd` counts the catalogue's mipmapped textures at 50, 35, 19 and 43 MiB for Acts I–IV. The A12 has not been measured.

### Warming the act ahead

The first open of an act no longer has to decode its artwork on the main thread. `MapLandscapeAssets.prefetch` decodes the act's pictures on a low-priority `WorkerThreadPool` task, and `Main` asks for it whenever it routes a run (`_warm_map_landscape`): a new or resumed run warms the act it stands in, and a run standing on the boss of an act that is not the last warms the next act, so the boss reward and crown relic screens cover the decode. `for_act` stays the one entry. It takes a finished warm-up as it is; when the map opens before the worker is done, the pictures the worker has not reached are decoded at once, side by side on high-priority pool threads while the main thread waits, and only the picture the worker is on is waited for. Each picture is claimed once, so nothing is decoded twice, and a warm-up of another act is stopped and never waited for. Warming an act releases the kept one, so one act's artwork is still held at a time.

The worker cannot read a texture back from the renderer: that call queues on the main thread, which may itself be waiting for the worker. The landscape pictures are therefore imported as `Image` resources rather than lossless textures, and `MapLandscapeAssets._picture` applies the edge bleed the texture importer applied (`Image.fix_alpha_edges`, after the crop, which gives the same texels). Every texture of Acts I–IV is byte-identical to the texture-import pipeline's (size, format, mipmaps and pixels; `tests/test_map_landscape_prefetch.gd` pins Act I's), the catalogue digests are unchanged, and pad captures of Acts I and II differ from the build before only in the live waystones' animated halo, as two captures of the same build do. Textures are created on the thread that decodes them, one upload at a time: the RenderingDevice keeps a staging buffer for every upload it has run side by side.

Measured on the M1 Max with a real renderer (debug, pad shape, `--map --map-timing --seed=1`, three interleaved runs each of this build and the one before, while other work held the load average near 270, so the absolute figures run high), the medians from the call to a bound map were:

| Act | Before: cold | Cold | Early (resume) | Warmed | Reopen |
|---|---|---|---|---|---|
| I | 685 ms | 357 ms | 401 ms | 301 ms | 47 ms |
| II | 653 ms | 457 ms | 431 ms | 339 ms | 52 ms |

The warm-up itself took 0.50 s (Act I) and 0.35 s (Act II) on its worker, and the longest frame while it ran was 13–15 ms, against 11–16 ms over as many idle frames just before it. The catalogue's textures hold the same video memory on both builds (57.6 MiB for Act I, measured around `MapLandscapeAssets.new`). The bench's `MAP_KEPT` row reads 43.9 MiB for Act II, as before, and 61.2 MiB for Act I against 61.0 MiB; that 0.2 MiB lies outside the catalogue, stays when the new pipeline runs serially on the main thread with no warm-up, and was not traced further.

What remained of a warmed open was the screen itself: building `WorldMapScreen` (about 30–75 ms), generating the layout (about 30 ms), and the canonical input, camera registry, scenery filter and landscape geometry (about 300 ms, in one call) while the machine was loaded. Each of these runs as one indivisible step longer than a 16 ms frame, so none of them can be prepared ahead in idle frames on the main thread without a visible hitch, and this change does not try. Moving the layout and scenery filter of the next act onto a worker is the next step if the A12 needs it.

### Keeping the screen

A return to the map within an act no longer builds a screen. When the route leaves the map, `Main._clear_route` hands the screen to a [`MapScreenKeep`](../../presentation/map/map_screen_keep.gd), which takes it off the tree and holds it with what it was built for: the map, the run, the act, the shape and the language. The next `_show_map` with the same identity re-attaches it and calls `WorldMapScreen.reopen`, which applies only what a run changes within an act:

- each waystone whose node changed face (an unlit node the player has since visited, its bounty paid) is rebuilt, and every other waystone is kept;
- the live, cleared and current waystones, the lit roads, the instruction, the camera's seat on the current node and the sealed door are set as `refresh` sets them;
- whatever a fresh screen starts with is restored: no scripted walk, the default zoom, the pointer drift at rest, and the instruction undecided until the hint guide looks again, so the map-select hint, the selection bracket and keyboard focus behave as on a fresh screen.

The layout, the scenery, the landscape and the title stand, because the identity guarantees they would bind the same. The run HUD is still built per open, as on every other routed screen. A screen is kept only when its layout is bound and no walk is under way, so the charting veil of an opt-in compile never keeps one.

Anything else frees it. Another map (an act change, a new or resumed run, the title) releases it as `Main._map` is replaced; a shape or language change builds a new screen and frees the kept one (the shape it is kept under is the one it has when it is left, since a live screen follows a re-pick); an ended run releases it as it routes or as any screen replaces another, such as the run's end shown from the run menu during a fight, and a map left by an ended run is not kept. A run standing on the boss of an act that is not the last releases it before the next act's landscape warms, because the kept screen holds this act's artwork and only one act's may be held at a time.

Off the tree, `MapScene` parks its stage at 2×2 (`MapScene.PARKED_STAGE`), which hands back the stage's render buffers (colour, 4x MSAA and depth: 48.5 MiB at the 1180×820 pad stage), and `_fit` sizes them again as the scene returns. The screen's own kept share is then 2.0 MiB in Act I and 2.1 MiB in Act II (0.8 MiB of it vertex and instance buffers by `Performance.RENDER_BUFFER_MEM_USED`; the texture counter underflows on this build, so the rest is not itemised).

A screen can now enter the tree more than once, so `TransitionLayer.screen_in` numbers each entrance on its root and lets only the latest write: an entrance cut short by a route change does not resume against the next one. The reopen also stopped paying for two things every refresh paid for: `_focus_xz` keeps the candidate envelopes of the screen's graph instead of deriving them per call, and the bound node anchors are read from the screen's bind-time copy of the layout instead of `MapLayoutResult.to_dict`, a deep copy of the whole result that cost every focus, pick and projection pass about 7 ms.

Measured on the M1 Max with a real renderer (debug, pad shape, `--map --map-timing --seed=1`, three interleaved runs each of this build and the one before while other work held the load average between 130 and 160), the medians from the call to a bound map, and to the first frame drawn after it, were:

| Act | Before: reopen | Reopen (kept) | Rebuilt (caches only) | Kept video memory, before → after |
|---|---|---|---|---|
| I | 54.6 / 80.7 ms | 6.0 / 13.0 ms | 48.0 / 64.9 ms | 61.0 → 62.4 MiB (60.4 for the act, 2.0 for the screen) |
| II | 51.0 / 72.9 ms | 6.0 / 12.3 ms | 49.0 / 71.4 ms | 43.9 → 45.9 MiB (43.8 for the act, 2.1 for the screen) |

The bench's `rebuilt` row drops only the kept screen and opens once more, which is what every return did before. The first open of an act (`cold`, `warmed` and `early`) builds as before.

## What it does not guarantee

Measured against the governed hard rules with `tools/preview_map.gd --compile-only --quality=…` (Act I, seeds 1, 717 and 17634), the fast layout keeps journey order, the row and lane envelopes, both protected zones, the node, scenery and hero silhouette rules, the touch-target minimum and the focused safe frame. Since #621 it also measures clean for node spacing at every zoom, the road corridor around every waystone and the corridors between every pair of roads that do not cross (the bump passes are bounded, so this is measured on these seeds and the probe's five, not proved). Distinct violations before and after the polish of #621 (the same seeds and rules; [`docs/reviews/map-polish-2026-10-01/`](../reviews/map-polish-2026-10-01/) has the captures):

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

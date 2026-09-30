# Production map layout

Status: **production since 2026-09-30**. Owner decision: production must not depend on Map Compiler v2.

Code: [`MapLayoutPolicy`](../../presentation/map/map_layout_policy.gd) chooses the generator, and [`MapLayoutFast`](../../presentation/map/map_layout_fast.gd) is the production generator.
Proof: [`tests/test_map_layout_fast.gd`](../../tests/test_map_layout_fast.gd) and [`tools/probe_map_fast_layout.gd`](../../tools/probe_map_fast_layout.gd).
Captures: [`docs/reviews/map-fast-layout-2026-09-30/`](../reviews/map-fast-layout-2026-09-30/).

## Why the compiler is opt-in

Map Compiler v2 (#526, #527) is a bounded constraint solver over the governed quality contract ([`map-quality-v2.md`](map-quality-v2.md)). On the M1 Max debug VM, one Act I compile takes 160–300 s and peaks at 1.5–2 GB RSS. Three of five Act I seeds tried on 2026-09-30 (1, 42 and 543001) end in `NO_FEASIBLE_NODE_ROUTE_LAYOUT`, which leaves those runs with no map. On the iPad 8 (A12, 3 GB), TestFlight build 8 was killed by the launch watchdog inside this compile. Moving it to a worker thread behind the charting veil (#614) removes the kill, but the player would then wait minutes, and a seed the compiler cannot solve would still have no map.

The compiler is therefore an authoring tool. It never runs on the player's path, and it cannot run at all on a mobile build.

## What the fast layout guarantees

`MapLayoutFast.compile(input, quality, assets)` returns the compiler's packet shape and a `MapLayoutResult` that satisfies the same identity contract (`generator_version = map-layout-fast-v1`). `WorldMapScreen`, `MapScene`, the waylights, the camera resolver and the quality registry consume it unchanged.

- **Complete.** Every node and edge of the canonical live input has an anchor and a routed centreline, and every centreline starts and ends exactly on its anchors. A valid input has no failure path.
- **Bounded and fast.** There is no search: a fixed number of lane sweeps per row, a fixed 7×7 grid for a node moved off a landmark, and one bounding-box-filtered crossing test per pair of roads leaving the same row. Measured on the M1 Max for seeds 1, 42, 717, 17634 and 543001 in Acts I–IV, generation takes 27–31 ms for Acts I–III and about 2 ms for Act IV. The probe fails above 200 ms.
- **Deterministic.** The result is a pure function of the canonical input: nodes, edges, act, run and scenery seeds, and the asset, camera, hero and quality identities. The geometry uses only IEEE arithmetic and square roots, never a transcendental function, and the two derived constants are literals held to the registry by the test. Two processes print identical digests for all 20 probe cases, and the test compares the geometry against digests recorded in another process.
- **Playable.** Each node stands on its authored lattice seat (row, column and the run's own jitter) inside its governed row and lane envelope, and in journey order. Same-row neighbours that the jitter crowds are pushed apart along the lane, inside their envelopes, until their waystones clear at the default zoom on the phone (4.75 m). A node that would stand in a hero's protected zone, or behind the silhouette of the Vigil or the gate, steps to the nearest clear point of its envelope. Every node has a safe focused camera pose at every shipping shape, and every reachable waystone is tappable where it projects.
- **Readable roads.** Each edge is a cubic whose end tangents bisect the chord and the journey axis, so roads fanning into one node meet only at its seal. Where two roads between the same two rows cross, the one bound for a lower lane rises over the other: it ramps linearly from its nodes to a 0.45 m deck (the governed two-level minimum is 0.384 m) from one segment before the crossing to one segment after it. The renderer draws bridge masonry wherever a road stands above 0.15 m, so a crossing reads as a bridge, not as a junction where the player could turn.

Scenery, the Vigil and the gate are placed exactly as before: `MapScene.bind_layout` filters the seeded scenery candidates against node reserves, road corridors and hero zones. That filter now skips each exact polygon test when the two bounding boxes are already too far apart for it to fire. The accepted set is unchanged: all 20 probe layouts have the same digest with and without the skip, and 2,908 candidates compared rule by rule gave zero mismatches. Binding now takes about 175 ms instead of about 2 s.

Measured on the M1 Max (headless, debug), `Main._show_map` takes about 0.7 s from call to a bound map. About 30 ms of that is layout generation. The rest is building the screen (the act's landscape catalogue is decoded twice, about 0.2 s each time), the scenery filter and the landscape mesh. `tools/shot.sh --map` returns in about 4 s, including engine start, where it used to time out at 240 s. The A12 has not been measured.

## What it does not guarantee

Measured against the governed hard rules with `tools/preview_map.gd --compile-only --quality=…` (Act I, seeds 1, 717 and 17634), the fast layout keeps journey order, the row and lane envelopes, both protected zones, the node, scenery and hero silhouette rules, the touch-target minimum and the focused safe frame. It does not pass the whole contract, and never claims to:

- **Farthest zoom.** At zoom stop 3 (28 m), adjacent-lane waystones touch or overlap on every shape. The lattice's 6 m lane spacing is too tight at that zoom, and the default play zoom (stop 2) is clean.
- **Two-level crossings.** The evaluator asks for 0.384 m of clearance over the whole overlap of the two 2.5 m corridors, with ramps no steeper than 0.353. A roughly 8 m diagonal road cannot fit both, so each bridged crossing still counts as a violation (8–13 per map in Act I, counting near-misses where two roads pass within a corridor width).
- **Near-misses.** A road can pass within its corridor of a neighbouring waystone (15–25 such cases per map, up to 0.9 m deep).
- **Branch fan-out.** Two roads leaving one node can still read as one road for their first few metres at the farthest zoom, and once at the default zoom on the phone (seed 1).

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

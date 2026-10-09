# R3.3: stone (issue #660)

Branch `map/r3-3-stone-2026-10-05`, on main `711302a5`. This is step R3.3 of
the R3 plan: Act I's rocks, cliffs and ruins. The ravine reads as a gorge of
stepped strata, mossy granite outcrops anchor the islands between the road
loops, and gravestones and broken walls stand along the roads.

Nothing here touches `domain/`, the save schema, the layout or its digests,
route ids, waystones, tokens, pins or other screens. Acts II–IV keep their
scenery: they are painted landscapes with no kit, terrain or rivers for the
stone to stand in, so the kit does not apply to them cheaply (as R3.2 found
for the floor).

**The woodland moved.** Placing the stone changes the kit's placement
sequence, so the woodland, which R3.1 b's unchanged rules plant round the
kit, re-flows. About two thirds of its cards stand where they stood and the
rest stand elsewhere, with the same totals and mix. The orchestrator
accepted the re-flow on 9 Oct ([below](#the-woodland-re-flowed)).

**Video memory and the cold open.** On the iPad the first device batch read
+22.8 MiB of video memory against main, over R3.2's +20 MiB line. So the
woodland's atlas is now two layers, so that no upload passes 4 MiB, and the
kit's textures load one at a time, so that their uploads never overlap;
the final code reads +17.3 MiB ([below](#the-woodland-atlas-in-two-layers)).
Two of the stone's stages now run beside the land's worker, and the cold
open reads 17 ms under main's in the same batch ([The cold
open](#the-cold-open)).

## What changed

| Commit | What |
|---|---|
| `fbf822a4` | **tools(map): the stone kit.** The Blender recipes (`tools/map_atelier/journey/stone/`: `sculpt.py`, `outcrops.py`, `cliffs.py`, `ruins.py`, `build_stone.py`, `prepare_stone.py`), the generated source pictures and their prompts, the masters (`journey/sources/<kind>.blend`), the hero kinds' reduced GLBs and the ruins' sculpts with their baked colour. None of it ships. `cover_tools.py` is shared with the floor's recipe. |
| `9a33cfd8` | **map: the stone.** The merged stone (`land_stone.gd`, `stone_pieces.gd`, `stone.gdshader`), the ravine's rule (`ravine_cliffs.gd`), the islands (`land_islands.gd`), the kit's groups, gravestones, walls and rocks off the water (`kit.gd`), the ruins as cards (`impostor_atlas.gd`, `impostor_wood.gd`, `wood_planting.gd`), the floor's strata, stamps and warm-up, the art (`assets/art/map-journey/stone/`, the woodland atlas re-baked), the packers, the probe's `--trace-kill=stone`, the payload budgets and the tests (`test_map_stone`, new; `test_map_wood` and `test_map_floor` for the stone; `test_map_floor` also checks that a settled floor is kept when its land is let go, the orchestrator's follow-up to #703). |
| `4fa0cee8` | **test(map): determinism and the ruins' sight.** `test_map_stone` builds seed 717's land twice and compares a digest of every placement; at four seeds it asserts that no ruin hides a road, a waystone or a token, and that nothing the kit keeps in sight was placed behind an earlier ruin's card. |
| `2fd7b2d7` | **map: the impostor atlas in two layers.** The woodland's albedo and normal atlases as two-layer texture arrays, so no upload passes 4 MiB ([below](#the-woodland-atlas-in-two-layers)): the packer's pages (`pack_impostors.py`), each tile's page (`impostor_atlas.gd`), the cards' instance data (`impostor_wood.gd`, `floor_plan.gd`), the two shaders (`impostor.gdshader`, `floor_caster.gdshader`), the re-packed atlas, the map-journey payload budget, and the tests (`test_map_wood`'s page decision, `test_map_floor`, and `test_texture_uploads`, new). |
| `95e7e339` | **map: the kit's textures load one at a time.** The kit's take (`ImpostorAtlas.Take`, the atlas's and the stone's) asks for its next texture only once the last is taken, so no two of its uploads overlap ([below](#the-kits-textures-one-at-a-time)); `test_map_wood` checks it. |
| `4364b834` | **map: the islands' search and the stone's merge beside the land's worker.** The island search runs on the worker pool during the kit's first stages (`kit.gd`), and the stone's pieces gather on it while the woodland is planted, committed after (`kit.gd`, `land_stone.gd`, `map_journey_landscape.gd`). Every placement is unchanged ([below](#the-cold-open)). |
| this commit | This README and its evidence, the art ledger's R3.3 section, and R3.2's README: re-anchored by a line where two preloads moved, and its prose on the live casters and the bake's cards brought up to date. |

Where the lane measured:

- the Mac's proofs and figures at `1ae3888c` and `abde6da0` (neither
  pushed). Their production files are the stone's code commit's, before the
  atlas split, the take one at a time and the levers. The split leaves the
  woodland's picture the same (a pixel diff of compression noise, every
  placement identical); the take changes only the order the kit's
  textures load in, and the levers change no placement;
- the iPad's batches at the stone (`60d3c805`, S1), the split (`2fd7b2d7`,
  S1b) and the final code (`4364b834`: S1c, T1 and S2) ([Gates](#gates));
- the token gate's Acts II–IV and their sheets at `99a23e3c`. Those acts
  draw no kit, stone or ravine, and nothing they run changed after it. The
  pin tripwire's history across the lane's heads is in
  [`mac/pin-diagnosis.txt`](mac/pin-diagnosis.txt).

## The look

Sheets cover every stop at both shapes, main on the left of each pair (Act I:
seeds 717 and 1–3, from the token gate's stop captures at the code-final
runtime; Acts II–IV: seeds 1–3):

| Act | Pad | Phone |
|---|---|---|
| I | [`act1-pad.jpg`](frames/act1-pad.jpg) | [`act1-phone.jpg`](frames/act1-phone.jpg) |
| II | [`act2-pad.jpg`](frames/act2-pad.jpg) | [`act2-phone.jpg`](frames/act2-phone.jpg) |
| III | [`act3-pad.jpg`](frames/act3-pad.jpg) | [`act3-phone.jpg`](frames/act3-phone.jpg) |
| IV | [`act4-pad.jpg`](frames/act4-pad.jpg) | [`act4-phone.jpg`](frames/act4-phone.jpg) |

Acts II–IV differ from main by at most 1.2% of a frame's pixels (the motes
and the mist; [`frames/pixel-diff.txt`](frames/pixel-diff.txt)).

Crops at 2×, main beside the branch (seed 1, pad, lean, under the A12
condition):

- [the ravine](frames/crop-ravine.jpg): stepped strata on both banks, with
  the lip a rock edge at the rim;
- [an island's group](frames/crop-island.jpg): a mossy tor with a conifer
  behind it;
- [outcrops and gravestones by the gateway](frames/crop-outcrops.jpg): the
  granite ridge and a boulder, with their moss, cracks and contact shade;
- [gravestones](frames/crop-ruins.jpg) on the verges and by the bridge;
- [a broken wall](frames/crop-wall.jpg) at the Journey stop;
- [the hero pieces on their own](frames/pieces.jpg), under the land's key
  light and ambient, and [the ruins' cards](frames/ruin-cards.jpg) as
  baked.

**The iPad 8 frame** ([the branch at Journey, seed 1](frames/ipad8-journey.jpg),
`4364b834`, batch S2, turned to landscape): the cliffs line both banks of the
river, mossy outcrops stand on the islands and by the bridge, and
gravestones and walls stand along the roads, among the woodland's cards.

## The kit

Crafted in Blender 5.2.2 (background, 4 threads), one recipe per kind, in
`tools/map_atelier/journey/stone/`:

- `outcrops.py`: five granite outcrops;
- `cliffs.py`: six cliff pieces;
- `ruins.py`: four gravestones, three broken walls and three rubble clusters.

Every kind is made the same way (`sculpt.py`):

1. **Sculpt.** Masses are fused into one solid by a voxel remesh: rounded
   blocks for granite, slabs for strata, ashlar for walls.
2. **Cut.** Joint planes are cut through the solid, and the remesh runs
   again to weather the cuts.
3. **Displace.** Every vertex moves along its normal by a seeded noise:
   Voronoi cracks along the joints, a slow swell, a fine grain, and level
   grooves at the strata.
4. **Retopologise.** Quadric collapse brings each kind to its triangle budget.
5. **Unwrap.** Each hero kind is unwrapped into its own cell of one atlas.
6. **Bake** (Cycles, CPU): normals, ambient occlusion and colour. The colour
   is the stone picture box-projected, darkened in its cavities and lifted on
   its edges, then darkened by the baked occlusion (a share of 0.75).

The masters are in `tools/map_atelier/journey/sources/`. A re-run of the kit
reproduces every shipped and source file byte for byte; only the `.blend`
masters differ, as Blender writes bytes of its own into them.

| Kind | Drawn as | Triangles | Circle (m) | Top (m) | What |
|---|---|---|---|---|---|
| `granite-bank` | mesh | 1,250 | 1.81 | 1.54 | Broad low granite mound: three rounded blocks on a flat joint top, a fallen piece at its foot |
| `granite-ridge` | mesh | 1,150 | 2.26 | 1.00 | Long low granite ridge: four jointed blocks falling away to one end |
| `granite-shard` | mesh | 900 | 0.99 | 2.13 | Upright granite pillar split from its bed, a leaning slab against it |
| `granite-tor` | mesh | 1,400 | 1.88 | 2.33 | Stacked granite tor: three blocks on level joints, a boulder shed at its side |
| `granite-boulder` | mesh | 874 | 1.07 | 0.90 | A single rounded granite boulder with a split face and a chip beside it |
| `cliff-wall` | mesh | 1,074 | 2.08 | 0.29 | Strata wall: even ledges stepping back from the water |
| `cliff-notch` | mesh | 1,074 | 1.94 | 0.35 | Strata wall cut by a deep weathered band, the layer above it overhanging |
| `cliff-buttress` | mesh | 1,074 | 1.98 | 0.40 | Strata wall with a jutting buttress whose facets turn toward the camera |
| `cliff-bend` | mesh | 1,074 | 1.99 | 0.32 | Strata wall curved outward, for the outside of the river's bends |
| `cliff-step` | mesh | 1,074 | 1.87 | -0.28 | Low broken strata step where the rim stands low over the water |
| `cliff-tall` | mesh | 1,074 | 2.14 | 0.51 | Tall strata wall with a high lip and an overhanging top ledge |
| `grave-arched` | card | 3,000 | 0.35 | 0.99 | Round-headed headstone with a sunk panel, leaning, its corner chipped |
| `grave-cross` | card | 3,500 | 0.39 | 1.26 | Ringed cross on a stepped plinth, one arm broken short |
| `grave-broken` | card | 3,000 | 0.81 | 0.67 | Pointed headstone snapped across, its head fallen at its foot |
| `grave-tablet` | card | 3,000 | 1.12 | 0.61 | Squat tablet leaning hard over its sunken ledger slab |
| `wall-run` | card | 6,000 | 1.79 | 1.70 | Run of coursed ashlar falling from shoulder height to its footing |
| `wall-corner` | card | 6,000 | 2.23 | 1.71 | Corner of a ruined building, its two runs broken off |
| `wall-pier` | card | 5,996 | 1.91 | 2.20 | Wall ending in a tall pier, an arch's springer stone left on it |
| `rubble-blocks` | card | 3,000 | 0.89 | 0.28 | Heap of fallen ashlar blocks, half sunk |
| `rubble-scree` | card | 3,000 | 0.97 | 0.25 | Fan of angular granite scree |
| `rubble-mossy` | card | 2,500 | 0.74 | 0.22 | Low mound of stones under moss |

**Hero kinds** (the outcrops and the cliffs) are drawn as meshes:

- `assets/art/map-journey/stone/stone-albedo.png` (2048×1536, 4×3 cells of
  512) holds their colour, which carries the occlusion;
- `stone-normal.png` (1024×768) holds the tangent-space normals at half size,
  imported as a normal map;
- `stone-pieces.res` holds the reduced meshes as plain arrays.
  `pack_stone.gd` packs them from the GLBs under
  `tools/map_atelier/journey/stone/glb/`; the GLBs themselves do not ship.

**Ruins** are drawn as impostor cards, re-baked into the woodland's atlas
(`impostors/wood-*`). Their tiles outgrow main's 2048×1408 page, so the
atlas is two layers of 2048×1024
([below](#the-woodland-atlas-in-two-layers)). Their sources are under
`tools/map_atelier/journey/impostors/stone/`: each sculpt at 2,500–6,000
triangles and its baked colour. They do not ship. The re-bake is
deterministic, and the woodland's own 42 tiles are the same as main's on
every covered texel; only the colour bled under the transparent texels
differs.

**Textures.**

- The granite and the cliff strata were generated with the image tool R3.2
  used, one candidate each. The prompts are in `stone/sources/prompts.txt`,
  with the pictures beside them.
- `prepare_stone.py` takes the slow light out, wraps the edges and grades
  the pictures. It shares its helpers with the floor's recipe
  (`cover_tools.py`), which still reproduces the floor byte for byte.
- The moss on the stone is the floor's own moss (`floor/floor-moss.png`),
  sampled in world space and lifted to an olive green, so it ships nothing
  new.

Every asset is a lane pick with a row in `docs/art-ledger.md`; the owner may
re-pick any of them.

## How the stone is drawn

`land_stone.gd`, `presentation/map/landscape/land_stone.gd:98 (build)`:

- The kit's granite and the ravine's cliff pieces are merged into one mesh per
  32 m cell on one material, so the stone draws in a few draws (seven at
  seed 717 for 49 pieces, six at seed 1 for 65). The merge is `SurfaceTool.append_from` over the
  packed arrays (`presentation/map/landscape/land_stone.gd:146 (_merge)`), which are
  held as meshes the renderer never sees, so nothing is read back from the
  renderer on the land's worker. The pieces load on the loader's threads
  before any land is built (`presentation/map/landscape/land_stone.gd:57 (prepare_step)`,
  from `Kit.preload_step`).
- `stone.gdshader` (`presentation/map/landscape/stone.gdshader:34 (fragment)`):
  - three samplers, none anisotropic: the atlas's colour and normals, and the
    moss;
  - a grade on the baked colour (`stone_tint`): granite reads grey under the
    warm key, not tan;
  - a moss cap where the mapped normal faces the sky, broken up by the moss
    picture; the cliffs' strata take a third of the outcrops' moss (by their
    cells in the atlas), so the rim reads as rock;
  - nothing that moves;
  - no vertex stage of its own, so its shadow uses the renderer's shared
    shadow pipeline.
- **The stone casts into the floor's bake, not live** (a [judgement
  call](#judgement-calls)). The live shadow pass keeps only the gateway arch
  and the bridges' parapets (`presentation/map/landscape/land_floor.gd:28 (LIVE_CASTERS)`).
- The floor's warm-up draws a sample of the stone's pipeline before the
  title, behind the launch screen, on a mesh in the stone's own vertex format
  (`presentation/map/landscape/floor_warm.gd:196 (_stone_mesh)`).

**The ravine** (`presentation/map/landscape/ravine_cliffs.gd:57 (plan)`): along both
banks of both rivers, a piece stands every 0.82 of its own width.

- **Placement.** Its face is turned to the water and its lip sits at the
  rim. A piece reaches 4.0 m below its rim and is scaled up, never down,
  where the rim stands high, so that its foot always reaches 0.5 m under the
  water.
- **Kind** (`presentation/map/landscape/ravine_cliffs.gd:94 (_kind)`). The bend piece
  goes on the outside of a bend, the low step where the rim stands low, and
  the tall wall where it stands high. Elsewhere a wall, a notched wall or a
  buttress is chosen by hash.
- **Clearances.** No piece stands:
  - by a bridge deck, an abutment, a waystone or a road;
  - within 2.5 m of the land's far edge or 8.9 m of its near edge. The
    camera sees under the near edge, and pieces there hung their feet below
    the land in the Whole act view.
  - where its foot would sink below the journey camera's slab
    (`MapJourneyCameraContract.LAND_LOW`, 5 m below the land's zero).
    Pieces 5.4 m deep broke that contract at low rims; `test_map_journey`
    caught it.
- **The banks.** The floor's bake lays the strata on the steep banks
  (`floor_paint.gdshader`), biplanar along the bank.

**The islands** (`presentation/map/landscape/land_islands.gd:30 (find)`,
`presentation/map/landscape/kit.gd:491 (_islands)`):

- **Finding them.** The ground no road or river lets out to the land's edge.
  Each island is held at its pole, the cell farthest from a road.
- **The group.** Each of the eight largest is anchored by an outcrop (the
  largest that fits of a tor, a bank and a boulder), with a conifer behind it,
  shrubs round it and gravestones either side of it (in front, a card would
  hide the rock).

**Gravestones and ruins**:

- **Gravestones.** Short rows of two along the roads' verges, one row every
  13 m of road on alternating sides, 2.3–3.1 m off the line, placed before
  the woodland's families (`presentation/map/landscape/kit.gd:575 (_verge_graves)`);
  after them, one beside each of up to eight memorial shrines, of the first
  sixteen (`presentation/map/landscape/kit.gd:557 (_shrine_graves)`); more on the
  islands; at most 30 on the verges and by the shrines (15–26 gravestones a
  land in all at seeds 717 and 1–3).
- **Broken walls** (`presentation/map/landscape/kit.gd:620 (_ruins)`). Up to four
  stand 3 to 5.5 m off a road, at least 16 m apart, turned across the
  camera's view, each with fallen blocks and a mossy mound beside it.
- **Only where they will be drawn** (`presentation/map/landscape/kit.gd:681 (_in_sight)`,
  `presentation/map/landscape/kit.gd:700 (_unhidden)`). A ruin is a card, and the
  woodland draws a card only where it hides nothing it must keep in sight:
  the roads' lanes, the decks, the waystones, the lamps, the water, the
  gateway, the shrines, the rocks and the other ruins. The kit asks the same
  question before it places a ruin, of the same grid
  (`presentation/map/landscape/wood_planting.gd:261 (protect_ground)`,
  `presentation/map/landscape/wood_planting.gd:309 (protected_area)`), and keeps it up
  to date with every placement after; and it places nothing the woodland
  keeps in sight behind a ruin's card. The planting then plants against the
  kit's grid (`presentation/map/landscape/kit.gd:456 (woodland_sight)`), the same
  protection over the same placements, so the grid is built once. Without
  this, 34 of 58 ruins at seed 717 were placed and then left out.
- **Planting.** The woodland plants them as cards where the kit placed them,
  never shrunk (`presentation/map/landscape/wood_planting.gd:527 (_fit_stone)`).
- **Floor and motion.** The standing ruins cast into the floor's bake
  through their cards (`presentation/map/landscape/wood_planting.gd:536 (casts)`), and
  their cards never sway (`presentation/map/landscape/impostor_wood.gd:159 (card_colour)`).

**Rocks off the water** (`presentation/map/landscape/kit.gd:884 (_clear)`): an
outcrop's footprint circle may reach over the bank and at most a quarter of
its radius over the water. On main, two to five rocks a land reached further
over the river (2, 3, 5 and 2 at seeds 717, 1, 2 and 3).

The granite kinds replace the R1 slate kinds in the same places, with the
same footprints (`granite-bank`, `granite-ridge`, `granite-shard`). The
slate scree is now the `rubble-scree` card. The new kinds' circles are the
kit's own, from its manifest.

## The woodland re-flowed

The woodland is R3.1 b's lane pick, planted by its unchanged rules round the
kit's placements. R3.3 changes the kit's placement sequence:

- the islands' groups, the walls and the verge rows come before the
  woodland's families;
- the new kinds have footprints of their own;
- rocks keep off the water.

Every later clearance follows from the earlier ones, so the woodland
re-flows. On 9 Oct the orchestrator accepted the re-flow, for four reasons:

- the owner picked R3.1 b's rules and character, not a fixed set of
  positions;
- nothing in the layout moves;
- the islands' groups are an R3.3 deliverable;
- main's rocks over the river are a defect.

The woodland stays a lane pick the owner may re-pick.

Built headless from the run seed, main `711302a5` against the branch's
code-final head (`tools/wood_dump.gd.txt`, `tools/wood_final.py.txt`,
[`mac/woodland.txt`](mac/woodland.txt)). The cards of the ruins are left out
of every count but the first column's note.

| Seed | Cards, main → branch | Identical | Re-flowed (main's, branch's) | Re-flowed within 5 m of a stone or ruin | Trees, main → branch | Kit placements in the same place |
|---|---|---|---|---|---|---|
| 717 | 3,788 → 3,762 (−0.7%; +42 ruins) | 2,542 (67.1%) | 1,246, 1,220 | 74% | 233 → 206 | 74 of 478 |
| 1 | 3,904 → 3,868 (−0.9%; +35) | 2,624 (67.2%) | 1,280, 1,244 | 71% | 270 → 267 | 78 of 532 |
| 2 | 3,866 → 3,822 (−1.1%; +40) | 2,624 (67.9%) | 1,242, 1,198 | 69% | 270 → 249 | 100 of 525 |
| 3 | 4,020 → 3,983 (−0.9%; +39) | 2,706 (67.3%) | 1,314, 1,277 | 66% | 271 → 249 | 77 of 562 |

- **Determinism.** Each seed was built twice on the branch: the two builds
  are identical, byte for byte. The layout digests are main's at every seed,
  and `tests/test_map_layout_fast.gd`, untouched, passes.
- **The mix holds** (R3.1 b's art direction, 35–40% conifers): conifers
  38.3, 39.3, 39.0 and 36.9% of the trees at the four seeds (main 38.2,
  39.3, 38.5, 38.0); crimson 36.9–38.6% (main 35.6–39.3); rust and amber
  22.9–24.8% (main 21.5–26.2).
- **Kinds that moved by more than 10%** over the four seeds: `ember-round`
  211 → 185 (−12.3%), `conifer-spire` 190 → 164 (−13.7%) and `conifer-wind`
  51 → 41 (−19.6%). The trees give way where the stone stands: the islands'
  poles, which crowns covered on main, now hold their groups; the verge rows,
  the walls and the rocks moved off the river take ground the woodland's
  families and the fill's crowns stood on; and a crown may not stand in front
  of a stone. `conifer-wind` is an accent of ten or so a land, so a few go a
  long way. Undergrowth moves by under 7% a kind; all cards by −0.9%.
- **Kit foliage left out by the sight rule** ('kit sight'): 717 19 → 21, 1
  18 → 25, 2 27 → 27, 3 30 → 32, every one foliage (every ruin is drawn).
  `test_map_wood`'s line, under a tenth of the kit's foliage, holds.
- **Main's rocks over the river**: 2, 3, 5 and 2 at seeds 717, 1, 2 and 3
  (`slate-bank`, `slate-ridge`, one `slate-shard`), each with more than a
  quarter of its radius over the water. The branch has none
  (`test_map_stone` checks the four seeds).

**R3.1 b's woodland gates, re-run** (its own tools, on the Mac under the
A12 Metal condition, lean, Reduce Motion stills, no drifting air, seed 1;
the cover by the flat-magenta count with the ruins' stone cards left out;
[`mac/woodland-gates.txt`](mac/woodland-gates.txt)):

| Figure | Gate | Main | Branch |
|---|---|---|---|
| Canopy cover, pad Journey | ≥ 45% | 45.3% | **43.6%** (misses by 1.4 points) |
| Canopy cover, pad Whole act | ≥ 45% | 43.9% (R3.1 b's exception) | 42.8% |
| Canopy cover, pad fresh-run opening | ≥ 45% | 45.8% | 45.8% |
| Canopy cover, phone Journey | ≥ 45% | 44.2% | 42.8% |
| Red share, pad Journey | 6.3–16.3% | 16.7% (R3.1 b's open residual) | **16.1%**, inside the band |
| Red share, pad Whole act | 6.3–16.3% | 11.5% | 12.2% |
| Red share, pad fresh-run opening | 6.3–16.3% | 12.5% | 12.3% |
| Red share, phone Journey | 6.3–16.3% | 12.5% | 14.1% |
| Saturated reds' hue bands (345–355 / 355–5 / 5–15°), pad Journey | the target's 5 / 56 / 39 | 0 / 59 / 41 | 0 / 55 / 45 |
| Pins, R2's tripwire (rim minimum) | pad 1.10, phone 1.05, desktop 1.10 | 1.93, 1.07, 1.96 | 1.91, **1.04**, 1.93 |
| Kit foliage left out by sight, seeds 717 / 1 / 2 / 3 | under a tenth of the kit's foliage | 19 / 18 / 27 / 30 | 21 / 25 / 27 / 32 |
| Token gate (#679), Act I, seeds 717 and 1–3, phone and pad | 0 failed | 0 failed in 8 runs, worst margin 1.006–1.023 | **0 failed** in 8 runs, worst margin 1.006–1.025 |

- **Cover** falls where crowns gave way to stone: the outcrops, the cliff
  ledges at the rim, the walls and the gravestones stand where crowns stood,
  and the ruins' own cards are not counted. The pad's Journey now misses the
  45% line by 1.4 points, as Whole act already did on main. The
  orchestrator accepted this exception as the stone's cost on 9 Oct, at
  about 44.1% (pad Journey) and 41.8% (phone Journey) on an earlier lane
  head, and re-confirmed it the same day at 43.6% and 42.8% after seeing the
  side-by-side sheets. R3.6 is to re-measure the cover against the target
  with the stone in place. Seen on
  the side-by-side sheets (Journey and Close, pad and phone, seeds 717 and
  1–3), nowhere reads barren where crowns gave way to stone: the stone stands
  in a wood as dense as main's, and the roads, the waystones and their touch
  squares stay clear.
- **Red share at the pad's Journey** comes inside its band, 16.1% against
  16.3%, which closes R3.1 b's open residual of that view (16.7%): some of
  the crimson crowns there gave way to grey stone.
- **The pins' tripwire on the phone** moves from 1.07 to 1.04, a hundredth
  under its re-baseline of 1.05. The orchestrator accepted this as a named
  move of the tripwire. The token is at (266, 113) on R2's mount
  ([`mac/pin-diagnosis.txt`](mac/pin-diagnosis.txt); [8× crop of main, the
  branch and their difference](frames/pin-phone-weakest-8x.png)).
  - Nothing inside the drawn token changed: 0 pixels within 16 px of its
    centre.
  - The probe gives the token's pane radius as 28 px, but the drawn token
    ends at about 16 px. So the method's "rim" band (23–27 px) and most of
    its "disc" band lie on the land outside the token. Since #679, the
    method compares land with land.
  - What moved is the land round the token: a crimson crown re-flowed to
    its left, and the floor beside it changed.
  - Across the lane's heads the figure read 1.02, 1.05 and 1.04. At the
    first of those heads the weakest token was another, at (455, 285): the
    gateway's companion bank, moved off the river, replaced a dark crimson
    crown in its ring.
  - The token gate, the legibility authority since #679, passes with the
    same margins.
  - Retiring R2's method for #679's tokens is proposed as a follow-up on
    #660.

**What R3.3 places** ([`mac/placements.txt`](mac/placements.txt)):

| Seed | Cliff pieces | Outcrops (tor, bank, ridge, shard, boulder) | Stone triangles | Gravestones | Walls | Rubble |
|---|---|---|---|---|---|---|
| 717 | 26 | 23 (3, 7, 2, 3, 8) | 52,866 | 23 | 4 | 15 |
| 1 | 36 | 29 (1, 7, 7, 3, 11) | 69,178 | 18 | 4 | 13 |
| 2 | 32 | 23 (2, 7, 3, 3, 8) | 59,060 | 21 | 4 | 15 |
| 3 | 32 | 16 (2, 2, 4, 3, 5) | 51,338 | 26 | 4 | 9 |

## The woodland atlas in two layers

On the iPad 8 (batch S1, 10 Oct), the branch's Journey hold read
**+22.8 MiB** against main, over R3.2's +20 MiB line. At the start of the
cold open, before any land is built, it already read +20.6 to +22.6 MiB. So
the delta was held for the life of the process, not by the land:

- about 7 MiB of ours: the stone's textures and buffers, and the woodland
  atlas's growth;
- about 16 MiB of the engine's transfer staging. The woodland atlas brought
  it when the ruins' cards grew it past 4 MiB
  ([Mac measurements](#mac-measurements), [`mac/vram-hunt.txt`](mac/vram-hunt.txt)).

The orchestrator brought the split into this PR.

**The lever, proven first** ([`mac/atlas-split.txt`](mac/atlas-split.txt)).
Each texture was imported as the game imports it and loaded alone, on the
loader's threads, in a bare process on the Mac (the A12 condition):

| Texture | Its uploads | Untracked growth, alone | After main's atlas |
|---|---|---|---|
| Main's atlas, one page of 2048×1408 | 3.67 MiB | +14.00 MiB | — |
| R3.3's atlas, one page of 2048×1776 | 4.63 MiB | +30.00 MiB | **+16.00 MiB** |
| R3.3's atlas, two layers of 2048×1024 | 2.67 MiB each | +13.99 MiB | **−0.01 MiB** |

Three interleaved runs of each read the same to the hundredth. A bare
process has made no upload yet, so its first upload sets up the staging.
Once main's atlas has set it up, as any game process has by the time the map
opens, the one page grows it by 16 MiB and the two layers do not grow it.

**What changed:**

- Both atlases are two-layer texture arrays (`2d_array_texture`), a page a
  layer. The engine uploads an array a layer at a time, each with its whole
  mip chain.
- The importer makes a VRAM-compressed array's layers powers of two. So the
  pages are 2048×1024, and the normals' 1024×512, not the 2048×888 halves
  first planned. Each albedo layer uploads 2.67 MiB.
- `pack_impostors.py` packs the tiles a shelf at a time. A shelf that would
  pass a page's foot starts the next page; the pages use 1,009 and 754 of
  their 1,024 rows. Each page's gutters bleed within it.
- It packed a re-bake of the committed recipes, byte-identical to the bake
  behind the one-page atlas.
- A card carries its tile's rect on its page, with the page added to the
  rect's top (`presentation/map/landscape/impostor_atlas.gd:230 (custom)`).
  `impostor.gdshader` and `floor_caster.gdshader` read the page back as the
  whole part and sample a `sampler2DArray`. Their sampler counts are
  unchanged: two and one.
- Payload: +0.88 MiB on iOS, from the power-of-two pages (282.1 → 283.0 MiB
  in all). The map-journey group's budget goes from 17 to 18 MiB.

**The woodland is unchanged** ([`mac/atlas-split.txt`](mac/atlas-split.txt)):

- Every tile keeps its kind, yaw, picture-plane rect, reach and silhouette;
  only its page and rect on the page moved.
- The placements are identical at seeds 717 and 1–3: every card's kind,
  tile, base and scale (`wood_dump.gd`).
- **Pixel diff**, the split against the pre-split branch (`60d3c805`). Act I,
  seeds 717 and 1–3, pad and phone, Journey and Close, lean, under Reduce
  Motion, with no drifting air. The pre-split build was captured twice, and
  every pixel that moved between those two captures (the water) is left out:
  - mean difference 1.38–2.14 of 255;
  - 0.88–1.82% of pixels differ by more than 16, and 0.22–0.45% by more than 32;
  - the largest connected patch over 32 is 10–88 px.

  The patches lie inside cards, in 4×4 blocks. Zoomed, the same card stands
  in the same place with the same colours
  ([a wall at Close](frames/split-zoom-close.jpg)). That is block compression
  falling on new texel rows, and the pages' power-of-two mips. A card moved
  or missing would leave a patch of hundreds of pixels. A re-tint would
  shift the colour; the mean shift on the changed pixels is at most 0.26 of
  255 in any channel.
- The A12 condition: no "Error compiling shader" at the three shapes, en and
  zh-Hant lean and en full. Reduce Motion at Close: 12,786 pixels move (the
  water), against 12,801 before the split.
- `test_map_wood` tests the decision itself:
  - every tile's instance data, read back as the shaders read it, finds that
    tile's own silhouette on its page, row for row, and both pages hold tiles;
  - every drawn card carries its own plant's tile and page.

  `test_map_floor` checks the same for the floor's shadow cards.

**The guard** (`tests/test_texture_uploads.gd`, this fix's regression test).
It reads every texture the iOS preset ships from its imported file and fails
when any uploads more than 4 MiB at once, a layer counting alone. Reverting
the atlas to one page fails it (mutation table below).

When it landed, 23 other shipped textures already uploaded more than that.
All are 2D art imported lossless:

- the boot splash, 11.07 MiB;
- the combat stages' backdrops and middles, 6.0 MiB each, and two ledges,
  4.46 and 4.62 MiB;
- the scenes, and the title's background, 4.5 MiB each.

The guard holds each at its present upload, so none may grow and nothing may
join them. Bringing them under 4 MiB is a follow-up.

### The kit's textures, one at a time

The split alone did not bring the iPad under the line. In batch S1b, the
branch's Journey hold read **+21.4 MiB** against main, in two modes 12.0 MiB
apart. The mode was set before the first frame: the step is already there at
the boot's second frame.

In the real projects on the Mac, the cause was decisive
([`mac/atlas-split-diagnosis.txt`](mac/atlas-split-diagnosis.txt)):

- the five map textures taken together (the woodland's two arrays and the
  stone's three) grew the untracked memory by 16.00 MiB in every run;
- taken one at a time, in either order, or the woodland's pair on its own,
  they grew it by nothing.

RenderingDevice keeps a pool of transfer workers, as many as the device has
processor cores. An upload that finds every worker busy makes a new one,
with a staging buffer of its own that is never shrunk. So the kit's take
(`presentation/map/landscape/impostor_atlas.gd:87 (Take)`) now asks the loader
for its next texture only once the last is taken: its texture made and its
upload recorded. `Kit.preload_step` already began the stone's take only once
the atlas's had settled. Nothing changes in what loads, on which thread, or
when the map may use it; only the order. `test_map_wood` checks that a take
never has more than one request in flight (mutations: 2 of 2 caught).

**Proven on the Mac first** ([`mac/serial-proof.txt`](mac/serial-proof.txt)):

- **The kit's own take, in the game's order**, ten runs per build:

  | Build | Untracked growth |
  |---|---|
  | One at a time (`95e7e339`) | **+0.00 MiB in 10 of 10** |
  | The branch before the change | +8.00 MiB in 9, +16.00 MiB in 1 |
  | Main | +16.00 MiB in 4, none in 6 |

  Main's own pair of textures, taken together, shows the same effect.
- **Short game probes**, 16 per build, interleaved, Journey hold in MiB:

  | Build | Readings |
  |---|---|
  | Before the change | 239.8 ×2 (the step), 231.8 ×8, 225.8 ×3, 223.8–223.9 ×3 |
  | After the change | 231.8 ×14, 223.8 ×2, never the step |
  | Main | 232.6 ×5, 216.7–218.6 ×11 |

**What it costs the kit's readiness.** The take now waits for each texture
in turn. Medians on the Mac, five runs each:

| How the take runs | One at a time | Before the change | Main |
|---|---|---|---|
| Waiting, as a map opening now does | 29.5 ms | 32.3 ms | 4.3 ms |
| A step a frame, as the prefetch under the title does | 75.4 ms | 30.8 ms | 10.6 ms |

The stepped take spends a frame or more on each texture, under the title.
The cold open does not wait for it. The kit's textures and the stone's
pieces are held for the life of the process (`ImpostorAtlas`, `LandStone`),
and a cold open, every cache dropped, never takes them again. A boot waits
for the take only when a map opens before the prefetch under the title has
finished, as the `--map` path does.

On the iPad 8, batch S1c read **+17.3 MiB** against main, within the line. The high mode still came in 7 of 14 boots ([Video memory on the iPad](#video-memory-on-the-ipad)).

## Gates

### iPad 8

Every batch ran the QA app only, under the shared device lock, with main
`711302a5` against the branch, interleaved. The battery was full (99–100%)
on external power throughout. Every launch is in `device/`.

| Batch | The branch's build | What it measured |
|---|---|---|
| [S1](device/batchS1/summary.txt) | `60d3c805`, the stone | the gates; two installs a build |
| [S1b](device/batchS1b/summary.txt) | `2fd7b2d7`, the atlas split | the same, with two more cold opens an install |
| [S1c](device/batchS1c/summary.txt) | `4364b834`, the final code | the same |
| [T1](device/batchT1/summary.txt) | `4364b834`, built with nonces | the fresh-install title path |
| [S2](device/traces/batchS2-batch.log) | `4364b834` | the screenshot and the Metal System Traces |

**Gates at the final code** (S1c, S2 and T1):

| Gate | Branch (median; every launch) | Main | Verdict |
|---|---|---|---|
| Hero meshes ≤ 1.0 ms at the reference clock | **0.15 ms**: the main 3D pass with the stone, 0.530 ms vertex and 1.694 fragment, against 0.439 and 1.631 without it (S2, one trace each, 302 and 301 stage frames). 0.20 ms of the GPU's busy time | — | Pass |
| Stage ≤ 130k primitives, Journey | **86,882** primitives, 78 draws | 56,430, 79 | Pass. The fresh-run opening: 101,448 primitives, 96 draws (plan: 160k, 120). Whole act: 167,928, 211 (plan: 200k, 150; main already had 218 draws) |
| Floor fragment ≤ 0.9 ms at the reference clock | **0.146 ms**: the main 3D pass's fragment 1.694 ms with the ground, 1.548 without (306 stage frames) | Main's ground 1.131 ms (R3.2's B2) | Pass |
| Bake ≤ 0.4 s, no frame over 100 ms | Boots: **162.2 ms** over 14 launches; worst frame 83.3. Cold opens: 116.6–131.9 ms; worst frame 66.8 | 166.9; worst frame 83.2 | Pass. S1 and S1b each had one outlier, the first launch after an install on the `--map` path, which skips the title's warm-up: 3,048 and 1,935 ms frames (`dev1-l1`). It did not recur in S1c. T1 measures the player's path |
| Live shadow ≤ 15k primitives | **4,118** at most (river 3,108) | 5,754 at most | Pass |
| Video memory ≤ +20 MiB, Journey hold | 303.4 MiB over 12 launches | 286.1 over 12 | **+17.3 MiB**, pass ([below](#video-memory-on-the-ipad)) |
| Transient ≤ +40 MiB, freed in 10 frames | Cold-open peaks 333.1 ×5 and 325.1; 303.4 or 295.4 ten frames later | 318.1 ×6 | +15.0 MiB, pass |
| Cold open | **2607.3 ms** (2565.5, 2598.7, 2599.2, 2615.3, 2730.5, 2835.6) | 2624.5 (2500.0, 2529.8, 2585.3, 2663.6, 2663.8, 3166.3) | **−17.2 ms against main.** 7.3 ms over the absolute 2.6 s line, which main misses by 24.5 ms: the floor reached ([below](#the-cold-open)) |
| Warmed open ≤ 200 ms | **97.6 ms** (110.9, 84.3) | 95.4 (104.3, 86.4) | Pass |
| Reopen ≤ 60 ms | **47.4 ms** over 12, at most 60.0: 40.8, 39.8, 46.6, 49.1, 45.8, 35.4, 48.8, 60.0, 50.3, 50.8, 48.2, 29.2 | 45.0: 45.9, 40.8, 43.1, 36.7, 47.8, 44.1, 50.6, 50.5, 46.6, 43.8, 36.1, 47.8 | Pass |
| Rest at vsync, 0 missed, every view | Every view, at the cadence and live, every launch: means 16.659–16.664 ms, **0 missed** | 0 missed | Pass |
| Fresh-install title path (#682's acceptance, not this PR's) | Frame 0, fresh: **8067.3, 8395.4 ms**. First map open's worst frame: 184.4, 399.3 | 6276.4, 6129.4; 181.0, 175.4 | Known: **+2.0 s** ([below](#the-title-path-on-a-fresh-install)) |

Main's outlier: `ctl1-l1`'s cold open at 3166.3 ms, the first launch after
its install (its land took 2375 ms to build, its terrain 1284).

#### Video memory on the iPad

The pooled Journey hold, every launch with one, in MiB:

| Batch | Branch | Main | Delta |
|---|---|---|---|
| S1, the stone | 304.05 (8) | 281.25 (8) | +22.8 |
| S1b, the split | 303.4 (12) | 282.0 (12) | +21.4 |
| **S1c, the final code** | **303.4 (12)** | **286.1 (12)** | **+17.3** |

On S1's mix of launches alone (the first launch and the short Journey holds,
eight of each build), S1c reads +18.15. Every launch's start, peak, end and
after, for the boot and every open, is in
[`device/batchS1c/vram.txt`](device/batchS1c/vram.txt) (and S1's and S1b's
beside it).

**Both modes, counted.** The branch's boots end in modes 8 MiB apart,
set before the first frame:

| Batch | High (303.2–303.3) | Middle (295.2) | Low (287.2–291.3) |
|---|---|---|---|
| S1b | 8 of 14 | — | 6 of 14 |
| S1c | 7 of 14 | 2 of 14 | 5 of 14 |

Main's boots end at 279.9–283.9, once at 268.2.

**The high mode survives on the device.** It survived the textures taken
one at a time:

- 7 of 14 boots read it;
- one launch that booted low (`dev1-c2`, 289.3) read it after its cold and
  warmed opens (303.7).

S1c passes because main's own pooled figure rose with the batch's cold-open
launches: main's hold after its opens reads 288.0, against 280–282 before
them. Within the branch:

- **Ours** is the part Godot accounts, the same in every mode: its textures
  +5.4 MiB and its buffers +2.0 against main, so about 7.4 MiB.
- **The rest** is untracked: about +4 MiB in the low mode and +16 in the
  high mode.

The high mode is the transfer workers' staging again, from uploads that
overlap beyond the kit's own take: the land's build on its worker, the
opens and the kit's scenes. That part is inference: on the Mac the kit's
take alone now grows nothing, in 10 runs of 10.

#### The title path on a fresh install

T1 is batch R's method from R3.2. Never-used nonces were given to the five
floor shaders and `stone.gdshader` on the branch, and to main's five floor
shaders. Each fresh install was launched fresh, then cached, interleaved, in
ms:

| Build | Frame 0, fresh | Frame 0, cached | Frames after frame 0 over 100 ms | First map open: ready, worst frame |
|---|---|---|---|---|
| Main (nonces M, N) | 6276.4, 6129.4 | 432.9, 404.2 | none | 646.6 and 181.0; 646.9 and 175.4 |
| The branch (nonces A, B) | **8067.3, 8395.4** | 557.3, 395.4 | none | 663.1 and 184.4; 878.6 and **399.3** |

The branch's warm-up draws take about 4.6 s each, against main's 3.5 s: the
stone and the texture arrays add pipelines it compiles before the title's
first frame. So frame 0 on a fresh install is about **2.0 s later** than
main's. This is #682's acceptance, not this PR's. Once installed, the cached
launch is like main's.

One of the two fresh installs (`dev-B`) drew a 399.3 ms frame on its first
map open, where the others drew 173–189. That frame is the open's
transition frame (frame 28 on every build), so a pipeline the warm-up does
not cover was probably compiled there.

#### The traces

S2 recorded three Metal System Traces of the branch at Journey, seed 1,
live, about 7 s each
([`device/traces/`](device/traces/batchS2-batch.log)): as it is, without the
stone (`--trace-kill=stone`) and without the ground. Read at the reference
clock (tonemap at 0.270 ms; `tools/map_trace/roles.py`):

| Trace | The main 3D pass, vertex / fragment | GPU busy | The 3D chain's fragment |
|---|---|---|---|
| As it is | 0.530 / 1.694 ms | 4.99 ms | 2.59 ms |
| Without the stone | 0.439 / 1.631 ms | 4.79 ms | 2.52 ms |
| Without the ground | 0.493 / 1.548 ms | 4.75 ms | 2.40 ms |

The stone costs 0.15 ms of the main 3D pass, 0.09 of it vertex. The first
attempt at the plain trace ended early ("Device disconnected", 0.94 s) and
was retaken; the three kept traces each ran their whole time.
### The cold open

R3.2's gate is an absolute 2.6 s. Its round 3 asked for a median of 2.5 s
or less, "or the floor reached and why". On this iPad main itself moves
between batches. R3.2 recorded it at 2,250 to 2,476 ms; here it reads:

| Batch | Main's cold opens (ms) |
|---|---|
| R3.2 N4 | 2468.3, 2483.0 (median 2475.7) |
| S1 | 2882.0, 2715.5 |
| S1b | 2498.6, 2507.8, 2513.5, 2632.4, 2651.8, 2682.7 |
| S1c | 2500.0, 2529.8, 2585.3, 2663.6, 2663.8, 3166.3 |

S1's and S1b's eight readings have a median of 2642.1 ms, and so do all 14.

So the absolute line cannot tell the branch's cost from main's drift. The
drift is a tracker item, not this PR's.

**Two levers, each keeping every placement byte-identical** (`4364b834`; the
whole planting's digest, every card, kit placement and stone piece, the same
at seeds 717 and 1–3):

- **Off the critical path.** The island search reads only the land: its
  roads' field and height grid, and the rivers.
  - It now runs on the worker pool from the start of the kit's build, and
    the islands' stage waits for it after the arch, the heroes and the
    lanterns (27 ms on the Mac; the search 9 ms)
    (`presentation/map/landscape/kit.gd:525 (_seek_islands)`).
  - The stone's merge reads only the kit's placements and the land. It now
    gathers the pieces into their cells on the worker pool while the
    woodland is planted beside it, and the land's worker commits the meshes
    after (`presentation/map/landscape/kit.gd:738 (gather_stone)`,
    `presentation/map/landscape/land_stone.gd:129 (finish)`).
  - Gathering sends nothing to the renderer, so no two uploads overlap.
  - On the Mac, the islands' stage on the land's worker falls from 25.3 to
    17.1 ms, and the stone's from 9.4 to 2.0 ms.
- **Algorithmic waste.** Where the stages spend their time, on the Mac
  ([`mac/cold-open-levers.txt`](mac/cold-open-levers.txt)):
  - The island search spends 4.1 ms reading its grid of 2,560 cells, 2.2 ms
    on the depths and 1.5 ms on the edge's flood: linear passes, now off
    the critical path.
  - The merge appends each piece once, in the engine (`SurfaceTool.append_from`).
  - The islands' groups place in a few tries each (`_near`: the mark and at
    most twelve spots round it), each a clearance query through the kit's
    neighbour grid.
  - The sight the ruins are tested against (8 ms on the device) is the
    woodland's own, built once and shared with the planting, which no
    longer builds it: that is the woodland's −8 ms.

  I found no repeated scan, quadratic pair loop or allocation in a loop
  worth taking.

**On the iPad** (S1c, six cold opens a build, interleaved; every one in
[`device/batchS1c/land-stages.txt`](device/batchS1c/land-stages.txt)):

| | Main | Branch |
|---|---|---|
| Cold open, median | 2624.5 ms | **2607.3 ms** |
| The land's build, median | 1824.5 ms | 1858.5 ms (+34.0) |
| The kit | 458.5 ms | 516.5 ms (+58.0) |
| The woodland's planting | 131.0 ms | 131.0 ms |

In S1b, before the levers, the land's build was +142.5 ms and the kit
+106.5. On the land's worker the stone's stages now take:

| Stage | Time (S1c medians) |
|---|---|
| The islands' groups, with the ruins' sight built at the first gravestone (8.4 ms of it, the woodland's, shared) | 22.9 ms |
| Gravestones by the shrines | 4.6 ms |
| Gravestones on the verges | 2.1 ms |
| The walls | 1.6 ms |
| Committing the stone's meshes | 5.7 ms |
| Waiting for the island search | 0.0 ms |
| Waiting for the stone's gathering | 0.0 ms |

Off the land's worker, the island search takes 11.9 ms and the gathering
25.0 ms. Both are done before the land waits for them.

**The floor reached, and why.** What is left is the stone's own
placements, which are the picture: the islands' groups, the gravestones and
the walls, tried a few spots each, and the meshes committed to the
renderer. That is 36.9 ms of stages on the worker the cold open waits for;
8.4 ms of it is the sight, which the woodland no longer builds. The kit's
other stages read about 21 ms more than main's (the kit's +58.0 less those
stages). They place round the stone, testing each rock against the water
and the ruins' cards. None of this can run beside the woodland, which
plants round all of it.

The branch's cold open is 17.2 ms under main's in S1c. It is over the
absolute 2.6 s line by 7.3 ms, as main is by 24.5 ms. Main's own readings
in these batches run from 2498.6 to 3166.3 ms.

### Mac measurements

These were taken on the M1 Max with the map probe (`tools/map_trace/probe.gd`):

- the A12 Metal condition, lean, pad, seed 1, two steps in;
- 120-frame holds;
- main `711302a5` against the branch's code-final runtime, five interleaved
  pairs ([`mac/probe.txt`](mac/probe.txt)). The geometry was the same in
  every run.

The geometry is the device's: it is the same land and the same lean profile.

| View | Stage, main | Stage, branch | Live shadow, main | Live shadow, branch |
|---|---|---|---|---|
| Journey | 56,430 primitives, 79 draws | **86,882**, 78 | 5,031, 8 | 4,118, 2 |
| River | 54,718, 68 | 98,376, 68 | 3,758, 5 | 3,108, 1 |
| Close | 44,010, 58 | 74,400, 57 | 4,706, 6 | 4,118, 2 |
| Whole act | 109,134, 220 | 173,292, 214 | 5,928, 14 | 4,118, 2 |

- **Stage ≤ 130k primitives at the Journey view** (the plan's gate): 86,882.
  Draws stay within the plan's 95 there (78). Whole act is inside its 200k
  primitives. Its draws were over the plan's 150 on main already (220), and
  fall by six.
- **The stone itself**: 51–69k triangles a land at seeds 717 and 1–3
  ([`mac/placements.txt`](mac/placements.txt)), in 6–7 draws. At seed 717: 49 pieces,
  52,866 triangles, 47,932 vertices. At seed 1: 65 pieces, 69,178
  triangles. That is about 2.5 MiB of vertex and index buffers.
- **Video memory** (Metal's allocation, the Journey hold): main reads
  236.6 MiB in all five runs. The branch reads 251.2 in three runs
  (**+14.6 MiB**) and 259.2 in two (**+22.6 MiB**); every later branch run
  read the higher figure. The step between them is exactly 8.0 MiB. The
  delta has two parts ([`mac/vram-hunt.txt`](mac/vram-hunt.txt)):
  1. **Ours**, which Godot's own accounting holds: textures +5.0 MiB and
     buffers +2.0. Loaded one at a time on the Mac (S3TC), the stone's
     atlas costs 2.0 MiB, its normals 1.0, the strata 0.2, and the woodland
     atlas's growth 1.2; the merged stone's buffers are 1.9–2.5 MiB a land.
     That is about 7 MiB against the plan's 18 MiB line for hero meshes and
     textures (the atlas's growth belongs to the impostor atlases' 16).
     `LandStone`'s pieces, held arrays and material are statics that live
     for the process, as the woodland atlas does; only the per-land merged
     meshes go with their land.
  2. **The engine's transfer staging**, which Godot does not account:
     **+8 or +16 MiB**, held for the process. A RenderingDevice transfer
     worker's staging buffer grows to the next power of two above the
     largest single upload it has made and is never shrunk
     (Godot 4.7's `servers/rendering/rendering_device.cpp`, lines
     7221–7244; measured with plain uploads by `tools/staging_rule.gd.txt`). The woodland atlas's
     colour, grown to 2048×1776 by the ruins' 37 tiles, is 4.63 MiB with its
     mips (S3TC here, ETC2 on iOS, the same size). It was the only texture
     the map loads over 4 MiB; main's is 3.67 MiB. (Split into two layers
     since: [below](#the-woodland-atlas-in-two-layers).) Loaded alone, it costs
     +20.8 MiB, of which +16.0 is untracked; main's costs +3.9, none of it
     untracked (`tools/tex_cost.gd.txt`). Whether one or two loader threads'
     workers end up holding the larger buffer is decided by the timing of
     the threaded loads behind the launch screen. That is the 8 MiB step:
     it is set before the first frame and never moves, so it is not a
     transient caught by the measurement.

  The gate grades the total: R3.2's Journey-hold VRAM within +20 MiB of
  main, on the iPad's pooled median ([Gates](#gates)).
- **The land's build** (headless, seed 1, nine builds each, interleaved,
  medians, load 11–12; [`mac/land-time.txt`](mac/land-time.txt)):
  - the kit: 322 ms on main, 376 on the branch (+54);
  - the woodland: 99 and 92 (−7, because the planting reuses the kit's
    sight grid);
  - net: **+47 ms**.

  The stone's stages:
  - the island search, 8.9 ms;
  - the islands' groups, 26.1 (including the sight grid's 7.1);
  - the walls, 1.1;
  - the verge rows, 1.3;
  - the shrines' graves, 2.8;
  - the merge, 8.9.

  The kit asks 8,624 clearance questions against main's 6,984 (117 ms
  against 88).
- **Opens** (medians of the four clean pairs, load 7–12):
  - cold: 1,763.8 ms against 1,707.7 (+56);
  - warmed: 58.7 against 54.9;
  - reopen: 13.3–14.9 against 13.3–15.5.

  The device's opens are under [Gates](#gates).
- **Payload** (`tools/payload_report.py`, iOS; [`mac/payload.txt`](mac/payload.txt)):
  the pck estimate goes from 277.2 to 282.1 MiB, **+4.86 MiB** (the plan's
  gate: +10 MB).
  - The map-journey group gains 4.83 MiB (the stone's art and the woodland
    atlas's growth). Its budget is raised from 12 to 17 MiB, as R3.2 raised
    it for its own art.
  - The presentation group gains 42 KB (the stone's scripts and shaders).
    Its budget is raised from 3.2 to 3.3 MiB.

## Visual proof and conditions

- **The A12 condition**
  (`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 --rendering-driver metal --rendering-method mobile`),
  at pad, phone and desktop, en and zh-Hant lean and en full: **no "Error
  compiling shader"**, no script error and no other error, on main and the
  branch ([`mac/a12-and-reduce-motion.txt`](mac/a12-and-reduce-motion.txt)).
  The token gate's stop captures, Act I, every seed and shape: none either.
  Acts II–IV show main's own 10 lines a run on both builds (`map_mineral`'s
  sampler 17). `stone.gdshader` binds three samplers, none anisotropic.
- **Reduce Motion** at Close, two frames 1.5 s apart:
  - With it on, 12,801 pixels change on the branch and 10,288 on main.
    **Every one of them is the river's water**
    ([frame](frames/reduce-motion-close.png), in magenta, main on the left).
    The branch shows more water there because main's bank stood over the
    river.
  - With it off, 115,904 change on the branch and 116,513 on main.
  - The stone has no vertex stage and reads no time, and the ruins' cards
    never sway (`test_map_stone`).
- **The token gate** (`tools/map_token_gate.gd`): **0 failed** in every run.
  Act I at the head, seeds 717 and 1–3, phone and pad: worst margins
  1.006–1.025 against main's 1.006–1.023. Acts II–IV, seeds 1–3, at the
  earlier head `99a23e3c`: margins the same as main's
  ([`mac/token-gate.txt`](mac/token-gate.txt)).
- **The floor's GPU proof** (`tools/check_floor_bake.gd`) passes under the
  A12 condition with the stone casting into the bake
  ([`mac/floor-bake-check.txt`](mac/floor-bake-check.txt)).
- **Mutation proof**: 27 of 27 mutations of `test_map_stone`'s
  subject were caught, and 5 of 5 of the atlas split's: the atlas back on one
  page (`test_texture_uploads`), cards without their page, every tile read on
  the first page, and the woodland's and the floor's cards without their page
  (`test_map_wood`, `test_map_floor`), and 2 of 2 of the take's: a take that
  asks for its next texture while one is in flight, or only for its first
  (`test_map_wood`) ([`mac/mutations.txt`](mac/mutations.txt)). Earlier
  runs' survivors each led to a stricter check:
  - all gravestones gone, and rocks over the water: the rocks are now
    checked off the water at four seeds, and gravestones beyond the islands
    and beside the shrines;
  - cliffs by the waystones, once the pieces moved: the cliffs are now
    checked at all four seeds;
  - ruins that hide what stands behind them, and ruins placed blind to the
    woodland's sight: these were caught only by the count of ruins drawn.
    The test now asserts it directly on the land as placed: no road
    (sampled every 0.5 m), waystone or token behind a ruin's silhouette, and
    no shrine, gateway, rock or standing ruin placed behind an earlier ruin's
    card. Each mutation now fails on that assertion first.
- **Determinism**, committed: `test_map_stone` builds seed 717's land twice
  and checks that a digest of every kit placement, stone piece and woodland
  card is the same. An unseeded `randf_range` in the islands' rock yaw fails
  it.
- **The kit reproduces**: a re-run of `build_stone.py` gives every shipped
  and source file byte for byte, except the `.blend` masters. The impostor
  re-bake is the same run to run. `prepare_stone.py` and `prepare_floor.py`
  give their files byte for byte.

## Core gate

Run once on the final code and tests (`4364b834`), at `497bb692`, which adds only docs, on `711302a5`. Mac, 10 Oct, 21:47–22:52, each step waiting for load under 50 ([`mac/core-gate.txt`](mac/core-gate.txt)). It covers the core gate and every check `tools/ci_scope.py` selects for the PR's diff.

| Command | Exit | Last verdict line |
|---|---|---|
| `godot --version` | 0 | 4.7.2.stable.official.ed1daf0bf |
| `tools/check_imports.sh` | 0 | asset import OK |
| `tools/check_scripts.sh` | 0 | scripts OK (498 checked) |
| `godot --headless -s res://tests/run_all.gd` | 0 | PASS (158 tests) |
| `python3 -B tests/test_ci_scope.py` | 0 | OK |
| `python3 tools/check_store_dev_exclusion.py` | 0 | store-dev-exclusion OK |
| `tools/test_check_store_dev_exclusion.sh` | 0 | check_store_dev_exclusion regression tests OK (12 cases) |
| `python3 -B tools/check_export_paths.py --self-test` | 0 | export-paths self-test OK (10 cases) |
| `python3 -B tools/check_export_paths.py` | 0 | export-paths OK |
| `godot --headless -s res://tests/run_all.gd -- --tests=res://tests/test_release_identity.gd,res://tests/test_sentry_release.gd` | 0 | PASS (2 tests) |
| `python3 -B tools/check_anchors.py` | 1 | 11 anchors in this README drifted where `kit.gd` and `land_stone.gd` moved: the README of `497bb692`, before it was re-assembled. Re-assembled at this commit: `anchors OK` |
| `python3 -B tools/check_benchmark_freeze.py` | 0 | benchmark citations frozen (592 in 52 file(s)) |
| `python3 -B tools/build_site.py --self-test` | 0 | site self-test OK (20 seeded defects rejected; samples rendered exactly) |
| `python3 -B tools/build_site.py --check` | 0 | site is current: 7 files; the zh-Hant heading face covers all 54 display characters |
| `python3 -B tools/check_map_assets.py --self-test` | 0 | self-test OK (all injected gates failed; GPU silhouette uses _silhouette_noise) |
| `python3 -B tools/land_map_glb.py --self-test` | 0 | self-test OK (default land writes no provenance; accept is provenance-only) |
| `python3 -B tools/check_map_assets.py` | 0 | map assets OK (48 payload files; runtime landscape and retained asset library) |
| `python3 -B tools/check_map_quality_v2.py --self-test` | 0 | self-test OK (12 fail-closed mutation fixtures) |
| `python3 -B tools/check_map_quality_v2.py` | 0 | map quality v2 OK schema=1 contract=2.0.0 hard=18 soft=12 provisional=25 digest=4b54927afa7459be4b8b1bedc88fd8d653b8d9ba4ef8b79a53dce1282ecb0b5f |
| `python3 -B tests/test_performance_budget.py` | 0 | OK |
| `godot --headless -s res://tools/probe_map_seeds.gd -- --seeds=20` | 0 | map profiles OK (4 acts, 125978 candidate transforms; complete-layout proof is separate) |
| `godot --headless -s res://tests/choice_scroll_reachability.gd` | 0 | PASS choice scroll reachability (844x390) |
| `godot --headless -s res://tests/boss_relic_choice_containment.gd` | 0 | PASS boss relic choice containment (1180x820 en+zh-Hant) |
| `godot --headless -s res://tests/dawn_phone_containment.gd` | 0 | PASS dawn containment (en + zh-Hant, pad-landscape) |
| `godot --headless -s res://tests/measure_hud_location.gd` | 0 | MEASURE OK (0 clipped) |
| `godot --headless -s res://tests/event_phone_containment.gd` | 0 | PASS event containment (2024 rects, en + zh-Hant, 11 events, 3 shapes) |
| `python3 tools/payload_report.py` | 0 | TOTAL (pck estimate)                  283.0      400  ok |
| `python3 tools/ci_scope.py --changed-paths-nul <lane>/changed.nul --changed-gdscript-nul <lane>/changed-gd.nul --repository-root .` | 0 | every selected check is a row above |

27 of 28 steps exit 0 at `497bb692`; the anchors pass at this commit, with the freeze and the site (`benchmark citations frozen (592 in 52 file(s))`, `site is current: 7 files`). The same gate ran earlier at `871668f7` (code `2fd7b2d7`, the split): 28 of 28 exit 0, `PASS (158 tests)`; and at `d03e5c35` (code `4fa0cee8`): 28 of 28, `PASS (157 tests)`.

## Judgement calls

1. **The stone casts into the bake, not live** (settled by the orchestrator,
   5 Oct). R3.2 kept its slate outcrops as live casters. Their replacements
   are not, for two reasons:
   - the stone is 51–69k triangles a land (48–65 pieces at seeds 717 and
     1–3), which the live shadow pass's 15k primitives cannot hold;
   - the key light is static, so the baked normals and occlusion carry the
     stone's own form.

   Their shadows on the ground are in the floor's bake, with contact
   occlusion at each outcrop's foot. What is lost is a rock's shadow on the
   water and on another rock, which the floor does not hold: main's big bank
   by the river at seed 1 threw its shadow on the water; the branch's does
   not. At Close the outcrops do not read flat. Their baked normals and
   occlusion, moss caps and cracks give them form under the key, and the
   floor holds a contact shade at each foot ([outcrops](frames/crop-outcrops.jpg),
   [the tor](frames/crop-island.jpg)).
2. **One atlas and merged meshes.** All the hero stone shares one material,
   so it draws in a few draws, not a draw per kind per cell. The cost is one
   2048×1536 atlas, whose cells must be baked together.
3. **The ruins are cards.** They are re-baked into the woodland's atlas.
   They cost no draws and 1.25 MB, and they cast into the bake through their
   cards.
4. **Slate replaced in place.** The granite kinds keep the slate kinds'
   footprints, so the kit's composition, and the gateway's companions with
   it, stays close to R3.2's.
5. **Moss from the floor's own picture.** It adds no texture, and the stone's
   moss matches the ground's.
6. **A few tries, not a search.** The groups' placements try their mark and
   at most twelve spots round it; a verge row's stone tries its own spot
   only. The land is built on a worker the opening map waits for.
7. **The kit places ruins by the woodland's own sight rule** (above), so no
   ruin is placed and then left out, and the planting reuses the kit's grid.
8. **Gravestones either side of an island's rock, not before it**, and one
   beside a shrine, not a pair round it: in front, their cards would hide
   the rock or the shrine, and the woodland would leave them out.
9. **Rocks kept off the water.** Main's rule let a rock stand on the bank
   with its circle over the river (two to five a land). The branch keeps
   three quarters of each rock's radius off the water, which moves the
   gateway's companion bank at seed 1 back from the river.
10. **The woodland re-flows** (accepted by the orchestrator, 9 Oct; below).
11. **The stone's grade is the lane's**: `stone_tint` (0.8, 0.83, 0.88),
    `moss_tint` (1.15, 1.5, 0.6), the strata a third of the moss, the
    occlusion's share 0.75. The final balance against the north star belongs
    to R3.6's grade.

## For the owner: points to re-pick

Seen against the Act I target by the orchestrator on 9 Oct. Each is a lane
pick the owner may re-pick. None is tuned in this PR: R3.6 (light and grade)
is to revisit the stone's value against the target.

- **The stone's value and its moss.** The target's rocks are darker and more
  broken, and its moss a darker green. Ours are a paler grey with a bright
  olive-yellow cap: at Journey they are among the brightest things after the
  tokens.
- **The cliff tops at Close** read as striped tan ledges, where the target
  has dark broken rock.

## Open risks

1. **The cold open sits on the absolute line.** On the iPad (S1c) the
   branch's median is 2607.3 ms: 7.3 ms over R3.2's 2.6 s line, and 17.2 ms
   under main's 2624.5 in the same batch. After the two levers, the floor is
   the stone's placements on the land's worker: the islands' groups, the
   gravestones and walls, and committing the merged meshes, about 45 ms
   ([The cold open](#the-cold-open)). Main moves between batches on this
   iPad by more than that.
2. **Video memory's high mode survives on the iPad.** S1c passes at
   +17.3 MiB, but 7 of 14 of the branch's boots end 14–16 MiB above its low
   mode. That is untracked staging, from uploads that overlap outside the
   kit's own take (inference; [Video memory on the
   iPad](#video-memory-on-the-ipad)). A batch whose main reads low could put
   the pooled delta back over +20. The follow-ups:
   - name the overlapping uploads on the device;
   - bring the 23 shipped textures that already upload more than 4 MiB under
     it (the guard holds them, `tests/test_texture_uploads.gd`).
3. **The woodland re-flowed** (accepted by the orchestrator). Canopy cover
   at the pad's Journey now misses the 45% line by 1.4 points, as Whole act
   already did on main. This is accepted as the stone's cost; R3.6 is to
   re-measure the cover against the target with the stone in place.
4. **R2's pin tripwire on the phone** reads 1.04, a hundredth under its
   re-baseline of 1.05 (main 1.07), accepted by the orchestrator as a named
   move. The cause is land the method samples outside the token. The token
   gate, the legibility authority since #679, passes with the same margins.
5. **The stone's shadows are in the floor only**: no rock shades the water or
   another rock.
6. **The art is a set of lane picks**: the granite and strata pictures (one
   candidate each), the kit's sculpts and the stone's grade.
7. **Pre-existing, not this branch's**:
   - main's `map_mineral` A12 shader lines in Acts II–IV;
   - the exit-time "resources still in use" and RID-leak lines;
   - water that moves under Reduce Motion;
   - the export presets "Web Dev", "iOS Dev Review" and "Android Dev Review"
     (presets 0, 4 and 5) filter only `port_fixtures/*`. So a Dev Review or
     Web Dev build carries the stone kit's imported GLBs and ruin pictures
     under `tools/map_atelier/`, about 3.1 MiB as imported. The `.blend`
     masters and the source pictures sit under `.gdignore` and never
     import. The store presets (macOS, iOS, Android) and the QA app
     (`qa_export.sh`, on the iOS preset) exclude `tools/map_*`.

## Files

- `mac/`: the woodland and its gates, the pin diagnosis, the token gate, the
  A12 condition and Reduce Motion, the floor's GPU proof, the probe's
  geometry and opens, the land's build times, the placements, the payload,
  the mutations, the atlas split and the core gate.
- `device/`: the batches' logs, summaries and rows ([Gates](#gates)).
- `frames/`: the sheets, the crops, the pieces and cards, the conditions,
  the pin crops, the split's zoomed diff and the iPad 8 screenshot.
- `tools/`: the lane's scratch harnesses, never part of the game, as `.txt`.
  They include R3.1 b's and R3.2's own tools where they were reused (the
  cover count's `look.gd`, its `magenta.gdshader`, R2's pin mount `look4n.gd`
  with a listing added) and the woodland's `wood_dump.gd` and
  `wood_compare.py`.

### Safety

- Nothing was deleted on the iPad or on the Mac outside the lane's scratch
  folder (`.claude/worktrees/map-lane`) and its worktrees.
- A fresh install was simulated only by the nonce method; no cache was
  cleared.
- The QA app was the only app installed or launched, under the shared lock.
- The removals the lane's tools make are all inside its scratch folder, and
  each tool prints the folder it cleans before it runs:
  - the device helper (`tools/map_trace/device.zsh`) removes each launch's
    stale row and launch files and any cut-short trace, inside the batch's
    folder;
  - `qa_export.sh` clears the measuring worktree's `build/ios-qa`.
- One slip: a file list (7 KB) was written to `/tmp/r33files.txt` on 9 Oct
  at 01:52. The orchestrator checked it and removed it.

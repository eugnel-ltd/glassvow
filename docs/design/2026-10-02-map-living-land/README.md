# The map as a living land: concept dossier (Phase 1)

> **Superseded direction (3 October 2026).** The owner rejected concepts A, B and
> C below ("They all fail") and chose to revive the September journey rebuild
> instead: the archived woodland map with terrain derived from the routes, a
> filled river, arched bridges, seated 3D waystones and the cloaked pilgrim. That
> map is the base; the redesign, upgrade and polish happen on top of it. The
> audit and revival plan are in [revival.md](revival.md). The diagnosis (§1), the
> living-motion spec (§3) and the A12 and performance plans (§4, §6) still apply
> to the polish programme that follows the revival. The three concepts and
> their ranking (§2, §8) are kept only as a record.

Design lane, 2 to 3 October 2026. Owner instruction (James, 23:49 BST, 2 October):
the map "is nothing like an AAA commercial game"; the goal is "immersive,
dynamic, living, stunning, AAA class". Brief: orchestrator's `map-lane/brief.md`
(§3 vision binding, §4 constraints). This is Phase 1 only: diagnosis, three
concepts, motion, technical plan, assets, performance, risks and a ranked
recommendation. Nothing in the production tree changes on this branch.

Base: `origin/main` at `5b61932e`. Every frame here is Act I, seed 1, after two
steps (`--steps=2`), so the walked, open and cold road states are all on screen.
Layout digest in every frame, before and after: `a3ecf0fb9f42…af83c`. No concept
touched the layout.

## How the concept frames were made

Each concept frame is a **Godot proof-of-look on the production map**, not a
painting. A scratch runner (`proof/concept_look.gd.txt`) mounts the production
`WorldMapScreen` the same way `tools/preview_map.gd` does: real `MapLayoutFast`
layout, real `MapCameraRig` (−40°, orthographic, zoom stop 2), real waystone
pins, real `RunHud`. A concept dresser then re-dresses only the 3D world in that
running scene before the capture. Captured headed on the Mac (Metal, Mobile
renderer), at 1180×820 and 844×390.

What is honest and what is not:

- **Honest:** layout, camera, framing, pin positions and sizes, HUD, the
  light/fog/shadow pipeline, terrain form, scenery placement (the production
  scenery result, plus infill under the stated height cap), road-state data.
- **Placeholder:** every new mesh is a primitive built in code (stacked jagged
  cones for conifers, cylinders for cairns, boxes for lantern posts), and every
  texture is one already in `assets/art/map-atelier/` or `assets/art/stage/`. No
  image generation and no Blender was used in Phase 1. The proofs show structure,
  value and light, not final art; the asset bill says what replaces each
  placeholder.
- The proof sources are kept as `.txt` under `proof/` (the `docs/` tree is
  `.gdignore`d, and `tools/check_scripts.sh` would sweep a tracked `.gd`). To rerun:
  copy them into a scratch folder under `res://` with their real extensions and run
  `godot --path . -s res://scratch_lane/concept_look.gd -- --concept=a --steps=2
  --shape=pad-landscape --output=/tmp/a.png` (never `--headless`). Add `--pose=overview`
  for the establishing frame, `--dump` for the facts in §1 and `--measure` for the
  rest-render numbers in §6.

### The six concept frames

| | pad 1180×820 | phone 844×390 |
|---|---|---|
| before (main) | [`frames/before-1180x820.png`](frames/before-1180x820.png) | [`frames/before-844x390.png`](frames/before-844x390.png) |
| A, The Lantern Road | [`frames/a-1180x820.png`](frames/a-1180x820.png) | [`frames/a-844x390.png`](frames/a-844x390.png) |
| B, The Leaded Pane | [`frames/b-1180x820.png`](frames/b-1180x820.png) | [`frames/b-844x390.png`](frames/b-844x390.png) |
| C, The Painted Road | [`frames/c-1180x820.png`](frames/c-1180x820.png) | [`frames/c-844x390.png`](frames/c-844x390.png) |

Contact sheets: [`frames/sheet-1180x820.jpg`](frames/sheet-1180x820.jpg),
[`frames/sheet-844x390.jpg`](frames/sheet-844x390.jpg). The whole act at an
establishing framing (ortho size 66 m, pins hidden, so outside every governed
zoom stop): [`frames/sheet-overview.jpg`](frames/sheet-overview.jpg) and
`frames/overview-{before,a,b,c}.jpg`.

Note on the brief's before-stills: `scratchpad/map-lane/before/map-phone-seed*.png`
are 1180×820, identical in size to the pad stills, so the phone shape did not
apply when they were captured. The phone frames here were recaptured at a true
844×390.

---

## 1. Diagnosis: what the current map is, measured

The brief's §2 reading holds. Measurements below are from `--dump` and from
reading the production path, at seed 1, Act I.

**1. The ground is flat to within 27 mm.** `MapLandscape.ground_point` lifts the
ground by `noise × 0.025 m`. The generated heath spans y −0.047 to −0.020 m across a
97 × 55 m act. Under one directional key, N·L is the same everywhere, so the
ground can only show its texture, never a form. There is no horizon, sky, slope
or depth cue. The ravines are the only relief: nine strata rings stepping 5.8 m
down to a flat basin plane.

**2. Nothing can move, by design.** `MapScene` renders the 3D stage for three
frames after any input and then sets `SubViewport.UPDATE_ONCE`. At rest the land
is a frozen texture. The rest cost is zero, which is what kept the A12 budget, and
the freeze is asserted by `tests/test_map_scene.gd:94` and
`tests/test_map_landscape.gd:65`. Any living motion replaces this rest contract
(see §4, decision D2).

**3. Props are unlit paper.** Every scenery and hero prop except the slate
cluster is a painted card (`MapLandscapeAssets._card`): an unshaded,
alpha-scissor quad with the 40° tilt baked into its vertices. A card receives no
light, and `MapLandscape.batch` casts a shadow only when a material override is
set, which cards do not have, so no card casts one. The key light has
`shadow_enabled = true`, but only strata, ledges, the slate GLB and bridge
masonry cast. Grounding is one radial-gradient decal per prop ("Contact shade").
Scale is per card (`_spec`): the copse is 4.4 m, the tree 3.6 m, the Vigil 4.5 m
and the terminus tower 5.6 m, so a chapel and a single tree are almost the same
height.

**4. The dressing is sparse because the reserves eat it.** Of 1,828 seeded
candidates, 247 are accepted (13.5%). Rejections: node reserve 901 (49%),
accepted-footprint overlap 348, land edge 231, hero zone 70, road corridor 31.
Of the 247, 100 are 0.85 m heath tufts. That leaves about 5 props per 100 m² over
roughly 5,000 m² of plate, which is the "sparse random scatter" the owner sees.

**5. The road-state language is nearly invisible.** Waylight beads have a radius
of 0.065 m (`MapWaylightTracer.BEAD_RADIUS_M`). At the default zoom on pad
(41 px/m) a bead is about 2.7 px in radius. The walked, open and cold states
differ only in bead colour. The road itself is a 1.04 m paving ribbon with
inset flagstones every 0.65 m, which reads as a string of beads (the brief's
item 3).

**6. A third of the act per frame, and the act never seen whole.** At the
default stop (20 m) the pad frame covers 28.8 × 31.2 m of ground (x −44.5 to
−15.7), about 34% of the ~84 m journey from the Vigil to the terminus. Even the
far stop (28 m) shows about 40 m. Seen whole (`overview-before.jpg`), the land
is three flat slabs with a strata skirt over a void, and the near and far plate
edges come into view at the far stop and the pan bounds.

**7. Most of the kept VRAM is uncompressed cards.** `_picture` decodes each
atelier PNG to an uncompressed RGBA8 `ImageTexture` with mipmaps, on purpose, to
keep the stored pixels. Act I's seven pictures (two ground tiles, three scenery
cards, the Vigil, the terminus) total **54 MiB**, which is almost all of the
measured 44–61 MiB kept per act. ASTC 4×4 would cut that to about 14 MiB and fund
everything new below.

**8. Half the shader files the brief names are off the production path.**
The live ground, strata, paths and water all use `map_mineral.gdshader` (shaded,
Burley diffuse, two samplers). `map_ground.gdshader`, `map_prop.gdshader`,
`map_vigil.gdshader` and the per-act grade PNGs are referenced only by
`tools/map_scene_proxy.gd` and `tools/probe_map_shaders.gd`. `map_ground`'s
header ("~85% of every map frame", "`shadow_enabled` appears nowhere in this
tree") is stale: `MapScene._add_key` enables shadows. Per-act identity is four
colours in `MapRegions` (`LAND_KEY`, `LAND_AMBIENT`, `LAND_TINT`, `WATER`).
`MapRegions.weather` is assigned and read only by tests; nothing on the map draws weather.

**9. Where the frame time goes.** At rest it goes nowhere, because the stage is
frozen. While panning on the Mac proxy (`preview_map.gd --measure`, pad), the
viewport CPU p95 is 1.03 ms. Forced to render continuously
(`concept_look --measure`), the stage draws 38 calls and 78k primitives, plus 10
calls and 46k primitives in the shadow pass. Metal exposes no GPU timer, and the
frame interval stays pinned near 8.3 ms (the 120 Hz display) whatever the scene
holds, so **the Mac proxy cannot rank GPU cost**. §6 says what replaces it.

**The binding conflict in the vision.** §3 asks for "the whole act readable in
one frame at the default zoom". The 40° tilt and the four zoom stops are compiled
into the layout itself (`MapLayoutFastSeating.COT_TILT`, `FAR_PX_PER_M_LANE`) and
into the quality registry (`content/map/map-quality-v2.json`: `tilt_deg`,
`zoom_stops_m`), both frozen by §4. The contract also forbids it on its own
terms. To fit an ~84 m journey across 844 px, a phone frame needs about 10 px/m.
The 6 m lane pitch then projects to 3.86 m × 10 = 39 px, under the 44 px touch
floor and well under the 60 px ink pitch the seating enforces. On pad (14 px/m)
it is 54 px: enough for touch, short of ink. Every concept below therefore keeps
the governed default zoom. It shows the whole act as a non-interactive
**establishing shot** on the first open of an act (decision D1).

---

## 2. Three concepts

All three keep the same layout, pins, HUD and governed camera poses. They differ
in how the camera is used, what the ground is, and what stands on it.

### A. The Lantern Road (real land, real light)

`frames/a-1180x820.png`, `frames/a-844x390.png`, `frames/overview-a.jpg`

- **Camera.** The governed rig is unchanged (orthographic −40°, stops 12/16/20/28).
  Two additions: an **establishing shot** on the first open of an act (the whole
  act framed as in `overview-a.jpg`, the lanterns of the open road kindling, then
  a 2–2.5 s glide to the focused pose; any tap skips it; Reduce Motion cuts it),
  and **the Flame as the camera's warm light**, a real light at the current
  waystone that colours the near ground in the run's flame colour.
- **Terrain.** Real form under the layout. Height is a function of distance to the
  nearest road or waystone (zero on every road and node, so the layout and pin
  projection are untouched), plus seeded hills in the open land, rising wooded
  ridges past the far edge that close the top of the frame, a near edge that drops
  to a drifting cloud sea, and ravine banks that meet the existing strata. One
  rule guards readability: **a rise never exceeds `(d − 1.5) × 0.5` metres at
  distance `d` from a road**, so no slope hides a road behind it. The ground is lit
  by one moon key with cast shadows, and its shader blends painted floor and rock
  tiles by slope and by road wear.
- **Dressing.** 3D groves on the production scenery placements: each copse becomes
  7–11 conifers inside its card footprint and under its card height, a tree becomes
  one or two, a heath tuft becomes a few shrubs. Seeded infill fills open land
  where the noise puts a grove, with every crown capped at
  `(d − 1.2) / 1.19` m (the 40° cot), so no crown can reach a road or a waystone's
  touch region up-screen. Forest walls close the act ends and the far ridge. All
  of it is lit and casts shadows.
- **Road.** A worn earth path with ragged verges (`road_a`), and iron lantern posts
  every 3.6 m on alternate sides. The open road's lanterns burn (real light pools),
  the walked road's glow settled amber, and the cold road's lanterns are dark
  embers. These posts are the waylights, at a readable size. Bridges keep their
  masonry.
- **Waystones.** A stone cairn under every anchor, kindled with a lantern light
  when reachable; the Flame stands at the current one. The 2D pin keeps its
  governed hit region; Phase 2 slims its visual to a glass lens over the cairn's
  lantern (§4).
- **Read.** The only concept that answers §3 points 1–6 literally: terrain, ground
  contact and shadow, a road that is a road, lanterns, in-world waystones, light
  that carries act identity. It costs the most (§6).

### B. The Leaded Pane (the land as a backlit window)

`frames/b-1180x820.png`, `frames/b-844x390.png`, `frames/overview-b.jpg`

- **Camera.** The same governed rig, but the frame is an **object**: the act is a
  stained-glass window laid on the pilgrim's table, with a lead-and-iron frame,
  dark wood and two candles, visible at the pan bounds and in the establishing
  shot.
- **Terrain.** None: one flat pane cut into glass along the layout. A single
  procedural Voronoi shader reads one data texture (road distance, road state,
  grove density, waystone distance) at each pane's centre, so every pane takes one
  flat colour. Honey glass marks the open road, settled gold the walked road and
  smoked lilac the roads not yet reachable, each outlined in gilt lead. Viridian and
  crimson panes stand where groves stand, the ravines are cobalt water glass, and
  each waystone sits in a lead roundel.
- **Dressing.** Inlaid glass, not standing objects; only the hero landmarks stand.
- **Living.** The backlight breathes, a slow light sweep crosses the glass, candle
  flicker throws moving highlights, and motes drift in the candle beams.
- **Read.** The most distinctive, the most on-brand (the pins already are glass
  medallions), the clearest road-state language, and by far the cheapest (§6). But
  it is texture, not terrain, and a window, not a land the pilgrim walks: it
  departs from §3 points 1 and 2 on purpose.

### C. The Painted Road (the painted plate, deepened)

`frames/c-1180x820.png`, `frames/c-844x390.png`, `frames/overview-c.jpg`

- **Camera.** The same governed rig plus a **screen-space parallax stack**: a
  painted night-sky band under the HUD (gradient, moon, the act's backdrop ridge
  sliding at 0.15× the pan), and near foreground silhouettes at the bottom corners
  sliding at 1.3× the pan. Both are drawn between the land and the pins, so
  tappability is untouched.
- **Terrain.** Flat, as today, but painted: an unshaded night plate in which the
  painting carries its own light. It has two painted tiles at two scales, large
  colour masses, a paler corridor along every road, warm lantern pools on the open
  road, and cooled shadow pooled under groves.
- **Dressing.** The house-style painted cards stay, moonlit and doubled in density
  by the same height-capped infill as A; lantern glows float along the open road.
- **Read.** The cheapest evolution of the shipping pipeline, and it keeps the
  painted look. But the cards remain unlit paper, nothing stands in real light, and
  the parallax layers read as a vignette rather than as depth. It is the current
  map made handsome, not a different class of map.

### Acts II–IV, in brief

| | A, The Lantern Road | B, The Leaded Pane | C, The Painted Road |
|---|---|---|---|
| **II, The Drowned City** | A flooded lowland: shallow water planes fill the low ground off the roads, with roads on causeways and the ravines as tidal channels. Drowned cloister ruins and arcades stand half-submerged, under a cold teal key, low mist and steady drip rings. Lanterns hang on mooring posts. | Teal, sea-green and cobalt glass. Water panes are the majority; the road is the honey thread across it. | Teal night plate, mist bands across the sky band, drowned cloister cards. |
| **III, The Obsidian Court** | A broken black-glass plain: obsidian blades and shard fields, cracks with ember-red emissive seams, a violet storm key with occasional lightning (the key light's energy spikes), heat shimmer over the seams. | Black and violet glass with ember lead seams; panes splinter smaller toward the court. | Storm sky band with flashes; obsidian blade cards. |
| **IV, The Mirrored Road** | Polished stone obelisks with glass insets line the roads (the act backdrop's avenue), mirror pools reflect the lanterns, a rose-gold dawn key throws long shadows, and embers drift the wrong way, rising. | Rose and gold glass, mirror-silver panes, the brightest window of the four. | Dawn band, memorial cards. |

---

## 3. Living motion

The spec below is for A, the recommendation; B's and C's are noted in §2.
Everything here is shader- or particle-driven; no node moves on the CPU per
frame. The proof already renders the ash, embers, cloud shadow and mist drift
(look at `TIME` in `proof/terrain_a.gdshader.txt` and `proof/mist.gdshader.txt`).

| What moves | How | Cost | Reduce Motion |
|---|---|---|---|
| Lantern flicker (all acts) | Emissive and light energy times a two-octave noise of `TIME` and a per-lantern hash. Real lights only for the Flame and the ≤ 6 open-road lanterns nearest the focus; the other pools are painted into the ground's light channel and flicker in the same shader. | ALU only | **Kept** (the one motion that stays) |
| Cloud shadow | The terrain shader darkens by a value noise scrolling at about 1 m/s across the act. | ~10 ALU per pixel | Off |
| Trees breathing | Vertex sway, weighted by the vertex colour's alpha (zero at the trunk), at 0.3–0.6 Hz with a per-instance phase from the instance colour. | Vertex ALU | Off |
| Mist and the cloud sea | Two transparent planes, each with two drifting value-noise octaves, kept to the ravines and the near edge to bound overdraw. | Overdraw-bound; the main A12 risk | Static |
| Act I, ash fall and embers | `GPUParticles3D`, about 420 ash flakes and 160 embers, billboard quads over the visible area only. | Under 1,200 triangles | Off |
| Act II, drowned mist and drip | Ripple rings on the water shader (`TIME`-driven rings at hashed points), a denser low mist, slow drip particles. | ALU plus one particle system | Off |
| Act III, storm and heat | Lightning as a key-light energy envelope every 6–14 s, ember-seam pulse in the emissive, heat shimmer over the seams. The shimmer is the act's **one** `hint_screen_texture` reader. | One screen read in Act III only | Lightning off, seams static |
| Act IV, inverted embers | Rising ember particles, mirror pools that ripple and catch the lanterns, a slow drift in the dawn key's warmth. | Particles plus ALU | Off |
| The road's state change | When a step lands, the next road's lanterns kindle in sequence over about 0.6 s; the walked road settles to amber. | Event-driven, not idle | Instant |

**Rest cadence.** Idle motion means the stage renders at rest. Proposal: render
the 3D stage at **30 Hz at rest** (every other frame) and 60 Hz during input,
travel and the establishing shot. Every rest motion in the table is slow enough that 30
Hz is invisible, and it halves the rest cost. Under Reduce Motion only the
lantern flicker remains, at 15 Hz.

---

## 4. Technical plan (for A)

**Terrain source: a displacement texture, not a generated mesh.** The proof built
chunked meshes in GDScript, which took 0.36 s on an M1 Max for terrain, groves and
lanterns together, a multiple of that on an A12, and outside the 0.5 s
first-open budget. Production instead uses:

- **One static grid mesh per act**, built once and layout-independent: about
  200 × 116 vertices at 0.5 m, cut into 8 × 8 m chunks for culling and for the
  Mobile renderer's per-object light limit.
- **A per-layout data texture**, RGBA8 at 210 × 122. Channels: road/node distance,
  road state, grove density, lantern light. It comes from a chamfer distance
  transform: concept B's proof built four such fields and its data texture in
  about 120 ms of GDScript on the M1 Max, so production moves it to the bind
  worker or native code.
- **Height computed in the vertex shader** from that texture plus one tiling noise
  texture, with normals from finite differences in the vertex stage. The shadow
  pass runs the same vertex function, so shadows follow the form.
- **Props get their Y on the CPU** from the same height function, written
  bit-for-bit in GDScript.

The data texture joins `MapScene._bound["bake"]`, so a reopen re-binds it at no
cost and the kept-screen path does not change. The noise is a deterministic
polynomial, as in `MapRavine.sine`, so every device gets the same height wherever
height feeds scenery acceptance.

**Scenery acceptance stays the production rule, made terrain-aware.**
`_selection_footprint` extrudes a prop's silhouette by `grounded_height / tan 40°`.
With terrain, the extrusion uses `terrain_y + grounded_height`. Infill candidates
join the existing seeded candidate set, so they pass through the same
`_scenery_rejection` (node reserve, road corridor, hero zone, footprint), not
through the proof's approximate cap. This changes scenery acceptance and therefore
its digests. It is dressing, allowed by §4 in an explicit commit that says why.
`MapLayoutFast`, `MapLayoutResult`, the canonical input, the quality registry
and the layout digests do not change. The quality evaluator's silhouette checks
read the same extruded footprints, so tappability and clearance stay governed at
every shape and stop.

**Lighting and shadow under the A12 budget:**

- **Key light.** One `DirectionalLight3D` per act (colour, angle and energy per
  act), orthogonal shadow, 2048² atlas, max distance fitted to the far stop.
- **Shadow casters are low-poly proxies.** Each visible tree casts no shadow; a
  12-triangle cone with `SHADOW_CASTING_SETTING_SHADOWS_ONLY` casts for it. The
  proof cast 413k shadow primitives; the target is 60k or fewer.
- **Fallback if the A12 misses P95.** Stamp elongated shadow ellipses along the key
  direction into a shadow channel of the data texture at bind time, and turn off
  real-time shadows. The scene is static, so the result reads the same.
- **Lanterns.** The Mobile renderer lights at most 8 omni lights per mesh. Real
  `OmniLight3D`s go only to the Flame and the ≤ 6 nearest open-road lanterns; every
  other lantern pool is painted into the light channel. The terrain chunks keep any
  one mesh under the limit.
- **Environment per act.** Exponential depth fog plus height fog (the ravines fill
  with mist for free), ACES tonemap, and glow restricted to two levels at half
  resolution. The per-act grade PNGs are retired; `MapRegions` gains the key,
  fog, sky and weather rows.

**Material and sampler budget** (engine samplers included, A12 Metal limit 16, lane
cap 12 per stage):

| Shader | Fragment samplers (material) | Vertex samplers | Notes |
|---|---|---|---|
| Terrain | floor, rock, ash (3 tiles; one array texture if needed) + data (1) | data + noise (2) | Shaded; the engine adds its shadow and light samplers |
| Road | rock (1) + data (1) | — | Shaded |
| Foliage and props | per-act atlas (1) | — | Shaded, vertex sway |
| Mist and cloud sea | 0 (ALU noise) | — | Unshaded, depth-draw never |
| Water (Acts II, IV) | 1 normal tile + data | — | No screen read |
| Act III shimmer | screen texture (the 1 reader) | — | Act III only |

Every new spatial shader is checked on the Mac with
`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 tools/shot.sh --rendering-driver metal
--onboard=map-select --seed=1 --shape=pad --shot=/tmp/x.png`; any
`Error compiling shader` is a blocker.

**Waystones in-world, still tappable.** Under each anchor stands a type-shaped
cairn or shrine for the eight keys (crossed-blades stone, horned stone for elite,
hearth for rest, lantern stall for shop, chest cairn, rune stone for event,
monument, the boss gate). On top sits a leaded glass lantern whose glass carries
the node hue. When reachable it is kindled, with a light and an emissive pulse.
Anchors stay at y = 0 and the terrain is zero there, so `MapPinProjection` is
unchanged. `GlassWaystone` keeps its hit region (≥ 44 px, `pin_at`/`_pin_hit`) and
its focus ring, and draws a lighter visual (the emblem in a glass lens, without the
dark disc) inside the governed `ink_radius_px`. Drawing smaller ink than the
calibrated radius only increases clearance. The chip band and the RunHud are not
touched.

**Kept-screen and prefetch.**

- `MapLandscapeAssets.prefetch` already decodes an act's pictures on a worker. It
  also loads the act's GLB kits and atlases through `ResourceLoader` threaded
  loads.
- The atelier PNGs move to ASTC import, through `ResourceLoader` rather than the
  `Image` path. This frees about 40 MiB per act, and the importer's edge bleed
  replaces `fix_alpha_edges`.
- The terrain grid is shared across acts. Per-layout state (data texture,
  instance transforms) lives in the bind cache, so `tests/test_map_open_cache.gd`,
  `tests/test_map_landscape_prefetch.gd` and `tests/test_map_keep_screen.gd` keep
  their meaning. The 30 Hz rest cadence stops while the screen is parked
  (`NOTIFICATION_EXIT_TREE` already parks the stage).

---

## 5. Asset bill (A)

Each pick lands in `assets/art/map/…` marked "lane pick, owner re-pick open", with
an `docs/art-ledger.md` row carrying the prompt or Blender recipe. Every candidate
and a labelled contact sheet stay in the design folder. No Codex is used for
design. Drafts use the house landscape style block from `docs/art-ledger.md`
("Serious cartoon-gothic stained-glass game art: night landscape, chunky dark
silhouettes, 3-5 large jewel-tone colour masses, matte painterly texture, warm
amber lantern light, soft controlled glow…").

| # | Asset | Per act | Tool | Draft prompt or recipe |
|---|---|---|---|---|
| 1 | Ground tiles: floor, rock, wear (seamless, top-down, de-lit, 1024², ASTC) | 3 | `image-gen` | "Seamless tileable top-down texture, de-lit, no shadows, no perspective: {Act I ash-strewn forest floor of dark umber loam, grey ash drifts, rust needles, sparse teal moss}. Matte painterly, large shapes, low-frequency variation, no repeating motifs, no text." |
| 2 | Tree and plant kit (3–4 species, 300–600 tris, sway weight in vertex alpha) | 3–4 | Blender (scripted recipe) + `image-gen` atlas | Act I: tiered fir, crimson-rust fir, burnt ash snag, heather clump. Act II: drowned willow, root arch, reed bed. Act III: obsidian blade cluster, shard fan, cracked plinth. Act IV: obelisk with glass inset, memorial stone, dawn birch. Atlas prompt: "Painted foliage and bark atlas on a flat grid, stained-glass jewel tones, chunky dark lead outlines, matte, de-lit, transparent background." |
| 3 | Rock and ruin kit (slate outcrops, ruined walls, arches) | 4–6 | Blender | Bevelled, chunky low-poly; shares the act atlas. |
| 4 | Lantern post, mooring post (II), seam brazier (III), obelisk lamp (IV) | 1 | Blender | Iron post, a four-pane glass head with emissive glass; about 150 tris. |
| 5 | Waystone shrines, eight type keys | shared, with per-act stone tint | Blender + `image-gen` glyph decals | One base cairn and eight crowns, readable at 40 px from the tilted camera. |
| 6 | Hero landmarks in 3D: Vigil, the four termini | 1 | Blender, after owner sight of the painted cards | The cards stay until each mesh is approved. |
| 7 | Particle sprites: ash flake, ember, drip ring, rising ember | 1–2 | `grok-media` (budget) | "4×4 sprite sheet of soft {ash flakes}, white on transparent, painterly, no text." |
| 8 | Sky and cloud-sea noise | 0 | Procedural (shader) | — |
| 9 | Water normal tile (Acts II, IV) | 1 | `image-gen` or procedural | Seamless normal map, gentle ripples. |

Volume: about 9 Blender meshes per act plus 9 shared, about 4 painted textures
per act, and 4 sprite sheets. Estimated VRAM per kept act after ASTC: about 14 MiB
of existing cards, about 10 MiB of new tiles and atlases, an 8 MiB shadow map
(2048² × 16-bit) and about 6 MiB of glow buffers. That is roughly 40 MiB against
the 80 MiB cap.

---

## 6. Performance plan

**Proof numbers** (Mac M1 Max, Mobile renderer, pad, continuous render at rest;
`concept_look --measure`). These count geometry; they do not time the GPU.

| | Stage draw calls | Stage primitives | Shadow calls | Shadow primitives |
|---|---|---|---|---|
| before | 38 | 78,246 | 10 | 45,754 |
| A proof | 71 | 434,974 | 50 | 413,346 |
| B proof | 26 | 21,914 | 6 | 10,800 |
| C proof | 39 | 49,342 | 9 | 23,866 |

A's proof is deliberately unoptimised: every tree is a full mesh in both passes,
with no LOD and no proxies. **Phase 2 targets at the default stop: stage ≤ 60
calls and ≤ 150k primitives, shadow ≤ 20 calls and ≤ 60k primitives**, via shadow
proxies, shared per-species MultiMeshes, terrain chunk culling and cross-quad
impostors for the far ridge forest.

**Gates (from §4 of the brief), and how each is measured:**

- First warmed open ≤ 0.5 s and reopen ≤ 50 ms, Mac proxy then device:
  `tools/shot.sh --map --map-timing --seed=1` (`MAP_OPEN` rows) and
  `tools/bench_map_open.gd`.
- Kept VRAM ≤ 80 MiB per act: the `MAP_KEPT` rows (`kept_mib`, `act_mib`) and
  `tools/bench_map_assets.gd`.
- Map at rest P95 ≤ 8 ms on the Mac proxy: a new `tools/bench_map_rest.gd`, the
  scratch runner's `_measure_rest` promoted. It records frame p50/p95 under
  continuous render, plus stage and shadow draw calls and primitives from
  `RenderingServer.viewport_get_render_info`, so the geometry budget is gated
  deterministically even where Metal has no GPU timer.
- **The Mac cannot rank GPU cost.** Frame intervals stay near 8.3 ms whatever the
  scene holds. So the device is the GPU gate: an A12 run through the `devicectl`
  recipe in memory (engine arguments before `--`), reading the bench file for rest
  P95 and frame pacing (rc-bar P95 ≤ 16.67 ms) at 30 Hz rest and at 60 Hz pan.
- A12 shader compile: the `GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1` capture given in §4,
  once per new shader and once on the final candidate.
- Layout invariance: `tests/test_map_layout_fast.gd` passes without edits; every
  capture prints the same `layout_digest`.

**Order of measurement in Phase 2:** first terrain plus lighting alone, on the
device, before any dressing (the floor cost); then each layer (groves, lanterns,
mist, particles, glow) as a delta. A layer that breaks the budget is cut or
re-planned before the next one goes on.

---

## 7. Risks

1. **A12 fill rate at rest.** Continuous rendering of 2160 × 1620 with shaded
   terrain, mist overdraw and glow is the largest unknown. Mitigations: the 30 Hz
   rest cadence, a stage render scale (`MapScene.OVERSAMPLE` < 1 on the device),
   bounded mist coverage, two glow levels.
2. **Shadow pass cost.** Mitigated by proxies; the stamped-shadow fallback removes
   it entirely.
3. **Mobile per-object light limit (8).** Mitigated by chunked terrain and painted
   pools; only the nearest lanterns get real lights.
4. **Occlusion and tappability.** Terrain and crowns could cover roads or pins.
   Guarded by the rise rule, terrain-aware extrusion in the production scenery
   rejection, and the quality evaluator at every shape and stop. Scenery digests
   change in an explicit commit.
5. **Cross-device determinism.** If height feeds acceptance through
   `FastNoiseLite`, float drift could change scenery digests by device.
   Mitigation: polynomial noise as in `MapRavine.sine`, with heights quantised
   before acceptance.
6. **Art consistency.** Lit 3D groves next to painted, unlit hero cards (the Vigil
   and the termini, visible in `a-1180x820.png`) read as two worlds. The hero landmarks
   need either 3D meshes or a lit-card treatment, and the owner sees them first.
7. **Asset volume and quality.** The proof's primitives are not the bar; four acts
   of kits is the biggest schedule item. Mitigation: Act I first to full quality,
   reviewed, then II–IV.
8. **The rest contract.** Two tests assert the frozen stage at rest; living motion
   replaces that contract (D2).
9. **The establishing shot versus first-run hints and the kept screen.** It plays
   only on an act's first open, never on a reopen, is skippable, and is cut under
   Reduce Motion; the opening lane's first-run hint waits for it to end.
10. **Parallel lanes.** No overlap with the opening lane (`presentation/title/`,
    `presentation/ui/`) or the SFX lane. If the lantern kindle wants a sound, that
    is a request to the SFX lane, not an edit.

---

## 8. Ranked recommendation

1. **A, The Lantern Road, with B's road language folded in.** It is the only
   concept that is a land: form, ground contact, real light and shadow, lanterns,
   in-world waystones, and weather that differs by act. It is the one that answers
   "immersive, dynamic, living" and "fixed camera 3D" as the owner put them. From
   B it takes the glass road-state language: the lantern glass burns honey on the
   open road, settles to gold on the walked road and stays smoked on cold roads,
   and each waystone lantern is a small leaded roundel in its node hue. It costs
   the most; the plan in §4 and §6 keeps it under the A12 gates or names the
   fallback.
2. **C, The Painted Road**, as the fallback if A's device floor (terrain and light
   alone) fails the A12 budget. It is cheap and safe, but it stays painted paper.
3. **B, The Leaded Pane** ranks third as a map, because it deliberately leaves the
   vision (texture, not land), though it is the most striking frame of the three.
   Keep it as a reusable idea, for example an act-complete "window of the road
   walked".

## Decisions for the orchestrator (Phase 2 needs D1 and D2)

- **D1. "Whole act in one frame at the default zoom."** The governed tilt and stops
  (compiled into the layout and the registry, both frozen) and the phone touch
  contract make it impossible at the default zoom (§1). Proposal: the default zoom
  stays, and the whole act is shown as the first-open establishing shot. Accept?
- **D2. Rest contract.** Living motion needs the stage to render at rest.
  Proposal: replace the frozen rest (`UPDATE_ONCE`, asserted at
  `tests/test_map_scene.gd:94` and `tests/test_map_landscape.gd:65`) with a
  throttled rest at 30 Hz (15 Hz under Reduce Motion), and change those two tests
  in an explicit commit. Accept?
- D3 (not blocking). The scenery cards and, after owner sight, the hero cards are
  replaced by Blender meshes marked "lane pick, owner re-pick open".

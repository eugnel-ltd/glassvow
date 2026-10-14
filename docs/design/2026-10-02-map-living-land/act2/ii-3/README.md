# #660 II.3: Act II goes live (water, stone and light)

Lane `map-ii3`, 14 October 2026. Plan: `act2-plan.md` §3 II.3 (the lane folder).
Base: `origin/main` at `6ee88a9b` (II.2).

## What changed

Players now reach Act II's journey land, the Sunken City: the record's routes
as masonry causeways over one still water sheet (II.2), lit as a drowned
library city at night. It is the first Act II that reads as the identity in
the plan's §1 rather than the painted plate. The art is a lane pick, owner
re-pick open (`docs/art-ledger.md`, "#660 II.3").

- **Masonry atlas.** Two tileable layers, ashlar over paving, each 2 m × 1 m,
  made by `tools/map_atelier/journey/masonry/build_masonry.py` (byte for byte
  on a re-run) and loaded through the stone pipeline's loader steps
  (`causeway/city_kit.gd`, as R3.3's `LandStone`). `masonry.gdshader` reads
  the paving along each deck's own UV and the ashlar projected on the world,
  with the stone wet near the water. Three samplers.
- **City water.** R3.4's water made a still sheet (`city_water.gdshader`):
  darker channels on `MapRavine`'s line, a broken wash at every wall's foot,
  the walls mirrored toward the viewer, a cool sky at a grazing angle, glints,
  and the lanterns' and the pilgrim's flame's reflections in broken columns.
  No screen or depth read; one sampler, the land's light mask
  (`causeway/city_mask.gd`: the masonry's footprint, the lamps' pools and
  their reflections, painted on the land's worker).
- **Light.** `MapCausewayLandscape.light`: a pale cool key from Act I's
  direction, a teal fill, the lanterns' bloom; a cold far haze for the
  tilt-shift (`haze()`, per land class). Amber stays on the pilgrim's flame,
  whose pool now lights the paving and parapets round him, and on the lit
  waystones.
- **Lamps and air.** A masonry post with a jade lantern at each waystone's
  landing, off every walking route and waiting place (`causeway/city_lamps.gd`);
  Act I's flame flipbook burnt jade; jade motes and pale specks in the air.
- **The profile row is on** (`MapJourneyProfile`: Acts I and II), and Act II
  warms: the title builds a saved Act II run's land from the launch rite, as
  Act I's; and once Act I's boss is beaten, `NextActMap` works the next act's
  map out on a copy of the run (exact: nothing the player does before it draws
  on the run's randomness but the crown's offer), so the prefetch builds Act
  II's land paced under the rewards. Once built it is drawn once unseen
  (`MapLandWarm`, PathWarm's land steps moved there), so its first open builds
  no pipeline. The act's plate rides over the map from the frame after it
  opens.
- **Act I's static atlases are released** past its boss
  (`MapJourneyProfile.release_kit`: the held kit scenes, their static
  templates, the impostor atlas and the stone), and a prefetch lets go of
  every other act's (`release_kits`). Each land class readies its own kit
  (`ready_kit`, `prime_kit`), so an Act II build never loads Act I's.
- **Junction headroom** (II.2's review): a probe from every sample of the
  pilgrim's walking routes finds no deck underside, nor another level's deck
  more than a tread over him, within 2.12 m (`causeway_probes.gd`
  `headroom`). It found the ramp-over-road overlaps at seeds 1 and 717 and the
  near misses at 4, 42 and 17634. Raised roads are now fitted to the ordinary
  roads round them (`causeway/raised_profiles.gd`): level with their pad
  until they have left every road sharing it (and those roads level with it as
  far), ordinary roads graded under a walking body beneath every raised arch
  (down to the water's dry margin, stepping from a held pad at most 0.8), and
  a raised road lifted where that is not low enough.
- **Build time.** The deck's field query reads packed spans in one pass (the
  same operations in the same order; 120,000 random queries over seeds 1 and
  42 equal the old query's), and the edge masonry asks each deck once per
  point. The whole Act II build: about 4.0 s on the Mac at II.2, now 2.2 s.

**Cascades (D1) are not here.** They belong in II.4, which places the ruin
terraces they spill from. The hook: `CityMask.build` takes any triangles as
masonry footprint, so a cascade's foot pool passed with the footprints churns
the water's wash there, and its sheet takes the water's palette uniforms.

## Acceptance

| Item | Result |
|---|---|
| Junction headroom ≥ 2.12 m, seeds 1, 4, 42, 717, 17634 | Passes on all five (`tests/test_map_causeway.gd`): 7,000+ walking samples a seed, 0 hits; least clearance 2.29–2.43 m |
| Act II reads as §1 at Journey | Stills below, looked at, beside the north star |
| Reduce Motion still | The water's flow and the air stop (`_still` in the causeway test); flames hold their frame (`land_motion`) |
| Payload ≤ +8 MB | +1.0 MiB textures (ETC2) and about 0.05 MiB code; `map-journey` 18.3 MiB against a budget raised to 19 (`tools/payload_budget.json`); total 284.8 of 400 |
| A12 | The Metal condition (`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 --rendering-method mobile`) at Journey and Close: no shader or pipeline error |
| Device build time, first open, VRAM, footprint, memory warnings | The iPad 8 batch, below |

## Stills, looked at

Mac, seed 1, two steps in:

- [phone](frames/act2-phone.jpg), [pad](frames/act2-pad.jpg),
  [desktop](frames/act2-desktop.jpg) at Journey
- [Close](frames/act2-pad-close.jpg) and [Whole act](frames/act2-pad-whole.jpg) at pad
- [seed 717, three steps in](frames/act2-pad-seed717.jpg)
- [against the north star](frames/against-north-star.jpg)

Against the north star: the water, the stone, the jade lanterns and the amber
of the current path are there; the lit lancet halls and their blue glass
(II.4), the density of the district (II.5) and the cascades are not. The
north star's stone is a little lighter and its water more broken by
reflections; II.6 grades toward it.

## Mac transition (the probe's `--transition`, M1 Max, lean)

Act I boots, its boss is beaten, the crown's offer is read for 6–8 s, none is
taken and Act II's map opens:

| | main `6ee88a9b` | branch |
|---|---|---|
| Act II's land built ahead during the offer | no (painted act) | done after 3.3–3.6 s |
| Act II's first open: worst frame | 1,308 ms (the painted act decoding) | 71 ms |
| Act I's warmed first open, same launch: worst frame | 53.5 ms | 54.3 ms |

## iPad 8

The interleaved batch is recorded in the PR (#660 II.3), against the budgets pre-registered there before it ran.


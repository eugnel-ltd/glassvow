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

## Levers after batch 1 (Mac probe, seed 1, pad, lean)

The causeway's edge course, arch stones and parapets were most of Act II's
triangles, in one mesh a part, all casting shadows. One step at a time
(`226eefbe` holds all three):

| Step | Shadow pass, Whole act | Stage draws (Journey / Close / Whole) | Stage primitives (Journey / Close / Whole) | VRAM |
|---|---|---|---|---|
| Before (`526390ad`) | 449,190 | 81 / 41 / 151 | 447,824 / 442,064 / 451,832 | 242.5 MiB |
| 1. No shadow from the edge course, arch stones, parapets | 47,730 | 81 / 41 / 151 | unchanged | 242.3 MiB |
| 2. One surface a 32 m cell (`cell_surfaces.gd`) | 47,730 | 87 / 47 / 169 | 264,824 / 259,064 / 451,832 | 242.2 MiB |
| 3. Edge pieces 0.4 m, not 0.2 m | 47,730 | 87 / 47 / 169 | 201,260 / 195,500 / 336,188 | 227.1 MiB |

The shadow pass at Journey and Close fell the same way (442k → 41k, 439k →
37k). `test_map_causeway` (the headroom, deck and obstruction probes) passes
after steps 2 and 3 and on the final head; step 1 changes only which parts cast
a shadow, not the geometry the probes read. The decks' walls, arches and piers still cast shadows, so the
causeway still sits on the water ([Close](frames/act2-pad-close.jpg),
[Whole act](frames/act2-pad-whole.jpg); the five shape frames are re-taken
after step 3, seed 717 and the north-star frame are from before it).

`58562030` moves the next act's work off the offer screen's first frame: the
kept map goes once that screen has drawn, `NextActMap.predict` a frame later,
the prefetch a frame after that. On the Mac, after both: the prefetch is done
in 3.1 s under the 8 s offer, and Act II's first open's first frame is 56 ms
against Act I's warmed open's 54 ms in the same launch (before the levers: 102
to 122 ms against 76 to 84 ms). The levers explain Act II's first-open gap on
the Mac, so it needed no change of its own; the iPad reads it below.

## iPad 8

Two interleaved batches (ctl, dev, ctl, dev; QA app, shaders baked, the
shared lock held), graded against the budgets pre-registered in the PR before
batch 1 ran. Rows: [batch 1](device/batch1-summary.txt) (main `6ee88a9b`
against `5cf7f02e`) and [batch 2](device/batch2-summary.txt) (main `3a502235`
against `602b0a4b`: the levers, with main merged in). Script:
[`batch.zsh.txt`](device/batch.zsh.txt); table:
[`summarise.py.txt`](device/summarise.py.txt).

| Budget | Batch 1, branch | Batch 2, main | Batch 2, branch | Batch 2 |
|---|---|---|---|---|
| 1. Prefetch done inside the 8 s offer | 4,866 / 4,799 ms | none (painted act) | 4,629 / 4,765 ms | PASS |
| 2. Offer screen: no frame over 50 ms beyond main's own | worst 99.0 / 50.5 ms against main's 75.0 / 60.0 | worst 78.3 / 47.4 ms | worst 69.8 / 70.4 ms, one frame each | FAIL in dev2 (a 70.4 ms frame where ctl2 had none); dev1 passes |
| 3. Act II's first open, worst frame, no worse than Act I's warmed first open (same build) | 156 / 163 ms against 108 / 104 | 593 / 617 ms (painted act) | 138.3 / 137.6 ms against 94.3 / 98.8 | FAIL by 39–44 ms |
| 4. At rest: no missed frame beyond main's | Whole act at cadence: 10 and 29 missed | 0 missed | 0 missed in all 14 holds (max 22.4 ms) | PASS |
| 5. VRAM, Act II Journey at cadence: at most main's + 24 MiB | L1 +32.2, +25.7 MiB | L1 280.4 / 280.4, L2 288.4 / 288.4 MiB | L1 289.7 / 297.7, L2 298.0 / 298.0 MiB (+9.3 to +17.3) | PASS |
| 6. Peak physical footprint: at most main's + 48 MiB | not read (no trace saved) | 620.1 / 623.8 MiB | 693.4 / 675.0 MiB (+73.3, +51.2) | FAIL |
| 7. No memory warning | none | none | none | PASS |

- **Offer screen.** The slow frame is the screen's first frame on both builds.
  Main's own first frame ran 47.4–78.3 ms across its four launches; the
  branch's ran 69.5–71.6 ms. Graded as batch 1 was (each dev against its ctl),
  dev2 fails by that one frame. The prediction and the prefetch no longer land
  on that frame (batch 1: 99 ms).
- **Act II's first open.** The extra time is inside the open call, not in its
  draw. With the land built ahead, the call takes 118.0 / 117.6 ms and the first
  frame follows 20 ms later. Act I's warmed open takes 74.1 / 79.0 ms, also
  followed 20 ms later. A fast tap (2 s, land not yet built) calls in
  73.9 / 73.4 ms; its veil now lifts at 1.30–1.33 s (batch 1: 2.0–2.2 s). On
  the Mac the gap had closed (56 against 54 ms). Hypothesis, not yet profiled:
  the device spends about 44 ms in `_show_map` taking up the built land.
- **Footprint.** Each 30 s window opens a few seconds after launch and covers
  the offer, Act II's first open and its Journey rests. Close and Whole act come
  after the window. The branch's peak is one one-second sample during the offer,
  while Act II's land builds: dev1 693 MiB between 527 and 538, dev2 675 between
  532 and 541. Without that sample, the branch's highest is 605 / 613 MiB,
  under main's 620 / 624. At rest after Act II opens: 603 / 613 MiB against
  main's 564 / 564 (+39, +49). Batch 2 first ran with a 100 s window; neither
  save finished, so that start was stopped (it holds no rows and is not graded)
  and restarted with the dry run's proven 30 s.
- **Act I**, unchanged by the branch: warmed first open 94.3 / 98.8 ms against
  main's 96.6 / 103.4.


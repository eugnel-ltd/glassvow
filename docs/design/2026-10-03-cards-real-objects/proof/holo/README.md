# Card holograms: proof (#657, the hologram build)

The owner's picks of 14 Oct 2026, built from the research branch
`research/cards-holo-2026-10-14` (local, never pushed; design in its lane
folder's `holo-design.md`). Every still was taken on the real Main, windowed,
on the lane's isolated user dir, and looked at.

## Stills

The three holds of the motion signal are, top to bottom: leaning left and away
(-0.9, -0.6), flat (0, 0), leaning right and toward (0.9, 0.6). The cards' 3D
stages stay frozen; only the hologram moves, as it does in the hand when the
device tilts.

- `01-fight-hand-pad.jpg`, `02-fight-hand-desktop.jpg`, `03-fight-hand-phone.jpg`:
  a fight's hand with one card of each front tier, en (left) and zh-Hant
  (right), at the three holds. Left to right in the hand: rare (cut glass),
  uncommon (spectral frame), special (oil, a curse), common (silver rim) and
  starter (bare). The draw pile at the left wears the table's back with its
  lit panes; across the six runs each back is on a pile at least twice.
  `tools/capture_holo.gd --what=fight --back=<id>`.
- `04-draw-pile-phone-x2.jpg`: the draw pile on the phone, at twice size, for
  the Lancet, Vesper and Eclipse (rows) at the three holds (columns): the
  panes still read at pile size, which is what each back's knobs were tuned
  for (strength and pane scale up from the research's values).
- `05-vigil-backs-shelf.jpg`: the Backs shelf at pad, desktop and phone, in en
  (top) and zh-Hant (bottom), held at a lean (`GLASSVOW_HOLO=0.6,0.4`;
  `tools/capture_rooms.gd --state=mid --path=vigil --hold --look=backs
  --nowins --back=rose`).
- `06-dawn-earned-back.jpg`: a back revealed at Dawn, at the three holds,
  en pad/desktop/phone then zh-Hant pad/desktop/phone (`--what=dawn`). In
  some first columns the reveal's turn is still running: the hologram steps
  aside for the picture turn, as designed.

Research only, not shipped by this PR:

- `07-research-boss-gilt.jpg`: the coordinator's boss call, the rare's cut
  glass plus a warm gilt rim, on stand-in rare cards. No card has rarity
  `boss` in `content/` (the six boss items are relics), so it lands with the
  first boss card.
- `08-research-mythic-m0-crystal.jpg`: M0 with the owner's fix: the cost
  crystal is laid back over the frame and reads whole. It lands with the
  first mythic card (#212).

## iPad 8 (A12), one interleaved batch

QA app (`io.fol2.glassvow.qa`), baked shaders, under the shared lock; the
build was this branch plus an uncommitted probe (a ten-card deck, two each
of one card per tier, for the bench fight, an env switch that turns every hologram off, a synthetic
full-throw wobble so the holograms move every frame with the stages frozen,
and per-second frame rows). Fight `duskfang` (elite), a full hand of mixed
tiers and the draw pile, 30 s rows after an 8 s settle, arms interleaved:

| run | arm | frames | mean ms | worst ms | > 20 ms | > 25 ms |
|---|---|---|---|---|---|---|
| 1 | holograms off | 1815 | 16.67 | 16.7 | 0 | 0 |
| 2 | on, wobbling | 1753 | 17.17 | 30.3 | 8 | 2 |
| 3 | holograms off | 1601 | 18.91 | 29.2 | 16 | 3 |
| 4 | on, wobbling | 1654 | 18.31 | 26.8 | 21 | 3 |

The long frames rise run by run in both arms (0, 8, 16, 21), and the second
"off" run has twice as many as the first "on" run: a drift over the batch,
not the holograms. Mean frame time is the same in both arms (17.8 ms off, 17.7 ms on).
No visible hitch. `09-ipad8-fight-mixed-hand.jpg` is run 2 on the device.

**Axes.** Upright on its stand in landscape, the device read gravity
(9.80, 0.07, 0.21): the engine reports iOS readings in the device's portrait
axes. `HoloMotion.to_screen` maps it to (0.07, -9.80, 0.21), straight down the
screen, and the calibrated signal read (0.00, 0.00) at rest from the sensor
source. The pad stayed on its stand, so no hand-held lean was recorded; the
lean's direction is fixed by the unit test that a device turned one way reads
as the card's own slab turned the same way.

## The A12 Mac repro

`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --rendering-driver metal
--rendering-method mobile` ("Metal 4.0 - Forward Mobile ... Apple7") on the
fight with every front tier and a back on the pile: no shader, sampler or
compile error, and every hologram rendered.

## The cost crystal above the hologram (owner, 14 Oct 2026, 18:47)

`10-crystal-crops-pad.jpg` and `10-crystal-crops-phone.jpg`: each tier's cost
crystal in the fight's hand, before (left three) and after (right three), at
the three holds. Before, the rim, the spectral frame and the cut glass crossed
the numeral and the oil dimmed it. After, every front recipe lays the picture
back over the crystal's footprint last (`holo_gem_keep`, holo_common), and the
crystal takes its own small glint instead: a band that sweeps its light facets
with the card's tilt, never its numeral's dark ink, tinted by the tier (silver
on the common, a spectrum on the uncommon, the glass's sapphire to amber on the
rare, a faint tar sheen on the special, nothing on the starter). No extra pass
and no extra sampler. Crops come from `tools/capture_holo.gd`, which prints
each crystal's place in the still (`CAPTURE_HOLO_GEM`).

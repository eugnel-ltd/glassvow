# The flame on the HUD — lock PR 5 (#577, step 2)

**Status:** delivered for the owner's visual approval on device, 2026-09-29. Authority: the Flame lock ([`../README.md`](../README.md)) §5, §6 and §9; issue #577 step 2; the approved spike ([`../shader-spike/README.md`](../shader-spike/README.md)). Visual approval on device is pending: the look is a parameter set and can change without touching the wiring.

**The outcome.** The Duskblade's lantern shows the Flame wherever the deck changes or a fight begins: the combat HUD, the reward screen and the Night Stall. Presentation reads `EventTypes.FLAME` events and never computes purity; every change tweens over one second and nothing snaps. An aspect that declares no ways (the Ashwarden) never hears a reading, so its lantern is the painted art exactly as before and its reward and shop screens grow no lantern.

## What changed

| File | Role |
|---|---|
| `presentation/combat/lantern_flame.gdshader` | The material, moved from the lab. The leaded look only. A new input, `painted`, shows the lantern as painted (Kindling). |
| `presentation/combat/lantern_flame.gd` | `LanternFlame`: the palette table, the reading-to-inputs mapping, the one-second tween, and `light()`, which puts the flame on any lantern's art and relights the glow behind it. |
| `presentation/combat/hud_bar.gd` | `show_flame(event, instant)`; the first reading lights the lantern. The ember count moves from the glass to under the lantern's foot. |
| `presentation/combat/combat_screen.gd` | Forwards the start batch's reading at once, a reading from the pump with a tween, and relights a HUD rebuilt for a new shape. |
| `presentation/run/run_lantern.gd` | `RunLantern`: the same lantern (art, glow, flame; no pips, no count) for the reward and shop screens. |
| `presentation/reward/reward_screen.gd`, `presentation/run/shop_screen.gd` | `show_flame()`: build the `RunLantern` on the first reading, then pass readings on. |
| `presentation/run/run_hud.gd` | `chrome_bottom()`: where the run HUD's chrome ends, so the lantern can hang clear of it. The run HUD itself shows no lantern and gains none. |
| `application/main.gd` | `_read_flame()`: the reading taken where main edits the deck directly (reward claims, stall purchases and removals); plus the lab's `--flame` route. |
| `presentation/lab/flame_lab.gd`, `presentation/lab/reward_lab.gd`, `tools/bench_flame.gd` | The lab drives the production `HudBar.show_flame`; the reward lab takes `--pose=`; the probe takes `--pose=`. |
| `tests/test_lantern_flame.gd` | The controller's targets and tween, the HUD, the run lantern's seat, the combat forwarding, and main's reward and shop reads. |

## The four decisions, as built

1. **The leaded look ships; the vector look is gone.** Keeping it would have kept a second branch, its uniform and a lab toggle in production code for a look nobody ships. It survives in the spike's history (branch `spike/flame-shader-lab`).
2. **One palette table, keyed by what the flame burns.** `LanternFlame.COLOUR` holds the three ways by their content ids and the two undeclared tiers by their tier ids: Frostlight `#8fd0ff` (`shatter`), Hearthfire `#f2c14e` (`lantern`), Eclipse `#9c2fa6` (`edge`), Kindling `#e8702a`, Soot `#8a6e52`. Content carries ids only. A way with no entry burns as Kindling.
3. **Kindling is the lantern as painted.** Kindling sets `painted` to 1: every pane shows the art's own amber light, with a small, quick flicker so the lantern is alive (lock §5, "lively"), and the glow behind it is the HUD's own amber. Every other tier sets `painted` to 0 and relights the glass as the spike drew it. A tween out of Kindling crossfades the painted light into the new figure over the second. See *Kindling against today's lantern* below.
4. **The ember count sits under the lantern's foot.** Captured once against the two alternatives (`numerals.png`); see *Where the count sits* below.

## Kindling against today's lantern

`parity.png`: the phone HUD at 844×390 at 3×, today's lantern (the HUD never hears a reading) beside Kindling, and their difference amplified 16 times. The crop is the lantern's box and its count, with the pips.

| Measure (levels of 255, the phone HUD crop) | Value |
|---|---|
| A still, 1.2 s after the reading: mean / p99 / max | 0.15 / 2 / 3 |
| Over two seconds of flicker (60 frames): worst mean / max | 0.21 / 8 |
| Over those two seconds, the most pixels ever more than 4 levels apart | 2.4 % |

The glow accounts for the faint rings in the difference: the HUD's amber falloff shifts hue towards its edge, and the flame's falloff is one colour. The flicker is the rest: small (at most ±4 % of the painted light) and quick, so it reads as life without changing the lantern.

## Where the count sits

`numerals.png` sets three placements side by side on the phone HUD, over Kindling, Steady Edge and True Shatter: over the glass (before), beneath the foot, and beside the lantern.

**Beneath the foot** is the one kept. The pip arc runs −140° to 140° and leaves its gap at the bottom; the count closes that gap, so the pips and the count read as one gauge on the lantern. It covers nothing of the flame: not the top of a figure, not Edge's height, not the fringe, not True's halo. Beside the lantern, the count floats free of it: outside the pip ring it no longer belongs to the lantern, and on the phone it drifts towards the battlefield and reads as a number of its own. Legibility: the count keeps its 26 px Cinzel 800 with the 8 px outline in the lantern's 104 box, which is 17 pt on the phone's 68 pt lantern; the digit itself measures 13 pt (39 device pixels at 3×) in the phone capture. At the pad and desktop shapes the lantern stands just above the energy orb, so the two numerals stack (`hud-pad.png`): the count's digit stands 22 pt above the energy digit, which is half as large again and sits on its candles, and the count sits in the lantern's glow and pip ring.

## Accessibility: tier and way without colour

`grey-phone.png` is the phone HUD sheet in greyscale; `grey-figures.png` the large lantern. `evidence.py --measure` reads the phone HUD recordings in luminance only (Rec. 601), inside the box the panes stand in. With the count off the glass nothing needs masking. "Height" and "width" are the extent of the pixels at flame brightness (125), as shares of that box; "fill" is how solidly they fill the rectangle they make.

| Pose (phone HUD) | Mean L | p95 L | Height | Width | Fill |
|---|---|---|---|---|---|
| Kindling | 61.4 | 148 | (painted) | 0.77 | 0.29 |
| Steady Shatter | 46.1 | 124 | 0.46 | 0.74 | 0.15 |
| Steady Lantern | 58.9 | 206 | 0.41 | 0.79 | 0.44 |
| Steady Edge | 29.9 | 80 | 0.43 | 0.15 | 0.51 |
| True Shatter | 62.4 | 164 | 0.73 | 0.79 | 0.27 |
| True Lantern | 76.5 | 221 | 0.62 | 0.79 | 0.49 |
| True Edge | 37.3 | 111 | 0.48 | 0.15 | 0.61 |
| Soot | 28.7 | 54 | none | none | none |

Motion (median and p95 of the mean absolute frame-to-frame change in L over two seconds at 30 frames a second): Soot 0.31 / 0.98, Kindling 0.16 / 0.50, Steady Lantern 0.13 / 0.28, True Lantern 0.08 / 0.10.

- **Tier, without colour.** Stability orders all four tiers, by the median and by the p95: Soot gutters, Kindling flickers, Steady is calm, True is still. Height and brightness then separate the declared tiers in every way: True stands taller and burns brighter than Steady (Shatter 0.46 → 0.73 and p95 124 → 164, Lantern 0.41 → 0.62 and 206 → 221, Edge 0.43 → 0.48 and 80 → 111), and True alone carries the halo. Kindling has no standing figure: its glass is lit evenly as painted, so its "height" is the painted glow's, not a flame's. Soot is the darkest lantern, never reaches flame brightness and is the only one that gasps.
- **Way, without colour.** Width separates Edge's single blade (0.15) from Shatter and Lantern (0.74–0.79); fill separates Shatter's crown of shards (0.15–0.27) from Lantern's hearth (0.44–0.49). Both hold on the phone HUD.
- **One weak spot, as in the spike.** Edge's blade is dark by design (the eclipse), so on the phone most of it burns below flame brightness and its True height reads mostly as brightness and the halo.

## Frame time

`tools/bench_flame.gd` hosts the flame lab, which is the production `HudBar` lit through `show_flame`, at phone-landscape at 3× (a 2532×1170 window, iPhone density) with the large lantern hidden, so the HUD lantern is the only flame. Vsync off; 240 frames and 3 s of warm-up, then 1,200 frames; median and p95 of each run; every configuration once per round, rounds interleaved (`evidence.py --bench`). "Off" is the HUD as it ships without the Flame: its lantern never hears a reading. `+100` adds a hundred more HUD-sized lanterns carrying the same material, so a flame's own cost stands clear of the noise. Metal's GPU timer reads zero on this machine (the repository's own finding), so the GPU column is five rounds on Vulkan (MoltenVK) with the mobile renderer; three rounds on Metal give the production driver's CPU figures. MacBook Pro, Apple M1 Max, macOS 27.0, Godot 4.7.2 official, on a machine shared with other agents' suites.

| Phone 844×390 at 3× | GPU median (p95), ms (Vulkan) | CPU setup, ms (Vulkan / Metal) | CPU render, ms (Metal) | Whole frame median (p95), ms (Metal) |
|---|---|---|---|---|
| Off (before) | 0.431 (0.545) | 0.012 / 0.010 | 0.064 | 8.19 (17.48) |
| Kindling | 0.456 (0.570) | 0.023 / 0.021 | 0.091 | 8.38 (17.83) |
| True Lantern | 0.456 (0.575) | 0.020 / 0.018 | 0.075 | 8.24 (17.93) |
| Off, + 100 plain lanterns | 0.526 (0.655) | 0.013 / 0.011 | 0.093 | 8.28 (17.66) |
| True Lantern, + 100 burning lanterns | 1.660 (1.804) | 0.019 / 0.019 | 0.100 | 8.31 (17.98) |

- **The HUD flame costs about 0.025 ms of GPU and 0.01 ms of CPU setup per frame** at iPhone density on this Mac, the same at Kindling and at True Lantern: well under 1 % of a 16.7 ms frame. The setup cost is the flame's clock uniform, written every frame. Each further burning lantern adds about 0.011 ms (the hundred cost 1.13 ms).
- **The whole frame does not move.** Its median stays at the 120 Hz presentation interval with or without the flame; the p95 is the shared machine's hitching and is the same with the flame off. The CPU render column moves within the noise of three runs.
- **The floor devices** are still to be measured, as #577 requires before step 4; this is a ceiling to test there, not a clearance. The two levers the spike recorded (an early exit outside the panes, `TIME` instead of the clock uniform) are still unpulled, per the optimise-after-approval rule.

## The images

Every image is taken through `tools/shot.sh` against the production code. Stills are 1.2 s after the reading arrived, on the flame's pinned clock, so every lantern on a sheet is caught at the same moment of its flicker. HUD crops are the production HUD at the shape and density, in the lantern's resting (unlit) state, with the pips and the count.

| File | Shows |
|---|---|
| [`sheet-phone.png`](sheet-phone.png) | The HUD lantern at phone-landscape, 844×390 at 3×: Kindling, Steady and True in the three ways, the two fringes, Soot. |
| [`sheet-pad.png`](sheet-pad.png) | The same at pad-landscape, 1180×820 at 2×. |
| [`sheet-desktop.png`](sheet-desktop.png) | The same at desktop-landscape, 1458×820 at 2×. |
| [`grey-phone.png`](grey-phone.png) | The phone sheet in greyscale. |
| [`figures.png`](figures.png), [`grey-figures.png`](grey-figures.png) | The large inspection lantern (same material): the figures themselves, in colour and greyscale. |
| [`parity.png`](parity.png) | Today's lantern, Kindling, and their difference × 16, phone. |
| [`numerals.png`](numerals.png) | The count over the glass, beneath the foot and beside the lantern, phone. |
| [`tween.png`](tween.png) | Kindling to Steady Shatter every 0.2 s, HUD and large: nothing snaps. |
| [`soot.png`](soot.png) | Soot every ⅓ s: the gasps, the murk and the ash. |
| [`fight-phone.png`](fight-phone.png) | A real fight at the phone shape (a Development Scenario, Steady Shatter deck): the HUD lantern lit by the domain's own startCombat reading. |
| [`hud-pad.png`](hud-pad.png) | The whole pad HUD with True Lantern: the count under the lantern, above the energy orb. |
| [`reward-phone.png`](reward-phone.png), [`reward-offering-phone.png`](reward-offering-phone.png) | The production reward screen at the phone shape (the reward lab, `--pose=steady-shatter`), shallow and with the offering open. |
| [`shop-phone.png`](shop-phone.png) | The real Night Stall at the phone shape (a Development Scenario with the Steady Shatter deck), its lantern lit by main's read. |

## Reproduce

```sh
python3 docs/design/2026-09-29-dusk-flame/hud/evidence.py --capture --measure --recordings /tmp/flame-hud
python3 docs/design/2026-09-29-dusk-flame/hud/evidence.py --bench 5              # Vulkan: the GPU column
python3 docs/design/2026-09-29-dusk-flame/hud/evidence.py --bench 3 --driver metal
godot --path . -- --flame                                                         # the bench: ←/→, 1–0, F, N, R, Space, H
```

`--capture --only=phone,phone-motion` re-records single parts. The numeral comparison needs two scratch edits of `HudBar.LANTERN_COUNT_BOX` (to `Rect2(106, 46, 36, 34)` for beside and `Rect2(0, 0, 104, 104)` for the glass), each recorded with `--numeral=beside` or `--numeral=glass`; the chosen placement is `--numeral=foot`.

## Answers to the spike's open questions

1. **The numeral:** under the foot (above).
2. **Kindling darker than today:** no longer; Kindling is the painted lantern (above).
3. **Kindling and Soot burn plain:** kept. Kindling hints at no way.
4. **Fringe strength:** unchanged (55 % at `fringeMin` 0.25, full at 0.40); for the device review.
5. **Halo against the art-ready beacon:** unchanged; for the device review.
6. **Soot's ash on the HUD:** unchanged; Soot is carried by the murk, the dullness and the gasps.
7. **The Web build:** not exported in this PR.
8. **Seeing it on a device:** the lab still has no entry in the dev front door's catalogue (the organiser's registry); `godot --path . -- --flame` runs it natively.

## Residual risks

- **Brightness at commitment.** Kindling, being the painted lantern, is brighter overall than a Steady Shatter or any Edge flame (mean L 61 against 46 and 30). The figure, the colour and the stillness carry the change; if on device a committed lantern reads as dimmer than the start, the far glass's fill for declared ways is one constant.
- **The crossfade out of Kindling** passes through a warm grey for a fifth of a second on the way to a cold way. It reads as the old light giving way; a brightness dip at the midpoint is the lever if it reads as muddy.
- **The Night Stall's left window** is painted stained glass; the lantern hangs in front of it. It reads at device size (`shop-phone.png`), but a blue flame on the blue window is the weakest contrast on any surface.
- **Two numerals at the pad and desktop shapes.** The count under the lantern stacks above the energy numeral there (22 pt apart). They differ in size and in what each belongs to; if on device they read as one column, the count can shrink or tuck up onto the lantern's finial, one constant (`HudBar.LANTERN_COUNT_BOX`).
- **Floor devices.** The frame time above is an M1 Max; the floor devices are re-measured before step 4.

# #657 PR 5b, the top-menu deck as a stack: evidence

Measured and shot on the branch's code (`c48be94b`). §3 and §4 are the
dossier's (`../../README.md`); PR 5's evidence is `../pr5/README.md`. The
probe, the batch, the analysis and the mutation list are text under
`device/`; the raw rows stay out of the repository.

## The spec as built

| Item | Built | Where it differs, and why |
|---|---|---|
| 1. The run HUD's deck as a stack | `DeckStack` (`presentation/cards/deck_stack.gd`) on the deck button where `ui/deck.png` stood: a `PileStack` (reused, not forked) of backs in the table's back, the deck's size over it as before. A 36 × 51 card on the pad's 56 px square; the phone's 42 px square scales it to 27 × 38. The stack is drawn at the combat pile's card (83.2 px tall, the card the thickness law is written for) and scaled down to this one, so the law, the slivers, their jitter, the shadow and the glint scale together: on the pad 1 px a card becomes 0.61 px and the 14 px cap 8.6 px. A tap opens the deck view, unchanged (`Main._show_run_deck`). | **The top card is held, and the deck deepens under it.** A 51 px card and up to 8.6 px of edge overfill the 56 px the painting had, and the bar starts at the screen's edge: grown up from a fixed bottom card, the stack cut its own top off on the pad from about 30 cards (seen in the first stills). Held 2 px under the square's top, the count sits on the same place on the card at every size, and a full deck's edge runs about 6 px under the 56 px bar, clear of the relic row except past about 23 relics. |
| 2. The combat seal as the same stack | `HudBar`'s seal wears a `DeckStack`, counting what the seal counted: draw, hand and discard, never the ash. A tap opens the deck inspector, unchanged. | The seal's top card is held 2 px under its **button's** top, not under the painting's square, which started 6 px above the button: the phone's bar seats the button 1 px under the screen's edge, and a card held by the square lost 3 px of its top there. |
| 3. The glint | The stack's glint is the draw pile's (`PileStack`: 1.4 s of sweep every 9 s), starting half a cycle after it (`DeckStack.GLINT_PHASE`, 4.5 s), so in a fight the two sweeps never overlap. Reduce Motion: no glint. Canvas only: the glint is a polygon pair on one small child, redrawn only while it crosses; no card stage is built or rendered. | — |
| 4. The back baked outside a fight | The frame that builds a route with the run HUD bakes the chosen back when the table does not yet wear it baked (`Main._bake_table_back`, from `_attach_run_hud`). It runs on a bench of its own (`CardTurn.prewarm_on_bench`): a node under `Main` that is let go the moment the bake lands, so the retired card's video memory is released behind the same transition and is never carried into a fight. A session pays it once, on its first route with the HUD, and again only after a change of back (or a dropped bake). A fight's load then finds the bake made and pays a cached lookup. Until the bake lands, and after a change of back until its own does, the button shows the painting (`DeckStack` follows `CardTurn.back()` each frame), never a blank. | **Behind a screen transition, not the launch screen.** On the players' route from the title (Back to the Road) the map is built under the title's light flooding outward, so the frame with the painting is covered (`06-bake-on-the-route.jpg`); a new run reaches its first map under the departure's own flood, which was not shot. It is never in a fight (a fight has no run HUD) and never while the map is walked (the HUD is built with the route, not during it). |
| 5. Report: §3's *Deck view open* row | **Not built.** See below. | — |

**PileStack's glint, fixed on the way.** One still logged "Invalid polygon
data, triangulation failed" from the glint: at about 0.681 of its sweep a
card's corner clips the band to a sliver of three points all but in a line,
which `draw_polygon` refuses (2 pieces in 62,564 at a 1/20,000 sweep step).
The draw pile shares the code. The band's geometry is now one function
(`PileStack.glint_pieces`) that keeps only the pieces a triangulation takes.

## Item 5: is the *Deck view open* row built?

No. The deck view itself is: the run HUD's deck opens the `ChoiceScreen`
overlay on baked faces (`CardGrid`, one live card under the finger, built
since PR 2), and the combat seal opens the inspector on the same grid
(PR 5). What §3's row adds is not built: the stack lifting 6 px over 120 ms,
the cards streaming from it to their grid cells back up and turning face up
as they land (18 ms apart, the stream capped at 0.5 s, 0.3 s a card turning
in its last 60%), closing as the reverse at 60% of the time, a tap
completing it, and Reduce Motion's 160 ms fade.

What it would take, as its own PR with its own device measurement:

- `DeckStack.lift()` (a 6 px, 120 ms tween on the stack) and its top card's
  global rect as the stream's source.
- A `DeckStream` beside `PileStream`: one canvas item per flying card, each
  the picture turn (`card_turn.gdshader`) over that card's baked face
  (`CardFaces`, which the grid already bakes) with the table's back, using
  PR 5's `face_span` to turn a face rather than the back; its timing,
  stagger cap, Skip and Reduce Motion as pure functions, as `PileStream`'s
  are.
- The grid laid out before the stream starts (its cells' global rects), its
  `BakedCard`s hidden until their flight lands; the same in reverse on close,
  in `ChoiceScreen`'s overlay and in the combat inspector.
- Proof: open and close bursts at the three shapes, Skip and Reduce Motion,
  and on the iPad 8 a 40-card stream's frame times and the overlay's video
  memory before and after (§6.1's PR 5 row).

## PR 5's review carry-overs

- **Batch 5's rest-P95 delta.** PR 5's README gave the per-batch medians of
  the combat-at-rest P95 for batches 1 and 4 only. All three, B − A on the
  batch median: batch 1 **−0.19** (A 17.47, B 17.28), batch 4 **+2.03**
  (A 17.83, B 19.86), batch 5 **−1.01** (A 19.18 over ea1–ea4, B 18.17 over
  eb1–eb4). The signs disagree batch to batch, as that README said: the
  throttle's, not the piles'.
- **A combat rest with a charred card on the ash and a face-up discard** and
  **a reshuffle of cards all dealt before, in a real fight**: measured on the
  iPad 8 below.

## iPad 8 (A12, 2160 × 1620), frame times

QA builds (`io.fol2.glassvow.qa`), one of `main` (`711302a5`, A) and one of
the branch (`c48be94b`, B), each with the same untracked probe
(`device/deck_probe.gd.txt`, attached by `device/patch.py.txt`), launched
`--map --seed=1 --deck-probe=nonce=…,mode=…`:

- **mode=map**, the cold open to the map and the map at rest. Frames from the
  probe's first frame until the map has settled, marking the frame that
  built the run HUD, the frame B's bake bench appeared in and the frame its
  bake landed, and the engine's clock when the map's land is drawn (the cold
  open, from engine start); then **maprest**, 12 s of the map at rest with the
  run HUD, longer than the stack's 9 s glint cycle.
- **mode=fight**, PR 5's two carried measurements. The bench fight (Duskfang,
  elite) from the settled map; a hand card kindled to the ash through the
  real path; End Turn (the hand sweeps face up to the discard, the foe acts,
  the next deal); **ashrest**, 10 s at rest with a charred card on the ash
  (its rim breathing) and the discard's face-up top; then End Turn again,
  which reshuffles the nine cards in the discard, every one of them dealt
  before in this fight (the probe checks), and deals: **resh** while the
  stream flies, **rdeal** from its end until the drain is idle.

**Pending.** The batch waits on two things: the iPad's battery reaching 60%
(it was charging from 14% at 01:06, and PR 5's batches were thermally
confounded), and the Mac's login keychain, locked for agent shells, which the
QA export's development signing needs (`errSecInternalComponent`). The probe
runs on both builds on the Mac. The results, every launch listed, will
replace this paragraph.

## Tests and mutations

`tests/test_deck_stack.gd`: the card and the law scaled to it at the pad's
and the phone's squares, the top card held at every count, nothing in the
stack taking the pointer from its button; the painting until a back is
baked, the back once it is, the painting again after a change of back and
the new back once its bake lands, a stack built after the bake wearing it
from its first frame; the seal's and the draw pile's glints never crossing
together in 18 s (and each crossing), Reduce Motion stilling the seal's; the
run HUD's stack counting the run's deck at every refresh and shape and a tap
asking for the deck view; the seal counting draw, hand and discard (never
the ash) at four mixes, its top card 2 px under its button at the pad and the
phone, and a tap opening the deck.

`tests/test_card_turn.gd` (`_run_hud_bakes_outside_a_fight`), on a real
`Main`: the map's first build bakes the chosen back in the frame that builds
it, on a bench under `Main`, with the deck on its painting until it lands;
the bench is gone once it has; the deck wears the bake; a later route with
the HUD makes no bench and bakes nothing; the fight's load then bakes
nothing; after a change of back the next route bakes the new back on a bench
and the deck follows it; a bake dropped under the table is made again by the
next route.

`tests/test_piles.gd` (`_glint_fills`): at ±0.681 the glint draws only
pieces a triangulation takes; mid-card it draws both halves.

Twenty-one mutations (`device/mutations.json.txt`, run by `device/mutate.py.txt`:
back up, break, run the one test, copy back), every one caught, on the tests
as committed:

| Mutation | What it breaks | Caught by (the first failure) |
|---|---|---|
| `d01-law-unscaled` (`deck_stack.gd`) | the law unscaled (the stack drawn at its own card) | deck stack: 1 cards on a 56 px square: top at 2.00 (want 2.00), 1.00 deep (want 0.61) |
| `d02-top-not-held` (`deck_stack.gd`) | the stack grows up from a fixed bottom card | deck stack: 1 cards on a 56 px square: top at 1.39 (want 2.00), 0.61 deep (want 0.61) |
| `d03-no-follow` (`deck_stack.gd`) | the stack never follows the table's back | deck stack: a baked back is not worn in place of the painting |
| `d04-painting-never` (`deck_stack.gd`) | the painting never shows | deck stack: with no back baked it does not show the painting |
| `d05-blank-glass` (`deck_stack.gd`) | the stack shows with no back (blank glass) | deck stack: with no back baked it does not show the painting |
| `d06-glint-in-phase` (`deck_stack.gd`) | the stack glints in phase with the draw pile | deck stack: the seal and the draw pile glint together 0.05 s in |
| `d07-glint-overlaps` (`deck_stack.gd`) | the stack glints 0.9 s after the draw pile (sweeps overlap) | deck stack: the seal and the draw pile glint together 0.05 s in |
| `d08-takes-pointer` (`deck_stack.gd`) | the stack takes the pointer from its button | deck stack: Control takes the pointer from the deck button |
| `d09-seal-no-hand` (`hud_bar.gd`) | the seal's stack leaves out the hand | combat seal: draw 3, discard 4, ash 2, hand 5 stand 7 with '12' over them, want 12 |
| `d10-seal-counts-ash` (`hud_bar.gd`) | the seal's stack counts the ash | combat seal: draw 3, discard 4, ash 2, hand 5 stand 14 with '12' over them, want 12 |
| `d11-seal-off-button` (`hud_bar.gd`) | the seal's stack is not on its button | combat seal: the stack is not on the deck button |
| `d12-hud-stale-count` (`run_hud.gd`) | the run HUD's refresh leaves the stack's count | run hud deck: pad-landscape counts 12 on the stack and '13' over it, want 13 |
| `d13-hud-pad-size-on-phone` (`run_hud.gd`) | the phone's run HUD stands the pad's 56 px stack | run hud deck: phone-landscape does not stand a 42 px stack where the painting stood |
| `b01-no-bake-site` (`main.gd`) | the run HUD's route bakes nothing | card turn: the map's first build baked [], want vault on a bench |
| `b02-no-bench` (`main.gd`) | the bake runs on Main itself, not a bench | card turn: the map's first build baked [[<Control#359737070070>, "vault"]], want vault on a bench |
| `b03-bench-kept` (`card_turn.gd`) | the bench is kept after the bake | card turn: the bench outlives its bake |
| `b04-no-guard` (`main.gd`) | every route with the HUD makes a bench | card turn: a later route with the HUD baked again ([[<Freed Object>, "vault"]], 1 benches) |
| `b05-guard-on-wearing-only` (`main.gd`) | a dropped bake counts as worn | card turn: a dropped bake is not made again by the next route: [[<Freed Object>, "vault"], [<Freed Object>, "eclipse"]] |
| `b06-default-not-chosen` (`main.gd`) | the default back is baked, not the chosen one | card turn: the route after a change of back baked [[<Freed Object>, "vault"], [CardBackBench:<Node#426241955711>, "vault"]], want eclipse on a bench |
| `d14-seal-held-by-square` (`hud_bar.gd`) | the seal's top card held by the painting's square | combat seal: on pad-landscape its top card stands -4.00 px under the button's top, want 2.00 |
| `p01-glint-sliver-drawn` (`pile_stack.gd`) | the glint draws slivers no triangulation takes | piles: the glint at -0.681 draws a sliver the canvas cannot fill |

## Stills and bursts (Mac, M1 Max, Metal, Forward Mobile)

The game's own boots, `--map --seed=1` for the run HUD and the bench fight
(`--fight=duskfang --kind=elite --seed=1`) for the seal, the deck's size set
through the HUD's own inputs (`RunHud.refresh`, `HudBar.set_values`), Rose
baked and worn through `CardTurn.prewarm` for the second back.

| File | Shows |
|---|---|
| `01-sizes-pad.jpg`, `02-sizes-phone.jpg`, `03-sizes-desktop.jpg` | the run HUD's deck and the combat seal at 10, 20, 30 and 40 cards, Vault and Rose, English and Traditional Chinese, at 1180 × 820, 844 × 390 and 1458 × 820 |
| `04-frames.jpg` | the whole frame at each shape, the map and the fight |
| `05-glint-and-rm.jpg` | the glint crossing the run HUD's stack and the seal, 0.2 s apart; the same moments under Reduce Motion |
| `06-bake-on-the-route.jpg` | the bake on the players' route: Back to the Road, the light flooding out of the title, the frame that builds the map and the HUD (and bakes) under it, the map with the stack. Each frame was written to disk as it was drawn, so the frames are in order but not at their real pace |
| `07-a12-condition.jpg` | the A12 condition (below) |

What they show: 10, 20 and 30 cards read differently and 30 and 40 alike
(the law's cap, 8.6 px at this size); the count sits on the same place on
the card at every size; the top card is whole at every shape, the phone's
seal included; Vault and Rose both read, and the white count holds on both;
the two languages differ only in the bar's title (the count is a number); the
glint is a soft band crossing the top card, and under Reduce Motion there is
none; on the players' route the frame that shows the painting is under the
flood, and the map is uncovered wearing the stack.

## The A12 condition

`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --rendering-driver metal
--rendering-method mobile …` with the shader cache off (`override.cfg`
`[rendering] shader_compiler/shader_cache/enabled=false`), the run HUD and
the seal at 10 and 40 cards in Rose, the glint and Reduce Motion:
`Metal 4.0 - Forward Mobile`, **0 "Error compiling shader" lines**; the only
error line in each run is Godot's exit notice of resources still in use. The
stack is canvas style boxes and one texture, and the glint canvas polygons.

## Payload

`tools/payload_report.py` (iOS), measured on the branch and on `main`'s tree
(less the QA probe's files): about **+9.0 KiB packed**, all code.
`presentation` grows from 3,315,085 to 3,323,363 B (3.17 of its 3.2 MiB
budget; `deck_stack.gd` is 4.7 KiB of it), `application` by 0.9 KiB; the pack
estimate stays at 277.21 MiB. No asset is added or retired: the painted deck
stays, as the stack's fallback.

## Core gate

On `c48be94b` (`godot --version` 4.7.2.stable; `tools/check_imports.sh`;
`tools/check_scripts.sh`, 493 scripts; `godot --headless -s
res://tests/run_all.gd`; plus `check_anchors.py`, `check_benchmark_freeze.py`,
`payload_report.py`): green, **PASS (157 tests)**, anchors OK, 592 citations
frozen, payload within budget. A first full run on the same head, under a
load average of 72 to 79 from other lanes' balance runs, failed one
real-time assertion (`test_card_flights`: under Reduce Motion a leaving card
had not left within its 0.16 s fade and 0.05 s of slack); that test passed
alone twice and in the full re-run.

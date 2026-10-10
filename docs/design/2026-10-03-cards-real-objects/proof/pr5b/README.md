# #657 PR 5b, the top-menu deck as a stack: evidence

Shot on the branch's code at `c48be94b`; `4e38aeb9` adds tests and one
comment and changes no behaviour. The iPad rows b1–b3 are of `0b985fbd`, whose
code is `4e38aeb9`'s; the fix's fight batch is of `40b7f302`, the code head. §3 and §4 are the dossier's
(`../../README.md`); PR 5's evidence is `../pr5/README.md`. The probe, the
batch, the analysis, the batch logs, the analysis's output and the mutation
list are text under `device/`; the raw rows stay out of the repository.

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

**The orchestrator's design calls (9 Oct 2026), on the review of `08e9411d`.**

- Accepted: the top card held and the deck deepening under it; the seal's
  top card held 2 px under its button; the bake behind the route's
  transition rather than the launch screen; a deck of no cards showing only
  its count (the piles' rule).
- A loose end for the tracker, not fixed here: a full deck's edge runs about
  6 px under the run HUD's 56 px bar, and a relic row long enough to reach
  the deck (past about 23 relics) would meet it.

**Carried: a change of back inside a session.** `CardBacks.choose` has no
caller in a session yet: the Vigil's Backs shelf that will call it is PR 6.
"The stack follows a change of back" is proved through the route path: the
choice drops the old bake, the stack shows the painting, the next route with
the run HUD bakes the new back and the stack wears it
(`_run_hud_bakes_outside_a_fight`, `_follows_the_back`). A picker that
changes the back while a run HUD is on screen must also bake the new back
there (or refresh the screen's route); until it does, that HUD shows the
painting until its next route.

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

QA builds (`io.fol2.glassvow.qa`), one of `main` (`711302a5`, A; `main`
was at `64af9302` by then, which adds docs and balance-tool text only, so the
same runtime) and one of the branch (`0b985fbd`, B: the code of `4e38aeb9`
and proof docs), each with the same untracked probe
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
- **mode=route**, the bake on the players' route. No `--map`: the boot lands
  on the title, over the run an earlier `--map` launch saved in the QA app's
  development profile. Once the title has rested and its rooms have warmed
  (6 s), the probe taps Back to the Road (`_on_title_pick`, as a tap does):
  the title's light floods out over 0.48 s, the map and the run HUD are built
  under it (the branch bakes there) and the light fades off. Every frame from
  the tap until the map settles, each with the flood as it was drawn in that
  frame (its alpha and its radius as a share of full cover), marking the
  frame that built the HUD and the frame the bake landed in. A new run reaches
  its first map under the departure's own flood; driving Embark and the
  departure from a probe is not cheap, so it is not measured.

Each install's first launch is a `warm=1` map launch: the first run of a new
build, which may meet a cold shader cache (only the campaign's first did, as
it turned out). Its bake frame is listed by name, not graded.
On the branch a fight's load finds the table's back already baked (the map
baked it), while main bakes it inside the load: the fight's load frame differs
by design, and both are listed with whether the back was baked before the
load. The video memory column (`vram`, MiB) is kept for every frame: around
the bake it shows when the baked card, retired on its bench, is released.

**Results (10 Oct 2026, 18:12–20:13).** Three sessions of the shared iPad
lock, interleaved by install: b1 A then B, b2 B then A (it waited 17 min
for the R3.3 lane's hold to end), b3 A then B. Each install ran a warm-up,
then map, route and fight twice, with 90 s cool-downs: six measured launches
of each mode on each build, 42 launches in all, every row carrying its own
nonce and build tag. Both QA builds run the custom 4.7.3-rc iOS template, as
each probe's `PROBE` row reports. The iPad was on its charger and full at
every launch (100%, not charging); it was at 30.5 °C at the first launch and
33–40.6 °C after that. **No measured launch throttled** (the onset rule is a
1 s window whose median goes over 16.9 ms and stays there). Only B's first
warm-up (kbw1) throttled, from 4 s. The analysis's full output is
`device/summary.txt`; the batch logs are `device/b1-batch.log.txt`,
`b2-…` and `b3-…`.

Medians over the six measured launches of each build (per-launch p50 and
p95, then the median of each), with B − A for each batch in brackets:

| Figure (ms) | A, main | B, branch | B − A | Acceptance |
|---|---|---|---|---|
| Map at rest, p50 | 16.68 | 16.68 | 0.00 (b1 −0.01, b2 +0.08, b3 +0.07) | within +0.5: **met** |
| Map at rest, p95 | 17.20 | 17.14 | −0.06 (b1 +0.02, b2 −0.87, b3 −1.07) | within +0.5: **met** |
| Cold open, engine start to the map's land | 5882 | 5969 | +87 | not slower beyond noise: **met, leaning B's way** (below) |
| Bake site, `--map` boot: the map's first frame | 45.8 (HUD) | 87.9 (bake) | +42 | named (below) |
| Bake site, players' route: the frame that builds the map | 181.2 (HUD) | 287.7 (bake) | +107 | named (below) |
| Fight load frame | 783 | 648 | −135 | by design: B finds the bake made |
| Fight's first frame after the load | 15.0 | 108.0 | +93 | by design (below) |
| Combat rest, ash and face-up discard, p50 / p95 | 16.67 / 17.30 | 16.66 / 17.39 | −0.01 / +0.09 (p95 b1 −0.01, b2 +0.46, b3 +0.04) | measured |
| Reshuffle of cards dealt before, p50 / p95 | 16.68 / 18.29 | 16.67 / 18.39 | −0.01 / +0.10 (p95 b1 −0.06, b2 +0.34, b3 +0.30) | measured |
| Reshuffle, worst frame | 24.3 | 30.1 | +5.8 | measured (below) |
| Video memory at the combat rest (MiB) | 669 | 648 | −21 | the bench's card released on the map |

- **The map at rest: met.** Two of main's launches, kam3 and kam6 (at 38.5
  and 40.0 °C), have uneven pacing (p50 16.51 and 16.54, p95 18.85 and
  19.24) without meeting the throttle rule. They are the outliers, and they
  tilt b2's and b3's p95 deltas towards B. Without them main's p95 median is
  17.18 against B's 17.14, so the line is still met. B's six p95s run from
  17.11 to 17.23.
- **The bake on the `--map` boot.** The run HUD is built before the map's
  first drawn frame, and B's bake lands in that frame (frame 1) in all six
  launches. It takes 63.5–100.4 ms against main's 40.1–57.6 ms for the same
  frame: +42 ms on the medians, the A12 bake cost CardBacks measured earlier
  (33–58 ms). In both builds that frame is over 33 ms in every launch. The
  other frames over 33 ms within ±10 are frame 0 (the probe's first) in kbm4
  (45.6) and kbm6 (39.4), kbm6's +6 (48.2) and +10 (298.5), and main's kam3
  +2 (49.3). kbm6's 298.5 ms frame is the map's one canvas pipeline compile
  about 0.2 s in. Both builds have that compile when it misses the cache: in
  main's kam1 (133 ms), kaw2 (250) and kaw3 (283) at frames 15–16, and in the
  branch's kbm1 (233), kbm3 (133), kbm5 (267), kbm6 (298), kbw2 (117) and
  kbw3 (383) at frames 11–14. Only in kbm6 does it fall inside the window.
  Video memory: on B it is 228 MiB in the bake frame and 238–242 in the next,
  then 225 or 239 once the bench has gone (3–13 MiB less); on main it goes
  203 → 214/217 → 218/232. With the map in the same state, the branch holds
  7 MiB more at rest: the baked back the stacks wear.
- **The bake on the players' route** (Back to the Road from the title). B's
  bake lands in the frame that builds the map and the run HUD; its `rbaked`
  and `rhud` marks are the same frame in all six launches. That frame takes
  263.1–314.1 ms (median 287.7) against main's 179.7–183.4 ms (181.2). The
  flood drawn in it is at full cover with alpha 0.96–0.99 (main 0.97–0.99),
  so the frame with the painting is covered. In both builds the flood in the
  next frame has dropped to 0.52–0.57 alpha, because the fade catches up after
  the long frame. The bake therefore holds the full flood for about 0.1 s
  longer, a stall main already has. Frames over 33 ms within ±10: on B only
  the bake frame (6/6); on main the HUD frame and also a 50–67 ms frame after
  it in 5 of 6. Over the two frames that comes to about 288 + 17 ms against
  181 + 50 ms: +57 ms. Video memory: B rises 132 MiB in the bake frame
  (338 → 470) and is at 364 two frames later; main rises 111 (330 → 441) and
  settles at 352.
- **The cold open: met within noise, leaning B's way.** The medians differ
  by +87 ms (+1.5%), inside the spread between launches (A 5699–7440,
  B 5819–8076; a Mann–Whitney U of 12 for six against six, p ≈ 0.4). Still,
  B is later in five of the six pairs (+120, −37, +178, +636, +245, +1353).
  Split at the probe's first frame, the difference sits before that frame:
  - engine start to the first frame (building the map, the run HUD and, on
    B, the bake's bench): A 3644 ms, B 3782 ms (+138; U = 9, p ≈ 0.18);
  - first frame to the land: A 2317 ms, B 2295 ms.

  The slowest three (kbm4 8076, kbm6 7529, kam4 7440) are each install's
  second map launch, after a fight launch, at 39.7–40.6 °C.
- **The fight's load: different by design.** `BEFORE_LOAD` reads
  `baked=true back=vault` in all six of B's fights and `baked=false` in all
  six of main's. The branch's fight finds the map's bake made, while main
  bakes inside its load. Load frame: B 629.9–666.0 ms (median 648); main
  767.5–833.8 (780 without kaf1; 783 with it). kaf1's 7866 ms load is that
  install's first fight, since its warm-up warmed only the map. B's first
  frame after the load takes 84.7–119.0 ms (median 108) against main's
  8.5–25.1 (15), likely the GPU work that main's bake readback finishes
  inside the load. Taking the load and its next two frames together: B
  766 ms, main 822 (−56).
- **What the branch moves into the fight.** In all six of B's fights, the
  end of turn 1 (the hand sweeping face up to the discard) compiles 4 surface
  pipelines, 1 draw and 1 specialisation. The end of the reshuffle (the
  stream's last frame or the deal's first) compiles the same again. Main
  compiles nothing after its load in any of its six; its counts stay at
  135 / 7 / 46 from the load frame on. Main's bake runs on the fight's own
  tree, so it compiles these pipelines inside the load. The branch's bench
  on the map compiles its own instead, and the fight's flights then compile
  theirs at first use. At the end of turn 1 that frame takes about 21 ms. At
  the reshuffle the compile lands in the frame that also allocates the deal's
  18.5 MiB. There B's worst frame is 23.8–46.8 ms (median 30.1) against
  main's 22.0–41.8 ms (24.3). Over 33 ms: kbf3 at 46.8 (the stream's last
  frame) and kbf5 at 37.0 (the deal's first), and main's kaf4 at 41.8 (the
  deal's first, with no compile). The reshuffle's p95 stays within +0.5 ms
  on every batch. Not tuned here.
- **The combat rest with a charred card on the ash and a face-up discard.**
  p50 −0.01 and p95 +0.09 on the medians, and no frame over 33 ms in any of
  the twelve windows. Video memory at rest: B 648 MiB in all six, main 669
  (656 in kaf4). The bench's card is let go on the map, while main's baking
  card stays in the fight's tree.
- **PR 5's reshuffle account, settled.** These were real fights in which the
  nine reshuffled cards had all been dealt before (`dealt_before=true` in all
  twelve). On main, the frame from the stream to the deal takes 22.0–24.5 ms
  in five of six fights. kaf4's 41.8 ms deal frame is the exception, with no
  pipeline compile in it. PR 5's 37.2 ms frame was the probe's first build of
  cards never dealt, as that README reasoned.
- **Warm-ups** (each install's first launch; not graded). Only kaw1 was
  truly cold: frames of 4202, 10 634, 4899 and 1264 ms among its first
  eight, and the land at 31.4 s. The other five found the QA container's
  shader cache warm from earlier launches. Their bake or HUD frames: kbw1
  88.9 ms (throttled from 4 s), kbw2 83.7, kbw3 79.0, kaw2 46.6, kaw3 44.1.

Every launch below. Battery, charging state and temperature are as logged
just before the launch. The throttle onset is in seconds from the probe's
first frame. The figures are in ms:

| Batch | Launch | Build | Mode | Battery, temp. | Throttle onset | Figures (ms) |
|---|---|---|---|---|---|---|
| b1 | kaw1 (warm-up) | A | map | 100%, not charging, 30.5 C | none | rest p50 16.63 / p95 17.87; HUD frame 4202.1; land at 31388 |
| b1 | kam1 | A | map | 100%, not charging, 33.4 C | none | rest p50 16.67 / p95 17.21; HUD frame 40.9; land at 5699 |
| b1 | kar1 | A | route | 100%, not charging, 33.0 C | none | HUD frame 183.4 under flood a0.97; >33 within 10: +0:183.4 +1:49.9 |
| b1 | kaf1 | A | fight | 100%, not charging, 33.1 C | none | load 7866 (baked=false); ash rest p50 16.67 / p95 17.54; reshuffle p50 16.68 / p95 18.45, max 24.5 |
| b1 | kam2 | A | map | 100%, not charging, 36.7 C | none | rest p50 16.70 / p95 17.19; HUD frame 41.4; land at 5988 |
| b1 | kar2 | A | route | 100%, not charging, 34.8 C | none | HUD frame 181.3 under flood a0.99; >33 within 10: +0:181.3 |
| b1 | kaf2 | A | fight | 100%, not charging, 34.8 C | none | load 767 (baked=false); ash rest p50 16.67 / p95 17.20; reshuffle p50 16.70 / p95 18.29, max 24.1 |
| b1 | kbw1 (warm-up) | B | map | 100%, not charging, 37.7 C | 4 s | rest p50 17.69 / p95 20.85 (throttled); bake frame 88.9; land at 6454 |
| b1 | kbm1 | B | map | 100%, not charging, 36.8 C | none | rest p50 16.67 / p95 17.23; bake frame 87.7; land at 5819 |
| b1 | kbr1 | B | route | 100%, not charging, 35.8 C | none | bake frame 314.1 under flood a0.98; >33 within 10: +0:314.1 |
| b1 | kbf1 | B | fight | 100%, not charging, 36.1 C | none | load 646 (baked=true); ash rest p50 16.68 / p95 17.36; reshuffle p50 16.62 / p95 18.39, max 29.9 |
| b1 | kbm2 | B | map | 100%, not charging, 38.2 C | none | rest p50 16.68 / p95 17.22; bake frame 63.5; land at 5951 |
| b1 | kbr2 | B | route | 100%, not charging, 36.4 C | none | bake frame 298.4 under flood a0.99; >33 within 10: +0:298.4 |
| b1 | kbf2 | B | fight | 100%, not charging, 36.1 C | none | load 650 (baked=true); ash rest p50 16.65 / p95 17.36; reshuffle p50 16.74 / p95 18.23, max 23.8 |
| b2 | kbw2 (warm-up) | B | map | 100%, not charging, 37.3 C | none | rest p50 16.67 / p95 17.12; bake frame 83.7; land at 5690 |
| b2 | kbm3 | B | map | 100%, not charging, 37.4 C | none | rest p50 16.67 / p95 17.11; bake frame 88.1; land at 5955 |
| b2 | kbr3 | B | route | 100%, not charging, 37.1 C | none | bake frame 293.4 under flood a0.99; >33 within 10: +0:293.4 |
| b2 | kbf3 | B | fight | 100%, not charging, 37.2 C | none | load 633 (baked=true); ash rest p50 16.65 / p95 17.66; reshuffle p50 16.66 / p95 18.39, max 46.8 |
| b2 | kbm4 | B | map | 100%, not charging, 39.7 C | none | rest p50 16.68 / p95 17.15; bake frame 100.4; land at 8076 |
| b2 | kbr4 | B | route | 100%, not charging, 37.9 C | none | bake frame 267.4 under flood a0.99; >33 within 10: +0:267.4 |
| b2 | kbf4 | B | fight | 100%, not charging, 37.0 C | none | load 649 (baked=true); ash rest p50 16.66 / p95 17.49; reshuffle p50 16.61 / p95 18.42, max 29.9 |
| b2 | kaw2 (warm-up) | A | map | 100%, not charging, 39.8 C | none | rest p50 16.45 / p95 19.79; HUD frame 46.6; land at 6853 |
| b2 | kam3 | A | map | 100%, not charging, 38.5 C | none | rest p50 16.51 / p95 18.85; HUD frame 52.0; land at 5777 |
| b2 | kar3 | A | route | 100%, not charging, 37.7 C | none | HUD frame 179.7 under flood a0.99; >33 within 10: +0:179.7 +1:50.9 |
| b2 | kaf3 | A | fight | 100%, not charging, 37.6 C | none | load 786 (baked=false); ash rest p50 16.67 / p95 17.27; reshuffle p50 16.65 / p95 19.03, max 22.0 |
| b2 | kam4 | A | map | 100%, not charging, 39.9 C | none | rest p50 16.68 / p95 17.14; HUD frame 50.3; land at 7440 |
| b2 | kar4 | A | route | 100%, not charging, 37.9 C | none | HUD frame 180.9 under flood a0.99; >33 within 10: +0:180.9 +1:66.7 |
| b2 | kaf4 | A | fight | 100%, not charging, 37.5 C | none | load 768 (baked=false); ash rest p50 16.68 / p95 16.96; reshuffle p50 16.67 / p95 17.10, max 41.8 |
| b3 | kaw3 (warm-up) | A | map | 100%, not charging, 38.4 C | none | rest p50 16.69 / p95 17.13; HUD frame 44.1; land at 6055 |
| b3 | kam5 | A | map | 100%, not charging, 38.4 C | none | rest p50 16.68 / p95 17.16; HUD frame 40.1; land at 5738 |
| b3 | kar5 | A | route | 100%, not charging, 37.8 C | none | HUD frame 183.3 under flood a0.99; >33 within 10: +0:183.3 +1:50.0 |
| b3 | kaf5 | A | fight | 100%, not charging, 37.3 C | none | load 834 (baked=false); ash rest p50 16.68 / p95 17.36; reshuffle p50 16.64 / p95 18.28, max 24.4 |
| b3 | kam6 | A | map | 100%, not charging, 40.0 C | none | rest p50 16.54 / p95 19.24; HUD frame 57.6; land at 6176 |
| b3 | kar6 | A | route | 100%, not charging, 38.2 C | none | HUD frame 181.1 under flood a0.99; >33 within 10: +0:181.1 +1:50.9 |
| b3 | kaf6 | A | fight | 100%, not charging, 37.8 C | none | load 780 (baked=false); ash rest p50 16.66 / p95 17.32; reshuffle p50 16.70 / p95 18.07, max 23.8 |
| b3 | kbw3 (warm-up) | B | map | 100%, not charging, 39.9 C | none | rest p50 16.67 / p95 17.14; bake frame 79.0; land at 6921 |
| b3 | kbm5 | B | map | 100%, not charging, 39.3 C | none | rest p50 16.68 / p95 17.14; bake frame 81.8; land at 5983 |
| b3 | kbr5 | B | route | 100%, not charging, 38.3 C | none | bake frame 263.1 under flood a0.96; >33 within 10: +0:263.1 |
| b3 | kbf5 | B | fight | 100%, not charging, 38.2 C | none | load 630 (baked=true); ash rest p50 16.68 / p95 17.42; reshuffle p50 16.71 / p95 18.31, max 37.0 |
| b3 | kbm6 | B | map | 100%, not charging, 40.6 C | none | rest p50 16.67 / p95 17.13; bake frame 96.1; land at 7529 |
| b3 | kbr6 | B | route | 100%, not charging, 38.4 C | none | bake frame 282.0 under flood a0.99; >33 within 10: +0:282.0 |
| b3 | kbf6 | B | fight | 100%, not charging, 37.9 C | none | load 666 (baked=true); ash rest p50 16.66 / p95 17.34; reshuffle p50 16.68 / p95 18.64, max 30.2 |

**The orchestrator's calls on b1–b3 (10 Oct 2026).** Risk 1, the pipeline
compiles the branch moved into the fight, is fixed in this PR (`c4b1a418`
and `40b7f302`, below). The other three are accepted as recorded:

- **Risk 2, the route bake holding the full flood about 0.1 s longer:**
  accepted. The painting never shows, and main already stalls there.
- **Risk 3, the cold open:** accepted as within noise. The lean is the
  split: +138 ms before the first frame (p ≈ 0.18). Not tuned.
- **Risk 4, the temperature logging:** b1–b3 logged hundredths of a degree
  unpadded (36.09 °C as "36.9C"). `analyze.py` pads them back, so the table
  above is right. `batch.zsh` pads them since; the doc copy is the version f1,
  g1 and g2 ran, and its comment on that line says how b1–b3 differ.

### The fix: the fight holds its cards' generated shader and waits for its load's draw (`c4b1a418`, `40b7f302`)

**What moved, and why.** Two of the costs main's bake used to pay inside
the fight's load were left to the fight:

- **A generated shader freed mid-fight.** A card's side band wears a
  `StandardMaterial3D`. The engine generates that shader and frees it, with
  every pipeline compiled for it, when the last ready material that wears
  it goes. A hand swept to the discard leaves no card standing, so the next
  deal made the shader again and compiled its pipelines mid-fight. That was
  4 surface pipelines, 1 draw and 1 specialisation each time, at turn 1's
  end and again at the reshuffle. On main the bake's card, retired but kept
  by the fight, held a side material all fight long. With `--verbose`,
  b1–b3's branch build re-creates one `SceneForwardMobileShaderRD` shader
  between the kindle and turn 2, and again between the reshuffle's End Turn
  and turn 3. The fixed build (`40b7f302`, fxgv) re-creates none after its
  load.
- **The load's GPU work.** Main's bake read the back off the GPU after the
  load's draw, which waited for that draw to finish. On the branch the
  entrance's first frame did the waiting instead (median 108 ms on the
  iPad). PR 3's evidence names the same frame: it ran 110–165 ms without
  the pre-warm.

**The change**, inside the fight's load and the cards' materials (89 lines
with their comments):

- `CardView.side_material`: the side band's one factory, which
  `_build_stage` now calls.
- `CardView.generated_materials`: one of each generated material, made
  ready with `get_rid()`. A material made lazily never holds its shader: a
  keeper that had never been used changed nothing (Mac `fxb1`).
- `CardTurn.hold_for_fight`, which `Main._prewarm_card_turns` calls after
  `prewarm` in every fight's load. It adds a `CardShaderHold` node under the
  fight that holds those materials, so it leaves with the fight. It also
  reads one texel back after the load's draw. In `c4b1a418` the read was a
  one-shot lambda on `RenderingServer.frame_post_draw`, holding its texel.
  `40b7f302` made it a method of the hold, so a wait still pending goes with
  the fight. A run that never draws (the headless suite) had left the lambda
  connected until exit and crashed in shutdown (Core gate, below). A drawn
  fight behaves the same under either.

The map's path, the bake, the bench and the stack are unchanged
(`prewarm` and `prewarm_on_bench` are untouched).

**The map modes need no re-run.** The diff from `c3222ae0` to `40b7f302`:

- `application/main.gd`: one call added in `_prewarm_card_turns`, which only
  the two fight starts call.
- `presentation/cards/card_turn.gd`: `hold_for_fight` and its `_Hold` node
  added, plus comments. Nothing else in the file changes.
- `presentation/combat/card_view.gd`:
  - `side_material` holds the side band's four statements, moved as they
    were. `_build_stage` calls it with the same colour, so the map's cards
    (the bench's back, the deck view's card under the finger) wear the same
    material.
  - `generated_materials` is called only by `hold_for_fight`.
- `tests/test_card_turn.gd`: tests only.
- Two docs whose line anchors the new lines moved.

**Mac, the decisive check** (M1 Max, Metal, Forward Mobile, the A12
condition `GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1`, 1180 × 820, the load
average 4–7 at each start but fxg1's). The fight probe is the iPad's. The counters are
surface / draw / specialisation; the canvas count moves at the kindle on
every build.

| Run | Build | At the load | At turn 1's end | At the reshuffle | Load frame | +1 | +2 |
|---|---|---|---|---|---|---|---|
| fxa0, fxa1 | main `711302a5` | 143 / 23 / 65 | 143 / 23 / 65 | 143 / 23 / 65 | 267.7, 244.0 | 3.5, 3.6 | 8.7, 8.3 |
| fxb0 | branch before, `0b985fbd` | 148 / 25 / 67 | **152 / 26 / 68** | **156 / 27 / 69** | 257.0 | 20.1 | 2.5 |
| fxf1, fxf2, fxf3 | branch after, `c4b1a418` | 148 / 25 / 67 | 148 / 25 / 67 | 148 / 25 / 67 | 203.5, 202.7, 209.4 | 3.4, 3.5, 3.5 | 8.3, 9.1, 8.1 |
| fxg1 | branch after, `40b7f302` (load average 96) | 148 / 25 / 67 | 148 / 25 / 67 | 148 / 25 / 67 | 242.0 | 3.6 | 8.6 |

On the Mac, video memory at the combat rest is 489 and 485 MiB for main,
481 before the fix, 464 on `c4b1a418` and 480 on `40b7f302`. Runs of one build
repeat these to the tenth. I have not explained `c4b1a418`'s extra
16 MiB below the rest; both builds are under main. The Mac's other frame times swing
with the desktop: main's fxa1 ran a 111 ms frame at turn 1's end and
50–65 ms frames at rest, with no compile in any of them. So the Mac
grades the counters and the frame after the load. The iPad grades the
times.

These runs settled the diagnosis:
- A fight that kept a live back card (fxb2), or the card's own side
  material (fxb3), or a ready material from the factory (fxb5), compiled
  nothing after its load.
- A keeper that had never been used (fxb1) changed nothing.
- The texel read back after the load's draw alone took the frame after the
  load from about 20 ms to 4.8 ms (fxb4).

**iPad 8: the fight-only batch on `40b7f302`** (10–11 Oct 2026, 22:59–00:12)
- **Builds:** A is main's IPA from b1–b3 (sha256 `d75c5c4b…`; `origin/main` is
  still `64af9302`). B was rebuilt from `40b7f302` (`3c60c8ce…`).
- **Sessions:** two lock sessions, interleaved by install: g1 A then B, g2 B
  then A. Before each session the campaign waited for the lock to come free
  (g2 waited for ks2-main's session), then for the battery to cool to
  36.0 °C, and only then took the lock.
- **Launches:** each install ran a warm-up map launch, then three fights
  150 s apart, so six measured fights on each build.
- **Conditions:** the iPad was on its charger (99% down to 96%), at
  36.7–41.6 °C.
- **Throttle:** three of the twelve fights throttled: B's rbf2 (from 15 s)
  and rbf5 (from 25 s), and main's raf6 (from 13 s).
- **Records:** the analysis is `device/summary-fix.txt` and the batch logs
  are `device/g1-batch.log.txt` and `g2-…`.

Medians over the six fights of each build, with g1 / g2 in brackets:

| Figure (ms) | B, `40b7f302` | Main, this batch | The bar | Verdict |
|---|---|---|---|---|
| Pipeline compiles after the load (surface, draw, specialisation) | none in 6 of 6: 138 / 9 / 48 from the load frame to the end | none in 6 of 6: 135 / 7 / 46 | none | **met** |
| Load frame | 767.3 (749.6 / 768.5) | 791.7 (799.7 / 783.7) | ≤ 783 | **met** |
| The load and the next two frames | 813.5 (782.5 / 849.2) | 836.1 (839.6 / 832.6) | ≤ 822 | **met over all six and in g1; over the bar in g2, as main is too** (below) |
| First frame after the load | 16.3 (16.4 / 16.3); 6.3–21.2 | 16.4; 15.3–16.5 | within main's 8.5–25.1 | **met**, so no cover is needed (the probe draws none) |
| Video memory at the combat rest (MiB) | 648 (634–648) | 662 (656–669) | ≤ 669 | **met** |
| Turn 1's end, worst frame | 33.3 (29.1–46.6) | 45.8 (30.2–49.8) | reported | b1–b3: the branch 30.6 with its compile, main 27.7 |
| Reshuffle, worst frame | 23.8 (21.9–27.7) | 25.2 (23.6–27.2) | reported | b1–b3: the branch 30.1 |
| Reshuffle p50 / p95 | 16.71 / 18.93 | 16.69 / 18.19 | reported | below |
| Combat rest p50 / p95 | 16.69 / 17.44 | 16.68 / 17.30 | reported | p95 +0.14 (g1 +0.50, g2 +0.08) |

- **The compiles are gone.** None of B's six fights compiles a surface,
  draw or specialisation pipeline after its load, matching main.
  `c4b1a418`'s three fights in f1 compiled none either.
- **The load and the next two frames in g2.** B's g2 median, 849.2, is over
  the 822 bar for two reasons:
  - rbf4, the install's first fight in that session, loaded in 933.8 ms;
  - rbf5, throttled from 25 s, drew a 59.5 ms second frame.

  Main's own g2 median, 832.6, is over the bar too (raf5 loaded in
  863.2 ms): this batch ran at 36.7–41.6 °C, against 33–40 °C in b1–b3. Within
  each session B − A is −57.1 ms (g1) and +16.6 (g2). Over all six it is −22.6.
- **Second frames of about 50 ms:** rbf1 50.1 and rbf5 59.5 on the branch.
  Main's ran 33.3 in raf4 and raf5 here, and 49.6–50.1 in three of b1–b3's
  fights.
- **The reshuffle's p95 leans B's way**: +0.74 over all six (g1 +1.59, g2
  +0.64). Without the three throttled fights it is +0.80 (B 18.84, from 18.13
  to 19.31; main 18.04, from 17.06 to 18.83). A Mann–Whitney test over all six
  gives p ≈ 0.18. In b1–b3 the branch was +0.10, and its worst reshuffle
  frame has improved since. The fix adds nothing that runs in a frame (one
  node holding one material). With six fights at these temperatures I can't
  separate the lean from noise.
- **Outliers:**
  - rbf4: load 933.8;
  - raf5: load 863.2;
  - rbf1: first frame 6.3, below main's range, so faster;
  - rbf2, rbf5 and raf6: throttled. raf6's rest p95 is 21.71 and its
    reshuffle p95 22.42; rbf2's are 18.70 and 20.81.
- **Warm-ups** (named, not graded), with the bake or HUD frame each drew on
  the map: raw1 45.4 ms, rbw1 104.3, rbw2 122.3, raw2 167.3. rbw2's
  battery read charging.

Every fight, with battery, charging state and temperature as logged before
it. The counters run canvas / mesh / surface / draw / specialisation, and
"changes after it" lists only surface, draw and specialisation:

| Batch | Launch | Build | Battery, temp. | Throttle onset | Counters at the load | Changes after it | Load | +1 | +2 | Turn 1's end, worst | Reshuffle worst / p50 / p95 | Rest p50 / p95 | VRAM at rest |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| g1 | raf1 | A | 99%, not charging, 36.7 C | none | 22 / 10 / 135 / 7 / 46 | none | 800.8 | 15.3 | 23.5 | 46.3 | 23.6 / 16.67 / 18.83 | 16.68 / 17.92 | 669 |
| g1 | raf2 | A | 99%, not charging, 39.7 C | none | 22 / 10 / 135 / 7 / 46 | none | 799.7 | 16.4 | 24.3 | 33.3 | 25.7 / 16.70 / 17.06 | 16.67 / 16.94 | 656 |
| g1 | raf3 | A | 99%, not charging, 40.4 C | none | 22 / 10 / 135 / 7 / 46 | none | 782.9 | 16.5 | 18.9 | 49.7 | 25.4 / 16.68 / 17.20 | 16.67 / 16.92 | 656 |
| g1 | rbf1 | B (40b7f302) | 98%, not charging, 39.4 C | none | 22 / 10 / 138 / 9 / 48 | none | 771.0 | 6.3 | 50.1 | 29.1 | 22.8 / 16.63 / 18.13 | 16.68 / 17.44 | 648 |
| g1 | rbf2 | B (40b7f302) | 98%, not charging, 41.3 C | 15 s | 22 / 10 / 138 / 9 / 48 | none | 699.6 | 16.4 | 16.7 | 33.4 | 25.5 / 17.71 / 20.81 | 17.49 / 18.70 | 634 |
| g1 | rbf3 | B (40b7f302) | 98%, not charging, 41.0 C | none | 22 / 10 / 138 / 9 / 48 | none | 749.6 | 16.4 | 16.6 | 37.7 | 23.4 / 16.71 / 18.79 | 16.68 / 17.26 | 648 |
| g2 | rbf4 | B (40b7f302) | 97%, not charging, 37.4 C | none | 22 / 10 / 138 / 9 / 48 | none | 933.8 | 15.6 | 24.3 | 46.6 | 27.7 / 16.66 / 19.31 | 16.68 / 17.26 | 648 |
| g2 | rbf5 | B (40b7f302) | 97%, not charging, 40.3 C | 25 s | 22 / 10 / 138 / 9 / 48 | none | 768.5 | 21.2 | 59.5 | 33.2 | 24.1 / 16.99 / 18.98 | 16.75 / 17.44 | 648 |
| g2 | rbf6 | B (40b7f302) | 97%, not charging, 40.8 C | none | 22 / 10 / 138 / 9 / 48 | none | 766.1 | 16.3 | 17.2 | 29.5 | 22.0 / 16.71 / 18.88 | 16.70 / 17.47 | 648 |
| g2 | raf4 | A | 97%, not charging, 39.9 C | none | 22 / 10 / 135 / 7 / 46 | none | 783.7 | 15.6 | 33.3 | 45.4 | 25.0 / 16.70 / 18.04 | 16.68 / 17.36 | 669 |
| g2 | raf5 | A | 97%, not charging, 41.4 C | none | 22 / 10 / 135 / 7 / 46 | none | 863.2 | 16.4 | 33.3 | 30.2 | 24.1 / 16.66 / 18.34 | 16.69 / 17.24 | 669 |
| g2 | raf6 | A | 96%, not charging, 41.6 C | 13 s | 22 / 10 / 135 / 7 / 46 | none | 766.1 | 16.5 | 17.3 | 49.8 | 27.2 / 19.34 / 22.42 | 19.42 / 21.71 | 656 |


**The record on `c4b1a418`, not graded.** Its session f1 (A then B, 21:42–22:02)
ran straight after another lane's session, at 34.6–40.6 °C, with 90 s
cool-downs, and four of its six fights throttled. Its three B fights
compiled nothing after the load. Their loads were 750.3, 796.5 and
886.1 ms, and their first frames 15.8, 16.7 and 13.7 ms. I stopped the
campaign before its second session once `40b7f302` replaced the commit.
`device/summary-fix-c4b1a418.txt`, `device/f1-batch.log.txt`:

| Batch | Launch | Build | Battery, temp. | Throttle onset | Counters at the load | Changes after it | Load | +1 | +2 | Turn 1's end, worst | Reshuffle worst / p50 / p95 | Rest p50 / p95 | VRAM at rest |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| f1 | qaf1 | A | 100%, not charging, 35.8 C | none | 22 / 10 / 135 / 7 / 46 | none | 864.9 | 29.9 | 29.0 | 46.0 | 22.7 / 16.68 / 18.91 | 16.68 / 18.24 | 669 |
| f1 | qaf2 | A | 100%, not charging, 38.9 C | 17 s | 22 / 10 / 135 / 7 / 46 | none | 781.0 | 14.7 | 19.2 | 61.1 | 24.0 / 17.71 / 20.92 | 17.69 / 20.29 | 669 |
| f1 | qaf3 | A | 100%, not charging, 39.4 C | 26 s | 22 / 10 / 135 / 7 / 46 | none | 844.3 | 99.6 | 16.5 | 27.5 | 22.9 / 16.97 / 18.71 | 16.66 / 18.22 | 669 |
| f1 | qbf1 | B (c4b1a418) | 100%, not charging, 38.8 C | none | 22 / 10 / 138 / 9 / 48 | none | 750.3 | 15.8 | 23.0 | 22.2 | 21.9 / 16.66 / 17.14 | 16.67 / 17.05 | 634 |
| f1 | qbf2 | B (c4b1a418) | 100%, not charging, 40.4 C | 23 s | 22 / 10 / 138 / 9 / 48 | none | 796.5 | 16.7 | 20.1 | 46.2 | 37.8 / 19.06 / 21.41 | 16.73 / 18.34 | 648 |
| f1 | qbf3 | B (c4b1a418) | 100%, not charging, 40.6 C | 17 s | 22 / 10 / 138 / 9 / 48 | none | 886.1 | 13.7 | 50.0 | 25.4 | 110.9 / 21.34 / 23.79 | 18.38 / 21.92 | 648 |

## Tests and mutations

`tests/test_deck_stack.gd`: the card and the law scaled to it at the pad's
and the phone's squares, the top card held at every count, nothing in the
stack taking the pointer from its button; the run HUD's stack glinting
once a cycle and never under Reduce Motion; the painting until a back is
baked, the back once it is, the painting again after a change of back and
the new back once its bake lands, a stack built after the bake wearing it
from its first frame; the seal's and the draw pile's glints never crossing
together in 18 s (and each crossing), Reduce Motion stilling the seal's; the
run HUD's stack counting the run's deck at every refresh and shape and a tap
asking for the deck view; the seal counting draw, hand and discard (never
the ash) at four mixes, its top card 2 px under its button at the pad and the
phone, and a tap opening the deck.

`tests/test_card_turn.gd` (`_run_hud_bakes_outside_a_fight`,
`_fight_joins_the_route_bake`), on a real `Main`: the map's first build bakes the chosen back in the frame that builds
it, on a bench under `Main`, with the deck on its painting until it lands;
the bench is gone once it has; the deck wears the bake; a later route with
the HUD makes no bench and bakes nothing; the fight's load then bakes
nothing; after a change of back the next route bakes the new back on a bench
and the deck follows it; a bake dropped under the table is made again by the
next route. A fight that loads while the route's bake is still in flight
joins it (CardBacks' shared job): one bake, never read through a host freed
under it, and the fight's draw pile and seal both end on the baked back.

`tests/test_piles.gd` (`_glint_fills`): at ±0.681 the glint draws only
pieces a triangulation takes; mid-card it draws both halves.

Twenty-four mutations (`device/mutations.json.txt`, run by
`device/mutate.py.txt`: back up, break, run the one test, copy back), every
one caught, on the tests as committed (`4e38aeb9`). For `j01` the line is the
new test's; an older test in the same file fails first.

| Mutation | What it breaks | Caught by |
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
| `b02-no-bench` (`main.gd`) | the bake runs on Main itself, not a bench | card turn: the map's first build baked [[<Control#359602852346>, "vault"]], want vault on a bench |
| `b03-bench-kept` (`card_turn.gd`) | the bench is kept after the bake | card turn: the bench outlives its bake |
| `b04-no-guard` (`main.gd`) | every route with the HUD makes a bench | card turn: a later route with the HUD baked again ([[<Freed Object>, "vault"]], 1 benches) |
| `b05-guard-on-wearing-only` (`main.gd`) | a dropped bake counts as worn | card turn: a dropped bake is not made again by the next route: [[<Freed Object>, "vault"], [<Freed Object>, "eclipse"]] |
| `b06-default-not-chosen` (`main.gd`) | the default back is baked, not the chosen one | card turn: the route after a change of back baked [[<Freed Object>, "vault"], [CardBackBench:<Node#426107737987>, "vault"]], want eclipse on a bench |
| `d14-seal-held-by-square` (`hud_bar.gd`) | the seal's top card held by the painting's square | combat seal: on pad-landscape its top card stands -4.00 px under the button's top, want 2.00 |
| `p01-glint-sliver-drawn` (`pile_stack.gd`) | the glint draws slivers no triangulation takes | piles: the glint at -0.681 draws a sliver the canvas cannot fill |
| `j01-no-shared-join` (`card_backs.gd`) | a second caller of a bake in flight bakes again (no shared job) | card turn: a fight loading under the route's bake baked 2 times, want once |
| `j02-bench-freed-in-flight` (`card_turn.gd`) | the bench is let go before its bake lands | card turn: a bake in flight was read through a freed host: ["vault"] |
| `r01-rm-ignored-by-the-stack` (`pile_stack.gd`) | Reduce Motion ignored by the stack's glint (seal and run HUD) | deck stack: under Reduce Motion the seal still glints |

**The fix's tests** (`40b7f302`), in `tests/test_card_turn.gd`:

- `_generated_materials_held`, the structural guard. Every BaseMaterial3D on
  a front's stage and on a back's must match one material in
  `CardView.generated_materials`, the list a fight holds. The match is by
  class and by every stored setting except the values its shader reads as
  uniforms (colours, numbers, vectors); a texture counts only by whether
  there is one. The key comes from the material's own property list, not
  from a hand-kept list. So a generated material a card gains later, or the
  side band made otherwise than by `side_material`, fails it.
- `_fight_holds_its_cards_shader`: a real `Main`'s fight load leaves a
  `CardShaderHold` under the fight, holding those materials.

What the suite cannot see headless is shown on the Mac:

- whether a held material was made ready (`fxb1` against `fxb5`);
- the texel wait (the frame after the load).

Five mutations (`device/mutations-fix.json.txt`), every one caught on
`c4b1a418` and again on `40b7f302`:

| Mutation | What it breaks | Caught by |
|---|---|---|
| `g01-no-generated-listed` (`card_view.gd`) | `generated_materials` lists nothing | card turn: a front's stage wears a generated material no fight holds |
| `g02-side-made-otherwise` (`card_view.gd`) | the side band's material made otherwise than `side_material` makes it | card turn: a front's stage wears a generated material no fight holds |
| `g03-fight-holds-nothing` (`main.gd`) | a fight's load does not hold its cards' generated materials | card turn: the fight holds [] of its cards' generated materials |
| `g04-held-outside-the-fight` (`card_turn.gd`) | the hold is put beside the fight, not under it | card turn: the fight holds [] of its cards' generated materials |
| `g05-hold-empty` (`card_turn.gd`) | the hold keeps none of the generated materials | card turn: the fight holds [] of its cards' generated materials |

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

On `4e38aeb9`, at a load average of 7 to 18: `godot --version` (4.7.2.stable),
`tools/check_imports.sh`, `tools/check_scripts.sh` (493 scripts), `godot
--headless -s res://tests/run_all.gd`, then `check_anchors.py`,
`check_benchmark_freeze.py` and `payload_report.py`: green, **PASS (157
tests)**, anchors OK, 592 citations frozen, payload within budget. On
`c48be94b` it was green too, on a re-run: its first full run, at a load
average of 72 to 79 from other lanes' balance runs, failed one real-time
assertion (`test_card_flights`: under Reduce Motion a leaving card had not
left within its 0.16 s fade and 0.05 s of slack), which then passed alone
twice and in the full re-run.

**On the fix.**

- **`c4b1a418`, load average 7–20:** every step green, and the suite printed
  **PASS (157 tests)**, but it then crashed in shutdown (signal 11, exit
  134). The cause was a one-shot lambda on `RenderingServer.frame_post_draw`
  that held its texel. A headless run never draws, so the lambda stayed
  connected until exit. `tests/test_card_turn.gd` alone shows it on that
  commit: 5 textures leaked, then the crash.
- **`40b7f302`, which moved the wait onto the fight's hold:**
  - **Run 1 (load 88–101):** failed one real-time assertion,
    `test_pile_fight`'s "a kindle bumped the ash 0 times under Reduce
    Motion". That test waits at most 10 s of wall clock for the sequencer
    and never builds a `Main`, so the fix is not in its path. It passed
    alone twice at a load of about 70.
  - **Run 2 (load 73–95):** green, **PASS (157 tests)**, exit 0. Anchors
    OK (the four the new lines moved were re-anchored by hand), 592
    citations frozen, and the payload within budget (pack estimate
    277.2 MiB).

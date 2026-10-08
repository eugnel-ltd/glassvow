# #657 PR 5, piles of real cards: evidence

Measured and shot on the branch's code (`582ba419`; `acf3a6d3` adds only
documents). §4 and §3 are the dossier's (`../../README.md`). The probe
scripts, the batch and the mutation lists are text under `device/`; the raw
rows stay out of the repository.

## §4 as built

| Spec | Built | Where it differs, and why |
|---|---|---|
| Thickness law | 1 px a card up to ten, then 0.35 px, capped at 14 px in pad stage px (`PileStack.thickness`); the HUD's shell scales a phone's pile (64 of 96 px). One sliver per pixel, at most 24, two alternating tones darkening with depth, each jittered by a hash of its depth (±0.6 px, ±0.6°). | — |
| Draw pile | Squared, backs up in the table's baked back (`CardTurn.back`, followed as it is baked at the fight's load). Empty, it draws nothing; its count and name stay. | Its top card lies square, so a dealt card now leaves it at 0° (`CardFlight.PILE_TILT`): the −4° of §3's Draw row was the painting's lean. |
| Discard pile | Face up: the top is the last discarded card's face at the angle it landed at (`CardFlight.landing_rot`, ±3° played, ±5° and ±3 px swept); the cards under it lie loose (±3 px, ±5°). | The face is the card's own stage at rest, copied on the GPU as it lands (`CardFaces.take`): no bake and no readback. A card not yet at rest hands it on while it lies on the pile; one that went first (a strike not at rest, a fade, a card a foe added) is baked (`CardFaces.request`). A face is drawn at a third of its texels or less with no mipmaps, so it is drawn as four taps a third of a pixel apart, averaged: one bilinear tap sparkled. |
| Ashes | Backs up, charred (`CardFlight.CHAR`, the tint a burnt card lands in), an ember rim round the top card, at 0.9. | The slivers are cinders, a third of them catching: at a pixel a sliver, an ember on every edge read as one orange band. |
| One `_draw()`, about 26 commands, no node per card, one shared texture | Each pile is one `PileStack` and one `_draw()`: a shadow, at most 14 slivers (the thickness caps at 14 px) and the top, at most 19 draws (a face takes four taps) and a transform before each sliver and the top. | The life at rest sits on one small child of the draw and ash piles (`_Glow`), so a breath changes a modulate and a glint redraws one polygon pair: the pile's own `_draw()` runs only when its count, top or back changes. |
| Replaces the fan and the paintings | The `Fan`, `fly_backs` and the discard and ashes paintings are gone. | Recorded as row 26 of `docs/benchmark-divergence.md`. The draw painting stays: it is the Vault back's art. |

The pile card keeps the painted card's footprint (58.6 × 83.2 px in the pad's
96 × 130 box), so the flights PR 4 measured leave and reach a pile at the same
size.

## §3 rows as built

| Row | Built | Where it differs, and why |
|---|---|---|
| **Play** (attack) | A struck card bound for the discard hands its face on at the end of its strike; when its `toDiscard` lands the pile copy, the discard's top becomes that face (`DiscardTop`), as the blow resolves. | — |
| **Shuffle** | `PileStream`: at most eight cards fly, `0.6 s × 0.35 / n` apart, the last landing 0.6 s after the first leaves; the discard's top lifts face up and turns face down in the first 40% of its flight (the picture turn over its baked face: a `face_span` uniform on `card_turn.gdshader`, default off), the rest the table's back, the discard turned over as a block; the arc peaks at 11–17% of the stage height; the discard thins as each leaves and the draw pile thickens as each lands; the deck jogs ±2 px for 120 ms and squares up. 0.72 s in all. The `card` cue, as before. | The jog stands in for the draw pile's bump at the end. |
| Shuffle: Skip | A tap anywhere (heard, never consumed) completes the stream within 150 ms; the drain moves on as the last card lands, the deck squaring itself meanwhile. | — |
| Shuffle: Reduce Motion | No stream: the counts move at once and each pile gives one 200 ms pulse. | The pulse is light (brightness 1.25 and back), not a swell: Reduce Motion. |
| **Idle life at rest** | A glint crosses the draw pile's top back once every 9 s (1.4 s of sweep); the ash rim breathes 0.45 to 0.65 over 3.2 s. Canvas only. Reduce Motion: no glint, the rim holds at 0.55. | The top-menu stack's glint is not here: see below. |
| Play / End of turn, the landing | A card that lands on the discard is its top at once; the moment the pile wears its face the card lying on it goes (`HandView.hand_over`), instead of PR 4's 0.3 s hold and fade. A burnt card keeps PR 4's hold while its rim cools. | — |

**Counts.** A pile shows the domain's count less what has not happened on
screen: the events still queued (`EventSequencer.pile_change`) and the cards
still in the air to it (`HandView.in_air`), each card once. A deal walks the
draw pile down card by card (the per-wave override is gone), a discard
thickens as each card lands, and at rest every pile is the domain's. The
reshuffle alone walks two piles by hand.

**The inspector** (`CombatScreen._show_inspector`): the pile's cards on baked
faces (`CardGrid`, as the deck view), one live card under the finger; the draw
pile sorted, so looking does not tell the draw order (the text list grouped
cards by first appearance in it); the discard and the ash top down. The deck
seal's view is the same. No new strings.

**Not built: the top-menu deck as a stack (item 6).** PR 2 did not build it.
It needs the chosen back baked outside a fight: the run HUD shows on the map,
before any fight of a session, and the back is baked only at a fight's load
(`CardTurn.prewarm`). A new bake site at a still moment on the road, with its
own iPad measurement, plus `run_hud.gd` and the combat seal, is a second
reviewable change; it is left for its own PR.

## PR 4's review carry-overs

- **A kindle and its EXHAUST bump the ash once.** Since PR 4 a kindled card
  flies to the ash from its KINDLE event, and the EXHAUST that follows finds
  it already sent (it still lies on the pile) and does not answer again: the
  ash is bumped once, not twice as before PR 4. Under Reduce Motion the
  kindled card fades and never arrives, and the EXHAUST's pile copy bumps the
  ash: once either way. `tests/test_pile_fight.gd` asserts both.
- **A Skip tap racing a play, and racing an End Turn**: tested in a live fight
  (`_skip_races`): one card played once, every card face up in its seat, the
  next turn's deal dealt in full, the piles the domain's.
- **The seat arithmetic** goes through the hand's global transform
  (`HandView._seat_of`); tested under an ancestor scaled 0.5.
- **`_deal_gap` and a freed screen.** Freeing the screen mid-deal did resume
  `_deal_gap` on it and log "Resumed function '_deal_gap()' after await, but
  class instance is gone"; so did `CardView._ready`'s two-frame await on a
  card freed within two frames. The drain's waits now step on the screen's
  own frames (`_frame_ticked`, which a freed screen never emits), and a card
  freezes on a one-shot connection. Tested: a screen freed mid-deal,
  mid-flight with a bake landing late, and mid-reshuffle logs nothing.

## Tests and mutations

`tests/test_piles.gd`: the law, the stack's top following its count, a top
named before its face keeps the old picture, the glint's cycle and the rim's
breath and their Reduce Motion column, the stream's timing, its turn and its
Skip, the queue's pending counts with cards in the air counted once, the
discard top (a face handed on before arrival, a bake asked when there is
none, the idle settle), a seat under a scaled ancestor.

`tests/test_pile_fight.gd`, live fights in real time: the counts and the top
at every rest through a skill, a strike (its top set as its blow resolves),
three end turns (the top as each sweep lands) and a reshuffle tapped
mid-stream; a deal walking the draw pile down one card at a time; a kindle
bumping the ash once, with and without Reduce Motion; the Skip races; a pile
tap during a flight and during a reshuffle (the inspector shows the domain's
pile and leaves its order alone); the inspector's cards; a screen freed
mid-flight.

Thirty mutations (`device/mutations-*.json.txt`, run by `device/mutate.py.txt`:
back up, break, run the one test, copy back), every one caught, on the tests
as committed:

| Mutation | What it breaks | Caught by (the first failure) |
|---|---|---|
| `m01-tail` (`pile_stack.gd`) | the 0.35 px tail made 0.5 | piles: 11 cards stand 10.50 px, want 10.35 |
| `m02-top-flat` (`pile_stack.gd`) | the top does not rise with the count | piles: the top of 1 cards rises 0.00 px, want 1.00 |
| `m03-null-face-clears` (`pile_stack.gd`) | a top named without its face drops the old picture | piles: a top named without its face does not keep the old picture |
| `m04-rm-ignored` (`pile_stack.gd`) | Reduce Motion ignored by the life at rest | piles: under Reduce Motion the ash rim still breathes |
| `m05-glint-cycle` (`pile_stack.gd`) | the glint every 4.5 s | piles: the glint is on the card 5.0 s into its cycle |
| `m06-rim-still` (`pile_stack.gd`) | the rim never breathes | piles: at rest the glint never crosses (true) or the rim breathes 0.55-0.55 |
| `m07-stream-share` (`pile_stream.gd`) | the stream staggered 0.5 of 0.6 s | piles: a reshuffle of 1 flies 1, the last landing at 0.600 s |
| `m08-turn-share` (`pile_stream.gd`) | the first card turns over its whole flight | piles: the reshuffle's first card does not turn over in its first 40% |
| `m09-skip-slow` (`pile_stream.gd`) | Skip completes in 300 ms | piles: a tap does not complete the reshuffle in 150 ms (0 landed) |
| `m10-no-jog-wait` (`pile_stream.gd`) | the stream done before the deck squares | piles: the reshuffle's cards do not land in turn, once each |
| `m11-flying-counted-twice` (`event_sequencer.gd`) | a card in the air counted again by its queued event | piles: the queue's pile changes are [4, -1, 1, -2, 0], want [4, -1, 1, -3, 0] |
| `m12-reshuffle-sign` (`event_sequencer.gd`) | the reshuffle never empties the discard | piles: the queue's pile changes are [4, 5, 1, 3, 0], want [4, -1, 1, -3, 0] |
| `m13-seen-dropped` (`discard_top.gd`) | a face handed on before arrival is dropped | piles: an arrived card is not the top, in its own face at its landing angle |
| `m14-no-bake` (`discard_top.gd`) | no bake when no face can be handed on | piles: a top with no face is not named at once with a bake asked ([]) |
| `m15-settle-ignored` (`discard_top.gd`) | the idle drain never settles the top | piles: the idle drain does not settle the top on the last discard |
| `m16-landing-angle` (`discard_top.gd`) | the top lies square, not at its landing angle | piles: an arrived card is not the top, in its own face at its landing angle |
| `m17-seat-global-position` (`hand_view.gd`) | the seat through global_position (PR 4) | piles: a seat is placed off the hand's own transform |
| `f01-draw-ignores-queue` (`combat_screen.gd`) | the draw pile reads the domain, not the queue | pile fight: the deal walked the draw pile [5, 5, …, 5, 0, …] (one jump) |
| `f02-overrides-stick` (`combat_screen.gd`) | the reshuffle's overrides never cleared | pile fight: after end turn 2 the piles show [10, 0, 0], the domain holds [5, 0, 0] |
| `f03-landing-no-top` (`combat_screen.gd`) | a landing does not make the top | pile fight: the discard answered the skill with [-1] on top |
| `f04-strike-no-top` (`combat_screen.gd`) | a struck card's pile copy does not make the top | pile fight: a struck card did not top the discard as its blow resolved |
| `f05-kindle-bumps-twice` (`combat_screen.gd`) | a card already sent is answered again | pile fight: the discard answered the skill with [5, 5] on top |
| `f06-played-card-stays-in-fan` (`hand_view.gd`) | a played card stays in the fan | pile fight: the discard answered the skill with [5, 5] on top |
| `f07-stale-skip` (`hand_view.gd`) | a tap's skip outlives its deal | pile fight: a tap racing an End Turn skipped the next turn's deal too |
| `f08-sort-in-place` (`combat_screen.gd`) | the inspector sorts the domain's draw pile | pile fight: a pile tap during a flight reordered the domain's piles |
| `f09-unsorted` (`combat_screen.gd`) | the inspector in draw order | pile fight: the draw pile's inspector tells the draw order ["strike", "defend", "defend", "chisel", "strike"] |
| `f10-inspector-kept` (`combat_screen.gd`) | closing the inspector keeps its cards | pile fight: closing the inspector kept its cards |
| `f11-deal-gap-tree-frames` (`combat_screen.gd`) | _deal_gap awaits the tree's frames | pile fight: a screen freed mid-flight logged: modules/gdscript/gdscript_function.cpp:323 resume Resumed function '_deal_gap()' after await, but class  |
| `f12-card-ready-awaits` (`card_view.gd`) | CardView._ready awaits two frames | pile fight: a screen freed mid-flight logged: modules/gdscript/gdscript_function.cpp:323 resume Resumed function '_ready()' after await, but class ins |
| `f13-until-tree-frames` (`combat_screen.gd`) | _until awaits the tree's frames | pile fight: a screen freed mid-flight logged: modules/gdscript/gdscript_function.cpp:323 resume Resumed function '_until()' after await, but class ins |

## Stills and bursts (Mac, M1 Max, Metal, Forward Mobile)

Live bench fights (`--fight=duskfang --kind=elite --seed=1`) driven through
the game's own paths, bursts slowed to a tenth and sampled every 40 ms of game
time.

| File | Shows |
|---|---|
| `01-states-pad.jpg`, `02-states-phone.jpg`, `03-states-desktop.jpg` | each pile at 0, 1, 5, 10, 40 and 99 cards, in English and Traditional Chinese |
| `04-play-pad.jpg` | a skill landing face up on the discard and becoming its top |
| `05-strike-swap-pad.jpg` | the discard's top becoming the struck card's face as its blow resolves |
| `06-sweep-pad.jpg` | the end of a turn: each card lands loose and is the top in turn |
| `07-reshuffle-pad.jpg` | the reshuffle of ten (eight fly), then the deal |
| `08-reshuffle-skip-pad.jpg`, `09-reshuffle-rm-pad.jpg` | Skip (a tap at 200 ms) and Reduce Motion |
| `10-reshuffle-turn-detail-pad.jpg` | full resolution: the discard's top turning face down as it lifts |
| `11-inspector.jpg` | the inspector at the three shapes, a finger on a card |
| `12-idle-pad.jpg` | the glint crossing the draw pile, the ash rim breathing |
| `13-a12-condition.jpg` | the A12 condition (below) |
| `14-…-phone.jpg`, `15-…-desktop.jpg` | the strike's top and the stream at the other two shapes |

What they show: 1, 5 and 10 cards read differently, 40 is deeper and 99 no
deeper than 40; the discard's face is the card's own, readable at the iPad's
resolution; the ash is a charred back over cinders; the stream lifts the
discard's face, turns it and carries the backs over to the draw pile, which
thickens and squares; the phone stream stays low.

## The A12 condition

`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --rendering-driver metal
--rendering-method mobile …` with the shader cache off, every scene above and
the pile states, with and without Reduce Motion: `Metal 4.0 - Forward Mobile`,
**0 "Error compiling shader" lines**; the only error line is Godot's exit
notice of resources still in use. The piles are canvas style boxes and
textures; the stream's turning card is PR 3's pre-warmed picture shader.

## iPad 8 (A12, 2160 × 1620), frame times

QA builds (`io.fol2.glassvow.qa`), one of `main` (`a86b2f07`, A) and one of the
branch (`acf3a6d3`, B; its code is this PR's), each with the same untracked
probe (`device/pile_probe.gd.txt`, attached by `device/patch.py.txt`). A launch
boots `--map --seed=1`, waits for the map to settle, opens the bench fight
(Duskfang, elite), fills the hand to five and then measures:

- **rest0**, combat at rest for 10 s, longer than the draw pile's 9 s glint
  cycle, so the piles and the glint are inside the window (the ash pile is
  empty in this fight, so its rim draws nothing; its breath still runs);
- **deals 2–6** (2–4 in batch 5), each the hand's five views taken away
  outside the window and the five dealt again through the real DRAW handler,
  as PR 4's probe did; deal 1 is not graded;
- **reshuffles 1–3** (1–2 in batch 5): every card moved into the discard
  outside the window, then the domain's own draw of five, which reshuffles the
  ten cards (an eight-card stream) and deals; its RESHUFFLE and DRAW events go
  through the drain as a fight's do.

Three batches, each holding the iPad lock throughout, interleaved by install
(A, B, A, B, A, B in batches 1 and 4; B, A, B, A in batch 5), a warm-up launch
after each install (listed, not graded), batches 4 and 5 with 45 s and 120 s
cool-downs between launches and batch 5 started after 13 minutes' rest:
**16 measured launches of each build**. Two batches between batch 1 and
batch 4 were stopped and their rows discarded: batch 2 reused batch 1's
launch nonces, so its pulls read batch 1's rows files, and stopping it only
ran its clean-up, so it ran on beside batch 3. `device/batch.zsh.txt` now
exits on a signal and asks for nonces new to the container.

**The iPad throttled.** In 22 of the 32 measured launches (11 of each build)
the frame time drifts from 16.7 ms to 18–20 ms about 8–16 s into the fight
and stays there through every phase, rest included, on either build; the
throttle's onset has the same spread on both (`device/summary.txt`; the
"Throttled from" column). The cool-downs did not prevent it. Those launches
are named below and graded apart; the grade is on the launches it spared,
five of each build.

| Graded on the batch median, ms | A (main) | B (branch) | B − A |
|---|---|---|---|
| **Combat at rest** p50 / p95, unthrottled (5 + 5) | 16.66 / 17.25 | 16.66 / 17.25 | **0.00 / 0.00** |
| **Five-card deal** p50 / p95, unthrottled | 16.65 / 18.09 | 16.62 / 18.15 | **−0.03 / +0.06** |
| **Reshuffle** p50 / p95, unthrottled | 16.66 / 18.01 | 16.68 / 18.00 | +0.02 / −0.01 |
| Combat at rest p50 / p95, all 16 + 16 | 16.72 / 17.59 | 16.74 / 18.17 | +0.02 / +0.58 |
| Five-card deal p50 / p95, all | 18.23 / 21.13 | 18.35 / 21.04 | +0.12 / −0.09 |
| Reshuffle p50 / p95, all | 18.31 / 21.14 | 18.08 / 21.00 | −0.23 / −0.14 |

On the launches the iPad did not throttle, B is within +0.5 ms of A at the
median and the P95 at rest, through the deal and through the reshuffle. Over
every launch the rest P95 is +0.58: in batch 4 the throttle set in earlier
inside the 10 s rest window on B (db2 at 8 s, db1, db3 and db6 at 10–12 s)
than on A (da6 at 8 s, da3 at 10 s, da1 at 14 s), and the per-batch medians
disagree in sign (batch 1 −0.19, batch 4 +2.03). That row is the throttle's, not the piles'; a batch on a cool iPad
would settle it.

**Frames over 33 ms.**

- **The reshuffle, B, one frame in the first reshuffle of a launch**, at
  0.65–0.77 s (frames 39–46): 37.2 ms in b2 and b5 (unthrottled) and
  36.8–39.9 ms in the throttled B launches; none in b1, db4 or eb2, and none
  in any second or third reshuffle. It is the first frame of the deal that
  follows the stream, and the second of a pair main has too: a CPU frame
  (21–26 ms before the draw) builds the five drawn cards, then their stages'
  first render (a 19–24 ms draw). On main the pair is 22–30 ms a frame in its
  unthrottled launches; on the branch the render ends just past a vsync, so
  its frame takes one more interval (the pair sums 63–67 ms against
  47–55 ms). The cost is the cards' first build, and the probe makes it: its
  deals reuse five cards, so the reshuffle draws cards it has never dealt.
  In a fight the draw pile empties only once every card in it has been
  dealt, so a reshuffle's deal finds them built.
- **Main, a1, rest0**: five frames of 41–46 ms, every fourth frame from the
  16th, the draw holding 24–28 ms: one of the GPU-bound trains PR 4's
  evidence names, on main.
- **Main, a1, deal 1** (not graded): 47.5 ms, its first deal.
- **Throttled launches, both builds**: the same first-reshuffle frame
  (36–42 ms) in A and B alike, two deal frames (a6 36.9, da3 37.1) and ea1's
  rest train; listed in `device/summary.txt`.

Every launch (ms; warm-ups listed, not graded):

| Batch | Run | Build | Load ms | Rest p50 / p95 | Deals 2–6: p50 / p95 / > 33 | Reshuffles: p50 / p95 / max / > 33 | Throttled from |
|---|---|---|---|---|---|---|---|
| b1 | a1 | A | 833 | 16.67 / 17.68 | 16.67 / 18.09 / 0 | 16.66 / 18.00 / 29.8 / 0 | — |
| b1 | a2 | A | 799 | 16.69 / 17.25 | 16.65 / 18.11 / 0 | 16.68 / 18.01 / 25.2 / 0 | — |
| b1 | a3 | A | 1084 | 16.65 / 17.22 | 16.60 / 18.19 / 0 | 16.66 / 18.05 / 30.1 / 0 | — |
| b1 | a4 | A | 967 | 16.66 / 17.26 | 16.65 / 18.01 / 0 | 16.68 / 18.10 / 29.9 / 0 | — |
| b1 | a5 | A | 1300 | 16.91 / 20.05 | 19.06 / 21.45 / 0 | 19.52 / 21.83 / 36.3 / 1 | 10 s |
| b1 | a6 | A | 1331 | 17.92 / 20.68 | 19.92 / 22.31 / 1 | 19.55 / 22.09 / 40.2 / 1 | 8 s |
| b1 | b1 | B | 817 | 16.66 / 17.31 | 16.62 / 18.30 / 0 | 16.68 / 17.93 / 23.7 / 0 | — |
| b1 | b2 | B | 1201 | 16.68 / 17.25 | 16.64 / 18.12 / 0 | 16.68 / 18.21 / 37.2 / 1 | — |
| b1 | b3 | B | 1133 | 16.98 / 20.56 | 19.82 / 22.32 / 0 | 19.66 / 22.10 / 36.8 / 1 | 10 s |
| b1 | b4 | B | 1598 | 18.02 / 20.74 | 19.90 / 22.31 / 0 | 19.55 / 21.82 / 39.9 / 1 | 8 s |
| b1 | b5 | B | 1049 | 16.66 / 17.16 | 16.62 / 18.41 / 0 | 16.68 / 18.00 / 37.2 / 1 | — |
| b1 | b6 | B | 1085 | 16.68 / 16.90 | 17.34 / 20.09 / 0 | 17.93 / 21.28 / 38.1 / 1 | 38 s |
| b1 | wa1 | A | 818 | 16.65 / 17.04 | — | 16.66 / 18.74 / 25.0 / 0 | warm-up |
| b1 | wa2 | A | 1250 | 16.68 / 16.86 | — | 16.62 / 19.19 / 31.0 / 0 | warm-up |
| b1 | wa3 | A | 1300 | 16.72 / 17.14 | — | 18.34 / 21.40 / 38.0 / 1 | warm-up |
| b1 | wb1 | B | 1767 | 16.69 / 17.53 | — | 16.66 / 18.14 / 30.1 / 0 | warm-up |
| b1 | wb2 | B | 1265 | 16.56 / 18.78 | — | 16.64 / 18.21 / 29.7 / 0 | warm-up |
| b1 | wb3 | B | 1198 | 16.56 / 17.97 | — | 16.63 / 18.10 / 37.4 / 1 | warm-up |
| b4 | da1 | A | 1267 | 16.71 / 18.16 | 18.41 / 21.24 / 0 | 18.73 / 21.32 / 37.7 / 1 | 14 s |
| b4 | da2 | A | 1332 | 16.66 / 17.07 | 16.70 / 17.60 / 0 | 16.66 / 17.75 / 29.7 / 0 | — |
| b4 | da3 | A | 1234 | 16.84 / 19.34 | 19.44 / 22.42 / 1 | 19.40 / 22.32 / 33.0 / 0 | 10 s |
| b4 | da4 | A | 1200 | 16.73 / 17.49 | 17.54 / 21.01 / 0 | 17.31 / 20.42 / 36.6 / 1 | yes |
| b4 | da5 | A | 1167 | 16.71 / 17.42 | 19.64 / 21.93 / 0 | 19.69 / 22.05 / 42.5 / 1 | 16 s |
| b4 | da6 | A | 1267 | 18.32 / 21.26 | 19.49 / 22.15 / 0 | 18.59 / 21.77 / 37.6 / 1 | 8 s |
| b4 | db1 | B | 1184 | 16.73 / 19.57 | 19.72 / 22.09 / 0 | 19.59 / 22.54 / 39.7 / 1 | 12 s |
| b4 | db2 | B | 1483 | 18.64 / 21.17 | 19.92 / 22.31 / 0 | 19.38 / 21.76 / 39.2 / 1 | 8 s |
| b4 | db3 | B | 1200 | 17.43 / 20.29 | 19.60 / 22.32 / 0 | 19.18 / 22.19 / 37.9 / 1 | 10 s |
| b4 | db4 | B | 1135 | 16.67 / 16.94 | 16.68 / 17.11 / 0 | 16.69 / 16.99 / 26.1 / 0 | — |
| b4 | db5 | B | 1184 | 16.67 / 16.95 | 18.49 / 21.55 / 0 | 19.34 / 22.01 / 38.7 / 1 | 18 s |
| b4 | db6 | B | 1200 | 17.01 / 20.14 | 18.43 / 21.30 / 0 | 18.06 / 20.83 / 26.3 / 0 | 10 s |
| b4 | dwa1 | A | 1267 | 16.66 / 17.46 | — | 16.68 / 18.11 / 25.8 / 0 | warm-up |
| b4 | dwa2 | A | 1234 | 16.66 / 17.05 | — | 16.64 / 17.96 / 25.3 / 0 | warm-up |
| b4 | dwa3 | A | 1151 | 16.60 / 18.34 | — | 16.74 / 18.21 / 25.7 / 0 | warm-up |
| b4 | dwb1 | B | 1199 | 16.67 / 16.93 | — | 16.69 / 17.65 / 26.6 / 0 | warm-up |
| b4 | dwb2 | B | 1283 | 16.68 / 16.88 | — | 16.83 / 18.78 / 23.9 / 0 | warm-up |
| b4 | dwb3 | B | 1116 | 16.66 / 17.98 | — | 16.66 / 18.45 / 25.0 / 0 | warm-up |
| b5 | ea1 | A | 1298 | 17.19 / 21.04 | 19.74 / 22.20 / 0 | 19.07 / 21.43 / 40.4 / 1 | 10 s |
| b5 | ea2 | A | 1200 | 16.66 / 17.38 | 17.54 / 20.61 / 0 | 17.67 / 20.77 / 26.5 / 0 | 32 s |
| b5 | ea3 | A | 1300 | 18.21 / 20.91 | 19.52 / 21.80 / 0 | 19.31 / 21.57 / 33.0 / 0 | 8 s |
| b5 | ea4 | A | 1198 | 16.73 / 17.44 | 18.05 / 20.70 / 0 | 18.03 / 20.95 / 27.4 / 0 | 16 s |
| b5 | eb1 | B | 1200 | 16.75 / 18.31 | 18.16 / 20.79 / 0 | 17.84 / 20.08 / 39.5 / 1 | 12 s |
| b5 | eb2 | B | 933 | 16.66 / 17.49 | 16.59 / 18.15 / 0 | 16.68 / 18.26 / 24.0 / 0 | — |
| b5 | eb3 | B | 1167 | 16.88 / 19.85 | 19.07 / 21.56 / 0 | 18.54 / 21.18 / 38.5 / 1 | 12 s |
| b5 | eb4 | B | 1383 | 16.76 / 18.03 | 18.27 / 20.73 / 0 | 18.09 / 20.82 / 26.4 / 0 | 16 s |
| b5 | ewa1 | A | 853 | 16.68 / 17.97 | — | 16.68 / 17.92 / 25.7 / 0 | warm-up |
| b5 | ewa2 | A | 1417 | 16.64 / 18.16 | — | 16.63 / 17.94 / 37.0 / 1 | warm-up |
| b5 | ewb1 | B | 1399 | 16.64 / 18.12 | — | 16.65 / 18.07 / 38.8 / 1 | warm-up |
| b5 | ewb2 | B | 1267 | 16.70 / 17.59 | — | 16.65 / 18.24 / 29.3 / 0 | warm-up |

The device was found at run time; its identifier is not recorded. Only the QA
app's container was read; no real save was read or written; nothing was
uninstalled.

## Payload

`tools/payload_report.py` (iOS): the pack estimate falls by 342 KiB (276.30 to
275.96 MiB): the two retired paintings were 375.4 KiB of imported artefacts,
the code adds 33.1 KiB (`presentation` 3.06 to 3.09 MiB of its 3.2 budget).
The QA .ipa is 0.37 MB smaller.

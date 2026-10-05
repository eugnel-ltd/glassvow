# #657 PR 4, the flights: evidence

Measured and shot on `806e8a30`, the flights commit on `main` at `cbfac106`.
The branch was then rebased onto `main` at `8d1fd9f2` with every patch
unchanged (`git range-diff`); none of the commits between the two touch
`presentation/combat`, `presentation/cards` or `application/main.gd`, and
the branch's later commits change documents and one code comment only. The motion spec is §3 of the
dossier (`../../README.md`). The device scripts and summaries are under
`device/`, as text; the raw rows (about 4 MB) stay out of the repository.

## The §3 rows as built

| Row | Built | Where it differs from §3, and why |
|---|---|---|
| **Draw** (picture turn) | Leaves the draw pile's painted top card (`HudBar.pile_card`) face down at its size and −4°; lifts 6 px in the first 60 ms; travels ease-out cubic on an arc of 9% of the stage height (35 px phone, 74 px pad and desktop); turns 180° to 0° over t = 0.12 to 0.78 (smoothstep), pitch −14°·sin(πt); the shadow narrows with the turn and drops away under the arc; a 250 ms edge glint on landing. Stagger 90 ms to five cards, then `max(40 ms, 450 ms / n)`. | The 60 ms lift is inside the 0.42 s, so a five-card deal still takes the stated 0.78 s; the travel itself is 0.36 s. "Lands into the seat overshoot": the card's growth from pile card to hand card follows `CardView.POSE_EASE`, so it swells about 4% past a hand card near its seat and settles. The glint is a canvas rim, so no card pass re-renders for it. The optional live turn for a single mid-turn draw is not used: one renderer for every draw, and it is not a slow reveal. |
| Draw: Skip | A tap anywhere (mouse or touch, never consumed) lands every card in the deal face up within 120 ms; the rest of the wave lands with it (the screen's stagger wait ends early). | — |
| Draw: Reduce Motion | Each card fades in at its seat over 160 ms, rising 6 px, 40 ms apart; no arc, turn or pitch. The fade is over the card's playability tint, which a mid-fade change keeps. | — |
| **Play** (skill) | From where it was let go, 0.26 s ease-in to the discard pile's top card, face up, within ±3° (a hash of the uid); the pile bumps on arrival; the card lies there 0.3 s and fades into the pile in 0.15 s. Skip: lands at once. Reduce Motion: fades where it is in 160 ms; no bump, the count ticks. | **A power is not flown to the discard.** The domain consumes it (`powerConsumed`), and the pile count never takes it, so it leaves the hand at its play as before. Where a played card goes is read from its own next event in the batch (`EventSequencer.next_for`); an exhaust card burns to the ash instead (row Exhaust). The hand-off fade stands in for the face-up discard top, which is PR 5's pile. |
| **Play** (attack) | `strike_to` unchanged in time, scale and fade, now aimed by the card's centre. | Through `global_position` the shrinking card ended 59 × 84 px up and left of its foe (main does this today). "The discard pile's top becomes that card's face" needs the face-up pile: PR 5. |
| **End-of-turn discard** | Each card 0.26 s ease-in-out to the discard, 50 ms apart (five cards 0.46 s), within ±3 px and ±5°; the pile bumps once, on the last arrival. Skip: lands at once. Reduce Motion: the cards fade where they are; the count ticks. | — |
| **Exhaust** (picture turn) | The blaze (brightness 2.4, 8°, 0.6 of a pile card) over the existing 0.2 s, turning face down as it burns; lands on the ashes as a charred back (tint 0.42) whose ember rim cools over 1.2 s; ash motes rise about 0.6 s. Kindling takes the same path. Skip: lands charred at once. Reduce Motion: fades where it is with its ember rim. | The charred card fades into the ash pile after its rim cools; the charred stack is PR 5. |

The piles still draw their paintings: a landed card lies on the painted top
card and hands over to it.

## Frame bursts (Mac, M1 Max, Metal, Forward Mobile)

Each sheet is a live bench fight (`--fight=duskfang --kind=elite --seed=1`)
driven through the game's own paths (the DRAW handler, the drag gestures,
end turn), slowed to a tenth and sampled every 40 ms of game time.

| Sheet | Shows |
|---|---|
| `01-deal-pad.jpg` | the five-card deal at 1180 × 820 |
| `02-deal-today-pad.jpg` | the same deal on `main`, for reference |
| `03-deal-turn-detail-pad.jpg` | full resolution: off the pile face down, the turn's midpoint edge on (the side band), the face, the landing |
| `04-deal-phone.jpg`, `05-deal-desktop.jpg` | the deal at phone-landscape 844 × 390 and desktop-landscape 1458 × 820 |
| `06-skip-pad.jpg` | a tap at 150 ms: every card down by about 280 ms |
| `07-play-skill-pad.jpg`, `08-strike-pad.jpg` | a skill to the discard; an attack at its foe |
| `09-exhaust-pad.jpg`, `10-sweep-pad.jpg` | the burn to the ash; the end of a turn |
| `11-reduce-motion-pad.jpg` | Reduce Motion: the deal, a play, an exhaust |
| `12-a12-condition.jpg` | the A12 condition (below) |
| `13-phone-desktop-leaving.jpg` | play, exhaust and the end of a turn at the other two shapes |

What they show: the card leaves the pile exactly on its painted top card
(on `main` the face-up card started 28 × 40 px up and left of where it was
aimed, the same `global_position` error); the midpoint is edge on, the side band in the
stock's colour; the face reads the right way round from the turn's second half;
cards land in their seats; the phone arc stays low; the burnt back lands on the
ash pile with its rim alight.

## The A12 condition

`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --rendering-driver metal
--rendering-method mobile …` with the shader cache off (`override.cfg`
`[rendering] shader_compiler/shader_cache/enabled=false`), every scene above,
with and without Reduce Motion: `Metal 4.0 - Forward Mobile`, **0 "Error
compiling shader" lines**, the only error line being Godot's exit notice of
resources still in use. The rims are `StyleBoxFlat` panels and the turn is
PR 3's pre-warmed picture shader, so no new shader is compiled mid-fight.

## iPad 8 (A12, 2160 × 1620), frame times

QA builds (`io.fol2.glassvow.qa`), one of `main` (`cbfac106`, A) and one of the
branch (`806e8a30`, B), each with the same untracked probe (`device/`). A launch
boots `--map --seed=1`, waits for the map to settle, opens the bench fight
(Duskfang, elite), rests 3 s, then six times takes the hand's five views away
(1.2 s before the deal, so their video memory is released outside it) and deals
those five cards again through the real DRAW handler, resting 1.5 s after each.
A deal's frames run from the enqueue until the drain is idle and no card is in
the air, plus 15 frames. Deal 1 is reported apart; deals 2 to 6 are graded.
Interleaved by install: A (a warm-up launch, then two measured), B (the same),
three times each, so six measured launches a build, holding the iPad lock for
the whole batch (`device/b1-batch.log.txt`).

Every measured launch (ms; `to-draw + draw` is the frame's time before
`frame_pre_draw` plus the draw itself):

| Run | Build | Load | N+1 | N+2 | Deals 2–6: n, p50, p95, max, > 33 | Rest p50, p95 |
|---|---|---|---|---|---|---|
| a1 | A | 1265 | 16.3 | 29.3 | 360, 16.64, 18.07, 20.1, 0 | 16.66, 17.20 |
| a2 | A | 865 | 16.1 | 27.5 | 360, 16.66, 18.14, 22.6, 0 | 16.67, 17.19 |
| a3 | A | 848 | 15.3 | 16.5 | 360, 16.66, 17.95, 20.5, 0 | 16.68, 17.58 |
| a4 | A | 1348 | 15.7 | 26.0 | 359, 16.65, 18.21, 22.8, 0 | 16.67, 17.17 |
| a5 | A | 845 | 16.0 | 27.1 | 360, 16.65, 18.22, 21.8, 0 | 16.68, 17.36 |
| a6 | A | 900 | 16.3 | 20.8 | 360, 16.62, 18.22, 22.6, 0 | 16.66, 17.49 |
| b1 | B | 884 | 15.9 | 18.9 | 325, 16.65, 18.10, 22.4, 0 | 16.67, 17.42 |
| b2 | B | 901 | 15.7 | 24.6 | 325, 16.63, 17.91, 19.3, 0 | 16.66, 17.29 |
| b3 | B | 865 | 16.2 | 22.1 | 325, 16.61, 18.07, 22.1, 0 | 16.66, 17.55 |
| b4 | B | 884 | 15.5 | 16.8 | 325, 16.67, 18.06, 20.0, 0 | 16.66, 17.24 |
| b5 | B | 1084 | 16.3 | 19.2 | 325, 16.66, 18.07, 19.1, 0 | 16.68, 17.20 |
| b6 | B | 851 | 15.4 | 16.7 | 325, 16.65, 18.02, 21.0, 0 | 16.68, 17.31 |

| Graded on the batch median | A (main) | B (branch) | B − A |
|---|---|---|---|
| Deal p50 (median of per-launch p50s) | 16.65 | 16.65 | +0.00 |
| Deal p95 (median of per-launch p95s) | 18.17 | 18.07 | −0.10 |
| Deal, pooled p50 / p95 | 16.65 / 18.16 | 16.64 / 18.07 | −0.01 / −0.09 |
| Deal, the same 48-frame window of every deal, p50 / p95 / mean | 16.63 / 18.18 / 16.659 | 16.62 / 18.14 / 16.661 | −0.01 / −0.04 / +0.002 |
| Deal frames over 33 ms (deals 1–6, the graded launches) | 0 of 2590 | 0 of 2339 | — |
| Rest p50 / p95 (batch median) | 16.67 / 17.28 | 16.67 / 17.30 | 0.00 / +0.02 |

Both builds hold the display's 60 Hz through the deal; B's deal is within
+0.5 ms of A's at the median and the P95 (it is lower at the P95), and combat
at rest is the same. A B deal window is shorter (the wave takes 0.78 s where
A's drain stays busy about 0.95 s), so the fixed 48-frame window is the fairer
row; it agrees.

Outliers, named: a1 and a4 loaded in 1265 and 1348 ms, and b5 in 1084 ms,
against 845–901 ms (the load frame only; their deals and rests are in line).
Deal 1, not graded, peaks at 26.0 ms (a6) and 25.8 ms (b1). The rest P95 is
highest in a3 and b3 (17.58, 17.55). In the warm-up launches (the first after
each install, not graded) wb2 and wb3 ran N+1 at 7–9 ms and N+2 at 48–50 ms;
wb3's deal peaked at 32.0 ms. No graded or warm-up deal frame passed 33 ms.

## The entrance's long frames (N+2), explained

PR 3's review asked about a ~50 ms frame at N+2 of a fight's entrance with the
pre-warm, where the flights run. With the frame split into the time before the
draw and the draw itself (`device/b1-entrance.txt`, `device/b2-entrance.txt`):

- **It is not the cards, and not script.** In every long entrance frame
  (40–52 ms) the time before the draw, where every flight step and every other
  script runs, is 1–6 ms. The rest is the draw (24–39 ms) and the wait for the
  next vsync after it: the CPU waiting on the GPU and the display.
- **Main has them at the same rate.** In the first ten frames after the load,
  the worst frame is 48–52 ms in all six A launches and 48–49 ms in five of six
  B launches (21.8 in b5). Over the first second they come in trains, one every
  four frames (49, 17, 20, 17, …), for 1 to 14 frames per launch, in both
  builds: stretches where the GPU cannot hold 60 Hz.
- **They are not the pre-warm and not the opening deal.** A second batch on the
  branch (`device/b2-batch.log.txt`; a build that can leave the pre-warm or the
  opening deal out) gives long entrance frames with the pre-warm off (z1–z4:
  N+8; N+44–60; N+2 and N+30–42; N+12–16), with the opening deal off (n1–n4:
  N+2 at 50 ms in n3, N+5–18 in the others), and with both off (nz1, nz2:
  N+4–15). N+2 itself reached 50 ms with the pre-warm off (z3) and with no
  deal (n3).
- **What the pre-warm does move:** the wait for the fight's first render.
  Without the bake's readback in the load frame (the pre-warm off, or only its
  warmer), N+1 holds 83–145 ms (ten launches); with it, N+1 is 7–16 ms and the
  load frame grows (851–1084 ms in b1–b6, against 716–733 ms
  for v0a and v0b in the same batch). The warmer alone does not do this (v1a,
  v1b: N+1 117 and 83 ms): it is the readback, which waits for the load
  frame's GPU work inside the load frame.

So the N+2 frame is one of the entrance's GPU-bound frames, present on `main`,
with or without the pre-warm or the deal. The flights do not add to them; they
are not fixed here.

**The pre-warm's place (the review's fourth item).** It stays in the frame that
builds the fight. The opening deal is face down from the entrance's first
frame and reads the bake then; a pre-warm after the wipe's first tick would
show the pile's departing cards with no back for a frame and move the readback,
and the first render it waits for, into the entrance. PR 3's batch already
measured the wipe: its band sits at its start through the load frame.

## Files

- `device/flight_probe.gd.txt`, `device/patch.py.txt`, `device/batch.zsh.txt`,
  `device/analyze.py.txt`, `device/entrance.py.txt`: the probe, its attach, the
  batch, the two summaries.
- `device/b1-*.txt`: the graded batch (log, per-launch summary, entrance frames).
- `device/b2-*.txt`: the entrance variants.

The device was found at run time; its identifier is not recorded. Only the QA
app's container was read; no real save was read or written.

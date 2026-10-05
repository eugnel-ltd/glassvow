# Waystone tokens (#679): before and after

Issue #679, part of the map programme #660. Before is main at `cbfac106`; the
first head is `a3e2f0dd`; after is this branch's revision, which quiets the
stones the player cannot choose (the orchestrator's design revision of
5 October 2026). Everything here was measured on the Mac (M1 Max).

## The design as built

Every state is an opaque disc in `LeadlightTokens.INK` with a thin light rim
drawn inside the pane's radius, so the token covers no more ground than it
did. There is no contact shadow (below). The ember halo of an open or current
stone and the focus brackets are unchanged.

| State | Rim | Rim luminance, on `INK` | Glyph | Glyph luminance, on `INK` |
|---|---|---|---|---|
| open | `GOLD #f2c14e`, its throb lifting it halfway to `PARCHMENT` (held at the peak under Reduce Motion) | 0.576–0.650, 11.5:1–12.8:1 | `GOLD` | 0.576, 11.5:1 |
| current | `GOLD` | 0.576, 11.5:1 | `GOLD` | 0.576, 11.5:1 |
| walked | `RIM_QUIET #b1b5c0` (new) | 0.462, 9.4:1 | `TEXT_FAINT #626570` (new): a near-neutral slate | 0.131, 3.3:1 |
| cold | `RIM_QUIET` | 0.462, 9.4:1 | `GLASS_TEXT_FAINT #64729a` (new): a cool glass blue | 0.171, 4.0:1 |

`INK` is 0.0046. The gold rim is 1.25 times the quiet rim's luminance.

| Rim width on screen | phone (scale 0.58) | pad and desktop (0.92) |
|---|---|---|
| open, current (`RIM_W`, 3.5 local px) | 2.03 px | 3.22 px |
| walked, cold (`QUIET_RIM_PX`) | 2.00 px | 2.00 px |

The quiet width holds 2 px on screen through the draw scale the screen already
passes to `set_touch_min`.

A rim at 9:1 or more on its pane separates the token from any land at 3:1 or
more: a land as dark as the pane meets the rim at 9:1, one as light as the rim
meets the pane at 9:1, and in between the better of the two never falls below
the square root of the rim's ratio. That is 3.39:1 for the gold rim and 3.06:1
for the quiet one, the least the design allows.

## The gate

- **`tests/test_map_tokens.gd`** (headless suite):
  - every state of every kind goes through `set_state`;
  - the pane, rim and glyph are opaque;
  - the glyph on its pane is at least 4.5:1 (open, current) or 3:1 (walked,
    cold);
  - the edge is at least 3:1 on every land luminance from 0 to 1, at both ends
    of the open stone's throb;
  - every rim is at least 2 px on screen at every shipping shape;
  - the hierarchy: the dimmest lit rim is at least 1.2 times the luminance of
    the brightest quiet one, and no quiet rim is wider on screen than a lit one;
  - the map screen gives each stone the state its node is in.

  It holds the token's colours and widths; the suite has no renderer, so the
  draw path is proved by the tool below.
- **`tools/map_token_gate.gd`** (rendered picture): the production map screen,
  lean profile, two steps in, at each zoom stop of the act (Act I's Close,
  Journey and Whole act; the painted acts' four camera stops). Each token is
  read from the capture: the glyph's 90th-percentile luminance (the pixels a
  second, glyph-less capture of the same frame changes) against the pane's
  median; and in each 30° sector the better of the rim's core (at the stone's
  own rim width) and the pane against the median land 2–6 px beyond the token.
  Land excludes other tokens, bounty pills and quest lenses; a token is not
  judged when its centre is off frame, a quarter of its face is under another
  token or a pill, or fewer than four sectors keep land.

## Result: Acts I–IV, seeds 1–3, phone and pad landscape, every zoom stop

On Vulkan (MoltenVK), Forward Mobile (see the A12 section for why). Before is
main's tokens measured by the same tool with main's own geometry (the gold ring
at `r + 5` is the open and current rim; the 1.2 px arc at `r − 1` is the rest).

**Before: 1,368 tokens judged, 1,226 fail. After: 1,367 judged, 0 fail.** (The
first head was also 1,367 judged, 0 fail.)

The worst after, per state:

| State | Worst edge | Where | Worst glyph |
|---|---|---|---|
| open | 3.65:1 | Act I, seed 2, Whole act (both shapes) | 11.46:1 |
| current | 3.52:1 | Act I, seed 2, phone, Whole act | 11.46:1 |
| walked | 3.29:1 | Act I, seed 3, pad, Close | 3.31:1 |
| cold | 3.06:1 (the design's floor, met by real land) | Act I, seed 2, phone, Journey | 3.60:1 (two unlit stones at the phone's farthest stop, part of the glyph under their bounty pill) |

Before against after:

| Act | Shape | State | Before: judged / failed / lowest edge / lowest glyph | After: judged / failed / lowest edge / lowest glyph |
|---|---|---|---|---|
| 1 | phone | open | 12 / 1 / 2.87 / 12.77 | 12 / 0 / 3.65 / 11.46 |
| 1 | phone | current | 9 / 9 / 2.41 / 3.77 | 9 / 0 / 3.52 / 11.46 |
| 1 | phone | walked | 9 / 9 / 1.23 / 2.89 | 9 / 0 / 3.38 / 3.31 |
| 1 | phone | cold | 207 / 207 / 1.16 / 8.38 | 207 / 0 / 3.06 / 4.04 |
| 1 | pad | open | 12 / 0 / 3.36 / 12.77 | 12 / 0 / 3.65 / 11.46 |
| 1 | pad | current | 9 / 9 / 2.57 / 3.80 | 9 / 0 / 3.55 / 11.46 |
| 1 | pad | walked | 9 / 9 / 1.28 / 2.90 | 9 / 0 / 3.29 / 3.31 |
| 1 | pad | cold | 192 / 192 / 1.24 / 8.38 | 191 / 0 / 3.06 / 4.04 |
| 2 | phone | open | 14 / 0 / 4.95 / 12.31 | 14 / 0 / 5.25 / 11.46 |
| 2 | phone | current | 12 / 3 / 3.16 / 2.95 | 12 / 0 / 4.48 / 11.46 |
| 2 | phone | walked | 11 / 11 / 1.03 / 2.33 | 11 / 0 / 5.32 / 3.31 |
| 2 | phone | cold | 211 / 211 / 1.12 / 7.27 | 211 / 0 / 4.73 / 3.60 |
| 2 | pad | open | 14 / 0 / 4.45 / 12.23 | 14 / 0 / 4.64 / 11.46 |
| 2 | pad | current | 12 / 6 / 3.36 / 2.90 | 12 / 0 / 4.61 / 11.46 |
| 2 | pad | walked | 9 / 9 / 1.05 / 2.33 | 9 / 0 / 5.37 / 3.31 |
| 2 | pad | cold | 146 / 146 / 1.26 / 8.16 | 146 / 0 / 4.05 / 4.04 |
| 3 | phone | open | 14 / 0 / 5.45 / 12.31 | 14 / 0 / 5.62 / 11.46 |
| 3 | phone | current | 12 / 3 / 3.47 / 2.95 | 12 / 0 / 4.85 / 11.46 |
| 3 | phone | walked | 11 / 11 / 1.12 / 2.33 | 11 / 0 / 5.84 / 3.31 |
| 3 | phone | cold | 211 / 211 / 1.11 / 7.30 | 211 / 0 / 5.28 / 3.60 |
| 3 | pad | open | 14 / 0 / 4.80 / 12.23 | 14 / 0 / 5.53 / 11.46 |
| 3 | pad | current | 12 / 6 / 3.61 / 2.90 | 12 / 0 / 4.90 / 11.46 |
| 3 | pad | walked | 9 / 9 / 1.24 / 2.33 | 9 / 0 / 5.93 / 3.31 |
| 3 | pad | cold | 146 / 146 / 1.24 / 8.16 | 146 / 0 / 4.69 / 4.04 |
| 4 | phone | open | 12 / 0 / 5.51 / 12.31 | 12 / 0 / 5.43 / 11.46 |
| 4 | phone | current | 12 / 6 / 3.28 / 2.95 | 12 / 0 / 4.40 / 11.46 |
| 4 | phone | walked | 3 / 3 / 1.43 / 3.99 | 3 / 0 / 7.54 / 3.31 |
| 4 | phone | cold | 3 / 3 / 1.40 / 8.51 | 3 / 0 / 7.84 / 4.04 |
| 4 | pad | open | 9 / 0 / 4.69 / 12.71 | 9 / 0 / 5.24 / 11.46 |
| 4 | pad | current | 12 / 6 / 3.49 / 2.98 | 12 / 0 / 3.55 / 11.46 |

Every state was judged at every stop of Acts I–III, except Acts II and III's
nearest pad stop, which frames no walked stone. Act IV's road is a single
line: its walked and cold stones stand in frame only at the phone's farthest
stop, so the pad judges only open and current there. The headless test covers
every state without a frame.

Skipped tokens, after: 2,536 off frame and 23 covered; main: 2,536 and 22.
Every covered stone is in Act I, where a neighbouring stone or bounty pill lies
across a quarter of its face (at seed 1's Whole act, a pill over an event
stone's glyph). That placement is the chip band's and is untouched here.

## Salience

`salience-<phone|pad>.jpg`: each act at its farthest stop (Act I's Whole act,
the painted acts' stop 3), seed 1, before | first head | revision. The first
head made some sixty walked and cold stones carry the brightest element on the
map, a `TEXT` rim at 14:1, as bright as the gold pair. In the revision the
quiet rims are dimmer (0.462 against 0.716) and, on the pad, thinner (2.0 px
against 3.2), and the glyphs inside them are faint, so the gold pair is the
brightest thing on the map again. On the phone the quiet rim was already
2.0 px wide, so there the change is the tone alone, and the rings still read
as a pattern at Whole act, more quietly.

## The retired tripwire

R3.1b re-baselined R2's ring check (rim band at `r − 5…r − 1` against the land
at `r + 16…r + 28`, with `r` the pane's unscaled radius) as a tripwire. This
branch replaces it rather than keeping it beside the new gate: on the phone
the token is drawn at 16.2 px, so the check's rim band, 23–27 px out, is land,
and it compares land with land. On this lane's Act I Journey captures (seed 1,
two steps in, R2's mount without the HUD), main reads the record's own
figures, rim minimum phone 1.05 and pad 1.10 (the phone's lowest at the same
pin, 266, 113). The first head read phone 1.05 (land against land, unchanged)
and pad 3.74.

## A12 condition

`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --rendering-driver metal
--rendering-method mobile`, the whole sweep on the first head: 1,367 judged,
0 fail, 0 script errors, and 0 shader errors in Act I.

Acts II–IV print 10 `Error compiling shader` lines per launch, identically on
main (checked at seed 1, every act and shape). They are pre-existing on main
and not this PR's: every one is `SceneForwardMobileShaderRD` with `m_mineral`
and `m_groundcover` bound at sampler 17. That is the painted acts' shaded
ground (`map_mineral.gdshader`) under the engine's A12 sampler limit on the
official Mac 4.7.2 build, which the locally built iOS template fixes. This
branch changes no shader.

The Mac's default Metal renderer hits the same errors in the painted acts and
draws them on a flat ground, which is why the main sweep ran on Vulkan, where
every act's land draws as the device draws it.

## Frame time

`tools/map_trace/probe.gd` armed by `qa_patch.py` on detached worktrees of
main (`cbfac106`) and the first head's code commit (`789cda8e`, later rebased
as `d1de3c18` onto main's TestFlight build bump, #689). Act I, seed 1, two
steps in, lean; the cadence and live holds of 600 frames each; the Mac's
default Metal renderer; three launches a build and shape, interleaved. The
frame interval in ms (median of the launches; missed = frames over 25 ms,
summed):

| Shape | Hold | main: mean / p50 / p95 (missed) | first head: mean / p50 / p95 (missed) |
|---|---|---|---|
| pad | cadence | 8.34 / 8.56 / 9.40 (3) | 8.33 / 8.55 / 9.51 (0) |
| pad | live | 8.41 / 8.08 / 9.41 (4) | 8.34 / 8.07 / 9.41 (0) |
| phone | cadence | 8.35 / 8.49 / 9.65 (0) | 8.68 / 8.54 / 9.64 (4) |
| phone | live | 8.34 / 8.19 / 9.67 (0) | 8.37 / 8.15 / 9.85 (3) |

- Both builds sit on the 120 Hz display's vsync.
- The missed frames are hitches of 30–257 ms, 7 frames in each build: main's
  all at the pad, the branch's all at the phone. They are spread over
  different launches and holds on a host shared with other lanes, not a cost
  that follows the build.
- `--disable-vsync` does not lift the Mac's driver-level vsync (one launch
  each: the same 8.3 ms), so the interval bounds the token's cost rather than
  reading it.
- The 3D stage is untouched: identical draw calls and primitives (pad 80 /
  57,890, phone 82 / 55,240).
- Per stone, the 2D draw went from an aliased disc plus one or two
  anti-aliased arcs (48 and 32 segments) to two anti-aliased discs.
- The revision changes only a quiet rim's colour and its inner disc's radius:
  the same two discs, so it was not timed again.
- No shader changed, so the screen-texture readers and every spatial shader's
  samplers are as on main, and no device run was needed.

## Mutation proof

Each mutation backed `glass_waystone.gd` up, broke it, ran the gate and
copied the backup back.

`tests/test_map_tokens.gd`, at the revision, fails on each of 13 mutations:

- the hierarchy and widths it now pins:
  - a quiet rim as bright as `TEXT` (0.80 times the gold);
  - a 4 px quiet rim (wider than the lit rim at every shape);
  - a quiet rim width that ignores the draw scale (1.16 px on the phone,
    1.84 px on the pad);
- the checks it kept:
  - main's own colours, alphas and widths transcribed into the token tables
    (three checks fail);
  - a `TEXT_DIM` quiet rim (edge 2.51:1);
  - a translucent pane;
  - a half-alpha walked glyph;
  - a cold glyph under 3:1;
  - a dark open glyph;
  - a glyph tint that ignores the state;
  - no walked state;
  - a 3.0 px lit rim (1.74 px on the phone);
  - a throb that darkens the rim.

Run literally against main, the test cannot load: main has no token tables.
The first head's nine headless mutations failed it the same way.

`tools/map_token_gate.gd`, at the revision, Acts I and II at seed 1 on both
shapes:

- a 1 px rim drawn (the pane over all but 1 px) fails every token (worst edge
  1.00–1.13:1);
- a `TEXT_DIM` rim drawn fails 71 of 76, 66 of 73, 5 of 79 and 7 of 53 (worst
  edge 2.51–2.58:1).

The gate reads a live land: launch to launch a sector's edge moves by up to
0.3:1 (two launches of the first head compared row by row); every verdict held.

## Contact sheets

- `stills-act<N>-<phone|pad>.jpg`: every seed and zoom stop, before | after.
- `crops-<phone|pad>.jpg`: each state's token close up, every act and seed,
  at the default stop (Act I's Journey, the painted acts' stop 2), before |
  after, with each token's edge and glyph ratios and its verdict.
- `salience-<phone|pad>.jpg`: each act at its farthest stop, before | first
  head | revision.

Before, the cold and walked discs sink into the dark wood of Act I and the
dark ground of the painted acts, and the walked and current stones are
see-through. After, every stone reads as a ringed ink disc on every land; the
gold pair, open and current, is the brightest; cold glyphs are a faint glass
blue and walked ones a fainter grey.

## Judgements

- **`RIM_QUIET #b1b5c0`** sits at 9.4:1, inside the revision's 9.0–9.5 band.
  That gives the 1.2 times hierarchy (1.25) a margin, and puts the quiet rim's
  worst land at 3.06:1. Real land reached that floor once in the sweep (cold,
  Act I, seed 2, phone Journey), so there is no slack below it.
- **Glyph tones were chosen by eye at Whole act.** `#687290` and `#606577`
  (4.0:1 and 3.3:1, both bluish) were told apart by tone alone and barely. The
  chosen pair adds hue: cold a saturated glass blue (`#64729a`), walked a
  near-neutral slate (`#626570`).
- **`TEXT_FAINT` was retuned, not kept at `#757c92`.** It was new in this PR,
  and at 4.6:1 it would have been brighter than the cold glyph.
- **No contact shadow.** It is optional in the issue; it would fall in the
  2–6 px the gate reads as land, and the rim and pane already meet every land.
- **Open and current share the gold.** Open throbs and keeps its ember halo's
  pulse; current is steady and, in Act I, carries the pilgrim.

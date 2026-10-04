# Waystone tokens (#679): before and after

Issue #679, part of the map programme #660. Before is main at `cbfac106`;
after is this branch. Everything here was measured on the Mac (M1 Max).

## The design as built

Every state is an opaque disc in `LeadlightTokens.INK` with a thin light rim
drawn inside the pane's radius (`GlassWaystone.RIM_W`, 3.5 local px: 2.0 px on
the phone, 3.2 px on the pad), so the token covers no more ground than it did.
There is no contact shadow (below). The ember halo of an open or current stone
and the focus brackets are unchanged.

| State | Rim | Glyph | Rim on pane | Glyph on pane |
|---|---|---|---|---|
| open | `GOLD`, its throb lifting it halfway to `PARCHMENT` (held at the peak under Reduce Motion) | `GOLD` | 11.5:1 to 12.8:1 | 11.5:1 |
| current | `GOLD` | `GOLD` | 11.5:1 | 11.5:1 |
| walked | `TEXT` (silver) | `TEXT_FAINT`, a new token (`#757c92`) | 14.0:1 | 4.6:1 |
| cold | `TEXT` (silver) | `GLASS_TEXT_DIM` | 14.0:1 | 7.7:1 |

A rim at 9:1 or more on its pane separates the token from any land at 3:1 or
more: a land as dark as the pane meets the rim at 9:1, one as light as the rim
meets the pane at 9:1, and in between the better of the two never falls below
the square root of the rim's ratio. The lowest here is the gold rim's 3.39:1.

## The gate

- **`tests/test_map_tokens.gd`** (headless suite): every state of every kind,
  through `set_state`; an opaque pane, rim and glyph; the glyph on its pane at
  4.5:1 or more (open, current) or 3:1 (walked, cold); the edge at 3:1 or more
  on every land luminance from 0 to 1, at both ends of the open stone's throb;
  the rim at least 2 px on screen at every shipping shape; and the map screen
  gives each stone the state its node is in. It holds the token's colours; the
  suite has no renderer, so the draw path is proved by the tool below.
- **`tools/map_token_gate.gd`** (rendered picture): the production map screen,
  lean profile, two steps in, at each zoom stop of the act (Act I's Close,
  Journey and Whole act; the painted acts' four camera stops). Each token is
  read from the capture: the glyph's 90th-percentile luminance (the pixels a
  second, glyph-less capture of the same frame changes) against the pane's
  median; and in each 30° sector the better of the rim's core and the pane
  against the median land 2–6 px beyond the token. Land excludes other tokens,
  bounty pills and quest lenses; a token is not judged when its centre is off
  frame, a quarter of its face is under another token or a pill, or fewer than
  four sectors keep land.

## Result: Acts I–IV, seeds 1–3, phone and pad landscape, every zoom stop

On Vulkan (MoltenVK), Forward Mobile (see the A12 section for why). Before is
main's tokens measured by the same tool with main's own geometry (the gold ring
at `r + 5` is the open and current rim; the 1.2 px arc at `r − 1` is the rest).

**Before: 1,368 tokens judged, 1,226 fail. After: 1,367 judged, 0 fail.**
The worst after is Act IV, seed 3, pad, the nearest stop, the current stone:
edge 3.55:1, glyph 11.46:1.

| Act | Shape | State | Before: judged / failed / lowest edge / lowest glyph | After: judged / failed / lowest edge / lowest glyph |
|---|---|---|---|---|
| 1 | phone | open | 12 / 1 / 2.87 / 12.77 | 12 / 0 / 3.71 / 11.46 |
| 1 | phone | current | 9 / 9 / 2.41 / 3.77 | 9 / 0 / 3.59 / 11.46 |
| 1 | phone | walked | 9 / 9 / 1.23 / 2.89 | 9 / 0 / 5.08 / 4.63 |
| 1 | phone | cold | 207 / 207 / 1.16 / 8.38 | 207 / 0 / 3.84 / 7.67 |
| 1 | pad | open | 12 / 0 / 3.36 / 12.77 | 12 / 0 / 3.59 / 11.46 |
| 1 | pad | current | 9 / 9 / 2.57 / 3.80 | 9 / 0 / 3.59 / 11.46 |
| 1 | pad | walked | 9 / 9 / 1.28 / 2.90 | 9 / 0 / 5.03 / 4.63 |
| 1 | pad | cold | 192 / 192 / 1.24 / 8.38 | 191 / 0 / 3.75 / 7.67 |
| 2 | phone | open | 14 / 0 / 4.95 / 12.31 | 14 / 0 / 5.17 / 11.46 |
| 2 | phone | current | 12 / 3 / 3.16 / 2.95 | 12 / 0 / 4.48 / 11.46 |
| 2 | phone | walked | 11 / 11 / 1.03 / 2.33 | 11 / 0 / 7.95 / 4.63 |
| 2 | phone | cold | 211 / 211 / 1.12 / 7.27 | 211 / 0 / 7.07 / 6.62 |
| 2 | pad | open | 14 / 0 / 4.45 / 12.23 | 14 / 0 / 4.51 / 11.46 |
| 2 | pad | current | 12 / 6 / 3.36 / 2.90 | 12 / 0 / 4.55 / 11.46 |
| 2 | pad | walked | 9 / 9 / 1.05 / 2.33 | 9 / 0 / 8.04 / 4.63 |
| 2 | pad | cold | 146 / 146 / 1.26 / 8.16 | 146 / 0 / 6.16 / 7.67 |
| 3 | phone | open | 14 / 0 / 5.45 / 12.31 | 14 / 0 / 5.62 / 11.46 |
| 3 | phone | current | 12 / 3 / 3.47 / 2.95 | 12 / 0 / 4.85 / 11.46 |
| 3 | phone | walked | 11 / 11 / 1.12 / 2.33 | 11 / 0 / 8.86 / 4.63 |
| 3 | phone | cold | 211 / 211 / 1.11 / 7.30 | 211 / 0 / 7.90 / 6.62 |
| 3 | pad | open | 14 / 0 / 4.80 / 12.23 | 14 / 0 / 5.51 / 11.46 |
| 3 | pad | current | 12 / 6 / 3.61 / 2.90 | 12 / 0 / 4.90 / 11.46 |
| 3 | pad | walked | 9 / 9 / 1.24 / 2.33 | 9 / 0 / 8.86 / 4.63 |
| 3 | pad | cold | 146 / 146 / 1.24 / 8.16 | 146 / 0 / 6.96 / 7.67 |
| 4 | phone | open | 12 / 0 / 5.51 / 12.31 | 12 / 0 / 5.43 / 11.46 |
| 4 | phone | current | 12 / 6 / 3.28 / 2.95 | 12 / 0 / 4.40 / 11.46 |
| 4 | phone | walked | 3 / 3 / 1.43 / 3.99 | 3 / 0 / 11.28 / 4.63 |
| 4 | phone | cold | 3 / 3 / 1.40 / 8.51 | 3 / 0 / 11.72 / 7.67 |
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

## The retired tripwire

R3.1b re-baselined R2's ring check (rim band at `r − 5…r − 1` against the land
at `r + 16…r + 28`, with `r` the pane's unscaled radius) as a tripwire. This
branch replaces it rather than keeping it beside the new gate: on the phone
the token is drawn at 16.2 px, so the check's rim band, 23–27 px out, is land,
and it compares land with land. On this lane's Act I Journey captures (seed 1,
two steps in, R2's mount without the HUD), main reads the record's own
figures, rim minimum phone 1.05 and pad 1.10 (the phone's lowest at the same
pin, 266, 113). After: phone 1.05 (land against land, unchanged), pad 3.74.

## A12 condition

`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --rendering-driver metal
--rendering-method mobile`, the whole sweep again on the branch: 1,367 judged,
0 fail, 0 script errors. Act I: 0 shader errors. Acts II–IV: 10 `Error
compiling shader` lines per launch, `SceneForwardMobileShaderRD` with
`m_mineral` and `m_groundcover` at sampler 17, in every launch of main and
the branch alike (main checked at seed 1, every act and shape): the engine's
A12 sampler limit on the official Mac 4.7.2 build, which the locally built
iOS template fixes. This branch changes no shader. The Mac's default Metal
renderer hits the same errors in the painted acts and draws them on a flat
ground, which is why the main sweep ran on Vulkan, where every act's land
draws as the device draws it.

## Frame time

`tools/map_trace/probe.gd` armed by `qa_patch.py` on detached worktrees of
main (`cbfac106`) and the branch's code commit (`789cda8e`, since rebased as `d1de3c18` onto main's TestFlight build bump, #689): Act I, seed 1, two
steps in, lean, the cadence and live holds of 600 frames each, the Mac's
default Metal renderer, three launches a build and shape, interleaved. The
frame interval in ms (median of the launches; missed = frames over 25 ms,
summed):

| Shape | Hold | main: mean / p50 / p95 (missed) | branch: mean / p50 / p95 (missed) |
|---|---|---|---|
| pad | cadence | 8.34 / 8.56 / 9.40 (3) | 8.33 / 8.55 / 9.51 (0) |
| pad | live | 8.41 / 8.08 / 9.41 (4) | 8.34 / 8.07 / 9.41 (0) |
| phone | cadence | 8.35 / 8.49 / 9.65 (0) | 8.68 / 8.54 / 9.64 (4) |
| phone | live | 8.34 / 8.19 / 9.67 (0) | 8.37 / 8.15 / 9.85 (3) |

Both builds sit on the 120 Hz display's vsync. The missed frames are hitches
of 30–257 ms in both builds, 7 frames each: main's all at the pad, the
branch's all at the phone, spread over different launches and holds on a host
shared with other lanes, not a cost that follows the build. `--disable-vsync` does not lift
the Mac's driver-level vsync (one launch each: the same 8.3 ms), so the
interval bounds the token's cost rather than reading it. The 3D stage is
untouched: identical draw calls and primitives (pad 80 / 57,890, phone 82 /
55,240). Per stone, the 2D draw went from an aliased disc and one or two
anti-aliased arcs (48 and 32 segments) to two anti-aliased discs. No shader
changed, so the screen-texture readers and every spatial shader's samplers
are as on main, and no device run was needed.

## Mutation proof

Each mutation backed `glass_waystone.gd` up, broke it, ran the gate and
copied the backup back.

- `tests/test_map_tokens.gd` fails on each of: main's own colours, alphas and
  rim width transcribed into the token tables (three checks: the land shows
  through every state, the edge's worst land 2.59:1, the rim 0.70 px on the
  phone); a dim silver rim (`TEXT_DIM`, 2.51:1); a translucent pane; a
  half-alpha walked glyph; a dark open glyph; a glyph tint that ignores the
  state; no walked state; a 3.0 px rim (1.74 px on the phone); a throb that
  darkens the rim. Run literally against main, the test cannot load: main has
  no token tables.
- `tools/map_token_gate.gd`, Acts I and II at seed 1 on both shapes: a 1 px
  rim drawn (the pane over all but 1 px) fails every token there (worst edge
  1.00:1); a `TEXT_DIM` rim drawn fails 71 of 76, 66 of 73, 5 of 79 and 7 of 53
  (worst edge 2.51–2.58:1).
- The gate reads a live land: launch to launch a sector's edge moves by up to
  0.3:1 (two launches compared row by row); every verdict held.

## Contact sheets

- `stills-act<N>-<phone|pad>.jpg`: every seed and zoom stop, before | after.
- `crops-<phone|pad>.jpg`: each state's token close up, every act and seed,
  at the default stop (Act I's Journey, the painted acts' stop 2), before |
  after, with each token's edge and glyph ratios and its verdict.

What they show: before, the cold and walked discs sink into the dark wood of
Act I and the dark ground of the painted acts, and the walked and current
stones are see-through. After, every stone reads as a ringed ink disc on every
land, and the gold pair, open and current, is found by its hue. At Whole act
some sixty silver rings stand across the map: every stone is legible, but the
gold pair is no longer the only light on it, and in a still it is found by hue
alone (in play the open stone's throb also carries it).

## Judgements

- **Silver is `TEXT`.** A greyer silver at the gold's own luminance (`#c3c8d4`)
  was tried; side by side it read almost the same, and it would have been a new
  token with less margin (3.39:1 on the worst land against 3.75:1). No token
  dimmer than `TEXT` holds 9:1 on `INK`.
- **`TEXT_FAINT` is new.** The walked glyph needed a tone quieter than the
  cold one and still above 3:1; `TEXT_DIM` against `GLASS_TEXT_DIM` is a 25%
  step that does not read. `#757c92` is the run text's third step, 4.6:1 on
  `INK`.
- **No contact shadow.** It is optional in the issue; it would fall in the
  2–6 px the gate reads as land, and the rim and pane already meet every land.
- **Open and current share the gold.** Open throbs and keeps its ember halo's
  pulse; current is steady and, in Act I, carries the pilgrim.

# Cards as real objects — design dossier (issue #657, Phase 1)

3 October 2026. Base: `main` at `dc6d8fb3`. Status: research. No production code
changed. The prototypes are scratch: their sources are kept under `proof/` as
`.txt` and are not part of the game.

The owner's ask (James, 3 Oct, 09:43): polish the cards in the battle hand and
the deck on the top menu; turn every card into a 3D object with a front and a
back; animate the draw; make the piles out of those same cards; and make the
card back swappable, because backs will be rewards.

**Recommendation in one paragraph.** Keep today's card exactly as it is at rest.
Give its 3D slab a back face, and turn cards over in two ways behind one API:

- a **live turn** (the slab turns in the card's own 3D stage, option C) for
  slow, single-card moments where the material should catch the light: the
  reward reveal, a new back's reveal, inspecting a card in the deck view;
- a **picture turn** (the frozen card warped on the canvas, option B) for
  fast, many-card flights: the opening deal, end-of-turn discards, exhausts,
  reshuffles.

Draw the piles, the reshuffle stream and the top-menu deck as stacks of one
baked back. Move the many-card views (the deck overlay, the pile inspector) to
baked faces, with a live card only under the finger. Both turns leave the
resting hand pixel-identical to today. On the iPad 8 a full five-card deal adds
**+0.2 ms** per frame with the picture turn (today's face-up deal adds +0.3 ms)
and **+1.9 ms** with the live turn, and nothing at rest.

---

## 1. What exists, measured

### 1.1 The card is already a 3D object, but it has only one side

`presentation/combat/card_view.gd` (1,383 lines) is a `Control` whose picture
is rendered in two offscreen passes per card:

| Pass | Node | Size at the game's 2x oversample | Mode at rest |
|---|---|---|---|
| 2D face (art, name, rubric, rules, cost floor) | `_inner` SubViewport, `disable_3d` | 336 × 464 px (card 152 × 216 + 8 px pad, ×2) | `UPDATE_ONCE` (frozen) |
| 3D stage: the glass slab, a camera, the lamp | `_stage` SubViewport, `own_world_3d`, MSAA 4x | 400 × 528 px (card + 24 px pad, ×2) | `UPDATE_ONCE` (frozen) |

The slab is a rounded-rect prism (`_prism_mesh`) with three surfaces: the
**side band** (unshaded, the stock's colour), the **front face**
(`card_surface.gdshader`, spatial, unshaded, one sampler) and the **cost gem**
(`card_gem.gdshader`, an 18-facet rose cut). Stock thickness is 5 to 12 card px
(`CardSurface.STOCK`). The camera is a 20° long lens about 749 px away; the card
tilts at most 7° toward the cursor and lifts 10 px, on a spring whose stiffness
is the stock's.

The tilt budget is small on purpose. The card subtends only 4.25° to 13.65° of
specular half-angle at rest (the card angular budget, measured 25 Jul), which
is why every finish is tuned in degrees and its specular exponents run in the
hundreds. A turn to 180° sweeps far outside that budget, so the turn itself is
where a foil can flare.

The slab has **no back face**. Seen from behind it would be empty except for
the side band.

Measured cost of one live card: **15.8 MB of video memory on the iPad 8**
(15.4 MB on the Mac), freed with the card. Both passes are frozen at rest, so a
resting hand costs no rendering, only memory.

### 1.2 A back exists, but only in the card lab

Commit `177468ca` (29 Jul, on `main`) taught `CardView` a `back` key: a back is
the same slab wearing a painting instead of a face, with stock, edge, shadow
and finish kept, and the name, rules and cost gem left out. The same commit
added the `aurora` finish. The only users are three pseudo-entries in
`presentation/lab/card_lab.gd`, the `BACKS` dictionary (`back:draw`,
`back:discard`, `back:ashes`, all on `aurora`), reachable with
`--studio=back:draw` or `--cards=back:draw --surfaces=…`. **The game never
builds one.**

### 1.3 The hand, the draw and the flights

`presentation/combat/hand_view.gd`: the fan follows the benchmark's law (gap
112 px, tilt step `min(5, 42/n)`, sag 3.2 px per degree). The draw is
`deal_in`: the card is **face-up from the first frame**, centred on the draw
pile at the pile's width, and grows into its seat over 0.28 s (ease-out cubic),
inside a 0.5 s wave budget (five cards: 0.10 s stagger, 0.68 s in all).
`spend_to` (0.2 s, ease-in, shrink and fade) sends a card to a pile;
`strike_to` (0.27 s, to 22% scale) throws an attack at its foe. Nothing turns
over anywhere. In `stills/00-deal-burst-today-pad.jpg` a face appears over the
pile and flies out.

### 1.4 The piles

`presentation/combat/hud_bar.gd` draws three piles (draw, ashes, discard) as
`Fan` controls: up to 16 copies of one **flat square painting** per pile
(`assets/art/piles/{draw,discard,ashes}.png`, 512²), 5° apart, the span capped
at 30° (the benchmark's `pile-chrome.js`), all in one `_draw()`. The ash pile
sits at 0.9 opacity. `fly_backs` runs the reshuffle as a stream of those flat
paintings on a quadratic arc. `docs/pile-back-brief.md` (26 Jul) asked for a
baked `pile_back(which)` texture made through the card system; it was never
built.

Pressing a pile in combat opens `_show_inspector`, a **text list** (name ×
count), not cards.

### 1.5 The deck on the top menu

There are two deck buttons, both a small painted icon (`ui/deck.png`) with a
number over it:

- outside combat, `presentation/run/run_hud.gd` (deck size) opens
  `Main._show_run_deck`, a `ChoiceScreen` overlay that builds **one live
  `CardView` per deck card** (`stills/02-today-deck-overlay.jpg`);
- in combat, `hud_bar.gd`'s seal (draw + hand + discard) opens the text
  inspector.

Measured on the Mac: opening the overlay on the 10-card starter deck adds
**166 MB of video memory** (16.6 MB per card) and 20 SubViewports. A 30-card
deck late in a run would add about 500 MB, on top of the roughly 580 MB the
combat screen already holds on the iPad 8 (a 3 GB device). That is an existing
risk, and it sits directly in the path of "polish the deck on the top menu".

### 1.6 "I believe we already did that?" — the honest answer

Half of it. Since July every card **is** a real 3D object: a glass slab with
thickness, a lamp and a tilt, rendered in its own small 3D stage. What was not
done:

- the slab has no back side;
- the July back is a separate lab-only object, not the other side of the card;
- nothing in the game turns a card over;
- the piles and the reshuffle are still flat paintings, fanned the way the web
  build fanned them;
- there is no back catalogue in content, no chosen back, no unlock.

A weekly summary in session memory says "card-back cosmetics (aurora/cosmos/
prism finishes, BACKS catalogue, per-back baking, cache invalidation)". That
overstates it. Searching every local and remote ref (`git log --all -S BACKS`,
`-S pile_back(`, `-S CardBack` and the `back`, `cosmetic` and `bake` greps)
finds only `177468ca`. The "BACKS catalogue" is the lab's three pseudo-entries;
per-back baking and cache invalidation never reached git, on any branch.

### 1.7 Device facts that bound every option

- **The iPad 8 (A12) frame budget is already full.** Across all eighteen device
  runs the combat screen *at rest* measured 16.6 to 21.1 ms median per frame
  (60 Hz is 16.7 ms). Anything that adds per-frame work drops frames.
- **A12 spatial shaders.** Godot 4.7.2's Forward Mobile path breaks *shaded*
  spatial materials on A12 (16-sampler Metal limit). The card's surface and gem
  shaders are *unshaded* with one sampler each, and the shipped cards render
  correctly on the iPad. A back plate reuses the same unshaded surface shader,
  so it is in the same risk class as today's face. No option reads
  `hint_screen_texture`.
- **A12 repro, run.** With `GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1
  --rendering-driver metal --rendering-method mobile` (the A12's classic
  binding on Forward Mobile), a cards-only sheet carrying every shader of all
  three options (front, gem, back plate, canvas warp, the table's unshaded
  materials) compiled with **zero errors** and rendered pixel-identical to the
  normal render; today's combat and option C in combat also compiled clean.
  Side finding: in this build `--rendering-driver metal` *without*
  `--rendering-method mobile` ran Forward+ (clustered), whose unrelated
  sampler errors (19, the same with or without any card change) are not the
  A12 path. The repro needs both flags.
- **On the device itself**, B and C render correctly mid-turn and at rest
  (`stills/12-ipad8-deal-C-left-B-right.jpg`, `stills/13-ipad8-C-mid-turn-detail.jpg`).
- **First-use hitches.** On the Mac, B's first warp took one 412 ms frame
  (the canvas shader compiling) and C's first measured deal one 75 ms frame;
  today's deal also showed a 157 ms frame, so not every spike is the turn.
  Production should pre-warm the back plate and the warp material at combat
  load, behind the entrance.

---

## 2. Three ways to make "a real card with a front and a back"

All three were prototyped against the **live combat screen**. The proof boots
the real game (`--fight=duskfang --kind=elite --seed=1`), waits for the fight
to settle, then replays the opening deal from a ten-card draw pile under each
treatment, using the real `HandView` seats and the real HUD pile positions.
Sources: `proof/*.txt`.

### (A) One shared 3D table

A single transparent SubViewport the size of the stage (window pixel density,
MSAA 4x), one perspective camera, and every card as a mesh in it. The hand's
`CardView`s become invisible proxies that keep layout and input; their own 3D
stages are disabled; faces still come from each card's 2D face pass.

What it buys: real parallax thickness in the piles (stacked slabs, side bands
visible off-axis) and one camera for everything.

What it costs, measured:

- **Fidelity at rest regresses.** Against today's resting hand, 37% of the
  hand's pixels change (mean |Δ| 19/255). One camera views every card off-axis,
  so the tuned finishes shift; cards on deeper layers grow; the table shadows
  are gone; and the fan's overlap order has to be rebuilt as depth
  (`stills/08-rest-today-top-vs-A-bottom.jpg`).
- **Draw order becomes depth.** In the first prototype the cost gems of the
  hand poked through a card flying over them. A turning card sweeps about
  ±76 px in depth, so a card in the air has to ride about 90 px above the fan,
  which makes it visibly larger.
- **iPad 8: +8.6 ms on every deal frame** (median 29.7 ms during the deal
  against 21.1 ms at rest in the same run; 84% of deal frames over 20 ms), and
  **+160 MB of video memory** for the full-screen table.
- Input, hover tilt, tooltips (`keyword_at`) and shadows all need re-plumbing
  through a projection.

### (B) 2.5D on the canvas — the "picture turn"

The card stays exactly as it is. While it turns, its own `display` rect (the
frozen stage texture) gets a canvas shader (`warp.gdshader`) that casts each
fragment's ray into a rotated slab: the front samples the frozen face, the back
samples a baked back, and a ray that enters through the rim paints the side
band. The perspective is exact and no viewport renders while it turns.

- **Fidelity at rest: identical to today** (mean |Δ| 0.01/255; 0.02% of
  pixels, which is the ambient motes).
- **In the turn, the material is frozen.** The foil, the lamp and the gem's
  facets are a picture of the card at rest, turned; a cheap Lambert falloff
  stands in for the light. At deal speed (0.42 s) it is hard to tell from C in
  stills; in a slow reveal it shows.
- **iPad 8: +0.2 ms** mean per deal frame over rest in five-card deals (+0.25 ms
  in four-card deals), the same as today's face-up deal (+0.3 ms).
- Complexity: one canvas shader (two samplers), no change to input.

### (C) The card's own slab turns in its own stage — the "live turn"

The canvas card at rest is untouched. A **back plate** (the slab's face
outline, rotated 180° and sitting on the back of the slab) is added to the
card's existing 3D stage, wearing the chosen back through the same
`card_surface.gdshader` and lit by the card's own lamp. During a flight the
slab turns (yaw 180° to 0°, with a small pitch), and only that card's stage
re-renders until it lands. Piles and back-only flights are canvas stacks of one
baked back (`pile_stack.gd`).

- **Fidelity at rest: identical to today** (mean |Δ| 0.01/255).
- **In the turn, the material is live.** The finish, the foil band and the gem
  answer the angle as the card turns, because the same renderer is doing the
  same job (`stills/04-turn-sheet-C-B-A.jpg`, top row).
- **iPad 8: +1.9 ms** mean per deal frame over rest in five-card deals (runs
  +1.3 and +2.7), +1.4 ms in four-card deals (round 2), +2.1 ms median in
  round 1. That is about 0.5 to 0.7 ms per card while it turns (2.4 to 2.7
  cards are in the air at once). Turning MSAA off in flight (variant
  C2) did **not** reduce it (+2.1 ms), so the stage render itself, not its
  anti-aliasing, is the cost.
- Complexity: one child mesh and one material per card; the flight code gains
  a yaw. Input, hover, tooltips and shadows are unchanged.
- A12 risk: same shader class as today's face (unshaded, one sampler).

### 2.1 Looks

| Still | What it shows |
|---|---|
| `stills/04-turn-sheet-C-B-A.jpg` | One card at 0°, 35°, 70°, 100°, 140° and 180° under C, B and A, with a ten-card pile beside each row |
| `stills/05-deal-burst-C-pad.jpg` | C, live combat, the five-card deal at 0.25× time: back-up off the pile, turning in flight, landing face-up |
| `stills/06-deal-burst-B-pad.jpg` | B, the same deal |
| `stills/07-deal-burst-A-pad.jpg` | A, the same deal (after the depth fixes) |
| `stills/00-deal-burst-today-pad.jpg` | Today's deal, for reference |
| `stills/09-C-phone-landscape.jpg`, `stills/10-C-desktop-landscape.jpg` | C at the other two shipping shapes (pad is 05) |
| `stills/11-pile-states.jpg` | Piles of real cards: thickness from 0 to 99, discard face-up, ashes charred, the top-menu deck as a mini stack |
| `stills/03-back-concepts-vault-rose-eclipse.jpg` | Three backs for evaluation |
| `stills/12-ipad8-deal-C-left-B-right.jpg`, `stills/13-ipad8-C-mid-turn-detail.jpg` | Captured on the iPad 8: C and B mid-deal and at rest |
| `stills/01-today-combat-pad.jpg`, `stills/02-today-deck-overlay.jpg` | Today's combat screen and deck overlay |

### 2.2 Cost, Mac (M1 Max, Mobile renderer on Metal, 1180 × 820)

Eight measured deals each (the first deal is discarded as warm-up). The Mac
display holds the frame at its 120 Hz cadence even with vsync off (MoltenVK
behaves the same), so these numbers show that nothing regresses; they cannot
rank the options. The iPad does.

| Option | Deal p50 / p95 / max (ms) | Rest p50 / p95 (ms) | Draw calls in a deal frame (p50) | Video memory, rest / peak (MB) |
|---|---|---|---|---|
| Today | 8.0 / 9.5 / 157 | 8.3 / 9.4 | 111 | 397 / 480 |
| C | 8.1 / 9.7 / 75 | 8.0 / 9.3 | 126 | 397 / 480 |
| B | 8.0 / 9.4 / 11 | 8.5 / 9.3 | 120 | 397 / 480 |
| A | 8.0 / 9.4 / 16 | 8.6 / 9.3 | 131 | 445 / 478 |

### 2.3 Cost, iPad 8 (A12, 2160 × 1620, pad-landscape), round 1

One QA export of this tree (release build, local A12-fixed template,
Development profile), 60 Hz, eight measured deals per run from a ten-card
pile. On the device the Development profile opened this fight with a
**four-card** hand (against a "Veiled" Duskfang; the Mac dealt five), so the
device deals are four cards. The proof builds the whole hand in the deal's
first frame, which is harsher than the real game (one card per stagger) and
the same for every option.

| Option | Deal p50 / p95 / max (ms) | Deal frames > 20 ms | Rest p50 / p95 (ms) | Deal − rest, same run (median) | Video memory rest / peak (MB) |
|---|---|---|---|---|---|
| Today | 19.7 / 23.9 / 52.6 | 37% | 19.7 / 22.4 | +0.0 | 575 / 641 |
| C | 18.8 / 23.7 / 50.2 | 31% | 16.7 / 19.9 | +2.1 | 583 / 649 |
| B | 20.4 / 40.6 / 48.3 | 60% | 20.4 / 23.0 | −0.0 | 583 / 649 |
| A | 29.7 / 44.7 / 52.2 | 84% | 21.1 / 30.6 | **+8.6** | 742 / 798 |

Today, B and C have an *identical* resting scene, yet their resting medians
spanned 16.7 to 20.4 ms: that spread is device state (thermal and background),
not the cards. Round 2 was therefore run interleaved, and the comparison is
always against the same run's own rest.

### 2.4 Cost, iPad 8, round 2: four-card deals (interleaved: C, today, B, C2, C, today, B, C2)

| Run | Rest p50 (ms) | Deal p50 / p95 / max (ms) | Deal frames > 20 ms | Deal − rest (median) |
|---|---|---|---|---|
| C #1 | 16.7 | 17.1 / 21.4 / 46.1 | 10% | +0.4 |
| Today #1 | 18.9 | 18.6 / 23.1 / 53.9 | 22% | −0.3 |
| B #1 | 19.8 | 19.8 / 24.9 / 48.5 | 43% | +0.0 |
| C2 #1 | 19.8 | 21.8 / 28.1 / 39.9 | 84% | +2.0 |
| C #2 | 18.8 | 20.8 / 26.8 / 42.5 | 66% | +2.0 |
| Today #2 | 19.8 | 19.8 / 23.9 / 40.3 | 45% | +0.0 |
| B #2 | 19.8 | 19.7 / 23.9 / 39.8 | 39% | −0.0 |
| C2 #2 | 18.8 | 20.9 / 25.3 / 38.2 | 67% | +2.1 |

Pooled, as mean deal frame (the card-building first frame excluded) minus mean
rest frame in the same runs:

| | Today | B (picture turn) | C (live turn) | C2 (live, no MSAA in flight) | A (round 1) |
|---|---|---|---|---|---|
| Added per deal frame | +0.10 ms | **+0.25 ms** | **+1.36 ms** | +2.09 ms | about +8.6 ms |

### 2.4b Cost, iPad 8, round 3: full five-card deals (interleaved: C, B, today, C, B, today)

The proof now tops the hand up to five from the draw pile, so these are full
five-card deals (confirmed by the memory peak: five live cards' worth above
rest).

| Run | Rest p50 (ms) | Deal p50 / p95 / max (ms) | Deal frames > 20 ms | Deal − rest (median) | Mean deal − mean rest |
|---|---|---|---|---|---|
| C #1 | 16.6 | 17.2 / 23.4 / 51.1 | 18% | +0.5 | +1.30 |
| B #1 | 18.7 | 18.4 / 22.6 / 55.7 | 20% | −0.2 | +0.06 |
| Today #1 | 20.6 | 20.5 / 27.1 / 49.0 | 67% | −0.1 | +0.31 |
| C #2 | 19.8 | 21.7 / 37.6 / 41.2 | 77% | +1.9 | +2.73 |
| B #2 | 20.3 | 20.3 / 25.2 / 50.8 | 59% | −0.0 | +0.35 |
| Today #2 | 20.3 | 20.4 / 25.6 / 46.9 | 65% | +0.1 | +0.25 |

| Five-card deal, pooled | Today | B (picture turn) | C (live turn) |
|---|---|---|---|
| Deal p50 / p95 / max (ms) | 20.4 / 26.3 / 49.0 | 19.6 / 23.7 / 55.7 | 19.3 / 28.3 / 51.1 |
| Added per deal frame (mean, build frame excluded) | +0.28 ms | **+0.20 ms** | **+1.85 ms** |

The share of deal frames over 20 ms mostly tracks the device's state in that
run (compare the two rows of the same option); the added-per-frame figure is
the one that separates the options.

Per live card on the A12: **15.77 MB** of video memory in every option except A
(whose per-card stage is disabled; A pays 160 MB for the table instead). The
largest single frame in every option (38 to 54 ms) is the frame that builds the
new cards, not the turn.

### 2.5 Input and hit-testing

- **B and C:** unchanged. The card stays a `Control` with its rect, signals
  and `keyword_at`. The turn happens inside its picture; flights already ignore
  input (the sequencer locks the hand).
- **A:** the `CardView` becomes an invisible proxy, but what the player sees is
  the projection of a mesh at a depth layer. Hit-testing, the hover tilt (which
  now sweeps into neighbouring layers), keyword tooltips and the table shadow
  all need re-mapping through the camera.

### 2.6 Complexity

| | New code | Changes to existing code | Risk |
|---|---|---|---|
| A | A table view (about 400 to 600 lines): depth layering, per-card lamp, shadows, picking | `HandView`, `CardView`, combat composition, the HUD piles | High: it changes a tuned look and the input model |
| B | One canvas shader (about 80 lines) plus the shared pile and back work | The flight code | Low; the frozen material is its look ceiling |
| C | A back plate (about 40 lines) plus the shared pile and back work | The flight code; `CardView` gains a turn API | Low; same renderer, same shader class |
| B + C behind one API | Both of the above (about 120 lines) and a rule for which turn a flight uses | As C | Low; two renderers to keep visually matched |

---

## 3. Motion spec

Durations are for pad-landscape; distances scale with the stage height (the
prototype's fixed 70 px arc was visibly too tall on the 390 px phone stage).
"Ease-out cubic" is `1 − (1 − t)³`; the seat overshoot is the existing
`CardView.POSE_EASE` (0.25, 0.9, 0.3, 1.2) over 0.28 s. "Picture" and "live"
name the two turns in the recommendation.

| Moment | Spec | Skip | Reduce Motion |
|---|---|---|---|
| **Draw** (per card), picture turn | The top card of the draw pile rises 6 px (60 ms) and the pile loses one card's thickness at once. It flies 0.42 s, ease-out cubic, on an arc peaking at 9% of stage height, scaling from the pile card to the hand card and rotating from the pile's −4° to its seat. It **turns** from 180° to 0° over t = 0.12 to 0.78 (smoothstep), pitching −14°·sin(πt) toward the viewer. The table shadow narrows with \|cos yaw\| and lifts away. It lands into the existing seat overshoot, with a 250 ms edge glint as the face settles. A wave staggers 90 ms, so five cards take 0.78 s (today 0.68 s); past five the stagger is `max(40 ms, 450 ms / n)`. A single draw mid-turn may use the live turn. | A tap during the deal lands every card in flight face-up in 120 ms. | No arc, no turn, no pitch: each card fades in at its seat (160 ms, 6 px rise), 40 ms apart. |
| **Play** (skill or power) | Unchanged up to release, then 0.26 s ease-in to the discard pile, landing **face-up** on top with a ±3° jitter; the pile bumps (existing `pileBump`). | Lands at once. | Fade at the seat; the pile count ticks. |
| **Play** (attack) | Existing `strike_to` (0.27 s to 22% scale at the foe); the discard pile's top becomes that card's face as the strike resolves. | — | — |
| **End-of-turn discard** | Each hand card flies 0.26 s ease-in-out to the discard pile, 50 ms apart, landing loose (±3 px, ±5°). Five cards: 0.46 s. | Lands at once. | Cards fade; the count ticks. |
| **Exhaust**, picture turn | The existing blaze (brightness 2.4, 8°, scale 0.6), but the card also turns face-down while it burns (0° to 180° over 200 ms) and lands on the ashes pile as a charred back whose ember rim cools over 1.2 s; ash motes rise for 0.6 s. | Lands charred at once. | Fade; ember rim only. |
| **Shuffle** (discard into draw) | The discard pile lifts as a stream (at most 8 visible, as today): the first card, which still shows its face, turns face-down in the first 40% of its flight (picture turn); the rest are sprites of the baked back. Each arcs over to the draw pile; the stagger is `0.6 s × 0.35 / n`; the draw pile thickens card by card; then the top edges jog ±2 px for 120 ms and square up (tapping the deck square). About 0.72 s. The reshuffle plays the generic `card` cue today; a riffle cue would be new SFX. | The stream completes in 150 ms. | Counts move; one 200 ms pulse on each pile. |
| **Reward pick**, live turn | Three cards are dealt face-down from a small stack in the reward window and turn over one after another (120 ms apart, 0.48 s each), the lamp sweeping across so each foil flares as it shows its face. The picked card turns face-down as it shrinks into the top-menu deck stack, which gains a card's thickness and bumps; the others turn back and slide away. | Cards appear face-up. | 160 ms fade, no turn. |
| **Deck view open** | Tapping the top-menu stack lifts it 6 px (120 ms); the cards stream to their grid cells back-up and turn face-up as they land (picture turn; 18 ms apart, the whole stream capped at 0.5 s; 0.3 s per card, turning in its last 60%). Grid cards are baked faces; the card under the finger becomes a live card with tilt and lamp, and turning it over to see its back is a live turn. Closing is the reverse at 60% of the time. | Tap again: the grid completes. | 160 ms fade. |
| **Idle life at rest** | Canvas only (the rule below): a slow travelling glint over the draw pile's top back and the top-menu stack (9 s cycle, phases offset), the ashes rim breathing (alpha 0.45 to 0.65 over 3.2 s), the existing rare shine on hand cards, and the existing hover tilt and lamp under the finger. | — | Glints off; the rim holds still. |

**The idle rule for the A12.** At rest a card's 3D stage stays frozen. A
"breathing" hand (a continuous ±0.6° drift) would keep five stages rendering
every frame: the live turn's cost made permanent on a device already at budget.
Life at rest therefore lives on the canvas (shaders over baked textures,
transforms), and a card's stage renders only when its pose changes: touch,
a live turn, play.

---

## 4. Piles of real cards

All piles are one `_draw()` each (at most about 26 draw commands), no node per
card, and one shared baked texture of the chosen back
(`stills/11-pile-states.jpg`; prototype `proof/pile_stack.gd.txt`).

- **Thickness law** (in pad stage px; the phone and desktop shells scale it):
  1 px per card up to 10, then 0.35 px per card, capped at 14 px. So 1, 5 and
  10 cards read differently, 40 is visibly deeper than 10, and 99 never becomes
  a tower. One edge sliver per pixel of thickness (at most 24), in alternating
  tones so single cards resolve, with a deterministic jitter of ±0.6 px and
  ±0.6°.
- **Draw pile:** a squared stack, backs up. Empty: the faces go and the count
  and name stay (the existing rule).
- **Discard pile — recommended face-up.** The top is the last discarded card's
  real face (baked when it lands, or that card kept frozen), loose underneath
  (±3 px, ±5°). This is how a discard pile looks on a real table, it shows the
  player what just went, and it keeps the three piles tellable apart **without
  tinting the player's chosen back**, which the issue's "backs showing" would
  otherwise force.
- **Ashes:** backs up, charred (tint 0.42) with an ember rim, at the existing
  0.9 opacity.
- **Top-menu deck:** a 36 × 51 px stack of backs where the icon is today, the
  count over it, thickness from the deck size (the same law, scaled). The same
  stack replaces the combat seal.
- **What it replaces:** the benchmark fan (16 faces, 5° apart, 30° cap) and
  the three pile paintings. That is a deliberate divergence from the frozen
  benchmark; the commercial rubric is the standard here.

---

## 5. Swappable backs as data

### 5.1 The catalogue

A content file, `content/card-backs.json`, read by presentation (the precedent
is `content/event-staging.json`, which `event_screen.gd` reads directly). The
domain never sees it.

```json
{
  "default": "vault",
  "backs": {
    "vault":   {"name": "ui.back.vault",   "art": "res://assets/art/piles/draw.png", "surface": "aurora", "unlock": {"kind": "default"}},
    "rose":    {"name": "ui.back.rose",    "shader": "res://presentation/cards/backs/rose.gdshader", "surface": "prism", "unlock": {"kind": "deed", "deed": "wins", "at": 1}},
    "eclipse": {"name": "ui.back.eclipse", "shader": "res://presentation/cards/backs/eclipse.gdshader", "surface": "gilt", "unlock": {"kind": "quest", "quest": "eighthOmen"}}
  }
}
```

A back is a picture (a painting on disk or a procedural canvas shader) plus a
`CardSurface` recipe, so the stock, the edge, the shadow and the finish are the
same system the fronts wear, and a new back costs one entry. The three concepts
(`stills/03-back-concepts-vault-rose-eclipse.jpg`): **Vault**, the existing
draw painting on the aurora finish (the natural starter back); **Rose**, a
leaded rose window in night glass on the prism finish; **Eclipse**, an
engine-turned gold field round a black sun on the gilt finish. Rose and Eclipse
are procedural shaders, so they cost no texture payload. The unlock rules shown
are placeholders for decision 7.

### 5.2 Applied everywhere a back shows

One presentation helper, `CardBacks`, owns it:

- `CardBacks.chosen() -> String` reads the preference, falling back to the
  default when the stored id is unknown or not unlocked.
- `CardBacks.baked(id) -> {stage, inner}` builds the back once through the
  `CardView` back path, renders it once and reads it back. It is cached per
  (back id, oversample) and dropped when the choice changes. The bake is one
  GPU readback; do it behind a screen transition, never mid-fight.
- Consumers: the card's back plate (live turns), the picture turn's back
  texture, every pile stack (draw, ashes, the top-menu deck, the combat seal),
  the reshuffle stream and the deck view's back-up cards. Changing the back
  touches none of `RunState`, the seeded RNG, the fixtures or any save.

### 5.3 Where the choice and the unlocks live

- **The choice: a preference.** `user://settings.cfg`, a new section
  `[cosmetics]` with key `card_back` (a string, default `"vault"`), held by
  `application/preferences.gd` next to `language`. It is **additive and
  backward-compatible**: an older build reading the file ignores the section.
  One caveat: `Preferences._store()` rewrites the whole file from the fields it
  knows, so an *older* build that saves settings drops the key and the player
  sees the default back again. That is cosmetic and touches no save lineage.
- **The unlocks, first set: derived, no save change.** Unlock rules are pure
  functions of what the Vigil v2 ledger already records: `deeds` counters
  (`wins`, `slain`, `shatters`, `kindles`, `perfects`, `bestVow`, …),
  `quests.<id>.state == "complete"` and `shards`. Nothing is written; an unlock
  is earned the moment the deed is.
- **If a later back must be granted by an event the ledger does not record**
  (a promotion, a one-off reward), add an additive v2 list `cardBacks` to
  `domain/state/vigil_state.gd`, following the `dawnLeaves` and
  `defeatEpitaphs` precedent ("Additive v2: missing on load defaults empty — no
  envelope bump"). It must **not** go into `unlocks`, which is the title's
  secrets count and the Dawn reveal feed. An older build loading such a file
  ignores the key; saving from an older build drops it, as with `dawnLeaves`.
  That is a domain change and is not needed for the first set.
- **The v2 run and Vigil lineage is untouched.** No breaking save change is
  required by any part of this plan.

### 5.4 Choosing

Recommended: a **Backs** shelf in the Vigil screen (the cross-run collection,
where earned things already live), each back shown as a live turning card, the
locked ones as a silhouette with their deed. A newly earned back is revealed at
Dawn as a card turning over. Settings stays for settings.

---

## 6. Recommendation, ranked

1. **Hybrid by moment (B + C behind one `turn()` API).** Canvas card at rest,
   exactly as today. Picture turn (B) for fast, many-card flights; live turn
   (C) for slow, single-card reveals. Piles, the reshuffle and the top-menu
   deck are canvas stacks of one baked back; many-card views use baked faces.
   It puts the live material where the eye has time to see it, and keeps the
   five-card deal at +0.2 ms (no more than today's) on a device that is
   already at budget.
2. **C everywhere.** One renderer, the best look in every flight, +1.9 ms per
   frame during a five-card deal on the iPad 8. The right choice if one
   mechanism matters more than that cost.
3. **B everywhere.** The cheapest; the material is frozen even in slow
   reveals, which is where the owner's "real object" is most visible.
4. **A, the shared table — rejected.** It changes the tuned look at rest,
   costs about 8.6 ms per deal frame and 160 MB on the A12, and turns draw
   order into a depth problem.

### 6.1 Build plan (PR-sized)

| PR | Outcome | Size (est.) | Proof |
|---|---|---|---|
| 1 | Back catalogue, `CardBacks` baker and cache, the `[cosmetics] card_back` preference with fallback; the lab's `BACKS` pseudo-entries retired in favour of the catalogue | ~300 lines | Unit tests (catalogue validity, preference round-trip, unknown/locked fallback); lab stills |
| 2 | The card gets its back and a `turn(yaw, pitch, live)` API: the back plate on the slab (live) and the canvas warp (picture); pre-warm both at combat load | ~200 lines | Turn sheet at three shapes; the A12 Mac repro (both flags) clean |
| 3 | Draw, play, discard and exhaust flights with turns, skip and Reduce Motion | ~250 lines | Frame bursts at three shapes; **iPad 8 frame times for a full five-card draw** |
| 4 | Piles as stacks (draw backs-up, discard face-up, ashes charred), the reshuffle as a turning stream, the pile inspector as cards | ~300 lines | Pile-state stills; reshuffle burst; iPad timing of an eight-card reshuffle |
| 5 | The top-menu deck as a stack; the deck overlay on baked faces with a live card under the finger; open/close turns | ~300 lines | **Video memory of the deck overlay before/after on the iPad 8**; open/close bursts |
| 6 | Reward pick as a live-turn reveal; the Vigil Backs shelf; the Dawn reveal of a new back | ~300 lines | Bursts; preference persistence |
| 7 | Final back art and locale strings | data | Art review |

Each stays under the 600-line-per-file stop condition.

### 6.2 Payload

The iOS pack estimate is **254.9 MiB** against the 400 MiB ceiling
(`tools/payload_report.py`, this tree).

- Code and shaders for the whole plan: under 0.1 MiB (the `presentation` group
  is 2.4 MiB of a 3 MiB budget).
- A **procedural** back (Rose, Eclipse): about 0.01 MiB each.
- A **painted** back at the card-art settings (1024 px limit, VRAM-compressed,
  mipmaps): about 0.5 to 0.9 MiB each; a card art at those settings measures
  0.46 MiB (`strike.jpg`).
- Retiring the discard and ashes paintings once the piles wear the chosen back
  saves about 0.4 MiB.

Six painted backs would add about 4 to 5 MiB; six procedural backs about
nothing.

### 6.3 Risks

- **The A12 is already at budget at rest** (16.6 to 21.1 ms medians across
  eighteen device runs). The idle rule in §3 and the picture turn for bulk flights are
  what keep the new work from becoming permanent cost.
- **Video memory per live card (15.8 MB) is the real hazard** of "piles of real
  cards" and of the deck view. Anything that wants many cards must use baked
  faces and keep at most a handful of live cards. A follow-up worth scoping:
  free a resting card's stage (keep its last frame as a texture) and rebuild it
  on touch, which would cut a resting hand from about 80 MB to under 10 MB.
- **The live turn's cost is not MSAA.** If C must get cheaper, the next lever
  to measure is a half-resolution stage while the card is in the air.
- **First-use hitches** (up to 412 ms on the Mac at the first warp): pre-warm.
- **Bake readback stalls**: bake behind transitions.
- **The phone arc**: distances must scale with the stage height.
- **Benchmark divergence**: the stack replaces the benchmark fan by design.
- **Two turn renderers must match**: same pose maths, same baked back; the
  turn sheet is the regression still.

---

## 7. Decisions needed

1. **Turn mechanism:** hybrid by moment (recommended), C everywhere, or B
   everywhere.
2. **Discard pile face-up** (recommended) or backs-up as the issue states.
3. **Squared stacks** replacing the benchmark fan for the draw pile.
4. **Starter back:** keep Vault (the existing draw painting on aurora), and
   retire the discard and ashes paintings.
5. **Back art direction:** procedural (no payload), painted (about 0.5 to
   0.9 MiB each), or a mix.
6. **Where backs are chosen:** the Vigil shelf (recommended) or Settings.
7. **Unlock mapping** for the first set, from existing deeds and quests (no
   save change).
8. **Scope of the video-memory fix** (baked faces for the deck view and the
   inspector): inside this issue as PR 5 (recommended) or a separate issue.
9. **The idle rule:** canvas-only life at rest on the A12.

---

## Appendix: how the evidence was made

- Proof sources: `proof/*.txt` (`proof.gd` drives the live combat screen;
  `backs.gd` builds and bakes backs; `pile_stack.gd`, `warp.gdshader`,
  `table3d.gd`, `flipsheet.gd`, `pilesheet.gd`, `preview_backs.gd`, `run.gd`;
  `device_runner.sh` and `device_attach_patch.py` for the iPad). Mac runs:
  `godot --path . -s res://qa_cards/run.gd -- --fight=duskfang --kind=elite --seed=1`
  with `CARDS_PROOF="opt=<base|a|b|c|c2>,back=rose,deals=9,out=…"`.
- iPad: a QA export of this exact tree with a four-line attach in `main.gd`
  (never committed), installed as a development build; the proof wrote its rows
  to `Documents/` and they were pulled with `devicectl`. The device was
  discovered at run time; its identifier is not recorded here. Development
  profile only; no real save was read or written.
- Device batch 2 (after the review round): `proof/device-b2/` keeps the batch log,
  the per-run summary and the batch script, as text.
- PR 4, the flights: `proof/pr4/` keeps the frame bursts of the Draw, Play,
  End-of-turn discard and Exhaust rows at the three shapes and under Reduce
  Motion, the A12 condition, and the iPad 8 batches against `main`: its
  `README.md` has the rows as built, the device table and the entrance's long
  frames; the scripts and summaries are text under `device/`.
- Fidelity diffs: the resting hand captured 1.2 s after the second deal,
  compared pixel by pixel with today's over the hand region (800 × 220 stage
  px).
- Captures used a real window (no `--headless`) and an isolated user directory.

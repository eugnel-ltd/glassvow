# Stagecraft art — candidates for #560–#563

## Landed (2026-09-29)

James picked nine Codex round-4 portraits on 2026-09-29 (see Round 4), and
eight of them landed. Each is at its ledgered path under
`assets/art/portraits/`, byte for byte the survivor named here, with its
`.import` sidecar. `docs/art-ledger.md` now records them as shipped, with the
request that rendered each one and the caveats this README notes. Stills of
each on its stage cut are in `docs/reviews/559/`.

| Ledger path | Pick | Rank across rounds |
|---|---|---|
| `portraits/keeper-tender.png` | `keeper-tender-c2` | #1 |
| `portraits/keeper-offering.png` | `keeper-offering-c3` | #1 |
| `portraits/keeper-weary.png` | `keeper-weary-c2` | #1 |
| `portraits/keeper-beckon.png` | `keeper-beckon-c4` | #1 |
| `portraits/lamplighter-wary.png` | `lamplighter-wary-c1` | #2, after `c4` |
| `portraits/lamplighter-asking.png` | `lamplighter-asking-c1` | #1 |
| `portraits/lamplighter-recognising.png` | `lamplighter-recognising-c4` | #2, after Grok's `b` |
| `portraits/lamplighter-urgent.png` | `lamplighter-urgent-c1` | #1 |

**The ninth pick was withdrawn before landing.** `lamplighter-grieving-c3`'s
lantern pole differs from the shipped figure's: it is held inverted, crook at
the foot, with the lantern hanging by his feet. `portraits/lamplighter-grieving.png`
stays commissioned for a round 5. Until then the stage carries that mood as
before: the shipped figure, in posture and light.

The Queue chorus (#562) and the two Unlit Way plates (#563) have not landed
either; a redo round is under way. Only this README and the four contact
sheets came to `main`. Everything else stays on the branch
`art/stagecraft-candidates-2026-09-29` at 44ce8a61: every other survivor, so
the `survivors/` links below resolve there and not on `main`, and
`tools/key_magenta.py`, the keyer and gate this README runs.

Everything below is the candidates round as it stood before the landing.

A candidates round for the portraits and plates billed in `docs/art-ledger.md` ›
"Commissioned — dialogue stagecraft portraits and plates (2026-09-27)" (parent
#559). **Nothing here is in `assets/`.** James picks one file per path. A
landing commit then copies each pick to its ledgered path, commits the
`.import` sidecar, moves the ledger row to Shipped with the prompt that
rendered it, and takes the stills the issues ask for.

118 candidates were generated on 2026-09-29 in four rounds, and 73 survive.

- **Rounds 1 to 3 (Grok Build, 69 candidates, 31 survivors).** Round 1 was the
  canonical prompts. Round 2 was an authorised follow-up for the four files
  round 1 left short, each with one amended sentence. Round 3 re-rolled
  `unlit-way` alone, with a placement sentence of its own (see Rounds 2 and 3).
- **Round 4 (Codex, 49 candidates, 42 survivors).** Round 4 redid every file with
  Codex on the owner's instruction, drawing the portraits on a transparent
  background rather than magenta. Each file is now ranked once across both
  tools (see Round 4).

Each family's contact sheet shows every candidate of every round, labelled,
rejects included, and its tags carry that cross-round ranking. `survivors/`
holds all of Grok's survivors and the Codex survivors ranked #1 or #2 in their
file. The 25 MB cap left the rest on the sheets (see Round 4). Raw renders and
rejects stay out of the tree.

| Family | Issue | Sheet | Generated (Grok + Codex) | Survivors (Grok + Codex) | Ranked first, across both |
|---|---|---|---|---|---|
| Keeper moods | #560 | [`contact-keeper.png`](contact-keeper.png) | 16 + 16 | 11 + 15 | tender-c2, offering-c3, weary-c2, beckon-c4 |
| Hollow Lamplighter moods | #561 | [`contact-lamplighter.png`](contact-lamplighter.png) | 24 + 20 | 13 + 20 | wary-c4, asking-c1, recognising-b, urgent-c1, grieving-c3 |
| Queue chorus | #562 | [`contact-queue.png`](contact-queue.png) | 9 + 5 | 3 + 0 | queue-chorus-h |
| Unlit Way plates | #563 | [`contact-plates.png`](contact-plates.png) | 20 + 8 | 4 + 7 | unlit-way-c3, unlit-way-end-c1 |

**No gaps remain.** Every file has at least two survivors. Round 3 was Grok's
last round.

## Binding

- **Portrait contract** (the ledger): an image-to-image edit of the named
  reference on the same canvas and framing, with one bust crop per actor that
  fits every mood. The `content/actors.json` crops, as `[x, y, w, h]`: Keeper
  rows 7–71%, Lamplighter rows 0–60%, Queue the full canvas. No face, ever.
  Generated on flat `#FF00FF` and keyed. The alpha gate applies, and shipped
  assets are never modified.
- **Rejected on sight** (this round's brief): any face, eye or glowing point in a
  hood or on the Lamplighter's head; painted cloth instead of leaded panes; a
  re-framed, re-scaled or cropped figure; the wrong rim-light side; a Keeper
  pose that points at anything; a Lamplighter whose lantern is lit or missing; a
  Queue that reads as a crowd rather than one receding line; a plate with a
  figure in it, or anything load-bearing in the outer 28% of the width or the
  bottom 30%.
- **Moods cut against each other.** `content/scenes.json` cuts straight from one
  mood to the next. act4-node5 plays revealed, revealed, then beckon. m1-pre
  plays wary then recognising; m3-pre, recognising then wary; m4-pre,
  recognising then urgent; m5-pre, recognising, asking, then grieving. A mood
  whose glass or rim light departs from its reference therefore changes the
  character's material on the cut. That is why a lost amber rim or a drifted
  palette is a rejection here, not a matter of taste. The canonical prompt
  binds the palette too ("keep the exact same … palette").
- **The stage lights its own rim.** `StagePortrait` adds a warm rim from the
  side `actors.json` declares: Keeper right, beckon left, Lamplighter left. The
  shipped Lamplighter carries painted amber on both edges, so for him a rim
  that shifts to one side is a caveat. A rim that vanishes is a rejection.
- **Where the busts stand.** `StageDirection` seats the hero at 0.20 of the
  width and the Lamplighter at 0.80 (far-right 0.92, centre 0.50). The plates'
  28% bands are those two columns.

## How they were made

This section covers rounds 1 to 3, made with Grok Build. Round 4's Codex method,
its unkeyed gate and the cross-round ranking are under Round 4.

- **Generation.** Through `~/.claude/scripts/subagents/run-grok-media.sh`:
  Grok Build CLI 1.0.41 with the model `grok-4.7` (the wrapper picks the newest
  at run time), one image per call, three calls at a time. Each request reads
  the reference at its absolute path, then carries the canonical prompt
  verbatim from the issue (the issues assemble the ledger's clauses), the exact
  canvas and the output path. Round 1 made 49 calls, round 2 16 and round 3 4.
  All 69 returned the right canvas on the first attempt; no retry was needed.
- **References.** For the portraits, the files the ledger names:
  `meta/keeper.png`, `enemies/eternalKeeper.png` for beckon, and
  `meta/hollow-lamplighter.png`. For the Queue, `meta/keeper.png` and
  `scenes/unsealing-mirror-queue.png` as style references for a new figure
  group. The plate brief names no reference, so each plate request attached
  `scenes/opening-hearth.png` as a style anchor and told the model to keep only
  its rendering. In `unlit-way-d` the hall bled through anyway.
- **Keying and the gate.** `tools/key_magenta.py` is new in this change.
  Pillow 10.4.0 was already installed, so nothing was installed. The tool keys
  the field: magenta strength `min(R, B) − G` within 48 of the border's own,
  connected to the border or in an enclosed pocket of at least 48 px. It mattes
  a 2 px edge against the local figure colour, so no pink or green fringe
  survives. It then writes RGBA, runs `sips -Z 1024` and grades the written
  file against the ledger gate. `--haze` (Lamplighter and Queue only, never the
  Keeper, whose violet glass reaches strength 120) also clears enclosed pockets
  of the render's own pink haze and despills slivers. `--cut-bottom` (the Queue
  only) reports the bottom edge's near-black without grading it. Plates are not
  keyed: `--plate` checks the 1536×1024 canvas.
- **Review aids.** These were measured outside the tool and are not committed.
  Silhouette IoU is the overlap with the reference at alpha ≥ 128. Warm edge is
  the share of amber pixels (hue 20–50°, saturation ≥ 0.45, value ≥ 0.35) in
  the silhouette's outer 12 px, split at the bounding box's midline. Reference
  values: `keeper.png` 9.9% (weighted right), `eternalKeeper.png` 12.0%
  (weighted left), `hollow-lamplighter.png` 20.2% (both sides). Plate door
  positions are the column span of the glow, at 80% of its peak brightness or
  more, as a share of the width.
- **Contact sheets.** Every candidate of a family, keyed and over mid-grey,
  with the shipped reference first in each portrait row. A re-rolled file has
  one row per round. The plates carry the two-shot guides: cyan lines at 28%
  and 72% of the width and 70% of the height. Round 4 added a Codex row per
  file and rebuilt the sheets as dithered 256-colour PNGs (`--palette`) at 90%
  of these tile heights.

```bash
python3 tools/key_magenta.py RAW.png OUT.png --expect 682x1024                        # Keeper
python3 tools/key_magenta.py RAW.png OUT.png --expect 682x1024 --haze                 # Lamplighter
python3 tools/key_magenta.py RAW.png OUT.png --expect 1024x1024 --haze --cut-bottom   # Queue
python3 tools/key_magenta.py --plate RAW.png                                          # plates
python3 tools/key_magenta.py --contact-sheet contact-keeper.png --tile-height 400 \
    --row "keeper-tender  (#560)" REF.png A.png B.png C.png D.png \
    --tag keeper-tender-a="#1" --tag keeper-tender-b="REJECT: chest slab"   # one --row per file
```

How to read the tables: **Magenta** is leftover field-magenta (< 32). **Frame
dark** is opaque near-black in the 8 px canvas frame (< 400), with the
bottom-edge share in brackets; "not graded" marks the Queue's bottom edge.
**Corners** are the four corner alphas; 0 means all four are clear. **≥240** is
the share of visible pixels at alpha ≥ 240 (≥ 90%). **Verdict** in the
family tables below ranks each file's survivors across rounds 1 to 3, Grok
only. Round 4's tables and the contact sheets carry the ranking across both
tools, and that is the ranking to pick from. James picks.

## Round 2 — the authorised follow-up

The orchestrator authorised a follow-up on the owner's delegation: four more
candidates each for the four files round 1 left short. Each round-2 request is
the round-1 request with exactly one sentence appended. The canonical text is
otherwise unchanged, and the ledger's style blocks stay verbatim.

| File | Sentence appended, verbatim | Where |
|---|---|---|
| `lamplighter-wary` | "The amber rim light from outside the frame and the thin worn gold edging on the lead stay exactly as in the reference." | End of the POSE block. |
| `queue-chorus` | "All five figures, including the last and smallest, stay fully inside the left and right edges of the canvas." | End of the Queue paragraph. |
| `unlit-way`, `unlit-way-end` | "For this two-shot plate the subject (the road, the seat, the broken paving, the last lamp post and the distant arch) sits inside the central 44 percent of the width; the outer 28 percent on each side holds only ground, ash and sky." | After the TWO-SHOT FRAME clause. |

**The placement sentence is an implementation amendment to the ledger prompt
for two-shot plates.** It now stands for `unlit-way-end` only; Round 3 gave
`unlit-way` its own. At landing, each plate's ledger row should carry the
sentence that rendered the pick, because #559 asks that the Shipped row record
the prompt that rendered it. The same applies to the wary sentence if a round-2
wary file is picked.

The Queue brief cuts the figures at the canvas foot, so the bottom edge's
near-black is reported but not graded for this file (`--cut-bottom`). The other
three edges and the corners are still graded, and that is how the tool now
fails the renders that run off a side edge.

Round 2: 16 renders, 6 survivors (`wary-e`, `wary-f`, `queue-chorus-g`,
`queue-chorus-h`, `unlit-way-end-f`, `unlit-way-end-g`).

## Round 3 — `unlit-way`'s own placement sentence

The last round, authorised the same way: four more `unlit-way` renders (`i` to
`l`). For this plate only, the round-2 sentence was replaced by:

> For this two-shot plate the subject sits inside the central 44 percent of the
> width: the stone road receding into plain darkness, the row of dead iron lamp
> posts along its verge, and one flat roadside stone composed as an empty seat
> at about 55 to 60 percent of the width. The outer 28 percent on each side
> holds only ground, ash and sky. There is NO arch, NO door, NO light and NO
> dawn on the horizon: the road runs out into darkness.

**The two plates now carry different placement sentences, on purpose.** The
round-2 sentence named "the distant arch" as part of the subject, and all four
round-2 `unlit-way` renders drew one. That arch is the door, and the door must
not appear before m5. Meetings m1 to m4 stand on `unlit-way`; only m5 reaches
the end of the road. So the first plate's sentence forbids the arch outright
and places the seat, while `unlit-way-end` keeps the round-2 sentence and its
arch. Each plate's ledger row should carry its own sentence at landing.

Round 3: 4 renders, 1 survivor (`i`). None drew an arch, a door or light on the
horizon. `j` and `k` still stood a lamp post behind the Lamplighter's seat. The
seat landed at 35–72% of the width across the four, and on its 55–60% mark
only in `k`.

## Round 4: Codex

On 2026-09-29 James judged Codex's image generation better than Grok Build's. It
draws on a transparent background itself and holds a reference consistently. He
asked for every Grok file to be redone with Codex at round 1's counts: four per
portrait file, five for the Queue and four per plate, with at most 50 renders.
The brief, the gate and the rejection rules stay the same, and each file gets
one ranking across both tools.

- **Generation.** `~/.claude/scripts/subagents/run-imagegen.sh` runs Codex CLI
  0.159.0 with `gpt-5.6-terra` at low reasoning effort; the wrapper picks the
  newest Terra at run time. Codex draws with its built-in image generation. It
  made one image per call, three calls at a time, each call in an empty working
  directory of its own. There were 49 calls, taking 62–226 s each (median 89 s).
  Codex served every one, and none printed `FALLBACK:`. Every call returned the
  briefed canvas and mode on the first attempt (RGBA portraits, RGB plates), so
  no retry was spent. Codex scaled the portraits (generated at about 1024×1536)
  and the Queue (1254 px square) to the briefed canvas itself. The plates came
  back at 1536×1024.
- **Requests.** Each file's latest request from rounds 1 to 3, verbatim, with
  one change for the portraits. The two magenta sentences of the background
  paragraph, "BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field, edge to edge, no
  vignette, no floor, no shadow. Black exists ONLY inside the hood void.",
  became "Output a PNG with a TRANSPARENT background (alpha 0 outside the
  figure); no magenta, no floor, no shadow, no vignette. Black exists ONLY
  inside the hood void."
  - The Lamplighter's keeps his canonical "head void", because he wears no hood.
    The Queue's reads "figures" and "hood voids".
  - The rest of that paragraph ("EDIT THE ATTACHED REFERENCE: …") is unchanged,
    and the plates stay full-bleed.
  - "Latest" means `lamplighter-wary` and `queue-chorus` carry their round-2
    sentences, `unlit-way-end` carries round 2's placement sentence and
    `unlit-way` carries round 3's. The other files send round 1's requests.
  - The reference paths point at this worktree's copies of the same files.
- **No keying.** `tools/key_magenta.py --no-key` is new in this round. It writes
  the render's own alpha as RGBA, runs `sips -Z 1024` and grades the written
  file on three rows: the frame, the corners and the solid share. A fourth row
  fails a render with no alpha channel. With no keyed field there is nothing
  left over to grade, so the tool reports the field-magenta count instead of
  grading it. On these renders that count measures glass (Finding 3).
  `--cut-bottom` still covers the Queue's bottom edge.
- **Codex's own post-processing.** The logs show two renders where Codex went
  beyond scaling:
  - For `keeper-tender-c3` it pasted keeper.png's alpha over its render.
  - For `lamplighter-recognising-c2` it thresholded its render's alpha to a
    1-bit mask to remove an amber haze.

  The other 39 transparent renders carry the generator's own alpha.
- **Review aids.** As before, measured at alpha ≥ 128, plus the figure's mean
  saturation and value (S and V, 0–100). These show the palette step a mood
  makes on a cut. keeper.png reads S 60, V 18; eternalKeeper.png S 62, V 27;
  hollow-lamplighter.png S 59, V 22. The warm edge, re-measured the same way,
  reads 9.5%, 11.5% and 19.8% on those three references, within half a point of
  round 1's figures.
- **Ranking.** Each file is ranked once across both tools. The order weighs
  three things, in turn:
  1. The pose change as it reads in the bust crop the stage cuts, since that is
     what a mood portrait adds over the shipped figure.
  2. Continuity on the cut from the neighbouring mood: palette, rim side and
     strength, the side the prop is on, and framing.
  3. The rest of the brief and the finish.

  For the plates, anything load-bearing in the right band rejects, as in rounds
  1 to 3. A lamp post in the left band, behind the hero, is a caveat, as it was
  for `unlit-way-c`. It ranks a plate below every plate with both bands clear.
- **What is committed.** The 25 MB cap cannot hold all 42 Codex survivors: Codex
  kept 42 of 49 where Grok's rounds kept 31 of 69. So the Codex survivors ranked
  #1 or #2 in their file are committed as `survivors/<file-stem>-c<n>.png`: 16
  portraits and 4 plates, 19.1 MB. The others keep their rank on the contact
  sheets and in the tables below, marked "sheet only". Their full-size files
  stayed in the session's scratch directory and are not in the tree.
- **Contact sheets.** Each file gains one labelled Codex row below its Grok
  rows, rejects included. The tags now show the cross-round ranking. "#3 (was
  #1)" marks a Grok survivor whose rank changed. To fit the cap, the sheets are
  now dithered 256-colour PNGs (`--palette`) at 90% of round 1's tile heights:
  5.0 MB for all four, against 15.9 MB in full colour.

```bash
python3 tools/key_magenta.py --no-key RAW.png OUT.png --expect 682x1024                # Keeper, Lamplighter
python3 tools/key_magenta.py --no-key RAW.png OUT.png --expect 1024x1024 --cut-bottom  # Queue
python3 tools/key_magenta.py --plate RAW.png                                           # plates
python3 tools/key_magenta.py --contact-sheet contact-keeper.png --tile-height 360 --palette \
    --row "keeper-tender  Codex round 4, transparent  (#560)" REF.png C1.png C2.png C3.png C4.png \
    --tag keeper-tender-c2="#1"   # one --row per round and file; --guides for the plates
```

### Cross-round ranking

One line per file gives the ranking across both tools, best first (Grok by
letter, Codex by `c<n>`), and whether Codex beat Grok. Every candidate before
this round came from Grok.

| File | Ranking | Codex beat Grok? |
|---|---|---|
| `keeper-tender` | c2, c4, a, c1, c | Yes. c2 and c4 tilt the hood visibly where Grok's a barely moves it. The cost is brighter glass on the default-to-tender cut (V 24 against keeper.png's 18). |
| `keeper-offering` | c3, b, a, c2, c1, c4 | Yes. c3 holds a glass ember forward at chest height, the brief's reading. Grok's b is a speck at bust size, and a holds fire. |
| `keeper-weary` | c2, c3, c4, c1, c, b, a, d | Yes, on the pose: every Codex render bows the hood 55–95 px where Grok's barely bow. None dims the rim or the glass as briefed; Grok's did. |
| `keeper-beckon` | c4, c1, a, d, c2, c, c3 | Yes. c4 and c1 open the palm further toward the empty seat and keep eternalKeeper's violet and left rim. c2 and c3 run pinker. |
| `lamplighter-wary` | c4, c1, c2, e, c3, d, f | Yes. c4 and c1 draw the pole across the body in the reference's palette and rim. Grok's e has the better lean, but darker glass (S 44 against 59) and a black lantern. |
| `lamplighter-asking` | c1, c4, c2, c3, a, c, b | Yes. Codex sharpens the shipped pose (hand forward and low, IoU 0.78–0.82). Grok's three reproduce it (IoU 0.98–0.99). |
| `lamplighter-recognising` | b, c4, c3, c1, d, c2, a | No. All four Codex renders move the pole to his other hand, so it changes sides on every cut to and from his other moods. Grok's b keeps it on its usual side and stays first. |
| `lamplighter-urgent` | c1, c3, c2, c, c4, a | Yes. c1 is the brief exactly (one hand grips, the other reaches), and c3 carries the most tension. Both keep the reference's palette, which Grok's c darkened. |
| `lamplighter-grieving` | c3, c4, c2, c1, b, a | Yes. Deeper bows in the reference's palette and rim; Grok's b is darker (S 48). |
| `queue-chorus` | h, g, e | No. All five Codex renders fail the gate. Four run the line into the right edge despite the inside-edges sentence, and the fifth fails on one corner pixel. Their glass is royal blue rather than slate. |
| `unlit-way` | c3, c4, i, c1, c, c2 | Yes. c3 is the first of 16 renders to keep both bands clear with the seat on its mark, and c4 keeps both bands clear too. |
| `unlit-way-end` | c1, c4, g, c3, f | Yes. In c1 the ground falls away into mist toward a small, far door at about 62% of the width; Grok's g stands on a flat plain. |

### The gate

44 of 49 renders pass. All 36 Keeper and Lamplighter renders and all 8 plates
pass. The five Queue renders fail. c1 and c3 fail on dark frame and c2 on a
corner, all three where the line runs into the right edge. c4 and c5 fail on
one bottom-left corner pixel at alpha 1, and c4's last figure also touches the
right edge. In the portrait tables below, **Magenta** is the
field-magenta count the tool reports without grading. **Verdict** is the
cross-round rank: bold for a committed file, "sheet only" for a survivor that is
ranked but not committed.

#### Codex renders: Keeper (#560)

| File | Size | Magenta | Frame dark (bottom edge) | Corners | ≥240 | Gate | Verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| `keeper-tender-c1.png` | 682×1024 | 6 | 3 (0) | 0 | 98.3% | pass | #4, sheet only | The hood turns and tilts toward the viewer's left, the hands stay folded, the rim stays on the right (L:R 0.78). The brightest of the four: the glass reads V 29 against keeper.png's 18, a visible step on the default-to-tender cut in opening b1. IoU 0.981. |
| [`keeper-tender-c2.png`](survivors/keeper-tender-c2.png) | 682×1024 | 3 | 14 (0) | 0 | 98.1% | pass | **#1** | The hood tilts toward the viewer's left and dips forward, the clearest tender tilt of both rounds at bust size; hands folded, rim on the right (L:R 0.78). The glass is brighter than keeper.png (V 24 against 18). The brief's 'a touch warmer' allows some of that, but it shows on the cut from default. IoU 0.940. |
| `keeper-tender-c3.png` | 682×1024 | 0 | 0 (0) | 0 | 98.6% | pass | reject | Not the render's own alpha. Codex judged its render's background a dark halo and pasted keeper.png's alpha over it, so the outline is the reference's by construction (IoU 1.000). The tilted hood sits inside the old outline, leaving a thick dark band on the hood's right and speckle along the hem. |
| [`keeper-tender-c4.png`](survivors/keeper-tender-c4.png) | 682×1024 | 0 | 132 (0) | 0 | 98.2% | pass | **#2** | As c2 with the hood a little more upright; rim on the right (L:R 0.66), glass V 24. IoU 0.957. |
| `keeper-offering-c1.png` | 682×1024 | 3 | 14 (0) | 0 | 98.0% | pass | #5, sheet only | The right hand is raised to shoulder height by the hood, palm up, holding a faceted ember of amber glass; the other hand stays in the lap. The ember is glass as briefed, but the hand sits above chest height and close to the body, so the offer reads small. Glass V 24 against 18. |
| `keeper-offering-c2.png` | 682×1024 | 1 | 66 (0) | 0 | 97.5% | pass | #4, sheet only | Palm up at chest height with a glowing amber ember; the other hand in the lap. The hand stays tucked against the robe, so the offer reads smaller than c3's. V 24. |
| [`keeper-offering-c3.png`](survivors/keeper-offering-c3.png) | 682×1024 | 2 | 51 (0) | 0 | 97.6% | pass | **#1** | The right hand held forward at chest height, palm up, cupping a round ember of amber glass, the brightest point on the figure; the other hand in the lap. The clearest offer of both rounds at bust size. Glass V 24 against keeper.png's 18: a step on the offering-to-default cut in opening b1. |
| `keeper-offering-c4.png` | 682×1024 | 0 | 21 (0) | 0 | 97.9% | pass | #6, sheet only | As c1: the hand raised by the hood with a faceted ember. The most saturated glass of the four (S 70 against 60). |
| `keeper-weary-c1.png` | 682×1024 | 2 | 88 (0) | 0 | 98.1% | pass | #4, sheet only | The hood bows forward (its top 55 px lower), the shoulders sink, the hands rest loose. The rim is not dimmed (warm edge 12.0% against keeper.png's 9.5%) and the glass keeps its brightness (V 20). |
| [`keeper-weary-c2.png`](survivors/keeper-weary-c2.png) | 682×1024 | 0 | 151 (0) | 0 | 98.1% | pass | **#1** | The deepest bow of both rounds: the hood drops 95 px toward the lap, the shoulders sink, the hands rest loose, and it reads weary at once in the bust crop. But the rim is not dimmed (14.8%) and the glass is not darker (V 20). The brief asks for both and Grok's renders delivered them (V 16, rim about 7%). With the real art landed, the stage no longer grades the mood down. |
| [`keeper-weary-c3.png`](survivors/keeper-weary-c3.png) | 682×1024 | 0 | 0 (0) | 0 | 97.7% | pass | **#2** | A clear bow (hood 84 px lower), hands loose, and the faintest rim of the four (9.9%, the reference's level); glass at keeper.png's brightness (V 18). |
| `keeper-weary-c4.png` | 682×1024 | 0 | 97 (0) | 0 | 98.2% | pass | #3, sheet only | As c2 with a smaller bow (66 px); rim 14.7%, V 19. |
| [`keeper-beckon-c1.png`](survivors/keeper-beckon-c1.png) | 682×1024 | 14 | 56 (0) | 0 | 98.2% | pass | **#2** | One hand lifted from the lap, palm up and open, reaching toward the empty space on his left; the other stays in the lap. eternalKeeper's violet and teal are kept (S 65, V 30 against 62, 27), with the amber from the left (L:R 2.70). IoU 0.921. |
| `keeper-beckon-c2.png` | 682×1024 | 105 | 65 (0) | 0 | 97.9% | pass | #5, sheet only | The gesture of c1, but the violet chest and lap panes run hotter: 105 px pass the field-magenta test, against 1 px on eternalKeeper.png. That is a pink flash on the revealed-to-beckon cut. Amber from the left (L:R 1.98). |
| `keeper-beckon-c3.png` | 682×1024 | 339 | 0 (0) | 0 | 98.0% | pass | #7, sheet only | The hand is raised higher, to shoulder height, palm up and open. The pinkest of the four: 339 px pass the field-magenta test, a hot-pink chest pane on the revealed-to-beckon cut (S 71, V 33). |
| [`keeper-beckon-c4.png`](survivors/keeper-beckon-c4.png) | 682×1024 | 22 | 65 (0) | 0 | 97.5% | pass | **#1** | The clearest invitation of both rounds: the forearm reaches toward the empty space on his left, palm up and open, with the other hand in the lap. Continuous with eternalKeeper on the revealed-to-beckon cut: S 68 and V 30 against 62 and 27, and amber from the left at L:R 3.69 against the reference's 4.01. IoU 0.949. |

#### Codex renders: Hollow Lamplighter (#561)

| File | Size | Magenta | Frame dark (bottom edge) | Corners | ≥240 | Gate | Verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| [`lamplighter-wary-c1.png`](survivors/lamplighter-wary-c1.png) | 682×1024 | 0 | 4 (0) | 0 | 95.7% | pass | **#2** | The pole drawn diagonally across the body from the left foot to the right shoulder and gripped at the chest; the lantern stays dark on its usual side; the empty hand lowered and closed. Rim and gold edging kept (21.0%), palette as the reference (S 60, V 25). He stands upright rather than leaning back. |
| `lamplighter-wary-c2.png` | 682×1024 | 3 | 0 (0) | 0 | 94.6% | pass | #3, sheet only | The pole crosses the body the other way, and the lantern hangs on the viewer's left, as in Grok's wary-e. The empty hand is lowered and closed; rim kept (23.9%). The lantern changes sides against the shipped figure and the other moods' picks. |
| `lamplighter-wary-c3.png` | 682×1024 | 3 | 0 (0) | 0 | 95.1% | pass | #5, sheet only | The pole held almost upright in front of the body rather than across it; the hand lowered and closed; rim kept (22.0%). |
| [`lamplighter-wary-c4.png`](survivors/lamplighter-wary-c4.png) | 682×1024 | 0 | 8 (0) | 0 | 95.3% | pass | **#1** | The pole drawn across the body from the left foot to the right shoulder, the weight a little back, the empty hand lowered and closed, the lantern dark on its usual side. Strong rim and gold edging (26.7%). The palette matches the reference (S 62, V 24), so the cut to and from recognising keeps its material. |
| [`lamplighter-asking-c1.png`](survivors/lamplighter-asking-c1.png) | 682×1024 | 2 | 2 (0) | 0 | 93.8% | pass | **#1** | The shipped pose sharpened as briefed: the open hand comes forward and low, palm up and cupped, and the pole stands upright at his side. Palette and rim as the reference (S 61, V 24; warm 20.9%). IoU 0.802, because the hand moved in from the side: that is the change. |
| `lamplighter-asking-c2.png` | 682×1024 | 7 | 0 (0) | 0 | 94.2% | pass | #3, sheet only | As c1 with the palm a little higher, at the waist. |
| `lamplighter-asking-c3.png` | 682×1024 | 0 | 56 (0) | 0 | 94.7% | pass | #4, sheet only | As c1, but the pole loses its crook: the lantern hangs from a straight pole with a small hook. |
| [`lamplighter-asking-c4.png`](survivors/lamplighter-asking-c4.png) | 682×1024 | 4 | 28 (0) | 0 | 93.9% | pass | **#2** | As c1 with the hand a little further out to the side, nearer the shipped pose. |
| `lamplighter-recognising-c1.png` | 682×1024 | 2 | 7 (0) | 0 | 93.9% | pass | #4, sheet only | Leans toward the viewer's left, head tilted, with the dark lantern raised to head height beside it. The pole moves to his other hand. So on every cut from wary, asking, urgent or grieving it changes sides, since all of those hold it on the viewer's right, bar wary-c2 and Grok's wary-e. The free hand opens outward to the right, palm up, which also reads as asking. |
| `lamplighter-recognising-c2.png` | 682×1024 | 0 | 0 (0) | 0 | 100.0% | pass | #6, sheet only | As c1, with a hard 1-bit edge. Codex thresholded its render's alpha to remove an amber haze its generator had added, so the silhouette has no anti-aliasing. |
| `lamplighter-recognising-c3.png` | 682×1024 | 2 | 12 (0) | 0 | 94.2% | pass | #3, sheet only | As c1 with the lantern raised a little higher beside the head. |
| [`lamplighter-recognising-c4.png`](survivors/lamplighter-recognising-c4.png) | 682×1024 | 1 | 1 (0) | 0 | 94.5% | pass | **#2** | The strongest lean and tilt of the four, with the lantern raised high beside the head, toward the face he studies. It has the same side change as c1. |
| [`lamplighter-urgent-c1.png`](survivors/lamplighter-urgent-c1.png) | 682×1024 | 2 | 0 (0) | 0 | 94.6% | pass | **#1** | One hand grips the pole hard while the other comes forward, fingers spread, toward the viewer's left; the body is pitched in and the hem swings. The brief's reading exactly, and it reads in the bust crop. Palette and rim as the reference (S 62, V 23; warm 20.4%). |
| `lamplighter-urgent-c2.png` | 682×1024 | 0 | 2 (0) | 0 | 95.0% | pass | #3, sheet only | Both hands grip the pole at chest height; the body leans in, the hem swung left. |
| [`lamplighter-urgent-c3.png`](survivors/lamplighter-urgent-c3.png) | 682×1024 | 4 | 3 (1) | 0 | 94.9% | pass | **#2** | Hunched and pitched in with both hands on the pole and the hem swung wide: the most tension of the four. |
| `lamplighter-urgent-c4.png` | 682×1024 | 1 | 117 (0) | 0 | 95.1% | pass | #5, sheet only | Both hands on the pole, with a smaller lean and swing. |
| `lamplighter-grieving-c1.png` | 682×1024 | 5 | 6 (6) | 0 | 95.0% | pass | #4, sheet only | Head bowed low, the free hand flat on the chest, and the lantern lowered to hang by his feet from the pole's crook: the pole is held upside down, crook at the foot. This pole also grows a second hook at the top. Palette and rim as the reference (S 61, V 25; warm 22.9%). |
| `lamplighter-grieving-c2.png` | 682×1024 | 1 | 13 (13) | 0 | 94.9% | pass | #3, sheet only | As c1 without the second hook, with a slightly smaller bow. |
| [`lamplighter-grieving-c3.png`](survivors/lamplighter-grieving-c3.png) | 682×1024 | 2 | 2 (2) | 0 | 95.2% | pass | **#1** | The deepest bow, the hand pressed flat to the chest, the dark lantern hanging by his feet from the inverted pole. It reads as grief at once in the bust crop, and palette and rim match the reference (S 60, V 25; warm 20.0%). |
| [`lamplighter-grieving-c4.png`](survivors/lamplighter-grieving-c4.png) | 682×1024 | 2 | 9 (9) | 0 | 95.9% | pass | **#2** | As c3 with the neck a little further forward. |

#### Codex renders: Queue chorus (#562)

| File | Size | Magenta | Frame dark (bottom edge) | Corners | ≥240 | Gate | Verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| `queue-chorus-c1.png` | 1024×1024 | 11 | 678 (0, not graded) | 0 | 97.7% | **fail** | reject | Gate fail: 678 px of dark frame. The last figure is cut by the right edge (494 opaque px in its 8 px band). One receding line of five with amber breast lights, but full length rather than cut at mid-thigh, and saturated royal blue rather than slate. |
| `queue-chorus-c2.png` | 1024×1024 | 0 | 1544 (1365, not graded) | [0, 0, 0, 252] | 98.0% | **fail** | reject | Gate fail: the bottom-right corner is at alpha 252, because the line runs into the right edge. The only Codex Queue cut at the canvas foot as briefed; royal blue rather than slate. |
| `queue-chorus-c3.png` | 1024×1024 | 9 | 1303 (0, not graded) | 0 | 97.7% | **fail** | reject | Gate fail: 1,303 px of dark frame, where the last figure runs into the right edge. Full length; royal blue. |
| `queue-chorus-c4.png` | 1024×1024 | 8 | 146 (14, not graded) | [0, 0, 1, 0] | 97.7% | **fail** | reject | Gate fail: the bottom-left corner is at alpha 1. The last figure is also cut by the right edge (516 opaque px in its 8 px band), and the figures are full length and royal blue. |
| `queue-chorus-c5.png` | 1024×1024 | 16 | 171 (1, not graded) | [0, 0, 1, 0] | 97.5% | **fail** | reject | Gate fail on one reading only: a bottom-left corner pixel at alpha 1, invisible on screen. The last figure stops 3 px short of the right edge. It adds violet glass the brief does not name, and the figures are full length rather than cut at mid-thigh. |

#### Codex renders: Unlit Way plates (#563)

Door positions on the end plate are the brightest compact spot above the pane
line, as a share of the width: `c1` 62%, `c2` 61–64%, `c3` 63–64%, `c4` 69%.

| File | Size | Canvas | Verdict | Notes |
|---|---|---|---|---|
| `unlit-way-c1.png` | 1536×1024 | pass | #4, sheet only | The road runs into plain darkness at about 46%, with a row of dead posts on its left verge, no arch, door or light on the horizon, and amber from low left. But the nearest post stands at 24-28% of the width, at the left band's edge behind the hero, and the seat spans 56-72%, wider than its 55-60% mark. Dark (mean luminance 14.6). |
| `unlit-way-c2.png` | 1536×1024 | pass | #6, sheet only | As c1, but the nearest post, the tallest thing in the frame, stands inside the left band (17-25%) behind the hero's bust, and the seat spans 58-72%. The clouds are flat stylised panes. |
| [`unlit-way-c3.png`](survivors/unlit-way-c3.png) | 1536×1024 | pass | **#1** | The first render of 16 to keep both bands clear with the seat on its mark. The dead posts stand on the road's left verge at 33-46% and the flat stone seat at 57-63%. Both outer bands hold only ground, ash and the low-left amber glow. The road runs out into plain darkness (no arch, door or dawn), the bottom 30% is dark ground, and the sky is broken into glass-like shards. Mean luminance 12.2. |
| [`unlit-way-c4.png`](survivors/unlit-way-c4.png) | 1536×1024 | pass | **#2** | Both bands clear: small dead posts line both verges inside the centre band, the seat spans 56-70%, and the road runs into darkness. The whole sky is drawn as leaded glass panes, the boldest stained-glass reading of both rounds. The raking amber lights the paving in the bottom-left corner, under the pane. |
| [`unlit-way-end-c1.png`](survivors/unlit-way-end-c1.png) | 1536×1024 | pass | **#1** | The last dead lamp leans at the end of the broken paving at the centre. Beyond it the ground falls away into a misty valley toward a small, far arch of light at about 62% of the width. Cold, empty and painterly, with dark paving in the bottom 30%. The one caveat: low ruined towers stand on the horizon in both bands, small and distant. |
| `unlit-way-end-c2.png` | 1536×1024 | pass | reject | Arched ruins, an aqueduct and a castle, stand in both bands; the right one, behind the Lamplighter's seat, echoes the door. A stone bench from the first plate bled in at 30-44%, and the lit paving fills the bottom 30%. |
| `unlit-way-end-c3.png` | 1536×1024 | pass | #4, sheet only | The dead lamp stands at the centre on a broken ledge, the door is a far arch at about 63%, and the ground falls into misty chasms. But the plate is warm and dramatic rather than emptier and colder: an amber shaft of light fills the upper right band, crags fill both bands, and lit paving runs into the bottom 30%. |
| [`unlit-way-end-c4.png`](survivors/unlit-way-end-c4.png) | 1536×1024 | pass | **#2** | Cold and empty: the dead lamp stands on the broken slabs at about 56%, with mist beyond and the door a small far arch at about 69%, near the right band's edge. The bottom 30% is dark and quiet. Low ruins sit in both bands, and an amber shaft comes from the left. |

### Round 4 findings

1. **Transparency straight from the generator works for single figures.** All 36
   Keeper and Lamplighter renders passed the gate unkeyed, 34 of them on the
   generator's own alpha, with no halo, fringe or leftover field. Their interior
   alpha sits at 251–253, not 255. The shipped `hollow-lamplighter.png` does the
   same, and it does not show.
2. **The gate cannot see a borrowed alpha; the logs can.** `keeper-tender-c3`
   carries keeper.png's alpha and `lamplighter-recognising-c2` a 1-bit edge, and
   both pass the gate. Only the call logs give them away, or an IoU of exactly
   1.000 and an alpha channel with two values. Read the log of any Codex pick
   before landing it.
3. **Field-magenta means nothing without a key.** On eternalKeeper's violet it
   counts the glass's own hot highlights: 105 px on `keeper-beckon-c2` and 339
   on `c3`, against 1 on the reference. So `--no-key` reports it without grading
   it. The count still flags the pinker palette, which is how c2 and c3 lost
   rank.
4. **Codex brightens the Keeper and holds the Lamplighter.** Its tender and
   offering glass reads V 24–29 against keeper.png's 18, and its beckon V 30–33
   against eternalKeeper's 27. That is a step on every cut from the shipped
   figure. Its Lamplighter matches the reference more closely than Grok's did: S
   59–65 and V 23–25 against 59 and 22, where Grok's ran S 35–58 and V 17–21.
5. **Codex moves the pose more and the light less.** The weary bow, the asking
   hand and the beckon palm are all clearer. But no weary render dims "the rim
   low and faint, the glass a little dimmer". All four recognising renders swap
   the pole to the other hand, which the brief did not ask for.
6. **The Queue fails for Codex on a side edge, as it did for Grok.** Codex fills
   the square with bigger figures and runs the tail into the right edge in four
   of five, despite the inside-edges sentence. Only one of the five cuts the
   figures at the canvas foot. Grok's h stays the pick.
7. **Codex follows the plates' placement sentences.** None of the four
   `unlit-way` renders drew an arch, and two kept both bands clear, against one
   of Grok's twelve. All four end plates put the door at 61–69% of the width.
   Grok's round 2, with the same sentence, ranged 61–85%.
8. **No rate limit.** The 49 calls ran over 27 minutes, three at a time, and
   none fell back to Cursor.

## Keeper — #560

Round 1 only. Tender, offering and weary edit `meta/keeper.png`; beckon edits
`enemies/eternalKeeper.png`. Eleven of 16 survive; every file has at least two.

| File | Size | Magenta | Frame dark (bottom edge) | Corners | ≥240 | Gate | Verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| [`keeper-tender-a.png`](survivors/keeper-tender-a.png) | 682×1024 | 0 | 0 (0) | 0 | 98.4% | pass | **#1** | Hood tilts toward the viewer's left, hands stay folded, rim on the right. Framing within 2 px of the reference (IoU 0.972). |
| `keeper-tender-b.png` | 682×1024 | 0 | 0 (0) | 0 | 98.9% | pass | reject | A flat glowing teal slab replaces the chest panes: a painted fill, not leaded glass. |
| [`keeper-tender-c.png`](survivors/keeper-tender-c.png) | 682×1024 | 0 | 0 (0) | 0 | 98.9% | pass | **#2** | The subtlest tilt of the four (IoU 0.992 against the reference): safe, but the mood barely moves. |
| `keeper-tender-d.png` | 682×1024 | 0 | 5 (0) | 0 | 98.6% | pass | reject | Amber glow painted beyond the silhouette onto the field; it keys to a pink halo down the right edge. |
| [`keeper-offering-a.png`](survivors/keeper-offering-a.png) | 682×1024 | 0 | 0 (0) | 0 | 98.9% | pass | **#2** | Palm up at chest height holding a small painted flame. Reads at once at bust size, but it is fire, not the brief's ember of amber glass. |
| [`keeper-offering-b.png`](survivors/keeper-offering-b.png) | 682×1024 | 0 | 0 (0) | 0 | 99.0% | pass | **#1** | Palm up at chest height cupping a small ember of amber glass, the brief's reading. The ember is small at bust size. |
| `keeper-offering-c.png` | 682×1024 | 0 | 4 (0) | 0 | 99.0% | pass | reject | The ember's glow, painted onto the field, keys to a red halo disc, and the amber rim is gone (warm edge 0.8% against the reference's 9.9%). |
| `keeper-offering-d.png` | 682×1024 | 0 | 0 (0) | 0 | 98.6% | pass | reject | A pink glow disc about 90 px across round the flame survives keying. |
| [`keeper-weary-a.png`](survivors/keeper-weary-a.png) | 682×1024 | 0 | 0 (0) | 0 | 98.7% | pass | **#3** | Hands loose and apart on the knees, rim dimmed; the hood barely bows. |
| [`keeper-weary-b.png`](survivors/keeper-weary-b.png) | 682×1024 | 0 | 0 (0) | 0 | 99.0% | pass | **#2** | As a, with the hood a little lower. |
| [`keeper-weary-c.png`](survivors/keeper-weary-c.png) | 682×1024 | 0 | 0 (0) | 0 | 98.4% | pass | **#1** | The clearest bow: hood low and forward, hands loose, rim dimmed as asked. |
| [`keeper-weary-d.png`](survivors/keeper-weary-d.png) | 682×1024 | 0 | 0 (0) | 0 | 99.6% | pass | **#4** | Both palms turned up on the knees. It reads as a gesture, close to the vocabulary of offering and beckon. |
| [`keeper-beckon-a.png`](survivors/keeper-beckon-a.png) | 682×1024 | 0 | 0 (0) | 0 | 98.9% | pass | **#1** | Keeps eternalKeeper's saturated violet, amber from the left, open palm turned to the empty space on his left. Continuous with the revealed-to-beckon cut in act4-node5. |
| `keeper-beckon-b.png` | 682×1024 | 0 | 0 (0) | 0 | 98.7% | pass | reject | Glass drifts to dusty grey-lavender. act4-node5 cuts from revealed (eternalKeeper itself) straight to beckon, so the figure would change colour on the cut. |
| [`keeper-beckon-c.png`](survivors/keeper-beckon-c.png) | 682×1024 | 9 | 0 (0) | 0 | 98.6% | pass | **#3** | Hood and shoulders go grey-blue: a visible palette step on the revealed-to-beckon cut. |
| [`keeper-beckon-d.png`](survivors/keeper-beckon-d.png) | 682×1024 | 0 | 0 (0) | 0 | 99.1% | pass | **#2** | As a, with a smaller gesture. |

<details><summary>Exact request: keeper-tender, and how the other three differ</summary>

```text
Read the reference image at <repo>/assets/art/meta/keeper.png and produce an edited variation of it.

Serious cartoon-gothic stained-glass game art: chunky dark outer silhouette, simplified exaggerated proportions, one iconic readable pose, 3-5 large jewel-tone glass colour masses with very few thick lead dividers, matte painterly texture, warm amber rim light, soft controlled inner glow. Designed to remain readable at 128px. No text, no labels, no watermark.

CONSTRUCTION, this is the most important instruction: the figure is not painted cloth. The entire robe, hood and body are built from large flat panes of coloured glass separated by thick black lead came lines, exactly like a cathedral stained-glass window rendered as a character. Each fold of the robe is a distinct glass pane with a hard lead border, not a soft painted fold. Only a few big panes, never lacework or many small pieces. The lead lines are heavy, black, and clearly visible across the whole figure. Glass is blue, violet, teal and deep red, lit from within by a faint cold glow, with thin worn gold edging on the lead. Readable as a solid black shape if all internal detail were removed.

BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field, edge to edge, no vignette, no floor, no shadow. Black exists ONLY inside the hood void. EDIT THE ATTACHED REFERENCE: keep the exact same canvas size, figure scale, position, bounding box, hem line, pane layout and palette; change ONLY the pose described below. Single complete figure, no cropped limbs. The hood opening is a deep black VOID with NO face, NO eyes, NO glowing points.

The Keeper — a seated hooded figure, knees drawn in, completely still and calm. Low wide hooded seated mass. Warm amber rim light falling on the figure from the RIGHT, from a fire outside the frame. The figure holds no lantern, staff or weapon. Do NOT draw a hearth, chair, floor, hall, fire, or any background object.

POSE CHANGE: the hood tilts slightly toward the viewer's left, as if toward someone seated near; the shoulders soften; the hands stay folded in the lap. The inner glow is a touch warmer. Stillness, fondness, fatigue.

Canvas: exactly 682x1024 pixels.

Save the result as a PNG file at <scratch>/stagecraft-raw/keeper-tender-<x>.png
```

- `keeper-offering` and `keeper-weary`: the same request with the POSE block
  replaced by #560's, verbatim.
- `keeper-beckon`: reads `<repo>/assets/art/enemies/eternalKeeper.png`. The
  Keeper paragraph drops "Warm amber rim light falling on the figure from the
  RIGHT, from a fire outside the frame.", and the last paragraph is #560's
  beckon block: "INVERTED hearth light: warm amber arrives from the LEFT, the
  wrong side, catching the lead edges; the rest of the glass is cold
  violet-grey and deep teal. POSE CHANGE: one hand is lifted from the lap, palm
  up and open, and turned toward the empty space beside the figure: an
  invitation to sit down. Gentle, not a command."

</details>

## Hollow Lamplighter — #561

Every file edits `meta/hollow-lamplighter.png`. Wary was re-rolled in round 2
(`e` to `h`). Thirteen of 24 survive, and every file has at least three.

| File | Size | Magenta | Frame dark (bottom edge) | Corners | ≥240 | Gate | Verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| `lamplighter-wary-a.png` | 682×1024 | 0 | 0 (0) | 0 | 98.3% | pass | reject | No amber rim and no gold edging (warm edge 0.0% against the reference's 20.2%). Wary cuts against recognising on consecutive lines in m1-pre and m3-pre, so the glass would change material. The pole also stays at his side. |
| `lamplighter-wary-b.png` | 682×1024 | 0 | 0 (0) | 0 | 98.4% | pass | reject | The best pose of the four (pole across the body, weight back), but no rim or gold edging, washed sage glass, and the head 71 px lower. |
| `lamplighter-wary-c.png` | 682×1024 | 0 | 0 (0) | 0 | 98.0% | pass | reject | The head is a solid black silhouette (the pale skull dome is gone), the robe breaks into many small shards, and there is no rim. |
| [`lamplighter-wary-d.png`](survivors/lamplighter-wary-d.png) | 682×1024 | 0 | 0 (0) | 0 | 97.6% | pass | **#2** | Pole drawn in across the body, empty hand lowered and closed, rim and gold edging intact, head where the reference has it. The lantern is larger, with pale cold panes: unlit, but brighter than the reference's. |
| [`lamplighter-wary-e.png`](survivors/lamplighter-wary-e.png) | 682×1024 | 0 | 0 (0) | 0 | 97.0% | pass | **#1** | Round 2. The pole is drawn across the body like a staff held between, the empty hand lowered and closed, the lantern dark. The rim and gold edging stay (warm edge 17.1%, against 0.0% for round 1's a to c), and the head is where the reference has it. |
| [`lamplighter-wary-f.png`](survivors/lamplighter-wary-f.png) | 682×1024 | 0 | 0 (0) | 0 | 98.1% | pass | **#3** | Round 2. The shipped pose with the empty hand lowered and closed into a fist; the pole stays at his side. Rim kept (17.0%). The smallest change of the survivors. |
| `lamplighter-wary-g.png` | 682×1024 | 0 | 0 (0) | 0 | 98.6% | pass | reject | Round 2. The raw render replaced the lantern with a flat grey slab crossed by lead lines: no iron frame and no glass, a fill rather than the lantern. The head also sits 33 px low. |
| `lamplighter-wary-h.png` | 682×1024 | 0 | 0 (0) | 0 | 98.6% | pass | reject | Round 2. The lantern is fixed on top of the pole instead of hanging from it, and the figure is 9% shorter (head 75 px lower). |
| [`lamplighter-asking-a.png`](survivors/lamplighter-asking-a.png) | 682×1024 | 0 | 0 (0) | 0 | 97.5% | pass | **#1** | The shipped pose with the palm-up hand forward and low, rim intact. Near-identical to the shipped figure (IoU 0.983). |
| [`lamplighter-asking-b.png`](survivors/lamplighter-asking-b.png) | 682×1024 | 0 | 0 (0) | 0 | 98.1% | pass | **#3** | As a, with darker glass and the darkest lantern: a small palette step from the reference. |
| [`lamplighter-asking-c.png`](survivors/lamplighter-asking-c.png) | 682×1024 | 0 | 0 (0) | 0 | 98.6% | pass | **#2** | Near-identical to a (IoU 0.990 against the reference). |
| `lamplighter-asking-d.png` | 682×1024 | 0 | 52 (17) | 0 | 97.5% | pass | reject | Re-scaled: the figure grows 4-8 px on every side (IoU 0.919) with no gain in pose. |
| [`lamplighter-recognising-a.png`](survivors/lamplighter-recognising-a.png) | 682×1024 | 0 | 0 (0) | 0 | 98.6% | pass | **#3** | Lantern raised overhead on a level pole, head bowed toward the left. Strong, but it reads more as brandishing, and the painted rim moves to his back (right about 3:1). |
| [`lamplighter-recognising-b.png`](survivors/lamplighter-recognising-b.png) | 682×1024 | 0 | 0 (0) | 0 | 98.2% | pass | **#1** | Head tilted left, lantern raised beside the head, empty hand forward; rim balanced like the reference's. |
| `lamplighter-recognising-c.png` | 682×1024 | 0 | 0 (0) | 0 | 97.4% | pass | reject | Pose not applied: the shipped figure again (IoU 0.980), which the stage already shows for this mood. |
| [`lamplighter-recognising-d.png`](survivors/lamplighter-recognising-d.png) | 682×1024 | 0 | 0 (0) | 0 | 96.2% | pass | **#2** | Leans left with the lantern raised by his head, toward the face he studies: the most literal reading. The painted rim moves to his back (right about 2.6:1). |
| [`lamplighter-urgent-a.png`](survivors/lamplighter-urgent-a.png) | 682×1024 | 0 | 0 (0) | 0 | 98.1% | pass | **#2** | Pitched in, one hand on the pole, the other at the belt rather than forward; the hem swing falls below the bust crop. |
| `lamplighter-urgent-b.png` | 682×1024 | 0 | 0 (0) | 0 | 97.2% | pass | reject | Head turned to the viewer's right, away from the partner the stage seats on his left. |
| [`lamplighter-urgent-c.png`](survivors/lamplighter-urgent-c.png) | 682×1024 | 0 | 0 (0) | 0 | 96.8% | pass | **#1** | Both hands grip the pole at chest height, body tense, hem swung wide, rim intact. Lantern panes pale and cold (unlit), and larger than the reference's. |
| `lamplighter-urgent-d.png` | 682×1024 | 0 | 0 (0) | 0 | 96.7% | pass | reject | No rim or gold edging (warm edge 0.0%); the glass goes flat grey-teal. |
| [`lamplighter-grieving-a.png`](survivors/lamplighter-grieving-a.png) | 682×1024 | 0 | 0 (0) | 0 | 98.2% | pass | **#2** | Head bowed, hand on the chest, lantern hung low by the feet from an inverted pole. The rim is much weaker than the reference's (5.5% against 20.2%). |
| [`lamplighter-grieving-b.png`](survivors/lamplighter-grieving-b.png) | 682×1024 | 0 | 0 (0) | 0 | 98.1% | pass | **#1** | Head bowed, hand flat on the chest, lantern set on the ground at his feet with the pole upright, rim intact. The lantern falls outside the bust crop, as the brief implies. |
| `lamplighter-grieving-c.png` | 682×1024 | 0 | 0 (0) | 0 | 98.8% | pass | reject | Head turned to the viewer's right, away from his partner, and no rim (0.3%). |
| `lamplighter-grieving-d.png` | 682×1024 | 0 | 0 (0) | 0 | 98.3% | pass | reject | A skull face is drawn: eye sockets, nose and teeth. |

<details><summary>Exact request: lamplighter-wary (round 1), and how the rest differ</summary>

```text
Read the reference image at <repo>/assets/art/meta/hollow-lamplighter.png and produce an edited variation of it.

Serious cartoon-gothic stained-glass game art: chunky dark outer silhouette, simplified exaggerated proportions, one iconic readable pose, 3-5 large jewel-tone glass colour masses with very few thick lead dividers, matte painterly texture, warm amber rim light, soft controlled inner glow. Designed to remain readable at 128px. No text, no labels, no watermark.

CONSTRUCTION, this is the most important instruction: the figure is not painted cloth. His entire robe and body are built from large flat panes of coloured glass separated by thick black lead came lines, exactly like a cathedral stained-glass window rendered as a character. Each fold of the robe is a distinct glass pane with a hard lead border, not a soft painted fold. Only a few big panes, never lacework or many small pieces. The lead lines are heavy, black, and clearly visible across the whole figure. Glass is cold grey-green and deep teal, lit from within by a faint cold glow, with thin worn gold edging on the lead. Readable as a solid black shape if all internal detail were removed.

BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field, edge to edge, no vignette, no floor, no shadow. Black exists ONLY inside the head void. EDIT THE ATTACHED REFERENCE: keep the exact same canvas size, figure scale, position, bounding box, hem line, pane layout and palette; change ONLY the pose described below. Single complete figure, no cropped limbs.

The Hollow Lamplighter, a gaunt keeper, tall and skull-thin, in a long floor-length robe. Bare head, no raised hood, face a deep black void with no glowing eyes. The one warm colour in the frame is an amber rim light falling on him from outside the frame, from a fire he is not carrying. He holds a tall iron lantern pole; the lantern hanging from it is DARK AND EMPTY, with cold dead glass panes and no flame inside, the single unlit object in the frame, in every pose.

POSE CHANGE: he leans back a little, weight on the rear foot; the lantern pole is drawn in close across his body like a staff held between; the empty hand is lowered and closed.

Canvas: exactly 682x1024 pixels.

Save the result as a PNG file at <scratch>/stagecraft-raw/lamplighter-wary-<x>.png
```

- The other four files send the same request with the POSE block replaced by
  #561's, verbatim (asking, recognising, urgent, grieving).
- Round 2 (`wary-e` to `wary-h`) appends the rim sentence in Round 2 to the
  POSE block.

</details>

## Queue chorus — #562

A new figure group, so there is no edit reference and no framing to keep.
Re-rolled in round 2 (`f` to `i`). Three of nine survive.

| File | Size | Magenta | Frame dark (bottom edge) | Corners | ≥240 | Gate | Verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| `queue-chorus-a.png` | 1024×1024 | 0 | 1077 (225, not graded) | 0 | 99.2% | **fail** | reject | Six figures, a smaller one standing beside the leader, cropped at the left edge (852 px of frame dark away from the bottom edge): a cluster, not one receding line. |
| `queue-chorus-b.png` | 1024×1024 | 0 | 3150 (3150, not graded) | 0 | 99.5% | pass | reject | The hoods face the viewer's right (the actor faces left), and the cloaks are drawn as outlined cloth folds rather than leaded panes. |
| `queue-chorus-c.png` | 1024×1024 | 0 | 3183 (2431, not graded) | 0 | 99.0% | **fail** | reject | Five figures side by side on one baseline, facing front: a size lineup, not a line receding in depth. Cropped at the left edge. |
| `queue-chorus-d.png` | 1024×1024 | 0 | 531 (525, not graded) | [0, 0, 0, 255] | 99.3% | **fail** | reject | The nearest miss and the strongest read: five of one walker in one overlapping line from centre-left into the right, each smaller and dimmer, amber breast light, facing left. But the last figure runs off the right edge (556 px of edge contact, bottom-right corner opaque): a cropped figure, and a hard vertical cut on stage. Clean vector glass, flatter than keeper.png. |
| [`queue-chorus-e.png`](survivors/queue-chorus-e.png) | 1024×1024 | 0 | 1667 (1667, not graded) | 0 | 98.9% | pass | **#3** | One receding line of five, facing left, amber breast lights, the most glass-like texture, clear of both side edges. Hoods alternate gold and slate, which reads as several walkers, and the line fills only the lower half of the canvas, so the chorus bust will read small. |
| `queue-chorus-f.png` | 1024×1024 | 0 | 121 (121, not graded) | 0 | 99.2% | pass | reject | Round 2. The front figure is smaller than the one behind it, so the line opens as a pair and reads as a group (round 1's a failed the same way). |
| [`queue-chorus-g.png`](survivors/queue-chorus-g.png) | 1024×1024 | 0 | 2280 (2280, not graded) | 0 | 99.3% | pass | **#2** | Round 2. One receding line of five, inside both side edges, with amber breast lights and the most leaded-glass look of the round, in exactly the briefed gold, slate and pale teal. The figures face the viewer rather than slightly left, and a faint 1 px dark purple line survives on a few robe edges. |
| [`queue-chorus-h.png`](survivors/queue-chorus-h.png) | 1024×1024 | 0 | 464 (464, not graded) | 0 | 98.8% | pass | **#1** | Round 2. One line of five of the same walker from the left into the right, each smaller and dimmer, facing left, amber breast lights, inside both side edges: the fullest reading of the brief. The lead is thinner than keeper.png's, and the last two figures are very dark. |
| `queue-chorus-i.png` | 1024×1024 | 0 | 2094 (1115, not graded) | [0, 0, 255, 0] | 99.5% | **fail** | reject | Round 2. The line runs edge to edge: the front figure is cut by the left edge and the last by the right (979 px of dark frame off the bottom edge, bottom-left corner opaque). |

The gate fails exactly the four renders that run off a side edge (`a`, `c`,
`d`, `i`). The bottom edge is reported but not graded (see Round 2).

<details><summary>Exact request</summary>

```text
Read the two style reference images at <repo>/assets/art/meta/keeper.png and <repo>/assets/art/scenes/unsealing-mirror-queue.png and produce a new image as a variation in their style: take the leaded stained-glass figure construction from the first and the single-file line of hooded walkers from the second. It is a new figure group, not an edit of either composition.

Serious cartoon-gothic stained-glass game art: chunky dark outer silhouettes, simplified exaggerated proportions, 3-5 large jewel-tone glass colour masses with very few thick lead dividers, matte painterly texture, warm amber rim light, soft controlled inner glow. No text, no labels, no watermark.

CONSTRUCTION, this is the most important instruction: every figure is built from large flat panes of coloured glass separated by thick black lead came lines, like cathedral stained glass rendered as characters. Only a few big panes per figure, never lacework. The lead lines are heavy, black and clearly visible. Glass is cold gold, slate and pale teal with thin worn gold edging on the lead.

BACKGROUND is a FLAT SOLID MAGENTA #FF00FF field, edge to edge, no vignette, no floor. Black exists ONLY inside the hood voids.

The Queue: five hooded walker figures standing in ONE single-file line that recedes from the centre-left of the frame toward the right. Each figure is a little smaller and dimmer than the one before it. Every hood opening is a deep black VOID with NO face, NO eyes. Each figure carries exactly one small point of warm amber light at the breast. They stand still, patient and quiet, facing slightly left. The bottom edge of the canvas cuts the figures at mid-thigh. They read as ONE line of the same walker, not a crowd.

Canvas: exactly 1024x1024 pixels.

Save the result as a PNG file at <scratch>/stagecraft-raw/queue-chorus-<x>.png
```

Round 2 (`f` to `i`) appends the inside-edges sentence in Round 2 to the Queue
paragraph.

</details>

## Unlit Way plates — #563

1536×1024, full-bleed, not keyed. Both files were re-rolled in round 2 (`e` to
`h`), and `unlit-way` again in round 3 (`i` to `l`). Two of 12 survive for
`unlit-way` and two of eight for `unlit-way-end`. Measured door-glow spans on
the end plate, as a share of the
width: round 1 `a` 71–74%, `b` 77–79%, `c` 75–77%, `d` 78–81%; round 2 `e`
80–85%, `f` 61–68%, `g` 61–63%, `h` 61–72% (a ring, not an arch).

| File | Size | Canvas | Verdict | Notes |
|---|---|---|---|---|
| `unlit-way-a.png` | 1536×1024 | pass | reject | Photographic render, off the painterly family; the seat spans 61-77% of the width, into the right bust band. |
| `unlit-way-b.png` | 1536×1024 | pass | reject | Lamp posts stand in both bust bands (the right one, a post with a lantern, sits behind the Lamplighter's own pole); the seat spans 62-84%. |
| [`unlit-way-c.png`](survivors/unlit-way-c.png) | 1536×1024 | pass | **#1** | Painterly. Road east to a dawnless horizon, dead lamps, the empty seat just right of centre (53-68%), raking amber from low left; the right band is empty. The nearest two posts stand in the left band, behind the hero's bust; the lit paving reaches into the bottom 30%. |
| `unlit-way-d.png` | 1536×1024 | pass | reject | The style reference bled in: a cathedral hall with a rose window and a doorway, not the open road. The seat (63-88%) and the nearest post sit in the right band. |
| `unlit-way-e.png` | 1536×1024 | pass | reject | Round 2. The bottom quarter is a flat grey fill that reads as a letterbox bar, a lit arch (the end plate's door) stands at the road's end, and the seat reaches 74% of the width. |
| `unlit-way-f.png` | 1536×1024 | pass | reject | Round 2. The seat spans 64-80% of the width, into the right band, and a ruined arch stands at the road's end. |
| `unlit-way-g.png` | 1536×1024 | pass | reject | Round 2. One lamp post stands in the road instead of a row along the verge, the finish is photographic (bokeh on the ash), and an arch stands at the road's end. |
| `unlit-way-h.png` | 1536×1024 | pass | reject | Round 2. The nearest miss: a row of dead lamps along the verge inside the centre band, amber from low left. But the seat reaches 75% of the width, into the right band; the finish is photographic, with black vignettes down both sides; and a ruined arch stands at the road's end. |
| [`unlit-way-i.png`](survivors/unlit-way-i.png) | 1536×1024 | pass | **#2** | Round 3. Both bands hold only ground, ash and the amber shaft from low left; the road runs out into plain darkness at the centre, with no arch or horizon light, and the row of dead posts stands on its verge at 45-56%. Dark (mean luminance 15.4, as dark as the shipped opening-hearth.png at 17.7). The finish is photographic, and the seat sits on the road at 45-54% rather than roadside at 55-60%. |
| `unlit-way-j.png` | 1536×1024 | pass | reject | Round 3. The two nearest lamp posts stand in the right band (75-78% and 85-91% of the width), behind the Lamplighter's seat, and a fire burns inside the left band instead of far behind the viewer. |
| `unlit-way-k.png` | 1536×1024 | pass | reject | Round 3. The nearest lamp post stands in the right band (71-78%), behind the Lamplighter's seat, and the amber light comes from the upper right rather than low left. |
| `unlit-way-l.png` | 1536×1024 | pass | reject | Round 3. The best finish of the round, painterly like c. But the road's vanishing end and the far row of posts sit at 68-85% of the width, behind the Lamplighter's seat; the nearest post, the tallest thing in the frame, stands in the left band (20-27%); and the seat is at 35-51%, left of centre. |
| `unlit-way-end-a.png` | 1536×1024 | pass | reject | Photographic; the door arch straddles the 72% line; paving fills the bottom 30%. |
| `unlit-way-end-b.png` | 1536×1024 | pass | reject | Painterly, but the door arch sits at about 78% of the width (right band), and a ruined cathedral spans 9-52%. |
| `unlit-way-end-c.png` | 1536×1024 | pass | reject | The last lamp reads lit (bright glowing panes), and the door arch sits at 75-77%. |
| `unlit-way-end-d.png` | 1536×1024 | pass | reject | The nearest miss: dead lamp at the centre, broken slabs, cold and empty. But the door arch sits at 78-81%, directly behind the Lamplighter's seat (0.80), and the slabs reach into the bottom 30%. |
| `unlit-way-end-e.png` | 1536×1024 | pass | reject | Round 2. The door sits at 80-85% of the width, in the right band, and a seat from the first plate bled in. |
| [`unlit-way-end-f.png`](survivors/unlit-way-end-f.png) | 1536×1024 | pass | **#2** | Round 2. A crooked dead lamp stands at the centre where the slabs break; cold mist, the ground falling away into a valley, the door at 61-68% of the width, inside the centre band. But the paving runs on past the lamp to the door, which is nearer and more detailed than 'far off, never detailed'. |
| [`unlit-way-end-g.png`](survivors/unlit-way-end-g.png) | 1536×1024 | pass | **#1** | Round 2. The last dead lamp (broken, dark glass) stands on the broken slabs at the centre where the road ends. The door is a small, far arch of light at 61-63%, and the outer bands hold only ground, ash and sky. The ground beyond is a flat plain rather than falling away into mist, and the slabs reach into the bottom 30%. |
| `unlit-way-end-h.png` | 1536×1024 | pass | reject | Round 2. The door is a swirling ring of cold light close behind the lamp (61-72% of the width), not a distant arch on the horizon, and its mist spills into the right band. |

<details><summary>Exact request: unlit-way, and the unlit-way-end subject</summary>

```text
Read the style reference image at <repo>/assets/art/scenes/opening-hearth.png and produce a variation of it that keeps only its rendering style, palette, light and brushwork. The composition and subject come entirely from the prompt below: do not keep its hall, hearth, fire, doorway or window.

Cinematic gothic fantasy key art, painterly and richly rendered, in the visual language of a stained-glass world: deep environment perspective with real recession into the distance, asymmetric composition with the subject well off centre, strong raking light cutting through the dark, heavy chiaroscuro with most of the frame in warm-black shadow, dust motes and drifting embers in the light shafts, matte painterly brushwork with no photographic sheen and no visible generation noise. Palette: warm amber, honey and gold against cold slate, deep teal, indigo and violet — a candlelit cathedral at night. Every figure is built from large flat panes of coloured glass separated by thick black lead came lines with thin worn gold edging: cathedral stained glass rendered as a character, only a few big panes, never lacework or many small pieces. Hooded figures have no face — the hood opening is a deep black void with no glowing eyes. Landscape 1536x1024, full-bleed to every edge. Keep every load-bearing element inside the central 92 percent of the width and out of the bottom 12 percent of the height. NO TEXT of any kind, no caption, no letterbox bars, no logo, no watermark, no UI, no border frame.

TWO-SHOT FRAME: keep the left 28 percent and the right 28 percent of the width free of anything that reads as a figure, and keep the bottom 30 percent quiet (a dialogue pane covers it). NO people, walkers, lamplighter or hooded figures anywhere in the plate.

The Unlit Way at night: a long stone road running east into darkness toward a faint horizon with no dawn; a row of tall iron lamp posts along its verge, every lamp dead and dark; ash drifting on a low cold wind; one flat roadside stone composed as a seat just right of centre, empty. Raking amber light from low left, as if from a fire far behind the viewer.

Canvas: exactly 1536x1024 pixels.

Save the result as a PNG file at <scratch>/stagecraft-raw/unlit-way-<x>.png
```

- `unlit-way-end` sends the same request with the last paragraph replaced by
  #563's subject, verbatim: "Where the Unlit Way runs out: the paving breaks
  off into broken slabs and ash at the centre of the frame; the last dead lamp
  post stands at the end of the road; beyond it the ground falls away into mist
  toward a distant arch of light on the eastern horizon (the door, far off and
  never detailed). Emptier and colder than the first plate."
- Round 2 (`e` to `h` of both files) appends the placement sentence in Round 2
  to the TWO-SHOT FRAME clause.
- Round 3 (`unlit-way-i` to `unlit-way-l`) appends `unlit-way`'s own sentence,
  quoted in Round 3, in its place.

</details>

## Findings

1. **The rim sentence fixed the Lamplighter's relight.** In round 1, five
   renders dropped the amber rim and the worn gold edging entirely (warm edge
   0.3% or less): wary `a`, `b` and `c`, `urgent-d` and `grieving-c`. With the
   round-2 sentence, all four wary renders kept it (17.0–21.2%, against the
   reference's 20.2%). Round 2's wary failures were about the prop instead:
   `g`'s lantern became a flat slab, and `h`'s sits on top of the pole.
2. **The first plate needed three rounds.** In round 1 every `unlit-way-end`
   render put the door at 71–81% of the width, behind the Lamplighter's seat at
   0.80. Round 2's shared placement sentence fixed that: `f` and `g` put it at
   61–68%, and both survive. On `unlit-way` the same sentence had two side
   effects:
   - The seat still drifted into the right band: `e` 74%, `f` 64–80%, `h` 75%.
   - Every round-2 render drew an arch at the road's end, against none in
     round 1, because the shared list names "the distant arch".

   Round 3's own sentence removed the arch from all four renders, but only `i`
   kept both bands clear. Placement by percentage is approximate with this
   model: the seat landed on its mark once in four. The stills at landing are
   the real check.
3. **The Queue's side edges were the real test.** Round 1 kept two of five
   inside both side edges (`b`, `e`); round 2, with the inside-edges sentence,
   kept three of four (`f`, `g`, `h`). For the landing: `actors.json` gives the
   Queue a full-canvas crop, and `StagePortrait` dissolves only a bust cut above
   the canvas foot, so the brief's bottom cut will not dissolve by itself,
   although #562 expects it to. Check it in the `act4-node1` still.
4. **Enclosed background keeps the render's haze.** Grok Build floods the
   border-connected field to pure `#FF00FF` itself. Background that the figure
   encloses, between the lantern pole and the robe or inside the lantern's
   ring, keeps a pink haze of strength 60 to 160. That is what `--haze` clears.
   Without it, `lamplighter-wary-a` failed the leftover gate at 1,823 px.
5. **m5-pre's first line enters the Lamplighter at the centre (0.50)**, in front
   of the end plate's lamp post. Both end-plate survivors keep the door at
   61–68%, visible between the centre and the right seat once he moves there.
6. **Asking is the shipped pose.** All four asking renders reproduce the shipped
   figure (IoU 0.92 to 0.99; `d` grew and is rejected). Landing one changes
   little on screen, because the stage's fallback already shows the shipped
   figure for this mood.

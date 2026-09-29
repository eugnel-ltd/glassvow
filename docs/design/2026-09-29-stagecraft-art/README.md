# Stagecraft art — candidates for #560–#563

A candidates round for the portraits and plates billed in `docs/art-ledger.md` ›
"Commissioned — dialogue stagecraft portraits and plates (2026-09-27)" (parent
#559). **Nothing here is in `assets/`.** James picks one file per path. A
landing commit then copies each pick to its ledgered path, commits the
`.import` sidecar, moves the ledger row to Shipped with the prompt that
rendered it, and takes the stills the issues ask for.

49 candidates were generated on 2026-09-29 and 24 survive. Each family's
contact sheet shows every candidate, keyed and labelled, rejects included. Only
the survivors are committed, in `survivors/`. Raw renders and rejects stay out
of the tree.

| Family | Issue | Sheet | Generated | Survivors | Ranked first |
|---|---|---|---|---|---|
| Keeper moods | #560 | [`contact-keeper.png`](contact-keeper.png) | 16 | 11 | tender-a, offering-b, weary-c, beckon-a |
| Hollow Lamplighter moods | #561 | [`contact-lamplighter.png`](contact-lamplighter.png) | 20 | 11 | wary-d, asking-a, recognising-b, urgent-c, grieving-b |
| Queue chorus | #562 | [`contact-queue.png`](contact-queue.png) | 5 | 1 | queue-chorus-e |
| Unlit Way plates | #563 | [`contact-plates.png`](contact-plates.png) | 8 | 1 | unlit-way-c; none for unlit-way-end |

**Gaps.** `lamplighter-wary`, `queue-chorus` and `unlit-way` have one survivor
each; `unlit-way-end` has none. Findings 1 to 3 explain why, and the last
section suggests the next round. It was not run.

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

- **Generation.** On 2026-09-29, through
  `~/.claude/scripts/subagents/run-grok-media.sh`: Grok Build CLI 1.0.41 with
  the model `grok-4.7` (the wrapper picks the newest at run time), one image per
  call, three calls at a time. Each request reads the reference at its absolute
  path, then carries the canonical prompt verbatim from the issue (the issues
  assemble the ledger's clauses), the exact canvas and the output path. All 49
  calls returned the right canvas on the first attempt; no retry was needed.
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
  of the render's own pink haze and despills slivers. Plates are not keyed:
  `--plate` checks the 1536×1024 canvas.
- **Review aids.** These were measured outside the tool and are not committed.
  Silhouette IoU is the overlap with the reference at alpha ≥ 128. Warm edge is
  the share of amber pixels (hue 20–50°, saturation ≥ 0.45, value ≥ 0.35) in
  the silhouette's outer 12 px, split at the bounding box's midline. Reference
  values: `keeper.png` 9.9% (weighted right), `eternalKeeper.png` 12.0%
  (weighted left), `hollow-lamplighter.png` 20.2% (both sides).
- **Contact sheets.** Every candidate of a family, keyed and over mid-grey,
  with the shipped reference first in each portrait row. The plates carry the
  two-shot guides: cyan lines at 28% and 72% of the width and 70% of the height.

```bash
python3 tools/key_magenta.py RAW.png OUT.png --expect 682x1024          # Keeper
python3 tools/key_magenta.py RAW.png OUT.png --expect 682x1024 --haze   # Lamplighter
python3 tools/key_magenta.py RAW.png OUT.png --expect 1024x1024 --haze  # Queue
python3 tools/key_magenta.py --plate RAW.png                            # plates
python3 tools/key_magenta.py --contact-sheet contact-keeper.png --tile-height 400 \
    --row "keeper-tender  (#560)" REF.png A.png B.png C.png D.png \
    --tag keeper-tender-a="#1" --tag keeper-tender-b="REJECT: chest slab"   # one --row per file
```

How to read the tables: **Magenta** is leftover field-magenta (< 32). **Frame
dark** is opaque near-black in the 8 px canvas frame (< 400), with the
bottom-edge share in brackets. **Corners** are the four corner alphas; 0 means
all four are clear. **≥240** is the share of visible pixels at alpha ≥ 240
(≥ 90%). **Verdict** ranks the survivors of each file. James picks.

## Keeper — #560

Tender, offering and weary edit `meta/keeper.png`; beckon edits
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

Every file edits `meta/hollow-lamplighter.png`. Eleven of 20 survive; wary has
one.

| File | Size | Magenta | Frame dark (bottom edge) | Corners | ≥240 | Gate | Verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| `lamplighter-wary-a.png` | 682×1024 | 0 | 0 (0) | 0 | 98.3% | pass | reject | No amber rim and no gold edging (warm edge 0.0% against the reference's 20.2%). Wary cuts against recognising on consecutive lines in m1-pre and m3-pre, so the glass would change material. The pole also stays at his side. |
| `lamplighter-wary-b.png` | 682×1024 | 0 | 0 (0) | 0 | 98.4% | pass | reject | The best pose of the four (pole across the body, weight back), but no rim or gold edging, washed sage glass, and the head 71 px lower. |
| `lamplighter-wary-c.png` | 682×1024 | 0 | 0 (0) | 0 | 98.0% | pass | reject | The head is a solid black silhouette (the pale skull dome is gone), the robe breaks into many small shards, and there is no rim. |
| [`lamplighter-wary-d.png`](survivors/lamplighter-wary-d.png) | 682×1024 | 0 | 0 (0) | 0 | 97.6% | pass | **#1** | Pole drawn in across the body, empty hand lowered and closed, rim and gold edging intact, head where the reference has it. The lantern is larger, with pale cold panes: unlit, but brighter than the reference's. |
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

<details><summary>Exact request: lamplighter-wary, and how the other four differ</summary>

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

The other four files send the same request with the POSE block replaced by
#561's, verbatim (asking, recognising, urgent, grieving).

</details>

## Queue chorus — #562

A new figure group, so there is no edit reference and no framing to keep. One
of five survives.

| File | Size | Magenta | Frame dark (bottom edge) | Corners | ≥240 | Gate | Verdict | Notes |
|---|---|---|---|---|---|---|---|---|
| `queue-chorus-a.png` | 1024×1024 | 0 | 1077 (225) | 0 | 99.2% | **fail** | reject | Six figures, a smaller one standing beside the leader, cropped at the left edge (852 px of frame dark away from the bottom edge): a cluster, not one receding line. |
| `queue-chorus-b.png` | 1024×1024 | 0 | 3150 (3150) | 0 | 99.5% | **fail** | reject | The hoods face the viewer's right (the actor faces left), and the cloaks are drawn as outlined cloth folds rather than leaded panes. |
| `queue-chorus-c.png` | 1024×1024 | 0 | 3183 (2431) | 0 | 99.0% | **fail** | reject | Five figures side by side on one baseline, facing front: a size lineup, not a line receding in depth. Cropped at the left edge. |
| `queue-chorus-d.png` | 1024×1024 | 0 | 531 (525) | [0, 0, 0, 255] | 99.3% | **fail** | reject | The nearest miss and the strongest read: five of one walker in one overlapping line from centre-left into the right, each smaller and dimmer, amber breast light, facing left. But the last figure runs off the right edge (556 px of edge contact, bottom-right corner opaque): a cropped figure, and a hard vertical cut on stage. Clean vector glass, flatter than keeper.png. |
| [`queue-chorus-e.png`](survivors/queue-chorus-e.png) | 1024×1024 | 0 | 1667 (1667) | 0 | 98.9% | **fail** | **#1** | One receding line of five, facing left, amber breast lights, the most glass-like texture, clear of every edge but the brief's bottom cut. Hoods alternate gold and slate, which reads as several walkers, and the line fills only the lower half of the canvas, so the chorus bust will read small. |

Every Queue render fails the frame metric, because the brief cuts the figures
at the canvas foot (Finding 3). Read the bracketed bottom-edge share: `e` is the
only render clear of the other three edges and all four corners.

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

</details>

## Unlit Way plates — #563

1536×1024, full-bleed, not keyed. One of four survives for `unlit-way` and none
for `unlit-way-end`. The door-glow positions below were measured as the
brightest point right of the centre on the horizon: `a` 72.1–73.2%, `b`
77.4–78.5%, `c` 75.1–77.1%, `d` 78.6–80.7% of the width.

| File | Size | Canvas | Verdict | Notes |
|---|---|---|---|---|
| `unlit-way-a.png` | 1536×1024 | pass | reject | Photographic render, off the painterly family; the seat spans 61-77% of the width, into the right bust band. |
| `unlit-way-b.png` | 1536×1024 | pass | reject | Lamp posts stand in both bust bands (the right one, a post with a lantern, sits behind the Lamplighter's own pole); the seat spans 62-84%. |
| [`unlit-way-c.png`](survivors/unlit-way-c.png) | 1536×1024 | pass | **#1** | Painterly. Road east to a dawnless horizon, dead lamps, the empty seat just right of centre (53-68%), raking amber from low left; the right band is empty. The nearest two posts stand in the left band, behind the hero's bust; the lit paving reaches into the bottom 30%. |
| `unlit-way-d.png` | 1536×1024 | pass | reject | The style reference bled in: a cathedral hall with a rose window and a doorway, not the open road. The seat (63-88%) and the nearest post sit in the right band. |
| `unlit-way-end-a.png` | 1536×1024 | pass | reject | Photographic; the door arch straddles the 72% line; paving fills the bottom 30%. |
| `unlit-way-end-b.png` | 1536×1024 | pass | reject | Painterly, but the door arch sits at about 78% of the width (right band), and a ruined cathedral spans 9-52%. |
| `unlit-way-end-c.png` | 1536×1024 | pass | reject | The last lamp reads lit (bright glowing panes), and the door arch sits at 75-77%. |
| `unlit-way-end-d.png` | 1536×1024 | pass | reject | The nearest miss: dead lamp at the centre, broken slabs, cold and empty. But the door arch sits at 78-81%, directly behind the Lamplighter's seat (0.80), and the slabs reach into the bottom 30%. |

<details><summary>Exact request: unlit-way, and the unlit-way-end subject</summary>

```text
Read the style reference image at <repo>/assets/art/scenes/opening-hearth.png and produce a variation of it that keeps only its rendering style, palette, light and brushwork. The composition and subject come entirely from the prompt below: do not keep its hall, hearth, fire, doorway or window.

Cinematic gothic fantasy key art, painterly and richly rendered, in the visual language of a stained-glass world: deep environment perspective with real recession into the distance, asymmetric composition with the subject well off centre, strong raking light cutting through the dark, heavy chiaroscuro with most of the frame in warm-black shadow, dust motes and drifting embers in the light shafts, matte painterly brushwork with no photographic sheen and no visible generation noise. Palette: warm amber, honey and gold against cold slate, deep teal, indigo and violet — a candlelit cathedral at night. Every figure is built from large flat panes of coloured glass separated by thick black lead came lines with thin worn gold edging: cathedral stained glass rendered as a character, only a few big panes, never lacework or many small pieces. Hooded figures have no face — the hood opening is a deep black void with no glowing eyes. Landscape 1536x1024, full-bleed to every edge. Keep every load-bearing element inside the central 92 percent of the width and out of the bottom 12 percent of the height. NO TEXT of any kind, no caption, no letterbox bars, no logo, no watermark, no UI, no border frame.

TWO-SHOT FRAME: keep the left 28 percent and the right 28 percent of the width free of anything that reads as a figure, and keep the bottom 30 percent quiet (a dialogue pane covers it). NO people, walkers, lamplighter or hooded figures anywhere in the plate.

The Unlit Way at night: a long stone road running east into darkness toward a faint horizon with no dawn; a row of tall iron lamp posts along its verge, every lamp dead and dark; ash drifting on a low cold wind; one flat roadside stone composed as a seat just right of centre, empty. Raking amber light from low left, as if from a fire far behind the viewer.

Canvas: exactly 1536x1024 pixels.

Save the result as a PNG file at <scratch>/stagecraft-raw/unlit-way-<x>.png
```

`unlit-way-end` sends the same request with the last paragraph replaced by
#563's subject, verbatim: "Where the Unlit Way runs out: the paving breaks off
into broken slabs and ash at the centre of the frame; the last dead lamp post
stands at the end of the road; beyond it the ground falls away into mist toward
a distant arch of light on the eastern horizon (the door, far off and never
detailed). Emptier and colder than the first plate."

</details>

## Findings

1. **Some renders relight the Lamplighter.** Five renders dropped the amber rim
   and the worn gold edging entirely (warm edge 0.3% or less): wary `a`, `b`
   and `c`, `urgent-d` and `grieving-c`. Wary lost it three times in four,
   urgent and grieving once each, asking and recognising never. A wary
   re-roll could add "keep the amber rim light and the worn gold edging
   exactly as in the reference". That changes the canonical prompt, so it is
   James's call.
2. **The plate prompt works against the two-shot rule.** The shared style block
   asks for an "asymmetric composition with the subject well off centre".
   With only the centre band free, every `unlit-way-end` render put the door at
   72–81% of the width, behind the Lamplighter's seat at 0.80. Three of four
   `unlit-way` renders put the seat in the right band. Re-rolling the same
   prompt will probably repeat this. A suggested amendment for the two two-shot
   plates is to replace "well off centre" with a placement, such as "the door
   arch sits between 45 and 60 percent of the width".
3. **The Queue cannot pass the frame metric as briefed.** "The bottom edge of
   the canvas cuts the figures at mid-thigh" puts lead on the bottom edge of
   every render (225 to 3,150 px). The tool now reports the bottom-edge share;
   the other three edges are the real test. For the landing: `actors.json`
   gives the Queue a full-canvas crop, and `StagePortrait` dissolves only a
   bust cut above the canvas foot, so this cut will not dissolve by itself,
   although #562 expects the dissolve to hide it. Check it in the
   `act4-node1` still.
4. **Enclosed background keeps the render's haze.** Grok Build floods the
   border-connected field to pure `#FF00FF` itself. Background that the figure
   encloses, between the lantern pole and the robe or inside the lantern's
   ring, keeps a pink haze of strength 60 to 160. That is what `--haze` clears.
   Without it, `lamplighter-wary-a` failed the leftover gate at 1,823 px.
5. **m5-pre's first line enters the Lamplighter at the centre (0.50)**, in front
   of the end plate's focal point, the broken road and the last lamp. That
   line covers the brief's centre composition wherever the door lands.
6. **Asking is the shipped pose.** All four asking renders reproduce the shipped
   figure (IoU 0.92 to 0.99; `d` grew and is rejected). Landing one changes
   little on screen, because the stage's fallback already shows the shipped
   figure for this mood.

## Suggested next round (not run)

- `lamplighter-wary`: four more, with the rim line from Finding 1 if James
  agrees.
- `queue-chorus`: four more. The target is `d`'s composition (one walker,
  repeated and overlapping) with the line ending inside the frame.
- `unlit-way` and `unlit-way-end`: four more each, once the placement amendment
  in Finding 2 is settled.

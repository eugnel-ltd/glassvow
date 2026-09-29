# The app icon against the signed rose-door brief (#545 inspection)

**Status:** inspection complete, 2026-09-29. The shipped icon does not meet the brief. Four generated candidates wait for James to pick one and sign it at arm's length. Nothing here enters `assets/`; the shipped `glassvow-icon.png` and `glassvow.icns` are untouched. Owner: James. Author: Claude (Opus 5.5), for #545 under #409.

**Authority.** The brief is #409's icon line, which carries #243's resolution (signed 2026-08-19) unchanged. This record judges the current file against it and does not reopen it.

## What was inspected

| | |
|---|---|
| Shipped file | `assets/icon/glassvow-icon.png`: 1024 × 1024 RGBA, sha256 `4e4309be3af4440673c880d60625a45d45b4495c03efaa3e0120dd7d83a8ba04`. |
| History | Last changed 2026-08-01, when it shipped as a provisional pending James's pick. It is byte-identical to `assets/icon/candidates/icon-A-full-rose.png`. On 2026-08-19 #243 ruled that this file "does not ship", and it has not changed since. |
| What it is | A crop of the in-game Emberglass rose, `assets/art/meta/emberglass-mural.png` under `emberglass-frame.png`, seated on the macOS icon grid by `tools/make_icon_master.py` (824 px live area inside a transparent 100 px margin). It has no generation prompt of its own and no art-ledger row. |
| Earlier candidates | `icon-B-shard-star.png` enlarges the gold pane; `icon-C-lantern.png` shows a crown over a gloved hand holding a lantern. Neither has a door, and C has a hand. |
| Prompt source | `docs/` has no app-icon art bible and the art ledger has no app-icon row, so there is no ledger prompt. The candidates below quote #243's wording instead. |

## How it was rendered

Pillow, from the 1024 master. Each master is flattened opaque on black, because the App Store slot must be opaque, then downsampled with Lanczos to 180 px (60 pt @3x), 120 px (60 pt @2x), 76 px (76 pt @1x) and 60 px (60 pt @1x). Each render is masked by a rounded square whose corner radius is 22.37 % of the side, an approximation of Apple's squircle, and shown on light `#F2F2F7` and dark `#000000`. The first sheet shows the 1024 master at 1:1 across both backgrounds; the candidates sheet shows it at 25 %. The 60 px render is also shown ×4 with nearest-neighbour scaling: exactly the pixels a 60 pt icon has at 1x, readable on any screen. Open the sheets at 100 % for true sizes.

![The current icon at 1024, 180, 120, 76 and 60 px on light and dark, iOS mask applied](contact-current.png)

## Verdict, item by item

| Brief item | Verdict | What I saw |
|---|---|---|
| Rose-window identity | **Met** | A circular leaded rose with six spokes and a thin gold ring, in cobalt, violet, gold and pale glass. At 60 px the round wheel of coloured glass still reads as a rose window. |
| A sealed door with a hairline of light | **Not met** | #243 makes the door the hub; here the hub is an empty dark disc. The only door is a scene detail: a 50 × 68 px pointed arch with a 2 px crack of light at the foot of the stairs in the top pane. At 60 px it is about 3 × 4 px and the crack is sub-pixel. |
| One to three legible shapes at 60 pt | **Not met** | At 60 px one shape reads: the wheel. Inside it six colour wedges compete, and every scene breaks into speckle. Neither the door nor the light is among what reads. |
| No figures, no stairs, no five-pane comic | **Not met** | Five of the six panes are the mural's narrative scenes: six robed figures and a gloved hand, three bearers carrying a shard down a staircase, a crown over a lantern, pages rising off a stepped stack. Only the gold shard-star pane is abstract. This is the five-pane comic the brief excludes. |
| Same mark in both locales (no text in the mark) | **Met** | No text, letters or numerals. One `config/icon` serves en and zh-Hant; there is no per-locale icon. |

## The one remaining mismatch

The icon was never remade. The shipped file is still the 2026-08-01 provisional that #243 ruled out, so the rose carries the story mural where the brief wants the rose door: a sealed door at the hub, a hairline of light, and plain glass around it. That single cause fails three items (the door, legibility at 60 pt, and figures, stairs and comic). Rose identity and the text-free mark already hold, and a remake keeps them.

## Outside the brief: the iOS slot

This changes no verdict above; it belongs to the integration step. The iOS export preset sets no icon, so the iOS build falls back to `config/icon`, which is this macOS-grid master with its transparent margin. The App Store 1024 slot must be opaque, and flattened, that margin is black (its RGB is 0, 0, 0). On iOS the rose would fill about 65 % of the tile inside a black band, as the sheet shows. Whichever mark James picks, iOS needs a full-bleed opaque master; the macOS icns can keep the grid.

## Candidates

Four calls on 2026-09-29, one image each; provenance is below. Every request kept the rose and asked for changes only to the hub and the panes. The variants test the two choices that decide legibility at 60 pt: the door's scale (C1 against C2) and the colour strategy (C3 against C4). Two of the four are not image-model output. For C2 and C3 the model kept drawing eight or twelve spokes, so Grok drew the icon itself in Pillow, resampling glass from its own generation.

![Candidates at 1024 (shown at 25 %), 180, 120, 76 and 60 px on light and dark, with the current icon as the first row](contact-candidates.png)

Ranked against the brief: the door and its light at 60 pt first, then rose identity, then fidelity to the reference and fit to the Store slot. "Rose width" is the lit rose as a share of the canvas; iOS masks the corners, never the rose.

| Rank | Candidate | Made by | Rose width | Why this rank |
|---|---|---|---|---|
| 1 | [C1 · hub door](candidate-1-hub-door.png) | Image model, two edits | 79 % | The only candidate that keeps the game's leaded rose, palette and painterly glass while making the door the focal point, and the door reads at every size. Off the reference: eight divisions, not six; a round head, not a pointed arch; the hairline thins to about a pixel at 60 px @1x. |
| 2 | [C4 · lit rose, dark door](candidate-4-lit-rose.png) | Image model, two edits | 66 % | The strongest 60 px read (the lit glass is 2.6× the door's luminance) and the plainest picture of "light the rose, open the sealed door". But at 60 px the door shrinks to a slotted disc, and eight spokes, a wooden door and amber-only glass read as a sun or a lamp rather than the game's glass. |
| 3 | [C2 · large door](candidate-2-large-door.png) | Pillow, from its own generation | 84 % | The most legible door, with six spokes and a pointed arch. But the rose shrinks to a ring around it, and the flat brown door and blotchy glass fall short of shelf finish. |
| 4 | [C3 · cool rose, warm seam](candidate-3-cool-rose.png) | Pillow, from its own generation | 84 % | The right geometry: six spokes, a pointed arch, one warm line. But at 60 px the slate door is only 1.2× the luminance of its glass and nearly vanishes, and the resampling smears the glass. |

Every candidate meets the brief's exclusions: no figures, no stairs, no pane comic, no text. They differ in how well the door, the light and the rose survive at 60 pt, which is what the ranking weighs.

## Provenance

| | |
|---|---|
| Tool | Grok Build CLI 1.0.45, one image per call, through `~/.claude/scripts/subagents/run-grok-media.sh`. The runner picks the newest model in `grok models` at run time and passed `-m grok-4.7`; the session transcripts record it as `grok-4.7-build`. Low reasoning effort, tool use auto-approved. Grok's working directory was a scratch folder outside the repository, and the worktree was clean afterwards apart from this folder. |
| Image path | Grok rewrote each request into its own prompts for Grok Build's Imagine `image_edit` tool, with the current icon as the input image (quoted below). Imagine returned 1024 × 1024 JPEGs. C1 and C4 are the second edit of each, converted to PNG with `sips`. C2 and C3 are Pillow and NumPy drawings Grok wrote after two edits each: glass resampled from its second Imagine output, with ring, spokes, door and hairline drawn in code. |
| Date | 2026-09-29, London time. C1 16:35–16:38; C2 16:39–16:51; C3 16:39–16:48; C4 16:39–16:42. |
| Reference | Each request told the tool to read `assets/icon/glassvow-icon.png` (sha256 `4e4309be…`) at its absolute path in the delivery worktree, and to change only the hub and the panes. |
| Request | Verbatim below. The ledger has no icon prompt, so the request quotes #243's icon wording and #409's restatement. `{OUT}` was each call's absolute output path in the scratch folder. |
| Files here | The four candidate PNGs are the tool's final files byte for byte: 1024 × 1024, opaque RGB, nothing resized or re-encoded. sha256: C1 `1868f205a54b5632a37282c0f8549b3fb2a01c3607bbc280849d6df52beb95b6`; C2 `537b2c322fb58ef69baecebdd1e1bfd6ccb3c310b282e9fc8bc4ce2dec3ca1fd`; C3 `ff2725587066208cc50caa80606dbf4d1a56adbc3f4a8bc33a7b5b44f68d1d79`; C4 `aa0e96dd5b924e183f73f7c4842059f3c9124e4d8ea348d00bfae195954e387a`. |
| Who picks | James. No candidate is accepted, integrated or entered in the art ledger until he picks one and signs it at arm's length. |

The shared request, sent in all four calls:

```text
Generate one image and save it as a PNG at exactly this absolute path: {OUT}
Size: 1024x1024 pixels.

This is the iOS app icon for Glassvow (琉璃誓言), a stained-glass roguelite deckbuilder.

Signed brief (issue #243, verbatim): "Remake the rose window. Hub is the sealed door with a hairline of light. 1–3 shapes readable at 60pt. No figures, no stairs."
The same brief restated in issue #409 (verbatim): "rose window with a sealed door and hairline of light, one to three readable shapes at 60 pt, no figures/stairs/five-pane comic, same mark in both locales."

Reference: first read the current icon at /Users/jamesto/Coding/glassvow/.claude/worktrees/agent-af01b75691af875f3/assets/icon/glassvow-icon.png and use it as the reference. Keep what it gets right: a circular leaded stained-glass rose window with six dark spokes and a thin gold ring, painterly glass texture with dark lead lines, the palette of cobalt blue, violet, amber gold and pale glass, on a near-black night ground (#04050b).

Change only what the brief says is wrong with it:
1. The hub: replace the empty dark centre with a sealed door - a closed, pointed-arch door of two leaves, seen straight on - with one hairline of warm light along the seam where the two leaves meet. The door is the focal point.
2. The panes: remove every figure, hand, face, staircase and scene. The panes become plain, unpictured leaded glass.

Nothing else: no text, letters or numerals; no people; no stairs; no crown, lantern, cards or pages.
Format: a full-bleed opaque square. The night ground runs to all four edges; do not draw a rounded tile, frame, border, drop shadow or transparent margin (iOS applies its own mask later). Centre the rose; its outer ring spans about 84% of the width.
It must still read as one to three shapes - the rose, the door, the line of light - when shrunk to 60x60 pixels.
```

Then one variant line per call, and a closing line (`When done, reply with the absolute path of the saved file.`):

| Call | Variant line |
|---|---|
| C1 | `Variant: the door is about one third of the rose's diameter and sits in the hub; the six panes keep the reference's mix of cobalt, violet and gold as plain glass.` |
| C2 | `Variant: the door is large, about half the rose's diameter, its arch rising into the upper panes; the spokes end at the door's frame; the six panes keep the reference's mix of cobalt, violet and gold as plain glass.` |
| C3 | `Variant: the door is about two fifths of the rose's diameter; every pane is cool cobalt and violet glass, so the hairline of light is the only warm colour in the icon.` |
| C4 | `Variant: the door is about two fifths of the rose's diameter; every pane is warm amber-gold glass, lit as if from behind, around a dark door whose seam carries one pale-gold hairline of light.` |

C1 came back with eight divisions, so calls C2 to C4 add one line after the variant: `Keep exactly six spokes and six panes, as in the reference (not eight).`

**What the tool said and what came back.** Grok's closing summaries are not evidence. For C1 it reported a pointed arch and six panes, and for C4 six spokes; the images show a round-headed door and eight divisions in both. The ranking table records what the images show.

<details>
<summary>What reached the image model: Grok's <code>image_edit</code> prompts, verbatim</summary>

**C1** (session `01a0edce-f36d-7340-acf3-b2046c686060`)

Edit 1, input the current icon, aspect 1:1:

```text
Keep the same circular leaded stained-glass rose window: six dark spokes, a thin gold outer ring, painterly glass texture and dark lead lines, palette of cobalt blue, violet, amber gold and pale glass, centred on a full-bleed near-black night ground (#04050b) that runs to all four edges of a square. The outer gold ring spans about 84% of the width. Replace the empty dark hub with a sealed door seen straight on: a closed pointed-arch door of two leaves, about one third of the rose diameter, dark leaded glass and iron, with one hairline of warm gold light along the vertical seam where the two leaves meet. That door is the focal point. Replace every pane with plain unpictured leaded glass, keeping the reference mix of cobalt, violet and gold as abstract glass only.
```

Edit 2, input its first Imagine output, aspect 1:1:

```text
Keep the same rose window, six dark spokes, thin gold ring, cobalt violet and amber plain glass panes, and the near-black full-bleed night ground. Simplify the central pointed-arch door so both door leaves are plain dark panels with no plants, tracery, or ornaments. Leave only one thin vertical hairline of warm light down the seam where the two closed leaves meet. The door stays about one third of the rose diameter, sealed and seen straight on.
```

**C2** (session `01a0edd2-447b-7480-be1a-f5d690dd9609`)

Edit 1, input the current icon, aspect 1:1:

```text
A square full-bleed app icon on a near-black night ground that runs to all four edges. Keep the same circular leaded stained-glass rose window: six dark spokes, a thin gold outer ring, painterly cobalt blue, violet, amber gold and pale glass with dark lead lines, centred so the outer ring spans about 84 percent of the width. Replace the hub with a large sealed door about half the rose’s diameter: a closed pointed-arch double door of two dark leaves seen straight on, its arch rising into the upper panes, the six spokes ending at the door’s frame, and one hairline of warm light down the seam where the two leaves meet. The six panes are plain unpictured leaded glass in the same cobalt, violet and gold mix.
```

Edit 2, input its first Imagine output, aspect 1:1:

```text
Same painterly stained-glass rose on a flat square of solid near-black #04050b that fills every corner with no rounded tile. Rebuild the window as exactly six panes and exactly six dark spokes, like a pie cut into six equal wedges, one spoke straight up. The hub is a large sealed pointed-arch double door, Gothic lancet arch not a round arch, about half the rose diameter, two closed dark leaves seen straight on, one hairline of warm light only along the vertical seam. Spokes stop at the door frame. Panes are plain unpictured leaded glass in cobalt, violet and amber gold, with a thin gold outer ring spanning about 84 percent of the width.
```

**C3** (session `01a0edd2-4da4-7f80-a279-08f62f26081f`)

Edit 1, input the current icon, aspect 1:1:

```text
A square full-bleed app icon on a near-black night ground (#04050b) that runs to all four edges, no rounded tile, no frame, no border, no drop shadow. Centred is the same circular leaded stained-glass rose window: exactly six dark spokes dividing exactly six panes, a thin gold outer ring spanning about 84% of the width, painterly glass with dark lead lines. Every pane is plain unpictured leaded glass in cool cobalt blue and violet only, irregular glass texture, no pictures inside the panes. The hub is a sealed door, a closed pointed-arch double door of two leaves seen straight on, about two fifths of the rose diameter, dark metal and glass, with one hairline of warm amber light along the vertical seam where the two leaves meet. That hairline is the only warm colour; the rest of the glass stays cool cobalt and violet. The door is the focal point. Gothic cathedral rose-window icon, crisp and readable as three shapes: the rose, the door, the line of light.
```

Edit 2, input its first Imagine output, aspect 1:1:

```text
Same square icon and night ground. Rebuild the rose as exactly six huge wedge panes, like a pie cut into six equal slices, with exactly six thick dark spokes at 12, 2, 4, 6, 8 and 10 o'clock. One single thin gold ring around the outside, spanning about 84% of the canvas width. Cool cobalt and violet painterly leaded glass only, no pictures in the panes. In the centre, a large sealed pointed-arch double door seen straight on, about two fifths of the rose diameter, two closed leaves, and one hairline of warm light only along the vertical seam where the leaves meet. No glowing outline around the arch. Dark lead, full-bleed opaque square.
```

**C4** (session `01a0edd2-5441-70d1-aa91-96b8022dc728`)

Edit 1, input the current icon, aspect 1:1:

```text
A square full-bleed app icon on a near-black night ground (#04050b) that runs unbroken to all four edges. Centred is a circular leaded stained-glass rose window whose thin gold outer ring spans about 84% of the width. Keep exactly six thick dark spokes dividing six panes, painterly cracked glass, dark lead cames, and a thin gold ring. Every pane is plain unpictured warm amber-gold glass, glowing as if lit from behind, with irregular lead lines and no pictures. The hub is a sealed pointed-arch double door seen straight on, about two fifths of the rose diameter, dark iron-brown wood, closed, with one pale-gold hairline of warm light running the full vertical seam where the two leaves meet. The door is the focal point. No people, no text.
```

Edit 2, input its first Imagine output, aspect 1:1:

```text
Same square icon, same near-black full-bleed ground, same amber-gold leaded rose window and thin gold ring. Change the wheel so it has exactly six dark spokes and exactly six large plain amber panes, evenly spaced like a pie cut into six, not eight. Enlarge the sealed pointed-arch double door so it is about two fifths of the rose diameter, still centred and seen straight on, dark wood, one pale-gold hairline of light down the seam, no handles or hinges. Painterly stained glass, no people, no text.
```

</details>

## The decision left for James

Pick one candidate and sign it at arm's length on a phone, or reject all four by naming the brief criterion they miss; #545 allows no further aesthetic round without one. After a pick the rest is integration under #545: the full-bleed iOS master, the macOS grid master through `tools/make_icon_master.py`, the icns through `tools/make_icon.sh`, and the art-ledger row carrying the pick's request, its Imagine prompts and its hash from this record.

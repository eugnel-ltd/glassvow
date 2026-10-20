# Website story art (2026-10-20)

Art made for the storytelling home page of glassvow.eugnel.com: the eleven story
chapters through Acts I–III, and the concept art and mechanism backdrops added in
the second batch. None of it is in `assets/`, so the game does not
load it. It is concept art for the website, owned here so that it can be
regenerated. The page itself is a design canvas, not yet ported into `site/`.

`docs/art-ledger.md` › *Website — story plates and parallax layers* is the
ledger entry. This folder holds the files and the prompts exactly as they were
sent.

## How it was made

- **Generator.** The Codex CLI (0.163.0) built-in image tool, running on the
  owner's ChatGPT subscription, with `codex exec --sandbox read-only`, one
  request per image. Nothing went through a paid API.
- **Style.** Scene plates reuse the shared scene-plate style block from
  `docs/design/2026-08-16-scene-plates/README.md` › *Shared style block*.
  Figures reuse the style-bible block and its construction clause, as recorded
  for the Keeper in `docs/art-ledger.md`.
- **Defect.** The scene-plate prompts lost the block's first two lines
  ("Cinematic gothic fantasy key art, painterly and richly rendered, in the
  visual language of a stained-glass world: deep environment perspective with
  real"), and the block's trailing `## The nine subjects` heading was sent with
  them. A regeneration should send the full block. The results still held the
  style, so nothing was redone.
- **Transparency.** Layers ask for a transparent PNG with the clause the
  Keeper's portraits use. Every layer came back with real alpha, so no chroma
  key or matte was needed.
- **References.** Requests that keep a character's design read its shipped
  figure as a reference image:
  - `meta/keeper.png`
  - `meta/hollow-lamplighter.png`
  - `heroes/duskblade.png`
  - `enemies/sovereign.png`
  - `ui/lantern.png`

## Files

Each file is the generated original, re-encoded to WebP at quality 90 and the
same size. The prompts are in `prompts/<name>.txt`.

| File | Size | Use on the page |
|---|---|---|
| `art/act1.webp` | 1536×1024 | Act I, The Ashen Woods: background plate |
| `art/act2.webp` | 1536×1024 | Act II, The Sunken City: background plate |
| `art/act3.webp` | 1536×1024 | Act III, The Obsidian Court: background plate |
| `art/door.webp` | 1536×1024 | Chapter XI, the sealed door (closed, nothing behind it) |
| `art/prologue-bg.webp` | 1536×1024 | Prologue background: the road at night |
| `art/prologue-shards.webp` | 1254×1254 RGBA | Six emberglass shards, split into six sprites for the "one fire into six" animation |
| `art/hero-keeper.webp` | 1024×1536 RGBA | The Keeper layer, seated on the hearth step of `scenes/opening-hearth.png` |
| `art/hero-fg.webp` | 1536×1024 RGBA | Hero foreground: hall pillars and coals |
| `art/keeper-lantern-scene.webp` | 1536×1024 | Chapter III, the gift of the lantern |
| `art/lantern.webp` | 1024×1536 RGBA | The pilgrim's lantern, a swinging layer |
| `art/duskblade-scene.webp` | 1536×1024 | Chapter IV, the road east. Stands in until a 3D Duskblade exists. |
| `art/lamplighter-scene.webp` | 1536×1024 | Chapter VI, the Unlit Way |
| `art/sovereign-scene.webp` | 1536×1024 | Chapter X, the Eternal Sovereign on his throne |
| `art/act1-fg.webp`, `art/act2-fg.webp`, `art/act3-fg.webp` | 1536×1024 RGBA | Per-act foreground frames for parallax |
| `art/way-emblems.webp` | 1942×809 RGBA | Shatter, Lantern and Edge emblems, split into three |

### Second batch — concept art and mechanism backdrops

Generated the same way, with the **full** shared scene-plate style block (the
first batch's defect is fixed here). Each request read its shipped art as a
reference image, named in its prompt file. These are labelled "Concept art" on
the page.

| File | Size | Reference | Use on the page |
|---|---|---|---|
| `art/vigil-exterior.webp` | 1536×1024 | `map-concepts/act1-vigil-hall.png` | Chapter II: the Vigil from the road at dusk, a walker leaving east. No figure at the hall. |
| `art/merchant.webp` | 1536×1024 | `props/merchant.png` | Chapter VII backdrop: the Merchant's night stall |
| `art/gambler.webp` | 1536×1024 | `events/gambler.png` | Chapter VII concept panel |
| `art/wounded-knight.webp` | 1536×1024 | `events/woundedKnight.png` | Chapter VII concept panel |
| `art/flesh-trader.webp` | 1016×1024 | `events/fleshTrader.png` | Chapter VII concept panel. Cropped from 1536 wide to drop a round red window in the background that reads as the Rose Window. |
| `art/tidecaller.webp` | 1536×1024 | `enemies/tidecaller.png` | Chapter VIII inset |
| `art/monument.webp` | 1536×1024 | `map-concepts/shared-standing-monument.jpg` | Backdrop of the pilgrimage-loop diagram: one monument with a card set in it |
| `art/kindle.webp` | 1536×1024 | `ui/lantern.png` | Backdrop of the turn diagram: a card fed to the lantern |
| `art/shatter.webp` | 1536×1024 | `enemies/duskfang.png` | Backdrop of the shatter diagram |

### Third batch — layered scenes and the Lamplighter redone

Chapters II, III and VI became parallax scenes built from separate layers, each
generated with the reference named in its prompt file: a background plate with
the full style block, then transparent figure and foreground layers. Figure
layers are cropped to their bounding box; the page places and sizes them.

| Files | Reference | Chapter |
|---|---|---|
| `art/vigil-bg.webp`, `art/vigil-hall.webp`, `art/vigil-walker.webp`, `art/vigil-fg.webp` | `art/vigil-exterior.webp` | II: sky and road, the hall, the walker leaving east, the foreground frame. No figure at the hall. |
| `art/lantern-bg.webp`, `art/lantern-keeper.webp`, `art/lantern-fg.webp` | `art/keeper-lantern-scene.webp`; `meta/keeper.png` for the figure | III: the hall and hearth, the Keeper kneeling to offer the lantern (the Keeper's one appearance on the page), the pillar and coals |
| `art/lamp-bg.webp`, `art/lamp-figure.webp`, `art/lamp-fg.webp` | `meta/hollow-lamplighter.png` | VI: the Unlit Way in a storm, the Lamplighter raising his dead lantern, wind-bent grass |

`art/lamplighter-scene.webp` is off the page: its lantern is lit, and the
Lamplighter's lantern holds no flame. The new figure's lantern is dark.

## Footage

`footage/turn.mp4` and `footage/shatter.mp4` are recorded from the game, not
generated. Godot 4.7.2 ran the real Main into a bench fight (`--fight=alphaFang
--kind=normal --seed=7`, pad-landscape) under `xvfb-run` with the OpenGL
compatibility renderer and the movie writer (`--write-movie`, 30 fps).
`footage/fight_driver.gd.txt` is the driver: it plays a Strike, Kindles a
Defend, uses the Lantern Art, Strikes again and ends the turn through the
combat screen's own request paths.

One thing is staged and is said here so the clip is not over-read: before the
first card the driver sets the foe two facets from breaking and the lantern to
two Embers, so a single turn shows a chip, a Kindle, an Art and a shatter.
Everything after that is the game's own resolution. The compatibility renderer
is not the shipping mobile renderer, so colour and grading differ slightly; a
map capture made the same way looked wrong for that reason and was not used.
`shatter.mp4` is a crop of the same take around the foe, slowed to 0.7×.

## Promoted for the live home page

The home page at glassvow.eugnel.com is built from this work by
`tools/teaser_page.py` and `tools/story_page.py` (template
`tools/story_page.html`, copy `tools/story_copy.json`). Two inputs came from
unmerged branches and are promoted here on the owner's approval (3D foes, round
4 review: "3d is good"; the unnamed card, round 2: "keep the mythics"):

| Files | Source |
|---|---|
| `models/gravewarden.glb` | `lab/rig-round4-handoff` at `6d02a484`: `lab/rig-round4/mobs/gravewarden/rig-round4-housing1/gravewarden.glb` |
| `models/siren.glb` | same commit: `lab/rig-round4/mobs/siren/rig-contact-batch/siren.glb` |
| `models/watcherEye.glb` | same commit: `lab/rig-round4/mobs/watcherEye/rig-contact-batch/watcherEye.glb` |
| `mythic/bankedFire-B-L0.jpg` … `L5.png` | research branch at `c70766cf`: `research/mythic-art/round4/bankedFire-B-L0` … `L5` |

Each copy is byte-identical to its source. `build_site.py --media` moves each
model's one embedded JPEG out beside it (`<name>-skin.jpg`), because the site's
Content-Security-Policy admits no `blob:` URL, which three.js would otherwise use
for embedded textures.

## Storage

From this batch on, the folder's WebP, MP4 and JPEG files, the models and the
unnamed card's layers are tracked by Git LFS (`.gitattributes`). The first two batches were committed as ordinary blobs
and are re-added here as LFS pointers; their history is not rewritten.

## Spoiler review

Every subject was checked against `docs/story/00-truth.md`, the foreshadow
ledger and `docs/story/04-delivery.md`:

- Acts I–III only. No Act IV, no mirror road, no un…Self figures.
- No unsealing imagery. The door is closed and dark, with no monuments queued
  before it and no rose window.
- The Keeper is shown only as the warm figure at the hearth, never beside the
  Sovereign.
- The Act I plate shows a few roadside monuments as landmarks only, as the
  Ashen Woods canon describes them.

The second batch was checked the same way:

- The Vigil appears only as a building. The Keeper is not in it.
- The Merchant's mask is shown, not explained. His origin stays unread.
- The Wounded Knight is dying, not shown becoming a monument.
- The monument stands alone, with no queue of stones before a door.
- The Flesh Trader crop removes the round window (see above).
- The page's old pilgrimage diagram showed a fall, a monument and a return to
  the Vigil. That loop reads as a spoiler, so the page now shows only the
  choice of paths, and `art/monument.webp` is no longer used on it.

The emberglass mural (`meta/emberglass-mural.png`) was left off the page: its
panes show a line of figures that reads as the Queue.

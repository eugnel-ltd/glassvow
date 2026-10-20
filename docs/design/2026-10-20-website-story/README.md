# Website story art (2026-10-20)

Art made for the storytelling home page of glassvow.eugnel.com: the eleven story
chapters through Acts I–III. None of it is in `assets/`, so the game does not
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

The emberglass mural (`meta/emberglass-mural.png`) was left off the page: its
panes show a line of figures that reads as the Queue.

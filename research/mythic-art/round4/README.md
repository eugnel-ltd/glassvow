# Mythic card art, round 4 (research)

Art research for the six mythic cards. Tracking issue: #738. Nothing here is a production asset. Nothing in this folder enters `assets/` until the owner picks (#739) and the engine decision lands (#740, #741).

This folder is a copy of the engine lane folder `mythic-art-layers-4/`, published on 17 Oct 2026 so cloud agents can reach it. The parent folder has a `.gdignore`, so Godot does not import it.

## Cards and candidates

Card ids: `bankedFire`, `silvering`, `unbrokenFlame`, `unbowed`, `knownRoad`, `cleanBreak`. Each card has candidate A and candidate B, two compositions inside one look. `LOOKS.md` gives each card's camera, world, light, palette and layer recipe.

## Files

| File | What it is |
|---|---|
| `set-overview.jpg` | All twelve flats, full size and at 64 px |
| `sheet-<card>-<A\|B>.jpg` | Layers, lean −1 / 0 / +1, small-size reads. Start here to review. |
| `<card>-<A\|B>-motion.mp4` | 4 s preview. Offline approximation, not the shader. |
| `<card>-<A\|B>-flat.jpg` | The layers recomposited at lean 0, visible window only |
| `<card>-<A\|B>-layers.json` | The authority for each pack: painter order, depth, effect, texture list |
| `<card>-<A\|B>-L<n>.png` / `-L0.jpg` | The layers (L0 is the opaque back) |
| `<card>-<A\|B>-contact-lock.json`, `-checks.json`, `-contact-mask.png` | Acceptance data per candidate |
| `acceptance.json` | Acceptance for all twelve |
| `sources/<name>/generated.png` | The 61 generated source images, with prompts beside them |
| `generation-count.jsonl` | Every image-generation call, in order |
| `briefs/` | The lane briefs for rounds 1 to 4 |
| `*.py` | Build, preview and validation scripts |

## Layer geometry

- Canvas 2304 × 1546. Visible window 2048 × 1374 at (128, 86).
- Total travel at lean ±1 is at most 123 px on any layer, including rotation and shear.
- A grounded subject shares its support's transform. Contact slide is 0 px at lean −1, 0, +1 on all twelve.
- RGBA layers are resampled in premultiplied float. Key-colour spill is 0 px on every layer.

## Known gaps

- The stage-B lane stopped before its write-up. `NOTES.md` and `ENGINE-NOTES.md` describe the A set only. `LOOKS.md` has no §6 rows for B. The B packs are complete; read `<card>-B-layers.json`.
- Sources are 1536 × 1024, upscaled about 1.5×, so fine texture is soft at full size.
- No Godot run, shader or device measurement exists for these packs.

## Scripts

The scripts find their root from their own location, so they run from this folder. They need Python 3 with Pillow, numpy and OpenCV, and ffmpeg for previews. `generate.py` calls a local image tool that exists only on the owner's MacBook Pro; a cloud agent cannot generate new sources with it.

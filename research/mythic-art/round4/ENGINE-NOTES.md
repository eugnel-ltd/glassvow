# Round-four layer handoff

Six A candidates only. Art research; no branch, PR, CI, Godot run or production asset write. Every motion preview is an **offline approximation, not the shader**. The full-resolution layer canvas is 2304 × 1546. The visible window is 2048 × 1374 at (128, 86). Generated sources are normally 1536 × 1024; the world canvas therefore upscales them about 1.5 times. The final inspected dimensions are recorded in each layer manifest.

`<cardId>-A-layers.json` is the authoritative painter order, depth, effect and texture inventory. Back layers are opaque JPEG q90. Other renderable layers are straight-alpha RGBA PNG. The final emission mask is greyscale. All are pixel aligned. Flats are neutral composites, not extraction sources. New generated back, ground and front plates are independent for every card.

| Card | Textures | Back / support / front travel | Card-specific layers and behaviour |
|---|---|---|---|
| Banked Fire | 8 | −6 / +22 / +106 px | Diagonal ash ribbon +12 behind the stone; stone and ember share the support; white-hot core reveal past lean +0.3 follows the same transform. |
| Silvering | 8 | −20 / +40 / +86 px | Complete mirror, raised-blade reflection and lowered-blade walker; copy's upper body shears oppositely (up to 30 px) while its foot band stays registered. |
| The Unbroken Flame | 14 | 0 / +10 / +48 px | Housing with cold backing, amber-to-white chamber light, six indexed pane layers, one flame core. Panes slide inward up to 34 px, tint white-gold and thin out under positive lean. |
| Unbowed | 6 | −12 / +58 / +64 px | Back and front rotate 2.5° about (1400, 1280) with the world; the figure, boots and level road do not rotate. |
| The Known Road | 9 | −3 / +4 to +90 shear / +118 px | Arch body, door leaf (narrows about its left hinge), pale-gold backlight with halo, and shadow (shears about the threshold). Door depth equals the ground row at its contact. |
| Clean Break | 9 | +1 / +3 / +14 px | Two pane halves with a fixed 3 px offset, lifted blade, seam light (absent at −1, 0.8 at 0, full from +0.25). Shallow depth keeps the overhead read. |

Lean drives depth, focal-only sheen, heat, inward petal motion, world rotation, door opening, shadow swing and seam reveal. Time drives a sparse looping particle drift, plus Silvering's half-breath lag. The four-second proof sweep runs −1 → +1 → −1. H.264 files are 1024 px wide at 24 fps; GIFs are 640 px wide, 24 frames and at most 5 MB. Temporary video and GIF outputs are decoded and checked before replacing final files.

Design §5.2 specifies angle-driven effects, at most two samplers, no added pass and no backbuffer copy. These separate texture packs and optional time motion do not prove that contract. The two engine options remain one multi-texture shader, requiring an explicit sampler budget, or stacked TextureRects with small materials, requiring an explicit pass and composition budget. The A12 sampler limit remains a device constraint. This lane selects neither option and makes no shader or device-performance claim. The amber M0 frame is not rendered by the art-only preview.

Texture counts above include the greyscale emission mask. The Unbroken Flame's 14 textures (six panes plus chamber light) is the largest pack; a single-shader option would need to pack the six panes into one indexed texture (`unbrokenFlame-A-petal-index.png` holds the pane index) to stay near the two-sampler limit.

Inspection limitations: sources are 1536 × 1024 upscaled about 1.5 times, so fine texture is soft at full size. The GIFs use at most 128 colours; the Unbroken Flame's far-lean white-gold reads as cream in the GIF and correctly in the MP4. All checks are offline; none measures a shader, a frame time or a device.

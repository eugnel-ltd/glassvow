# Lane brief: mythic art in layers (fix round)

Date: 15 Oct 2026. Orchestrator: the Glassvow orchestrator session.

Read the lane rules first. They bind: `/Users/jamesto/Coding/glassvow/.claude/skills/glassvow-orchestrator/references/lane-rules.md`.

## Seat clause

You run on the seat (Mac mini). The repo and the tools are on the engine (MacBook Pro).

- Run `zsh /Users/jamesto/Coding/glassvow/.claude/skills/glassvow-orchestrator/references/mbp.sh --where`, then `... mbp.sh --check` once.
- Run every shell command on the engine through `zsh .../mbp.sh -c '<pipeline>'`. This includes Python, ffmpeg and the image-gen script.
- Your Read, Write and Edit tools on the seat edit the engine's files directly at the same absolute path.
- Do not run git. Do not run Godot. This round has no branch, no PR and no CI.
- One Bash call stops after 10 minutes. Run long batches in the background on the engine (`nohup ... > log 2>&1 &`) and poll the log.
- Never run a broad `find` over `/Users/jamesto`. Search only inside the paths named in this brief.

## Outcome

Two layered candidates for each of the six mythic cards. The owner picks from them. Each candidate is one flat plate plus separate layers. A later engine lane will give each layer its own depth, VFX and motion in a new mythic hologram.

## Owner decisions (15 Oct 2026, verbatim intent)

- "do multi layer for mythic cards, so when we do the holo it become much more impressive. and we can do vfx effect (and/or animation/motion) for specific layer, or different vfx for each layer."
- "some of those are too 'normal' like the guarantee one, just a red dot on the stone rack? please do again."
- The round-1 page with the A/B picks is superseded. Do not reuse a round-1 plate as a candidate.

## What the pilot proved

A pilot lane did bankedFire A and B and stopped at its gate (4 calls). The direction holds: B (a large shuttered iron lantern) is the strongest composition; A (an ember heart) has the best amber read at 64 px. The layer method failed:

- Layers were cut out of a finished flat plate and L0 was inpainted. Under parallax, the cut edges and the soft inpainted patch showed.
- A's source arrived at 1881×836. The cover fit clipped the coal's left edge.
- B's bracket was clipped at the top and carried blue backdrop colour in its edge pixels.
- B's handle and bracket sat on different layers, so they separated when the card tilted.

This round fixes the method. Read the pilot's evidence before you start (see "Read only these").

## Lane folder

`/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art-layers-2/`. Create it. Write only inside it.

The pilot folder `/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art-layers/` is read-only to you. You may read and copy from it (scripts, B's flat plate). Never write, move or delete there.

## Read only these

1. `/Users/jamesto/Coding/glassvow/docs/design/2026-10-15-mythic-set/README.md`: the rule of each card (search for each card name), §5 (from line 662) and §6.
2. `/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art/generate.py`: reuse its STYLE text, its three style references, its bans, its prompt shape and its load and disk guards.
3. `/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art/sheet-*.jpg` and `NOTES.md`: round 1, so that you know what was "too normal".
4. `/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art/sheets.py`: reuse its 148×91 crop and 64 px preview method.
5. The pilot folder: `NOTES.md`, `ENGINE-NOTES.md`, `sheet-bankedFire.jpg`, `pilot-misses.jpg`, `pilot-mid-sweep.jpg`, and the scripts `generate.py`, `backgrounds.py`, `layers.py`, `preview.py`. Reuse what works.

Do not read the rest of the repository.

## The six cards and their hologram (design §5.2)

| Card id | Hologram | Effect |
|---|---|---|
| bankedFire | Lantern | Cold art. Past a threshold lean the coal flares white-hot under the ash and the frame turns amber. |
| silvering | Shade | A pale copy lags behind and moves the other way. |
| unbrokenFlame | Six into one | Six coloured shards in a six-petal mask slide into one white-gold flame. Motes drift in front. |
| unbowed | Will not tilt | Inverse parallax: the picture stays level. |
| knownRoad | Door | An arched door's shadow swings. At the far lean a slit of light appears. |
| cleanBreak | Clean seam | One straight fracture lights at one lean and vanishes at the other. |

knightMonument is a scene plate, not a mythic card. It is out of scope.

## Composition direction

Round 1 failed because the subject was small and ordinary. Banked Fire read as "a red dot on a stone". Every candidate must have one large, iconic, strange focal subject that fills the central third or more. The hologram must have something to act on: give its moving part its own layer.

Starting points. You own the art direction and may go further. A and B must be different compositions, not two variants of one.

- **bankedFire.** A: the huge banked ember heart under cracked ash plates, molten amber seams in the cracks, in a cracked hearth. The whole coal must sit inside the window or the overscan; never clip it. B: the shuttered iron lantern banked with ash, light leaking through vents and seams. Keep §6: cold blue-grey world, amber is the only warm colour, no flame tongue (the hologram supplies the flare).
- **silvering.** A faceless figure before a tall arched mirror; the reflection is a pale silver double that steps out of the glass the other way. The double is its own layer.
- **unbrokenFlame.** Six coloured glass shards in a six-petal rose window converge on one white-gold flame. Each shard is separable, as one layer each or one layer plus an index mask.
- **unbowed.** A faceless upright figure planted level while the whole world sweeps on a hard diagonal: ash rain, bent trees, a toppling pillar. The figure is its own layer and stays level; the world layers tilt.
- **knownRoad.** Converging flagstones to a towering arched door ajar, a blade of light in the gap. The door leaf, its shadow and the light slit are separate layers.
- **cleanBreak.** A great pane, shield or blade split by one perfectly straight bright seam; the halves slightly offset. Each half and the seam are separate layers.

Look at the other round-1 plates. If one is "normal" in the same way, fix it the same way.

## The layer method (binding)

### Overscan canvas

- Every layer is 2304×1546 px.
- The visible window is 2048×1374 px at offset (128, 86). This is the card art area.
- The maximum parallax shift at lean ±1 is about 123 px (about 6% of the width). No layer may move further.
- The flat plate is the window crop of the recomposited layers at lean 0, 2048×1374.
- Image-gen returns about 1536×1024, so the canvas is an upscale of about 1.5×. Say so in NOTES and note any visible softness.

### The layers are the truth

- Make a complete L0 first, with no hole behind the subject by construction: generate the backdrop as its own plate (the scene with no subject), or paint it procedurally. Do not inpaint a hole in a finished plate.
- Build every other layer as its own complete object, then composite. The flat plate is the result of that composite, not its source.
- You may generate a hero plate first to fix the composition. Compare the recomposite with the hero for composition only, not pixel by pixel.

### Matte, per layer (your choice)

- **Lead-line cut.** Where the subject has a dark outline (iron, lead came, ash crust), cut along the middle of that line. Drop the outer half and keep the inner half, so no backdrop colour enters the edge.
- **Key-colour regeneration.** Where a layer needs content that the hero hides, or has no outline, regenerate the subject on a flat key colour that the card's palette does not use, then key it out with despill.

### Attachment rule

Two parts that touch in the picture must survive relative motion. Choose one per contact:

- Put both parts on the same layer.
- Hide the contact behind an occluder or mist on a nearer layer.
- Let the subject float, with no contact.

Only L0, and edge-running occluders that extend into the overscan, may touch the frame.

### Acceptance (check every layer of every candidate)

1. No fringe and no halo over a checkerboard and over a contrasting flat colour.
2. No backdrop colour in semi-transparent pixels.
3. No cut edge and no hole visible at lean −1 and +1 with the maximum shift.
4. Attached parts stay together through the sweep.
5. The flat plate reads at the 148×91 crop and at 64 px.
6. Look at the preview frames yourself (lean −1, 0, +1). Numbers alone do not pass a candidate.

## Layers per candidate

| Layer | Content | Format |
|---|---|---|
| L0 | Backdrop, complete, no hole | JPEG q90 |
| L1 | Midground | PNG RGBA |
| L2 | Focal subject | PNG RGBA |
| L3 | Foreground occluders (omit if the composition has none, and say so) | PNG RGBA |
| L4 | Particles and atmosphere: embers, ash, motes | PNG RGBA |
| L5 | Emissive or glow mask | PNG greyscale |
| Card-specific | The moving part of the hologram (double, shard, door leaf, shadow, seam, halves) | PNG RGBA or mask |
| Flat | The flattened plate, window crop at lean 0, 2048×1374 | JPEG q90 |

All layers except the flat are 2304×1546 and pixel-aligned. Name files `<cardId>-<A|B>-L0.jpg`, `-L1.png` and so on, and `<cardId>-<A|B>-flat.jpg`. Write a `<cardId>-<A|B>-layers.json` with each layer's file, depth and effect.

## Pilot gate

Do bankedFire A and B again first, end to end: layers, flat, acceptance checks, alpha proof and motion preview.

- B may reuse the pilot's B flat plate (`/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art-layers/bankedFire-B-flat.jpg`) as the composition hero. Copy it into your folder; do not edit it in place.
- A needs a new hero in which the whole coal fits.

Look at the result yourself against the acceptance list. If the method still fails, stop and report the pilot with its evidence. If it holds, continue with the other five cards without asking.

## Motion preview

For each candidate, make an offline approximation of a tilt sweep (lean −1 → +1 → −1, about 4 s). Give each layer a parallax depth within the 123 px cap, and apply the card's hologram and per-layer effects: L5 glow driven by lean, L4 drift, a sheen on the focal layer only, and the card-specific motion from the table above. Show only the window. Label it "offline approximation, not the shader".

Output an MP4 (H.264, 1024 px wide) and a GIF (640 px wide, at most 5 MB) per candidate.

§5.2 says the hologram is "angle, not time". The owner now asks for animation and motion per layer. Mark which effects in your preview are driven by lean and which by time. Do not decide the rule; the engine lane and the owner will.

## Guards

- Generate with `~/.claude/scripts/subagents/run-imagegen.sh "<prompt>"` on the engine, one call at a time, never in parallel.
- Before each call: wait while the 1-minute load average is above 50; stop and report if free disk is below 100 GiB. At 19:25 the load was 6.5 and free disk was 107 GiB. Keep files lean.
- Budget: at most 68 image-gen calls in total, including retries, about 5 per candidate as a soft cap. Log every call to your own `generation-count.jsonl` in your lane folder. If you reach the cap, stop and report what you have.
- Same style for all plates: the STYLE text, the three style references and the bans from `generate.py`. No text, letters, numerals, glyphs or runes. Faceless figures. No card chrome.
- Nothing into `assets/`. Nothing outside the lane folder.
- Delete only inside the lane folder, by literal absolute path, checking and deleting as separate commands. Never derive a delete path from `OS.get_cache_dir()`, `OS.get_user_data_dir()`, `OS.get_data_dir()`, `$HOME`, `~/Library` or any system path. Never touch `~/Library/Application Support/Godot/app_userdata/`.
- Never print a token, key or account id.

## Deliverables

1. The layer files for 12 candidates.
2. One contact sheet per card (`sheet-<cardId>.jpg`): A and B flats; a strip of their layers over a checkerboard; lean −1 and +1 frames; the 148×91 crop and the 64 px preview.
3. The motion previews (MP4 and GIF) per candidate.
4. `ENGINE-NOTES.md`, one page: per card, the layer list, the depth of each layer, the per-layer effect and the texture count. Flag the conflict with §5.2 (at most 2 samplers, no added pass, no backbuffer copy) and the A12 sampler limit. Name the two engine options (one multi-texture shader, or stacked TextureRects each with a small material) in one paragraph. Do not design the engine.
5. `NOTES.md`: the method, the acceptance result per candidate, the generation count and any misses.

## Report

Report as the lane rules say: the files, the contact sheets, the motion previews, your recommendation per card, the acceptance result, the misses and the generation count. End with a short Hong Kong Cantonese paragraph. Then stop.

# Lane brief: mythic art in layers (candidates round 2)

Date: 15 Oct 2026. Orchestrator: the Glassvow orchestrator session.

Read the lane rules first. They bind: `/Users/jamesto/Coding/glassvow/.claude/skills/glassvow-orchestrator/references/lane-rules.md`.

## Seat clause

You run on the seat (Mac mini). The repo and the tools are on the engine (MacBook Pro).

- Run `zsh /Users/jamesto/Coding/glassvow/.claude/skills/glassvow-orchestrator/references/mbp.sh --where`, then `... mbp.sh --check` once.
- Run every shell command on the engine through `zsh .../mbp.sh -c '<pipeline>'`. This includes Python, ffmpeg and the image-gen script.
- Your Read, Write and Edit tools on the seat edit the engine's files directly at the same absolute path.
- Do not run git. Do not run Godot. This round has no branch, no PR and no CI.
- One Bash call stops after 10 minutes. Run long batches in the background on the engine (`nohup ... > log 2>&1 &`) and poll the log.

## Outcome

Two layered candidates for each of the six mythic cards. The owner picks from them. Each candidate is one flat plate plus separate layers. A later engine lane will give each layer its own depth, VFX and motion in a new mythic hologram.

## Owner decisions (15 Oct 2026, verbatim intent)

- "do multi layer for mythic cards, so when we do the holo it become much more impressive. and we can do vfx effect (and/or animation/motion) for specific layer, or different vfx for each layer."
- "some of those are too 'normal' like the guarantee one, just a red dot on the stone rack? please do again."
- The round-1 page with the A/B picks is superseded. Do not reuse a round-1 plate as a candidate.

## Lane folder

`/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art-layers/`. Create it. Write only inside it.

## Read only these

1. `/Users/jamesto/Coding/glassvow/docs/design/2026-10-15-mythic-set/README.md`: the rule of each card (search for each card name), §5 (from line 662) and §6.
2. `/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art/generate.py`: reuse its STYLE text, its three style references, its bans, its prompt shape and its load and disk guards.
3. `/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art/sheet-*.jpg` and `NOTES.md`: round 1, so that you know what was "too normal".
4. `/Users/jamesto/Coding/glassvow/.claude/worktrees/mythic-art/sheets.py`: reuse its 148×91 crop and 64 px preview method.

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

- **bankedFire.** The coal is the subject, not a detail. Ideas: a huge banked ember heart under cracked ash plates, molten amber seams glowing through the cracks, in a cracked hearth; or a shuttered iron lantern banked with ash, light leaking through its vents and seams. Keep §6: cold blue-grey world, amber is the only warm colour, no flame tongue (the hologram supplies the flare).
- **silvering.** A faceless figure before a tall arched mirror; the reflection is a pale silver double that steps out of the glass the other way. The double is its own layer.
- **unbrokenFlame.** Six coloured glass shards in a six-petal rose window converge on one white-gold flame. Each shard is separable, as one layer each or one layer plus an index mask.
- **unbowed.** A faceless upright figure planted level while the whole world sweeps on a hard diagonal: ash rain, bent trees, a toppling pillar. The figure is its own layer and stays level; the world layers tilt.
- **knownRoad.** Converging flagstones to a towering arched door ajar, a blade of light in the gap. The door leaf, its shadow and the light slit are separate layers.
- **cleanBreak.** A great pane, shield or blade split by one perfectly straight bright seam; the halves slightly offset. Each half and the seam are separate layers.

Look at the other round-1 plates. If one is "normal" in the same way, fix it the same way.

## Layers per candidate

All layers 2048×1374 and pixel-aligned with the flat plate.

| Layer | Content | Format |
|---|---|---|
| L0 | Backdrop, a clean plate with no hole behind the subject | JPEG q90 |
| L1 | Midground | PNG RGBA |
| L2 | Focal subject | PNG RGBA |
| L3 | Foreground occluders (omit if the composition has none, and say so) | PNG RGBA |
| L4 | Particles and atmosphere: embers, ash, motes | PNG RGBA |
| L5 | Emissive or glow mask | PNG greyscale |
| Card-specific | The moving part of the hologram (double, shard, door leaf, shadow, seam, halves) | PNG RGBA or mask |
| Flat | The flattened plate | JPEG q90 |

Name files `<cardId>-<A|B>-L0.jpg`, `-L1.png` and so on, and `<cardId>-<A|B>-flat.jpg`.

## Method

You choose the layer method and the alpha method. rembg is not installed. PIL 10.4.0, numpy 1.26.4 and ffmpeg are available. A suggested method:

1. Generate the flat plate first, as the hero.
2. Derive each layer with an image-to-image pass that uses the flat plate as a reference (absolute path in the prompt): the same subject, position and scale, on a flat key colour. Choose a key colour that the card's palette does not use.
3. Generate the clean backdrop L0 as "the same scene with the subject removed and the background continued".
4. Make L5, and L4 where it works, procedurally from the layers. That costs no generation call.
5. Re-composite the layers and compare with the flat plate. If a layer drifts, re-register it (for example a translation and scale fit with numpy). Report the residual difference per layer.

Prove the alpha: each RGBA layer over a checkerboard and over a contrasting flat colour, with no key-colour fringe and no halo.

## Pilot gate

Do bankedFire A and B first, end to end: flat, layers, alignment check, alpha proof and motion preview. Look at the result yourself. If the layer method cannot hold alignment or clean edges, stop and report the pilot with its evidence. If it holds, continue with the other five cards without asking.

## Motion preview

For each candidate, make an offline approximation of a tilt sweep (lean −1 → +1 → −1, about 4 s). Give each layer a parallax depth, and apply the card's hologram and per-layer effects: L5 glow driven by lean, L4 drift, a sheen on the focal layer only, and the card-specific motion from the table above. Label it "offline approximation, not the shader".

Output an MP4 (H.264, 1024 px wide) and a GIF (640 px wide, at most 5 MB) per candidate.

§5.2 says the hologram is "angle, not time". The owner now asks for animation and motion per layer. Mark which effects in your preview are driven by lean and which by time. Do not decide the rule; the engine lane and the owner will.

## Guards

- Generate with `~/.claude/scripts/subagents/run-imagegen.sh "<prompt>"` on the engine, one call at a time, never in parallel.
- Before each call: wait while the 1-minute load average is above 50; stop and report if free disk is below 100 GiB. Free disk was 107 GiB at 18:01. Keep files lean.
- Budget: at most 72 image-gen calls in total, including retries. Log every call to `generation-count.jsonl`. If you reach the cap, stop and report what you have.
- Same style for all plates: the STYLE text, the three style references and the bans from `generate.py`. No text, letters, numerals, glyphs or runes. Faceless figures. No card chrome.
- Each flat plate must read at the 148×91 crop and at 64 px.
- Nothing into `assets/`. Nothing outside the lane folder.
- Delete only inside the lane folder, by literal absolute path, checking and deleting as separate commands. Never derive a delete path from `OS.get_cache_dir()`, `OS.get_user_data_dir()`, `OS.get_data_dir()`, `$HOME`, `~/Library` or any system path. Never touch `~/Library/Application Support/Godot/app_userdata/`.
- Never print a token, key or account id.

## Deliverables

1. The layer files for 12 candidates.
2. One contact sheet per card (`sheet-<cardId>.jpg`): A and B flats; a strip of their layers over a checkerboard; the 148×91 crop and the 64 px preview.
3. The motion previews (MP4 and GIF) per candidate.
4. `ENGINE-NOTES.md`, one page: per card, the layer list, the depth of each layer, the per-layer effect and the texture count. Flag the conflict with §5.2 (at most 2 samplers, no added pass, no backbuffer copy) and the A12 sampler limit. Name the two engine options (one multi-texture shader, or stacked TextureRects each with a small material) in one paragraph. Do not design the engine.
5. `NOTES.md`: the method, the alignment residuals, the generation count and any misses.

## Report

Report as the lane rules say: the files, the contact sheets, the motion previews, your recommendation per card, the misses and the generation count. End with a short Hong Kong Cantonese paragraph. Then stop.

# SFX ledger — ashglass-v1-unsealing

Port-scoped inventory of the sound pack Glassvow ships. The full generation
ledger (prompt set, category law, render pipeline) lives at
`../roguecardv2-benchmark/docs/sfx-ledger.md` (roguecardv2@6e06911).

Dispatch for new samples: `.claude/skills/glassvow-elevenlabs/SKILL.md`.
MCP config (IDE): `.cursor/mcp.json` → `elevenlabs`. Cloud Agents do not
read that file; register the same stdio server in the cursor.com/agents
MCP dropdown and put `ELEVENLABS_API_KEY` on the environment. The hosted
ElevenLabs MCP at `https://api.elevenlabs.io/v1/mcp` is Agents/TTS — not
this pack. REST fallback is `POST /v1/sound-generation`.

## What

The immutable **ashglass-v1** pack: 36 one-shot sounds at
`assets/audio/sfx/`, plus the **ashglass-v1-unsealing** addendum
(`unsealingSting`). Theme: Ashglass Vigil — glass, ash, lantern, and the
small metallic ticks of a climb. `pack_id` is `ashglass-v1-unsealing`.
v1 bytes stay untouched.

## Provenance

Synthesised with **ElevenLabs** (official sound-generation API) upstream in
the reference repo, where the pack was selected. This port carries the
**v1** one-shots verbatim, untrimmed as the API rendered them (`chip.mp3`
runs 0.52 s — the API's minimum). The reference's later v2 pass (tail
trims) is not what ships here. Do not re-encode or rename shipping files
without a pack bump.

## Contract

- Cue ids resolve through `SfxBus` in `presentation/audio/sfx_bus.gd`.
- `assets/audio/sfx/manifest.json` is the inventory the credits screen
  reads for the sound count and theme line.
- Playback is one-shot; looping and music beds belong to `MusicBus`.

## Shipped — unsealing sting (#377 leftover from #221)

Picked 2026-08-17, candidate **B**. Shipping copy sits at
`assets/audio/sfx/unsealingSting.mp3`; every candidate stays in
`docs/design/2026-08-17-unsealingSting/candidates/`. File stem is the
cue id. `pack_id` bumped to `ashglass-v1-unsealing`; the 36 v1 files are
byte-identical. `ScenePlayer` fires the cue once on unsealing beat 2
(窗成鏡). `SfxBus` still warns if the file is missing rather than
substituting `sealedDoor`, which stays the door/ceremony theme.

| cue | file | pick | duration | usage |
|---|---|---|---|---|
| `unsealingSting` | `unsealingSting.mp3` | **B** (`unsealingSting-b.mp3`) | 1.515 s | Unsealing beat 2 「窗成鏡」 unique sting |

Prompt that rendered (`eleven_text_to_sound_v2`, `duration_seconds` 1.5,
`prompt_influence` 0.65):

> One-shot glass sting: the six panes become a mirror. A short glass-chord inversion, warm amber bloom turning cold as the reflection takes. No choir, no vocals, no door grind, no footsteps, no long cinematic tail. Must not sound like a sealed door theme, a rose-window bed, or a tiny glass chip tick.

Do not steal a music-bus slot; this is a sting over the ceremony bed.
Beat 4’s low door-push is a separate cue.

## Pointer

For the generation bible and category law, see
`../roguecardv2-benchmark/docs/sfx-ledger.md` (roguecardv2@6e06911).
This file is the port-facing contract only.

## Commissioned — stagecraft cues (2026-09-27, not yet generated)

Billed by the dialogue stagecraft layer
(`docs/design/2026-09-27-stagecraft/README.md`); tracked in #564 under #559. `SceneDirector` already asks
for each cue by id and **plays a landed file with no code change**; until then
it falls back to the shipped cue in the table (or stays silent where none
fits). Generate through `.claude/skills/glassvow-elevenlabs/SKILL.md`, audition
in the running scene (`--stagecraft` reel), then move the row to Shipped with
its pick and bump `pack_id` — the 36 v1 files stay byte-identical.

| cue | fires on | fallback today | duration |
|---|---|---|---|
| `paneOpen` | a conversation's dialogue pane arriving (first line, or back from a title card) | silent | ~0.6 s |
| `glassCrack` | the `crack` effect (a truth landing: unsealing b3 l4, act4-node5 l2) | `chip` | ~0.8 s |
| `glassImpact` | the `impact` effect (the monuments' push, a blow) | `hit` | ~0.7 s |
| `shoutSting` | any line in the `shout` style | silent | ~0.5 s |

Prompts (`eleven_text_to_sound_v2`, `prompt_influence` 0.6, one-shot, no loop):

> **paneOpen** — A soft cathedral-glass chime as a small leaded window pane
> settles into its frame: one clear high glass tone with a faint warm
> resonance, very short, intimate, quiet. No bell tower, no choir, no whoosh,
> no UI beep, no sparkle arpeggio.

> **glassCrack** — A single sharp crack running through a thick pane of old
> stained glass: a hard brittle snap, a short splintering tick as the fracture
> spreads, then silence. Close and dry. No shatter, no falling shards, no
> impact thud, no reverb tail.

> **glassImpact** — A heavy blow landing against a great leaded window: a deep
> low thud of weight on stone and lead, the whole pane ringing once in a short
> dark glassy resonance. No explosion, no shatter, no metal sword clang.

> **shoutSting** — A short bright glass ring struck hard, like a tuning fork
> of glass hit once, with a quick warm swell under it: emphasis, not alarm.
> No voice, no vocal shout, no brass stab, no whoosh.

No voice-over and no per-character text blips: 07-scenes rules out VO (#175)
and blips are not billed.

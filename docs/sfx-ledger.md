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

## Commissioned — opening and start-up cues (2026-10-02, audition owed)

Billed by the opening lane (`docs/design/2026-10-02-opening-start/README.md`
§11). The code already asks for each cue by id through `SfxBus.play_owed`
and **plays a landed file with no code change**; until then it plays the
fallback below (or stays silent), and the missing file warns once.

| cue | fires on | fallback today | duration |
|---|---|---|---|
| `kindleCatch` | the launch rite's flame catching (0.4 s) | `kindle` | 1.6 s |
| `glassTakesLight` | the lantern's glass taking light (0.9 s) | silent | 2.0 s |
| `paneRise` | first launch: the two language panes rising | silent | 0.6 s |
| `paneChoose` | a language pane chosen; the lantern pressed | `click` | 0.7 s |
| `roomOpen` | the settings room opening | silent | 1.0 s |
| `roomClose` | the settings room closing | silent | 0.8 s |

Prompts (`eleven_text_to_sound_v2`, `prompt_influence` 0.6, one-shot):

> **kindleCatch** — One-shot: a single ember breathing in total darkness, a faint dry crackle, then a soft airy whoosh as a small candle-sized flame catches inside an iron lantern. Intimate, close-mic, warm. No music, no choir, no fire roar, no explosion, no long tail.

> **glassTakesLight** — One-shot: warm resonant glass hum swelling as light fills old stained glass, a soft crystalline shimmer and a bowed-glass tone rising gently and settling. Calm, luminous, intimate. No choir, no vocals, no bells, no whoosh, no sparkle arpeggio, no long cinematic tail.

> **paneRise** — One-shot UI sound: a small leaded glass pane sliding up into its frame, a soft glass tone with a tiny metallic tick of lead at the end. Quiet, short, close. No beep, no whoosh, no bell, no reverb tail.

> **paneChoose** — One-shot UI confirmation: a bright clear glass chime struck once with a soft warm flare under it, satisfying and short. Not a bell tower, no choir, no beep, no sparkle arpeggio, short tail.

> **roomOpen** — first batch (a–c): One-shot: an old wooden window shutter swinging open in a stone gatehouse at night, a soft wooden creak and a muffled latch, faint distant night wind behind it. Close and quiet. No door slam, no footsteps, no music. All three rendered near-silent, so the second batch (d–f) asked: One-shot, close-mic and clearly audible: an old wooden window shutter swinging open, a distinct wooden creak on its iron hinge and a soft latch lifting, in a stone room at night. Present and intimate, not distant. No door slam, no footsteps, no music, no long reverb.

> **roomClose** — One-shot: an old wooden window shutter swinging closed in a stone gatehouse at night, a soft wooden creak and a gentle muffled latch click. Close and quiet. No slam, no footsteps, no music.

Candidates sit in `docs/design/2026-10-02-opening-start/sfx/candidates/`.
Deterministic preflight (decode, duration, channels, peak, RMS, silent
fraction, last-10 ms tail); eligibility is technical only:

| file | duration | ch | peak dBFS | RMS dBFS | silent | eligible |
|---|---|---|---|---|---|---|
| `glassTakesLight-a.mp3` | 2.0 s | 2 | -4.3 | -14.3 | 0.06 | yes |
| `glassTakesLight-b.mp3` | 2.0 s | 2 | -2.9 | -12.0 | 0.03 | yes |
| `glassTakesLight-c.mp3` | 2.0 s | 2 | -5.5 | -16.4 | 0.02 | yes |
| `kindleCatch-a.mp3` | 1.6 s | 2 | -16.7 | -32.8 | 0.36 | yes |
| `kindleCatch-b.mp3` | 1.6 s | 2 | -0.5 | -15.3 | 0.34 | yes |
| `kindleCatch-c.mp3` | 1.6 s | 2 | -16.8 | -30.0 | 0.06 | yes |
| `paneChoose-a.mp3` | 0.68 s | 2 | -17.5 | -33.3 | 0.4 | yes |
| `paneChoose-b.mp3` | 0.68 s | 2 | -7.9 | -24.6 | 0.31 | yes |
| `paneChoose-c.mp3` | 0.68 s | 2 | -18.1 | -36.5 | 0.38 | yes |
| `paneRise-a.mp3` | 0.6 s | 2 | -10.2 | -31.8 | 0.22 | yes |
| `paneRise-b.mp3` | 0.6 s | 2 | -7.6 | -28.3 | 0.32 | yes |
| `paneRise-c.mp3` | 0.6 s | 2 | -10.0 | -29.8 | 0.32 | yes |
| `roomClose-a.mp3` | 0.8 s | 2 | -11.7 | -34.0 | 0.42 | yes |
| `roomClose-b.mp3` | 0.8 s | 2 | -5.1 | -34.0 | 0.56 | yes |
| `roomClose-c.mp3` | 0.8 s | 2 | -18.8 | -38.7 | 0.33 | yes |
| `roomOpen-a.mp3` | 1.0 s | 2 | -29.2 | -49.5 | 0.43 | **no** (too quiet) |
| `roomOpen-b.mp3` | 1.0 s | 2 | -26.4 | -52.5 | 0.6 | **no** (too quiet) |
| `roomOpen-c.mp3` | 1.0 s | 2 | -30.7 | -53.5 | 0.46 | **no** (too quiet) |
| `roomOpen-d.mp3` / `-e` / `-f` | 1.0 s | 2 | −28.3 / −25.1 / −18.9 | −49.9 / −46.5 / −42.8 | — | no / no / **yes** |

**Audition: not done, so nothing ships.** The lane played every eligible
candidate with `afplay` on 2026-10-02 and each returned `AudioQueueStart
failed (-66681)`: the session had no audio output device. No perceptual
criterion is scored. Owed: one owner audition per cue, then the pick moves to
`assets/audio/sfx/<cue>.mp3` with a manifest row and the `pack_id` bump
(the 36 v1 files and `unsealingSting` stay byte-identical).

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

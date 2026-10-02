# SFX ledger — ashglass-v1-opening

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
(`unsealingSting`), and the **ashglass-v1-opening** addendum (six start-up
cues, two of them rotations). Theme: Ashglass Vigil — glass, ash, lantern, and
the small metallic ticks of a climb. `pack_id` is `ashglass-v1-opening`.
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

## Shipped — opening and start-up cues (2026-10-02)

Billed by the opening lane (`docs/design/2026-10-02-opening-start/README.md`
§11). Owner audition: **James, 2 October 2026, via the audition page**; the
picks below are his, so the technical-only preflight that stood in for a
perceptual score no longer gates anything. `pack_id` bumped to
`ashglass-v1-opening`; the 36 v1 files and `unsealingSting` are byte-identical.
Every candidate stays in `docs/design/2026-10-02-opening-start/sfx/candidates/`.

`SfxBus.play_owed` asks for each cue by id. The four single cues play their
file. `roomOpen` and `roomClose` are **rotations**: each play draws one numbered
variant at random from the engine RNG (never the run's seeded RNG) through
`SfxBus.resolve`, and neither bare `roomOpen.mp3` nor `roomClose.mp3` exists.
The manifest carries one row per cue (so the credits count is cues, now 43),
with a `files` list on the rotations.

| cue | fires on | pick | files | fallback |
|---|---|---|---|---|
| `kindleCatch` | the launch rite's flame catching | **b** | `kindleCatch.mp3` | `kindle` if the file is missing |
| `glassTakesLight` | the lantern's glass taking light | **b** | `glassTakesLight.mp3` | silent |
| `paneRise` | first launch: the two language panes rising | **c** | `paneRise.mp3` | silent |
| `paneChoose` | a language pane chosen; the lantern pressed | **a** | `paneChoose.mp3` | `click` |
| `roomOpen` | the settings room opening | **b**, rotating | `roomOpen-1` = b, `-2` = d, `-3` = e, `-4` = f | silent |
| `roomClose` | the settings room closing | **c**, rotating | `roomClose-1` = a, `-2` = b, `-3` = c | silent |

`roomOpen` a and c are excluded from the rotation: near-silent
(−29.2 and −30.7 dBFS peak).

**Loudness.** The room candidates sit 15–25 dB under the other cues, so every
landed file was peak-normalised to −3 dBFS with ffmpeg (`volume=<gain>dB`,
libmp3lame 128 kbit/s, 44.1 kHz stereo, no trimming; durations are unchanged).
The mp3 re-encode moves the decoded peak by a few tenths of a dB, so the gain
was refined until the landed peak read within about ±0.4 dB of −3. Gains are
applied to the candidate file, not cumulative with any earlier gain.

Preflight re-run on the landed files (full-precision decode to float32,
per-channel sample peak, RMS over both channels; silent = share of 10 ms
windows under −60 dBFS RMS; tail = peak of the last 10 ms):

| file | cue | source candidate | gain dB | duration | peak before → after dBFS | RMS dBFS | silent | tail dBFS |
|---|---|---|---|---|---|---|---|---|
| `kindleCatch.mp3` | `kindleCatch` | `kindleCatch-b.mp3` | -2.13 | 1.600 s | -0.4 → -3.02 | -17.8 | 0.21 | -56.4 |
| `glassTakesLight.mp3` | `glassTakesLight` | `glassTakesLight-b.mp3` | +0.34 | 2.000 s | -2.9 → -3.01 | -12.1 | 0.02 | -63.7 |
| `paneRise.mp3` | `paneRise` | `paneRise-c.mp3` | +3.65 | 0.600 s | -6.6 → -3.23 | -23.6 | 0.30 | -51.0 |
| `paneChoose.mp3` | `paneChoose` | `paneChoose-a.mp3` | +14.13 | 0.680 s | -16.7 → -2.92 | -19.5 | 0.24 | -35.1 |
| `roomOpen-1.mp3` | `roomOpen` | `roomOpen-b.mp3` | +22.72 | 1.000 s | -25.3 → -3.00 | -29.2 | 0.05 | -47.5 |
| `roomOpen-2.mp3` | `roomOpen` | `roomOpen-d.mp3` | +26.43 | 1.000 s | -28.3 → -3.27 | -24.2 | 0.00 | -38.3 |
| `roomOpen-3.mp3` | `roomOpen` | `roomOpen-e.mp3` | +22.60 | 1.000 s | -25.1 → -3.13 | -24.5 | 0.06 | -46.5 |
| `roomOpen-4.mp3` | `roomOpen` | `roomOpen-f.mp3` | +16.02 | 1.000 s | -18.9 → -2.77 | -27.1 | 0.11 | -51.5 |
| `roomClose-1.mp3` | `roomClose` | `roomClose-a.mp3` | +8.49 | 0.800 s | -10.7 → -3.37 | -26.3 | 0.07 | -56.9 |
| `roomClose-2.mp3` | `roomClose` | `roomClose-b.mp3` | +1.07 | 0.800 s | -3.5 → -3.06 | -32.7 | 0.19 | -64.8 |
| `roomClose-3.mp3` | `roomClose` | `roomClose-c.mp3` | +15.71 | 0.800 s | -18.3 → -2.99 | -23.5 | 0.04 | -48.9 |

Peaks here are per-channel sample peaks of the decoded float, so the
"before" column reads up to 3 dB hotter than the candidate table the lane first
recorded (`sfx/preflight.json`), which measured a different downmix; the gain
was derived from the figures in this table. A large gain lifts the room tone:
`roomOpen-2` ends at −38 dBFS in its last 10 ms rather than near silence;
nothing was trimmed, per the owner's instruction.

**Playback check of the landed files (2026-10-02).** `afplay` returned
`AudioQueueStart failed (-66681)` on every file: the lane's session has no audio
output device, as before. So the landed files were not heard here. Core Audio
did decode each one (`afconvert` to 16-bit WAV, durations matching the table),
and the owner auditioned the unnormalised candidates on the audition page; the
landed files differ only by the gain above.

Prompts (`eleven_text_to_sound_v2`, `prompt_influence` 0.6, one-shot):

> **kindleCatch** — One-shot: a single ember breathing in total darkness, a faint dry crackle, then a soft airy whoosh as a small candle-sized flame catches inside an iron lantern. Intimate, close-mic, warm. No music, no choir, no fire roar, no explosion, no long tail.

> **glassTakesLight** — One-shot: warm resonant glass hum swelling as light fills old stained glass, a soft crystalline shimmer and a bowed-glass tone rising gently and settling. Calm, luminous, intimate. No choir, no vocals, no bells, no whoosh, no sparkle arpeggio, no long cinematic tail.

> **paneRise** — One-shot UI sound: a small leaded glass pane sliding up into its frame, a soft glass tone with a tiny metallic tick of lead at the end. Quiet, short, close. No beep, no whoosh, no bell, no reverb tail.

> **paneChoose** — One-shot UI confirmation: a bright clear glass chime struck once with a soft warm flare under it, satisfying and short. Not a bell tower, no choir, no beep, no sparkle arpeggio, short tail.

> **roomOpen** — first batch (a–c): One-shot: an old wooden window shutter swinging open in a stone gatehouse at night, a soft wooden creak and a muffled latch, faint distant night wind behind it. Close and quiet. No door slam, no footsteps, no music. All three rendered near-silent, so the second batch (d–f) asked: One-shot, close-mic and clearly audible: an old wooden window shutter swinging open, a distinct wooden creak on its iron hinge and a soft latch lifting, in a stone room at night. Present and intimate, not distant. No door slam, no footsteps, no music, no long reverb.

> **roomClose** — One-shot: an old wooden window shutter swinging closed in a stone gatehouse at night, a soft wooden creak and a gentle muffled latch click. Close and quiet. No slam, no footsteps, no music.

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

# Stagecraft glass cues: candidates (2026-09-29)

Research batch for #564, under #559. The four cues, their prompts, durations and
the pack rules are canonical in `docs/sfx-ledger.md` ("Commissioned — stagecraft
cues"); dispatch is `.claude/skills/glassvow-elevenlabs/SKILL.md`. Nothing here
ships: no file under `assets/audio/sfx/`, no manifest row, no `pack_id` bump and
no ledger row has moved.

Round 2 (four further directions per cue, after James's audition of round 1) is
recorded in the last section, "Round 2". Everything before it is round 1's record;
only the exit-status sentence under "Reproduce" was updated, to count both rounds.

## Result, and the one decision

Thirteen renders (twelve planned, plus one replacement for a technical failure)
gave **twelve technically eligible candidates, three per cue**. No approved
audio-capable evaluator auditioned any file, so **every perceptual criterion is
unscored** and the candidates are **unranked**: the letters are render order, not
preference.

**Decision requested from James:** audition the twelve shortlisted files in the
running scene (procedure below) and pick one per cue. Four names are enough, for
example `paneOpen-c, glassCrack-a, glassImpact-b, shoutSting-a`. After that single
decision the landing commit follows without another approval stop: the chosen
files to `assets/audio/sfx/<cue>.mp3`, their manifest rows, the `pack_id` bump,
the ledger rows moved to Shipped, Godot's import sidecars and the Godot gate.

| cue | target | shortlist (eligible, unranked) | dropped |
|---|---:|---|---|
| `paneOpen` | 0.6 s | `paneOpen-a`, `paneOpen-c`, `paneOpen-d` | `paneOpen-b`: fails the tail gate (sustains to the end of the file) |
| `glassCrack` | 0.8 s | `glassCrack-a`, `glassCrack-b`, `glassCrack-c` | none |
| `glassImpact` | 0.7 s | `glassImpact-a`, `glassImpact-b`, `glassImpact-c` | none |
| `shoutSting` | 0.5 s | `shoutSting-a`, `shoutSting-b`, `shoutSting-c` | none |

`candidates/` keeps the ineligible `paneOpen-b.mp3` as evidence; do not audition
it. `paneOpen-d` is the replacement render: the tail failure was the only technical
failure, and the batch stopped after that one replacement (13 of the 16 renders
the brief allows).

## Generation

The official sound-generation REST endpoint, one request per render, sequential,
on 2026-09-29 between 15:08 and 15:15 UTC.

| parameter | value |
|---|---|
| endpoint | `POST /v1/sound-generation`, `output_format=mp3_44100_128` |
| `model_id` | `eleven_text_to_sound_v2` |
| `prompt_influence` | 0.6 |
| `loop` | `false` (one-shot) |
| `duration_seconds` | the ledger target for the cue (column below) |
| `text` | the ledger prompt for the cue, verbatim (below) |

The endpoint takes no seed, so a render cannot be reproduced; the files are the
record. The four prompts read identically in the ledger and in issue #564
(compared byte for byte before the first request). Every render of a cue used
its prompt unchanged:

> **paneOpen** — A soft cathedral-glass chime as a small leaded window pane settles into its frame: one clear high glass tone with a faint warm resonance, very short, intimate, quiet. No bell tower, no choir, no whoosh, no UI beep, no sparkle arpeggio.

> **glassCrack** — A single sharp crack running through a thick pane of old stained glass: a hard brittle snap, a short splintering tick as the fracture spreads, then silence. Close and dry. No shatter, no falling shards, no impact thud, no reverb tail.

> **glassImpact** — A heavy blow landing against a great leaded window: a deep low thud of weight on stone and lead, the whole pane ringing once in a short dark glassy resonance. No explosion, no shatter, no metal sword clang.

> **shoutSting** — A short bright glass ring struck hard, like a tuning fork of glass hit once, with a quick warm swell under it: emphasis, not alarm. No voice, no vocal shout, no brass stab, no whoosh.

### Per-render record

| file | `duration_seconds` | credits | bytes | sha256 (first 12) | rendered (UTC) |
|---|---:|---:|---:|---|---|
| `paneOpen-a.mp3` | 0.6 | 6 | 10,493 | `1cb3117eaf76` | 15:08:47 |
| `paneOpen-b.mp3` | 0.6 | 6 | 10,493 | `dfecafd0d95d` | 15:08:52 |
| `paneOpen-c.mp3` | 0.6 | 6 | 10,493 | `05a42f618387` | 15:08:58 |
| `paneOpen-d.mp3` | 0.6 | 6 | 10,493 | `c4215c394996` | 15:14:40 |
| `glassCrack-a.mp3` | 0.8 | 8 | 13,836 | `39ba85eea2cc` | 15:12:33 |
| `glassCrack-b.mp3` | 0.8 | 8 | 13,836 | `c4675d0a57a8` | 15:12:39 |
| `glassCrack-c.mp3` | 0.8 | 8 | 13,836 | `fd14989020a5` | 15:12:45 |
| `glassImpact-a.mp3` | 0.7 | 7 | 12,164 | `a65d8055599c` | 15:12:51 |
| `glassImpact-b.mp3` | 0.7 | 7 | 12,164 | `02fb0f3b6190` | 15:12:56 |
| `glassImpact-c.mp3` | 0.7 | 7 | 12,164 | `b1eb5df32c31` | 15:13:05 |
| `shoutSting-a.mp3` | 0.5 | 5 | 8,821 | `3c7c288b8a0c` | 15:13:11 |
| `shoutSting-b.mp3` | 0.5 | 5 | 8,821 | `96c9de2a8aed` | 15:13:17 |
| `shoutSting-c.mp3` | 0.5 | 5 | 8,821 | `c70c29ce12d5` | 15:13:23 |

### Credits

Read from `GET /v1/user/subscription` (numbers only) before the first render and
again once the counter had settled after the last:

| | credits used | plan limit |
|---|---:|---:|
| before | 3,022 | 90,000 |
| after | 3,106 | 90,000 |
| **consumed** | **84** | |

The 84 matches the sum of the per-response `character-cost` headers (10 credits
per requested second). The batch ceiling was 6,000 credits, so 1.4% of it was
used. In this batch the subscription counter lagged the renders by several
minutes, so a reading taken straight after a render understated the spend.

## Technical preflight

`preflight.py` in this folder is the whole method: ffmpeg 9.0.1 decodes each file
to float at its own rate (the container's gapless trim is honoured), numpy takes
the measurements and ffmpeg's `ebur128` gives integrated loudness. Spot checks
against ffmpeg's own `astats` (peak, RMS; three files) and `silencedetect`
(leading edge; two files) agreed to within 0.1 dB and 2 ms.

These checks establish **technical eligibility only**. They say nothing about
quality, cue identity or mix fit.

| gate | passes when | basis |
|---|---|---|
| decode | ffmpeg decodes with exit status 0, nothing on stderr and at least one frame | technical |
| duration | decoded length within ±25% of the target | ledger: 0.6 / 0.8 / 0.7 / 0.5 s |
| rate | 44.1 kHz | all 37 shipped files read so |
| channels | 2 | all 37 shipped files read so |
| clipping | at most 0.05% of decoded samples at full scale (absolute value of 0.999 or more) | the four shipped files with isolated codec overshoot sit at 0.011% or less |
| level | whole-file RMS between -50 and -6 dBFS | the shipped pack spans -47.5 to -8.9 dBFS |
| lead | the first 2 ms window above -50 dBFS starts within 40 ms | the shipped pack's slowest start is 7.3 ms |
| tail | the final 50 ms is 30 dB or more below the loudest 10 ms, or below -60 dBFS outright | a one-shot must end, not sustain or loop |

Reported but not gated: peak level (judged through the clipping gate, because the
shipped pack carries hot API renders up to +1.5 dBFS on decode), integrated
loudness (LUFS-I; BS.1770's 400 ms gating makes sub-second files unreliable, and
three shipped files read -70.0), and "event", the time to the first 10 ms window
within 12 dB of the loudest one, which exposes a quiet lead-in that "lead" alone
would miss.

The ledger sets a duration target and nothing else, so every other threshold is
this batch's own. They were set against the 37 shipped files, so that a gate does
not fail what the pack already ships as ordinary API output: 35 of the 37 pass.
The two that fail are `atkEnemyHeavy` (0.20% of its samples at full scale) and
`blocked` (its final 50 ms sits only 13 dB below its loudest).

**One revision, disclosed.** After the first three renders (`paneOpen-a` to
`-c`) and before the other ten, the tail rule changed. The first version compared
the final 50 ms with the loudest 10 ms only, and it also required the last 2 ms to
peak below -34 dBFS. The three renders showed that the relative test cannot judge
a file whose loudest window is itself near-inaudible (`paneOpen-c`), and that the
end-peak test, whose threshold sat just above the end artefact the shipped `hit`
carries, failed `paneOpen-a` for a larger artefact of the same kind. The
absolute floor was added and the end-peak test dropped; the pack result stayed at
35 of 37. Every threshold has been frozen since, and the other ten renders were
judged by the frozen rules. `paneOpen-a` and `paneOpen-c` are the two candidates
whose eligibility depends on the revision; `paneOpen-b` fails under both versions.

### Results

Measured. "lead" and "event" are times from the start of the file, `x2` is two
channels, and the tail's first figure is absolute while its second is relative to
the loudest 10 ms:

| file | codec, rate, channels | duration s (target) | peak dBFS | full-scale samples | LUFS-I | RMS dBFS | lead ms | event ms | tail dBFS (rel. dB) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `glassCrack-a.mp3` | mp3 44.1 kHz x2 | 0.800 (0.80) | -0.5 | 0 (0.000%) | -24.4 | -28.8 | 9.8 | 54 | -84.8 (-74.2) |
| `glassCrack-b.mp3` | mp3 44.1 kHz x2 | 0.800 (0.80) | 0.5 | 12 (0.017%) | -18.9 | -25.4 | 0.0 | 0 | -64.7 (-55.3) |
| `glassCrack-c.mp3` | mp3 44.1 kHz x2 | 0.800 (0.80) | 0.2 | 2 (0.003%) | -15.9 | -23.3 | 0.0 | 9 | -69.9 (-60.8) |
| `glassImpact-a.mp3` | mp3 44.1 kHz x2 | 0.680 (0.70) | -2.2 | 0 (0.000%) | -19.9 | -17.2 | 0.0 | 0 | -56.8 (-48.6) |
| `glassImpact-b.mp3` | mp3 44.1 kHz x2 | 0.680 (0.70) | -19.9 | 0 (0.000%) | -36.3 | -34.7 | 0.0 | 0 | -76.9 (-51.5) |
| `glassImpact-c.mp3` | mp3 44.1 kHz x2 | 0.680 (0.70) | -0.2 | 0 (0.000%) | -15.1 | -15.7 | 0.0 | 0 | -59.9 (-55.3) |
| `paneOpen-a.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | -10.7 | 0 (0.000%) | -17.8 | -25.3 | 0.0 | 122 | -50.5 (-32.0) |
| `paneOpen-b.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | -14.4 | 0 (0.000%) | -20.2 | -26.6 | 0.0 | 0 | -27.5 (-2.9) |
| `paneOpen-c.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | -28.0 | 0 (0.000%) | -40.5 | -43.6 | 0.0 | 0 | -60.7 (-24.8) |
| `paneOpen-d.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | -20.4 | 0 (0.000%) | -30.1 | -32.0 | 0.0 | 0 | -66.9 (-42.9) |
| `shoutSting-a.mp3` | mp3 44.1 kHz x2 | 0.480 (0.50) | -26.3 | 0 (0.000%) | -38.8 | -42.5 | 0.0 | 0 | -75.3 (-41.9) |
| `shoutSting-b.mp3` | mp3 44.1 kHz x2 | 0.480 (0.50) | -12.9 | 0 (0.000%) | -26.2 | -31.8 | 0.0 | 0 | -61.7 (-38.9) |
| `shoutSting-c.mp3` | mp3 44.1 kHz x2 | 0.480 (0.50) | -24.5 | 0 (0.000%) | -41.2 | -46.9 | 0.0 | 0 | -77.8 (-42.6) |

Verdicts:

| file | decode | duration | rate | channels | clipping | level | lead | tail | eligible |
|---|---|---|---|---|---|---|---|---|---|
| `glassCrack-a.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `glassCrack-b.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `glassCrack-c.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `glassImpact-a.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `glassImpact-b.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `glassImpact-c.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `paneOpen-a.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `paneOpen-b.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | FAIL | **no** |
| `paneOpen-c.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `paneOpen-d.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `shoutSting-a.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `shoutSting-b.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `shoutSting-c.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |

### Notes (measurements only, no judgement of sound)

- `paneOpen-a`: the main event starts about 122 ms into the file, behind a quiet
  lead-in, and its last 2 ms peak at -30.3 dBFS (the shipped `hit` ends at -35.5).
- `paneOpen-b` (ineligible): still at -27.5 dBFS in its final 50 ms, only 2.9 dB
  below its loudest window, so the file ends while the sound is running.
- `paneOpen-c`: the quietest paneOpen render (peak -28.0, RMS -43.6 dBFS); its tail
  passes on the absolute floor only (-60.7 dBFS).
- `glassCrack-b` and `glassCrack-c` exceed full scale on decode (+0.5 and +0.2
  dBFS; true peak +1.0 and +0.6 dBTP; 12 and 2 full-scale samples, 0.017% and
  0.003%). Both are inside the 0.05% gate; four shipped API renders show the same
  isolated overshoot at 0.011% or less, and `atkEnemyHeavy` shows 0.20%.
  `glassCrack-a` peaks at -0.5 dBFS (true peak +0.2 dBTP).
- `glassImpact-c` is the hottest impact render (peak -0.2 dBFS, no full-scale
  samples); its last 2 ms peak at -35.0 dBFS, level with the shipped `hit`.
- Raw levels differ widely inside a cue. RMS spread: `paneOpen` -25.3 to -43.6
  (a, c, d), `glassCrack` -23.3 to -28.8, `glassImpact` -15.7 to -34.7 (19 dB),
  `shoutSting` -31.8 to -46.9. The shipped pack's median is -22.9 dBFS. The scene
  plays a file at its rendered level, so mix fit is judged as rendered; when
  comparing timbre alone, allow for the level gap. A pick that is too quiet or too
  hot is a landing decision, not a reason to audition again.
- Decoded lengths are 0.600, 0.800, 0.680 and 0.480 s for the four cues. The
  container's own duration agrees with the decode for every file.

## What is not verified here

No audio-capable evaluator was available to the agent that ran this batch, so it
auditioned nothing. Unscored, for every candidate: fit to the ledger brief, cue
identity, transient clarity, impact, timbre and mix fit. The constraints written
into the prompts and the issue guards cannot be checked by a decode either:

| cue | constraints in the prompt | status |
|---|---|---|
| `paneOpen` | one clear high glass tone; no bell tower, no choir, no whoosh, no UI beep, no sparkle arpeggio | unscored |
| `glassCrack` | snap then silence, close and dry; no shatter, no falling shards, no impact thud, no reverb tail | unscored; only the decay to silence is measured (tail figures) |
| `glassImpact` | deep thud, one short dark ring; no explosion, no shatter, no metal sword clang | unscored |
| `shoutSting` | bright glass ring, emphasis not alarm; no voice, no vocal shout, no brass stab, no whoosh | unscored |
| all four | must not sound like `unsealingSting` or the `sealedDoor` theme; no voice-over, no text blips | unscored; **an audition criterion** |

Length alone separates these files from the 1.48 s unsealing sting and from any
music bed; that says nothing about how they sound.

## Audition

Stage one candidate for one cue at a time, so a single variable changes and the
other cues keep their present fallbacks (`glassCrack` sounds `chip`, `glassImpact`
sounds `hit`, `paneOpen` and `shoutSting` stay silent). `SceneDirector` finds a cue
with `ResourceLoader.exists`, so the file must be imported. The copy and its
`.import` sidecar are throwaway: untracked, never committed.

```bash
cp docs/design/2026-09-29-stagecraft-cues/candidates/glassCrack-a.mp3 assets/audio/sfx/glassCrack.mp3
godot --headless --import
godot --path . -- --stagecraft
rm assets/audio/sfx/glassCrack.mp3 assets/audio/sfx/glassCrack.mp3.import
```

The reel is driven by taps, as a scene is, and loops. Where each cue fires:

- `paneOpen`: the pane arriving, so the first line and again after the title card.
- `glassCrack`: the second beat's Keeper line (`flash-cold` and `crack`); the real
  scenes are unsealing beat 3 line 4 and act4-node5 line 2.
- `shoutSting`: the third beat's first line, the Lamplighter's, in the `shout` style.
- `glassImpact`: the third beat's recoil line (`impact`); the real one is the
  monuments' push.

Criteria, all yours: the ledger brief and cue identity; transient clarity, impact
and timbre; mix fit against the combat and ambient beds; **no resemblance to
`unsealingSting` or the `sealedDoor` theme**; no voice, no whoosh and the other
"No ..." clauses in each prompt. `afplay <file>` gives a quick raw listen first.

## Reproduce

```bash
python3 docs/design/2026-09-29-stagecraft-cues/preflight.py docs/design/2026-09-29-stagecraft-cues/candidates/*.mp3
python3 docs/design/2026-09-29-stagecraft-cues/preflight.py assets/audio/sfx/*.mp3   # the calibration set
```

Needs `ffmpeg`, `ffprobe` and `numpy` (this batch used ffmpeg 9.0.1, Python 3.13.1
and numpy 2.2.4). Add `--json` for every raw metric. The exit status is 1 whenever
a file is ineligible, so the first command exits 1 here: `paneOpen-b` from round 1
and four round-2 files (`paneOpen-e`, `paneOpen-i`, `shoutSting-f`, `shoutSting-h`)
are ineligible.

## Round 2: four directions per cue (2026-09-29, evening)

Round 2 answers James's audition of round 1. Round 1's record, preflight and
shortlist above stand as written, and nothing here ships (no file under
`assets/audio/sfx/`, no manifest row, no `pack_id` bump, no ledger row moved).

### The owner's note and the brief

James auditioned round 1 and wrote that `glassCrack-c` is his pick, firm, so
`glassCrack` is closed and is not in this round. For the other three cues he
picked `paneOpen-d`, `glassImpact-b` and `shoutSting-c`, and asked: "Have better
choices?"

The owner authorised this round inside the #564 research budget (ceiling 6,000
credits; 3,106 used after round 1): twelve renders, four per cue, and no more than
16 renders in this round even if some fail. The brief was four deliberately
different directions per cue, not four re-rolls. Every request keeps its cue's
ledger "No ..." sentence verbatim as its closing sentence and keeps the ledger
duration. Three takes reuse the ledger prompt unchanged at `prompt_influence` 0.8,
the round's only parameter change.

### Result

Sixteen renders gave **twelve technically eligible candidates, four per cue**: the
twelve planned takes, plus four renders spent on the two directions that failed the
frozen gates (see "The two directions that needed a second look"). That is all 16
renders the brief allows. No approved audio-capable evaluator auditioned any file,
so every perceptual criterion is **unscored** and the candidates are **unranked**:
the letters continue each cue's render order and mean nothing else.

| cue | target | eligible, unranked | ineligible (kept as evidence; do not audition) |
|---|---:|---|---|
| `paneOpen` | 0.6 s | `paneOpen-f`, `paneOpen-g`, `paneOpen-h`, `paneOpen-j` | `paneOpen-e` (level and tail), `paneOpen-i` (tail) |
| `glassImpact` | 0.7 s | `glassImpact-d`, `glassImpact-e`, `glassImpact-f`, `glassImpact-g` | none |
| `shoutSting` | 0.5 s | `shoutSting-d`, `shoutSting-e`, `shoutSting-g`, `shoutSting-i` | `shoutSting-f` (tail), `shoutSting-h` (tail) |

**Decision requested from James:** audition the twelve eligible files, alongside his
round-1 picks (`paneOpen-d`, `glassImpact-b`, `shoutSting-c`, which stay on the
table), by the procedure under "Audition" above, and name one file per cue.
`glassCrack-c` stands. After that decision the landing commit follows without
another approval stop.

### Generation

The same call as round 1 (the official sound-generation REST endpoint, one request
per render, sequential) on 2026-09-29 between 22:00 and 22:03 UTC. Only
`prompt_influence` differs, and only on three takes:

| parameter | value |
|---|---|
| endpoint | `POST /v1/sound-generation`, `output_format=mp3_44100_128` |
| `model_id` | `eleven_text_to_sound_v2` |
| `prompt_influence` | 0.6, except 0.8 for `paneOpen-h`, `glassImpact-g` and `shoutSting-g` |
| `loop` | `false` (one-shot) |
| `duration_seconds` | the ledger target for the cue: 0.6 (`paneOpen`), 0.7 (`glassImpact`), 0.5 (`shoutSting`) |
| `text` | the request for each file, verbatim in the next section |

The endpoint takes no seed, so a render cannot be reproduced; the files are the
record. Before the first request the ledger's and issue #564's prompts were compared
byte for byte (they agree), every request was checked to end with its cue's ledger
"No ..." sentence character for character, and each unchanged take was checked
against the ledger prompt exactly.

### The requests, verbatim

**paneOpen** (0.6 s)

`paneOpen-e` (`prompt_influence` 0.6), direction: softer and simpler: one clear high glass tone, short natural decay, nothing else.

> A very soft cathedral-glass chime: a single clear high glass tone with a short natural decay, and nothing else. Very short, intimate, quiet. No bell tower, no choir, no whoosh, no UI beep, no sparkle arpeggio.

`paneOpen-f` (`prompt_influence` 0.6), direction: a small leaded pane seating in its frame: a tiny lead click, then a faint glass hum.

> A small leaded window pane seating into its frame: a tiny soft click of lead, then a faint glass hum that fades away. Very short, intimate, quiet. No bell tower, no choir, no whoosh, no UI beep, no sparkle arpeggio.

`paneOpen-g` (`prompt_influence` 0.6), direction: two quick soft glass notes, the second a little higher, like a pane settling.

> A small leaded window pane settling into its frame: two quick soft glass notes, the second a little higher than the first, each with a short natural decay. Very short, intimate, quiet. No bell tower, no choir, no whoosh, no UI beep, no sparkle arpeggio.

`paneOpen-h` (`prompt_influence` 0.8), direction: the ledger prompt unchanged.

> A soft cathedral-glass chime as a small leaded window pane settles into its frame: one clear high glass tone with a faint warm resonance, very short, intimate, quiet. No bell tower, no choir, no whoosh, no UI beep, no sparkle arpeggio.

`paneOpen-i` (`prompt_influence` 0.6), direction: softer and simpler: one clear high glass tone, short natural decay, nothing else. The request of `paneOpen-e` again, word for word, after that render failed a technical gate.

`paneOpen-j` (`prompt_influence` 0.6), direction: softer and simpler: one clear high glass tone, short natural decay, nothing else. Reworded after the same request failed twice; only the closing behaviour changes.

> A very soft cathedral-glass chime: a single clear high glass tone with a short natural decay that dies away completely into silence, and nothing else. Very short, intimate, quiet. No bell tower, no choir, no whoosh, no UI beep, no sparkle arpeggio.

**glassImpact** (0.7 s)

`glassImpact-d` (`prompt_influence` 0.6), direction: deeper and slower: a heavier thud, the pane's ring darker and longer.

> A heavy blow landing against a great leaded window: a deeper, slower, heavier thud of weight on stone and lead, the whole pane ringing once afterwards in a darker, longer glassy resonance. No explosion, no shatter, no metal sword clang.

`glassImpact-e` (`prompt_influence` 0.6), direction: a muffled heavy blow through thick glass, felt more than heard, almost no ring.

> A muffled heavy blow landing against a great leaded window, heard through thick glass: a deep dull thud felt more than heard, with almost no ring from the pane. No explosion, no shatter, no metal sword clang.

`glassImpact-f` (`prompt_influence` 0.6), direction: weight landing on lead came, with a low glass shudder and a dull stone knock (the request says "lead strips", so that "came" cannot be read as a verb).

> A heavy weight landing on the lead strips of a great leaded window: a low glass shudder through the panes and a dull stone knock. No explosion, no shatter, no metal sword clang.

`glassImpact-g` (`prompt_influence` 0.8), direction: the ledger prompt unchanged.

> A heavy blow landing against a great leaded window: a deep low thud of weight on stone and lead, the whole pane ringing once in a short dark glassy resonance. No explosion, no shatter, no metal sword clang.

**shoutSting** (0.5 s)

`shoutSting-d` (`prompt_influence` 0.6), direction: brighter and shorter: a single glass ping with a quick warm swell under it.

> A single short, bright glass ping with a quick warm swell under it: emphasis, not alarm. No voice, no vocal shout, no brass stab, no whoosh.

`shoutSting-e` (`prompt_influence` 0.6), direction: a struck glass rod, clean and bright, very quick decay.

> A glass rod struck once: a clean, bright ring with a very quick decay. Emphasis, not alarm. No voice, no vocal shout, no brass stab, no whoosh.

`shoutSting-f` (`prompt_influence` 0.6), direction: a high glass ring over a soft low swell, two layers.

> Two layers: a high glass ring struck once, over a soft, low, warm swell. Emphasis, not alarm. No voice, no vocal shout, no brass stab, no whoosh.

`shoutSting-g` (`prompt_influence` 0.8), direction: the ledger prompt unchanged.

> A short bright glass ring struck hard, like a tuning fork of glass hit once, with a quick warm swell under it: emphasis, not alarm. No voice, no vocal shout, no brass stab, no whoosh.

`shoutSting-h` (`prompt_influence` 0.6), direction: a high glass ring over a soft low swell, two layers. The request of `shoutSting-f` again, word for word, after that render failed a technical gate.

`shoutSting-i` (`prompt_influence` 0.6), direction: a high glass ring over a soft low swell, two layers. Reworded after the same request failed twice; only the closing behaviour changes.

> Two layers: a high glass ring struck once, over a soft, low, warm swell. Both layers die away quickly into silence. Emphasis, not alarm. No voice, no vocal shout, no brass stab, no whoosh.

### The two directions that needed a second look

Two of the twelve planned takes failed the frozen gates, so their directions were
rendered again inside the 16-render cap. In order:

1. `paneOpen-e` (softer and simpler) failed the level gate (whole-file RMS
   -50.7 dBFS against a floor of -50) and the tail gate (-58.4 dBFS in its last
   50 ms, only 10.1 dB below its loudest window). `shoutSting-f` (two layers) failed
   the tail gate (-22.3 dBFS in its last 50 ms, 5.4 dB below its loudest window).
2. Each request was rendered again unchanged (`paneOpen-i`, `shoutSting-h`). Both
   failed the tail gate too: -37.5 and -19.4 dBFS in the last 50 ms, 7.5 and 4.1 dB
   below their loudest windows.
3. Two failures in a row for each direction suggest that the request, not the draw,
   was the cause, so the last two renders went to one reworded request per
   direction, changing only the closing behaviour: `paneOpen-j` adds "that dies away
   completely into silence" and `shoutSting-i` adds "Both layers die away quickly
   into silence". Both passed every gate.

The rules did not move. A reworded request is a different request, so whether
`paneOpen-j` and `shoutSting-i` still sound like the direction they replace is an
audition question, unscored here. The four ineligible files stay in `candidates/` as
evidence only.

### Per-render record

In render order. Credits are each response's `character-cost` header.

| file | `duration_seconds` | `prompt_influence` | credits | bytes | sha256 (first 12) | rendered (UTC) |
|---|---:|---:|---:|---:|---|---|
| `paneOpen-e.mp3` | 0.6 | 0.6 | 6 | 10,493 | `0a33d2ecd661` | 22:00:18 |
| `paneOpen-f.mp3` | 0.6 | 0.6 | 6 | 10,493 | `2afbd9ca9878` | 22:00:19 |
| `paneOpen-g.mp3` | 0.6 | 0.6 | 6 | 10,493 | `af0ecfe385e7` | 22:00:21 |
| `paneOpen-h.mp3` | 0.6 | 0.8 | 6 | 10,493 | `ecfb17a7ad9b` | 22:00:22 |
| `glassImpact-d.mp3` | 0.7 | 0.6 | 7 | 12,164 | `4c7fcb7b89ab` | 22:00:24 |
| `glassImpact-e.mp3` | 0.7 | 0.6 | 7 | 12,164 | `e270960a0a5c` | 22:00:25 |
| `glassImpact-f.mp3` | 0.7 | 0.6 | 7 | 12,164 | `88f3c57d0a3b` | 22:00:26 |
| `glassImpact-g.mp3` | 0.7 | 0.8 | 7 | 12,164 | `9e46844fcefe` | 22:00:27 |
| `shoutSting-d.mp3` | 0.5 | 0.6 | 5 | 8,821 | `1b47abe22cc6` | 22:00:29 |
| `shoutSting-e.mp3` | 0.5 | 0.6 | 5 | 8,821 | `4858b212e46a` | 22:00:30 |
| `shoutSting-f.mp3` | 0.5 | 0.6 | 5 | 8,821 | `8024b8e2942a` | 22:00:32 |
| `shoutSting-g.mp3` | 0.5 | 0.8 | 5 | 8,821 | `7d7ee9fd7073` | 22:00:33 |
| `paneOpen-i.mp3` | 0.6 | 0.6 | 6 | 10,493 | `1446011b00d7` | 22:01:47 |
| `shoutSting-h.mp3` | 0.5 | 0.6 | 5 | 8,821 | `d2ae120e6c8c` | 22:01:50 |
| `paneOpen-j.mp3` | 0.6 | 0.6 | 6 | 10,493 | `3b5af2539ada` | 22:02:50 |
| `shoutSting-i.mp3` | 0.5 | 0.6 | 5 | 8,821 | `d1c53cf0732e` | 22:02:51 |

### Credits

Read from `GET /v1/user/subscription` (numbers only) before the first render, where
it equalled round 1's closing figure, and again once the counter had settled:

| | credits used | plan limit |
|---|---:|---:|
| before | 3,106 | 90,000 |
| after | 3,200 | 90,000 |
| **consumed** | **94** | |

The 94 equals the sum of the sixteen `character-cost` headers (10
credits per requested second: 6 per `paneOpen` render, 7 per `glassImpact`, 5 per
`shoutSting`). The counter lags the renders, as in round 1: it read 3,189 at
22:03:10 UTC, then 3,200 at 22:03:41 and again at 22:04:13. The research ceiling is
6,000 credits, so 2,800 remain under it.

### Technical preflight

The method, the gates and every threshold are exactly those of round 1:
`preflight.py` is untouched by this round (the same file, run unmodified), with the
same ffmpeg 9.0.1, Python 3.13.1 and numpy 2.2.4. The round-1 disclosure about the
one tail-rule revision still applies, and nothing was revised this round. The tables
cover all sixteen new files and are the tool's own output, sorted by file name. The
columns are those of round 1. These checks establish **technical eligibility only**.

| file | codec, rate, channels | duration s (target) | peak dBFS | full-scale samples | LUFS-I | RMS dBFS | lead ms | event ms | tail dBFS (rel. dB) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `glassImpact-d.mp3` | mp3 44.1 kHz x2 | 0.680 (0.70) | -0.1 | 0 (0.000%) | -17.7 | -8.5 | 0.0 | 0 | -67.1 (-63.9) |
| `glassImpact-e.mp3` | mp3 44.1 kHz x2 | 0.680 (0.70) | -0.1 | 0 (0.000%) | -18.3 | -11.5 | 0.0 | 0 | -59.6 (-57.6) |
| `glassImpact-f.mp3` | mp3 44.1 kHz x2 | 0.680 (0.70) | -0.6 | 0 (0.000%) | -19.6 | -20.8 | 0.0 | 0 | -58.6 (-52.2) |
| `glassImpact-g.mp3` | mp3 44.1 kHz x2 | 0.680 (0.70) | -5.7 | 0 (0.000%) | -21.9 | -22.4 | 0.0 | 0 | -67.4 (-56.2) |
| `paneOpen-e.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | -39.5 | 0 (0.000%) | -44.3 | -50.7 | 0.0 | 0 | -58.4 (-10.1) |
| `paneOpen-f.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | 0.0 | 1 (0.002%) | -21.6 | -29.7 | 0.0 | 244 | -71.1 (-56.3) |
| `paneOpen-g.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | -5.8 | 0 (0.000%) | -24.9 | -26.9 | 0.0 | 0 | -63.2 (-50.7) |
| `paneOpen-h.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | -14.6 | 0 (0.000%) | -36.3 | -40.9 | 0.0 | 0 | -68.0 (-41.8) |
| `paneOpen-i.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | -14.9 | 0 (0.000%) | -41.5 | -43.6 | 0.0 | 0 | -37.5 (-7.5) |
| `paneOpen-j.mp3` | mp3 44.1 kHz x2 | 0.600 (0.60) | -24.6 | 0 (0.000%) | -36.0 | -41.5 | 0.0 | 0 | -68.1 (-35.4) |
| `shoutSting-d.mp3` | mp3 44.1 kHz x2 | 0.480 (0.50) | -24.0 | 0 (0.000%) | -35.9 | -39.2 | 0.0 | 0 | -79.7 (-48.3) |
| `shoutSting-e.mp3` | mp3 44.1 kHz x2 | 0.480 (0.50) | -16.8 | 0 (0.000%) | -31.6 | -38.4 | 0.0 | 0 | -74.8 (-50.2) |
| `shoutSting-f.mp3` | mp3 44.1 kHz x2 | 0.480 (0.50) | -3.0 | 0 (0.000%) | -15.8 | -22.2 | 0.0 | 0 | -22.3 (-5.4) |
| `shoutSting-g.mp3` | mp3 44.1 kHz x2 | 0.480 (0.50) | -27.4 | 0 (0.000%) | -42.2 | -48.1 | 0.0 | 0 | -78.5 (-41.9) |
| `shoutSting-h.mp3` | mp3 44.1 kHz x2 | 0.480 (0.50) | -5.2 | 0 (0.000%) | -13.8 | -20.3 | 0.0 | 0 | -19.4 (-4.1) |
| `shoutSting-i.mp3` | mp3 44.1 kHz x2 | 0.480 (0.50) | -6.5 | 0 (0.000%) | -16.6 | -23.7 | 0.0 | 0 | -59.0 (-41.1) |

| file | decode | duration | rate | channels | clipping | level | lead | tail | eligible |
|---|---|---|---|---|---|---|---|---|---|
| `glassImpact-d.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `glassImpact-e.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `glassImpact-f.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `glassImpact-g.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `paneOpen-e.mp3` | PASS | PASS | PASS | PASS | PASS | FAIL | PASS | FAIL | **no** |
| `paneOpen-f.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `paneOpen-g.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `paneOpen-h.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `paneOpen-i.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | FAIL | **no** |
| `paneOpen-j.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `shoutSting-d.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `shoutSting-e.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `shoutSting-f.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | FAIL | **no** |
| `shoutSting-g.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |
| `shoutSting-h.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | FAIL | **no** |
| `shoutSting-i.mp3` | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | **yes** |

### Notes (measurements only, no judgement of sound)

- The four failures. `paneOpen-e` fails two gates: level (RMS -50.7 dBFS; the floor
  is -50) and tail (-58.4 dBFS in the final 50 ms, 1.6 dB above the -60 dBFS
  absolute floor and only 10.1 dB below its loudest window). `paneOpen-i`,
  `shoutSting-f` and `shoutSting-h` fail the tail gate alone: their last 50 ms sit
  only 7.5, 5.4 and 4.1 dB below their loudest window. Their last 2 ms peak at
  -17.7, -3.0 and -6.0 dBFS (against peaks of -14.9, -3.0 and -5.2), so each file
  ends while the sound is still running.
- `glassImpact-d` and `glassImpact-e` are the hottest renders of either round by
  RMS (-8.5 and -11.5 dBFS). The shipped pack's hottest is -8.9 dBFS, so
  `glassImpact-d` is above anything shipped; both pass the level gate (-6 dBFS at
  most) and neither has a full-scale sample (`glassImpact-d` peaks at -0.1 dBFS).
- `paneOpen-f` peaks at 0.0 dBFS (true peak +0.2 dBTP) with one full-scale sample
  (0.002%), inside the 0.05% clipping gate. Its loudest 10 ms window arrives about
  244 ms into the file, behind a quieter opening.
- Raw levels differ widely inside a cue, as in round 1. RMS spread of the eligible
  files: `paneOpen` -26.9 to -41.5 dBFS, `glassImpact` -8.5 to -22.4, `shoutSting`
  -23.7 to -48.1. The shipped pack's median is -22.9 dBFS. The scene plays a file at
  its rendered level, so mix fit is judged as rendered; as in round 1, a pick that
  is too quiet or too hot is a landing decision, not a reason to audition again.
- The three unchanged takes at `prompt_influence` 0.8 read RMS -40.9 (`paneOpen-h`),
  -22.4 (`glassImpact-g`) and -48.1 dBFS (`shoutSting-g`). Each sits inside the
  spread of its cue's 0.6 renders in round 1 (`paneOpen` -25.3 to -43.6,
  `glassImpact` -15.7 to -34.7, `shoutSting` -31.8 to -46.9), but one render each
  cannot say what the parameter does.
- The eligible files that end loudest, by the peak of their last 2 ms, are
  `glassImpact-f` (-34.6), `paneOpen-g` (-37.0) and `shoutSting-i` (-39.6 dBFS),
  against -35.5 for the shipped `hit`. The end-peak test was dropped from the gate
  in round 1 and stays dropped, so this is reported only.
- Decoded lengths are 0.600, 0.680 and 0.480 s for the three cues. The container's
  own duration agrees with the decode for every file.

### What is not verified here

As in round 1, no audio-capable evaluator was available to the agent that ran this
round, so it auditioned nothing. Unscored for every round-2 candidate: fit to the
ledger brief, cue identity, transient clarity, impact, timbre and mix fit; the "No
..." clauses in each request (no voice, no whoosh, no shatter and the rest); the
guard that none may sound like `unsealingSting` or the `sealedDoor` theme; and
whether a take that departs from the ledger wording still reads as its cue.

### Audition

The procedure under "Audition" above applies unchanged: stage one candidate for one
cue at a time, keeping the copy and its `.import` sidecar untracked and never
committed. `glassCrack` is closed (`glassCrack-c`), so this audition covers
`paneOpen`, `glassImpact` and `shoutSting` only. Do not stage the four ineligible
files.

# Stagecraft — the dialogue and cutscene system (2026-09-27)

Owner brief (James, 2026-09-27): Japanese-RPG dialogue — a framed pane,
characters on screen left and right (sometimes more), mood portraits,
shouts, and effects for blows and revelations — built as one reusable system
that carries every scripted scene, the opening and the ending included.
Ownership of the dialogue system, and authority to override the #334 staging
geometry, was delegated to the implementing agent in the same brief.

This file is the authoring reference and the design record. Scene *order*
and *meaning* stay where they were: `docs/story/07-scenes.md` (§1 grammar,
§2–§5 blueprints). Art and audio commissions are in `docs/art-ledger.md` and
`docs/sfx-ledger.md` under "Commissioned — stagecraft", tracked in #559
(sub-issues #560–#564).

## Principles

1. **Who speaks is lit.** Stained glass lives only while light passes through
   it. The speaker's bust is lit glass — saturated, glowing, a warm rim on its
   fire side, a halo of its own colour on the wall behind. Listeners are the
   same windows at night: dim, cold, desaturated, a step lower. Nobody speaking
   leaves everyone half-lit. (`glass_portrait.gdshader`)
2. **Mood is posture and light, never a face.** The Keeper, the Lamplighter
   and both heroes are faceless by canon. Moods are pose variants of the same
   cutout on the same canvas, so a mood swap reads as the same body shifting.
3. **One body per character.** The opening's seated Keeper (#283 cutout on
   the hearth) is the wide shot; when the Keeper steps into the two-shot as a
   portrait the hearth step is empty. #334's rule survives its geometry.
4. **Effects are glass.** A blow cracks the frame; a shatter throws jewel
   shards with their leading on; a kindle carries sparks hand to hand; light
   arrives as rays. Effects are events: resume and capture never replay them.
5. **Grammar is unchanged except where the reveal demanded it** — see below.
6. **Restraint for the Keeper.** Its voice is warm and tired (02-cast); its
   reveal is a cold flash and a crack, never a shake.

## Architecture

```
content/scenes.json (v2)          content/actors.json
  beats: art, motion, transition,   actor: name key, home side, facing,
         ambient, grade               tint, rim side, bust crop,
  lines: key, speaker, style, mood,   portraits { mood: art | {art,
         enter, exit, moods, fx,        fallback, rim} }
         sfx, focus
        │                                  │
        ▼                                  ▼
SceneScript ──► StageDirection        ActorBook
 (parse, fail closed)  (vocabulary, fold)   (resolve mood → art, fallback)
        │
        ▼
ScenePlayer — grammar: tap / hold-skip / walk / persistence-gated advance
        │  hands each presented line to
        ▼
SceneDirector — stands the cast, lights the speaker, sets the pane's voice,
        │        the beat's weather/grade/transition, fires the line's fx+sfx
        ├─ DialogueBox    leaded pane, name plaque, typed reveal, advance ember
        ├─ PortraitStage  five seats of StagePortrait busts (+ shader)
        ├─ SceneFx ×2     ambient (behind busts) and front (under the pane)
        └─ grade / wash / veil ColorRects
```

Directions ride on lines, never on extra steps, so the saved cursor still
means "line index": **no save change, no migration**. The stage at any cursor
is `StageDirection.fold(lines, cursor)` — a resumed or captured scene stands
exactly what a live playthrough built.

## Grammar change (07-scenes §1)

Lines now type in. §1 already reads "tap = 一句/一 beat(提前完成 reveal,或
即時推進)": a tap **lands** a line still typing, and a tap on a standing line
**steps**. One tap never moves more than one line and never costs the player a
line they have not seen whole (rubric: "a single tap … advances exactly one
dialogue line"). The previous implementation completed *and* stepped on a
mid-reveal tap; with a 0.55 s fade that was tolerable, with typing it would
skip reading. Hold-skip lands the typing line at the arm and then fast-forwards
at the old pace; beat ②'s 1 s skip floor counts from the moment the line
stands. The finale's walk lines keep their own grammar break unchanged.

Reading pace: Latin 50 cps, CJK 24 cps, a breath at stops (0.26 s), commas
(0.11 s) and dashes (0.20 s); whispers run at 72%. The reveal is never shorter
than the old 0.55 s. Reduced motion lands every line whole and keeps the full
dwell — it never shortens reading time.

## Authoring reference

### Beat fields (all optional beyond the v1 ones)

| field | values | default |
|---|---|---|
| `transition` | `cut` `fade` (dip) `black` `white` `flash` `wake` (slow first light) | `cut` |
| `ambient` | `none` `embers` `ash` `motes` `snow-glass` | `none` |
| `grade` | `none` `hearth` `cold` `dusk` `inverted` | `none` |

### Line fields

| field | form | meaning |
|---|---|---|
| `style` | `speech` `narration` `shout` `whisper` `chorus` `title` | delivery; default `speech` with a speaker, `narration` without |
| `enter` | `"id@seat"`, `"id@seat:mood"` or `{"id","at","mood"}`, list | seat an actor (moving them if already standing; whoever held the seat steps off) |
| `exit` | `["id", …]` or `["*"]` | take actors off |
| `mood` | mood id | the speaker's own mood from this line |
| `moods` | `{"id": "mood"}` | a listener's mood |
| `fx` | list of effects, actor-aimed ones as `"hop@id"` | one-shot, live only |
| `sfx` | cue id | overrides an effect's default cue |
| `focus` | actor id or `none` | who is lit, when not the speaker |

Seats: `far-left` `left` `centre` `right` `far-right`. A crowded side pulls its
near seat inward; three or more voices stand smaller; outer seats stand a step
back and draw behind.

Effects: `shake` `quake` `flash` `flash-ember` `flash-cold` `flash-blood`
`impact` `slash` `crack` `shatter` `kindle` `rays` `pulse` `dim`; actor-aimed
`hop` `recoil` `shake` `kindle` (kindle's sparks fly from the named actor's
hands to the first other figure on stage).

Everything fails closed at load: an unknown style, seat, effect, transition,
ambient or grade rejects the scene file, as an unknown `motion` always did.
`tests/test_stagecraft.gd` additionally requires every actor, mood and effect
target a scene names to be registered in `content/actors.json`.

### Adding a character

Add an actor row (name key in both locales, home side, which way the art
faces, tint, rim side, bust crop, `default` portrait). Declare each mood with
its ledgered path even before the art exists — the stage stands the default
figure in that mood's posture and light until the file lands.

## The shot list as staged

| Scene | Staging |
|---|---|
| Opening ① | `wake` from black into the hall; the Keeper seated on the hearth (the #283 figure), speaking from the fire; pane docked clear of the seat. |
| Opening ② | Push-in to the two-shot: hero left (the run's own aspect), Keeper right in `offering` — sparks kindle from its hands to yours on 「帶上這個」 — then still, then `tender` on the city. The destination beat keeps its 1 s skip floor. |
| Opening ③④ | Back to the wide: the portraits leave, the Keeper is seated again (the L0 plant — 身後，爐火仍亮着); 「守夜開始了」 as a gold title card clear of the seat. |
| Lamplighter m1–m5 | Night road (`dusk`, ash). Moods walk the five-price arc: `wary` → `recognising` → `asking` → `urgent` (m4's question, a small hop) → `grieving`. He steps back to the far seat on m3-post ("He steps back") and m5-post ("He steps aside"); in m5-pre he first stands centre, blocking the road. His embers kindle out of the hero's hands into the dark lantern, and the scene dims ("The lantern does not light"). |
| Unsealing | Rose lighting untouched; rays when the fire is one again, dim when "the light does not pass through"; a cold flash as the window becomes a mirror; a crack on the full truth; the monuments' push is a quake and an impact; dim on 「你沒有開門。」 |
| Act IV entry, nodes 1–4 | White arrival, glass snow, inverted grade; the Queue speaks as a `chorus` (its echo trails a half-beat) from the centre seat — voice only until `queue-chorus.png` lands. The eight selves stay silent (§4). |
| Act IV node 5 | Two-shot, hero left, Keeper right in its hearth figure: 「你到了。這裏你認得。」 — then `revealed` (the shipped boss form, lit from the wrong side) with a cold flash and a crack on 「我一句都沒有說錯」; `beckon`, whispered, on 「坐下。」 |
| Finale | White arrival and rays; the walk lines as title cards over the swap plate — the second step warms, the last lands with light. Win: rays over the ascended plate. Loss: 「這一個，也沒有回來。」 as the card, dimmed, ash falling. |

## Verification

- `tests/test_stagecraft.gd` — vocabulary fails closed; fold is order-exact;
  registry resolution and fallbacks; every scene's cast registered; names in
  both locales; pane, title card and busts inside the frame at pad, desktop
  and phone; CJK slower than Latin, stops breathe, shouts land, reduced motion
  lands; capture fires nothing, a live line fires its own; the opening shows
  exactly one Keeper at every cursor; pool rows (a walker's echo is heard, not
  seen; a Keeper row seats the Keeper); the dev reel covers the vocabulary.
- `tests/test_scene_player.gd` — the grammar change above, pinned.
- Stills: `godot --path . -- --scene=<id> --cursor=N --shot=…` (settled
  stage), and the reel `-- --stagecraft --cursor=N --freeze=SECONDS --shot=…`
  photographs a one-shot effect mid-flight. `contact-sheet.jpg` here is the
  reviewed set from this change.

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

## Beyond the scripted scenes

The same components carry the game's other narrative surfaces, still on
existing copy only:

| Surface | Staging | Data |
|---|---|---|
| Battle speech: the Usurper's three opening lines and each Shade's dying word | `BattleDialogue`: the fight dims, the speaker's bust rises on the right under its combat name, the line types into the pane with its effect (a crack on "mask", a hop and an ember flash on the threat, a cold flash on the dying word, which stays whispered for the L1 weight line). The drain awaits it, and the fight takes no input until the pane has cleared: the advance keys and taps are the pane's alone. A variant with no staging keeps the banner. | `content/battle-lines.json`; the Shade and the Sovereign are actors on their shipped art |
| The Hollow Lamplighter's price | The meeting's own two-shot between its pre- and post-scenes: hero left, the Lamplighter lit right, the ask under his plaque, the price as a choice window. Asking → wary (a recoil) when it cannot be met → recognising once paid; paying kindles your embers into the hollow lantern. | moods in `content/actors.json` |
| Road events (all eleven) | The event's painting full-bleed as the place, a location card, the prose in the pane, the choices in a window docked beside the figure; per-event weather and grade; each story beat's own effect, once, never on resume. | `content/event-staging.json` |
| The gambler's roll | The landed branch (win or lose) is narrated as its own event beat, with its own effect (`roll-win`, `roll-lose`); the roll is kept by id, so a resume shows the same outcome and never rolls again. | `content/event-staging.json` |
| The Lamplighter's replies | His meeting's own `ask`, `paid` and `cannot` lines in the pane under his plaque; the first meeting's promised price answers with `accepted`. | the meeting rows in `content/full-content.json` |
| Quest closers | Once each, straight after the fight that completes the journey, while four panes are lit: the Own Shade whispered over ash in a cold grade; the Usurper on its crowned bust with a crack; the Eighth Omen as a gold title card in the inverted grade. A win that closes two journeys plays both in turn. Each plays as a run scene `line:<row id>` (a pending pool line may not stand beside a pending reward or run end in the save contract). | `SceneScript.POOL_LOOKS`, `PoolBeats.CLOSERS` |
| The Unreadable Page | Each page read as its own scene (dusk, motes; the fifth page with rays) at the act-2 boss win that turns it, once, while the page is carried; that win's closers follow it. The pages are quest copy, not `story.*` leaves, so the scenes are built in code rather than authored in `content/scenes.json`. | `SceneScript.quest_page` (`unreadable-page-1`…`5`) |
| The Queue at the door | `payoff.mirror` heard once, as a chorus under hearth light and rays, straight after act4-entry on the first Act IV crossing (or after the short door, for a Vigil that crossed before the row could play). | `PoolBeats.KEY_L3` |
| The Eighth Omen's broken words | While that omen rules the act, each waystone's echo is followed by one of its four words as a title card, in turn by the waystone's row. The beat's cursor is saved, so a rebuild resumes on the words rather than replaying the echo. | `SceneScript.OMEN_ECHO` |
| The Night Stall | The merchant's line carries the lantern: its price out of reach (`poor`), and the throne told the moment it is sold (`bought`); otherwise the greeting. | `ShopScreen.say` |

Not staged, on purpose: the Night Stall's frame (the painting *is* the screen,
James's concept C1 — it speaks only through its own merchant line), dawn memories (the rubric's ceremony cadence), the Vigil and its
epitaphs (records, not speech), and the waystone echoes' plate. The only
existing monument art is a map icon, so the echoes stay a whisper in motes.

## Narrative timing (decided here)

The copy that was loaded and localised but never shown now plays through the
same engine, at the moment its own row or ledger entry names:

- **Closers are L2** (`04-delivery.md`: quest rewrites are closers only). The
  rows carry their own gate (`shards>=4`, `once`), so the line plays only when
  four panes are lit and only once across the Vigil. The moment is the
  completing fight (`05-foreshadow-ledger.md` rows 5, 41 and 83 call them the
  shade's confession, the victory pointer and the quest's closing line). The
  quest fields `final`, `death` and `resolved` are the same sentences.
- **Pages are milestone copy.** Pages one to four are L1 and the fifth is the
  L2 closer (ledger rows 12 and 17); each is read at the win that turns it.
- **The Queue's row is post-L3.** It is heard after the unsealing has been
  seen, at the door itself, so the ladder is never climbed early.
- **The omen's words and the stall's lines are L1** (ledger rows 16, 39, 40).

Every beat keeps the engine's existing laws: a row is drawn once per key and
replayed on resume without consuming randomness, and a scene marks
`scenes_seen` when it finishes (a heard closer is never queued again).

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
- `tests/test_quest_closers.gd` — each closer's gate (four panes, completed,
  not yet heard, not told before), the boss-win chain, the Own Shade's fight,
  page scenes (read once, only while carried, closers after them), the Queue
  after the first crossing only, every slot look in the vocabulary, the omen's
  words after a waystone, and the stall's lines. Every owed beat is a save the
  load contract accepts, and a resumed run replays it. Previews:
  `--stagecraft-screen=pool:<row-id>[:echo]`, `stall[:poor|:bought]`, and
  `--scene=line:<row-id>` or `--scene=unreadable-page-<n>`.
- `tests/test_event_rolls.gd` — the gambler's roll narrated, kept and resumed.
- `tests/test_stagecraft_screens.gd` — battle and event staging fail closed and
  match real content; the Hollow two-shot's moods and contracts; the event
  screen's plate, prose, choices and once-only beat effect; the pane laying out
  when placed before the tree. Previews: `-- --stagecraft
  --stagecraft-screen=hollow[:paid|:refused]`, `event:<id>[:c0|:c1|:c2|:coda]`,
  `battle:<variant>[:death]`, each with `--shape=` and `--freeze=`.

# The flame on the event screen — lock §8 and §9, a follow-up to PR 5 (#577)

**Status:** delivered for the owner's visual approval on device, 2026-09-29. Authority: the Flame lock ([`../README.md`](../README.md)) §8 ("removing off-colour glass raises purity and the flame answers on the spot") and §9 (where the flame shows); PR #587, which reads the flame after every event deck change; and the lantern itself, delivered in [`../hud/README.md`](../hud/README.md). The look is a parameter set owned by `LanternFlame`; nothing here changes it.

**The outcome.** Since #587 `Main` reads the flame after every event deck change, but the event screen had no lantern: the tier the event crossed was recorded and its lines owed, and nothing was shown until the next combat, reward or shop. The event screen now hangs the same `RunLantern` the reward screen and the Night Stall hang. It opens on the flame as it stands, drawn at once; it turns, over a second, after a change that moves the flame; it does nothing when the deck did not move; and an aspect that declares no ways (the Ashwarden) grows no lantern at all.

## What changed

| File | Role |
|---|---|
| `presentation/run/event_screen.gd` | `show_flame()` builds the lantern on the first reading, as the reward screen and the stall do. `inherit_lantern()` carries it on to the result beat that replaces the choices. The lantern sits under the title, the pane and the choices, and is re-seated on every layout and by `set_shape`. |
| `presentation/run/run_lantern.gd` | `keep_clear_of(stage_width, crowd)`: the lantern keeps the reward and shop seat unless the screen's own furniture reaches it, and then hangs from the other edge at the same inset, size and height. Nothing changes for the screens that never call it. |
| `application/main.gd` | `_show_event_screen()` routes every event screen: a choice screen opens on the flame as it stands, a result beat carries the previous event screen's lantern on. `_read_flame_at_event()` (PR #587) now reaches a live lantern; its docs no longer say the event screens carry none. |
| `tests/test_lantern_flame.gd` | The event rows now follow the lantern the player is shown; the Ashwarden variant replaces the old "no lantern" one; new rows for the mirrored seat, the carried lantern, the whisper heard once, a rebuilt screen reading afresh, and the seat at every shape, event and beat. |

## The decisions, as built

1. **The same lantern at the same seat.** The event screen hangs the reward screen's own component just under the run HUD's chrome, at the size and inset the layout book gives the combat lantern: 104 px at 18 px on the pad and the desktop, 68 px at 2 px on the phone.
2. **Mirrored where the choices reach it.** The choices' window docks at the left, and on the phone it is 520 px wide (14 to 534 of 844), so it reaches the seat (2 to 70, at 136 to 204) on every event and on the beat's Continue window too. On the pad and the desktop the window starts at 142 and 239 px, 20 and 117 px clear of the seat's box, and leaves it free. `RunLantern.keep_clear_of()` decides by the rects, not by the shape's name: at the phone the lantern hangs from the right edge, at the same 2 px inset; on the other two shapes it keeps the reward and shop seat.
3. **The result beat carries the lantern on.** Every event choice that moves the flame (the Shrine's Pray, the Mirror's Reflect and Shatter it, the Library's Study) is followed by a result beat, and the beat replaces the choice screen in the same frame. A tween played on the choice screen would run on a screen already gone, so the player would see the flame jump between screens. The beat now inherits the lantern with whatever it is showing, mid-tween included, and the coda after it inherits it in turn. A choice screen never inherits one, whatever it replaces (a rebuild, another Scenario put in its place), and a resume has nothing to inherit from: both open on the flame as it stands, drawn at once.
4. **The lines fire as they fire on the reward screen.** Nothing new. The reading taken at the event owes its lines in the domain (the Shrine's removal owes `flame.steady`, then `codex.lantern.shatter`); the next won fight draws them and queues the whisper as a run scene (`_on_combat_over`), and the once gates keep it to one hearing. The event screen does not speak.

## The images

Every capture is at the stage's device density (`--vp=2360x1640`, the 1180×820 pad stage at 2×; `--vp=2532x1170`, the 844×390 handset stage at 3×); the stills are shrunk to 1024 px on the long edge, the strips and the sweeps to 1400 px wide. The stills of the choice screens and the sweeps go through `tools/shot.sh`; the result beat and the turn strips come from a scratch driver that plays the same handlers the game calls (see *Reproduce*). The files say *handset* where the shape says *phone*: the CI classifier reads that word in a path as a release-platform change.

| File | Shows |
|---|---|
| [`kindling-pad.png`](kindling-pad.png), [`kindling-handset.png`](kindling-handset.png) | The Forgotten Shrine's choices on a Kindling deck (the starters plus Uppercut, Quakeblow and War Cry). |
| [`steady-pad.png`](steady-pad.png), [`steady-handset.png`](steady-handset.png) | The result beat after Pray and the removal of War Cry: the same run, now Steady Shatter, the lantern turned. |
| [`turn-pad.png`](turn-pad.png), [`turn-handset.png`](turn-handset.png) | The lantern on that beat every 0.2 s, on the flame's pinned clock: Kindling to Steady Shatter. |
| [`sweep-pad.jpg`](sweep-pad.jpg), [`sweep-handset.jpg`](sweep-handset.jpg) | All eleven events, each opened on a Steady Shatter deck, to look for a collision with any plate. |

## What I saw

- **Pad, Kindling.** The lantern hangs at the left edge just below the run HUD's relic icon, painted as it always was: orange glass, the HUD's own amber glow. The choices' window starts 20 px to the right of its box and 90 px below it, so neither the buttons nor the title come near it; the pane is further below.
- **Handset, Kindling.** The lantern hangs at the right edge, at the same height, clear of the choices, which fill the left and the centre. The eye of the shrine is left alone.
- **After the removal, both shapes.** The deck count on the HUD goes from 13 to 12 and the lantern is blue-white, a crown of shards in dark iron: Steady Shatter, as the domain reads a deck with three Shatter cards in five. It is the same lantern object that stood on the choices, and the beat's typed text and its Continue button sit clear of it.
- **The turn.** On the pad and the handset alike the glass stays amber until 0.4 s, turns through a warm grey at 0.6 s and is blue-white by 0.8 s (the crossfade PR 5 recorded: the painted light giving way to the new figure). Nothing snaps. The beat fades in over 0.45 s, so the colour change lands after the fade, not under it.
- **Eleven events, two shapes.** On the pad the lantern hangs at the left over background in every plate (arches, windows, foliage), and its dark iron reads against each; the knight, the idol, the gambler's skull and the trader's hand all stand clear of it. On the handset it hangs at the right, again over background: a tip of the Knight's cloak, a sleeve of the Trader's coat, the rim of the Fountain's basin. It covers no face and none of the things the events turn on, and it is drawn under the title, the pane and the choices, so nothing readable can ever go behind it.

**Seen, not touched.** Every handset capture, before and after this change, shows two older defects: the run HUD's relic icon sits over the left end of the first choice button, and the location text prints over the event's title. Neither belongs to this change; they want their own issue.

## Reproduce

The choice-screen stills and the sweep are Development Scenarios, so they run on the isolated Development profile and never touch a real save. The Kindling still of the pad is:

```sh
tools/shot.sh --scenario='{"id":"custom","revision":1,"seed":12,"locale":"en","overrides":{"act":0,"node":"2,4","gold":120,"add_cards":["uppercut","quakeblow","warCry"]}}' \
  --shape=pad-landscape --vp=2360x1640 --settle=8 --shot=/tmp/kindling-pad.png
```

The handset takes `--shape=phone-landscape --vp=2532x1170`. The sweep changes `seed` and `node` to a row below and `add_cards` to `["uppercut","quakeblow"]`, which reads Steady Shatter. Each (seed, waystone) is an Act I event waystone that rolls the event beside it, found by asking the Scenario kernel what each seed's event waystones roll.

| Event | Seed | Waystone | Event | Seed | Waystone |
|---|---|---|---|---|---|
| Forgotten Shrine | 12 | 2,4 | Humming Chest | 4 | 2,4 |
| Silvered Mirror | 1 | 5,4 | Fountain of Embers | 14 | 3,5 |
| Drowned Library | 11 | 2,2 | Forgotten Forge | 3 | 2,4 |
| Wounded Knight | 2 | 2,5 | Bone Gambler | 5 | 4,4 |
| Cursed Idol | 19 | 3,2 | Flesh Trader | 13 | 4,1 |
| | | | Ruined Camp | 6 | 4,0 |

A scenario boot cannot press a button, so the beat and the turn strips come from a driver that is not committed. It boots `Main` on the Kindling scenario, calls `_on_event_choice("0", "forgottenShrine")`, emits the pick overlay's `chosen` with War Cry's uid (the two handlers the buttons reach), waits for the typed text, pins the lantern's flame, and photographs. For the strip it puts the carried lantern back on a Kindling reading and hands it the deck's Steady reading again, tweened, then steps `LanternFlame.advance(0.2)` and photographs after each step.

## Residual risks

- **Device approval is pending**, as it is for PR 5: the look is a parameter set, the wiring is what this delivers.
- **Events with no result beat leave for the map at once**, so their lantern cannot be watched. The one deck-changing event without a beat, the Cursed Idol, adds a Hex, which is uncoloured glass, and the Forge's upgrade keeps every id, so neither moves the flame; every choice that does has a beat.
- **The lantern is small at the handset** (a 68 px box, about 30 px of art). It is the combat lantern's own size for the shape, and the same on the reward screen and the stall.
- **The weakest contrast** is a blue-white flame on the Mirror's and the Knight's pale-blue windows (the pad sweep); the iron still outlines it. It is the same trade PR 5 recorded for the stall's blue window.
- **Two older handset overlaps** (above) stay until someone owns them.

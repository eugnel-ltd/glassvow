# The title's rooms: one house, one light (#655)

**Owner instruction** (James, issue #655, 3 Oct 2026 09:43): "the menu; we have many options here. we need
to align them to the same immersive approach. eg: The Vigil; how to play; credits; also enhance
transition, eg when entering settings it's just 0 sec transit; the 'back to the road' i sometimes can
see the oval.. so make some detail and polish please." Clarified at 09:52: "it's currently 0s transit
means no good. need to make them better." Standing bar: AAA commercial, immersive, no static screens
(every state alive at rest), surprise me.

**Status.** This is the one build spec for #655. PR A (the oval, the ground, Reduce Motion, the type
floor), PR B (the passage, Settings, How to Play, Credits) and PR C (the Vigil as the hearth hall) are
built; where the build differs from the text, an *as built* note says how and why. V2′, the rose's
flight into the window after the unsealing, was cut (§13's first cut). It was written on the
lane branch `ui/title-rooms-2026-10-03` at `124c528d` (the pre-squash head of PR #654, whose tree is
identical to `2228f94f` on `main`). It continues the opening's design record,
`docs/design/2026-10-02-opening-start/README.md` (Concept A "Held Light", §7 motion spec, §8 Leadlight
kit, §16–§17 as built). Five surveys were taken at `124c528d` in the lane's scratch space (A the room
mechanics and the 0 s cut, B the Vigil, C How to Play and Credits, D the oval, E the before-stills); their
findings are folded in here and cited by letter. Three concept directions were then drawn and judged;
their mocks are in `mocks/`, and the shipped state they replace is in `before/` (§15 indexes both).

**Hard constraints carried through every section.** `domain/` untouched. No save change (the v2
lineage, `RunState`, `VigilState` and `Preferences` keys stay as they are). Main's route ids and
behaviours unchanged (§9 lists every observable delta, all of them presentation). Both locales, with
no new locale keys (§2.13). Shapes 844×390, 1180×820 (identity) and 1458×820, plus the flex device
stages. A12: no shaded 3D spatial material, no new shader at all, the transition grain stays the one
`hint_screen_texture` reader. Every transition skippable by a tap; Reduce Motion lands whole with a
short cross-fade, never a hard cut; nothing lengthens a wait. Fonts Cinzel, Alegreya and Noto Serif TC
only. Audio: the six shipped opening cues plus the shipped `click`, `relic` and `paneChoose`; no new
music.

---

## 0. What James will see

| | Today (`before/`) | After this spec |
|---|---|---|
| Settings | Appears and vanishes in one frame (`before/seq-settings-open-sheet.jpg`); a blue focus ring on CLOSE for a touch player | The lantern carries you to the room: it is lowered to your left hand, the room's lead is drawn out from it and the glass lights as its light reaches it (about half a second), and it all folds back into the flame when you leave. The way back is **Return** beside the lantern, the same place in every room |
| How to Play | A grey-rimmed web modal that opens scrolled past its own title (`before/11-help-pad.jpg`) | The same glass room as Settings, seven lit section panes, one page each; the Flame codex lines burn beside a flame of the colour they describe |
| Credits | A blue placard (`before/13-credits-pad.jpg`) | The road onward: the title's own wordmark becomes the head of the roll, the names drift past as you walk on, each line warming as the lamps reach it, and the track that is playing carries a breathing flame |
| The Vigil | A grey frame, then a rounded card over a starfield (`before/seq-vigil-open-sheet.jpg`); on a phone the RETURN button is off the stage | You turn back west to the hearth at the road's end: the Keeper keeps his seat by the fire, the deeds are lit by it, and looking up to the Rose Window brings the real Emberglass rose into the hall's own window. The road is not torn down; when you turn back it is exactly where you left it |
| The oval | A gold ellipse round the lantern after any return to the title (`before/22-oval-after-vigil-return-pad.jpg`) | Gone for touch. A keyboard player gets a gold rim on the lantern's own silhouette instead of an ellipse across the road |
| Every route | Fades up from the engine's 0.3 grey; Reduce Motion hard-cuts | The ground is the night (VOID); Reduce Motion is a 150 ms cross-fade everywhere |

---

## 1. Decision

### 1.1 The choice

Three directions were judged through three lenses (owner fit, UX, engineering):

| Direction | Owner fit | UX | Engineering | Sum |
|---|---|---|---|---|
| Free, "One light, no cuts" | 6 | **8** (winner) | **8** (winner) | **22** |
| Lantern, "The lantern opens" | 7 | 7 | 6.5 | 20.5 |
| Road, "Rooms along the road" | **7.5** (winner) | 5.5 | 5 | 18 |

**The base is Free**: the road is never torn down, one passage grammar serves every room, rooms take
input from their first frame, departures never block, the Vigil's art is warmed on a thread, and the
grey frame dies with one project setting. Free's weakness under the owner's own words is that 300 ms
in and 220 ms out still reads as instant, and that its rooms are all the same arch over a veil. So
the spec keeps Free's engineering and takes its **look and its time** from the other two:

- from **Lantern**, the light itself: the room is made of the lantern's light (lead traced from the
  sill nearest the flame, glass lit as the light front reaches it, the light folded back into the
  flame with a flare on leaving), at a pace that is felt (about half a second) but never waited on;
- from **Road**, the sense of place, following the precedent James accepted on 3 Oct ("the setup page
  please be immersive", answered by standing the departure in the road with a figure): the Vigil is the
  hearth hall with the Keeper by the fire, and Credits is the road onward.

The result has **two materials and one grammar**. Places (the Vigil, Credits) are somewhere in the
world, with content standing in them as the departure's beats do. Glass (Settings, How to Play) is
the leaded window the lantern lights. Both are entered by the same passage, left by the same
Return in the same place, sound the same, focus the same and fall back to the same Reduce Motion form.

### 1.2 Grafted, and where it lands

| Idea | From | Section |
|---|---|---|
| Never tear down the road; the Vigil from the title keeps its route but the title is **held** (hidden, paused) instead of freed | Lantern (held title), Free's own fallback; all three judges | §2.1, §9 |
| Interactive from frame 1; departures never block; a tap on another word kills a departure | Free | §2.6 |
| A double-tap guard on the opening tap's point (fixes Free's double-tap hazard) | UX judge | §2.6 |
| Felt timing: glass 520 / 400 ms, places 600 / 480 ms, with a damped swing tail that never blocks | Lantern pace, UX graft 2 | §5 |
| Light-front reveal (`reach`) and lead trace (`trace`), drawn without a new shader | Lantern | §2.4 |
| The tapped word rides to the room's crown and back (ghost word) | Free | §2.3 |
| One seat and one **Return**, anchored to the stage, the lantern itself tappable | Road (`LeadlightSeat`), UX graft 6, owner-fit graft 7 | §2.2, §3.1 |
| The Vigil as the hearth hall with the Keeper; three looks (hearth, window, floor) instead of tabs | Road | §4.1 |
| Deeds as carved rows with every description and reward visible (no tap to read) | Road rows, UX graft 3 | §4.1 |
| `LeadlightRose` with four pane states, one rose component for door and Vigil; bounded reading glass | Free, Lantern | §4.1 |
| How to Play as seven panes, one page each; phone numerals plus the active section's name | Free, Lantern, UX graft 10 | §4.2 |
| Credits as the road onward; wordmark as the first card; lamp line; small walk; now-playing flame | Road, Free | §4.3 |
| Licences as their own reading glass, not a 37,000 px fold | Lantern, Road | §4.3 |
| `LeadlightFocus` input modality; plaque follows visible focus; silhouette rim for keyboard focus | all three; rim from Road | §6 |
| `TitleWorld.inherit` for every remaining title rebuild; `lift` for route-form returns | Road, Free | §5, §9 |
| VOID clear colour; Reduce Motion `screen_in` fade; grey-frame gate; idle gate | Free, Road | §2.8, §11 |
| 0.6 s afterglow on the word you came back to | Lantern | §5 |
| Pipeline warm for first-use materials; device frame times as the acceptance | engineering judge | §11.6, §12 |
| After the unsealing only, the door's rose flies into the Vigil's window | Lantern (first to cut) | §5, V2′ |

### 1.3 Rejected, and why

- **Road's camera stances and wall sweep.** Yawing the projected camera moves a flat, cover-fitted
  painting 173–433 px against 0–25 px of overscan, empties the world-fixed mote field and runs past the
  eight lamp pairs; the wall hides a 175–210 ms (A12 estimate) frozen frame each way. The held title
  removes the rebuild the wall was hiding, so there is nothing left to cover.
- **Lantern's swallow-every-tap rule and 640 / 560 ms.** It costs a fast player a tap per room. This
  spec keeps the pace and drops the tax.
- **Free's 300 / 220 ms**, its 4×2 deed tiles with a single reading line (eight taps to read eight
  deeds), five-pane Credits, and the Vigil from the title as a modal (a change to Main's route
  behaviour).
- **Free's per-room arch for the Vigil.** It hides the Keeper and the fire behind a box; the place
  carries the room better and matches the accepted departure.
- **A door-to-window match-cut before the unsealing.** It states the L3 reveal early (story canon,
  `docs/story/01-world.md`; foreshadow-ledger rule 2). After the unsealing it is the payoff (V2′).

### 1.4 Every flagged blocker, resolved

| Flag (judge) | Resolution |
|---|---|
| Free makes the title Vigil a modal: Main route behaviour moves (UX, engineering) | The Vigil stays a route in every entry. From the title, `_show_route` holds the title instead of freeing it (§9). `_route_screen is VigilScreen`, `_remember_route` and Back → title are unchanged |
| Free's double-tap hazard: rooms cover the word that opened them (UX) | Double-tap guard (§2.6) and its test (§11.1) |
| Free reads as instant to an owner who said 0 s is no good (owner fit) | 520–600 ms entrances and 400–480 ms exits, felt, with input live throughout (§5) |
| Road's Vigil passage lengthens a wait; frozen wall frame (all three) | No wall; interactive from frame 1; title never rebuilt for the title Vigil; the build target and its contingency in §12 |
| Road's painting overscan under yaw (owner fit, engineering) | No camera yaw. The only lateral move is the Vigil turn, which pans the procedural world in screen space and slides the painting at most 0.03 W with a 1.03 scale; a coverage test holds every stage pixel covered at every sampled t (§11.1) |
| Road's mocks show a CSS blur the game cannot render (engineering) | No blur anywhere; depth is dimming only. Noted against every Road mock in §15 |
| Lantern's new `leadlight_reach.gdshader` has no warm plan (engineering) | No new shader: `reach` and `trace` are `_draw` with `Geometry2D` clipping (§2.4) |
| Reduce Motion instant swaps in all three (section, pane, look changes) | Every change, however small, is a 150 ms cross-fade under Reduce Motion (§2.7) |
| Road's RM Vigil dip to VOID | RM Vigil is a 150 ms cross-fade over the held road (§5, V1) |
| Rubric 18 px floor misses in all three; 60×60 hits | Every text in the rebuilt rooms and every new kit part is ≥18 px at 1180×820; every hit ≥60×60 at pad, ≥44 at phone; tested (§3.3, §11.1). Text outside the rebuilt rooms is open decision 1 |
| Road's seat overlaps the deeds scroll on phone (UX) | Content rects never intersect the seat rect; tested at every shape and device stage (§3.1, §11.1) |
| Free adds a new locale key for "licence not found" | Not added: the fold omits a missing file instead (the files are bundled and already pinned readable) |
| Two exits with two names in Settings (Lantern) | One exit everywhere: the seat's **Return** (§2.2) |
| Lantern raises five owner questions | Decided here (§14 keeps one) |

---

## 2. The house rules

### 2.1 Never tear down the road

The title (`TitleScreen`) is never freed to visit a room. Settings, How to Play and Credits are
overlays over the living title, as today. The Vigil opened from the title is still a route, but Main
**holds** the title under it instead of freeing it (§9): its world is hidden and paused once the turn
has landed, and resumes from the same phase when you turn back. No 61–74 ms (M1 Max) title rebuild, no
grey frame, no motes restarting, no oval path. Title rebuilds that remain (a language change, a
route-form return, departure Back) inherit the old world's clocks (`TitleWorld.inherit`, §9) so the
road continues rather than resets.

### 2.2 The lantern carries you; one way back

On every title-to-room passage the title's own `LeadlightLantern` is carried from its home to **the
seat**, bottom left, and stays there while the room is open; on leaving it goes home. It is the same
object, so its flame, its reading and its breath are the room's light: the glass is lit with
`LeadlightSheet.set_light` from the lantern's live wick every frame. While seated it draws above the
room (`z_index` 205) and ignores the pointer (Godot's GUI picking does not follow `z_index`).

A new kit part, **`LeadlightSeat`**, owns the way back in every room: a transparent hit rect over the
seated lantern's body plus a quiet `LeadlightWord` **Return** (`ui.menu.return`, "Return" / 「返回」) with a
small lead chevron drawn beside it (drawn, not a glyph, so no font fallback). Tapping the lantern or
the word is the same action; the two hits are separate rects, never one bounding box, so the seat
cannot take a tap meant for content beside it. It is anchored to the stage, never to content, so it cannot be scrolled
or pushed off. `LeadlightSeat.for_stage(shape, stage_size)` is a pure function returning the lantern
rect, the word rect and the two keep-clear rects, tested on every shape and flex stage. Where there is no
title lantern (a room opened in a run, or the route-form Vigil) the seat shows the word alone at the
same place.

The other ways out are unchanged in meaning: Escape / `ui_cancel` in every room, and a tap on the veil
in the glass rooms, now on **release without drag** (a wheel tick or the start of a scroll never closes
a room; survey C's D2). Settings' CLOSE pane, Help's "Fight On" button, Credits' Close button and the
Vigil's boxed RETURN are all replaced by the seat's Return (labels and places only; the `closed` and
`back_requested` signals are the same).

### 2.3 The word becomes the room's name

The tapped word lifts out of the road and rides to the room's crown, where it becomes the crown label
(the crown keys are the word's own: `ui.menu.settings`, `ui.menu.howToPlay`, `ui.menu.credits`,
`ui.menu.theVigil`, so no new copy). In English, Cinzel's small capitals cross-fade to the crown's
capitals over the last third of the flight; zh-Hant needs no case change. On leaving, the crown rides
back and becomes the word, which keeps a 0.6 s afterglow ("you came from here"). The ghost is a
`Label` owned by the passage at `z_index` 210 and freed on landing.

*As built after the PR B review:* the word never runs through lit text. Arriving, it lifts off at once
and eases into the crown (SETTLE_OUT over 420 ms: REVEAL's quint start outran the dimming furniture);
the neighbours it lifts through as it sets off (any it reaches inside 100 ms) go in 50 ms, the rest of
the furniture in 180; and any of the room's content its path crosses rises only once it has passed
(`LeadlightGhostWord.leaves_at`, the room host's `ghost_clear`). Leaving, the crown waits until the
content behind its path is dark (80 ms in a glass room, 140 in Credits, whose roll is gone by 180)
and then rides home by 360 ms; furniture it crosses on the way comes back behind it.

### 2.4 The light reaches the room

Glass rooms are drawn by the light of the seated lantern, in `LeadlightSheet._draw`, with no shader:

- **`trace`** (0..1): the arch's lead loop is drawn by arc length from the sill nearest the lantern,
  outward both ways (`draw_polyline` of a sub-path).
- **`reach`** (0..1): a disc grows from `reach_from` (the wick on stage, followed every frame). The
  glazing polygon is `Geometry2D.intersect_polygons(arch, disc)`, the quarry lines are clipped to the
  disc analytically, and a soft front band (two `draw_arc`s, flame colour mixed with GOLD, clipped to
  the arch by point-in-polygon) runs along its edge.
- **Content** is grouped (`reveal_groups()` on the room); each group rises 8 px and fades in when the
  front reaches its centre.

Places are lit by their own light: the Vigil by the fire and the seated lantern, Credits by the lamps.
Their content groups rise in order of distance from that light. The glass passage costs one 24-point arch
against a 48-point disc and about 120 segment clips per frame, for about 30 frames.

### 2.5 Two materials

| Material | Rooms | Ground | Chrome |
|---|---|---|---|
| **Glass** | Settings, How to Play (and the Credits licence glass, the Vigil's reading glass) | `LeadlightRoom` / `LeadlightSheet` over a VOID veil at 0.62, the road dimmed but breathing behind | crown in the arch, section panes, the seat |
| **Place** | The Vigil (the hearth hall), Credits (the road onward) | the world itself; content stands on a soft VOID legibility band, as the departure's beats do | crown and section panes in the same type and glass as the rooms, the seat |

Only glass is boxed (kit rule §8.1 of the opening record). Choices are always glass (`LeadlightPane`).

### 2.6 Input during a passage

- **Arrival.** The room's controls take input from the first frame they are drawn.
  - A press on the veil or on the bare place (not a control) during the arrival lands it and is
    swallowed.
  - **Double-tap guard:** during the first 300 ms, a press within 64 px (44 px on phone) of the opening
    tap's point is swallowed and lands the arrival, whatever is under it. Elsewhere, a press on a room
    control acts at once and lands the arrival.
  - Enter or Space lands the arrival; Escape lands it and then leaves.
- **Departure.** Never blocks. The title is thawed on frame 0 and takes input from frame 1. A press on a
  title word lands the departure (the leaving room is freed) and that word acts; any other press lands
  it and passes through.
- **Section, look or pane change.** A new tap retargets at once.
- **Floods and lifts** keep `TransitionLayer.skip`.

### 2.7 Reduce Motion

Every passage becomes one 150 ms linear cross-fade (`LeadlightMotion.REDUCED_FADE`) of the veil or band
and the room. The lantern fades out at home over 75 ms and in at the seat over 75 ms, so the room's
composition is identical. No ghost word, trace, front, swing, slide, walk or plate motion. Section,
look and pane changes cross-fade in 150 ms (the plate jumps under the fade). `TransitionLayer.screen_in`
becomes a 150 ms fade game-wide instead of today's hard cut. The flood keeps its shipped 0.15 s form.

*As built in PR A:* every change of what is on screen under Reduce Motion (each route, each room, confirm
or run menu opening or closing) is one cross-fade from the frame before it. Main asks the transition
layer for it just before the change (`TransitionLayer.cross_fade`); the layer copies the frame on screen
(a GPU texture copy, about 0.04 ms on the M1; a read-back where the renderer has no device), lays it over
whatever the change puts there and fades it out in 150 ms, linear, never more than a ninth a frame, so a
route built on the tap frame cannot spend the fade unseen. The new screen stands whole beneath it from its
first frame. Fading the leaving nodes through their root instead was tried and rejected: every stacked
layer blends on its own, which bunches the change into the fade's last frames (the Vigil's last step was
3.6 times its first), and it keeps a screen alive and able to route after the change. The screen that
leaves is freed at once, as under full motion. With nothing copied (the headless renderer), `screen_in`
fades up from the night.

*As built in PR B:* a room's passage takes the same form: Main copies the frame before the room opens or
leaves (`TransitionLayer.cross_fade`), and the room lands whole beneath it, the lantern already at the
seat or home. One copied frame cannot hold the lantern out of itself, so the text's 75 + 75 ms is met
in part: the lantern in its new place comes in from the fade's middle over a fade's length (75 to 225
ms), kindling as it comes. For the first half only the old one shows, going; then the old one (under
half) and the new one (under half) show together, faintly, for about five frames; and the plaque and the
crown dissolve through each other as any cross-fade does (`stills/pr-b/seq-g1-settings-pad-en-rm.jpg`).
Before the review the new lantern was whole beneath the copy from the first frame, so both showed for
the whole fade. Bringing it in over the second half alone (75 to 150 ms) put more than an eighth of the
change on one frame leaving Settings (§11.5's cut gate: 0.0127 against 0.0115); over 75 to 225 every
Reduce Motion sequence passes. With nothing copied (the headless
renderer) the room fades over 150 ms, linear, from its first frame; a leaving room fades out the same way
while the title is back whole at once.
Idle motion follows opening §7: the flame's flicker (and the Vigil's firelight, which is the fire's
flicker) stays; everything else at rest stops.

### 2.8 One ground

`rendering/environment/defaults/default_clear_color` is set to VOID `#05070e` in `project.godot`. Any
gap anywhere in the game is night, never the engine's 0.3 grey. The boot splash already is VOID.

### 2.9 Sound: one cue per tap

| Moment | Cue | Today |
|---|---|---|
| A room word tapped | `roomOpen` (rotating, 4 variants), played by the passage on the tap frame | `click` from the word plus, for Settings only, `roomOpen` from its constructor |
| The rose tapped (Vigil on the Rose look) | `relic` (shipped), no `roomOpen` | `relic` |
| Any close path (seat, veil, Escape) | `roomClose` (rotating, 3 variants), by the passage | Settings only; Help, Credits and the Vigil silent or `click` |
| Section, look or pane change | `paneChoose` | `click` or nothing |
| A complete rose pane selected | `glassTakesLight` | nothing |
| Licence glass opens / closes | `paneRise` / `roomClose` | `click` |
| The Settings language reopen | nothing (no second `roomOpen`) | `roomOpen` replayed |

`TitleScreen._choose` stops playing `click` for room ids. Music: the Vigil emits its first cue after
Main connects (`vigil`, or `roseWindow` when opened on the Rose look; fixes survey B §9.4); turning back
plays `title`, which now **resumes** where it stopped (§7, item 14).

### 2.10 Focus

One rule, in a new `LeadlightFocus` (§6): code-path focus is hidden unless the last input was a key or a
pad, and the plaque follows visible focus only. Every room's focus on arrival goes through it.

### 2.11 Captures and the headless suite

Every passage honours `_transitions.instant` and the headless renderer: arrivals land in the same
frame, departures free at once, so `--shot` stills and the test suite never wait.

### 2.12 Alive at rest

Every room has draw-only motion at rest (listed per room in §4) and is proven by three-frame bursts
(§11.4): at least 0.5% of the room's pixels change between frames 1 s apart (today: Help 0.00%,
Credits 0.00%, Vigil 0.00%, Settings 0.07%).

### 2.13 Copy

No new locale keys. Reused: `ui.menu.return`, the four room words, `ui.settings.title`,
`ui.help.*Title` and bodies, `ui.credits.*`, `ui.vigil.stats`, `ui.vigil.*Tab`, `ui.vigil.title`,
`ui.rose.*` (with `replayUnsealing` now visible). Help's section panes show each existing title up to
its dash (" — " in en, "——" in zh-Hant); the page heading carries the full title. Keys no longer read
(`ui.credits.close`, `ui.credits.themeLine`, `ui.menu.fightOn`, `ui.vigil.return`) stay in both
bundles; removing them is a separate clean-up. Copy debts this lane does not settle are in §13 (they go
to a story-skill batch).

---

## 3. Geometry

All values in stage pixels. Flex device stages (845×390, 844×443, 1180×885, 1180×824, 1458×911) take
their shape class's rules with the stage's own width and height; anchors are bottom-left for the seat
and top for content.

### 3.1 The seat

| Shape | Lantern art square at the seat | Return word (hit) | Keep-clear rects (no content) |
|---|---|---|---|
| pad 1180×820 | 220 px at (−6, 588); wick (104, 761) | (152, 742) 150×64 | lantern (0, 588)–(170, 820); word (146, 736)–(310, 820) |
| desktop 1458×820 | as pad (anchored bottom-left, not centred) | as pad | as pad |
| phone 844×390 | 132 px at (−4, 266); wick (62, 370) | (100, 340) 116×44 | lantern (0, 262)–(104, 390); word (96, 334)–(220, 390) |

The lantern's home is the shipped `TitleScreen.Layout` (pad 420 px at (380, 423); phone 226 px at
(309, 181)). The seat path is a lowered arc (control point 0.25 of the way, 40 px below the chord), so
the lantern reads as lowered to the hand, not slid. The lantern's hit covers its visible body (pad
(44, 596)–(164, 806), phone (24, 272)–(100, 390)); the word's hit is the column above.

*As built in PR B* (`presentation/ui/components/leadlight_seat.gd`): the two hits as the table gives them
overlapped by 12 px at pad (the body to x 164, the word from 152), so the lantern's hit stops where the
word's begins (pad (47, 597)–(152, 804)): two separate rects. The art square at (−6, 588) is partly off
the stage by design (its margins are clear); what the seat's test holds on the stage is the lantern's body
and both hits. The lowered arc is `LeadlightSeat.path`.

### 3.2 Room rects

| Room | pad 1180×820 | desktop 1458×820 | phone 844×390 |
|---|---|---|---|
| Settings (glass, fitted to its tallest section) | (318, 300) 792×≤470 | (457, 300) | (108, 6) 730×324 |
| How to Play (glass) | (316, 22) 832×732 | (471, 22) | (108, 6) 730×324 |
| Licence glass (Credits) | (316, 22) 832×732 | (471, 22) | (108, 6) 730×324 |
| Credits roll column (place) | centred on the stage, 600 wide; the roll shows in y 20–730 and starts under the wordmark (y 190) | centred, 600 wide | centred, 520 wide; y 6–330, starting at y 70 |
| Vigil column (place) | x 260 to the Keeper's left − 40, max 640 wide; header y 18–150, body y 168–730 | x 260–900 | x 112 to the Keeper's left − 40; header y 4–56, body y 62–330 |

No content rect intersects either of the seat's keep-clear rects, and every rect lies inside the stage; both are
tested at every shape and flex stage (§11.1).

### 3.3 Type and touch in the rooms

New tokens in `LeadlightTokens` (pad / phone): `SIZE_ROOM_CROWN` (24, 15), `SIZE_ROOM_HEAD` (20, 15),
`SIZE_ROOM_READ` (18, 14), `SIZE_ROOM_LABEL` (18, 13), `SIZE_ROOM_CARVED` (18, 12). `LeadlightRoom`'s
crown and section panes move to them, so Settings' crown and panes grow with the house (its rows are
untouched; see open decision 1). Every hit rect in the rooms is at least 60×60 at pad and desktop
(drawn smaller where the glass is smaller, with an invisible 60 px hit) and at least 44×44 at phone.
Rubric: `docs/commercial-rubric.md`, global criteria (18 px floor, 60×60 hits, a visible pressed state
within one frame, drag-off cancels).

---

## 4. The rooms

### 4.1 The Vigil: the hearth hall

The Vigil is the hearth at the road's west end (canon: 守夜之爐, `docs/story/01-world.md`). Choosing it
turns you back to it. The hall is the shipped `assets/art/scenes/opening-hearth.png` (already the
opening's beats and every departure's L0 linger), with the Keeper seated by the fire through the
shipped `HearthFigure.attach` stagecraft (its measured seat, hearth grade and haze), so it adds no new
canon and no new art. Content stands in the hall on a legibility band, as the departure's beats stand
on the road. The three tabs become **three looks across one hall**: to the hearth (Deeds), up to the
window (Rose Window), down to the floor before the fire (Epitaphs).

Reference mocks: `mocks/road-vigil-deeds-1180x820.jpg`, `mocks/road-vigil-rose-1180x820.jpg`,
`mocks/road-vigil-deeds-844x390.jpg` (the build differs from them where noted in §15).

**The hall framing rule.** `VigilHall.frame(stage, look) -> Transform2D` is pure. For the Deeds look the
plate is cover-fitted and enlarged ×1.08, then placed so the Keeper stands whole on the stage and his
hem stays on it:

- scale `s = cover(stage) × 1.08`;
- x offset `clamp(W − 24 − 1360·s, W − 1536·s, 0)` (1360 plate px is the Keeper sprite's right edge on
  the plate, from `HearthFigure`'s seat);
- y offset `clamp(min((H − 1024·s) / 2, H − 8 − 861·s), H − 1024·s, 0)` (plate y 861 is the hem).

Worked values, Deeds look: pad s 0.865, offset (−21, −33), Keeper at x 908–1156; iPad 8 (1180×885)
s 0.933, offset (−114, −35), Keeper at x 888–1156; desktop s 1.025, offset (0, −115), Keeper at
x 1101–1395; phone s 0.593, offset (0, −129), Keeper at x 637–808. The column's right edge is the
Keeper's left − 40 (pad 868).

**The three looks** (each a framing of the same plate, tuned per shape class in `VigilHall.LOOKS` and
pinned by the coverage test):

| Look | Framing | What is in frame | Content |
|---|---|---|---|
| Deeds (the hearth) | the rule above | the doorway onto the night road at the left above your lantern, the column, the Keeper at the fire | header, then the deed rows |
| Rose Window (looking up) | plate ×1.6 of the Deeds scale (pad about 1.38 stage px per plate px; phone 0.95), placed so the plate's own painted rose window lies wholly under the Emberglass rose, the hall dimmed to 0.72 | the high wall, the window, the moonlight falling from it | the rose at left, the reading glass at right |
| Epitaphs (looking down) | ×1.15, raised so the flagstones before the hearth fill the lower two thirds | the floor in firelight; the Keeper's hem and the fire's glow at top right | the carved lines, centred when few |

The painted window's centre and radius are measured on the plate in the build and pinned as constants
beside `HearthFigure`'s seat (estimated from a preview: centre (214, 180), radius about 90 plate px).
Worked pad Rose look: the painted window lands at about (296, 249) with radius 125, the rose's centre
at (300, 312) with radius 190, so the rose covers it and the hall never shows two windows; the plate's
top-left corner lands at or beyond the stage's.

**Header** (all looks, pad): crown `ui.vigil.title` ("THE VIGIL" / 「守夜」) in ROLE_PRIMARY 24, GOLD, at
(260, 26); under it the **ledger**, one carved line from `ui.vigil.stats` with carved numerals
(`LeadlightNumerals.carved`: Roman in en, Chinese in zh-Hant; "—" for no vow), ROLE_CARVED 18, gold at
0.7, e.g. "XII PILGRIMAGES · III DAWNS · DEEPEST VOW: II", at y 62. The three **look panes**
(`LeadlightPane`, LOZENGE, ROLE_LABEL 18, 52 drawn / 60 hit) stand across the top right, right-aligned to
W − 40 at y 96 (above the Keeper's head and clear of the rose): Deeds; Rose Window only with
`emberglass`; Epitaphs only with epitaphs (as today). The header never moves between looks. Phone: crown
15 and ledger 12 at the top left, the look panes at the top right.

**Deeds look.** One scroll in the body box (pad 608×562 from (260, 168); phone 485×268 from (112, 62)), with a 24 px
fade at its foot and a lead rail with a gold bead as its scroll indicator. Each deed is a row, about
76 px at pad and 62 px at phone, with no box, separated by lead hairlines:

- a 56 px leaded roundel holding the deed art (`assets/art/deeds/<id>.png`; an empty roundel if
  missing): backlit by the firelight when done, at 25% saturation and half brightness when not;
- the name in ROLE_LABEL 18, GOLD when done and PARCHMENT when not; the count right-aligned in
  tabular Arabic figures "9 / 15" (a meter reads best in figures; integer format);
- the description and "→ rewards" in ROLE_READ 18, exactly the shipped composition (withheld classes
  omitted, `aspect2` read as `ui.vigil.ashwarden`), rewards joined with "、" in zh-Hant;
- a **`LeadlightCame`** along the foot of the row: a 2 px LEAD line with a GOLD_DIM underline, lit GOLD
  up to the progress, an ember tip that breathes (2.8 s), white-gold with a glow when done.

At pad about 7.3 rows show; the eighth scrolls. Every datum of every deed is readable without a tap.
Rows are not interactive.

**Rose Window look.**

- **The rose** is `LeadlightRose` (the title door's component) extended with four pane states and a
  selection rim, so one component serves the door and the Vigil (the door keeps its held / not-held
  use through the default state map):
  - dormant: dark glass; armed: pale glass with an ember "?" that flickers with the lantern's ember;
  - revealed: lilac glass with a `LeadlightCame` arc along the outer rim showing progress and carved
    integer numerals "1 / 3" inside the pane (fixes "2/3.0");
  - complete: the mural through the mask, backlit, breathing ±8% (the shipped `LeadlightRose` breath);
  - selected: a gold rim drawn from the pane's own mask, never a rounded rectangle; no caption ever
    covers the mural.
- Under the rose, **six lozenges**, one lit per shard held: the count at a glance (rubric story (b)).
  When all six quests are complete, the lozenges give way to a visible `LeadlightPane` **"Replay the
  unsealing"** (`ui.rose.replayUnsealing`), node name `Replay`, behind the same gate as today.
- **The reading glass** at right is a `LeadlightSheet` lancet (spring 0.13, no quarry, lit from the
  window's side), pad (530, 168) 610×562, phone (330, 56) 506×274. It holds, in a fixed box that scrolls
  with fades, so nothing can push the seat or the stage edge:
  - the pane's name (ROLE_PRIMARY 22) and its state line ("1 / 3" with a came, "???" when armed, "Shard
    recovered" (`ui.rose.shardRecoveredShort`) when complete, `ui.rose.paneDark` when dormant);
  - its inscription, then **every archived dawn memory as full prose** (rubric story (a)), so a memory
    no longer hides the inscription;
  - a lead divider with a diamond, then `ui.rose.whisperLogTitleUpper` and the whispers heard, numbered
    in carved numerals, with `ui.rose.finalWhisperMark` last when there are more than 24.
- Selection keeps today's initial rule. Panes carry `accessibility_name` as well as their tooltip.

**Epitaphs look.** Each epitaph is a `Label` (the line-table text, as the tests require) in
ROLE_CARVED 18 with a dark groove shadow, numbered in carved numerals, vertically centred when there are
few and scrolling in the body box when there are many; the firelight crawls across them.

**Desktop** gives its extra width to the hall: the column stays from x 260, the Keeper and more of the
fire stand at the right. **Phone** shows the Keeper to the right of the column on the Deeds and
Epitaphs looks and lets the reading glass cover him on the Rose look.

**Every datum and action kept** (survey B's numbering):

| # | Datum / action | Where it lives now |
|---|---|---|
| D1–D3 | runs, dawns, deepest vow | the carved ledger line (vow in Chinese numerals in zh-Hant; fixes the Roman vow in zh) |
| D4 | 8 deeds (ClassScope-filtered): art, name, done mark, count, description, rewards, progress | deed rows; the done mark is the lit roundel and gold name; progress is the came |
| D5 | six panes in four states | the rose's pane states; the shard lozenges |
| D6 | selected pane detail and its priority | the reading glass (`_detail_copy` itself unchanged, still used for the accessible name) |
| D7 | accessible names | `accessibility_name` plus tooltip |
| D8 | whisper ledger and final mark | the reading glass, under the divider |
| D9 | Replay the unsealing | the visible `Replay` pane; same gate |
| D10 | epitaphs | the Epitaphs look (`_epitaph_tab`, `_epitaph_list`, `_show_epitaphs()` kept) |
| D11 | music cues | `vigil` on Deeds and Epitaphs, `roseWindow` on Rose; first cue emitted after Main connects |
| — | Return, Escape | the seat, `ui_cancel` |

**Alive at rest** (one clock in the new `VigilHall`, all `_draw` or modulate):

| Moves | Under Reduce Motion |
|---|---|
| Firelight: two additive `SkyField.disc` draws (the hearth mouth and the floor spill), ±12% from two summed sines and a 0.35 s step | kept (it is the fire's flicker) |
| Embers: 18–24 points rising from the hearth, each living 6–9 s, recycled | stop |
| The Keeper breathes: 1.2% vertical scale about the hem on a 5.6 s sine (`HearthFigure` gains an opt-in `breathe`, off by default, so the opening and the departure linger are unchanged) | stops |
| Done roundels' backlight follows the firelight; came tips breathe | stop (backlight holds) |
| Rose look: a moonlight shaft from the window drifts ±2° over 11 s with 30 dust motes; complete panes breathe; armed panes pulse every 4.2 s | stop |
| The seated lantern flickers | kept |

**Defects fixed** (survey B §9): the phone soft-lock and pad clipping (1), unbounded detail (2),
"2/3.0" (3), the wrong first cue (4), the invisible Replay (5), no sound on select (6), the Reduce
Motion hard cut (7), the zh "、" join and numerals (8), the rubric sizes (12). The en plural (9) and the
"Return to the Vigil" naming at run end (10) are copy for a story batch (§13); the legacy Act IV
entrance (11) keeps its behaviour.

**Contracts kept.** `VigilScreen`'s class, constructor `(vigil, content, shape, open_rose, sfx)`,
signals, `set_shape()` and `DEED_IDS`; every `Label` rule `test_class_scope` walks (names and
descriptions stay `Label`s, never `_draw` text); `_epitaph_tab`, `_epitaph_list`, `_deed_list`,
`_show_epitaphs()`; `RoseWindowView`'s constructor, `IDS`, `_detail_copy` and the `Replay` node; the dev
`vigil` scenario. The route-form Vigil (every entry but the title's) draws the same hall and a seat word
without a lantern, and no private `TitleWorld` any more (`RunStyle.add_backdrop` is no longer used here).

*As built in PR C* (`presentation/run/vigil_screen.gd`, `vigil_hall.gd`, `vigil_deeds.gd`,
`vigil_epitaphs.gd`, `rose_window_view.gd`, `presentation/ui/components/leadlight_rose.gd`; stills in
`stills/pr-c/`):

- **The window, measured.** The plate's painted rose is centred at plate (215, 184), radius 100 with its
  moulding (the glass alone is about 75). Looking up, the window is centred under the Emberglass rose and
  the plate is no smaller than it must be for its corner to stay on or past the stage's: the scale is the
  largest of the Deeds scale and the rose's centre over the window's on each axis (`VigilHall.frame`), so
  the rose stands exactly where the window is painted. At pad that is 1.696 stage px a plate px, not ×1.6
  of the Deeds scale (1.38), which left the window's moulding outside a 190 px rose and the plate's corner
  inside the stage. The rose's visible radius is the frame art's tracery ring, 0.84 of its half side
  (`LeadlightRose.RIM`). Phone: the rose at (220, 182), radius 112 (the plate at 1.02); the painted window
  lies inside it at every shape and flex stage, by `WINDOW_IN_ROSE` (0.92) of its radius
  (`tests/test_vigil_hall.gd`).
- **Looking up** dims the hall to 0.86, not 0.72: at 0.72 under the rose's own dark the hall read as a
  blank wall. The moonlight falls from the window down to the floor where you stand, by the doorway: a
  shaft towards the fire ran under the reading glass and was never seen. The rose carries a little of the
  door's warm halo (`radiance` 0.35).
- **Looking down** keeps the Keeper's hood under the look panes (`VigilHall.HEAD_ROOM`, 154 px at pad, 46
  on a phone): bottom-aligned at ×1.15, the phone's floor look cut his hood off at the stage's top.
- **The header and the column** are as written. Every row of the body box ends 40 px short of the Keeper
  on each look (`VigilScreen.body_for`); its foot is 90 px above the stage's (60 on a phone). On a phone in
  English the carved ledger does not fit beside the three look panes, so it stands under their row; the
  rose (at y 182) and the reading glass (from y 64) clear it, and the full rose's Replay pane stands under
  the glass at its right, clear of the seat (no part of the header stands on another, nor the rose, the
  glass or Replay on any of them: `tests/test_vigil_screen.gd`).
- **Carved counts the faces can draw.** The zh-Hant faces ship subset to the locale's own text
  (`tools/subset_noto_serif_tc.py`), which never writes 零, 千 or 萬: a fresh Vigil's ledger drew
  "▯ 次朝聖". Where its numerals would need one of them, a count is written in figures
  (`LeadlightNumerals.carved_drawn`), as English writes its zero; every CJK character the hall sets is held
  to the shipped faces by the screen's test. The subset's corpus is the real fix (§14, open).
- **Deeds.** A row is about 88 px at pad (its name, its line and its came at the rooms' 18 px), so six
  stand whole at pad and the seventh fades at the foot; a row fades by how much of it the view still shows,
  never cut through by the edge (the spec's 24 px fade cut the roundel of a row half in view). An unlit
  roundel is the art under cold glass (a fill over it at 0.55), not 25% saturation: a desaturation needs a
  shader or a CPU copy of every icon, and the cold glass is the kit's own word for an unlit pane.
- **Epitaphs** are set in the reading face at 20 px (16 on a phone), their numerals carved: tracked Cinzel
  broke a one-line epitaph into two at 18 px. Each is still a `Label` with the line-table text.
- **The rose.** Each pane's centre is its mask's (`LeadlightRose.PANE_AT`); a pane's tap is a fifth of the
  rose's side (90 px at pad, 53 on a phone). The selected pane's rim is its mask grown ×1.05 about its
  centre in gold, over the mask in the backing's dark, under the pane: a rim of the pane's own shape. A
  revealed pane's count is whole figures in the carved face ("2 / 5"). The six lozenges hide under the
  Replay pane. In the reading glass a dormant or armed pane is named by its accessible name ("Dormant
  Emberglass pane 6", "Unknown Emberglass pane 2"), already in both bundles: no new copy.
- **Alive at rest**, all drawing and one clock (`VigilHall`): the firelight, embers, the Keeper's breath,
  the roundels' backlight, the came tips, the shaft and its dust, the complete panes' breath and the armed
  panes' pulse, as the table says. The epitaphs' firelight is the fire's flicker, so it stays under Reduce
  Motion with the fire.
- **The back shelf** (#657, the cards lane's PR 7) has a seat and nothing in it: `VigilHall.shelf()`, a
  named, empty, input-blind layer on the plate (plate px, moving with every look), between the plate and
  the fire's light, under the Keeper.

**Canon guard.** The Emberglass rose stands in the hall's own window: that is canon (the Rose Window,
爐邊彩窗, faces in at the fire). The title door's rose never travels into the Vigil before six shards
and `scenes_seen` holding `unsealing`; after that, V2′ (§5) is the sanctioned payoff, checked under the
story skill's foreshadow-ledger rule before it ships.

### 4.2 How to Play: seven panes of one window

A glass room, crown "HOW TO PLAY" / 「玩法說明」, lit from the seat.

- **Pad and desktop.** A column of seven section panes at the left (`LeadlightPane`, TAB shape, 240
  wide, 64 tall, ROLE_LABEL 18, a carved numeral and the section's title up to its dash, wrapping to two
  lines where it must), and one page at the right (about 512 wide, ROLE_HEAD 20 heading with its
  numeral, ROLE_READ 18 body at line height 1.45, `[b]` in a lighter gold). Every page fits without
  scrolling at pad (estimated: the longest, The Lantern with its coda, is about 370 px of a 598 px page); the
  page still sits in a `ScrollContainer` with fades, opened at 0.
- **Phone.** Seven numeral lozenges I–VII across the top (60×44), with the active section's name in
  ROLE_LABEL 13 beside them; the page scrolls under them. A horizontal swipe on the page moves to the
  next or previous section, as a shortcut only.
- **Data kept.** All seven sections in order with their `ui.help.*` bodies; `{count}` = 3 (Act IV stays
  unsaid); the Flame codex coda as a `RichTextLabel` named `Coda` directly after the Lantern body, now
  inside the Lantern page; no `Coda` node when the codex is empty; `HelpScreen.new()` with no arguments,
  `closed`, `set_shape`.
- **The codex flames.** Each heard line sits beside a small flame glyph (the plaque's flame glyph) in the
  colour it describes, from `LanternFlame.COLOUR` keyed by the flame path the row's slot names, breathing
  on 2.8 s. The colour is shown and never named (the flame lock).
- **The ⬤ energy glyph** is set at the body size and baseline-aligned through a `[font_size]` tag, so it
  stops stretching its line.
- **Fixed:** D1 (opens at scroll 0 with focus on the first pane, never pulled to a button at the end),
  D2 (release without drag), D3 (phone sizes from tokens), D5 (one family with Settings).
- **Alive at rest:** the lantern's light drifts on the glass with the flame's breath; glints run along
  the leading; the lit pane breathes (`LeadlightMotion.breath`, 3.3 s); the codex flames flicker. And two
  small living diagrams, cut first (§13): on The Glass page a row of five facet lozenges chips one every
  2.4 s and refills; on The Lantern page an ember travels into a lantern glyph every 4 s. Each is under
  40 lines of `_draw` and still under Reduce Motion.

Reference: `mocks/lantern-rooms-family-1180x820.jpg` (middle panel; the build's seat and exit differ).

*As built in PR B* (`presentation/run/help_screen.gd`): the panes name their sections in Cinzel's small
capitals, as written (the title's own words are set that way): in capitals, "I  THE PILGRIMAGE" broke
after "THE" at any width the column can give. The column is 264 wide (not 240), so all but two names
stand on one line, and the page about 470. A page's heading is the title up to its dash, after its
numeral, and what follows the dash stands under it as a quieter line in the reading face (gold at 0.72):
the heading's tracked capitals split zh-Hant's "——" into two dashes. The `[b]` runs keep the body's
colour: `test_stagecraft` pins the Lantern's body as authored markup, and a colour tag would change it.
The energy glyph is set at 0.78 of the body size. The glass stands over the title's wordmark, so the
wordmark goes with the title's furniture while How to Play is open (`LeadlightRoomHost.covers_wordmark`);
otherwise its tip showed past the arch's shoulder. On desktop the glass stands at x 455, the same 142 px
right of the stage's centre as at pad (the table's 471 has no rule behind it). A change of shape class
(pad to phone) rebuilds the room on the lit section. Fight On goes: the way back is the seat's Return,
the veil or Escape.

### 4.3 Credits: the road onward

Credits is a place: the road you stand on, walked a little further. The title's furniture goes, the
lantern is lowered to the seat, and the title's own wordmark stays where it is and becomes the head of
the roll.

- **The roll**, centred, 600 wide at pad and desktop, 520 at phone, over a radial VOID legibility band
  (about 0.7 at its centre):
  - the wordmark (the title's own `TextureRect`, lent to the roll and returned on leaving);
  - "CREDITS" (the ghost word lands here as the roll's first heading);
  - `ui.credits.bodyBrand`, then THE GLASS (`ui.credits.headingGlass`, `ui.credits.bodyGlass`; the
    pinned zh string stays);
  - MUSIC with its count line and the titles in two columns of twelve at pad and desktop (one column on
    phone), from the manifest in its order; SOUND with its count line; TYPE (three lines); ENGINE; and
    the footer last.
  - Headings ROLE_HEAD 20 GOLD; names ROLE_READ 20 PARCHMENT; secondary lines 18 TEXT.
- **The lamp line** sits at 56% of the stage height, where the nearest lamp pair passes. A line warms as
  it crosses it (alpha 0.75 → 1.0, PARCHMENT → `#fff1d0`), a per-label modulate.
- **The walk.** After 1.2 s with no input the roll drifts at 22 px/s (16 on phone). A touch, drag, wheel,
  key or focus change takes over at once and the drift resumes 3 s after the last input; it stops when
  the footer reaches the lamp line. `TitleWorld` gains a small `walk` (metres, clamped to 2.0) added to
  the eye's z and driven by the roll's progress, and the painting scales about the door by
  `1 + walk × 0.012`, so the lamps really pass and no edge can show (the scale only grows). Under Reduce
  Motion there is no drift and no walk: a plain scroll.
- **Now playing.** The title whose cue is `MusicBus.current_cue` carries the breathing flame glyph.
- **Held until the unsealing.** Track titles that belong to Act IV or the unsealing (the cue list is
  taken from `docs/music-ledger.md` and pinned as a constant with a test) show as a carved "· · ·" row
  until `scenes_seen` holds `unsealing`; the count line stays 24. Help says three acts; the credits no
  longer contradict it (foreshadow-ledger rule 2; checked under the story skill in the commit).
- **Not shown any more:** the internal pack ids (`stained-glass-v1-act4`, `ashglass-v1-opening`) and the
  duplicated "Ashglass Vigil" theme line (survey C D6). Items with `wired: false` are filtered.
- **Licences.** Two `LeadlightPane`s at the end of the roll, `ui.credits.fontLicences` and
  `ui.credits.engineLicences`. Each opens its own **licence glass** (a `LeadlightRoom` sheet, §3.2) over
  the paused, dimmed roll, with its own scroll: the font texts (`_build_font_licences()` fills
  `_font_licence_wrap` inside it) or the engine text, components and licence texts (37,000 px, now
  scrolled inside the glass, never inline). The literal `\n` in one engine string is replaced at render.
  The Sentry SDK's MIT notice, read from `addons/sentry/LICENSE.md`, is added to the engine glass when the
  addon is in the export (survey C D8). The seat's Return closes the glass first, then Credits.
- **Kept:** `CreditsScreen.new()` with no arguments, `FONT_LICENCES` (an alias constant once the
  licence code moves to its own file), `_build_font_licences()`, `_font_licence_wrap`, no Label holding
  "6e06911" or "0.5.0+".
- **Alive at rest:** the drift and the walk themselves; the lamp line; the now-playing flame; the road's
  motes, weather and lamps; once the roll has stopped, the door's nimbus breathing.

Reference: `mocks/road-credits-1180x820.jpg` (the start of the roll).

*As built in PR B* (`presentation/run/credits_screen.gd`, `credits_roll.gd`, `credits_licences.gd`): the
wordmark is not reparented; it stays the title's, drawn over the room while it is lent (z 201) and carried
by the roll's scroll (`TitleScreen.offset_wordmark`), and goes home on leaving. `ui.credits.headingBrand`
("GLASSVOW") is no longer read: the wordmark is the brand's heading. The manifest has grown to 28
tracks since this spec was written, so the count line reads 28 and the columns are fourteen each. The
held list is Act IV's six stems as the music ledger lists them (`act4Combat`, `act4Boss`, and the held
alternates `act4CombatA`, `act4CombatB`, `act4CombatD`, `act4BossB`): the ledger names no music cue of
the unsealing's own. The band is the kit's soft light in VOID at 0.7. A place has no veil to tap: a tap
on the bare road never closes Credits (`LeadlightRoomHost.veil_closes`); the seat's Return and Escape do,
and close an open licence glass first. The licence texts are set at the rooms' 18 px floor and their
headings at 20, inside their glasses (`CreditsLicences.Shelf` and `Glass`). The Sentry SDK's MIT notice shows where
`addons/sentry/LICENSE.md` is in the pack and the SDK is loaded; every export's include filter now carries
it and the fonts' OFL texts (§14). The roll is built with the room down to the ninth row of each column,
and the rest a part a frame after the tap frame, below the fold and unseen under the arrival's reveal
(§11.6). The door's nimbus breathing once the roll stops was
not built: the road's own motes, weather and lamps, the lamp line and the now-playing flame keep it alive.

*As built after the PR B review:* each line comes up at the warmth the lamp line gives it, so nothing
dims in one step as the room lands (it did: every line away from the lamp fell to 0.75 on the landing
frame), and a line fades out over the roll's top and foot (40 px, 24 on a phone) instead of being cut
through by the view's edge. Leaving (C2), the roll fades from the frame Return is tapped, farthest from
the lamp line first, and is gone by 180 ms; "Credits" rides back from 140 ms and the title's furniture
returns from 200, so the plaque never prints over a line still lit. The passage's own focus on arrival
is not a touch: the first drift comes 1.2 s after the landing. A licence glass sets its text below its
crown (the arch's spring plus 30 px; the glass's own seat had put it in the arch, under the crown, its
scroll bar out past the lead), fades the text into the glass at its scroll's top and foot, and fades
the roll behind it to 0.1 under its own night of 0.5 (at the text's 0.4 the roll still read round the
arch, cut by its lead). Its scroll takes the focus on arrival (a ScrollContainer takes none of its own):
Up, Down, Page Up and Page Down read it, focus stays in it, and Enter on the pane behind does not open
it again. The licence texts are set to the glass's column: their hard wraps at about 78 characters are
joined where a line runs on, and kept at a short line, a blank, a rule, a colon, a list item or a
copyright notice (`CreditsLicences.reflow`), so no line breaks twice ("…DEALINGS IN" / "THE" /
"SOFTWARE.").

### 4.4 Settings: the lantern-maker's window

Controls and behaviour unchanged: the five sections, every row, the language transaction, ERASE and its
two steps, the diagnostics notice, the privacy link; `closed`, `reset_requested`, `language_changed`,
`focus_language()`, `set_shape` and every tested node name.

- **Place.** The `LeadlightRoom` stands right of the seat (§3.2), fitted to its tallest section, so the
  empty lower 60% and the lantern's finial under the room are gone (`before/05-settings-pad.jpg`), and the
  dimmed wordmark and door read above it. Its glass is lit from the seated lantern.
- **The way back** is the seat's Return; the CLOSE pane goes. The footer keeps the version line.
- **Section change** (G3): the page cross-rises and a glint runs along the lead from the pane to the
  page; `paneChoose`.
- **Focus** on arrival: the first section pane through `LeadlightFocus` (hidden for touch). Today a
  touch player sees a blue ring on CLOSE.
- **`roomOpen` moves out of the constructor** into the passage, so the language reopen is silent.
- **Alive at rest:** the shipped light drift and glints, now breathing with the seated flame; the
  slider grabbers (lantern discs) breathe ±6% in step; the lit pane breathes.

*As built in PR B* (`presentation/run/settings_panel.gd`): the room stands 124 px right of the stage's
centre at pad and desktop (318 and 457, as the table has them), its foot 50 px over the stage's foot
(770 at 820, 834 on the iPad 8's 884), as tall as its tallest section needs and no taller than 470; on a
phone it fills the stage beside the seat (108 to 6 from the right, 6 to 60 from the foot). Its rows,
toggles, notes and panes are at the rooms' sizes (18 px, 60 px hits at pad and desktop): the shipped
15 px row panes and 12 px notes are gone. The build line in its footer is the title's build identifier
and keeps its 10 px under the same waiver (§14). A change of shape rebuilds the room on the lit section,
since its rows are cut for their shape. The slider discs breathe as a brightness of ±6%. Fitting the room
to its tallest section shapes every section's text, the four unseen ones included; the height is kept
for the launch (by shape, language and the notes the room carries), so only the first opening pays it.

### 4.5 Rooms opened in a run

How to Play and Settings also open from the run menu over the map or combat. There is no title lantern
there: the seat shows the word alone, the room is lit from the `RunHud` lantern's position when it has
one (else the bottom-left corner), the veil sits over the frozen route (combat is never frozen, as
shipped), and the passage runs without the lantern and ghost lanes (X1). Settings opened at boot with
`--settings` lands whole, with no passage.

*As built in PR B:* the run's HUD carries no lantern in this build, so a room in a run is lit from the
stage's bottom-left corner. The run menu's How to Play and Settings no longer play their own click: the
room's `roomOpen` is the tap's one cue. The run menu folds away under the room it opens (180 ms,
SETTLE_OUT, from the tap frame) instead of vanishing on it, and a room rebuilt on a change of shape keeps
its seat without a lantern's tap (`LeadlightRoomHost.lend_seat`).

---

## 5. Transitions

Times are from the tap frame, in milliseconds, at pad. Curves are `LeadlightMotion` pairs: REVEAL =
QUINT/OUT, EXIT = CUBIC/IN, SETTLE_OUT = CUBIC/OUT, IN_OUT = CUBIC/IN_OUT, BREATH = SINE/IN_OUT.
"Live" is when input is taken. Skip and Reduce Motion follow §2.6 and §2.7 unless the row says
otherwise.

### 5.1 Every transition

| ID | From → to | Settled | Live | Skip | Reduce Motion | SFX | Focus on arrival |
|---|---|---|---|---|---|---|---|
| G1 | Title → Settings / How to Play | 520 (swing tail to 900) | frame 1 | §2.6 arrival | 150 cross-fade, lantern 75 + 75 | `roomOpen` | first section pane |
| G2 | Settings / How to Play → title | 400 (afterglow to 960) | title frame 1 | never blocks | 150 cross-fade | `roomClose` | the word that opened it |
| G3 | Section → section (Settings, How to Play; How to Play swipe on phone) | 220 | at once | retargets | 150 cross-fade | `paneChoose` | stays on the pane |
| C1 | Title → Credits | 600; drift after 1.2 s idle | frame 1 | §2.6 arrival | 150 cross-fade; no walk or drift | `roomOpen` | the seat's Return |
| C2 | Credits → title | 480 | title frame 1 | never blocks | 150 | `roomClose` | Credits word |
| C3 | Credits ↔ licence glass | 320 in / 240 out | at once | lands | 150 | `paneRise` / `roomClose` | the glass's scroll / its pane |
| V1 | Title → the Vigil (the turn west), title held | 600 | frame 1 | §2.6 arrival | the hall cross-fades in over the road in 150; lantern 75 + 75 | `roomOpen`; music `vigil` | the lit look pane |
| V2 | Title rose → the Vigil on the Rose look | 600 | frame 1 | as V1 | as V1 | `relic`; music `roseWindow` | the selected pane |
| V2′ | As V2 after the unsealing only: the door's rose flies into the window | 600 | frame 1 | as V1 | no flight; as V1 | as V2 | as V2 |
| V3 | The Vigil → title (the turn east), title un-held | 480 | title frame 1 | never blocks | 150 | `roomClose`; music `title` (resumed) | The Vigil word (or the rose) |
| V4 | Look ↔ look (Deeds, Rose Window, Epitaphs) | 480 | at once | lands; retargets | 150 cross-fade, plate jumps under it | `paneChoose`; music cue swap | the new look pane |
| V5 | Rose pane → pane | 220 | at once | retargets | 150 cross-fade | `paneChoose` (`glassTakesLight` on a complete pane) | the pane |
| V6 | The Vigil → Replay the unsealing (all six complete) | 240 flare + 480 flood | — | `TransitionLayer.skip` | 150 to cover | `glassTakesLight` | the scene's |
| V7 | Replay end → the Vigil (route form, Rose look) | flood clears 320 | frame 1 | lands | 150 | `roomOpen` | first complete pane |
| V8 | Unsealing end, legacy Act IV entrance, dev scenario → the Vigil (route form) | `screen_in` 450 from VOID (the wipe first with a live run, shipped) | frame 1 | lands | 150 fade | `roomOpen` | the lit look pane |
| V9 | Route-form Vigil → title | lift 300 | title frame 1 | `skip` | 150 | `roomClose`; music `title` | hidden on the lantern |
| S5 | Settings → Erase confirm | 320 | frame 1 | lands | 150 | `roomOpen` (the confirm's) | the quiet answer |
| S6 | Erase confirm → Cancel → title (behaviour as shipped) | 180 + G2 400 | title frame 1 | never blocks | 150 | `roomClose` (shipped quiet answer) | Settings word |
| S7 | Erase confirm → Erase Everything → fresh title | 180 + flood 480 + clear 320 | — | `skip` | 150 to cover, 150 out | `paneChoose` (shipped) | none (first key brings the lantern) |
| S8 | Settings language toggle | 150 | at once | — | same | `click` (the toggle's, shipped) | the language toggle, via `LeadlightFocus` |
| X1 | Run menu → How to Play / Settings over map or combat, and back | 520 / 400 | frame 1 | as G1 / G2 | 150 | `roomOpen` / `roomClose` | first pane / restored hidden |
| X2 | Departure Back, and Begin Anew → Stay on the Road → title | lift 300 | title frame 1 | `skip` | 150 | `click` (Back) or `roomClose` (Stay), both shipped | hidden on the lantern |
| X3 | Run menu → Title | `screen_in` 450 from VOID (the wipe with a live run, shipped) | frame 1 | — | 150 fade | shipped | hidden |
| X4 | Any route, Reduce Motion on | `screen_in` 150 linear, no scale | — | — | (this is the RM form) | — | — |

A room word tapped while another room is leaving lands the leaving one at once (it is freed) and
starts its own G1, C1 or V1. A room opened over another (`_show_overlay` replacing `_modal`) lands any
passage first.

### 5.2 What moves

**G1, title → glass room (520 ms)**

| Lane | Window | Curve |
|---|---|---|
| The tapped word dips (shipped press) and becomes the ghost | 0 | shipped |
| Title furniture (plaque and sub-line, Rekindle pane, the other words, carved slabs, consent line, version) to alpha 0 | 0–180 | EXIT |
| Veil VOID 0 → 0.62 | 0–320 | SETTLE_OUT |
| Lantern home → seat along the lowered arc, 420 → 220 px | 0–480 | IN_OUT |
| Lantern pool `reach` 1 → 0.15 (about 1.6 screens of additive fill go) | 0–480 | SETTLE_OUT |
| Lantern swing, ±3° damped on its chain | 380–900 | damped sine; never blocks |
| Ghost word → crown rect; en small capitals to capitals over the last third | 0–420 | REVEAL |
| Lead `trace` from the sill nearest the seat | 60–360 | SETTLE_OUT |
| Light front `reach` from the wick across the glass; glazing lit inside it | 80–440 | REVEAL |
| Content groups rise 8 px and fade in as the front reaches them, 200 ms each | 120–520 | REVEAL |
| The room's light follows the lantern's live wick | every frame | — |

**G2, glass room → title (400 ms)**

| Lane | Window | Curve |
|---|---|---|
| Content and glazing go dark, far to near from the seat | 0–220 | EXIT |
| Lead retracts to the sill | 40–240 | EXIT |
| Crown rides back to its word and becomes it | 0–360 | REVEAL |
| Veil 0.62 → 0 | 80–400 | SETTLE_OUT |
| Lantern seat → home, `reach` 0.15 → 1 | 120–400 | IN_OUT |
| Flame `flare` 0 → 0.35 → 0, "the light returns" | 200–400 | BREATH |
| Furniture back, nearest the lantern first, 30 ms stagger | 160–400 | REVEAL |
| Afterglow on the returned word (a glow, no hairline) | 360–960 | SINE/OUT; never blocks |

**G3, section change (220 ms):** the outgoing page fades (0–100, EXIT); the incoming rises 6 px and
fades in (20–220, REVEAL; on a phone swipe it slides 12 px from the swipe's side); the pane lights; one
glint runs along the lead from the pane to the page (40–220). The room never resizes.

**V1, title → the Vigil, the turn west (600 ms)**

| Lane | Window | Curve |
|---|---|---|
| Title furniture to alpha 0 | 0–180 | EXIT |
| The road turns away: `TitleWorld.pan_px` 0 → +0.08 W (a screen-space shift of its projected points; its sky fills the rect, so no edge); the painting, the door's rose and the wordmark slide +0.03 W while the painting scales 1 → 1.03 about its centre; all to alpha 0 | 0–400 | SETTLE_OUT |
| The hall comes in from the west: plate at its Deeds framing − 0.08 W → framing, alpha 0 → 1, drawn above the road | 0–420 | SETTLE_OUT |
| Lantern home → seat, `reach` → 0.15, swing | 0–480 (swing to 900) | IN_OUT |
| Fire: firelight 0 → 1, embers begin | 200–600 | SETTLE_OUT |
| The fire answers the flame: a 1.15 flare as the lantern seats | 480–720 | BREATH |
| Ghost word "The Vigil" → crown "THE VIGIL" | 0–420 | REVEAL |
| Header, panes and rows rise as the firelight reaches them, from the hearth side, 40 ms stagger | 160–600 | REVEAL |
| On landing the title's world, painting, vignette, chain, rose and wordmark are hidden and their processing disabled (`hold_world`) | 600 | — |

The plate (×1.08 enlarged, see the framing rule) covers the stage at every t; the coverage test samples
t = 0, 0.25, 0.5, 0.75 and 1 at every shape. The road and the hall are both drawn for at most 25 frames.

**V2′ (after the unsealing only).** The door's `LeadlightRose` travels from the door to the reading
position of the Vigil's rose (100–560, IN_OUT), growing to its size, and cross-fades into the Vigil's
rose at 560; it flies back during V3 (0–360). Gate: six shards and `scenes_seen` holding `unsealing`,
tested on a fixture that has not seen it.

**V3, the Vigil → title, the turn east (480 ms)**

| Lane | Window | Curve |
|---|---|---|
| `hold_world(false)` on frame 0: the road's clocks resume where they stopped | 0 | — |
| Content to alpha 0 | 0–200 | EXIT |
| Crown rides back to "The Vigil" | 0–360 | REVEAL |
| The hall slides −0.08 W and fades | 0–360 | EXIT |
| The road slides back from +0.08 W and fades in | 40–440 | SETTLE_OUT |
| Lantern seat → home, flare | 120–480 (flare 300–480) | IN_OUT |
| Furniture back | 200–480 | REVEAL |

**V4, look change (480 ms):** the plate's framing moves to the new look (0–480, REVEAL); the old
content drifts with the plate at 0.6× and fades (0–180, EXIT); the new content rises 8 px and fades in
(140–480, REVEAL, 40 ms stagger); on the Rose look the moonlight shaft fades in (160–480). The Keeper and
the fire are on the plate, so they move with it.

**V5, pane select (220 ms):** the old rim fades (0–100), the new rim fades in (40–220) and a glint runs
round the new pane's lead; the reading glass cross-fades (out 0–100, in 60–220).

**V6, Replay (L3 only):** the six panes brighten to 1.6 (0–240, SETTLE_OUT), then
`TransitionLayer.flood` from the rose's centre in GOLD (240–720, CUBIC/IN); the scene is built under the
cover; the held title is freed with the route change.

**C1, title → Credits (600 ms)**

| Lane | Window | Curve |
|---|---|---|
| Furniture to alpha 0, except the wordmark | 0–180 | EXIT |
| Legibility band 0 → 0.7 | 0–320 | SETTLE_OUT |
| Lantern home → seat, swing | 0–480 (to 900) | IN_OUT |
| Ghost word "Credits" → the roll's first heading under the wordmark | 0–420 | REVEAL |
| The roll's first screen rises line by line from the wordmark down, 40 ms stagger | 120–600 | REVEAL |
| The first step: `walk` 0 → 0.4 m | 0–600 | BREATH |

**C2, Credits → title (480 ms):** the roll fades, farthest from the lamp line first (0–240, EXIT); the
heading rides back to its word when it is on screen, else the word relights; the wordmark glides back to
its seat if the roll moved it (0–480, REVEAL); `walk` → 0 (0–480, IN_OUT); the band fades (80–400); the
lantern goes home (120–480); the furniture returns (200–480).

**C3, licence glass:** in, the glass rises 12 px from its pane and fades in (0–320, REVEAL) while the
roll pauses and dims to 0.4; out, the reverse (0–240, EXIT).

**S5, Settings → Erase confirm (320 ms):** Settings sinks (alpha → 0, scale → 0.985, 0–160, EXIT); the
lantern stays seated; the passage's veil fades out as the confirm's own VOID 0.62 veil fades in
(0–180), so the darkness holds steady; the confirm makes its shipped entrance (sheet `enter`, 320).

**S6, Cancel:** the confirm leaves (sheet `exit` 0–180 with its veil, new for every confirm) while the G2
lanes run from 0 (lantern home, furniture back). Cancel lands on the title, as shipped.

**S7, Erase Everything:** the confirm leaves (0–180); `TransitionLayer.flood` from the seated lantern's
wick in VOID, the light going out (0–480, CUBIC/IN); the reset and a fresh title (a cold lantern) are
built under the cover; the flood clears (320, SETTLE).

**S8, language toggle:** the old room is frozen on top; under it the title is rebuilt (inheriting the
old world, lent instantly with the lantern at the seat, no `screen_in`) and the new room is built landed;
the old room fades out over 150 ms (linear). No re-arrival, no second `roomOpen`.

**X2 and V9, lift (300 ms):** the outgoing route screen is reparented onto the transition layer and
frozen; the title is built beneath it, landed and not lent (for X2 it inherits the departure's world,
which stands on the same road, so the road is identical); the outgoing screen fades out (0–300, EXIT);
the title's furniture rises (60–380, REVEAL).

*As built in PR B* (`presentation/ui/leadlight_passage.gd`, `components/leadlight_room_host.gd`): one
`LeadlightPassage` (Main's, made with the first title so it sees the tap that opens a room) runs G1, G2,
C1, C2, S5 to S8 and X1 on its own clock (a suite steps it by hand); the room's own lanes (trace, the light
front, its content rising) are the room host's `arrive_at` and `leave_at`. The lantern's swing and the
word's afterglow are the lantern's and the word's own (`LeadlightLantern.swing`, `LeadlightWord.afterglow`);
the word in flight is `LeadlightGhostWord`, two labels scaled between the word's size and the crown's
rather than re-shaped each frame. The double-tap guard holds its 300 ms from the tap even once it has
landed the arrival; Enter and Space land an arrival and are consumed. A press lands every room leaving,
and passes through. Every yes-or-stay sheet leaves through the passage with a 180 ms fade (EXIT), so the
Erase confirm's own exit (S5 to S7) is the same for Begin Anew, Abandon and Leave the Road. The language
reopen's old room lingers 2 above the new one and survives Main's route reset (`LeadlightPassage.clear`
keeps a lingering room); everything else the passage holds is landed and freed by it. The S7 flood is the
night (VOID) from the seated wick, the title asked to `leave()` first so no invisible word can take a tap
under the dark. The opening word is hidden on every path, the crown being the word now.

*As built after the PR B review* (the timings above stand; these curves and windows moved, each because
the frames showed it): leaving answers on the frame Return is tapped. On EXIT's slow start a room stood
almost whole for eight frames (about 7% of the change in the first third of G2) and then the lantern
whipped home in eight, a lag and then a rush. Now in G2 the glass goes dark and its lead retracts from
0 (SETTLE_OUT over 220 ms), the content goes far to near from the seat by time (each group over 100 ms,
all of it by 160: tied to the light's edge, the panes' column went in half a frame), the veil lifts from
0 (SETTLE_OUT to 400), the seat's word goes in 160, the lantern sets off home at 40 ms on a sine (BREATH)
to 400, and the furniture returns from 160, each piece easing in (SETTLE_OUT, not a quint whose first
frame took the wordmark to half) over at least 140 ms, 80 ms of stagger in all; C2 is the same with the
roll gone by 180 (farthest from the lamp line first), the band lifting from 0 and the furniture from 200. Arriving, the furniture goes from the first frame (SETTLE_OUT over 180), and the
seat's Return comes in from 360 to 520 ms, once the lantern is nearly seated, never under it in flight.
A section change (G3) lets the leaving page go first (SETTLE_OUT over 80 ms) and brings the new one in
from 60 to 220, so the two pages' text never prints over each other. The word in flight is §2.3's.

*As built in PR C* (the Vigil's lanes are its own: `VigilScreen.arrive_at`, `leave_at`, `_look_to`; the
title's half is `TitleScreen.turn` and `hold_world`): V1, V3 and V4 keep their windows. Three curves moved,
each because the frames showed it. The header and each look's parts rise over 260 ms on SETTLE_OUT, not
200 on REVEAL: the rose and its reading glass are large, and a quint's first frame brought a third of
either in at once (`stills/pr-c/seq-v2-pad-en.jpg` before the change put 40% of V2's change on one frame).
They rise in order of their distance from the light: the hearth's side on the Deeds and Epitaphs looks,
the window's on the Rose look, where the rose you came for stands. The plate's framing in V4 moves on
IN_OUT, not REVEAL (whose first two frames took a third of the climb to the window), and the old look
leaves on SETTLE_OUT from its first frame, not EXIT (it stood whole while the plate had already moved).
The legibility band follows the move. The Keeper is the one part of the hall that comes in slower than
the plate: his ember haze is clipped to his glass by a clip pass, which composites him with the hall's
alpha applied twice. `TransitionLayer.lift` (V9, X2) fades the lifted screen on SETTLE_OUT from its first
frame, not EXIT. V2 has no word in flight: the crown fades up as a room's does without one.

Reference storyboards: `mocks/free-storyboard-title-settings.jpg` and
`mocks/free-storyboard-title-vigil.jpg` (the lanes and the ghost word; the build's times are this
section's, not the mocks'), `mocks/lantern-storyboard-reach-and-fold.jpg` (the light front, the trace
and the fold with its flare).

---

## 6. The oval

### 6.1 Diagnosis

The oval is the lantern's keyboard focus ring, drawn by the `_FocusHalo` style box in
`presentation/ui/components/leadlight_lantern.gd`: a gold ellipse of radii 0.36 and 0.50 of the
lantern's side whose top touches the plaque, so it reads as hanging from BACK TO THE ROAD. A touch
player sees it because of Godot 4.7's focus visibility: a tap gives a button *hidden* focus, and any
code-path `grab_focus()` with no argument makes focus *visible*, even on a control that already holds it
hidden. Four paths do that today:

1. **A return to the title.** `presentation/title/title_screen.gd` (`_focus_first`) only asks whether
   anything holds focus. After a route rebuild, the old screen's tapped button (the Vigil's RETURN,
   departure Back, the Settings language toggle, Begin Anew's Stay) still holds hidden focus because
   `queue_free` waits for the frame's end, so the new title grabs the lantern visibly. This is the
   "sometimes": a cold boot has no focus owner.
2. **A tap on the lantern during the launch rite.** The rite's skip calls the same `_focus_first`, which
   flips the lantern's own hidden focus to visible.
3. **Any key or pad press**, including a bare modifier (Shift or Cmd for a macOS screenshot), through the
   title's `_unhandled_input`.
4. **Main's thaw after an overlay** records focus with `has_focus()` (hidden counts) and restores it with
   a plain `grab_focus()` (`application/main.gd` (`_thaw_surfaces`)): the underline left under SETTINGS
   after a tapped close (`before/23-oval-after-settings-close-pad.jpg`).

The plaque lights its own focus look (a gold hairline and an ember halo stretched to about 4:1 behind
"BACK TO THE ROAD") on `focus_entered`, which fires for hidden focus too: that is the softer second
oval. Its two-segment linear falloff, and the lantern pool's, band into visible contours at 7×
magnification: the faint third.

Proving still: `before/22-oval-after-vigil-return-pad.jpg` (the Vigil, RETURN tapped, back on the title:
the full ellipse and the hairline, with a touch player's input only). Keyboard form:
`before/03-title-focused-pad.jpg`.

### 6.2 Fix

1. **`LeadlightFocus`** (new, `presentation/ui/leadlight_focus.gd`, about 55 lines):
   `note(event)` sets the modality to *keyed* on an `InputEventKey` that is not a bare modifier (Shift,
   Ctrl, Alt, Meta, Caps Lock), an `InputEventJoypadButton` or an `InputEventJoypadMotion` beyond 0.5, and
   to *pointer* on a mouse button, a touch or a drag. `give(control, force_visible := false)` calls
   `control.grab_focus(not (keyed or force_visible))`. Main's `_input` calls `note` once per event and
   never consumes it.
2. **Every code-path grab goes through `give`:** the title's `_focus_first` (a forced call from a key
   still shows the ring), every room's first focus, `LeadlightConfirm`'s quiet answer,
   `presentation/run/departure_screen.gd` (`_focus`), and Settings' `focus_language()`.
3. **The title's key path ignores bare modifiers**, so a screenshot shortcut never shows a ring.
4. **Main's freeze and thaw keep visibility:** `_freeze_under_modal` records `button.has_focus(true)`
   (visible only); `_thaw_surfaces` restores with `grab_focus(not was_visible)`.
5. **The plaque follows visible focus only:** the lantern forwards `has_focus(true)` from its
   `NOTIFICATION_DRAW` (Godot redraws a control whenever its focus visibility flips) as a
   `focus_shown(bool)` signal, and the title sets `_plaque.focused` from it. A touch that slides off the
   lantern no longer leaves the halo lit.
6. **The keyboard ring becomes a rim**, not an ellipse across the road: a silhouette of the lantern art
   (a white alpha mask built once per process from `lantern-hero.png` at 256², lazily on the first
   visible focus) drawn behind the art in GOLD at 0.45, scaled ×1.04 about the glass centre.
   *As built:* grown outward evenly instead (the union of the body's silhouette shifted 3 mask px, and
   half that, every way: about 5 px at 1180×820, 2.6 px on a phone), since a scale about the glass centre
   thickens the band with distance from it, into a solid cap over the chain. The chain is not rimmed: the
   rim starts at the roof (the art's 240 of 1024 px), so it never climbs to the plaque on the chain's ring.
   The plaque's hairline runs in the clear band between the name's ink and the sub-line's, measured from
   the shaped glyphs (`LeadlightPlaque.hairline_y`), since the sub-line is tucked into the name's line box.
7. **Smooth light.** The plaque halo uses a six-stop smoothstep falloff, grown 10% across and 60% up and
   down (was 18% and 90%), its height tied to the name's width so its aspect never exceeds 2.6:1; the
   lantern pool texture goes to 512² with six stops; under Reduce Motion the pool takes the flame's
   colour (`_apply_kindle` sets its RGB as well as alpha), not white.
8. With the title held under the Vigil (§2.1), path 1 no longer happens for the Vigil at all; the fix
   still covers every other return.

### 6.3 Proof

**Deterministic** (`tests/test_focus_modality.gd`, headless, Main booted on an isolated profile). Each
touch path is driven as a player would: `LeadlightFocus.note` with a touch event, `grab_focus(true)` on
the tapped control, its `pressed` signal, then one frame. Asserted after each:
`title.lantern.has_focus(true) == false`, `title._plaque.focused == false`, and no `BaseButton` under
Main has `has_focus(true)`.

| Path | Driven |
|---|---|
| a | title → the Vigil → Return (held form) |
| b | title → the Vigil route form (dev scenario) → Return (rebuilt) |
| c | departure Back |
| d | Begin Anew → Stay on the Road |
| e | map → run menu → Title |
| f | Settings → language toggle → Return |
| g | Settings, How to Play, Credits each closed by tap |
| h | rite running, tap on the lantern body |
| i | a bare Shift key: no visible focus anywhere |
| j | a Tab key: `lantern.has_focus(true) == true` (keyboard players keep their ring) |

Mutation proof, recorded in the PR: with `LeadlightFocus.give` reverted to `grab_focus()`, the suite
fails on a, b, c, d, e, f, g and h.

**Stills** (`tools/capture_rooms.gd`, headed, real Main, pad and phone, en, saved run): paths a, c, e,
h, i and j, each 1 s after landing. Pass:

- 64 points sampled on the old ring's path (centre `rect.size × 0.5 + (0, side × 0.04)`, radii
  `(0.36, 0.50) × side`, ±2 px): **0 of 64** within ±12° of GOLD's hue with saturation over 0.45 and
  value over 0.55 (`before/22` gives at least 40 of 64);
- the gold pixel count in that annulus is under 1% of the before still's (the residue is the lantern's
  own gilded metal, measured on a cold-boot control still);
- a crop of the plaque with levels lifted shows no halo edge;
- path j (Tab) shows the silhouette rim (gold within 6 px outside the art's alpha edge on at least 60% of
  its perimeter samples) and no ellipse.

*As measured in PR A* (`stills/pr-a/focus-paths.txt`): every path a, c, e, g, h, i and j at pad and phone
scores 0 of 64 on the gold samples and a band count equal to the cold-boot control's. The spec's gold does
not see the shipped ring, though: a 1.2 px line of GOLD at 0.55 over the blue road reads at saturation
0.10–0.15, so `before/22` scores 1 of 64 and less band gold than the control. The ring is therefore also
measured as what it is, a line (a pixel 0.12 brighter than the road 4 px either side, at a sample and one
beside it): `before/22` 43 of 64, `before/03` 44 of 64, every path above 0 of 64, absolutely and beyond the
control. The plaque crop with levels lifted is `oval-plaque-levels-pad-en.jpg`; the rim covers 97–100% of
the perimeter samples. The phone Vigil's RETURN stands below the stage until PR C, so on that path its
tap is delivered to the button as the viewport delivers a tap (the run says so).

---

## 7. Title detail and polish

1. The oval (§6).
2. The VOID ground (§2.8).
3. Reduce Motion never cuts: `screen_in`'s 150 ms fade (§2.7).
4. **The pressed plaque.** Today it goes bright yellow with a heavy pale outline (`before/00-overview.jpg`,
   still 04). It becomes LIT_GOLD with an ember underglow and the 0.97 dip, no outline stroke.
5. **Smooth light** for the plaque halo and the pool (§6.2, item 7).
6. **One cue per tap** (§2.9).
7. **A pressed state within one frame** on every title word and the Rekindle pane:
   `LeadlightMotion.press` on `button_down`, with the hairline (rubric).
8. **Hit rects.** The six quiet words and the Rekindle pane get 60 px tall hits at pad and desktop; the
   visuals do not move. *As built:* and 44 on a phone, the touch floor (the Rekindle pane's glass is drawn
   34 tall there); no two taps overlap (`tests/test_title_rubric.gd`).
9. **The afterglow** on the word you came back to (G2).
10. **The beckon** is held while a room is open and re-armed on return, so the idle ember never flies
    to the plaque a second after a room closes.
11. **The title's `_unhandled_input` returns at once while lent or held.** Today Main's
    `set_process_unhandled_key_input(false)` misses it (the title overrides `_unhandled_input`, not the
    key variant).
12. **The road persists** across every remaining rebuild (`TitleWorld.inherit`) and is held, not
    rebuilt, under the Vigil.
13. **Departure Back and Begin Anew → Stay** lift the departure off the same road (X2) instead of a
    fade from grey.
14. **The title music resumes.** `MusicBus` remembers each cue's playback position for the session and
    resumes a cue it returns to (`incoming.play(position)`), so the title track no longer restarts from 0
    after the Vigil. No new music.
15. **First-use pipelines are warmed.** The Vigil's additive firelight, `HearthFigure`'s clip pass and
    `rose_pane.gdshader` at Vigil size are drawn once at alpha 0.004 under the title on its first idle
    frame after landing (the rite's own frame-0 warm already covers the title's), so the first V1 never
    compiles on the tap frame.
16. **The Vigil's art is warmed on a thread:** about 1 s after the title lands, Main requests the hall
    plate, the Keeper, the mural, frame and six masks and the eight deed icons with
    `ResourceLoader.load_threaded_request`; the reference is dropped when a run starts.

*As built in PR C:* item 14 resumes the road's and the hall's cues only (`MusicBus.RESUMES`: `title`,
`vigil`, `roseWindow`), each stem where it stopped this session; a fight's, a stinger's and the map's cues
still start from their top (a victory fanfare resumed mid-phrase would be wrong; "each cue" read as the
owner's intent, the title's track after the Vigil). Item 15 is RoomWarm's last step: once its rooms are
done it draws `VigilHall.pipeline_sample` (the plate, the fire's and the moonlight's additive light, the
Keeper's clip pass, the rose's pane shader at its size in every state, a came) for one frame under the
road at 0.004. Item 16 loads the hall's art and also its two tracks and the title's own on a worker
(`Main._warm_vigil_art`): a 3.7 MB track read on the tap frame cost 5.5 ms on the M1. The art is let go
once a run starts and nothing is still loading (`Main._take_vigil_art`); RoomWarm also builds the hall
off the tree once, both its looks, for its glyphs at their sizes.

Out of scope, recorded: a "news" glint on The Vigil word from `vigil.news` (clearing it needs a domain
command); the door's rose showing six dark panes on a fresh install against the art ledger's L0 ruling
(an art and story decision).

---

## 8. Carried from the PR #654 review

1. **Escape on the departure's first beat returns to the title** again (desktop and keyboard only; Back
   is on screen). `DepartureScreen` handles `ui_cancel` in `_unhandled_input` on beat A only, emitting
   `back_requested`; the gift and art beats ignore it (they have no Back). Test in `test_departure.gd`.
2. **`_setting_out` is cleared in `_show_title`**, as hardening: a title can never inherit a stale
   "setting out" from an abandoned departure. Test: set it, show the title, assert it is false.

Both ride in PR A (§10).

---

## 9. Main: what changes, what does not

**Unchanged.** Route ids (`continue`, `begin`, `vigil`, `rose`, `help`, `settings`, `credits`, `dev`,
`quit`) and `application/main.gd` (`_on_title_choice`); `application/main.gd` (`_on_title_pick`) still
floods only `continue` and `begin`; every room's constructor and signals; one `_modal` at a time, set to
null on the same frame as a close (`test_confirm_sheets`); `_modal is SettingsPanel` straight after a
language toggle (`test_live_locale_switch`); the title never frozen under a room; the Vigil a route in
every entry with `_route_screen is VigilScreen`, `_remember_route(_show_vigil.bind(open_rose))` and Back
→ title; the dev `vigil` scenario; `domain/` and the save.

**Changed (all presentation):**

1. **One `LeadlightPassage`**, owned by Main, drives every title ↔ room passage (it wraps a
   `LeadlightRite`, so `land()` is the rite's skip). `application/main.gd` (`_show_overlay`) starts an
   arrival when the screen is a `LeadlightRoomHost`; `application/main.gd` (`_close_overlay`) still nulls
   `_modal` and thaws on the same frame, then hands the node to the passage, which detaches it, makes it
   inert and frees it on landing (at most 400 ms later). `application/main.gd` (`_clear_route`) lands and
   frees anything the passage holds. Confirms, the run menu, the deck view, potions, treasure and the dev
   console are untouched, except that every `LeadlightConfirm` now leaves with its 180 ms exit through
   the same detach.
2. **The held title.** When `_show_vigil` runs with a `TitleScreen` in `_choice_screen` and no live run,
   it moves the title to a new `_held_title` slot before `_show_route(screen, false, &"vigil", false)`,
   whose `_clear_route` then leaves it alone; the title is lent (§2.2) and its world held on landing. The
   Vigil's `back_requested` goes to a new `_leave_vigil()`: with a held title it runs V3, restores
   `_choice_screen` and `_remember_route(_show_title)` on the same frame and hands the Vigil to the
   passage; otherwise it calls `_show_title()` as today. Every other route change frees `_held_title`.
   `application/main.gd` (`_reshape`) reshapes it too.
3. **`TransitionLayer.lift(control, time)`** for route-form returns (V9, X2), and `TitleWorld.inherit`
   wherever an outgoing screen has a world.
4. **Language toggle (S8):** `application/main.gd` (`_on_language_changed`) keeps its transaction; the
   closing panel lingers frozen for 150 ms instead of vanishing, and the reopened panel lands whole.
5. **Erase (S5–S7):** `application/main.gd` (`_confirm_reset`) hands the lent title to the confirm;
   `application/main.gd` (`_on_reset_choice`) runs S6 or S7. Cancel still lands on the title.
6. **Labels:** Settings' CLOSE, Help's "Fight On", Credits' Close and the Vigil's RETURN become the
   seat's Return.
7. **The veil closes on release without drag**, not on press (survey C's D2 fixed).
8. **`_show_title` clears `_setting_out`** (§8).
9. **`_input` notes the input modality** (§6).

*As built in PR B:* `_show_overlay` hands a `LeadlightRoomHost` to the passage (`arrive`, with the title
when the title is what the room opens over, the tapped word from `_on_title_pick`); `_close_overlay` nulls
`_modal`, thaws on the same frame and hands the node to `_release_modal` (a room departs, sinks under the
Erase question, or lingers over a language reopen; a confirm is dismissed; anything else is freed at once).
`_show_title` continues the road it replaces, the title's or the departure's (`TitleWorld.inherit`), and
does not fade a title in under a language reopen. `TransitionLayer.lift`, the held title and
`TitleWorld.pan_px` are PR C's: nothing in PR B uses them.

*As built in PR C:* `application/main.gd` (`_show_vigil`) holds the title only when the title's own Vigil
word or rose opened it (`from_title`, passed by `_on_title_choice`): a dev scenario, the unsealing's end
or a run's sealed door would otherwise hold a title built for another profile or a moment ago and bring
it back stale. The title moves to `_held_title` before `_show_route`, the passage carries the lantern in
(V1, V2) and the hall's `rest` holds the title's world (`TitleScreen.hold_world`: the road, the painting,
its lamps, the vignette, the rose, the wordmark and the furniture hidden and still, nothing of the title
focusable). `application/main.gd` (`_leave_vigil`) runs V3 on the same frame (the title back in
`_choice_screen`, released, `_remember_route(_show_title)`, the hall to the passage, `title` asked for,
the word that opened the hall given the focus, hidden for a touch); without a held title it builds the
title beneath the lifted hall (`_lift_to_title`, V9), as departure Back and Begin Anew's Stay now do (X2).
`_clear_route` frees a held title; `_reshape` reaches it. The Vigil's first cue comes from `announce`,
after Main connects. A room names its opening sound (`LeadlightRoomHost.opening_cue`): the Vigil opened
on the rose plays none over the rose's own `relic`. The route form plays `roomOpen` and, leaving,
`roomClose`.

---

## 10. Implementation plan

### 10.1 Branches and order

Three PRs, each independently mergeable, in order. PR A is small and lands first, so James sees the
oval and the grey gone in the next build.

- **PR A** goes on `ui/title-rooms-2026-10-03`, rebased onto `origin/main` first (its base `124c528d` is
  #654's pre-squash head; the tree equals `2228f94f`, so `git rebase --onto origin/main 124c528d` is
  clean). This spec is its first commit.
- **PR B** and **PR C** each branch from `main` after the previous one merges.

### 10.2 Commits

Line counts are additions plus deletions, estimated. No code file passes 600 in one commit.

**PR A: the oval, the grey and the cut**

| Commit | Files (± lines) |
|---|---|
| A0 | this spec, `mocks/`, `before/` (docs) |
| A1 VOID ground; RM `screen_in` | `project.godot` (+1); `presentation/stage/transition_layer.gd` (+14/−3); `tests/test_transition_rm.gd` (new, ~70) |
| A2 focus modality and the oval | `presentation/ui/leadlight_focus.gd` (new, ~55); `presentation/title/title_screen.gd` (+30/−8); `application/main.gd` (+18/−6); `presentation/ui/components/leadlight_lantern.gd` (+60/−20: forward visible focus, rim, pool); `presentation/ui/components/leadlight_plaque.gd` (+30/−14: visible focus, halo, pressed look); `presentation/run/settings_panel.gd`, `help_screen.gd`, `credits_screen.gd`, `presentation/ui/components/leadlight_confirm.gd`, `presentation/run/departure_screen.gd` (±4 each); `tests/test_focus_modality.gd` (new, ~260) |
| A3 #654 carried items | `presentation/run/departure_screen.gd` (+12); `application/main.gd` (+1); `tests/test_departure.gd` (+45) |
| A4 evidence tool | `tools/capture_rooms.gd` (new, ~260: promoted from survey E's scratch driver, but booting the real Main and driving its methods; the title paths, `--seq`, `--burst`, the grey gate) |

**PR B: the passage, Settings, How to Play, Credits**

| Commit | Files (± lines) |
|---|---|
| B0 evidence tools | `tools/capture_rooms.gd` (+140: rooms, sections, `--at`, `--rm`); `tools/bench_rooms.gd` (new, ~220) |
| B1 kit | `presentation/ui/leadlight_tokens.gd` (+12); `presentation/ui/components/leadlight_sheet.gd` (+100/−10: `reach`, `trace`, second light, glazing alpha); `presentation/ui/components/leadlight_room.gd` (+75/−15: room tokens, panes across, G3, glint); `presentation/ui/components/leadlight_seat.gd` (new, ~160 with the pure `for_stage`); `tests/test_leadlight_seat.gd` (new, ~130); `tests/test_leadlight_sheet_reach.gd` (new, ~90) |
| B2 passage and Settings | `presentation/ui/leadlight_passage.gd` (new, ~300); `presentation/ui/components/leadlight_room_host.gd` (new, ~140: `closed`, veil release-without-drag, `ui_cancel`, seat, `crown_rect`, `reveal_groups`, `first_focus`, guard); `presentation/title/title_screen.gd` (+150/−12: lend, reclaim, furniture, word rect, afterglow, beckon hold, input early return, press within a frame, 60 px hits); `application/main.gd` (+95/−15); `presentation/run/settings_panel.gd` (+55/−50); `presentation/ui/components/leadlight_confirm.gd` (+35: exit, veil hand-over); `presentation/ui/components/leadlight_lantern.gd` (+30: swing, seat travel); `tests/test_room_passage.gd` (new, ~320) |
| B3 How to Play | `presentation/run/help_screen.gd` (+240/−185); `tests/test_stagecraft.gd` (±4, deliberate: the Coda's sibling is read inside the Lantern page); `tests/test_locale.gd` (±6, the seam map); `tests/test_help_room.gd` (new, ~130) |
| B4a licence move (mechanical) | `presentation/run/credits_licences.gd` (new, +235); `presentation/run/credits_screen.gd` (−235) |
| B4b Credits, the road onward | `presentation/run/credits_screen.gd` (+230/−160); `presentation/stage/title_world.gd` (+50: `walk`, `pan_px`, `inherit`); `presentation/title/title_screen.gd` (+25: wordmark lent to the roll); `presentation/run/credits_licences.gd` (+25: Sentry notice); `tests/test_credits_roll.gd` (new, ~150); `tests/test_title_world.gd` (new, ~100); `tests/test_presentation.gd` and `tests/test_locale.gd` (±6 deliberate) |
| B5 rooms in a run | `application/main.gd` (+25); `presentation/run/run_hud.gd` (+6, the lantern's stage position); `tests/test_rooms_rubric.gd` (new, ~160) |

**PR C: the hearth hall**

| Commit | Files (± lines) |
|---|---|
| C1 held title, lift, music resume, warm loads | `application/main.gd` (+120/−20); `presentation/title/title_screen.gd` (+45: `hold_world`, pipeline warm); `presentation/stage/transition_layer.gd` (+55: `lift`); `presentation/audio/music_bus.gd` (+18); `tests/test_vigil_hold.gd` (new, ~240) |
| C2 the hall | `presentation/run/vigil_hall.gd` (new, ~280: framing rule, looks, firelight, embers, shaft); `presentation/story/hearth_figure.gd` (+18: opt-in breathe); `presentation/ui/components/leadlight_came.gd` (new, ~90); `tools/capture_rooms.gd` (+60: looks, states, memory); `tests/test_vigil_hall.gd` (new, ~220: framing, coverage, Keeper clear of the column) |
| C3a deed rows extracted | `presentation/run/vigil_deeds.gd` (new, ~190); `presentation/run/vigil_screen.gd` (−150) |
| C3b the Vigil screen | `presentation/run/vigil_screen.gd` (+230/−200: header, looks, seat, Epitaphs, `announce`); `tests/test_locale.gd` (±6 deliberate) |
| C4 the rose | `presentation/ui/components/leadlight_rose.gd` (+130/−20); `presentation/run/rose_window_view.gd` (+210/−230); `tests/test_vigil_screen.gd` (new, ~200) |
| C5 the turn and the looks | `presentation/ui/leadlight_passage.gd` (+130: place passages V1, V3, V4); `presentation/run/vigil_screen.gd` (+60) |
| C6 the rose flight after the unsealing (first to cut) | `presentation/title/title_screen.gd` (+30); `presentation/ui/leadlight_passage.gd` (+45); `tests/test_vigil_hold.gd` (+50) |

*As built in PR C* (each commit's code files under 600 lines changed; the Vigil's screen took three steps
to stay under it): C1 the kit (`TitleWorld.pan_px`, `TransitionLayer.lift`, the music's resume,
`HearthFigure.breathe`, `LeadlightCame`, `LeadlightRose.vigil`, the room's opening cue); C2 the hall
(`VigilHall`); C3a the deeds and the epitaphs as their own parts (`VigilDeeds`, `VigilEpitaphs`, the old
screen using them for one commit); C4 the Rose look (`RoseWindowView` rebuilt); C5 the Vigil as the
hearth hall with the title held under it, the lift, the warm loads and the warm's re-queue
(`test_vigil_hall`, `test_vigil_screen`, `test_vigil_hold`); C6 the turn west and east and the looks
(the lanes); C7 the capture and bench tools; then three found in the stills and the spec's rows: C8 the
hall's zh-Hant counts in figures where the faces lack the numerals, C9 the phone's header and Replay clear
of each other, C10 the Replay's sound (V6). The spec's C6, the rose flight, was cut.

### 10.3 Gates and review

- Each commit passes the narrow test that answers it; each PR's final candidate passes the core gate once
  before its first push: `godot --version`, `tools/check_imports.sh`, `tools/check_scripts.sh` (new `.gd`
  files staged first), `godot --headless -s res://tests/run_all.gd`, plus `tools/check_anchors.py` for
  the docs.
- Visual and temporal claims are proven by stills and sequences (§11.3–§11.5), inspected by eye at every
  affected shape; audio routing by playback on the Mac (the six cues are already auditioned and shipped).
- Each PR is a non-mechanical multi-file change with interacting risks, so each gets exactly one
  final-candidate review by `.claude/agents/ai-sdlc-reviewer.md` (task contract, base, exact head,
  constraints and the deterministic evidence; not this transcript), recorded in the PR.

---

## 11. Tests and evidence

### 11.1 Deterministic (headless)

- **`test_focus_modality.gd`** (§6.3).
- **`test_transition_rm.gd`:** `screen_in` under Reduce Motion starts below alpha 1 and is at 1 within
  0.16 s, with no scale; without Reduce Motion it is unchanged.
- **`test_leadlight_seat.gd`:** for every shape and the five flex stages, the seat's lantern, word and
  hit lie inside the stage; the hit is at least 60×60 at pad and desktop, 44×44 at phone; the word never
  overlaps the lantern's glass.
- **`test_leadlight_sheet_reach.gd`:** `reach` 0 draws no glazing and 1 draws all of it; `trace` 0 and
  1 draw none and the whole loop; both are pure functions of their value (stepped twice, same result).
- **`test_room_passage.gd`:** for Settings, How to Play and Credits through `_on_title_pick`:
  - `_modal` is set on the tap frame, the room's first control accepts a press on frame 1, the lantern is
    at the seat and the room settled after 0.52 s (Credits 0.6 s), stepped with `Tween.custom_step`;
  - a veil press during the arrival lands it and does not emit `closed`; after it, a veil release without
    drag emits `closed`, and a wheel tick or a drag start never does;
  - **double tap:** a second press at the opening point at +120 ms and at +280 ms acts on nothing and
    lands the arrival; at +320 ms it acts;
  - on close, `_modal == null` on the same frame, the title's word takes a press on frame 1, and the
    leaving node is freed by 0.45 s; `_clear_route` mid-exit frees it; a room word tapped mid-exit frees it
    and opens the new room;
  - under Reduce Motion, frame 1's room alpha is strictly between 0 and 1 and all is done by 0.16 s;
    `instant` and headless land whole with no tween;
  - an `SfxBus` spy hears exactly one `roomOpen` and one `roomClose` per round trip and no `click`;
  - language toggle: `_modal is SettingsPanel` at once, no second `roomOpen`, the old panel freed by
    0.16 s; Erase → Cancel lands on the title; Erase → Erase Everything rebuilds a fresh title under the
    flood.
- **`test_help_room.gd`:** opens on the first page at scroll 0 with focus on its pane; each pane shows its
  page; every pad page fits without scrolling in both locales; the Coda rules; phone numerals show the
  active name.
- **`test_credits_roll.gd`:** the drift advances at rest and not under Reduce Motion; a touch holds it
  and it resumes after 3 s; `walk` never exceeds 2.0; the licence glass builds `_font_licence_wrap`; no
  Label holds a pack id; held Act IV rows read "· · ·" before the unsealing and their titles after; the
  now-playing row follows `MusicBus.current_cue`.
- **`test_title_world.gd`:** at `walk` 0 and `pan_px` 0 the projection of the door, road and lamp points
  equals the shipped one exactly; `inherit` reproduces the source world's projected points and mote
  fields.
- **`test_vigil_hold.gd`:** title → Vigil → back keeps the same title instance and resumes its world's
  `_time` from where it stopped; music order `vigil` then `title`, the title resumed at its position; each
  of the five Vigil entries lands on `VigilScreen` (held for the title, route form otherwise); every other
  route frees `_held_title`; `_reshape` reaches it; the held title takes no input; V2′ never runs without
  the unsealing.
- **`test_vigil_hall.gd`:** for every shape, flex stage and look, the plate covers the stage at t = 0,
  0.25, 0.5, 0.75 and 1 of V1, V3 and V4; the Keeper's sprite never intersects the column; on the Rose
  look the painted window lies inside the Emberglass rose.
- **`test_vigil_screen.gd`:** for every shape, flex stage, both locales and the states fresh, mid, full
  and the longest memory selected with 30 whispers, the seat lies inside the stage and every content rect
  is clear of it and inside the stage; progress prints as integers; zh-Hant joins rewards with "、" and
  carves Chinese numerals; the first music cue is `roseWindow` when opened on the Rose look; `Replay`
  exists, is visible and has a size only when all six are complete.
- **`test_rooms_rubric.gd`:** in the four rooms and the licence glass, every `BaseButton` hit is at least
  60×60 at pad and desktop and 44×44 at phone; every `Label` and `RichTextLabel` is at least 18 px at pad;
  no `RunStyle.panel` or `GlassStyle.pane` style box remains in a room; the project's clear colour equals
  `LeadlightTokens.VOID`.
- **`test_departure.gd`** (§8) additions.

### 11.2 Shipped pins

Kept unchanged: `test_class_scope` (Vigil labels), `test_line_table` and `test_story_acceptance`
(epitaphs), `test_batch4_landing` (`_detail_copy`), `test_scene_wiring` (Replay → the unsealing → back to
`VigilScreen`), `test_bespoke_staging` (`RoseWindowView.IDS`), `test_dev_tools` (scenario `vigil`),
`test_edge_way` (`DEED_IDS`), `test_confirm_sheets`, `test_live_locale_switch`, `test_first_launch_flow`,
`test_title_reach`, `test_title_screen`.

Updated deliberately, each in the commit that needs it with the reason in its message: `test_stagecraft`
(the Coda's preceding sibling is read inside the Lantern page; the assertion is unchanged), `test_locale`
(its seam map of which function carries which key, for the restructured Help, Credits, Vigil and rose
files), `test_presentation` (Credits: no pack ids is now asserted, the folds are licence glass).

### 11.3 Stills

`tools/capture_rooms.gd` drives the real Main (headed, `--position 40,40`, never `--headless`; the lane's
isolated user dir), with `--room`, `--look`, `--section`, `--shape`, `--locale`, `--state=fresh|mid|full`,
`--memory`, `--at=<ms>` (holds a passage at that time), `--rm`, `--burst` and `--seq`. Every room at rest
at 844×390, 1180×820 and 1458×820, in en and zh-Hant:

- Settings (AUDIO and PRIVACY); How to Play (pages I and IV); Credits (head, music, end, both licence
  glasses); the Vigil (Deeds, Rose, Epitaphs; fresh, mid and full; a memory selected);
- the Vigil and Settings also at 845×390 and 1180×885 (the soft-lock and the iPad 8);
- the oval set (§6.3); the title at rest, pressed and keyboard-focused.

### 11.4 Idle bursts

Three frames 1 s apart per room at rest (pad en and phone zh-Hant): at least 0.5% of the room's own
pixels change between consecutive frames (the glass for glass rooms; the column and the hall for the
Vigil; the roll band for Credits). Under Reduce Motion the bursts are recorded and inspected, not gated.

### 11.5 Transition sequences

Every row of §5.1 at pad en with `--fixed-fps 60`, frames 0 to settled + 4, as contact sheets; G1, G2,
V1, V3 and C1 also at phone zh-Hant and under Reduce Motion. **Grey gate:** no frame of any sequence has
more than 0.5% of its pixels within ±4 of RGB (77, 77, 77). **Cut gate:** under Reduce Motion no frame differs from
the one before it by more than an eighth of the whole change plus idle noise (a 150 ms fade moves about a
ninth per frame at 60 fps; today's hard cut moves all of it in one). The idle noise is the larger of the source's (two frames before the tap) and
the settled destination's (its last two frames), since a flame flickers under Reduce Motion too.

### 11.6 Frame times

- **Mac** (M1 Max, `GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 --rendering-driver metal`):
  `tools/bench_rooms.gd` opens and closes each room 20 times at pad and phone, en and zh-Hant, and holds
  5 s at rest in each; it reports tap → first moved frame, P50, P95 and max CPU and GPU per phase, against
  the title at rest. The Mac's wall interval is display-bound (opening §16.3), so CPU render time is the
  comparable number.
- **iPad 8** (A12, the owner's device): the existing devicectl QA-probe recipe on the Development
  profile, never committed; each room toured 10 times (open, 3 s, close) plus 30 s at rest; rows in
  `evidence/ipad8-rooms-frame-times.txt`. The first-ever open of each room after a cold install is
  reported apart (pipeline compiles).

**Pass on the iPad 8:**

| Measure | Pass |
|---|---|
| Tap → first moved frame | ≤ 50 ms for every room, the Vigil included |
| The tap frame (the room's build) | ≤ 33 ms Settings, How to Play, Credits; ≤ 50 ms the Vigil |
| Every other frame of a passage | P95 ≤ 16.7 ms; none over 33 ms |
| At rest in a room | P95 ≤ the title's at-rest P95 + 0.5 ms |

*As built in PR B* (evidence in `stills/pr-b/`, taken with `tools/capture_rooms.gd` and
`tools/bench_rooms.gd`; after the PR B review every still, burst and sequence was retaken on the code
that shows it, each file's header naming the commit):

- **Stills** (§11.3): Settings (AUDIO, PRIVACY), How to Play (I, IV) and Credits (its head, the music,
  the end of the roll, both licence glasses) at rest at 844×390, 1180×820 and 1458×820 in en and zh-Hant,
  and Settings at the flex stages 845×390 and 1180×885 (the iPad 8's), as `<room>-<part>-<shape>-<locale>.jpg`.
- **Idle bursts** (§11.4, `idle-gates.txt`): at full motion every room passes, the least change between
  frames 1 s apart being 15.2% to 35.0% of the room's own pixels; under Reduce Motion the rooms rest still
  (0.00%), recorded as §2.7 asks.
- **Sequences** (§11.5, `sequence-gates.txt`, contact sheets `seq-*.jpg`): G1, G2 and G3 (Settings and How
  to Play), C1, C2 and C3 (Credits and its font glass) and X1 (How to Play from the run menu) at pad en;
  G1, G2 and C1 at phone zh-Hant; G1, G2 and C1 under Reduce Motion. Every frame of every sequence passes
  the grey gate (worst 0.13%); the three Reduce Motion sequences pass the cut gate (largest step 0.0092 to
  0.0108 of a 0.081 to 0.092 whole, as a 150 ms fade moves). Under full motion no room's passage puts more
  than 29% of its change on one frame (PR A's Settings opened in one: 100%), and every departure now moves
  from its first frame (G2's first eight frames carried 7% of its change before the review); a section
  change (G3), a small change overall, puts 67% on its first frame in Settings and 76% in How to Play, the
  pane lighting under the finger as the old page goes. Before the review the rooms' staged builds (§14)
  were retaken against the stills of the time (`retake-staged-builds.txt`, on `11aa2233`): every How to
  Play and Credits still within 0.24% of its twin, every gate line equal to the fourth decimal.
- **Frame times, iPad 8** (§11.6, `evidence/ipad8-rooms-frame-times.txt`, the QA app, 10 laps a room,
  each room's first opening in the launch apart). "First moved" is the tap frame itself: the passage takes
  its first step in that frame's process step, after the input that opened the room. The bench's release
  is parsed in a frame's process step and waits out the rest of that frame, about 16 ms here: the worst
  case for a finger, which lifts at any moment. A passage's frames are those inside its own span (before
  the review the bench padded each with 0.2 s of the room at rest, which drew its P95 towards the title's;
  those rows are re-read inside the span in the evidence). en on the review's code (`c041b68e`, the first
  launch after its install); zh-Hant on `03cf374a` (the same passages, before Settings was fitted ahead:
  the `c041b68e` zh-Hant launch ran, but every file copy from the QA container hung from then on, so its
  rows could not be fetched). Laps 2 to 10, median (max), en and zh-Hant:

  | Measure | Pass | Settings | How to Play | Credits |
  |---|---|---|---|---|
  | Tap → first moved frame | ≤ 50 ms | 38.3 (41.1), 43.0 (44.0) | 37.7 (42.0), 41.0 (42.2) | 36.4 (38.2), 39.7 (40.0) |
  | The tap frame | ≤ 33 ms | 22.6 (24.4), 27.1 (29.3) | 21.9 (24.5), 25.4 (26.5) | 20.1 (20.5), 23.3 (23.9) |
  | Other passage frames, P95 (max) | ≤ 16.7 ms (none over 33) | 17.4 (22.9), 18.2 (23.3) | 17.6 (23.1), 18.4 (23.1) | 17.4 (22.5), 17.5 (22.2) |
  | At rest, P95, against the title's 18.0 and 18.0 | ≤ the title's + 0.5 ms | 17.3, 17.4 | 17.5, 17.8 | 17.7, 17.8 |

  Every tap to first moved frame is under 50 ms and every later tap frame under 33 (Settings' zh-Hant
  worst is now 29.3; it was 37.5). **Shortfall:** no passage meets §11.6's 16.7 ms P95 as written (17.4 to
  18.4 ms): on iOS a frame's present wait is inside its draw, so the title at rest is itself 18.0 ms at P95
  (vsync jitter), and the passages stand within 0.4 ms of it. Reading the bar against the title's own P95
  is a reinterpretation the owner has not made (§14, open). No passage frame passes 33 ms but one, 58 ms
  on `03cf374a` (Settings' tenth lap, en, with 10.5 ms of its own work: the display held the frame).
  **The first opening in a launch** was labelled "the first opening after install" before the review; it
  is paid by every launch, since each is a new process. RoomWarm (§14) now pays its work while the title
  rests. On a second launch on its install (`03cf374a`, zh-Hant), the first opening's tap frame is 28.6 ms
  for How to Play and 28.0 for Credits (54.7 and 48.6 before the review) and its tap to first moved 44.5
  and 44.3 (70.9 and 64.7); Settings' is 33.5 ms, 0.5 over, and tap to first moved 49.3. That last cost is
  Settings fitting itself to its tallest section, which `c041b68e` now does ahead in the warm; its effect
  on a second launch is not yet measured on the device. The first launch after an install also compiles
  pipelines for the first time (§11.6 reports it apart): on `c041b68e` en its tap frames are 38.4, 29.7
  and 28.2 ms and its taps to first moved 53.0, 45.8 and 44.5.
- **Frame times, Mac** (§11.6, `mac-frame-times.txt`, M1 Max on the A12's Metal path, 20 laps a room at
  pad and phone in both languages, on `c041b68e`): the shared Mac paced every frame of all four runs at
  about 9.4 ms, so only the tap frames compare: 8.1 to 11.5 ms (median, laps 2 to 20), and 9.2 to 12.5 on
  each room's first opening in the launch (12.2 to 22.1 on `11aa2233`, before the warm). Rare 27 to 242 ms
  frames fall in later laps while other lanes' suites ran.
- **Mutation proof** (`evidence/pr-b-mutations.txt`): fifteen rules broken one at a time in the shipped
  code, each caught by the suite that guards it; and after the review, the 23 rules it asked for, each
  caught (three were not, at first: their tests were tightened).

*As built in PR C* (evidence in `stills/pr-c/`, taken with `tools/capture_rooms.gd` and
`tools/bench_rooms.gd` on `1e1395f2`, the hall's code; the zh-Hant fresh stills retaken on C8, whose only
change on screen is a zero count, and every phone still on C9, which moved the phone's header, rose and
Replay; the gate files' headers name their commit):

- **Stills** (§11.3): the hall at rest at 844×390, 1180×820 and 1458×820 in en and zh-Hant, as
  `vigil-<look>-<state>-<shape>-<locale>.jpg`: Deeds mid-way and fresh, the Rose Window mid-way (the pane
  holding the longest memory selected) and full (all six whole, the Replay pane, thirty whispers), and the
  Epitaphs; Deeds and the Rose Window also at 1180×885 (the iPad 8) and 845×390.
- **Idle bursts** (§11.4, `idle-gates.txt`): the hall's own pixels change by 12.2% (Deeds, pad en), 25.3%
  (the Rose Window) and 5.3% (Deeds, phone zh-Hant) between frames 1 s apart; under Reduce Motion only the
  fire's flicker moves, under the gate's step (0.00%, recorded as §2.7 asks).
- **Sequences** (§11.5, `sequence-gates.txt`, contact sheets `seq-*.jpg`): V1, V2, V3, V4 (to the window
  and to the floor), V5, V8 and V9 at pad en; V1 and V3 at phone zh-Hant; V1, V3 and V4 under Reduce
  Motion. Every frame of every sequence passes the grey gate (worst 0.21%); the three Reduce Motion
  sequences pass the cut gate (largest step 0.0112 to 0.0132 of a 0.099 to 0.116 whole). Under full motion
  no V1, V2 or V3 frame carries more than 23% of its change; V4 to the window puts 37% on the frame the
  rose and its glass begin to rise, a large glass on a cubic's ease; V8, the route form's shipped
  `screen_in` from the night, puts 88% on its first frame (the screen it replaces goes at once, as shipped).
- **Mutation proof** (`evidence/pr-c-mutations.txt`): twenty-one rules broken one at a time in the
  shipped code, each caught by the suite that guards it (two were not, at first: their tests were
  tightened and the whole run repeated).
- **Frame times, Mac** (`mac-frame-times.txt`): recorded, noisy (the shared Mac's load average ran 45 to
  120); the iPad 8 rows below are the acceptance.
- **The A12's Metal path** (`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1`, Metal, the mobile renderer, on the
  Mac): the hall and the rose, whose panes are the shipped `rose_pane.gdshader`, draw whole
  (`a12-metal-deeds-1180x885-en.jpg`, `a12-metal-rose-1180x885-en.jpg`). PR C adds no shader and no
  `hint_screen_texture` reader; the fire and the moonlight are `CanvasItemMaterial` additive blends.

### 11.7 What closes each PR

PR A: the core gate, `test_focus_modality` with its mutation proof, the oval stills, the grey and cut
gates on the Vigil and Settings sequences. PR B: the gate, its tests, the stills, bursts and sequences for
Settings, How to Play and Credits, and their iPad 8 rows. PR C: the same for the Vigil.

---

## 12. A12 budget

Estimates from survey A's M1 Max measurements at about 3× for the A12, and from fill counted in
full-screen equivalents at 2160×1620. The device rows (§11.6) replace every number here; no knob is
turned before they exist.

| Moment | Estimate | Why |
|---|---|---|
| Glass room arriving (G1) | about +0.2 screens for 31 frames; under 0.2 ms CPU per frame | adds the veil (1.0) and the sheet (about 0.6); removes most of the lantern pool (about −1.4 at pad); the clip and trace are one polygon intersection and about 120 segment clips |
| Glass room at rest | about the title at rest | the sheet adds about 0.6, the shrunken pool removes about 1.4 |
| Credits at rest | the title at rest plus the band (0.5) and about 40 label modulates | no new fill beyond the band; the walk is a camera offset |
| The Vigil's turn (V1, V3) | about +1.5 screens for at most 25 frames | the plate (1.0, opaque), firelight (0.3), the Keeper's clip pass (0.15) over the fading road |
| The Vigil at rest | **cheaper than the title** | the road's `TitleWorld`, painting and vignette are hidden and paused (about −3), the plate, fire, Keeper and band add about 2 |
| Build on the tap frame | Settings about 25 ms; How to Play about 40 ms (seven pages up front); Credits about 20 ms (the licence text stays lazy); **the Vigil about 175 ms today** | the Vigil's build drops its private `TitleWorld` (route form included), reads warmed textures and builds only the Deeds look in its first frame (the Rose and Epitaphs looks build on their first frame of V4 or on the next idle frame); target ≤ 15 ms M1, ≤ 50 ms A12 |
| Contingency if a build fails its row | — | build the room off-tree once during the title's idle, after 2 s without input, keep it until the Vigil state or Preferences change, and `add_child` it on the tap |
| Title rebuilds | none for the title Vigil (61–74 ms M1 each way today); S8 still rebuilds under the room | the held title |
| Shaders and passes | no new shader; grain stays the one `hint_screen_texture` reader; no 3D | `reach` and `trace` are `_draw`; the firelight is `SkyField.disc`; the rose is the shipped `rose_pane.gdshader` (a canvas shader) |
| Memory | +9.1 MB VRAM while the Vigil's art is warm (plate 6.3 MB, Keeper 2.8 MB, both already shipped and used by the opening) | released when a run starts |
| Plate scaling | phone looks stay at or above 0.55 stage px per plate px | the plates have no mipmaps; below about 0.5 they shimmer |

---

## 13. Risks, and what to cut first

**Risks**

1. **The Vigil's tap frame on the A12** reads as a dead tap if its build stays near 175 ms. Mitigated in
   order: no private `TitleWorld`, warmed textures, the Deeds look first, then the idle prebuild. The
   device row is the acceptance.
2. **The held title** is new Main state (input, focus, reshape, music, the language path). `_clear_route`
   owns freeing it and `test_vigil_hold` covers every entry and exit.
3. **Detached leaving rooms against the synchronous contracts.** Covered by `test_room_passage` and the
   unchanged `test_confirm_sheets` and `test_live_locale_switch`.
4. **Plate coverage and the painted window's measurement.** The framing is a pure function and the
   coverage test fails on any exposed pixel.
5. **Legibility in the hall at phone, zh-Hant.** The band and the column are checked in the zh phone
   stills before PR C is reviewed.
6. **The lantern means "go" at the title and "back" in a room.** It always means "to the road", and the
   word beside it says which. Watch for it in the owner's play round.
7. **The Reduce Motion `screen_in` fade touches every route** and changes every Reduce Motion capture.
   Run the full suite and the Reduce Motion stills once.
8. **Story canon.** The Emberglass rose in the hall's window, the held Act IV credits and V2′ go past the
   story skill (`.claude/skills/glassvow-story/SKILL.md`, foreshadow-ledger rule 2) in their commits.

*As built:* V2′ was cut in PR C: the hall, the held title and every V* passage were the work, and the
flight is a payoff for a handful of players that would want its own story check (rule 2) and device
rows. The door's rose never travels into the Vigil.

**Cut order** (first cut first): V2′, the rose flight; Help's living diagrams; the Credits walk (keep
the roll and the lamp line); the ghost word (keep the crown fading in); the lantern's swing; the
Epitaphs look's tilt (epitaphs on the Deeds framing); the moonlight shaft and dust; the Keeper's breath.

**Never cut:** PR A whole; a felt passage for all four rooms with input live from frame 1; the held
title; the hall with the Keeper; the phone soft-lock fix and the bounded reading glass; the Reduce Motion
cross-fades; one cue per tap.

**Copy debts for a story batch** (not this lane): plural forms for `ui.vigil.stats` and `ui.brand.stats`
("I pilgrimages"); Help's touch-first wording ("clicking", "press A"); "above their heads" and
「難度之梯」 near the banned vertical vocabulary; "Return to the Vigil" at run end, which lands on the road.

---

## 14. Open decisions for the orchestrator

1. **The 18 px rubric floor outside the rebuilt rooms.** The title's quiet words and panes (15 px),
   carved slabs (14 px), captions (12 px), the version label (9 px) and Settings' row text and notes
   (10–15 px) are below `docs/commercial-rubric.md`'s floor; the owner signed the title at those sizes in
   #650. **Default in this spec:** the rebuilt rooms and every new part comply now; the rest stays as
   shipped. The choice is to raise `SIZE_WORD`, `SIZE_PANE`, `SIZE_CARVED` and Settings' rows to 18 at pad
   in a follow-up (after a still review of the title), or to record a waiver for them.

   **Decided by the orchestrator, built in PR A:** every functional text on the title is raised to the
   floor at 1180×820 and on desktop now. `SIZE_WORD`, `SIZE_PANE`, `SIZE_CARVED` and `SIZE_CAPTION` go to
   18 at pad and 14 at phone (the plaque stays 24 / 17): the quiet words, the Rekindle pane, the carved
   deeds, the plaque's act and waystone line and the first launch's consent line, note and Privacy Policy
   word. The composition is kept by layout, not by smaller type: the plaque stands on the lantern's ring
   with its sub-line tucked into Cinzel's spare line height, a long Roman count is set with its tracking
   closed up rather than cut (never smaller), and the consent sentence reads across its row in balanced
   lines with the switch and the link under it, the left words standing from the top of their arc while
   it shows so the row clears them at the 44 px touch floor. Settings' rows are rebuilt in PR B and are
   not part of this. Pinned by `tests/test_title_rubric.gd`, at every shape, in both languages and in every
   state the title shows (the consent line owed with a saved run and deeds included), with nothing on the
   title standing on anything else.

   **Waiver, recorded.** The build number (`TitleScreen._version`, 11 px, dim, bottom right) is not
   functional text: it is a build identifier for reports, read by no player decision; it stays below the
   floor, and the test fails if it ever grows past it unnoticed. It is the only waiver. The carved deeds
   meet the floor as they are drawn: lying on the road foreshortens them, so they are set larger
   (`LeadlightInscription`: the set size is the role's size over the lie's squash, 20 px for 18 at pad and
   desktop, 16 for 14 on a phone, with the lie eased to 0.14), and the test reads the drawn size.

   *As built after the PR A review:* the deeds stand in the road's two corners, each from its own edge of
   the stage (clear of the build number), two close lines with their foot near the stage's foot, lower and
   further out than the words, so they no longer read as a fourth row of the menu. The consent line takes
   the foot of the left side only when it is free (a fresh install's two left words); with a saved run's
   three left words it stands in the open sky top right instead, clear of the wordmark, so it never lies
   over How to Play or the deeds (a player from before the consent line existed). Its zh-Hant sentence
   breaks at the "，" that best balances it, never inside a word such as 資料, and the switch's ON / OFF
   (開 / 關) is set at the caption's size like the sentence. Settings' row panes (Erase All Progress, Close,
   Privacy Policy) keep their shipped 15 px: they are rebuilt with the room in PR B. The departure's and the
   confirm sheets' words and panes do rise with the kit's tokens (18 at pad and desktop, 14 on a phone):
   the Begin Anew, Abandon Run, Leave the Road and Erase Everything sheets and the departure are in
   `stills/pr-a/` at the three shapes in both languages.

   **Found while raising it:** the lantern's button took a tap anywhere in its 420 px square, so in
   zh-Hant on pad the middle of 設定 (and, at 18 px, of 續火) fell on the lantern and took the road. The
   lantern's hit is now its own body (`LeadlightLantern.HIT_UV`, the art's opaque bounds); every word's
   and pane's rect is held clear of it at every shape, in both languages.

   **Evidence:** `stills/pr-a/` (the title in five states, fresh, saved, the Vigil's deeds, the consent
   line and the deeds with the consent line still owed, at three shapes in both languages; the returns
   a, c, e, g, h, i and the keyboard rim j at pad and phone with `focus-paths.txt`; the oval, rim,
   plaque and type before-and-after sheets; the Reduce Motion and grey-frame sequences with
   `sequence-gates.txt`; the kit surfaces, `kit-surfaces-at-18px-*`), taken with `tools/capture_rooms.gd`.

Everything else is decided here: Erase → Cancel lands on the title (behaviour unchanged); the Sentry
notice ships when the addon is in the export; the Act IV track titles are held until the unsealing; the
title music resumes after the Vigil; no art is commissioned.

**Decided while building PR B** (the passage, Settings, How to Play, Credits). Each is recorded where it
applies, as built; together:

- **The waiver** of the build identifier covers Settings' footer line too (`BrandLine`, 10 px): it is the
  same build string as the title's corner, read by no choice. `tests/test_rooms_rubric.gd` exempts it by
  name and nothing else.
- **Reduce Motion** for a room is PR A's snapshot cross-fade of the frame before (§2.7, as built), the
  lantern landing at the seat or home beneath it; with nothing copied the room fades over 150 ms.
- **The seat's two hits** are disjoint: the lantern's stops where the word's begins (§3.1, as built).
- **How to Play's panes** are in small capitals at 264 wide, its headings split at the dash, its `[b]`
  in the body's colour (§4.2, as built); it fades the wordmark with the furniture.
- **Credits** keeps the wordmark the title's, drawn over the room; reads 28 tracks; holds Act IV's six
  stems; has no veil to tap; sets its licence texts at 18 px in their own glasses (§4.3, as built).
- **`TitleWorld.pan_px`, `TransitionLayer.lift`, the held title, the music resume and the Vigil's warm
  loads** are PR C's and are not in PR B: nothing PR B builds needs them (YAGNI).
- **The run's HUD** carries no lantern, so a room in a run is lit from the bottom-left (§4.5, as built).
- **The licence texts ship in every export.** On the iPad 8 the QA build's Fonts glass read "licence file
  not found" for all four families and the engine glass had no Sentry notice: an OFL `.txt` or
  `LICENSE.md` is not an imported resource, so it reaches a pack only through its preset's include
  filter, and every preset's was empty. The decision above (the Sentry notice ships when the addon is in
  the export) and the OFL's own condition (each copy of the fonts carries the licence) settle it: every
  preset in `export_presets.cfg` includes `assets/fonts/OFL*.txt` and `addons/sentry/LICENSE.md`, and
  `tests/test_credits_roll.gd` fails if any preset's filter leaves out a text `CreditsLicences` reads. The
  device's own file probe, before and after, is in `evidence/ipad8-rooms-frame-times.txt`.
- **A room builds what is on view in its tap frame.** Text is shaped as it enters the tree, and the first
  iPad 8 rows (the QA build of `c04a168d`) put How to Play's tap frame and Credits' over §11.6's 33 ms
  (render CPU 0.2 ms: none of it drawing). How to Play builds its lit page with the room and each other page on its first showing;
  Credits builds its roll's head and the first nine rows of each column, and the rest a part a frame
  after (§4.3); the band's light and the parsed manifests are made once a session. No pixel at rest and
  no frame of a passage changes (`stills/pr-b/retake-staged-builds.txt`).

**Decided after the PR B review** (each recorded where it applies):

- **The word in flight never crosses lit text**, either way (§2.3, as built), and **every departure moves
  from the frame Return is tapped** (§5.2, as built): EXIT's slow start no longer opens any leaving lane.
- **The first opening in a launch is paid while the title rests.** `RoomWarm`
  (`presentation/ui/room_warm.gd`): once the title has rested 0.8 s with nothing over it or moving, it
  builds each room once off the tree (a frame each), fits Settings to its tallest section, shapes the
  rooms' text at their sizes within 1.5 ms a frame, draws their glyphs under the road at 0.004 within the
  same budget a frame, and frees itself; one a launch for each language and shape, never in the headless
  suite. *As fixed before build 20:* it first drew every glyph in one frame, and since every new glyph
  re-sends its whole font page to the GPU, that frame cost the iPad 8 30 to 270 ms (en to zh-Hant), the
  next 66 to 83 ms, and 53 to 92 MiB of upload staging the engine never gives back
  (`evidence/roomwarm-pacing/`). The warm was chosen over building the rooms in the tree ahead (§12's
  contingency), which would have put a 20 to 25 ms frame at rest into the title three times. Settings
  keeps its fitted height for the launch.
- **Credits' roll fades at its edges and warms from its arrival; a licence glass reads as a glass**
  (focus, keys, its text under its crown, fades where it runs on, its texts set to its column, the roll
  behind at 0.1) (§4.3, as built).
- **The run menu folds away** under a room it opens (§4.5, as built).
- **The title's taps are 44 px on a phone** too (§7 item 8, as built).
- **Reduce Motion's lantern** comes in from the cross-fade's middle (§2.7, as built).

**Decided while building PR C** (the Vigil as the hearth hall; each recorded where it applies):

- **Only the title's own pick holds the title** under the Vigil (§9, as built); every other entry is the
  route alone with the seat's word and no lantern, and leaves by the lift (V9).
- **The road's and the hall's music resumes**; a fight's and a stinger's never do (§7, as built).
- **The Vigil's warm loads include its two tracks and the title's** (§7, as built).
- **The window, the dim and the moonlight** as measured and as seen (§4.1, as built).
- **The rise and the look change's curves** (§5.2, as built).
- **V2′ is cut** (§13, as built).
- **A count the zh-Hant faces cannot carve is written in figures** in the hall (§4.1, as built); the
  subset's corpus is left to its own fix (open item 3 below).
- **The passage bar on the iPad 8 (open item 2 below), ruled by the orchestrator on 4 Oct 2026:** on
  iOS a frame's present wait sits inside its draw, so vsync jitter lifts every P95 over 16.7 ms, the title
  at rest included (18.0 ms). The bar is read against the title's own at-rest P95 in the same launch: a
  passage's P95 is at most the title's at-rest P95 + 0.5 ms, and no passage frame passes 33 ms but a single
  display stall. It applies to the V* passages (§11.6, as built in PR C) and closes item 2.
- **#670 review, follow-up 1:** a language or shape changed while the rooms' warm runs was dropped for
  the launch (`_warm_rooms` returned while a warm was alive). It is now warmed when that warm ends
  (`Main._on_room_warm_done`), pinned in `tests/test_vigil_hold.gd`. Follow-ups 2 and 3 are measured in
  §11.6 (as built in PR C).

**Open, for the owner** (PR B builds around it; it does not block it; item 3 from PR C):

1. **Copy** (§13's debts stand; PR B wrote none): no new locale key was needed. `ui.credits.headingBrand`,
   `ui.credits.close`, `ui.credits.themeLine` and `ui.menu.fightOn` are no longer read; they stay in both
   bundles for a separate clean-up, as §2.13 says.
2. *Closed by the orchestrator's ruling in PR C (above).* **§11.6's 16.7 ms passage P95 on the iPad 8.** No passage meets it as written (17.4 to 18.4 ms inside
   their own spans), and neither does the title at rest (18.0 ms): on iOS a frame's present wait is inside
   its draw, so vsync jitter lifts every P95 over 16.7. The passages stand within 0.4 ms of the title's own
   P95 and no frame of one passes 33 ms but a single display stall. The choice: read the bar against the
   title at rest (the passages pass), or measure the passages another way (the frame's own work, which
   the device cannot separate from its present wait). PR B does not decide it.
3. **The zh-Hant subset's corpus** (found in PR C). `tools/subset_noto_serif_tc.py` subsets the three
   Noto Serif TC faces to the characters `locale/*.json` and the line table write, and
   `LeadlightNumerals.hanzi` writes three the locale never does: 零 (zero, and the zero inside 一百零五),
   千 and 萬. The Vigil writes such counts in figures (§4.1, as built); the title's carved deeds still
   carve them, so a zh-Hant player whose deeds reach 105 or 1,000 sees a missing glyph there. The fix is to
   add the numerals' characters to the corpus and rebuild the faces (pinned sources, deterministic output),
   which needs the font sources this lane does not hold; a font change for its own PR.

---

## 15. Mocks and before-stills

HTML mocks from the three concept lanes (headless Chrome, shipped fonts and art); they show intent, not
pixels. None of them is the build. Where they differ from this spec, this spec wins.

| File | Shows | The build differs |
|---|---|---|
| `mocks/road-vigil-deeds-1180x820.jpg` | the hall, the Keeper, carved deed rows | the column starts at x 260 and stops above the seat; the look panes are glass lozenges; no CSS blur (depth is dimming only); the seat lantern is 220 px |
| `mocks/road-vigil-rose-1180x820.jpg` | the Rose look and the reading glass | the rose sits over the plate's painted window (§4.1), with the lozenges or Replay under it |
| `mocks/road-vigil-deeds-844x390.jpg` | the phone hall | no content under the seat; rewards inline in the rows |
| `mocks/road-credits-1180x820.jpg` | the start of the roll | a "CREDITS" heading under the wordmark; no pack ids; two columns of titles |
| `mocks/lantern-rooms-family-1180x820.jpg` | glass rooms at the seat | the seat is 220 px with Return beside it, no plaque; no CLOSE pane; How to Play's panes at 18 px |
| `mocks/lantern-storyboard-reach-and-fold.jpg` | the light front, the trace and the fold with its flare | applies to the glass rooms; the Vigil is a place (§4.1) |
| `mocks/lantern-rose-states-1180x820.jpg` | rose pane states, the came arc, the shard lozenges | state looks only; the Vigil around it is the hall |
| `mocks/free-storyboard-title-settings.jpg` | the passage's lanes and the ghost word | times are §5's (520 / 400), not 300 / 220 |
| `mocks/free-storyboard-title-vigil.jpg` | the turn west | 600 ms; the Keeper is in the hall; the title is held under the Vigil route |

Before-stills (survey E's harness at `124c528d`, which copies Main's mechanics; `before/00-overview.jpg`
is the contact sheet of all of them):

| File | Shows |
|---|---|
| `before/01-title-saved-pad.jpg` | the title at rest, saved run |
| `before/03-title-focused-pad.jpg` | the keyboard ring (the oval's shape) |
| `before/22-oval-after-vigil-return-pad.jpg` | the oval for a touch player after the Vigil's RETURN (the proving still) |
| `before/23-oval-after-settings-close-pad.jpg` | the SETTINGS underline after a tapped close |
| `before/seq-settings-open-sheet.jpg` | Settings in one frame (the 0 s cut) |
| `before/seq-vigil-open-sheet.jpg` | the Vigil: one grey frame, then a fade from grey |
| `before/05-settings-pad.jpg` | Settings' empty lower 60%, the finial under the room, the blue ring on CLOSE |
| `before/08-vigil-deeds-phone.png` | the phone soft-lock: RETURN off the stage |
| `before/09-vigil-rose-pad.jpg` | captions over the mural, "1/3.0", Return clipped at pad |
| `before/11-help-pad.jpg` | How to Play opened past its own title |
| `before/13-credits-pad.jpg` | the blue placard, pack ids on show |
| `before/idle-help-diff.png` | How to Play at rest: no pixel changes |

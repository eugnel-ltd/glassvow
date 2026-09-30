# Event screen at the phone shape (#595): evidence

Two older layout defects, seen in every phone capture taken for #594 and not caused by it: the HUD's location line and the event title overprinted each other, and the HUD's relic icon stood over the choices' window. Both are fixed at the phone reference shape (844 x 390); the pad (1180 x 820) and desktop are untouched.

## The change

- `RunHud` names the two edges the event screen needs: `bar_bottom()` (62 px on the phone) and `relic_row_bottom()` (the collection's first row, 100 px on the phone), plus the `COLLECTION_GAP` and `relic_side()` the HUD already used inline.
- `EventScreen._layout()`, phone only: the title takes a band under the top bar (y 66, was 13.65), centred in the right half of the stage (x 422 to 830), which the relic row, growing from the left edge, does not reach until it holds about fourteen seats; and the choices' window starts under the relic row (y 104, was 51.65 to 88.5). The pad and desktop arms are the code they were.
- `RunHud._add_fallback()` holds a missing-art glyph in a bare `Control`, so its line height cannot grow a phone relic seat to 37 px (the row then ended at y 103, not the 100 `relic_row_bottom()` names). Seats with art, and every pad and desktop seat, are unchanged.

## Captures (`--shape=... --vp=...` through `tools/shot.sh`, the Forgotten Shrine on the Kindling scenario of `docs/design/2026-09-29-dusk-flame/event/README.md`, shrunk to 1024 px)

| | Before | After |
|---|---|---|
| Phone | [`before-handset.png`](before-handset.png) | [`after-handset.png`](after-handset.png) |
| Pad | [`before-pad.png`](before-pad.png) | [`after-pad.png`](after-pad.png) |

Phone, before: the title wraps under the location line and the relic icon sits on the window's left edge. Phone, after: the location line has the bar to itself, the title has its own band under it at the right, and the window starts under the relic. Pad: the same picture (the ambient particles differ frame to frame, so the captures are not pixel-equal; the geometry below is the proof).

## Deterministic proof

- `tests/event_phone_containment.gd` (new, wired into CI as `run_event_containment`): all 11 events, both locales, both the choice screen and the result beat, on the phone, pad and desktop shapes, under a live HUD dressed with a phial rack and an omen, and twelve relics on the phone (thirteen seats, ending near x 476) or five on the pad and desktop. It holds the title clear of every HUD element, the window clear of every HUD element, both inside the stage, the window above the prose pane, the first choice whole in the window and the last brought into view by focus. On origin/main it fails on the phone (title over the location line in every event; window over the relic row in every event; window over the top bar in the events that scroll) and passes on the pad and desktop; with the change it prints `PASS event containment (2024 rects, en + zh-Hant, 11 events, 3 shapes)`.
- Pad and desktop unchanged: the title, window and pane rects of every event, choice screen and beat, on the pad and the desktop, were dumped from origin/main and from this branch (66 rows with the phone's) and the pad and desktop rows are identical.

## Phone geometry, before and after (px)

| | Title top | Window top | Window height | Scroll view |
|---|---|---|---|---|
| Before | 13.65 (x 84 to 759, centred) | 51.65 or 88.5 | 192.85 or 156 | 164.85 or 128 |
| After | 66 (x 422 to 830, centred in the right half) | 104 | 140.5 | 112.5 |

## Trade-off

The relic row and the title take the top 104 px, so on the phone the choices' window is 140.5 px tall on every event: the first choice is whole and the next shows in part, and the rest are reached by scrolling, which the window already does and focus already follows. Before, the two-choice events showed both in full, because the window rose over the HUD to do it.

## Not fixed here

On the pad a title centred on the stage already meets the ninth relic seat (the same at origin/main). It is outside #595's phone scope and the pad is to stay unchanged, so the test holds the pad and desktop to the modest collection; it wants its own issue.

# #657 PR 7, the reward reveal, the Vigil's Backs shelf and the Dawn's earned back: evidence

The suite's proof is `tests/test_vigil_backs.gd`. The stills were taken on the
real Main and route, windowed, on an isolated user directory: the shelf with
`tools/capture_rooms.gd` (`--look=backs --state=mid --nowins --back=rose`), the
reward and the Dawn with the scratch `device/pr7_capture.gd.txt`. The device
probe, its patch and the campaign are text under `device/`; the raw rows stay
out of the repository. §3 and §5 are the dossier's (`../../README.md`).

## The spec as built

| Item | Built | Where it differs, and why |
|---|---|---|
| Reward pick, the reveal (§3) | `RewardEmbers`: the offering is dealt face down out of a small stack at the rack's middle (it rises into the bed, 0.20 s; the cards go to their seats top card first, 0.26 s each, 0.06 s apart), then each turns over left to right, 0.12 s apart and 0.48 s each, pitching toward the eye as the deal does (−14°·sin πt). The turn is the live one (`CardView.turn(…, true)`): the slab turns in its own stage under its own lamp. | **No lamp sweep.** The card's lamp belongs to the pointer at rest (the reward file's own rule); the finish answers the turn because the slab turns under the lamp, which is the flare the eye reads. A face-down card dealt before the table's back is baked (it is baked as this route is built) is dressed again the frame the bake lands. Until the deal each card stands face up at 1% opacity, so what its face draws compiles behind the route's wipe (see iPad 8). |
| Skip | A tap or a click once the deal has begun lands the offering face up at once (`settle`). A tap on a face-down card lands the offering and takes nothing; the next tap takes. | Taps during the husk's break do nothing, as before. |
| Reduce Motion | Each card fades in face up at its seat, 0.16 s, 0.04 s apart; no turn, no stack. | |
| Reward pick, the pick (§3) | The card taken flies into the run HUD's deck over 0.42 s, shrinking to the deck's card, turned face down by 60% of the way, over the HUD; the deck counts it and bumps (`DeckStack.bump`, the piles' `pileBump`) as it lands (`RunHud.owe_card`, `card_home`). The others turn back and slide away into the bed (0.32 s). Leave it sends all three away. Under Reduce Motion every card fades where it stands and the count ticks. | A resumed reward whose card slot was answered shows the offering gone, as a pick leaves it (it used to stand dimmed). |
| The Backs shelf (§5.4) | `VigilBacks`, a fourth look of the hearth hall on the hearth's framing (pane BACKS, after DEEDS): every back in the catalogue as a card in the body column, an earned one as a live card (`CardBacks.build`, released at rest) chosen with a tap, a click or its key; the back in use raised, IN USE under its name; a back not yet earned a silhouette of a card (the dark of a card, its rim in dim gold) with its deed. Built when the pane is first tapped, as the Rose look is, or, in the hall Main builds ahead while the title rests, a frame after the hall, hidden, so its cards have drawn and let their stages go before the tap. | **In the column, not on the plate.** #688 left `VigilHall.shelf()`, a seat on the plate under the column's legibility band: cards there are darkened by the band, scale with every framing, and on the phone the hearth framing puts the mantel at the stage's top edge. The seat had no other user and is removed. |
| Choosing | `Main._choose_back` → `CardTurn.choose`: refused unless earned; stored as `[cosmetics] card_back`; the table wears it at once (`CardTurn.wear`, a bench bake under Main, so it outlives the hall), and every deck stack follows `CardTurn.back()` frame by frame. `Main._bake_table_back` now calls the same `CardTurn.wear`. | The carry-over (#661): a choice no longer leaves the table on a dropped bake until the next route. |
| The Dawn's earned back (§5.3, §5.4) | Derived, no save change: `Main._on_terminal_commit` reads `CardBackCatalogue.unlocked` before and after `commit_run`, and each back newly earned is one Dawn event (`DawnScreen.back_events`, kind `back`) in the feed the run's save already carries (`pendingDawn.events` is free-form and validated only for shape). Its card stands beside its name and line, face down as its beat starts, and turns over from 0.30 s in, 0.48 s long; skipped, resumed or under Reduce Motion it stands face up. A hidden warm card per owed back is drawn in the route's build frame, behind its wipe, so the beat compiles nothing. | A back earned on a run that ends in a fall has no Dawn; it is on the shelf. A card built ahead and moved into the feed came up with its table-shadow panel twice its size, so the shown card is built at its beat and the warm card stays hidden until the screen leaves. |
| Copy | Through the story skill (a fresh-context check against the glossary, the vertical-vocabulary ban and the ladder): BACKS / 牌背, The Lancet / 長窗, Vesper / 晚禱, Eclipse / 日蝕, "Earn an emberglass shard." / 取得一片燼璃。, "See a dawn." / 迎來一次破曉。, IN USE / 現用, NEW CARD BACK / 新牌背, "It waits on the Vigil's shelf." / 它在守夜的架上等着。 | The check rewrote two: "Night Rose" (an echo of the canon Rose Window on the same screen) and "WORN". UI labels; no ledger entry. 背, 晚 and 迎 were outside the shipped Noto Serif TC subsets, which were rebuilt with `tools/subset_noto_serif_tc.py` (pinned sources; +0.7 to +1.7 KB each). |

## Stills

| File | What |
|---|---|
| `01-reward-reveal-en.jpg`, `02-reward-reveal-zh-Hant.jpg` | Rows pad, phone, desktop; columns mid-deal, mid-turn (the middle card edge-on), at rest |
| `03-reward-pick.jpg` | Mid-flight (the others turning back as they slide away), landed, after: pad en, phone zh-Hant, desktop en; the deck reads 10, then 11 as the card lands |
| `04-reward-reduce-motion.jpg` | Reduce Motion, pad: the offering faded in face up; the pick faded, the count ticked |
| `05-vigil-backs-shelf.jpg` | Rows pad, phone, desktop; en and zh-Hant: The Lancet earned, Vesper in use, Eclipse a silhouette with its deed |
| `06-dawn-earned-back.jpg` | Rows pad, phone, desktop; mid-turn and at rest, en and zh-Hant |

## iPad 8

QA builds (`io.fol2.glassvow.qa`, shaders baked as the release bakes them) of
`main` (A, `97890cad`) and the branch (B), installed A, B, A, B; after each
install a first launch of each mode (the "w" rows: straight after the install,
so its shader cache is cold for the new binary) and then one measured reward
launch and one measured shelf launch (`device/campaign7.zsh.txt`). The probe
(`device/card_probe7.gd.txt`) opens a reward with a three-card offering from
the title at rest, takes the middle card, and opens the Vigil as from its word,
then (B) the Backs pane and a change of back. Frame times are wall time from
one frame's start to the next; the step is the frame the probe acted in. All
rows: `device/summary-b1.txt`, `device/summary-b2.txt`.

**Batch 1** (B at `def03786`) read two long frames, both fixed in `8fcc7848`:

- B's first launch after its install: one 466 ms frame mid-reveal. A canvas
  pipeline main compiles as its cards rise in (frame 32 after the build)
  waited, on B, for the first card's face at rest, at the end of its turn
  (frame 99). The offering now stands face up at 1% opacity until the deal,
  so that compile lands in the frames that build the route.
- The Backs pane: one 50 ms frame after the tap (its two live cards' first
  draw, draw 36 ms), in 2 of 2 B shelf launches.

**Batch 2** (B at `8fcc7848`), measured launches (warm cache):

| Phase | A (2 launches) worst / p95 | B (2 launches) worst / p95 | B frames > 33 ms |
|---|---|---|---|
| Reward reveal (from the route's build to 1 s past the entrance; B: the deal and the live turns) | 26.8 / 19.1 ms | 41.3 / 19.2 ms | 1 (one frame at 0.48 s, before the deal, in 1 of 2) |
| Reward pick (B: the flight into the deck) | 17.8 / 17.3 ms | 21.3 / 19.4 ms | 0 |
| Vigil open from the title | 26.8 / 18.9 ms | 25.3 / 19.4 ms | 0 |
| Backs pane (B only) | — | 40.1 / 18.8 ms | 1 (the look change's first frame, in 1 of 2) |
| A change of back (B only; the tap frame bakes the table's back) | — | 17.4 / 16.9 ms after a 48.6 / 52.1 ms tap frame | 0 |

The first launch after each install ("w" rows): A's reveal holds one 413 ms
frame as its cards rise in (frame 33 after the build), B's one 383 ms frame at
frame 7, behind the route's wipe and before anything moves. B's Backs pane in
those launches: one 40 ms frame, the same first frame of the look change. No
pipeline compiles during the Backs pane or the pick on either build.

**Reading.** No visible hitch in the reveal, the turns, the pick, the flight or
the Backs shelf: every motion's frames run at the display's 16.7 ms with p95
under 20 ms. What remains is one frame of 40 ms (2.4 refreshes) where the Backs
look starts: the first frame of a cross-fade that starts from nothing, with no
compile behind it (draw 24 ms; most likely the shelf's glyphs and kept card
frames reaching the GPU for the first time). The one 41 ms frame in a reveal
came before the deal, while the cards were still unseen, in 1 of 4 B reveal
readings across both batches. The tap that changes the back holds its own
frame for about 50 ms while the bench bakes the back, as `CardBacks` documents
for a warm iPad 8 bake; nothing in motion follows it but the 0.24 s lift.

The shelf built with the hall ahead moves its cost to the title at rest,
where main's own warms already run (`PathWarm`, `RoomWarm`): the title's worst
frame in the measured launches was 24.9 to 48.2 ms on A (0 to 19 frames over
33 ms per launch) and 47.5 to 56.6 ms on B (1 to 14).

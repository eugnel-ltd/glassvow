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
| Reward pick, the reveal (§3) | `RewardEmbers`: the offering is dealt face down out of a small stack at the rack's middle (it rises into the bed, 0.20 s; the cards go to their seats top card first, 0.26 s each, 0.06 s apart), then each turns over left to right, 0.12 s apart and 0.48 s each, pitching toward the eye as the deal does (−14°·sin πt). The turn is the live one (`CardView.turn(…, true)`): the slab turns in its own stage under its own lamp. | **No lamp sweep.** The card's lamp belongs to the pointer at rest (the reward file's own rule); the finish answers the turn because the slab turns under the lamp, which is the flare the eye reads. A face-down card dealt before the table's back is baked (it is baked as this route is built) is dressed again the frame the bake lands. |
| Skip | A tap or a click once the deal has begun lands the offering face up at once (`settle`). A tap on a face-down card lands the offering and takes nothing; the next tap takes. | Taps during the husk's break do nothing, as before. |
| Reduce Motion | Each card fades in face up at its seat, 0.16 s, 0.04 s apart; no turn, no stack. | |
| Reward pick, the pick (§3) | The card taken flies into the run HUD's deck over 0.42 s, shrinking to the deck's card, turned face down by 60% of the way, over the HUD; the deck counts it and bumps (`DeckStack.bump`, the piles' `pileBump`) as it lands (`RunHud.owe_card`, `card_home`). The others turn back and slide away into the bed (0.32 s). Leave it sends all three away. Under Reduce Motion every card fades where it stands and the count ticks. | A resumed reward whose card slot was answered shows the offering gone, as a pick leaves it (it used to stand dimmed). |
| The Backs shelf (§5.4) | `VigilBacks`, a fourth look of the hearth hall on the hearth's framing (pane BACKS, after DEEDS): every back in the catalogue as a card in the body column, an earned one as a live card (`CardBacks.build`, released at rest) chosen with a tap, a click or its key; the back in use raised, IN USE under its name; a back not yet earned a silhouette of a card (the dark of a card, its rim in dim gold) with its deed. Built when the pane is first tapped, as the Rose look is. | **In the column, not on the plate.** #688 left `VigilHall.shelf()`, a seat on the plate under the column's legibility band: cards there are darkened by the band, scale with every framing, and on the phone the hearth framing puts the mantel at the stage's top edge. The seat had no other user and is removed. |
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

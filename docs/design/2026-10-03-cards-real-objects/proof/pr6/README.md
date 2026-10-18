# #657 PR 6, the resting card's stage released: evidence

The code is `2b9c4a41`; `9ca2d945` re-anchors four doc references it moved.
The windowed proof is `tools/check_card_rest.gd`, the suite's
`tests/test_card_rest.gd`. The device probe, the campaign, the analysis, the
frame differ and the mutation list are text under `device/`; the raw frames
and rows stay out of the repository. §1.1, §3 and §6.3 are the dossier's
(`../../README.md`).

## The spec as built

| Item | Built | Where it differs, and why |
|---|---|---|
| 1. Release at rest | A card that `releases_at_rest` arms a release whenever its stage is set to draw one last frame of the slab at rest (`_set_live(false)`, `_draw_stage_once`). After that frame's draw (`RenderingServer.frame_post_draw`) it looks again: still not pointed at, not springing, the slab not turned live, in the tree. Then the stage's frame is copied on the GPU into a texture the card owns (`GpuCopy`), the picture wears it, and both passes are freed: the face's render target, the stage's, its 4x MSAA buffers and its world (`own_world_3d`). The face's root, the slab and the camera stay with the card, out of the tree, and go with it when it is freed. The `_inner` pass goes too: the stage's frame already carries the face. | **A GPU copy, never a readback.** `RenderingDevice.texture_copy` of the whole stage (400 × 528 at the 2x oversample, 0.81 MiB), recorded after the frame that drew it, so nothing waits for the GPU. It is the copy `CardFaces` already made for baked faces, moved into `GpuCopy` so both share one owner that frees its texture with itself. The **whole** stage is kept, not `CardFaces`' crop to the gem's reach: the kept frame is then drawn by the same node on the same quad with the same texel grid, so a fanned, scaled card is the same pixels, where a crop differs by a level on a few edge pixels. Cost on the Mac: twelve releases in a probe fight, the worst release frame 8.7 ms against a rest p50 of 8.8 (`device/summary-mac.txt`); the iPad's is in the device table. Without a RenderingDevice on the render thread (Compatibility, the web build) the card keeps its passes. |
| 2. Rebuild on demand | The moment the stage must draw — `_set_live(true)` (a pointer: hover, or a touch's emulated mouse, which a drag and a play begin with) or `_draw_stage_once` (a live turn, or anything else that moves the slab) — the card builds both passes again around what it kept (`_mount`, the same factory as at its build): the face pass first, so it draws before the stage that samples it; the plates rebound to the new face texture; the picture back on the live stage. They draw in that same frame, before the picture shows them. No material is made: the rebuilt stage wears the objects the card was built with. Back at rest, it releases again. | A picture turn (the deal, the burn, the reshuffle's first card) needs no stage and builds none; a play from rest flies the kept frame. |
| 3. Coverage | The combat hand (`HandView.add_card`), and the reward's offering (`RewardSpoils.card`, through which the reward screen builds its three cards). | Below. The Night Stall's rack is **not** built: see *Coverage*. |
| 4. Lifetime safety | Nothing a flight, a touch or a live turn needs is freed by a release: the slab keeps its materials (the side band's generated `StandardMaterial3D`, the face's and the stone's `ShaderMaterial`s over `card_surface.gdshader` and `card_gem.gdshader`, which `CardView` preloads), the live turn's back plate stays on the slab, and the fight still holds one of each generated material (`CardTurn.hold_for_fight`). The structural guard (`tests/test_card_rest.gd`, `_rebuild_wears_what_the_fight_holds`) fails if a rebuilt stage wears a material it was not built with, a generated material the real fight's load does not hold, or a shader the card's script does not hold. | The counters: below. |

**Carried items.**

- *PR 5b's watch item, the reshuffle p95:* measured in the device batch (below).
- *PR 3's review items for PRs 4–7:*
  - `CardView.turn()` returns early on a retired card: **landed** (PR 4). This PR keeps it, and `retire()` now also holds on a card that has let its passes go.
  - No child scan that casts to CardView: **landed**. The only scans are `HandView.card_at` and `keyword_at`, which accept only a card the hand holds (`_held` checks `_views`), so the pre-warm's retired back card under the CombatScreen is never taken; the reward and stall scans walk their own seats. This PR adds none: the passes are put back by index (`_display.get_index()`).

## Coverage: every other place a live card rests

| Place | What rests there | Built here? |
|---|---|---|
| The combat hand | five live cards (about 80 MB on the iPad 8, §6.3) | **Yes**, the scope's first item. |
| The reward window (the reward screen, RewardEmbers; the lab's other concepts build through the same factory) | three live cards while the player chooses | **Yes**: one line in `RewardSpoils.card` and a test. Windowed: with only the cards on screen, main and the branch are pixel-identical through rest, a pointer, its settle and the release (11 of 11 frames), and nothing compiles (`--reward`, below). PR 7's reveal will turn these cards live; a live turn rebuilds the stage. |
| The deck view's card under the finger, and the pile inspector | one live card standing in for a baked face (`BakedCard`, `CardGrid`) | **Already released.** The stand-in is freed once it has sprung back to rest (`BakedCard.go_rest`), since PR 2 and PR 5. |
| The map | no live card: the top-menu deck is a canvas stack of one baked back (PR 5b), the deck view baked faces | **Nothing to release.** |
| The Night Stall's rack | up to five live cards while the player browses | **Not built.** One line would do it, and it is pixel-identical (`--shop --seed=1`, 11 of 11 frames). But in a session that reaches the stall without a fight, the first rebuild compiles 54 surface, 3 draw and 3 specialisation pipelines where main's first hover compiles 46, 3 and 3 (three runs each, the same every time): main's own first-use compile, plus 8 surface pipelines this PR would add. They are not identified and not held, so by the brief's rule the stall waits for its own change (with the #682 lane's warm). |
| The card lab, the studio, the turn sheet | dev tools; the lab dumps both passes (`GLASSVOW_DUMP`) | **Not built.** Not shipped flows. A card being dumped never releases before the dump (`_pinned`). |
| A bake's card (CardBacks, CardFaces) | read back through both passes, then retired or freed | **Never releases** (`releases_at_rest` is false by default); a test holds it. |

## Tests and mutations

`tests/test_card_rest.gd`, on a fake keeper (`CardView.use_keeper`: the suite
is headless, where no frame is drawn and no RenderingDevice copies):

- a resting hand holds no stage: every card wears its kept frame, and no SubViewport stands under the hand;
- a touched card has one, built in the call: the face pass before the stage before the picture, the picture on the live stage, the plates reading the new face pass, its own face, slab and camera inside; held, it keeps it;
- a card back at rest releases its stage: the pointer leaves, it settles, it wears a new kept frame;
- a live turn builds the stage and keeps it while the card lies turned; turned back to rest, it lets it go; a picture turn builds none;
- a card armed to let go and touched before the frame draws keeps its stage;
- a card that does not release (a plain one, a bake's back) keeps its passes;
- the reward's offering releases;
- **the structural guard**: every hand card's rebuilt stage wears exactly the materials it was built with, every generated one matching one the real fight's load holds, every shader one the card's script holds;
- a card freed while released leaves no face, slab or camera behind.

Seventeen mutations (`device/mutations.json.txt`, run by `device/mutate.py.txt`:
back the file up, break it, run the one test, copy the backup back), every one
caught on the tests as committed:

| Mutation | What it breaks | Caught by |
|---|---|---|
| `r01-hand-not-opted-in` (`hand_view.gd`) | the hand's cards do not release | a resting hand card strike holds its stage |
| `r02-never-armed` | a card armed to rest never waits to let go | a resting hand card strike holds its stage |
| `r03-releases-while-held` | the release ignores a pointer on the card | a card touched after it was armed to let go let its stage go |
| `r04-releases-turned` | the release ignores a slab turned live | a card lying turned live let its stage go |
| `r05-picture-not-back` | a rebuild leaves the picture on the kept frame | a touched card's picture does not wear its live stage |
| `r06-face-not-rebound` | a rebuild leaves the plates reading the old face pass | a rebuilt card's plate 1 does not read its new face pass |
| `r07-stage-before-face` | the stage seated before the face pass it samples | a rebuilt card's passes are not face, stage, then picture |
| `r08-touch-no-rebuild` | a pointer does not build the stage | a touched card has no stage |
| `r09-turn-no-rebuild` | a live turn does not build the stage | a live turn did not build the stage |
| `r10-turn-never-lets-go` | a card turned back to rest keeps its stage | a card turned back to rest kept its stage |
| `r11-everyone-releases` | every card releases, a bake's included | a card that does not release let its stage go |
| `r12-orphans-kept` | a card freed while released leaves its nodes | a card freed while released left 3 of its face, slab and camera behind |
| `r13-rebuild-new-side` | a rebuild dresses the side band anew | strike's rebuilt stage wears materials it was not built with |
| `r14-rebuild-side-unheld` | a rebuild dresses it in a generated material no fight holds | (as r13) |
| `r15-fight-holds-nothing` (`card_turn.gd`) | the fight's load holds no generated material | strike's rebuilt stage wears a generated material the fight does not hold |
| `r16-released-without-a-frame` | the picture does not wear the kept frame | a resting hand card strike holds its stage |
| `r17-offering-not-opted-in` (`reward_spoils.gd`) | the offering does not release | a reward offering's card at rest holds its stage |

## Stills, swaps and frames (Mac, M1 Max, Metal, Forward Mobile)

`tools/check_card_rest.gd` boots the map (`--map --seed=1`), deals a
five-card deck so the opening hand is all of it — Novaflare (rare: the
*nebula* foil, the gilt rim and the shine), Ashen Choir (uncommon, *opal*),
Held Light (common, *card*), Edge and Ward (starters, *plain*) — and opens the
bench fight (Duskfang, elite) at `--fixed-fps 60`, so two builds take the same
steps on the same frames. The same script ran on main (`5666c336`) and the
branch at 1180 × 820, 844 × 390 (`--shape=phone-landscape`) and 1458 × 820
(desktop), in English and Traditional Chinese (`device/stills6.zsh.txt`).
`--hand-only` hides everything but the hand, and the rare's shine (which runs
on TIME). `device/pixel-diffs.txt` has every comparison
(`device/diff_frames.py.txt`).

- **The resting hand: pixel-identical to main** at all three shapes in both
  languages: `01-rest` and `40-turn2-rest` (the reshuffle's deal) differ in 0
  pixels in all six. So do the settle and release frames, the live turn after a
  release and both plays after a release: 26 of the 31 frames, every shape and
  language, 0 pixels.
- **The touch frames** (`11`–`15`, a pointer on the foil card): identical at
  pad/English; at the other five, up to 16 levels on the hovered rare's gilt
  rim only (`09-touch-rim-runs-on-time.jpg`). The rim's hover sheen runs on
  shader TIME (`card_edge.gdshader`, `TIME * 0.6 * hover`), which a fixed
  frame rate does not fix: two runs of **main** differ on the same frames and
  the same rim (pad/Chinese, up to 2 levels). Nothing else on any card moved.
- **The swap at a release** (`16-back-settled`, the frame the stage draws its
  rest in, against `17-back-after`, the first frame on the kept copy):
  identical, on both builds and against main.
- **The swap at a rebuild** (`06-swap.jpg`; the `SWAP` check): a rebuild with
  nothing moved. The kept frame, the rebuilt stage's first frame and the frame
  after it lets go again are one frame, pixel for pixel, and the frame it keeps
  the second time is the first, texel for texel (both read back). At a touch the
  rebuilt stage draws in the touch's own frame with the spring's first step, as
  main's stage does; `11-touch-0` against main is the comparison above.
- **Full frames** (everything on screen, `01-rest-shapes.jpg`): the cards are
  identical to main but for the rare's shine (TIME); the actors' idle animation
  differs run to run on any build.

| File | Shows |
|---|---|
| `01-rest-shapes.jpg` | the resting hand, full frame, pad, phone and desktop, English and Traditional Chinese (branch) |
| `02-rest-hand-main-vs-branch.jpg` | the hand alone, main beside the branch: pad/English, phone/Chinese, desktop/Chinese |
| `03-touch-and-release.jpg` | the touch on the foil card, frame by frame: before, the touch's frame, +1, +2, +6, held (tilt and lamp), the frame it settles in, the first frame on the kept copy, rest |
| `04-live-turn-after-release.jpg` | a live turn of a released plain card, over and back, and rest after |
| `05-plays-after-release.jpg` | a strike at the foe and a defend to the discard, from rest |
| `06-swap.jpg` | kept, rebuilt, released |
| `07-reward-offering.jpg` | the reward's offering at rest, cards only, main beside the branch |
| `08-a12-condition.jpg` | the A12 condition (below) |
| `09-touch-rim-runs-on-time.jpg` | where the touch frames differ: the rim, main against the branch and main against main |

Looked at, every one: the resting hands read the same at every shape and in
both languages; the touched card rises, tilts to the finger and takes the lamp,
and springs back to rest with no jump at the release; the live turn shows the
back plate (Vault) and comes back face up; the strike streaks to the foe and
the defend lands face up on the discard.

## The counters and video memory (Mac)

- **Pipeline compiles** (surface, draw, specialisation), from the fight's load
  frame: **no rebuild compiles one.** In the windowed check (pad/English) they
  read 152 / 26 / 65 at the load and stay there through the touch, the settle
  and release and the live turn; the only change in the whole fight is the
  first play's, after which they stay at 152 / 27 / 66 through the reshuffle's
  deal and the rebuild-at-rest swap. That first play compiles 1 draw and 1
  specialisation pipeline (and 1–3 canvas) on main as on the branch, on the
  same step (the strike's hit in the windowed check, the defend in the probe):
  a first use outside the cards, for the #682 lane. Under the A12 condition,
  the same (below).
- **Video memory** with five cards in hand at rest: main 477.7 MiB, the branch
  414.4 (−63.3), measured by mounting the five cards' passes again one by one:
  11.9 MiB a card on the Mac, against 0.81 MiB for its kept frame. At the
  probe's turn-2 rest, main 470.5 and the branch 419.2 (−51.3). The iPad 8's
  figure is in the device table.
- **The touch on the Mac** (the probe, A12 flags): the touch's frame and the
  two after it 8.3 / 9.3 / 7.8 ms on the branch, 7.7 / 8.0 / 9.3 on main.

## The A12 condition

`GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 godot --rendering-driver metal
--rendering-method mobile …` with the shader cache off (`override.cfg`
`[rendering] shader_compiler/shader_cache/enabled=false`, for these runs
only), the fight check (rest, touch, release, live turn, plays, reshuffle,
swap) and the reward offering: `Metal 4.0 - Forward Mobile`, **0 "Error
compiling shader" lines**; every check passed but the first play's compile
named above; the only error line is Godot's exit notice of resources still in
use (`08-a12-condition.jpg`).

## iPad 8 (A12, 2160 × 1620)

QA builds of main (`5666c336`, A, sha256 `46a22af5…`) and the branch
(`2b9c4a41`, B, the code of this PR; `fdfcb29d…`), each with the same untracked
probe (`device/card_probe.gd.txt`, attached by `device/patch.py.txt`). One hold
of the iPad lock for the whole campaign (`device/campaign6.zsh.txt`: 11 Oct
2026, 20:41:17 to 22:03:49), two sessions interleaved by install, p6-1 A then
B and p6-2 B then A. Each install ran a warm-up map launch, then three fights
150 s apart: six measured fights per build, 16 launches in all, every row with
its own nonce and build tag. The iPad was on its charger and full (100%, not
charging) at every launch, at 33.2–41.4 °C. The probe opens the bench fight
(Duskfang, elite) from the settled map, as PR 5b's did: a kindle, End Turn,
then **rest**, 10 s with five cards in hand (frame times, video memory, stages
held); **the touch**, the hand's front card entered as a finger's emulated mouse
enters it (`CardView.point_at`: the card's `mouse_entered`, then the motion that
sets the lamp down), held 1 s and left (no tap: on the iPad a tap would also
lift the card); a play from rest (a defend to the discard); End Turn, which
reshuffles nine cards all dealt before, and the deal (**resh**, **rdeal**).
The analysis is `device/summary-p6.txt`, the batch logs `device/p6-1-batch.log.txt`
and `p6-2-…`.

Medians over the six fights of each build (per-fight p50 and p95, then the
median of each), with p6-1 / p6-2 in brackets:

| Figure | A, main | B, branch | B − A | The bar | Verdict |
|---|---|---|---|---|---|
| Video memory at the combat rest, five cards in hand (MiB) | 659.2 (655–659) | 600.6 (593–601) | **−58.6** | report it against the dossier's ~80 MB → <10 MB | the hand's stages held about 62 MiB (58.6 freed, 5 × 0.81 kept); see below |
| Stages held at rest | 5 live cards | 0 in 6 of 6 | | | |
| Combat rest p50 (ms) | 16.66 | 16.67 | +0.01 (−0.00 / +0.01) | within +0.5 | **met** |
| Combat rest p95 (ms) | 18.01 | 18.29 | +0.28 (−0.07 / +0.12) | within +0.5 | **met** |
| The touch's frame / +1 / +2 (ms) | 17.2 / 17.0 / 16.8 | 15.3 / 19.0 / 16.3 | | no frame over 33 ms | **met**: 0 of 18 frames on B (worst 19.8) |
| Pipeline compiles after the load (surface, draw, spec.) | at the play only: +1 draw, +1 spec. (6 of 6) | at the play only, the same (6 of 6) | none | flat after the load | **met for this change**: the touch, the releases, the rebuild, turn end, the reshuffle and the deal compile nothing on either build; the one compile is main's own first play (below) |
| Reshuffle p50 / p95 (ms) | 16.72 / 18.94 | 16.64 / 19.18 | −0.07 / +0.24 (p95 +0.17 / −0.04) | PR 5b's watch item: +0.74 then | measured: +0.24 |
| Reshuffle, worst frame (ms) | 24.9 | 23.9 | −1.0 | reported | |
| Releases per fight / worst release frame (ms) | — | 12 / 21.3–24.2 | | reported | inside the deals, where main's worst reshuffle frames run 23–26 ms |
| Throttle | p6af1 from 27 s | none | | recorded | |

- **Video memory.** The resting hand holds 58.6 MiB less on the branch in
  every pairing (A 655–659 MiB, B 593–601). Five kept frames cost 4.0 MiB, so
  the five live stages held about 62.6 MiB on the iPad 8, 12.5 MiB a card:
  less than the dossier's 15.8 MB (its figure was a whole live card as built,
  this one only what the release frees). The dossier's "about 80 MB to under
  10 MB" becomes 62.6 MiB to 4.0 MiB.
- **The touch** builds a stage in its own frame: the frame takes 15.3 ms on
  the median (A 17.2), and the frame after it, the rebuilt stage's first full
  draw, 19.0 (A 17.0). The worst of the eighteen is 19.8 ms.
- **The one compile after the load** is the first play's: 1 draw and 1
  specialisation pipeline (and 3 canvas), in the play phase of all twelve
  fights, on both builds. It is not a card stage's: no count moves at the
  touch, at a release or at the rebuild, and the kindle earlier in the same
  fight, which flies a card to a pile, compiles nothing. In p6af1, main's
  install's first fight, that play's frame took 611.3 ms; elsewhere 33–51 ms
  on both builds. A first use for the #682 lane.
- **The reshuffle.** p95 +0.24 over all six (p6-1 +0.17, p6-2 −0.04), against
  PR 5b's +0.74; the worst frame is 1.0 ms better.
- **Outliers:** p6af1 (A) throttled from 27 s: its reshuffle p95 43.79 and its
  play's 611 ms frame; without it main's rest p95 median is 18.20 (B − A
  +0.09) and its reshuffle p95 median 18.60 (B − A +0.58, against PR 5b's
  +0.80 without its throttled fights). The load's second frame ran 48–50 ms in p6af1 and
  p6bf2, and 30–33 ms in p6af4 and p6bf4, on both builds as in PR 5b.
- **Warm-ups** (named, not graded): p6aw1, p6bw1, p6aw2, p6bw2, none throttled.

Every fight, with battery, charging state and temperature as logged before it:

| Batch | Launch | Build | Battery, temp. | Throttle onset | Counters at the load | Changes after it | Load / +1 / +2 | Rest p50 / p95 | VRAM at rest (stages held) | Touch / +1 / +2 | Play worst | Reshuffle p50 / p95 / worst | Releases (worst) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| p6-1 | p6af1 | A | 100%, not charging, 34.09C | 27 s | 22/10/142/9/48 | the play, frame 1474 25/10/142/10/49 | 809.3 / 20.4 / 50.1 | 16.66 / 17.39 | 659 (-1) | 17.1 / 16.8 / 16.4 | 611.3 | 20.66 / 43.79 / 46.1 | - |
| p6-1 | p6af2 | A | 100%, not charging, 37.59C | none | 22/10/142/9/48 | the play, frame 1554 25/10/142/10/49 | 731.7 / 16.0 / 22.8 | 16.67 / 17.81 | 659 (-1) | 17.2 / 17.2 / 16.8 | 49.2 | 16.73 / 18.60 / 24.9 | - |
| p6-1 | p6af3 | A | 100%, not charging, 38.59C | none | 22/10/142/9/48 | the play, frame 1467 25/10/142/10/49 | 778.7 / 16.2 / 16.8 | 16.67 / 17.39 | 659 (-1) | 17.4 / 16.8 / 16.8 | 50.1 | 16.71 / 18.23 / 24.9 | - |
| p6-1 | p6bf1 | B | 100%, not charging, 37.39C | none | 22/10/142/9/48 | the play, frame 1442 25/10/142/10/49 | 733.1 / 16.2 / 16.7 | 16.66 / 17.27 | 601 (0) | 15.5 / 18.8 / 15.8 | 49.7 | 16.71 / 19.16 / 23.7 | 12 (23.7) |
| p6-1 | p6bf2 | B | 100%, not charging, 39.50C | none | 22/10/142/9/48 | the play, frame 1556 25/10/142/10/49 | 749.8 / 15.1 / 48.2 | 16.68 / 17.32 | 593 (0) | 15.4 / 18.5 / 16.7 | 46.4 | 16.64 / 18.40 / 24.2 | 12 (24.2) |
| p6-1 | p6bf3 | B | 100%, not charging, 39.89C | none | 22/10/142/9/48 | the play, frame 1610 25/10/142/10/49 | 728.5 / 16.2 / 24.6 | 16.67 / 18.30 | 601 (0) | 16.1 / 18.1 / 16.3 | 50.1 | 16.64 / 18.77 / 24.2 | 12 (21.5) |
| p6-2 | p6af4 | A | 100%, not charging, 39.19C | none | 22/10/142/9/48 | the play, frame 1537 25/10/142/10/49 | 732.8 / 16.1 / 33.2 | 16.66 / 18.45 | 659 (-1) | 17.2 / 17.5 / 16.6 | 49.8 | 16.64 / 19.82 / 25.6 | - |
| p6-2 | p6af5 | A | 100%, not charging, 41.00C | none | 22/10/142/9/48 | the play, frame 1518 25/10/142/10/49 | 745.9 / 15.3 / 19.0 | 16.65 / 18.95 | 659 (-1) | 17.3 / 17.3 / 17.0 | 45.9 | 16.60 / 19.28 / 23.3 | - |
| p6-2 | p6af6 | A | 100%, not charging, 41.00C | none | 22/10/142/9/48 | the play, frame 1617 25/10/142/10/49 | 728.9 / 16.5 / 20.3 | 16.66 / 18.20 | 655 (-1) | 15.8 / 16.5 / 17.6 | 45.5 | 16.74 / 17.87 / 23.4 | - |
| p6-2 | p6bf4 | B | 100%, not charging, 39.09C | none | 22/10/142/9/48 | the play, frame 1509 25/10/142/10/49 | 727.0 / 16.4 / 30.0 | 16.64 / 18.57 | 601 (0) | 14.7 / 19.8 / 16.1 | 33.3 | 16.65 / 19.20 / 22.4 | 12 (21.3) |
| p6-2 | p6bf5 | B | 100%, not charging, 40.79C | none | 22/10/142/9/48 | the play, frame 1563 25/10/142/10/49 | 744.8 / 16.6 / 16.5 | 16.67 / 18.28 | 601 (0) | 15.2 / 19.1 / 16.8 | 50.1 | 16.66 / 19.24 / 23.5 | 12 (23.5) |
| p6-2 | p6bf6 | B | 100%, not charging, 41.00C | none | 22/10/142/9/48 | the play, frame 1456 25/10/142/10/49 | 761.9 / 16.6 / 19.5 | 16.68 / 18.78 | 593 (0) | 14.7 / 19.5 / 16.3 | 50.5 | 16.58 / 19.65 / 24.4 | 12 (21.9) |

## Core gate

On `9ca2d945` (the code of `2b9c4a41`), at a load average of 7 to 17 at its
start: `godot --version` (4.7.2.stable), `tools/check_imports.sh`,
`tools/check_scripts.sh` (503 scripts OK), `godot --headless -s
res://tests/run_all.gd`, `check_anchors.py` (OK; the four references the change
moved were re-anchored by hand in `9ca2d945`), `check_benchmark_freeze.py`
(592 citations frozen) and `payload_report.py` (`presentation` 3.2 of its
3.3 MiB, the pack estimate 283.0 MiB of 400, as on main). The suite ran 159
tests and failed one, `test_pile_fight`'s real-time "a kindle bumped the ash 0
times under Reduce Motion", the load-sensitive test PR 5b also met; it builds no
`Main` and its cards never release headless. Alone, twice, at a load of 23 to
26: **PASS** both times.

## Membership guard evidence correction (18 October 2026)

The historical `r14` recipe replaces the side material. Its retained table
entry names the same material-identity diagnostic as `r13`. It does not prove
that shader membership failed independently. `r15` separately checks generated
material retention. The old campaign has no retained independent negative
control for the script-held shader branch.

`tests/test_card_rest_membership_controls.gd` now calls the unchanged structural
guard through a real hand's release and rebuild. After the guard captures its
baseline, one control changes the same side material's cull mode. Another
changes the same face material's shader to an unheld copy with identical code.
Each keeps all material objects and requires exactly its own membership
diagnostic, with no material-identity diagnostic. Untouched controls run before
and after both cases.

The first valid fixture and UID are frozen at `ef3f0d01`. They pass on the
unchanged production code. Two separate temporary bypasses of the old guard
each make exactly the corresponding new expectation fail. These failures are
deliberate test mutations, not evidence of a production defect. The original
test is restored byte for byte after each run.

This headless proof checks material identity and membership. It measures no
GPU readiness, pipeline compilation, pixels or device timing. The historical
mutation recipes, results and images remain unchanged.

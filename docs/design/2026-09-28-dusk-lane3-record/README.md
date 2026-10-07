# Dusk lane 3 — record of an unshipped lane (#421)

**Status: NOT shipped. Not merged to main. Not a P9 receipt.** None of the lane-3 gameplay content (content, rules, locale, tests) is on `main`. It exists only on the kept branches listed in §10. This file is a docs-only record.

**Owner decision (James, 2026-09-28).** Lane 3 is not merged. This single docs PR on `main` records its full spec and why it failed. PRs #567, #568 and #569 are to be closed unmerged, and their branches are kept as reference.

Sources: the design lock and probe notes (#567), the exam 1 readout and data (#568), the C3 diagnosis revision 2 and probe data (#569), the [#421 readout comment](https://github.com/eugnel-ltd/glassvow/issues/421#issuecomment-5863378757) and the three PR bodies. Where this record and a source differ, the source wins. VERIFIED and INFERRED tags are copied from the sources. Acceptance was amended P9 ([#108 comment 5850584190](https://github.com/eugnel-ltd/glassvow/issues/108#issuecomment-5850584190), point 4 as amended in [#421 comment 5855915475](https://github.com/eugnel-ltd/glassvow/issues/421#issuecomment-5855915475)), for Duskblade only at vows 0 and 5.

## 1. Design intent

Lane 3 tried to give Duskblade a third viable strategy cell. Before it, #557 (the Unbroken Crown) had made smolder:fat a second lane, but no third cell was in band. From the [design lock](https://github.com/eugnel-ltd/glassvow/blob/e7f42147cf5c2a8e282e2b0767ed35a4adf8799f/docs/reviews/421/dusk-lane3-design-lock.md) §1–§2:

- A V5 third cell has to be a fat cell, because mid cells mostly hold act-2 deaths (VERIFIED on #557's exam-1 rows; the conclusion is INFERRED).
- attrition:fat was then "shatter decks that missed their tools", not a strategy (VERIFIED). A popular no-chip fork lowers the relative shatter median and fills the cell with real holders (INFERRED).
- A second new relic would share the crown's pilot key (`relicRarity.boss`). Crown of Tithes already has a named policy key, shipped art and a zh name (VERIFIED).
- The crown's per-Attack payoff rewarded thin, attack-heavy random builds (arm 2) (VERIFIED). Max HP is not a C2 lever (VERIFIED, paired probe).

The chosen shape, F1, did two things. Crown of Tithes became a deck-scaled Duskblade fork, and the Unbroken Crown got a fullness threshold. Deck-scaled payoffs punish unfocused decks and spare focused ones. In the F1 probe, random-build Tithes holders won 80/203 (old Tithes 126/202) and crown holders won 86/177 (122/189). Tuned holders stayed neutral: Tithes −1.0 / +0.7 pp and crown −1.2 / −0.2 pp, paired over 600 policies (VERIFIED, probe scale). The [probe notes](https://github.com/eugnel-ltd/glassvow/blob/e7f42147cf5c2a8e282e2b0767ed35a4adf8799f/docs/reviews/421/dusk-lane3-probe-notes.md) list the rejected alternatives (tC, nB, tP1/tP2, HP 68/64, Rootheart facets 8, Cracked 2 → 1).

## 2. Spec as implemented

Candidate commits on `feat/421-dusk-lane3`:
- [`85deaec3d75f89169d95b7937b586fef64a3c6fc`](https://github.com/eugnel-ltd/glassvow/commit/85deaec3d75f89169d95b7937b586fef64a3c6fc): lock §3 content, the first candidate.
- [`582e2f71a406910ef6c1d949ff9717f343539ffd`](https://github.com/eugnel-ltd/glassvow/commit/582e2f71a406910ef6c1d949ff9717f343539ffd): retry knob 1, the exam candidate.

### 2.1 Content (`content/full-content.json`)

| Key | #557 base (`a9ad6c55…`) | `85deaec` (`b4593087…`) | `582e2f7` (`f0ecd890…`) |
|---|---|---|---|
| `relics.crownOfTithes.duskFervorPer` | — | **10** | 10 |
| `relics.crownOfTithes.duskWardPer` | — | **4** | 4 |
| `relics.unbrokenCrown.wardPerAttack` | 3 | **2** | 2 |
| `relics.unbrokenCrown.smolderPerAttack` | 3 | **2** | 2 |
| `relics.unbrokenCrown.fullDeck` | — | **30** | 30 |
| `relics.unbrokenCrown.fullPerAttack` | — | **3** | 3 |
| `enemies.rootheart.hp` | [240, 240] | [240, 240] | **[280, 280]** |

The `text` fields of both relics changed to match (§2.3). Pools, rarities, IDs and saves did not change. The relic count stays 32 and the locale leaf count stays 713. Content file SHA-256 values are in full in §10. Permalinks at `3c5144e`: [Crown of Tithes](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/content/full-content.json#L2056-L2064), [Unbroken Crown](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/content/full-content.json#L2079-L2090), [Rootheart](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/content/full-content.json#L2470-L2475).

Resulting rules:
- **Crown of Tithes, Duskblade holder (`run.aspect == 0`).** Blows no longer chip Facets. The holder starts each combat with `deck ÷ 10` Fervor, once per combat. At the start of each turn, it gains `deck ÷ 4` Ward. Kindle twice per turn for 3 Ward each is unchanged for both aspects. Ashwarden gets none of the Dusk clause.
- **Unbroken Crown.** Each Attack gives 2 Ward and 2 Smolder, or 3 of each while the run deck holds 30 or more cards.
- "Deck" is `run.player.deck.size()`, with integer division. Every number is read from content. The hooks make no RNG draws and add no policy key. `tools/` is untouched.

### 2.2 Rules (`domain/rules/combat.gd`, 29 insertions and 4 deletions)

All links are pinned to `3c5144e`:
1. **Fervor at combat start.** In `_apply_start_relics`, directly after the Crown of Cinders block, Fervor (status `str`) is added and a `relicProc` is emitted ([L293-L296](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/domain/rules/combat.gd#L293-L296)).
2. **New helper `_tithes_per_deck(run, field)`.** It returns `deck ÷ per`, where `per` is the relic's `field` value, for a Duskblade Tithes holder. For Ashwarden, non-holders or a missing or zero field, it returns 0 ([L318-L326](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/domain/rules/combat.gd#L318-L326)).
3. **Turn Ward.** In `_start_player_turn`, right after the Ward reset, `gain_block_player(cb, n, false, run)` runs (no Poise), and a `relicProc` is emitted. It also runs under Barricade ([L368-L371](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/domain/rules/combat.gd#L368-L371)).
4. **No-chip guard.** `apply_chips` and `preview_play` extend the #557 guard with `or run.has_relic("crownOfTithes")` ([L685-L687](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/domain/rules/combat.gd#L685-L687), [L1422-L1425](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/domain/rules/combat.gd#L1422-L1425)).
5. **Crown fullness.** In `play_card`, `crown_full` is true when `fullDeck` is present and the deck holds at least `fullDeck` cards. Ward and Smolder then use `fullPerAttack`; otherwise they use `wardPerAttack` and `smolderPerAttack` ([L846-L863](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/domain/rules/combat.gd#L846-L863)).

The kindle limit and kindle Ward, `domain/rules/rewards.gd` and every tool were unchanged. The independent review (`ai-sdlc-reviewer`) on exact head `85deaec` returned APPROVE with no blockers. Its one non-blocking note was that the Tithes `relicProc` events are presentation-only.

### 2.3 Locale (`locale/en.json`, `locale/zh-Hant.json`; 2 lines each)

- **Crown of Tithes.** The shipped text is kept, and a Duskblade clause is appended. en: "…Duskblade: your blows no longer chip Facets; begin each combat with 1 Fervor for every 10 cards in your deck, and at the start of each turn gain 1 Ward for every 4." zh-Hant: 「…暮刃：你的攻擊不再琢擊璃面；每場戰鬥開始時，牌庫每有 10 張牌便獲得 1 層熾心；每回合開始時，每有 4 張牌便獲得 1 點護光。」
- **Unbroken Crown.** en: "…gain 2 Ward and apply 2 Smolder to the enemy; 3 of each while your deck holds 30 or more cards." zh-Hant: 「…獲得 2 點護光，並對該敵人施加 2 層陰燃；當你的牌庫有 30 張或以上時，兩者各為 3。」
- The zh terms follow shipped copy. Every character already appears in shipped text (VERIFIED in the lock).

### 2.4 Tests and pins

- `tests/test_aspect_shatter.gd` ([L152-L325](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/tests/test_aspect_shatter.gd#L152-L325)):
  - The existing crown case now reads its numbers from content: Emberbite 4 + 2 = 6 Smolder and 2 Ward on the 10-card deck.
  - New `_unbroken_crown_fullness`: 2 + 2 at 29 cards and 3 + 3 at 30.
  - New `_tithes_dusk_clause`, on a 23-card deck: 0 preview chips; no chip, stagger or explicit chip; 2 Fervor, once; 5 Ward on turns 1–3 (on turns 2–3 after 50 leftover Ward); kindles twice for 3 Ward each, and a third kindle is refused.
  - New `_tithes_ash_unchanged`: no Fervor and no turn Ward, but still kindles twice.
- Pins, old → new:

| Pin | `85deaec` | `582e2f7` |
|---|---|---|
| `tests/test_balance_catalogue.gd` `LIVE_FILE` | `a9ad6c55…` → `b4593087…` | → `f0ecd890…` |
| `tests/test_balance_catalogue.gd` `LIVE_SEMANTIC` | `45502203…` → `3ec1abca…` | → `c8f333a8…` |
| `tests/test_balance_sim.gd` `EXPECTED` (seed-1000 digest) | unchanged `2c3ce746…` | → `2c4c953e…` (the run meets the Rootheart) |

- Gate on both heads (Linux x86_64 VM, Godot `4.7.2.stable.official.ed1daf0bf`): `tools/check_scripts.sh` OK (257 checked), `run_all.gd` PASS (74 tests), locale and font coverage OK, anchors OK, and the Python checks selected by `ci_scope.py` OK. CI was green on both heads.

### 2.5 Diff summary

Lane-3-only diff, `git diff 567760f0...3c5144e8` ([compare](https://github.com/eugnel-ltd/glassvow/compare/567760f0104e46d400f18828978a3cb6271394d2...3c5144e87882dd7290b9f132f810053c8aab36ee)): 19 files, +4412 / −21. The merge base is the #557 head `567760f`.

| Area | Files | Change |
|---|---|---|
| Content | `content/full-content.json` (+10/−6) | §2.1 |
| Rules | `domain/rules/combat.gd` (+29/−4) | §2.2 |
| Locale | `locale/en.json`, `locale/zh-Hant.json` (+2/−2 each) | §2.3 |
| Tests | `tests/test_aspect_shatter.gd` (+136/−4), `tests/test_balance_catalogue.gd` (+2/−2), `tests/test_balance_sim.gd` (+1/−1) | §2.4 |
| Design docs (#567) | `docs/reviews/421/dusk-lane3-design-lock.md`, `docs/reviews/421/dusk-lane3-probe-notes.md` | lock and dev probes |
| Exam docs (#568) | `docs/balance/2026-09-28-421-dusk-lane3-exam.md` plus 9 JSON files in `docs/balance/data/421-lane3/` | readout, dev gate, both Phase A runs, layer 1 and 2, manifest |

#569 adds two more docs files on top of `3c5144e`: `docs/reviews/421/dusk-lane3-c3-diagnosis.md` and `docs/reviews/421/data/dusk-lane3-c3-probes.json`.

The full stacked diff against `main` (`git diff origin/main...3c5144e8`, merge base `330c692`, #566) is 73 files, +17171 / −71. It includes the unmerged #556 and #557 (§3).

## 3. Stacking: what lane 3 assumes from #556 and #557

Lane 3 is stacked on two unmerged draft PRs. **`main` has none of this content.** `main`'s content SHA-256 is `a0d608a5…` (H39): Dusk max HP 64, no Unbroken Crown, and the P9 tools still count C1b ≥ 4 and C3 ≥ 4.

| From | Branch and head | What lane 3 depends on | Its own outcome |
|---|---|---|---|
| #556 | `design/421-duskblade-breadth-retune` `e7a004d7122cf91c350aa0abc926965353017384`, content `8934031…` | Dusk max HP 64 → 72 (68 in exam 1, then 72); Refract Ward 6/9 → 8/11; Emberheart heal 3 → 6. Removal cost stayed 75 after a save-rejection gate. Amended P9 counts in the tools: C1b `len(viable) >= 3` (main: 4); C3 `stayed >= 3` with every stayed island within 15 pp (main: `stayed >= 4 and close >= 3`); V5 ceiling fails at ≥ 90% (main: > 90%). | Two exams, both MISS; stopped |
| #557 | `design/421-dusk-content-lane` `567760f0104e46d400f18828978a3cb6271394d2`, content `a9ad6c55…` | The Unbroken Crown: a Dusk-only boss relic (`"aspect": "duskblade"`) in the boss pool, which makes 6 Dusk boss relics with 3 offered. At #557's head it gives no chip, 3 Ward and 3 Smolder per Attack (Smolder 2 → 3 was #557's dev-gate retry), plus a holder exception to the H11 Dusk Smolder block. It also adds the aspect filter in `relic_pool` (`domain/rules/rewards.gd`) and the no-chip guard that lane 3 extends. | Exam 1 MISS (C1a, C1b, C3; C2 at V0); stopped |

Lane 3 itself adds only §2: the Tithes fork, crown fullness (which retunes #557's 3/3 to 2/2 and 3/3 at 30+) and Rootheart 280. The lane-3 lock was written on `e0388dfa` (#557 readout), and `e7f42147` merged #557's head (`567760f`, carrying main's #558 and #566) before implementation. `main` has since gained #565, which touches `domain/rules/rewards.gd`, so reviving any branch would need a reconcile.

## 4. Acceptance and procedure (lock §5)

- **Pass, per Dusk grid, at both vows.**
  - C1a: at least 3 cells within 10 pp of the top.
  - C1b: at least 3 cells at or above the floor, (top + arm 2) / 2.
  - C2: arm 2 < 50% and top − arm 2 ≥ 35 pp.
  - C3: at least 3 CEM islands stay in their start cell at or above the floor, all within 15 pp of the grid's best holdout.
  - C4: end-cell ceiling gap < 15 pp.
  - V5 best holdout < 90%.
- **Pre-exam dev gate.** Root 7421, policies 0–299 × seeds 12000–12015, arm 2 on 12100–12899. PASS at both vows needs at least 3 cells within 10 pp of the top, arm 2 < 50% with a gap ≥ 35 pp, and Tithes and crown paired deficits ≥ −5 pp. The rows were expected to reproduce the F1 probe exactly.
- **Phase A.** All four arm-2 rates must be < 50%, Dusk V0 ≤ 35.0% and Dusk V5 ≤ 20.0%.
- **Exam.** The #556 procedure: `--stage=exam`, roots 215/216, sweep seeds 3000–3039, controls 4000–4199, and 12 Dusk CEM islands (training 4200–4999, holdout 5000–5199).
- **One retry, in order.**
  1. C2 V0 short: Rootheart HP 240 → 280 (owner call A).
  2. attrition:fat is the only cell more than 10 pp off: `duskWardPer` 4 → 3.
  3. Any other C1 shape, or a C3/C4 miss: no knob; stop.
- The lock flagged C3 as UNKNOWN and the largest risk. Layer 2 was not probed before the exam.

## 5. Dev gate and Phase A history

Dev gate: [`dev-gate.json`](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/data/421-lane3/dev-gate.json). It passed at both vows before and after knob 1, and each run reproduced its lock probe rows (F1, then K2) byte for byte (9 of 9 files). The knob-1 run used `85deaec` code with the knob-1 content, whose SHA-256 equals `582e2f7`'s.

| Head | Vow | Top three cells | Arm 2 | Gap | Tithes paired (holders) | Crown paired (holders) |
|---|---|---|---:|---:|---:|---:|
| `85deaec` (F1) | V0 | 70.7 · 68.4 · 64.8 | 34.4% | 36.3 pp | +1.3 pp (951) | +0.1 pp (746) |
| | V5 | 56.5 · 51.5 · 50.9 | 14.5% | 42.0 pp | +2.6 pp (621) | +1.0 pp (414) |
| `582e2f7` content (K2) | V0 | 72.4 · 68.1 · 64.4 | 30.4% | 42.0 pp | +2.9 pp (897) | +2.8 pp (647) |
| | V5 | 60.6 · 56.7 · 56.6 | 11.1% | 49.5 pp | +7.4 pp (543) | +7.4 pp (340) |

Phase A arm 2 (200 seeds each):

| Run | Dusk V0 | Dusk V5 | Ash V0 | Ash V5 | Lock ceilings | Result |
|---|---:|---:|---:|---:|---|---|
| 1: `85deaec` ([JSON](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/data/421-lane3/phase-a-85deaec-before-knob1.json)) | **75/200 (37.5%)** | 26/200 (13.0%) | 42/200 (21.0%) | 12/200 (6.0%) | Dusk V0 37.5% > 35.0% | **MISS → knob 1** |
| 2: `582e2f7` ([JSON](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/data/421-lane3/phase-a.json)) | 64/200 (32.0%) | 23/200 (11.5%) | 40/200 (20.0%) | 8/200 (4.0%) | all met | PASS |

Run 1's miss triggered retry knob 1 (Rootheart 240 → 280). The owner approved call A as knob 1, and that spent the lane's single retry. The legacy #204 bands returned VETO on both runs (run 2 holdout: Dusk 68.0% / 36.0%, Ash 67.5% / 40.0%). They were recorded, but they are not the lock's gate. The fresh exam controls reproduced all 3,200 Phase A control rows exactly.

## 6. Exam 1 on `582e2f7`: MISS on C3 only

Run on 2026-09-28, 03:22–05:19 BST, on a Linux x86_64 VM (8 vCPU) with Godot `4.7.2.stable.official.ed1daf0bf`, using `tools/balance_exam.py --jobs 6` at `nice -n 10`. [Readout](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/2026-09-28-421-dusk-lane3-exam.md). Layer 1 has 320,000 rows (win 63,713, loss 256,184, stall 103). The exam's own axes are deck cuts 20/29 and Dusk medians of 0.889 shatters and 0.0 Smolder kills per fight. This was the only exam, and no re-run was due after a MISS.

| Criterion | Threshold | Dusk V0 | Dusk V5 |
|---|---|---|---|
| C1a: within 10 pp of top | ≥ 3 cells | 3 — PASS | 3 — PASS |
| C1b: viable | ≥ 3 cells | 3 (floor 50.06%) — PASS | 3 (floor 31.61%) — PASS |
| C2: arm 2 | < 50% | 32.00% — PASS | 11.50% — PASS |
| C2: arm-2 gap | ≥ 35 pp | 36.11 pp — PASS | 40.21 pp — PASS |
| C3: stayed viable | ≥ 3 islands | 1 (island 1) — **MISS** | 0 — **MISS** |
| C3: stayed islands close to best | all within 15 pp | 1/1 (gap 10.50 pp) | none stayed — **MISS** |
| C4: end-cell ceiling gap | < 15 pp | 8.50 pp — PASS | 12.50 pp — PASS |
| V5 best holdout | < 90% | 71.00% (not applicable) | 38.50% — PASS |

Layer-1 Dusk cell rates, as wins/runs and rate ([`layer1-analysis.json`](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/data/421-lane3/layer1-analysis.json)):

| Cell | V0 | V5 |
|---|---:|---:|
| smolder:fat | 4,671/6,858 · **68.11%** (top) | 1,375/2,659 · **51.71%** (top) |
| shatter:fat | 10,877/16,670 · 65.25% (−2.86) | 4,152/8,684 · 47.81% (−3.90) |
| attrition:fat | 5,084/8,258 · 61.56% (−6.55) | 1,921/4,267 · 45.02% (−6.69) |
| shatter:mid | 2,918/10,829 · 26.95% | 568/11,106 · 5.11% |
| smolder:mid | 725/3,486 · 20.80% | 98/1,741 · 5.63% |
| attrition:mid | 873/8,914 · 9.79% | 121/11,556 · 1.05% |
| smolder:thin | 67/1,746 · 3.84% | 6/1,479 · 0.41% |
| shatter:thin | 388/12,569 · 3.09% | 44/17,815 · 0.25% |
| attrition:thin | 61/10,670 · 0.57% | 6/20,693 · 0.03% |

Against #557's exam 1:
- attrition:fat rose from 37.02% to 61.56% at V0 and from 14.31% to 45.02% at V5.
- Arm 2 fell from 44.0% to 32.0% at V0 and from 15.0% to 11.5% at V5.
- The V5 best holdout fell from 64.5% to 38.5%.

Fork holders ("holder" = the run ends holding the relic; [manifest](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/data/421-lane3/raw-rows-manifest.json)):

| Grid | Relic | Holders (share) | Holder win | Non-holder win | Main cell (runs, win) |
|---|---|---:|---:|---:|---|
| V0 | Crown of Tithes | 13,201 (16.5%) | 56.3% | 27.3% | attrition:fat (6,053, 75.0%) |
| V0 | Unbroken Crown | 11,651 (14.6%) | 48.8% | 29.2% | smolder:fat (6,017, 70.8%) |
| V5 | Crown of Tithes | 5,909 (7.4%) | 45.0% | 7.6% | attrition:fat (2,957, 61.4%) |
| V5 | Unbroken Crown | 5,223 (6.5%) | 31.8% | 8.9% | smolder:fat (2,362, 54.2%) |

Layer 2 ([`layer2-analysis.json`](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/data/421-lane3/layer2-analysis.json)). Holdout is 200 runs per island. `stall` is CEM's plateau stop rule, not a simulation stall.

| Grid | Island | Start → end cell | Holdout | Generations | Stop |
|---|---:|---|---:|---:|---|
| V0 | 0 | smolder:fat → smolder:mid | 62.5% | 13 | stall |
| V0 | 1 | shatter:fat → **shatter:fat** | 60.5% | 20 | stall |
| V0 | 2 | attrition:fat → shatter:fat | 61.5% | 13 | stall |
| V0 | 3 | shatter:mid → shatter:fat | 71.0% | 17 | stall |
| V0 | 4 | smolder:mid → shatter:thin | 54.0% | 15 | stall |
| V0 | 5 | attrition:mid → shatter:fat | 69.5% | 20 | stall |
| V5 | 6 | smolder:fat → shatter:fat | 26.0% | 17 | stall |
| V5 | 7 | shatter:fat → shatter:thin | 38.5% | 20 | stall |
| V5 | 8 | attrition:fat → shatter:thin | 23.5% | 14 | stall |
| V5 | 9 | smolder:mid → attrition:fat | 24.5% | 20 | maxGen |
| V5 | 10 | shatter:mid → shatter:thin | 21.0% | 13 | stall |
| V5 | 11 | attrition:mid → shatter:thin | 17.5% | 12 | stall |

Every island that started in a fork cell (smolder:fat or attrition:fat) drifted out, mostly to shatter:fat or shatter:thin. That was the risk named in lock §8.

## 7. Diagnosis and probes (#569, revision 2)

[Diagnosis](https://github.com/eugnel-ltd/glassvow/blob/04fd5b85c7653736972761f575d5c7db32415fa3/docs/reviews/421/dusk-lane3-c3-diagnosis.md) and [probe data](https://github.com/eugnel-ltd/glassvow/blob/04fd5b85c7653736972761f575d5c7db32415fa3/docs/reviews/421/data/dusk-lane3-c3-probes.json). All probes used development seeds only (12000–12899, 13000–13199, 14000–14799), with no exam seeds and no `--stage=exam`. Revision 2 answered an independent review that had returned REQUEST CHANGES (four blockers, six nits), and it withdrew revision 1's candidate A.

**Answer: mostly an honest game signal.** Two content causes:
- **V5: the act-1 wall** (VERIFIED). At 280 HP the Rootheart ends 42–54% of each V5 island's holdout runs, against 13–41% at 240 HP in #557. Pooled, 49.2% of V5 holdout runs beat it (#557: 74.2%).
- **V0: no fork is a competitive first boss relic for optimised play** (VERIFIED). Among act-1 survivors in the pooled exam holdout, win rate by first boss relic was: Hollow Crown 84% (n 511), Tithes 70% (43), other crowns 66–69%, Unbroken Crown 50% (70). In #557 the crown was 83% (133). Hollow Crown ranks first in 10 of 12 final policies.
- Fullness is what sank the crown for tuned play (VERIFIED rows; INFERRED cause). Optimised decks are lean: island 0 holds the crown in 60% of runs, yet 72 of its 200 rows end in smolder:mid, where the crown pays only 2 + 2.
- Offer arithmetic caps any fork island (VERIFIED). Each fork appears in 3 of 6 boss offers. Even when the start-lane relic is forced to the top of the final policies, it is the first boss pick in only 36–46.5% of V0 runs and 19–32% of V5 runs.
- Tool properties add noise, not the V0 direction (existence VERIFIED; reading INFERRED). These are the representative rule (all 12 representatives are 100% on 1–5 in-cell runs), argmax fitness, the modal end cell, and relic-blind card and relic scoring with one global `cardDecline`. For the V5 fork islands, the start may cost up to about 8.5 pp (INFERRED). Reading end cells from wins only still gives V0 1 and V5 2, and both V5 islands are below the V5 floor, so C3 still misses (VERIFIED).

**Policy 846 frontier check** (seeds 13000–13199, VERIFIED):
- Layer-1 policy 846 wins exactly 45.0% at V5 (90/200) on #568 content, and 50.5% at Rootheart 260. Its layer-1 62.5% was a high draw.
- Exam island 7's final CEM policy wins **46.5%** on the same seeds. So CEM reached the V5 whole-policy frontier, and that frontier is shatter:fat.
- The next four layer-1 policies win 19.5–37.5%, and four perturbations of 846 win 27.5–39.5%, so 846 is a narrow peak. Exam fork islands 6 and 8 replay at 35.0% and 28.0%.
- Paired over 9 policies × 200 seeds, Rootheart 280 → 260 adds +3.2 pp (±0.8) at V5 and +2.4 pp (±0.9) at V0. P1 alone adds +1.1 pp (±1.0) at V5.

**The bar and the candidates.** The owner rule allowed a variant only if it showed **at least 3 distinct V0 stays and a credible V5 path**, preferring B over A if tied. The full-scale layer-2 rehearsal used the shipped CEM at exam defaults, six islands per grid, the shipped `select_islands` and the shipped `balance_cem_report.py`:

| Variant | Grid | Floor | Distinct stays at or above the floor | Grid best | Mean holdout | C3 | C4 |
|---|---|---:|---|---:|---:|---|---|
| A: Crown of Cinders Ashwarden-only + Rootheart 260 | V0 | 50.5 | **1**: attrition:fat (77.0) | 79.0 | 69.5 | MISS | PASS |
| | V5 | 34.6 | **1**: attrition:fat (36.5) | 49.0 | 38.1 | MISS | PASS |
| B: Crown of Cinders Ashwarden-only (P1) | V0 | 50.5 | **2**: shatter:fat (55.5), attrition:fat (57.0); neither within 15 pp of best | 82.5 | 68.2 | MISS | PASS |
| | V5 | 33.8 | **1**: shatter:fat (36.0) | 42.0 | 32.6 | MISS | PASS |

- **All eight smolder islands drifted**, at both vows and in both variants. So did all 16 V0 smolder:fat islands at probe scale (VERIFIED).
- Neither variant has a credible V5 path. Each keeps one V5 cell (VERIFIED).
- The result is robust to reading rules: wins-only end cells or #557's 21/30 cuts add no V0 stay (VERIFIED).
- Estimated Phase A Dusk V0 would be 33.5–35.0% for A and 33.1–34.6% for B, at or near the 35.0% ceiling, with knob 1 already spent.

Revision 1 also priced, at probe scale: R240 (knob 1 reverted); P (P1 plus Crown of the Hearth Ashwarden-only; arm 2 V0 37.1%); H20 (Hollow Crown −20 max HP); HX (Hollow Crown Ashwarden-only; C1a 2 cells at both vows); P1 + crown full at 26 cards and P1 + flat crown 3 + 3; and dev-gate-only combinations HXR260, HXR240, PR260, PR240, P1R260C26 and P1R260CF. No variant with a mini-CEM showed more than 2 distinct V0 stays; the dev-gate-only combinations were not run through CEM.

**Decision (#569): stop.** No variant qualifies, neither content field is implemented, no exam is spent, and C3 is not loosened.

## 8. Why lane 3 failed

Lane 3 met layer 1 and missed layer 2. The Tithes fork and crown fullness made three fat cells playable within 10 pp of each other at both vows, and C1a, C1b, C2, C4 and the V5 ceiling passed. C3 missed at both vows: V0 had 1 stayed-viable island and V5 had 0, against the 3 required (VERIFIED, exam rows). When CEM optimised a policy, it left the fork lanes (VERIFIED):
- At V0, the forks were not competitive first boss picks against the lane-neutral Hollow Crown. Each fork is also offered in only half of act-1 boss offers.
- At V5, the 280-HP Rootheart ended roughly half of optimised runs before any boss relic. The best V5 whole-policy frontier found (45–47%) is in the shatter lane, and the fork-lane V5 islands sat 10–18.5 pp below it.

One lever, Rootheart HP, pulled Phase A and V5 C3 in opposite directions. Knob 1 (Rootheart 280) was needed to bring Phase A Dusk V0 arm 2 under 35.0%: it was 37.5% at 240 HP. The harder act-1 boss is also the V5 wall. Rootheart relief is the only V5 lever with evidence, and it adds no stay while pushing Phase A back to its ceiling (VERIFIED numbers; the reading is INFERRED in #569 §5). The lock's rules left no knob for a C3 miss, and neither #569 candidate met the owner's bar, so the lane stopped. The #569 diagnosis also records that tool properties add noise but do not explain the V0 direction (INFERRED).

## 9. Not tried or not done

- **Knob 2** (`duskWardPer` 4 → 3). It applies only when attrition:fat is the only cell more than 10 pp off, which was not the case. The single retry was also already spent on knob 1.
- **No C3 or P9 loosening.** #569 describes three rules changes without recommending them: a minimum number of in-cell runs for representatives, end cells taken from wins, and holdout run on the CEM mean. None was adopted, and the thresholds are unchanged.
- **Candidates A and B were not implemented**, and no second exam was run.
- **The shatter bundle** (Cracked 2 → 1, probe F1c1) was priced and rejected in the lock. It drops V5 shatter:fat 12.7 pp behind the top.
- **Instrument and pilot grammar are unchanged.** No policy key was added. The pilot's card and relic scores ignore held relics, and `cardDecline` is one global threshold. #569 lists both only as noise sources, and neither was changed.
- **Out of scope for the lane:** Ashwarden balance (deferred), H10 (Dusk-only stun) and the H11 scope. H10 and H11 were untouched, and Ashwarden gets none of the Dusk clause. Knob 1's Rootheart 280 does apply to Ashwarden's act-1 boss (lock §4). Phase A Ash arm 1 fell from 76.0% to 70.0% at V0 and from 34.0% to 30.0% at V5 (§5 Phase A JSONs, run 1 → run 2). The lock's dev probe had priced Ash arm 1 V0 at 71.8% → 65.8%. It also reversed the recorded "do not raise enemy HP or facets" lesson, as an explicit owner call.
- **No independent re-run.** The rules require one only after an all-PASS result.
- **Layer 2 was not probed before the exam.** The lock marked C3 UNKNOWN; its probe notes marked C3 and C4 UNKNOWN.
- **Follow-ups left open on the branch:** the story canon-lint for the new copy was not run (the repo has no deterministic script), the long Tithes text, and Facet gauges still drawing for fork holders. #569 also marks the test and fixture impact of P1 as UNKNOWN.

## 10. References

| PR | Branch | Head (full SHA) | Base | Disposition |
|---|---|---|---|---|
| #567 design lock | `design/421-dusk-lane3` | `e7f42147cf5c2a8e282e2b0767ed35a4adf8799f` | `design/421-dusk-content-lane` | to be closed unmerged; branch kept |
| #568 implementation and exam 1 | `feat/421-dusk-lane3` | `3c5144e87882dd7290b9f132f810053c8aab36ee` | `design/421-dusk-lane3` | to be closed unmerged; branch kept |
| #569 C3 diagnosis revision 2 | `docs/421-c3-diagnosis` | `04fd5b85c7653736972761f575d5c7db32415fa3` | `feat/421-dusk-lane3` | to be closed unmerged; branch kept |
| #557 (parent) | `design/421-dusk-content-lane` | `567760f0104e46d400f18828978a3cb6271394d2` | `design/421-duskblade-breadth-retune` | unmerged draft |
| #556 (parent) | `design/421-duskblade-breadth-retune` | `e7a004d7122cf91c350aa0abc926965353017384` | `main` | unmerged draft |

- **Lane-3 commits:**
  - lock `2c2a274273842bcb26efbe0f8fd08b52afc6cc80`;
  - merge `e7f42147cf5c2a8e282e2b0767ed35a4adf8799f`;
  - content `85deaec3d75f89169d95b7937b586fef64a3c6fc`;
  - knob 1 `582e2f71a406910ef6c1d949ff9717f343539ffd`;
  - readout `3c5144e87882dd7290b9f132f810053c8aab36ee`;
  - diagnosis r1 `cc047065ea87c15bd8d9584992fcd65c220c2b1b`;
  - diagnosis r2 `04fd5b85c7653736972761f575d5c7db32415fa3`.
- **Content SHA-256:**
  - `main` `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1`;
  - #556 `8934031593228e450d3670d24da01aa4717480bd01ea4392e359d69a6f474248`;
  - #557 `a9ad6c558cf05c35e1d326f9a45540f5b7d245b85005a64cd7808f734ffc4440`;
  - `85deaec` `b459308717e98d2d14743d3f0a20ef9662cc183b7f1136f630776572d36a3daa`;
  - `582e2f7` `f0ecd890ca3144d8f2d6f3e2f2a934d7dc0ef44880d1902a4655752accc99436`.
- **Documents:**
  - [design lock](https://github.com/eugnel-ltd/glassvow/blob/e7f42147cf5c2a8e282e2b0767ed35a4adf8799f/docs/reviews/421/dusk-lane3-design-lock.md);
  - [probe notes](https://github.com/eugnel-ltd/glassvow/blob/e7f42147cf5c2a8e282e2b0767ed35a4adf8799f/docs/reviews/421/dusk-lane3-probe-notes.md);
  - [exam 1 readout](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/2026-09-28-421-dusk-lane3-exam.md);
  - [exam data](https://github.com/eugnel-ltd/glassvow/tree/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/data/421-lane3);
  - [C3 diagnosis](https://github.com/eugnel-ltd/glassvow/blob/04fd5b85c7653736972761f575d5c7db32415fa3/docs/reviews/421/dusk-lane3-c3-diagnosis.md);
  - [C3 probe data](https://github.com/eugnel-ltd/glassvow/blob/04fd5b85c7653736972761f575d5c7db32415fa3/docs/reviews/421/data/dusk-lane3-c3-probes.json).
- **Issue:** [#421 exam 1 readout comment](https://github.com/eugnel-ltd/glassvow/issues/421#issuecomment-5863378757) (2026-09-28).
- **Raw rows:** VM-local raw rows, not in Git: `/home/box/ops/glassvow/d568-exam1-582e2f7` on the Linux x86_64 evaluation VM (`layer1/`, `layer2/`, `phase-a/` and `phase-a.log`, about 4.6 GB (4.3 GiB)). Paths, sizes and SHA-256 are listed in the [raw-rows manifest](https://github.com/eugnel-ltd/glassvow/blob/3c5144e87882dd7290b9f132f810053c8aab36ee/docs/balance/data/421-lane3/raw-rows-manifest.json). The probe runners and probe rows were never committed. The lock's probe notes and #569 §6 are their only record.

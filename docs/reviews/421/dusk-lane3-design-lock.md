# Dusk lane 3 — design lock (#421, amended P9)

Owner: Ash (PM). Author: Claude (design only). Implementer: Codex. Base: `origin/design/421-dusk-content-lane` `e0388dfa` (draft #557), content `a9ad6c55…` (Unbroken Crown, Smolder 3).
Acceptance: amended P9 ([#108 comment 5850584190](https://github.com/fol2/glassvow/issues/108#issuecomment-5850584190), point 4 as amended in [#421 comment 5855915475](https://github.com/fol2/glassvow/issues/421#issuecomment-5855915475)). Prior lock: [`dusk-content-lane-design-lock.md`](dusk-content-lane-design-lock.md). Probe detail: [`dusk-lane3-probe-notes.md`](dusk-lane3-probe-notes.md).
Tags: VERIFIED = read in code or measured on exam-1 rows / probes; INFERRED = reasoned from verified data; UNKNOWN = needs a run. "Exam-1 rows" = the Dusk layer-1 rows listed in [`raw-rows-manifest.json`](../../balance/data/421-content-lane/raw-rows-manifest.json) and their controls.

## 1. Diagnosis

1. **Fat cells carry survivorship; mid cells hold act-2 deaths** (VERIFIED, exam-1 rows). A cell is a conditional rate on end-of-run deck size (`tools/balance_landscape.py:30`, `tools/balance_landscape.py:54`). At V0, 17,664 losers end with mid decks, 13,202 of them dying in act 2. At V5, shatter:mid is 990 wins against 8,704 losses. Overall win rate barely moves with draft pickiness (V0 38.9 % at `cardDecline` 0–8 against 34.2 % at 32–40; V5 12.4 against 12.2); lean drafters' wins simply land in mid. **A V5 third cell must be a fat cell** (INFERRED), so shatter:mid cannot close its gap at V5.
2. **attrition:fat is not a strategy yet** (VERIFIED). Against shatter:fat, non-crown attrition:fat runs hold Shatterer's Crown in 17 % of runs versus 47 %, Limit Break 0.34 copies versus 0.81, and Uppercut 0.75 versus 1.31. Their shatters/fight deciles are 0.64–0.95, just under the 0.963 median. These are shatter decks that missed their tools. At V5 they are about 2,200 losers, which a crown-strength fork would need about 11,000 fat holders to outweigh (INFERRED arithmetic).
3. **The shatter median is relative** (VERIFIED, `tools/balance_landscape.py:31`, `tools/balance_landscape.py:52`). A no-chip fork with high uptake lowers the median, which moves weak-shatter fat decks into shatter:fat and leaves attrition:fat to the fork's holders. A static replay of exam-1 rows with an existing boss relic as the fork predicts a median of about 0.85 and pollution cut to 1.4–1.9k runs at V0 (INFERRED).
4. **A second new fork would share the crown's pilot key** (VERIFIED). The pilot scores unnamed relics by rarity (`tools/balance_pilot.gd:428-432`), so the crown and any new boss relic both read `relicRarity.boss`. Existing boss relics have named weights (`tools/balance_policy.gd:52`, `tools/balance_policy.gd:113`). Crown of Tithes is held in 13.8 % of exam-1 Dusk runs.
5. **Random builds are thin and attack-heavy; the crown pays them for that** (VERIFIED, exam-1 controls, V0). Arm-2 decks have a median of 27.5 cards and are 55 % attacks, against 41 cards and 41 % for arm 1. Tuned decks stack Powers (War Cry 1.82 against 0.41 copies in runs reaching act 3). The crown pays per Attack with no deck condition. In the dev base, arm-2 holders win 57/87 against 114/249 for act-1 survivors without it, and removing the crown lowers dev arm 2 by 4.7 pp (V0) and 4.0 pp (V5). Tuned holders gained only +2.66 pp in the exam-1 dev gate.
6. **Max HP is not a C2 lever** (VERIFIED, paired probe). Dropping 72 → 68 HP cuts the dev V0 top by 4.6 pp but arm 2 by only 2.4, so the gap narrows. The #556 28 → 36 % arm-2 shift was mostly seed noise. Act-1 difficulty is lane-neutral because forks come after the act-1 boss: the Rootheart (`content/full-content.json:2467-2470`) kills 16 % of arm 2 against 6 % of arm 1 at V0. But raising its HP also taxes tuned play (§4).

## 2. Verdicts from probes

Development only: root 7421, policies 0–299 × seeds 12000–12015 × vows {0, 5}, arm 2 on 400–800 dev seeds, paired against `e0388dfa`. Full table and method: probe notes §1–§3.

| Variant | V0 three best cells | V0 arm 2 / gap | V5 three best cells | V5 arm 2 / gap |
|---|---|---|---|---|
| base `e0388dfa` | sh 72.0 · sm 65.1 · shM 43.1 | 43.4 / 28.7 | sh 57.9 · sm 47.6 · at 24.4 | 17.2 / 40.7 |
| tC: Tithes fork, flat 3 Ward + 1 Fervor per Attack | sh 68.5 · sm 63.9 · at 60.9 | 43.0 / **25.5** | 50.9 · 50.6 · 46.5 | 16.5 / 34.4 |
| nB: new relic, tB payoff (shares the crown's key) | sh 70.4 · sm 69.8 · at **45.4** | 36.5 / 33.9 | 57.0 · 53.1 · **33.2** | 16.0 / 41.0 |
| **F1: Tithes fork + crown fullness (this lock)** | **sm 70.7 · sh 68.4 · at 64.8** | **34.4 / 36.3** | **sm 56.5 · sh 51.5 · at 50.9** | **14.5 / 42.0** |
| F1, policies 300–599 (replicate) | sm 70.4 · sh 67.4 · at 61.8 | 34.4 / 36.1 | sm 54.9 · sh 50.8 · at 49.7 | 14.5 / 40.4 |
| K2: F1 + Rootheart 280 HP | sm 72.4 · sh 68.1 · at 64.4 | 30.4 / 42.0 | sm 60.6 · at 56.7 · sh 56.6 | 11.1 / 49.5 |
| F1c1: F1 + Cracked 2 → 1 | sm 70.1 · at 65.2 · sh 63.7 | 31.0 / 39.1 | sm 62.9 · at 56.5 · sh **50.2** | 11.5 / 51.4 |

- **Deck-scaled forks punish unfocused decks and spare focused ones** (VERIFIED, probe scale). Under F1, random-build Tithes holders win 80/203 (old Tithes: 126/202) and crown holders 86/177 (was 122/189). Tuned holders, paired over 600 policies: Tithes −1.0 / +0.7 pp, crown −1.2 / −0.2 pp. Arm 1 is unchanged (76.5 / 40.8), and layer-1 V0 win is 34.7 % against 35.1 %.
- **The third cell is a real lane** (VERIFIED, tB4 ≈ F1's Tithes). Tithes holders are 76 % of V0 attrition:fat (winning 76.5 %) and 75 % at V5 (65.3 %). Weak-shatter leftovers fall from 217 runs to 103.
- **A payoff with no deck condition** (tC) makes three cells but hands random builds the lane, so the gap fails. **A shared key** (nB) gets 623 holders against 962, and attrition:fat stalls. **Power-scaled payoffs** (probe tP1/tP2) are weaker. **HP** 68/64 moves the gap by −2.1 / −0.2. **Cracked 2 → 1** breaks V5 C1. **Rootheart facets 8** lifts the crown lane to 73.2 at V0 and leaves only two cells in band.

## 3. The change (Duskblade only; no signed rule touched)

**Why Crown of Tithes.** It has its own policy key (§1.4), shipped art (`assets/art/relics/crownOfTithes.png`) and zh name 什一之冠 ("a tenth"). Its current kindle behaviour stays for both aspects. The new clause applies only when `run.aspect == 0`, so Ashwarden play is unchanged.

**Content** (`content/full-content.json`):
- `relics.crownOfTithes` (`content/full-content.json:2056-2062`): add `"duskFervorPer": 10, "duskWardPer": 4`. `text`: "You may kindle twice each turn, and each kindling grants 3 Ward. Duskblade: your blows no longer chip Facets; begin each combat with 1 Fervor for every 10 cards in your deck, and at the start of each turn gain 1 Ward for every 4."
- `relics.unbrokenCrown` (`content/full-content.json:2077-2086`): `wardPerAttack` 3 → **2**, `smolderPerAttack` 3 → **2**, add `"fullDeck": 30, "fullPerAttack": 3`. `text`: "Your blows no longer chip Facets, and your Smolder takes hold. Whenever you play an Attack, gain 2 Ward and apply 2 Smolder to the enemy; 3 of each while your deck holds 30 or more cards."
- No pool, rarity, ID or save change. Relic count stays 32 and locale leaves stay 713.

**Locale.** `locale/en.json:2089-2092` and `locale/en.json:2193-2196` use the strings above. `locale/zh-Hant.json` (same lines):
- Tithes: 每回合可燃燼兩次；每次燃燼獲得 3 點護光。暮刃：你的攻擊不再琢擊璃面；每場戰鬥開始時，牌庫每有 10 張牌便獲得 1 層熾心；每回合開始時，每有 4 張牌便獲得 1 點護光。
- Crown: 你的攻擊不再琢擊璃面，你的陰燃得以燃起。每當你打出一張攻擊牌，獲得 2 點護光，並對該敵人施加 2 層陰燃；當你的牌庫有 30 張或以上時，兩者各為 3。

Terms follow shipped copy (熾心 Fervor, 護光 Ward, 暮刃, 牌庫, 琢擊/璃面). Every character already appears in `locale/zh-Hant.json` or `content/line-table.json` (VERIFIED). CI font coverage is the proof. Run the story canon-lint before merge.

**Code hooks** (`domain/rules/combat.gd` at `e0388dfa`; about 12 lines, all numbers read from content, no RNG draws):
1. `domain/rules/combat.gd:668` `apply_chips` and `domain/rules/combat.gd:1399` `preview_play`: extend the existing Dusk no-chip guard with `or run.has_relic("crownOfTithes")`. The aspect test before it keeps Ashwarden out.
2. `_apply_start_relics` (`domain/rules/combat.gd:273`), directly after the Crown of Cinders block (`domain/rules/combat.gd:289-292`): for a Dusk holder, `add_status_player(cb, "str", run.player.deck.size() / duskFervorPer)`.
3. `_start_player_turn`, directly after the Ward reset (`domain/rules/combat.gd:352-353`): for a Dusk holder, `gain_block_player(cb, run.player.deck.size() / duskWardPer, false, run)`.
4. Crown block (`domain/rules/combat.gd:828-840`): `n = fullPerAttack` when `run.player.deck.size() >= fullDeck`; otherwise Ward uses `wardPerAttack` and Smolder uses `smolderPerAttack`. The H11 lift (`domain/rules/combat.gd:409`) is unchanged.
5. Kindle limit and kindle Ward (`domain/rules/combat.gd:1166`, `domain/rules/combat.gd:1189-1191`), `domain/rules/rewards.gd` and every tool stay unchanged. **The instrument is unchanged**: no policy key is added, so `sample_range` draws and the driver SHA hold. The pilot scores the relic through its existing `relics.crownOfTithes` weight.

## 4. Owner calls

- **A — Rootheart HP 240 → 280 (knob 1 only; not in the first candidate).** This is an owner call for three reasons. The Rootheart is also Ashwarden's act-1 boss (Ashwarden is deferred). It taxes tuned play: arm 1 V0 goes from 76.5 to 69.2 % (Dusk) and from 71.8 to 65.8 % (Ash). And it reverses the recorded lesson "Do not raise enemy HP or facets this campaign" (`docs/balance/2026-08-19-iteration-protocol.md:109`). K2 shows the payoff: V0 gap 36.3 → 42.0 with both vows still 3 in band. **If declined:** there is no C2 knob, and F1 stands alone with a thin V0 margin (§5).
- **Not owner calls:** H10 (Dusk-only stun) and the H11 scope are untouched; Tithes applies no Smolder. The shatter bundle is not used. **For visibility:** this rewrites a shipped relic's Duskblade rules, and the only measured alternative (a new relic, nB) misses C1.

## 5. Success measure (amended P9, Duskblade only, vows {0, 5})

- **Pre-exam dev gate.** Rebuild the runner from probe notes §1 (untracked, dev seeds only). Settings: root 7421, policies 0–299, seeds 12000–12015, both vows; arm 2 on seeds 12100–12899 (800 per vow); cells as in notes §1.
  - PASS at **both** vows: at least 3 cells within 10 pp of the top; arm 2 < 50 % and top − arm 2 ≥ 35 pp; Tithes and crown holders' paired deficit against identical-seed `e0388dfa` twins ≥ −5 pp.
  - Expected result (the F1 probe; the hooks draw no RNG, so rows should reproduce exactly): V0 70.7 / 68.4 / 64.8, arm 2 34.4, gap 36.3; V5 56.5 / 51.5 / 50.9, arm 2 14.5, gap 42.0; paired Tithes +1.3 / +2.6, crown +0.1 / +1.0.
  - If the rows differ, find the implementation difference before going on.
- **Phase A**, as in #556: all four arm-2 rates < 50 %, plus **Dusk V0 ≤ 35.0 %** and **Dusk V5 ≤ 20.0 %**. Exam controls reproduce Phase A rows exactly (VERIFIED in exam 1), so this *is* the exam's arm 2. With dev tops of about 70.6 / 55.7, these ceilings keep C2's gap at 35 pp or more.
  - If Dusk V0 > 35.0 %, apply knob 1 (§8) before the exam. That spends the single retry; then rerun Phase A.
  - If call A was declined, run the exam anyway and record C2 V0 as the expected miss.
- **Exam**, the #556 procedure unchanged: `--stage=exam`; roots 215/216; ten 200-policy shards on seeds 3000–3039; controls on 4000–4199; 12 Dusk CEM islands (top six cells with at least 20 policies, best in-cell representative); train on 4200–4999; holdout on 5000–5199. All flags go after `--`.
- **Pass, per Dusk grid:** C1a ≥ 3 cells within 10 pp of the top · C1b ≥ 3 cells ≥ floor · C2 arm 2 < 50 % and gap ≥ 35 pp · C3 ≥ 3 islands stay in their start cell at or above the floor, all within 15 pp of the grid best · C4 end-cell ceiling gap < 15 pp · V5 best holdout < 90 %. Thresholds are unchanged and C1 stays at 3.
- **Expected triple** (INFERRED): the three fat cells, smolder:fat · shatter:fat · attrition:fat, at both vows.
- **Readout:** `docs/balance/<date>-421-dusk-lane3-exam.md` plus `docs/balance/data/421-lane3/`, in the #556 shape. The manifest records holder counts for both forks per grid.

## 6. Reproducibility

Owner ruling, 13:41 BST 2026-09-27 ([#421](https://github.com/fol2/glassvow/issues/421#issuecomment-5855915475)): an independent re-run from a clean checkout of the same SHA passes if every criterion (C1a, C1b, C2, C3, C4, V5 ceiling, at V0 and V5) gets the same PASS/MISS verdict, on any host. Numbers need not match. Record `uname -m` and the Godot build string in both manifests.

## 7. Codex handoff (ordered)

1. Record the owner's ruling on call A. Then `git fetch origin && git checkout -B feat/421-dusk-lane3 e0388dfae6f20ef2e2c4cf829b853ef58d14c067`.
2. Add the content, locale and hooks from §3. Do not include Rootheart unless §5/§8 trigger it.
3. Update the pins that change by design:
   - `tests/test_balance_catalogue.gd:4-5` `LIVE_FILE` / `LIVE_SEMANTIC`.
   - `tests/test_aspect_shatter.gd:153-159`: the 10-card test deck is below 30, so Emberbite gives 4 + 2 = 6 Smolder and the crown 2 Ward. Read the numbers from content.
   - `tests/test_balance_sim.gd:7` `EXPECTED`, only if the digest moves (record old → new in the commit body).
4. Add tests next to the crown cases. A Dusk Tithes holder: preview chips 0; no chip or stagger; Fervor = deck ÷ 10 at combat start; Ward = deck ÷ 4 after each turn's reset; still kindles twice for 3 Ward. An Ash Tithes holder gets none of the Dusk clause. The crown at 29 cards gives 2 + 2 and at 30 cards 3 + 3.
5. Run the core gate once on the final candidate (`godot --version`, `tools/check_imports.sh`, `tools/check_scripts.sh`, `godot --headless -s res://tests/run_all.gd`), plus `python3 tools/check_locale_coverage.py` and the `tools/ci_scope.py` selection. CI must be green, including font coverage.
6. Run the dev gate, then Phase A, then the exam (§5) on the Linux x86_64 VM, with at most 6 Godot processes under `nice -n 10`.
7. Open one draft PR with the readout. Merge only with green CI and P9 met. Guards only: no ledgers, custody or op IDs.

## 8. Risks and the one-retry knob order

- **C3 is UNKNOWN and is the largest risk.** Each lane now has its own CEM steer: shatter (`combat.chip`, `shatterDusk`), crown (`relicRarity.boss`), and Tithes (`relics.crownOfTithes` plus low `cardDecline`). An island's end cell is its modal holdout cell (`tools/balance_cem_report.py:33`), however. A boss offer shows 3 of the 6 Dusk boss relics (`domain/rules/rewards.gd:160-171`), so a fork island stays only if its fork is taken in most holdout runs. Exam 1's V0 crown island reached 92.5 %. The fullness rule should lower thin-deck crown ceilings (INFERRED).
- **Lane overlap.** About a quarter of fat Tithes holders take one Ashfall-omen Smolder kill and score as smolder:fat (probe: V0 128 runs, 83.6 % win). This helps C1 but can pull a Tithes island's modal cell (INFERRED).
- **Thin V0 C2 margin** without call A: dev gap 36.3, against a 200-seed arm-2 draw of ±6.6 pp (95 %). Phase A catches this before layer 1.
- **Mid cells stay out of band by construction** (§1.1). This is accepted: C1 needs only three cells.
- **UX.** The Tithes text is long. Facet gauges still draw for fork holders (follow-up, as in the prior lock).

**One retry**, in this order:
1. C2 V0 short (Phase A Dusk V0 > 35.0 %, or exam gap < 35 with C1 met): **Rootheart HP 240 → 280**, only if call A is approved. K2: V0 gap 42.0, V5 49.5, 3 + 3 in band.
2. attrition:fat is the only cell more than 10 pp off at either vow: **`duskWardPer` 4 → 3** (F2: V0 69.6, V5 58.4; paired +9.1 / +11.9; V0 arm 2 +2.6 pp, so recheck C2).
3. Any other C1 shape, or a C3/C4 miss: no knob; stop. The shatter bundle (Cracked 2 → 1) is priced and rejected: F1c1 drops V5 shatter:fat 12.7 pp behind the top.

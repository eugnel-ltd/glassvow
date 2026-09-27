# Dusk content lane — design lock (#421, amended P9)

Owner: Ash (PM). Author: Claude (design only). Implementer: Codex. Base: `origin/design/421-duskblade-breadth-retune` `e7a004d7` (#556), content SHA `8934031…` (72 HP, Refract 8/11, Emberheart 6).
Acceptance: amended P9, [#108 comment 5850584190](https://github.com/fol2/glassvow/issues/108#issuecomment-5850584190). Prior lock: [`duskblade-breadth-retune-design-lock.md`](duskblade-breadth-retune-design-lock.md). Probe detail: [`dusk-content-lane-probe-notes.md`](dusk-content-lane-probe-notes.md).
Tags: VERIFIED = read in code/data or measured here; INFERRED = reasoned from verified data; UNKNOWN = needs a run.

## 1. Diagnosis

The PM's root cause holds, with one correction (item 4).

1. **Every Dusk attack feeds shatter** (VERIFIED). After a card resolves, each connecting attack chips `1 + card.chip + Beacon` facets (`domain/rules/combat.gd:811-825`, `domain/rules/combat.gd:814`). Facets are 4/5/6 (`domain/rules/combat.gd:223`), and each shatter adds +1 (`domain/rules/combat.gd:686`).
2. **The shatter bundle has no substitute** (VERIFIED). A shatter skips the enemy's next turn and applies Cracked 2 and +2 Embers (`combat.gd:685-697`). The pilot scores a previewed shatter at `shatterDusk` 86 against `poisonDusk` 0.23 (`tools/balance_policy.gd:39-40`). H19 removed the implicit chip: shatter:fat fell 41 pp and attrition:fat fell 34 pp instead of rising (`docs/balance/2026-08-20-421-hypothesis-19.md:82`). Non-shatter cells have no payoff of their own.
3. **Dusk Smolder is blocked in code** (VERIFIED). `add_status_enemy` drops player-sourced enemy `poison` when `aspect == 0` on the live catalogue (`domain/rules/combat.gd:400-409`; relic gates `domain/rules/combat.gd:298`, `domain/rules/combat.gd:303`). This is the owner-signed H11 (`docs/balance/2026-08-19-iteration-protocol.md:126-131`).
4. **Correction.** Dusk "smolder" cells are omen noise, not Smoldering Coal (which is blocked at `domain/rules/combat.gd:298`). They come from the Ashfall omen's `enemyStartStatus` poison 2 (`domain/rules/combat.gd:208-212`), carried by `_jump_smolder`, which passes no `run` and so is never blocked (`domain/rules/combat.gd:718-728`). VERIFIED.
5. **Dead cards in the reward pool** (VERIFIED). Pools have no aspect filter (`domain/rules/rewards.gd:40-54`). Five of the 40 pool cards (Emberbite, Ashcloud, Requiem, Emberfang, Bellows) and Smolderphial are fully or partly inert for Dusk, yet **58 % of Dusk probe runs hold one**.
6. **The instrument is a median split** (VERIFIED, `tools/balance_landscape.py:51-54`). A run is "shatter" if its shatters/fight exceed the per-aspect median (1.0 on exam 2). Otherwise it is smolder if smolder kills exceed the median (0), else attrition. C1 therefore needs the low-shatter half to win about as often as the high half. **Any payoff that shatter decks can also use lifts the top too.** CEM clamps every weight to 0.25–4× (`tools/balance_cem.gd:60,157`). `_status_value` has no `thorns` case (`tools/balance_pilot.gd:301-324`).
7. **Exam-2 gaps** (VERIFIED, `docs/balance/data/421-retune/exam-2/layer1-analysis.json`). V0: top shatter:fat 72.9; shatter:mid −27.9; smolder:fat −31.2 (omen); attrition:fat −31.9. V5: top 58.5; attrition:fat −43.3; shatter:mid −44.6.

## 2. Unblock-first verdict, and what the probes measured

Probe setup: development only. Throwaway Dusk-only runner (no exam seeds, nothing committed except these notes); policy root 7421; seeds 12000–12015; 300 policies × 16 seeds per vow; arm 2 on 100 seeds (12100–12199). Axes are exam-2's (cuts 21/30, Dusk medians 1.0/0.0). All variants use the same policies and seeds, so comparisons are paired. The baseline reproduces exam 2 (top 73.2 / 58.8 against 72.9 / 58.5). Wall clock was about 17 min on ≤ 4 niced processes.

| Variant | V0 top | V0 best others (gap) | V5 top | V5 best others (gap) | in-10 (V0/V5) | arm 2 V0/V5 |
|---|---:|---|---:|---|---|---|
| A0 baseline `8934031…` | 73.2 | smolder:fat −13.9 (n 86) · shatter:mid −28.8 · attrition:fat −32.2 | 58.8 | smolder:fat −29.4 (n 34) · attrition:fat −30.4 | 1 / 1 | 40 / 4 |
| **U unblock** (`id` ≠ `core`) | **74.6** | smolder:fat −16.2 (n 303) · shatter:mid −26.6 | **63.2** | smolder:fat −30.1 (n 145) · attrition:fat −39.3 | 1 / 1 | **46 / 13** |
| S1 +Splinters power (3 thorns) | 71.5 | shatter:mid −24.0 · attrition:fat −29.2 | 54.8 | smolder:fat −18.0 (n 19) · shatter:mid −32.5 | 1 / 1 | 37 / 14 |
| S2 S1 + Ward/Splinters common | 71.8 | smolder:fat −21.8 (n 80) · shatter:mid −28.8 | 60.1 | smolder:fat −29.1 (n 29) · shatter:mid −38.2 | 1 / 1 | 37 / 16 |

Under H11, smolder cells are omen rows with under 400 runs, so they are noise (exam 2's V0 smolder:fat is 41.7 % on 860 runs).

**Verdict: unblocking alone is not enough (VERIFIED direction, probe scale).**
- It lifts the top as well (+1.4 / +4.4 pp), and no cell enters the 10 pp band.
- Arm 2 rises by 6 / 9 pp, consistent with undoing H11 (which cut arm 2 by −10.0 / −15.5 pp). Probe C2 gap at V0: 74.6 − 46 = 28.6 pp, below 35 pp, so **C2 would fail** (INFERRED; arm 2 was run on only 100 seeds).
- It also reverses a signed identity rule for every Dusk run.

The Splinters cards (data-only, H11 kept) also fail. They draw as generic powers, and they close gaps only by *lowering* the top (dilution).

**What a lane must be worth** (VERIFIED, paired on identical policy × vow × seed):
- *Live Smolder, chip kept:* across the whole population, unblocking adds +4.0 pp at V0 (35.3 → 39.3) and +2.6 pp at V5. Runs that end up holding ≥ 2 Smolder cards gain +10.1 / +7.9 pp over their blocked twins (n 1,557 / 1,575). That second figure conditions on a post-pick outcome, so it is an upper bound.
- *Switching off shatter:* in a throwaway boss relic "blows no longer chip; each Attack grants 3 Ward" (~75 policies, H11 kept), runs are identical until the act-1 boss offer, so the pairing is clean. Holders win 31.5 % against 49.1 % for their twins at V0 (−17.6 pp) and 19.1 % against 29.8 % at V5 (−10.7 pp). Fat holders reach 54.5 % (n 44) and 43.2 % (n 37), against tops of 68.8 / 52.1.

So the shatter bundle is worth roughly twice any single substitute tested. A second lane needs a **fork** (so the top can't absorb it) with a **stacked** payoff (Ward and Smolder).

## 3. The change: one boss relic, `unbrokenCrown`

The smallest addition that addresses all three root-cause points is a build-around crown. It stops the holder's blows from feeding shatter, gives a Ward-plus-Smolder substitute, and lifts H11 only for the run that opts in. Shatter decks can't take it without giving up stagger, and random arm-2 builds lose stagger when they take it.

**Art.** It needs `assets/art/relics/unbrokenCrown.png` under the relic art bible (`docs/art-ledger.md:21`). A missing file renders an empty icon (`presentation/reward/reward_screen.gd:516-524`), so art is not needed for the exam but is needed before release.

**Content** (`content/full-content.json`):
- `relics.unbrokenCrown = {"rarity": "boss", "aspect": "duskblade", "glyph": "⬡", "tone": "#ff9a4d", "name": "Unbroken Crown", "wardPerAttack": 3, "smolderPerAttack": 2, "text": "Your blows no longer chip Facets, and your Smolder takes hold. Whenever you play an Attack, gain 3 Ward and apply 2 Smolder to the enemy."}`
- Append `"unbrokenCrown"` to `relicPools.boss`. No `poolGate` entry: it is available from the first run.

**Locale.** `locale/en.json` `content.relics.unbrokenCrown` = {name, text} as above. `locale/zh-Hant.json`:
- `name`: 不碎之冠
- `text`: 你的攻擊不再琢擊璃面，你的陰燃得以燃起。每當你打出一張攻擊牌，獲得 3 點護光，並對該敵人施加 2 層陰燃。

The terms follow the shipped Chisel (琢擊/璃面), Emberfang (該敵人/陰燃) and Refract (護光) copy. Every zh character already appears in `locale/*.json` or `content/line-table.json` (VERIFIED), so the zh-Hant font subset should not need a rebuild. FontTools is not installed here, so CI's `check_locale_font_coverage.py` is the proof. Treat the copy as working copy and run the story canon-lint before merge. "Shard" is avoided because it means emberglass (`docs/story/06-glossary.md:12`).

**Code hooks** (about 10 lines; numbers are read from the relic, so later knobs are content-only):
1. `combat.gd:408-409` `_player_smolder_blocked`: return false for a holder. The relic gates at `domain/rules/combat.gd:298` and `domain/rules/combat.gd:303` follow automatically.
2. `combat.gd:667-669` `apply_chips`: return early for a holder. `combat.gd:1394-1395` preview: `chips = 0` for a holder, so the pilot and UI never promise a shatter.
3. `combat.gd:828-837` after an attack resolves: Smolder applied = `venomous + smolderPerAttack` (same targets as the venomous block), then `gain_block_player(cb, wardPerAttack, false, run)` and `_proc`.
4. `rewards.gd:57-71` `relic_pool`: skip a relic whose `aspect` differs from `content.aspects[run.aspect].id`. This is one filter in the shared function, so Ash (deferred) is never offered it.

**Instrument is unchanged.** The pilot scores the relic through `relicRarity.boss` (`tools/balance_pilot.gd:428-431`). No policy key is added, so `sample_range` draws are unchanged and the driver SHA holds.

**Owner call (the one escalation).** Hook 1 relaxes the signed H11 for opted-in runs only. James must accept that before implementation. If declined, the fallback drops hook 1 and sets `smolderPerAttack: 0, wardPerAttack: 5`. That keeps H11 but has lower confidence (Ward alone measured −17.6 pp at 3).

## 4. Success measure (amended P9, Duskblade only, vows {0, 5})

- **Pre-exam dev gate.** Rebuild the throwaway runner from notes §1 and run it with the crown on the same dev root and seeds. Holders' paired deficit against identical seeds and policies without the crown must be ≥ −5 pp at **both** vows. If not, apply knob 1 (§7) before exam 1; that uses the single retry.
- **Phase A**, as in #556: all four arm-2 rates < 50 %, and Dusk V0 < 45 %.
- **Exam**, the #556 procedure unchanged: `--stage=exam`; roots 215/216; ten 200-policy shards on seeds 3000–3039; controls on 4000–4199; 12 Dusk CEM islands (top-6 cells with ≥ 20 policies, best in-cell representative); train on 4200–4999; holdout on 5000–5199. All flags go after `--`.
- **Pass, per Dusk grid:**
  - C1a: ≥ 3 cells within 10 pp of the top.
  - C1b: ≥ 3 cells ≥ floor.
  - C2: arm 2 < 50 % and gap ≥ 35 pp.
  - C3: ≥ 3 islands stay in their start cell at or above the floor, all within 15 pp of the grid best.
  - C4: end-cell ceiling gap < 15 pp.
  - V5 best holdout < 90 %.
- **Expected triple** (INFERRED): shatter:fat plus the crown lane's smolder:fat plus smolder:mid or shatter:mid.
- **Readout:** `docs/balance/<date>-421-dusk-content-lane-exam.md` plus `docs/balance/data/421-content-lane/`, in the #556 shape. The manifest also records the holder count per grid.

## 5. Reproducibility rule

- **Same architecture is binding.** A fresh clone on an Apple-chip (arm64) Mac, with identical flags, must match to **0.0 pp on every layer-1 cell, arm-2 rate, island ceiling and end cell**. Any difference is a reproduction failure. Record `uname -m` and the Godot build string in both manifests.
- **x86_64 Linux is reported, not binding.** The sim is deterministic per architecture but differs between them. In both #556 exams exactly 3 layer-1 rows differed (policy 327, Dusk V0, seeds 3011/3013/3029), and CEM amplified that into island gaps of up to 9 pp. Report the x86_64 diff next to the verdict; it cannot flip it.

## 6. Codex handoff (ordered)

1. Wait for the owner's H11 opt-in ruling (§3). Then `git fetch origin && git checkout -B feat/421-dusk-content-lane origin/design/421-duskblade-breadth-retune`.
2. Add the content, locale and code hooks from §3.
3. Update the pins that break by design:
   - `tests/test_content.gd:51` relic count 31 → 32.
   - `tests/test_balance_sim.gd:7` `EXPECTED` digest (the boss-offer RNG changes; record old → new in the commit body).
   - `tests/test_balance_catalogue.gd:4-5` `LIVE_FILE` / `LIVE_SEMANTIC`.
4. Add tests next to the H11 cases in `tests/test_aspect_shatter.gd`. H11 cases stay green without the crown. With it, a holder's Emberbite applies Smolder, a holder's attack chips 0 facets and gains 3 Ward, and `relic_pool(ash run, "boss")` excludes the crown.
5. Core gate once on the final candidate:
   - `godot --version`
   - `tools/check_imports.sh`
   - `tools/check_scripts.sh`
   - `godot --headless -s res://tests/run_all.gd`
   - `python3 tools/check_locale_coverage.py`
   - the `tools/ci_scope.py` selection (balance_ml, locale_content)

   CI must be green, including font coverage.
6. Run the dev gate, then Phase A, then the exam (§4), then the arm64 re-run and the x86_64 report (§5). Use ≤ 6 niced processes on the owner's desktop.
7. Open one draft PR with the readout. Merge only with green CI and the P9 criteria met. Guards only: no ledgers, custody, locks or op IDs.

## 7. Risks and next-knob order

- **Magnitude is UNKNOWN.** The probes priced the parts, not the whole (Ward-3 switch −17.6 / −10.7 pp; live Smolder +4 pp overall, at most +10 pp for holders). The sum may still be negative; the dev gate catches that cheaply.
- **The third cell is the likeliest miss.** One lane adds smolder:fat and maybe smolder:mid. If only two cells are in band, stop: this lock has no knob for a third lane.
- **Pilot bias against the lane.** `poisonDusk` 0.22 (CEM cap 0.88) under-drafts the Smolder support cards, so any error biases toward MISS, not a false pass.
- **UX.** Facet gauges still draw for holders. Hiding them is a follow-up, not part of this change.

One exam retry, in this order:
1. Both vows lag on crown cells: `smolderPerAttack` 2 → 3.
2. Only V5 lags: `wardPerAttack` 3 → 4.
3. Arm 2 ≥ 45 % or C2 gap < 35 pp (not expected): `wardPerAttack` −1.

After that, stop. The remaining lever is the shatter bundle itself (Cracked 2 → 1 in `_shatter_enemy`), which is code and needs its own ruling.

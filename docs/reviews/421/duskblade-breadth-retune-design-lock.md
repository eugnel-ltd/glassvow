# Duskblade breadth retune — design lock (#421, amended P9)

Owner: Ash (PM). Author: Claude (design only). Implementer: Codex. Base: `origin/main` `07b5aa9dec8436132a524511d5438c510e322070`, live content SHA `a0d608a5…` (H39).
Acceptance: the amended P9 wording, [#108 comment 5850584190](https://github.com/fol2/glassvow/issues/108#issuecomment-5850584190). Lane authority: [#421 comment 5850584294](https://github.com/fol2/glassvow/issues/421#issuecomment-5850584294). Ruling: [#156 comment 5850571428](https://github.com/fol2/glassvow/issues/156#issuecomment-5850571428) Part B.
Tags: VERIFIED = read first-hand from repo or GitHub; INFERRED = reasoned from verified data; UNKNOWN = needs a run.

## 1. Diagnosis

**What the s009 exam measured** (VERIFIED, [#421/5409696582](https://github.com/fol2/glassvow/issues/421#issuecomment-5409696582), `docs/balance/data/421-s009/layer1-analysis.json`). Exam content = H39 plus the s009 numeric patch (Dusk 60 HP, Flare 10, Ashfall 4, Refract untouched). That patch is **not** on `main` (VERIFIED: `main` content SHA `a0d608a5…`, exam `5b3504f1…`, `tools/balance_s009_reconstruct.py`). The retune starts from H39 at 64 HP, not from the exam catalogue.

| Grid | shatter:fat | shatter:mid | attrition:fat | smolder:fat | floor | within 10 pp / viable | arm 2 / gap |
|---|---:|---:|---:|---:|---:|---|---|
| Dusk V0 | **78.58** | 47.25 (−31.3) | 46.53 (−32.1) | 50.00 (−28.6; 724 runs) | 51.79 | 1 / 1 | 25.0 / +53.6 |
| Dusk V5 | **69.46** | 17.74 (−51.7) | 24.31 (−45.2) | 22.29 (−47.2; 175 runs, invalid) | 38.73 | 1 / 1 | 8.0 / +61.5 |

Layer 2 (VERIFIED, same comment): Dusk V0 islands 2 stayed / 1 close; Dusk V5 0 / 0; Dusk V5 C4 gap 15.5 pp (shatter:fat 47.5 vs shatter:thin 32.0). Dusk V0 island 5 drifted shatter:thin → shatter:mid at **81.5 %** against shatter:fat 82.5 %: a mid deck sits within 1 pp of fat once the policy is optimised, so the layer-1 shatter:mid deficit is a sampled-policy effect, not a ceiling effect (INFERRED).

**Which strategy dominates, which lag, by how much.** Shatter-fat dominates both vows. At V0 the three nearest cells sit 29–32 pp behind and none clears the 51.8 % floor. At V5 every other cell is 45–52 pp behind. Dusk V0 history (top / attrition:fat / shatter:mid, VERIFIED from the dated hypothesis docs): 2026-08-19 pre-identity 82.8 / 66.7 / 65.5 (gap ≈16); H13 70.8 / 40.8 / 43.9 (≈30); H22 72.1 / 44.5 / 47.5 (≈27); H27 65.5 / 32.7 / 34.4 (≈32); s009 78.6 / 46.5 / 47.3 (≈32). The gap opened at the identity split plus cantrip costs (H10–H13) and has not moved since; every later Dusk change (H27 HP, H29 Eclipse cost, H30 Flare, s009) moved all cells together.

**Mechanical cause** (VERIFIED in code unless marked):
1. Every connecting Dusk attack chips one facet (`domain/rules/combat.gd:814`, `per = 1 + chip + beacon`); facets are 4 / 5 / 6 for normal / elite / boss (`combat.gd:223`). An ordinary attack deck shatters at least once per fight, and a shatter pays stagger (enemy turn skipped), Vulnerable 2 and 2 Embers (`combat.gd:685–697`). The attrition cell is by construction "Dusk decks that forgo the stagger", and Dusk has no substitute payoff: its aspect-bonus cards are all chip cards (`tools/balance_pilot.gd:296`); its only non-shatter assets are Flare (AoE damage) and Emberheart (heal 3 per combat).
2. Dusk cannot apply Smolder (`domain/rules/combat.gd:403` returns early when `_player_smolder_blocked`, defined at `domain/rules/combat.gd:408`, is true). Dusk "smolder" cells are incidental rows from enemy-own Smolder (Smoldering Coal), about 1.3 runs per policy (724 runs / 547 policies). Smolder is not a Dusk strategy, so the only reachable triple is **shatter:fat, shatter:mid, attrition:fat**.
3. Thickness: fat wins because every accepted reward card beats a starter and there is no thin/mid engine; the mid cell also collects act-2/3 deaths because the axis is final deck size (`tools/balance_landscape.py`). Cheaper removal is the one content lever that moves winning decks into the mid tertile while improving them (INFERRED; #491 measured a modest C1 gain).
4. V5 is a sustain problem. Top-decile auditor: `status.regen` 2.71× (V0) and 2.82× (V5), the largest shift on both grids (VERIFIED). Waning (rest 20 %), Malice (+1 per hit) and the start Hex punish the long fights that non-stagger decks play; Dusk has 64 max HP and a 3-HP per-combat heal.
5. Prior knob evidence: H43–H72 were Phase-A probes judged on the **Ash V0 arm-1** KEEP bar (VERIFIED, e.g. H61 line 11); they say nothing about Dusk cells. The #491 Tier-1 F0 screen (VERIFIED, `docs/balance/2026-08-26-491-tier1-f0.md`, `data/491/tidy.json`) is the only Dusk-cell evidence: Refract 8/11 (`t1-c012`) was "the cleanest single-package C1 move", Dusk V0 within-10 count 1 → 2 and Dusk V5 viable 1 → 2 at 128 policies × 8 seeds, identity clean; cheaper removal was a modest C1 gain; Hollow Crown energy 2 raised mid win rate 0.31 → 0.35. #492 raced these and promoted nothing (VERIFIED issue comments). Refract is the only measured single-knob mover.

## 2. Change set (all in `content/full-content.json`; locale mirrors in `locale/en.json`, `locale/zh-Hant.json`)

| # | Path | Old → new | Rationale | Lifts |
|---|---|---|---|---|
| 1 | `cards.deflect.effects[0].n`, `cards.deflect.up.effects[0].n`; `cards.deflect.text` / `up.text`; locale `content.cards.deflect.text` / `textUp` (`#8#`, `#11#`) | 6 → **8**, 9 → **11** | The one measured Dusk C1 mover (#491 `t1-c012`); Ward plus draw is the non-shatter substitute for the stagger's damage prevention | attrition:fat (V0, V5), shatter:mid |
| 2 | `relics.emberHeart.heal`; `relics.emberHeart.text`; locale `content.relics.emberHeart.text` ("heal 6 HP" / "回復 6 點生命") | 3 → **6** | Dusk-only, 100 % coverage, per-combat sustain that counters Waning and Malice; the engine fallback is already 6 (`combat.gd:504`) | attrition:fat and shatter:mid at V5 |
| 3 | `player.maxHp` and `aspects[0].maxHp` | 64 → **68** | H27 (−8 HP) moved attrition:fat −11.8 and shatter:mid −13.0 against top −6.5 at V0 (VERIFIED); half of it back is the strongest measured differential Dusk lever | all non-top Dusk cells at V0 |
| 4 | `shop.removeCost` | 75 → **55** | Registry `removalEconomy` high value; curated winners land in the mid tertile and get better while doing so | shatter:mid |

Nothing else. Not touched: Ash content (deferred by #108), vows, Eclipse Slash cost 2, Flare 9, identity gates in `combat.gd`, `tools/balance_pilot.gd` and `balance_policy.gd`, roots 215/216, `port_fixtures/` (goldens bind `port_fixtures/content/slice-content.json`, not the live catalogue; VERIFIED `content/content_db.gd:6`).

Arm-2 budget (INFERRED from H27's ≈1.1 pp per HP and the s009 arms): Dusk V0 arm 2 ≈25 → 35–40 %, Dusk V5 8 → 15 %. C2 keeps ≥ 35 pp of gap at both vows. The Phase A guard in §3 enforces the margin. Change 4 carries a save-compatibility gate (§5).

## 3. Success measure (amended P9, Duskblade only, vows {0, 5})

Instrument identity: Godot `4.7.2-stable (official)`; content SHA = `FileAccess.get_sha256("res://content/full-content.json")` on the retune commit; `--stage=exam` (roots 215/216; seeds 3000–3039, 4000–4199, 4200–4999, 5000–5199 per `docs/balance/421-content-search-seeds-v1.json`). Every flag goes after `--`.

1. Phase A (≈10 min): `python3 tools/balance_phase_a.py`. All four arm-2 cells < 50 %. Design margin: Dusk V0 arm 2 must be **< 45 %**; if not, revert change 3 to 64 HP and re-run Phase A before any exam.
2. Layer 1 (≈50–70 min on ten processes): ten shards `godot --headless -s res://tools/balance_sweep.gd -- --mode=sweep --stage=exam --rootSeed=215 --policyFirst=<k×200> --policyCount=200 --seeds=40 --seed0=3000 --out=DIR/shard-k.ndjson`; controls `--mode=controls --stage=exam --seeds=200 --seed0=4000 --out=DIR/controls.ndjson`; merge with the manifest line first; readout `python3 tools/balance_landscape.py DIR/merged.ndjson DIR/controls-analysis.json DIR/layer1-analysis.json`. Pass numbers per Dusk grid: `len(within10pp) ≥ 3`, `len(viableCells) ≥ 3` (floor = (arm 2 + top) / 2), `arm2Rate < 0.50`, `arm2Gap ≥ 0.35`.
3. Layer 2 (≈4 h): seed the 12 Dusk islands from layer 1 by the 2026-08-14 rule (top-6 cells with ≥ 20 policies per grid, representative = best in-cell policy; format = `docs/balance/data/421-s009/island-seeds.json`); `godot --headless -s res://tools/balance_cem.gd -- --island=N --stage=exam --seedsJson=DIR/island-seeds.json --samplerRoot=215 --rootSeed=216 --trainSeed0=4200 --holdoutSeed0=5000 --holdoutCount=200 --out=DIR/layer2/island-N.ndjson` for N in 0–11; readout `python3 tools/balance_cem_report.py DIR/layer2 DIR/layer1-analysis.json DIR/layer2-analysis.json`. Pass numbers per Dusk grid, holdout rows only: ≥ 3 islands stay in their start cell with holdout ≥ floor, every one of those within 15 pp of the grid's best holdout; best end-cell ceiling − second end-cell ceiling < 15 pp; Dusk V5 best holdout < 90 %.
4. Readout committed as `docs/balance/<date>-421-duskblade-retune-exam.md` plus `docs/balance/data/421-retune/` (layer1-analysis, layer2-analysis, controls, island-seeds, raw-rows manifest), same shape as the s009 packet.

## 4. Independent clean re-run

A second agent (any x86_64 or arm64 host, ordinary `timeout`, no sandbox) clones the retune commit, runs `tools/check_imports.sh`, then §3 steps 1–3 with identical flags into a fresh directory, and diffs the two `layer1-analysis.json` and `layer2-analysis.json` files.

Band: neither landscape doc states a seed-variance band (VERIFIED: grep of `2026-08-14-` and `2026-08-19-strategy-landscape.md`). The sim is seed-deterministic (`tests/test_balance_sim.gd` digest; #489 256-row hash identical on M1 Max and M4). The band for this lane is therefore: **same SHA + same seeds ⇒ 0.0 pp expected on every cell and ceiling**; a difference larger than the Wilson half-width (1.0 pp on any layer-1 cell with ≥ 4,000 runs, 5.0 pp on any n=200 holdout ceiling) is a reproduction failure, not variance. Codex records this sentence in the exam readout so the amendment's "band stated in the landscape doc" clause is satisfied by the retune's own landscape doc.

## 5. Implementation handoff (Codex)

1. Branch from `origin/main`; apply changes 1–4 to `content/full-content.json` and the two locale files. Only digits change, so the zh-Hant font subset gate is unaffected.
2. Update the pins that exist to catch exactly this: `tests/test_content.gd:57` expected Emberheart heal 3 → 6; `tests/test_locale_hydration.gd:113` and `tests/test_locale_hydration.gd:216` Emberheart strings; `tests/test_balance_sim.gd:7` `EXPECTED` seed-1000 digest (record old → new in the commit body); `tests/test_balance_catalogue.gd:4` `LIVE_FILE`; `H39_FILE_SHA` in `tools/balance_host_qualify.py:37` and `tools/balance_s009_reconstruct.py:28` (the reconstruct tool must still produce `5b3504f1…`; if it reads the live file, point it at the committed H39 bytes via `git show`, not at live content).
3. Align the readouts with the amended counts, pp thresholds unchanged: `tools/balance_landscape.py` `'C1b': len(viable) >= 3` (was 4); `tools/balance_cem_report.py:65` `len(stayed) >= 3` (was 4).
4. Save-compatibility gate for change 4: `domain/rules/rewards.gd:497` compares a stored shop stock's `removeCost` with content × discount. Add a test that loads a v2 save holding an open shop stock priced at 75 under the new content. If load validation rejects it, **drop change 4** (no migration) and say so in the PR.
5. Run the core gate once on the final candidate: `godot --version`, `tools/check_imports.sh`, `tools/check_scripts.sh`, `godot --headless -s res://tests/run_all.gd`, plus the `tools/ci_scope.py` selection for `balance_ml` and `locale_content`. Then Phase A (§3.1), the full exam (§3.2–3.4), and the independent re-run (§4).
6. Open one ordinary PR carrying the readout; CI green before merge. Guards only: no destructive host changes, no secrets in evidence. No ledgers, custody, locks, oracle qualification, op IDs or owner-approval ladders.

## 6. Risks and iteration plan

Magnitudes are UNKNOWN until the first exam; the V5 gaps (45–52 pp) are unlikely to close in one pass. Next knob order, one change per iteration, Phase A between each, and a mini-landscape (`tools/balance_f0.py`, frozen #215 axes, seeds ≥ 9000) before spending exam seeds:

- attrition:fat still > 10 pp behind at V0: `relics.gravebloom` heal 10 → 15 (fires only at ≤ 50 % HP, so it pays bleeding decks by construction), then `cards.brace` Ward 8 → 10.
- shatter:mid lagging: `cards.sidestep.cost` 1 → 0 (H13 revert; re-check arm 2), then Hollow Crown energy 2 / max-HP −18 (`bossEnergyRoute` high, mid win rate +4 pp in #491).
- all non-top V5 cells lagging together: Dusk max HP 68 → 72 (full H27 revert), then Emberheart 6 → 8.
- arm 2 crowding 50 % or C2 gap < 40 pp: pull change 3 first, change 2 second; changes 1 and 4 stay.
- layer 2 fails while layer 1 passes: read the drift map; islands seeded in attrition that drift to shatter mean the attrition *ceiling* is short, so take the Gravebloom / Held Light branch, not more sustain.
- last resort, code not content, needs its own ruling: reduce the shatter bundle (Vulnerable 2 → 1 in `combat.gd` `_shatter_enemy`) to lower the top. Not part of this lock.

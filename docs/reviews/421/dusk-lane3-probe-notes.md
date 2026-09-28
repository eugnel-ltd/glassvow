# Dusk lane 3 — probe notes (development only)

These are the evidence behind [`dusk-lane3-design-lock.md`](dusk-lane3-design-lock.md) §2. They are directional probes, not acceptance. No exam seeds (3000–5399) and no `--stage=exam` were used. Nothing here was committed as code or content. Host: Linux x86_64 VM, 8 vCPU, Godot `4.7.2.stable.official.ed1daf0bf`, 2026-09-28. Every Godot process ran at `nice -n 10`, at most 6 at once, about 52 minutes of wall clock in total.

## 1. Method

- **Runner.** The throwaway `tools/_probe421.gd` template from the previous lane, copied untracked into the worktree and deleted afterwards. Two flags were added for §3's cross-aspect check: `--aspect` (default `duskblade`) and `--build` (`1` = random build, the default; `0` = planned build, i.e. arm 1). Sweep rows keep `policyIndex`, `vow`, `seed`, `outcome`, `deck`, `fights`, `deckIds`, `relics`.
- **Base.** The candidate content at `e0388dfa` (`a9ad6c55…`). The recorded #557 dev-gate rows (`935fa5d4`, root 7421, policies 0–299, seeds 12000–12015) were reused as the paired base after a fresh 1,920-row shard reproduced them exactly with the probe hooks in place (checked in round 1 and again in round 3; every later hook is gated on its own relic field).
- **Scale.** Block 1 = policies 0–299 × 16 seeds × vows {0, 5} = 9,600 rows. Block 2 = policies 300–599, same seeds (F1 and base only). Arm 2 = random build + tuned play on seeds 12100–12499 (400 per vow), plus 12500–12899 for base, F1, K1, K2 and F1c1 (800 per vow).
- **Cells.** `tools/balance_landscape.py` lean order and tie rule; fixed deck cuts 21/30 (exam 1's); the run set's own Dusk shatter median (both vows), because moving that median is part of the mechanism. Only cells with at least 100 runs count. "Paired" = holders' win rate minus their identical policy × vow × seed twins on base.
- **Probe hooks** (uncommitted `domain/rules/combat.gd` edits, all read from relic fields so every variant is a content file; diff SHA-256 prefix `ceeaebeba3819df7`): a Dusk holder of any relic with `duskFork` skips `apply_chips` and preview chips; `forkStrPerDeck` adds `deck ÷ n` Fervor in `_apply_start_relics` (after Crown of Cinders); `forkWardPerDeckTurn` adds `deck ÷ n` Ward (no Poise) right after the start-of-turn Ward reset; `forkWardPerAttack` / `forkStrPerAttack` / `forkWardPerPower` / `forkStrPerPower` fire after a card resolves; the Unbroken Crown reads `perAttackDeckDiv` or `fullDeck`/`fullPerAttack`; `emberHeart.probeCracked` overrides the shatter Cracked stacks. `deck` is `run.player.deck.size()` (integer division). None of these hooks draws from an RNG.

## 2. Variants

All start from base. "Tithes fork" = `crownOfTithes` gains `duskFork` (its kindle-twice, 3 Ward per kindle stays for both aspects). "Crown fullness" = Unbroken Crown gives 2 Ward + 2 Smolder per Attack, 3 + 3 while the deck holds 30 or more cards. SHA-256 prefixes are of the variant files.

| Variant | Construction | SHA-256 (12) |
|---|---|---|
| hp68 / hp64 | Dusk `maxHp` 72 → 68 / 64 | `c3bc57fc8b6e` / `643298d2a21d` |
| rh280 / rh320 | Rootheart HP 240 → 280 / 320 | `c5c82bdc2100` / `b2167383283b` |
| nocrown | Unbroken Crown removed from the boss pool (arm 2 only) | — |
| tA / tB / tB4 | Tithes fork + Fervor per 10 cards; tB adds Ward per 5 cards per turn; tB4 Ward per 4 | `81ad5f757ee3` / `9ffc720e517b` / `da458df7d2e4` |
| tC | Tithes fork + 3 Ward and 1 Fervor per Attack (generic payoff) | `f29c45e8058c` |
| tP1 / tP2 | Tithes fork + per Power played: 1 Fervor 4 Ward / 2 Fervor 6 Ward | `27fdb84df69d` / `ccefb744eab5` |
| nB | New Dusk-only boss relic with tB's payoff (scored by `relicRarity.boss`, like the crown) | `730ec6b7bf7d` |
| tBcd / tB4cd11 | Crown gives `deck ÷ 10` / `deck ÷ 11` Ward and Smolder per Attack | `65cff9ff57e0` / `383bc3b97f20` |
| tBrh, tBrh3, tBcdrh, tB4rh3 | Combinations with Rootheart 280 / 300 | see readout |
| tB4rf8 | tB4 + Rootheart `facets` 8 (Dusk-only act-1 lever) | `b0a287086b70` |
| **F1** | **Tithes fork (Fervor per 10, Ward per 4 per turn) + crown fullness** | **`e1d62d4c3b67`** |
| F2 | F1 with Ward per 3 | `6029d3974450` |
| K1 | F1 with the fullness threshold at 32 | `6057f9660d9e` |
| K2 | F1 + Rootheart HP 280 | `30702821f324` |
| F1c1 | F1 + Cracked 2 → 1 on shatter | `bacfb9d15b1d` |

## 3. Readout (block 1 unless marked)

`in10` = cells within 10 pp of the top; gap = top − arm 2; paired = Tithes holders (crown holders for base-content variants; after Rootheart changes the pairing is survivor-biased, so treat it as a floor check only).

```
variant  | V0 top three            in10 arm2(n)   gap  pair | V5 top three            in10 arm2(n)   gap  pair
base     | sh 72.0 sm 65.1 shM 43.1  2  43.4(800) 28.7   -  | sh 57.9 sm 47.6 at 24.4   1  17.2(800) 40.7   -
hp68     | sh 67.4 sm 60.7 shM 39.0  2  40.2(400) 27.2 -1.4 | sh 57.8 sm 45.7 at 18.8   1  13.8(400) 44.0 -0.5
hp64     | sh 63.1 sm 58.7 shM 35.5  2  34.0(400) 29.1 -5.3 | sh 54.8 sm 43.1 shM 12.1  1  12.0(400) 42.8 -4.3
rh280    | sh 73.0 sm 65.3 shM 43.1  2  38.5(400) 34.5  bias| sh 62.7 sm 53.8 at 30.3   2  13.0(400) 49.7  bias
rh320    | sh 72.9 sm 63.0 shM 42.8  2  33.2(400) 39.7  bias| sh 63.5 sm 56.1 at 30.2   2  10.5(400) 53.0  bias
tA       | sh 66.5 sm 61.2 at 32.7   2  31.5(400) 35.0-30.9 | sh 49.1 sm 47.8 at 22.9   2  12.8(400) 36.4-24.6
tB       | sh 68.4 sm 66.2 at 60.8   3  35.5(400) 32.9 -4.3 | sm 52.7 sh 50.7 at 44.8   3  15.0(400) 37.7 -3.8
tC       | sh 68.5 sm 63.9 at 60.9   3  43.0(400) 25.5 +5.1 | sh 50.9 sm 50.6 at 46.5   3  16.5(400) 34.4 +1.6
tP1      | sh 67.3 sm 64.9 at 46.1   2  31.5(400) 35.8-17.5 | sm 50.4 sh 50.3 at 34.7   2  13.5(400) 36.9-12.6
tP2      | sh 68.0 sm 64.9 at 55.2   2  33.2(400) 34.7 -5.8 | sh 50.6 sm 50.4 at 43.2   3  14.5(400) 36.1 -2.6
nB       | sh 70.4 sm 69.8 at 45.4   2  36.5(400) 33.9 -3.5 | sh 57.0 sm 53.1 at 33.2   2  16.0(400) 41.0 -3.3
tB4      | sh 68.6 sm 67.8 at 65.0   3  36.5(400) 32.1 +1.5 | sm 54.3 sh 51.1 at 50.6   3  15.8(400) 38.5 +3.0
tBcd     | sm 70.4 sh 68.2 at 60.3   2  31.5(400) 38.9 -4.1 | sm 57.8 sh 51.3 at 45.3   2  14.0(400) 43.8 -4.7
tBrh3    | sm 67.3 sh 66.2 at 61.0   3  30.5(400) 36.8  bias| sm 57.4 sh 56.0 at 52.2   3   9.8(400) 47.6  bias
tB4rh3   | sm 68.3 sh 66.5 at 65.2   3  32.0(400) 36.3  bias| sm 57.7 at 57.3 sh 56.6   3  10.5(400) 47.2  bias
tB4rf8   | sm 73.2 sh 63.9 at 61.2   2  34.0(400) 39.2  bias| sm 59.6 at 57.8 sh 54.9   3  13.8(400) 45.9  bias
tB4cd11  | sh 68.2 sm 67.3 at 64.5   3  30.2(400) 38.0 +1.3 | sm 60.8 sh 51.3 at 51.3   3  14.8(400) 46.0 +2.1
F1       | sm 70.7 sh 68.4 at 64.8   3  34.4(800) 36.3 +1.3 | sm 56.5 sh 51.5 at 50.9   3  14.5(800) 42.0 +2.6
F1 blk2  | sm 70.4 sh 67.4 at 61.8   3  34.4(800) 36.1 -3.2 | sm 54.9 sh 50.8 at 49.7   3  14.5(800) 40.4 -1.6
F1 1+2   | sm 70.6 sh 67.9 at 63.3   3  34.4(800) 36.2 -1.0 | sm 55.7 sh 51.1 at 50.3   3  14.5(800) 41.2 +0.7
F2       | sm 71.0 at 69.6 sh 68.7   3  37.0(400) 34.0 +9.1 | sm 58.8 at 58.4 sh 51.9   3  14.5(400) 44.3+11.9
K1       | sm 70.0 sh 68.3 at 64.4   3  33.6(800) 36.4 +1.2 | sm 57.8 sh 51.5 at 50.7   3  14.2(800) 43.5 +2.7
K2       | sm 72.4 sh 68.1 at 64.4   3  30.4(800) 42.0  bias| sm 60.6 at 56.7 sh 56.6   3  11.1(800) 49.5  bias
F1c1     | sm 70.1 at 65.2 sh 63.7   3  31.0(800) 39.1 +2.8 | sm 62.9 at 56.5 sh 50.2   2  11.5(800) 51.4 +7.5
```

Supporting reads:
- **Crown value to random builds.** Base arm-2 crown holders win 57/87 at V0, against 114/249 for runs that clear act 1 without it; `nocrown` arm 2 is 38.0 / 12.5 against 42.7 / 16.5 on the same 400 seeds.
- **Random builds versus the forks** (F1, 800 seeds). Tithes holders win 80/203 (old Tithes on base: 126/202); crown holders 86/177 (base 122/189). Tuned holders, paired on 600 policies: Tithes −1.0 / +0.7 pp, crown −1.2 / −0.2 pp at V0 / V5.
- **Who fills attrition:fat** (tB4, block 1). V0: 378 of 497 runs hold the Tithes fork and win 76.5 %; the weak-shatter remainder drops from 217 runs at 33.6 % (base) to 103 at 25.2 %. V5: 251 of 336, winning 65.3 %. About a quarter of fat Tithes holders take one Ashfall-omen Smolder kill and land in smolder:fat instead (V0 128 runs, 83.6 % win).
- **Tuned play (arm 1, 400 seeds).** Dusk base 76.5 / 40.8; F1 76.5 / 40.8 (the default policy never takes either fork); K2 69.2 / 34.0. Ashwarden arm 1 base 71.8 / 33.0 → K2 65.8 / 30.8; Ashwarden arm 2 24.5 / 4.5 → K2 18.5 / 5.2.
- **Layer-1 win rate** (all 300 policies, V0). Base 35.1, F1 34.7, K2 30.8, F1c1 31.1.

## 4. Caveats

- 16 seeds per policy against the exam's 40, and 300–600 policies against 2,000. Cell rates here carry about ±3–4 pp (95 %) at 400–1,000 runs; differences under that are noise. The two F1 blocks differ by up to 1.5 pp per cell.
- Arm 2 on 400 seeds has a 95 % half-width of about ±4.6 pp at V0 and ±2.4 pp on 800. The exam's arm 2 is one fixed 200-seed draw (seeds 4000–4199) with its own ±6.6 pp half-width, so the V0 C2 margin must be read against that (lock §5).
- The deck cuts are fixed at exam 1's 21/30; the exam refits them on all 320k rows including Ashwarden. Ashwarden rows are unchanged by F1, so the shift should be small.
- Layer 2 (CEM) was not probed; C3 and C4 are UNKNOWN.

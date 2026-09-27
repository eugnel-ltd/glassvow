# Dusk content lane — probe notes (development only)

These are the evidence behind [`dusk-content-lane-design-lock.md`](dusk-content-lane-design-lock.md) §2. They are directional probes, not acceptance. No exam seeds (3000–5399) or contract stages were used. Nothing here was committed as code or content. Host: Apple arm64, Godot `4.7.2.stable.official.ed1daf0bf`, 2026-09-27, all processes `nice -n 10`, ≤ 4 at once.

## 1. Method

The runner was a throwaway `tools/_probe421.gd`, deleted after use. Per policy it calls `BalanceSim.simulate(content, "duskblade", seed, vow, [], policy)` for vows 0 and 5. Policies come from `BalancePolicy.sample_range(7421, first, count)`. Each row keeps the `balance_sweep.gd` fields: `policyIndex`, `vow`, `seed`, `outcome`, `deck`, `fights`, `deckIds`, `relics`. `--mode=controls` runs arm 2 (`random_build=true, random_play=false`).

```
godot --headless -s res://tools/_probe421.gd -- --mode=sweep --content=<variant.json> --root=7421 --first=<0|150> --count=150 --seeds=16 --seed0=12000 --out=<v>-<a|b>.ndjson
godot --headless -s res://tools/_probe421.gd -- --mode=controls --content=<variant.json> --seeds=100 --seed0=12100 --out=<v>-ctl.ndjson
```

Cells use exam-2 axes (deck cuts 21/30, Dusk medians 1.0 shatters and 0.0 smolder kills per fight) with the `balance_landscape.py` lean and tie order. The runs' own Dusk medians came out at 1.00–1.04 and 0.00, so the axes hold.

| Variant | Construction from `content/full-content.json` @ `e7a004d7` | SHA-256 (16) |
|---|---|---|
| base | unchanged | `8934031593228e45` |
| unblock | `id: "core"` → `"probe"`; the only effect is `_player_smolder_blocked` (`combat.gd:409`) | `6f464f375365b7fc` |
| candA | + `splinterglass` uncommon power, cost 1: `thorns` 3 (up 4); appended to `cardPools.uncommon` | `6155fbd6db94cbbd` |
| candB | candA + `shardguard` common skill, cost 1: Ward 7 + `thorns` 2 (up 9 / 3); appended to `cardPools.common` | `4fde0426c108d896` |
| relic | + `probeCrown` boss relic in `relicPools.boss`, plus 3 uncommitted `combat.gd` hooks: `apply_chips` no-op and preview `chips = 0` for holders, and `gain_block_player(cb, 3)` after each holder Attack. H11 kept | `97a2faa143237cd5` |

Scale: 300 policies × 16 seeds × 2 vows = 9,600 rows per variant. The relic variant was stopped at about 75 policies (2,376 rows) to hold the compute budget; its arm 2 was not run. Wall clock was about 17 min in total.

## 2. Readouts

Cells are win rate (runs, policies). `floor` = (arm 2 + top) / 2. Arm 2 is on 100 seeds per vow.

```
base     arm2 V0 .40 V5 .04 | V0 win .353, 58.4% of runs hold a Smolder card
  V0 top shatter:fat .732 floor .566 in10 1 viable 2 | smolder:fat .593(86,66) shatter:mid .444(753,241) attrition:fat .410(432,179)
  V5 top shatter:fat .588 floor .314 in10 1 viable 1 | smolder:fat .294(34,33) attrition:fat .284(232,149) shatter:mid .218(574,240)
unblock  arm2 V0 .46 V5 .13 | V0 win .393, runs with a smolder kill 16.3% → 39.4%
  V0 top shatter:fat .746 floor .603 in10 1 viable 1 | smolder:fat .584(303,149) shatter:mid .480(771,230) attrition:fat .440(334,164)
  V5 top shatter:fat .632 floor .381 in10 1 viable 1 | smolder:fat .331(145,104) attrition:fat .239(205,132) shatter:mid .235(597,243)
candA    arm2 V0 .37 V5 .14 | new card held in 23.6% / 17.7% of runs
  V0 top shatter:fat .715 floor .543 in10 1 viable 1 | shatter:mid .475(745,230) attrition:fat .424(458,178) smolder:fat .325(83,71)
  V5 top shatter:fat .548 floor .344 in10 1 viable 2 | smolder:fat .368(19,18) shatter:mid .223(551,230) attrition:fat .214(276,158)
candB    arm2 V0 .37 V5 .16 | new cards held in 33.9% / 24.5% of runs
  V0 top shatter:fat .718 floor .544 in10 1 viable 1 | smolder:fat .500(80,67) shatter:mid .430(752,232) attrition:fat .376(402,171)
  V5 top shatter:fat .601 floor .380 in10 1 viable 1 | smolder:fat .310(29,29) shatter:mid .219(570,236) attrition:fat .210(248,148)
relic (~75 policies; holders paired with identical policy/vow/seed in base)
  V0 holders 165 (13.7%) win .315 vs twins .491 | holder fat .545(44) | top shatter:fat .688(282)
  V5 holders  94 ( 8.0%) win .191 vs twins .298 | holder fat .432(37) | top shatter:fat .521(165)
paired unblock − base (same policy/vow/seed; "hold" = held at run end, so an upper bound)
  V0 hold Emberfang +.065 (1393) | hold ≥2 Smolder cards +.101 (1557) | any smolder kill +.084 (1889)
  V5 hold Emberfang +.053 (1727) | hold ≥2 Smolder cards +.079 (1575) | any smolder kill +.066 (1383)
```

## 3. Caveats

- 16 seeds per policy against the exam's 40, and 300 policies against 2,000. Differences under about 3 pp between cells are noise at this scale.
- Arm 2 on 100 seeds has a 95 % half-width of about ±10 pp at V0. The C2 reading under unblock (§2 of the lock) is therefore INFERRED, although it agrees in direction with the recorded H11 effect (−10.0 pp).
- Why Ward is in the payoff: in base fat decks, non-shatter winners over losers most often held Ward, tempo and heal relics. At V0: hollowCrown .57/.26, duskmirror .37/.08, silkFan .50/.29. At V5: duskmirror .79/.27, crownOfTithes .47/.22, sunBlossom .43/.18. This is a correlational readout from `deckIds`/`relics`.

# STREAM A design verdict v1 — grammar-only second Dusk destination

**Verdict: FAIL CLOSED. No card/lock pair exists.**
No lock JSON is written. No card JSON is written. No Phase A is authorised or requested by this file.

Design-only. Zero Godot processes, zero simulator rows, zero seed identities, zero candidate files,
zero product mutations, zero RNG draws were created to produce this verdict.

## 1. Question as frozen by Ash

Can **any** new Duskblade card or pair of cards, expressed **only** in the existing card-effect
grammar, create a **second reachable Dusk destination that is not shatter-fat**?

Binding boundary (Ash, 2026-08-31):

- no new effect primitive, no new `special` id, no new `can_play` branch, no new status, no new
  resource, no engine change of any kind;
- ordinary `{"kind":"block","n":N}` Ward is allowed;
- Stun stays bundled inside `_shatter_enemy`;
- Emberglass, Kindle/Branch and the EP4 `ward-mirror-edge` package are not reopened;
- EP4 Ash controls (`hand-size-payoff`, `ash-poison-catalyst`) are retained;
- existing `direct-shatter` remains the Dusk comparator;
- H10 and H11 stay.
- Not authorised for STREAM A (already fail-closed by Claude): spend-Ward, facet-intact `can_play`,
  Stun outside `_shatter_enemy`.

## 2. Immutable inputs and identities

| Input | Identity |
|---|---|
| worktree head (== `origin/main` at freeze) | `c28ae38824f7ba2168b573002ab8b90dadd5bde1` |
| `content/full-content.json` | SHA-256 `a0d608a5142d2e3aab799cdf33d3163922b402c2aaf2a895e46e096399b56cf1` |
| `domain/rules/combat.gd` | SHA-256 `3adb0e063a536bf249d3b5d9524427facf1398304206da59d97594d3fff246e8` |
| `domain/rules/rewards.gd` | SHA-256 `fe69d19ecf6448aad71b466d9beee1716e1957fe277a62c5bacf8daba3c7ac83` |
| `tools/balance_pilot.gd` | SHA-256 `4ff5934fc03af84e9d0c8fb285a91c6b7d5dfcab180b88825b1e75bb47ea6c47` |
| `tools/balance_policy.gd` (pilot `p8-d0-v1`) | SHA-256 `8eeeb1d3289bbab7fb033e6f175b9d2adcbb2944292c097ad09f79419e162026` |
| `tools/balance_sim.gd` | SHA-256 `b169e2588e2ea65b75b94ee94b8e129c2c3ac8a0d5f7076224521a204623cd06` |
| EP4 published evidence head | `9e9409bf` on `research/issue-421-ep4-existing-packages-v1` |
| EP4 Phase A result | SHA-256 `86f2bfbfda0ad44721341b45e532c2f4ce8b6d7726cc3abc63855869e9bcba7a` |
| EP4 composite content | SHA-256 `ecbe896a96b8d93c2701c4fac872e1066df54a2c1274d3527e0f1b86ebdee3cb` |

The three identities that matter to this question — `content/full-content.json`,
`domain/rules/combat.gd`, `tools/balance_pilot.gd`, `tools/balance_policy.gd` — are **byte-identical**
to the identities EP4 froze in `research/issue-421-ep4/protocols/preregistration-v1.json`. The single
`tools/balance_sim.gd` difference is exactly EP4's observation-only readout injection
(`_harvest_fight` + one preload); nothing else differs. EP4's measurements therefore apply to this
source without re-derivation.

## 3. Method

Three zero-row instruments only:

1. **Complete source read** of the card-effect grammar and its aspect couplings
   (`domain/rules/combat.gd`, `domain/rules/rewards.gd`, `content/content_db.gd`).
2. **Immutable EP4 measurements** re-read from the published evidence head, not re-run.
3. **Deterministic policy arithmetic**: a faithful re-implementation of the frozen `p8-d0-v1`
   `card_score` (`tools/balance_pilot.gd:274-341`) in
   `research/issue-421-grammar-only/work/card_score_check.py`
   (SHA-256 `e31e5d57528f2103de9ff4cef4e7f8d214ede3552d12bbe73ff629a7a250f368`,
   self-check `PASS (3 checks)`). Its outputs are **acquisition arithmetic, not simulated outcomes**,
   and are labelled as such below.

## 4. The complete grammar (measured)

Card fields honoured by the engine: `type` ∈ {`attack`,`skill`,`power`,`curse`,`status`}, `cost`,
`target` ∈ {`self`,`enemy`,`allEnemies`}, `chip`, `exhaust`, `unplayable`, `endTurnDmg`,
`endTurnLoseHp`, `up`.

Effect kinds (`combat.gd:861-947`): `dmg(n,times)`, `block(n)`, `draw(n)`, `energy(n)`, `heal(n)`,
`loseHp(n)`, `status(id,n,who)`, `addCard(id,n,where)`, `chip(n)`, `ember(n)`, `special(id,…)`.

Special ids (`combat.gd:949-1010`): `leech`, `execute`, `momentum`, `doubleBlock`, `phantom`,
`devour`, `catalyst`, `shatterEcho`, `emberNova`, `pyreTithe`, `flawless`, `emberdance`.

Statuses (`full-content.json`): `str`, `dex`, `vulnerable`, `weak`, `frail`, `poison`, `thorns`,
`ritual`, `metallicize`, `regen`, `barricade`, `energized`, `venomous`, `rampage`, `beacon`,
`emberflow`, `nightsight`.

This is the entire expressible space. Nothing outside it is reachable without an engine change.

## 5. Structural findings

### F1 — Every Dusk-exclusive payoff is bundled to attack-typed damage (measured)

`apply_chips` returns immediately when `run.aspect != 0` (`combat.gd:667-668`): chip, shatter,
stagger, the shatter `vulnerable 2` and the shatter `+2 embers` are Dusk-exclusive.

Implicit chip is computed **only for `type == "attack"`**: `per = 1 + card.chip + beacon`
(`combat.gd:814`, mirrored in `preview_play` at `combat.gd:1392`). A landing attack always chips at
least 1 (`hit_enemy` sets the per-card hit flag at `combat.gd:579-582`).

Consequence: any Dusk damage on an attack feeds shatter; any Dusk damage **not** on an attack forfeits
the aspect's entire exclusive payoff. There is no third position in the grammar.

### F2 — Ward has no sink (measured, exhaustive)

`cb.player.block` is read at exactly five sites in the whole engine:
`combat.gd:353` (turn-start clear unless `barricade`), `:460-461` (damage absorption),
`:645-646` (gain), `:972` (`doubleBlock`, Ward → Ward), `:1359` (the `doubleBlock` preview mirror).

No effect, special, art or potion converts Ward into damage, chips, energy, cards, embers or any other
progress. **A Ward destination has no terminal in the existing grammar.** This is the exact gap
STREAM B is asked to specify; it cannot be closed by cards.

### F3 — Dusk's ember income is shatter-funded, and the only ember cash-out is capped (measured)

`_shatter_enemy` grants `+2` embers per shatter (`combat.gd:685-714`); `cb.ember_cap` is 9
(`combat_state.gd:20`, 12 with one relic, `combat.gd:290`). The only ember → damage special is
`emberNova` (`combat.gd:990`, damage `n × cb.embers`), ceiling `n × 9`. For Duskblade the dominant
ember source is shatter itself. An ember cash-out destination for Dusk is therefore funded by the
comparator it is supposed to be separate from: shatter-fat by construction.

### F4 — In the frozen policy, a card can be Dusk-preferential only by being chip- or shatter-coupled (measured)

`card_score` (`balance_pilot.gd:274-341`) differentiates the aspects at exactly these handles:
`chipDusk/chipAsh`, `poisonDusk/poisonAsh`, `vulnerableDusk/vulnerableAsh`, `venomousDusk/venomousAsh`,
`beaconDusk/beaconAsh`, `catalystDusk/catalystAsh`, `shatterEchoDusk/shatterEchoAsh`, and two
hard-coded card-id lists (`aspectBonus`).

Of these, `chip`, `beacon`, `vulnerable` and `shatterEcho` are shatter machinery; `poison`, `venomous`
and `catalyst` are the Ash identity that H11 protects. The `aspectBonus` lists are card ids in the
pilot, i.e. a policy edit, not grammar.

The arithmetic confirms it. Every STREAM A candidate shape scores **identically** for both aspects:

| Candidate shape (existing grammar only) | Dusk score | Ash score |
|---|---|---|
| A1 chip-free burst — `skill`, `dmg 12`, cost 1, common | 15.59 | 15.59 |
| A2 lantern burst — `skill`, `special emberNova n=3`, cost 1, rare | 13.67 | 13.67 |
| A3 reflect — `power`, `status self thorns 4`, cost 1, uncommon | 10.41 | 10.41 |
| A4 Ward pile — `skill`, `block 14`, cost 1, uncommon | 15.71 | 15.71 |
| A5 Ward + draw — `skill`, `block 8` + `draw 1`, cost 1, common | 20.41 | 20.41 |
| EP4 `mirrorEdge` (measured 1/200 Dusk activation) | 18.92 | 18.92 |

Card pools are aspect-blind: `RewardRules.card_pool` (`rewards.gd:40-56`) is a tier list plus
`run.unlocks`, with no aspect filter, and the balance profile grants only `["aspect2"]`
(`balance_sim.gd:78`) — so deed-locked cards are invisible to the simulator and **any new card must
enter a base `cardPools` tier, where Ashwarden sees it too**.

Consequence: a grammar-only card cannot be Dusk-scoped. It lands on both aspects with equal
acquisition value while being *worth less* to Dusk than an attack-typed twin (F1). It pushes on the
frozen `ashLead ∈ [0, 0.20]` and aspect-identity gates in the wrong direction.

### F5 — The frozen competent-play cohort cannot exploit a non-shatter Dusk line (measured weights)

Reachability is defined on **arm 1 only** (`preregistration-v1.json .readouts.reachabilityCohort`),
i.e. the frozen `p8-d0-v1` pilot. That pilot:

- adds `shatterDusk = 86.15` to any play whose preview reports `willShatter`
  (`balance_pilot.gd:163-164`, weight `balance_policy.gd:39`), against `lethal = 271.86` and raw card
  value in the 10–25 range (§4 table);
- **targets shatter first** for Dusk: `_target` scans living enemies for `willShatter`
  (`balance_pilot.gd:214-218`);
- previews damage only for `dmg`, `execute`, `momentum`, `doubleBlock` (`combat.gd:1343-1359`), so
  damage from `phantom`, `emberNova`, `leech`, `shatterEcho` and `devour` is invisible to the pilot's
  `loss`/`lethal` terms;
- values `thorns` at literal `0.0` (`balance_pilot.gd:301-325` (fall-through `return 0.0`), no `thorns` arm) and has no term at all
  for Ward spending, reflect damage or a chip-free burst.

A new destination therefore has no policy handle by which a competent build can prefer it, and no
play-time handle by which competent play can order it ahead of a shatter. That is not a tuning
opinion; it is the arithmetic of the frozen weights.

### F6 — The one prior grammar-only attempt is measured, and it failed on exactly this (measured)

EP4's `ward-mirror-edge` was a grammar-only package of the shape STREAM A asks about: one new card
`mirrorEdge` (`attack`, `dmg 6` + `block 11`, common, cost 1) plus three value moves
(`brace` 8→10, `bulwark` cost 2→1 and 13→20, `fortify` cost 2→1).

Measured on 200 frozen arm-1 runs per cell
(`research/issue-421-ep4/artifacts/phase-a-result-v1.json`):

| Cell | Destination | Activated runs | Probability | CP lower 95% | Floor |
|---|---|---|---|---|---|
| Dusk V0 | `directShatter` | 200/200 | 1.000 | 0.9817 | pass |
| Dusk V0 | `wardMirrorEdge` | 1/200 | 0.005 | 0.000127 | **fail (0.05)** |
| Dusk V5 | `directShatter` | 200/200 | 1.000 | 0.9817 | pass |
| Dusk V5 | `wardMirrorEdge` | 0/200 | 0.000 | 0.000 | **fail (0.05)** |
| Ash V0 | `handSizePayoff` / `ashPoisonCatalyst` | 26 / 151 | 0.130 / 0.755 | 0.0867 / 0.6894 | pass |
| Ash V5 | `handSizePayoff` / `ashPoisonCatalyst` | 33 / 129 | 0.165 / 0.645 | 0.1164 / 0.5744 | pass |

`directShatter` activates in **every** Dusk run at both vows. `mirrorEdge` ranks above 30 of the 40
pool cards on frozen acquisition arithmetic (18.92, §4 table) yet its package activated once in 400
Dusk runs.

**Hypothesis, not a measured decomposition:** the binding constraint was play-time ordering and the
two-card same-turn conjunction the readout required, not acquisition. Separating acquisition from play
would need rows and is not proposed here.

## 6. Candidate families examined, and the finding that closes each

| Family | Grammar-only expression | Closed by |
|---|---|---|
| Ward / defence pile | `block`, `doubleBlock`, `flawless`, `metallicize`, `dex`, `barricade` | **F2** — no Ward sink; the pile has no terminal and must still kill through attacks, i.e. through shatter |
| Chip-free burst | `skill` + `dmg` (escapes `per`, F1) | **F1 + F4** — strictly worse for Dusk than the attack twin; identical value to Ash on an aspect-blind pool |
| Lantern burst | `skill` + `special emberNova` | **F3** (shatter-funded, capped at `n×9`) + **F5** (unpreviewed → invisible to the pilot) |
| Reflect / attrition | `status self thorns` | **F4/F5** — aspect-neutral and valued `0.0` by the frozen policy; magnitude needed to be a route is a flat power increase landing harder on Ash (88 HP) |
| Vulnerable → execute amplification | `warCry`/`eclipseSlash` + `execute` | **F1** — every amplifier is attack-typed; the route is shatter's own tail, not a separate destination |
| Smolder / poison route | `status poison` | **H11** — player-origin enemy Smolder is Ash-only |
| Single-card destination | any card, readout defined as "played card X" | Inadmissible: no complementarity, so it cannot satisfy #421 package acceptance. Recorded and rejected, not tested |

## 7. Two findings that block *any* future Phase A, independent of this verdict

Both are recorded here as decision inputs for Ash. Neither is acted on.

### B1 — The frozen H11 observer fails on current-main content regardless of the candidate

H11 as frozen: *"player-origin enemy Smolder remains Ash-only; zero Dusk enemy Smolder applications
required across every Phase A row"* (`preregistration-v1.json .identity.H11`).

EP4 measured **2,419** Dusk enemy Smolder applications and vetoed
(`phase-a-result-v1.json .gates.identity`).

Current-main content puts `venomStrike` (Smolder 4), `toxicMist`, `annihilate` and the venom potion in
the **shared, aspect-blind** pools (§F4). Frozen acquisition arithmetic scores `venomStrike` at 11.63
for Dusk — mid-pool, above `twinFangs`, `tempest`, `brace` and `fortify` — so a Duskblade build buys
it whenever the offered three are weaker. `_jump_smolder` (`combat.gd:718-732`) then re-applies it.

**Therefore any Phase A that reuses the frozen H11 observer on current-main content will VETO on H11
again, whatever the candidate is.** Before another Phase A, exactly one of these must be chosen by
Ash: (a) restate H11 as a card-source-scoped observer (Smolder applied by a card the Dusk player
played), (b) restate H11 as a content invariant and remove Ash-identity Smolder cards from the shared
Dusk-visible pool, or (c) retire H11. This is a contradiction between a frozen identity gate and
shipped content, surfaced — not resolved.

### B2 — The EP4 readout definitions are asymmetric

`directShatter` activates on a **single** event (any shatter after any played attack);
`wardMirrorEdge` required a **two-card same-turn conjunction**
(`research/issue-421-ep4/tools/activation_readout.gd:36-42`). The comparator and the candidate were
not held to the same activation complexity. Any future destination comparison should freeze an
activation-complexity rule before rows.

## 8. Disposition

STREAM A is **FAIL CLOSED**. The causal chain is short and each link is measured on the frozen
identities:

1. Dusk's only exclusive mechanism is chip, and chip is bundled to attack-typed damage (F1).
2. Ward, the one Dusk-flavoured resource a defensive destination could accumulate, has no sink
   anywhere in the engine (F2).
3. The only non-shatter cash-out that does exist (embers → `emberNova`) is funded by shatter and
   capped (F3).
4. Consequently no card expressible in the grammar can be Dusk-preferential without being
   chip/shatter-coupled — proven by the frozen policy scoring every candidate identically for both
   aspects on an aspect-blind pool (F4).
5. And the arm-1 cohort that defines reachability has no acquisition or play handle for such a
   destination (F5), which is what the one prior attempt measured at 1/200 and 0/200 (F6).

No card JSON and no lock JSON are written. No Phase A is proposed.

Per Ash's instruction, the minimum system that *would* close F2 without unbundling Stun is specified
separately in `system-min-spec-v1.md`. That file is a specification for Codex, not an implementation
and not an authorisation.

## 9. Safe state

Product `main`, `content/full-content.json`, `domain/`, `tools/` and every protected seed are
unchanged. No branch was pushed, no PR opened, no Actions run started, no Godot process created, no
simulator row executed, no ledger or cache written. The only files added by this task are the two
design summaries and the zero-row arithmetic script under
`research/issue-421-grammar-only/`.

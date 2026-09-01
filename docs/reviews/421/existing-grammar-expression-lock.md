# Existing-grammar expression lock — #421 surface (b)

## Status

**DESIGN LOCK ONLY. Not implemented. Zero rows run. No P9 claim. No detector, holdout,
protected seed or promotion authorised. This lock edits zero lines of the harness and zero
lines of product content.**

Surface: **(b) bounded existing-grammar expression pass.** The question this lock freezes is
the one #421 makes the precondition for any new primitive:

> Can the **existing** values and couplings express a second viable Duskblade package, or is
> there evidence that they cannot?

**Verdict: the surface does NOT fail closed. An admissible finite set exists and it is not
empty.** The set is named, enumerated and ranked below. The prior tool-less
`(f) FAIL-CLOSED-the-whole-hunt` disposition is INVALID and is not used anywhere here.

Scope boundary, unchanged: no new card, relic, effect kind, special, status or system. Dusk
keeps its stun/shatter identity, Stun stays inside Shatter, Ash stays burn-only, the P9/#108
bar is untouched, and #421 remains the single integration boundary.

## Evidence this lock is built on

Read and measured in-session out of the tree at the binding head, not restated from a summary.

| Fact | Value |
|---|---|
| Binding current-main source | `c28ae38824f7ba2168b573002ab8b90dadd5bde1` |
| Lock worktree | `.claude/worktrees/421-existing-grammar-expression-lock`, branch `claude/421-existing-grammar-expression-lock` |
| Content DB read | `content/full-content.json` at `c28ae388` — 61 cards, 17 statuses, 31 relics, 8 deeds |
| Engine read | `domain/rules/combat.gd` (1414 lines), `domain/rules/rewards.gd`, `domain/state/run_state.gd` at `c28ae388` |
| Harness read | `tools/balance_sim.gd` at `c28ae388` |
| Prior lock | `docs/reviews/421/stream-b-attribution-repair-lock.md` (participation instrument) |
| Frozen baseline outcome digest | `b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf` |

Closed families this lock does not reopen, reuse or pool: Dimmed (v1), Chisel/Splinter/Glass
Rain (v2), Chisel/Splinter follow-up guard (v4 capacity), Three Disciplines + Eclipse direct
damage (v5), Emberglass Memory (futility at final correction cap), Kindle, EP4
ward-mirror-edge (VETO), STREAM-B `spend-Ward`/`facetBurst` p9-w0-v4 (FAIL CLOSED, causal,
`Played=0`).

## The existing grammar, enumerated

This is the whole of it. Nothing below is proposed; every row already executes at `c28ae388`.

### Effect kinds — `domain/rules/combat.gd` (`_apply_effect`), 11 total

`dmg`, `block`, `draw`, `energy`, `heal`, `loseHp`, `status`, `addCard`, `chip`, `ember`,
`special`.

Used by shipped cards: 9. **`addCard` and `heal` are engine-supported and used by zero cards**
— existing-grammar headroom, recorded, not spent here.

### Specials — `CombatRules.SPECIAL_IDS`, 12 total

`leech`, `execute`, `momentum`, `doubleBlock`, `phantom`, `devour`, `pyreTithe`, `catalyst`,
`shatterEcho`, `flawless`, `emberNova`, `emberdance`.

### Statuses — 17

`str`, `dex`, `vulnerable`, `weak`, `frail`, `poison`, `thorns`, `ritual`, `metallicize`,
`regen`, `barricade`, `energized`, `venomous`, `rampage`, `beacon`, `emberflow`, `nightsight`.

### The Dusk shatter coupling — measured, not summarised

`domain/rules/combat.gd`:

- `hit_enemy` — a connecting attack that draws unblocked blood earns one facet chip, once per
  card (`pending_chips`).
- `apply_chips` — **`if run.aspect != 0: return`**. Shatter/stagger is Dusk-only; Ashwarden
  computes implicit chip and never stuns. This is the aspect-identity boundary and it does not
  move.
- `_shatter_enemy` — on shatter: `facet_max += 1` (annealed), `staggered = true`,
  `vulnerable 2` applied, **`gain_embers(2)`**, and `prismCharm` spills 2 more on the first
  shatter of a combat.
- `enemy turn` — a `staggered` enemy skips its move. **This is Stun. It is inside Shatter and
  stays there.**
- `shatterEcho` — `2 if target.staggered or vulnerable > 0 else 1`, times `n`.

So the couplings `chip → shatter → {staggered, vulnerable 2, +2 embers}` and
`{staggered ∨ vulnerable} → shatterEcho ×2` **already exist and are already wired.** No
primitive is required to express a producer/consumer Shatter family. One is already authored.

## The defect: ten authored cards the research has never been able to draw

`content/full-content.json` carries a `"locked": "<deedId>"` field on 10 cards and 4 relics.
**None of them appears in any `cardPools` or `relicPools` entry.** The sole path into a pool is
`domain/rules/rewards.gd` (`card_pool`, `relic_pool`), which appends an id only when
`run.unlocks` contains `card:<id>` / `relic:<id>`.

| Deed | Requirement | Unlocks |
|---|---|---|
| `paneBreaker` | `shatters` ≥ 15 | `card:quakeblow`, `card:resonantLance` |
| `hundredShards` | `slain` ≥ 100 | `card:shardstorm`, `relic:bellOfEndings` |
| `untouched` | `perfects` ≥ 3 | `card:flawlessForm`, `relic:prismCharm` |
| `spendthrift` | `embersSpent` ≥ 30 | `card:novaflare`, `card:emberdance` |
| `darkWalker` | `unlitVisited` ≥ 6 | `card:nightSight`, `relic:thiefOfWicks` |
| `lanternFed` | `kindles` ≥ 20 | `card:tithe`, `card:pyreheart` |
| `ashSermon` | `smolderKills` ≥ 10 | `card:ashenChoir`, `relic:smolderingCoal` |
| `firstDawn` | `wins` ≥ 1 | `aspect2` |

`tools/balance_sim.gd` (`simulate`) sets:

```gdscript
var profile: Dictionary = {
    "aspect": aspect_index, "vow": vow, "reveals": content.reveal_ids.duplicate(),
    "unlocks": ["aspect2"], "quests": {}, "shards": [], "lamplighter": false,
}
```

`"aspect2"` carries no `card:` or `relic:` prefix. **Every P9 Dusk package search to date has
run against a content projection missing all ten cards and all four relics.** `reveals` is
supplied in full, so `poolGate` is wide open and this was easy to miss: the pool looks complete
because the *reveal* gate is open while the *deed* gate is shut.

Three of the missing ids are exactly a Dusk Direct-Shatter family:

| Role | Id | Cost | Effect | Gate |
|---|---|---|---|---|
| producer (already in start deck) | `chisel` | 1 | `dmg 4` + `chip` flag | none |
| producer | `quakeblow` | 2 | `dmg 8` + `chip` flag | `paneBreaker` |
| consumer | `resonantLance` | 1 | `special shatterEcho n=7` → **14 on a staggered or vulnerable target** | `paneBreaker` |
| consumer (relic) | `bellOfEndings` | — | on any Shatter, every other enemy takes 4 | `hundredShards` |
| consumer (relic) | `prismCharm` | — | first Shatter each combat spills 2 extra Embers | `untouched` |
| reach | `shardstorm` | 3 | `dmg 5 ×2` to allEnemies | `hundredShards` |

The v1 report already recorded the symptom without reaching this cause:

> The registered Direct-Shatter consumer was Resonant Lance. It is reveal-gated by
> `paneBreaker`, while the research profile supplied only `aspect2`; raw rows contain hundreds
> of producer fights and zero consumer fights. Its zero activation is therefore a
> package-availability defect in this protocol, not evidence that Duskblade has no Shatter
> route.

That disposition stands and this lock is its continuation. **The four families closed at
capacity since then (Dimmed, Glass Rain, the follow-up guard, Three Disciplines) each invented a
new consumer while the authored one sat behind a one-line profile literal.** Those closures
remain valid for the mechanisms they tested; none of them tested this one.

## In grammar / out of grammar

**In.** Exactly one degree of freedom: the contents of `profile["unlocks"]`, drawn only from the
`unlocks` arrays already authored on the 8 deeds. Nothing else.

**Out — and each of these is a STOP if it turns out to be required:**

- any edit to `content/full-content.json` — no card, relic, status, value, cost, pool, gate or
  deed threshold moves;
- any new effect kind, special id, status or keyword;
- any change to `domain/`, `application/`, `presentation/`, `port_fixtures/`;
- unbundling Stun from Shatter;
- lifting `apply_chips`'s `run.aspect != 0` guard;
- any change to P9/#108, any denominator, estimand, bound or vow set;
- any reuse of a closed family's identity, threshold, seed or content.

## Deterministic enumeration and ranking

The candidate space is the power set of admissible deeds. Enumeration and ranking are
deterministic and frozen **before** any row; model judgement does not select a candidate after
results.

**Exclusions, applied first and stated with reasons:**

| Deed | Disposition |
|---|---|
| `firstDawn` | already supplied as `aspect2`; not a variable |
| `lanternFed` | **EXCLUDED — Kindle is sealed.** `tithe`, `pyreheart` are out of this lock entirely |
| `ashSermon` | Ash-only (`smolderKills`, Smolder). Out of the **Dusk** exam. Retained, unspent, for a later Ash exam under the same design |
| `darkWalker` | admissible but not shatter-coupled; deferred to tier L3 by the ranking rule |
| `spendthrift` | admissible; shatter-coupled only through `gain_embers(2)` → `emberNova`. Deferred to tier L3. **Not Emberglass Memory** — that was the persistent-contract family and it stays closed |
| `paneBreaker` | **IN** — Dusk-native, the producer/consumer pair |
| `hundredShards` | **IN** — `bellOfEndings` is a direct Shatter consumer |
| `untouched` | **IN** — `prismCharm` is a direct Shatter consumer |

**Ranking rule (frozen):** ascending by count of ids added to the projection; ties broken by
lexicographic deed id. This is the issue's minimum-complexity ordering with a canonical
tie-break, and it produces exactly one order:

| Level | `profile["unlocks"]` | ids added | What it tests |
|---|---|---:|---|
| **L0** | `["aspect2"]` | 0 | Exact current baseline. Must reproduce `b02bca98…` |
| **L1** | L0 + `paneBreaker` | 2 | The minimal authored producer/consumer pair, alone |
| **L2** | L1 + `hundredShards` + `untouched` | +4 | The Shatter consumers |
| **L3** | L2 + `spendthrift` + `darkWalker` | +4 | Non-Kindle deed closure |

**Cheapest decisive gate first: only L0 vs L1 is authorised by this lock.** L2 and L3 are
enumerated so the ranking is complete and cannot be adapted later; they are not funded here and
require a separate registration.

## The one claim-specific exam

**Not a broad Phase A search. One two-arm contrast.**

| Dimension | Frozen at |
|---|---|
| Arms | L0 (`["aspect2"]`), L1 (`["aspect2","card:quakeblow","card:resonantLance"]`) |
| Aspect | `duskblade` only |
| Vows | 0 and 5 |
| Policies | 2 witnesses: the competent panel policy and the RandomBuild control, identical across arms |
| Seeds | 256 fresh seeds, band **6000–6255** |
| Rows | 2 × 2 × 2 × 256 = **2,048** — the same capacity budget the v4 and v5 families used |
| Estimands | Vow-0 and Vow-5 **activation complementarity** and **win complementarity**; pooled win complementarity; pooled bootstrap positive-sign agreement |
| Thresholds | Carried across **verbatim** from the closed families: pooled win complementarity ≥ `+0.02`, positive at both Vows, bootstrap positive-sign agreement ≥ `0.90` |
| Attribution | The v4 participation instrument: `<card>Offered`, `<card>Drawn`, `<card>Played`, `<card>InDeck`, keyed per row |
| Protected / reserve seeds | `0`. Acceptance `3000–5199` and reserve `5200–5399` are untouched |
| Correction cap | 2 corrected versions, per the issue's default family rule |

**The thresholds are not re-decided here.** Reusing the numbers that closed four families is the
only way this exam can be compared to them, and it removes any room to tune a pass.

### CRN — stated honestly before the run

`card_pool` rebuilds its array in order and `gen_combat_rewards` draws
`crng.pick_index(pool.size())`. **Adding two ids shifts the index→id mapping for every draw
after them.** L0 and L1 therefore do not share a trajectory: the same seed yields a different
offer, a different deck and a divergent run from the first card reward onward.

**This is a between-subjects contrast. CRN pins the seed, not the trajectory.** The seed band is
shared across arms for variance reduction only. Anyone who later reads an L0 row as a
same-trajectory twin of its L1 coordinate has repeated the exact error the STREAM-B v3
attribution instrument made, and this paragraph exists so that cannot be done silently.

Per-row causal attribution comes from participation, not from twin lookup — the instrument
already designed and already executed in v4.

### Reachability witness — free, computed off the L0 arm

`paneBreaker` requires `shatters ≥ 15`, and `tools/balance_sim.gd` already emits per-fight
`shatters`. The L0 arm therefore measures its own gate: report the distribution of total
`shatters` per Dusk run and the fraction of runs reaching 15.

**This is a required output, not a nicety.** P9 acceptance demands "real reward/economy
reachability or one separately validated deterministic acquisition path". If L0 Dusk runs do not
reach 15 shatters at a credible rate, `paneBreaker` is not reachable, L1 is not a real player
state, and the exam reports that rather than claiming a package.

## Files / functions for the later Codex implementer

**Not edited by this lock.** Baseline tree `c28ae38824f7ba2168b573002ab8b90dadd5bde1`.

| Path | Symbol | Change |
|---|---|---|
| `tools/balance_sim.gd` | `simulate` | Add one optional parameter `unlocks: PackedStringArray = PackedStringArray(["aspect2"])` and use it for `profile["unlocks"]`. **Default-preserving: every existing caller is byte-identical.** This is the only line outside `research/` and it is inert until passed |
| `research/issue-421-grammar-only/tools/` | new arm runner | Build the L0/L1 projections by passing `unlocks`; write the participation fields per the v4 repair |
| `research/issue-421-grammar-only/tools/` | analyser | Apply the frozen estimands, thresholds and stop rule. Emit the L0 reachability distribution |
| `research/issue-421-grammar-only/protocols/` | — | New protocol + JSON + SHA on a **fresh identity**. Every prior protocol file stays immutable |

Do **not** touch `content/`, `domain/`, `application/`, `presentation/`, `port_fixtures/`,
`tools/balance_metrics.gd`, `tools/balance_cem.gd`, or any closed family's artefacts.

**Note the scope honesty.** The prior lock listed "any `tools/` change" as a stop condition for
*its* repair. This exam needs exactly one, and it is a defaulted signature. The zero-row
preflight below proves mechanically that it changes nothing; if that proof fails, this is STOP,
not a smaller edit.

## Zero-row preflight

Runs before any cohort row exists; emits no protocol row. Failure of any assertion is **STOP,
not FAIL CLOSED** — nothing has been measured yet.

1. **Baseline digest sentinel.** One L0 row reproduces
   `b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf` exactly. This is the whole
   proof that the defaulted parameter is inert. If it does not match, stop and report.
2. **Pool-delta proof, zero rows.** Direct calls on a constructed `RunState`: under L0,
   `card_pool(run,"uncommon")` does **not** contain `quakeblow` and `card_pool(run,"rare")` does
   **not** contain `resonantLance`; under L1, both are present. Assert no other id differs
   between the two pools at any tier.
3. **The consumer actually fires.** Sweep seeds **outside every protocol band** (not 3000–5399,
   not 4000–4199, not 6000–6255, not 9000–9049 — use 9500–9549) on the L1 projection, Dusk,
   until at least one run has `resonantLancePlayed > 0`, and assert
   `Played > 0 ⇒ Drawn > 0 ⇒ Offered > 0`. Write these to a separate preflight artifact; never
   pool them with protocol rows. **If none fires, the exam is not measuring what it claims and
   this is STOP.** *A gate that has never seen a positive is not a gate* — the v2 lock's rule,
   and the exact rule v1 broke.
4. **Between-subjects proof.** Assert L0 and L1 terminal `rng` differ on a non-zero count of the
   shared seed coordinates. This confirms in data what the CRN section asserts in prose, and
   forecloses any later twin reading.
5. **Band disjointness.** Assert `6000–6255` and `9500–9549` are disjoint from every seed band
   registered in the ledger, and that protected `3000–5199` and reserve `5200–5399` are
   untouched.
6. **Harness-scope proof.** `git diff c28ae388 --name-only` touches only
   `research/issue-421-grammar-only/` plus `tools/balance_sim.gd`. Assert it mechanically; do
   not trust the diff by eye.

## PASS

All of:

1. The preflight passes in full, including the L1 `resonantLancePlayed > 0` positive.
2. L1 shows positive win complementarity at **both** Vow 0 and Vow 5.
3. Pooled win complementarity ≥ `+0.02`.
4. Pooled bootstrap positive-sign agreement ≥ `0.90`.
5. Activation is natural — `resonantLance` participation is non-trivial across the L1 arm, not
   concentrated in a handful of coordinates.
6. `paneBreaker` reachability holds on the L0 arm at a credible rate.
7. Zero errors, zero additional stalls, zero protected/reserve rows, zero product mutations.

Verdict: **the existing grammar expresses a second Duskblade package.** The Direct-Shatter
family becomes a candidate for the P9 package-support requirement, and no new primitive is
justified on this evidence. Promotion, detector work and the second Ash package remain outside
this lock.

## FAIL CLOSED

Any of:

- L1 fails any of PASS 2–5. **The authored Direct-Shatter family does not convert activation
  into win complementarity.** Report the levels and bounds; do not retune, do not escalate the
  deed set inside this identity, do not reach for L2 or L3 without a fresh registration.
- `paneBreaker` is measurably unreachable on the L0 arm. The family is not a real player state;
  report the distribution.
- Participation shows the consumer never activates naturally despite firing in preflight. Report
  as an availability finding, not as a mechanism finding.

A FAIL CLOSED here closes **L1 only**. It does not close the surface: L2 and L3 are enumerated,
ranked and untested, and the surface is not exhausted until they are.

## STOP (nothing measured; report before running)

- Any preflight assertion fails.
- The baseline digest does not reproduce.
- Any change to `content/`, `domain/`, or a second `tools/` file turns out to be required.
- Any seed, policy, vow, estimand, threshold or bound would have to move.
- The fresh protocol identity is not authorised.

## Success

Per the binding, exactly two outcomes are a success, and both are reached from here:

- **the existing expression produces a second package** — L1 (or, under a later registration, L2
  or L3) passes, and the complementarity #421 needs is shown to be expressible with no new card,
  relic or system; or
- **a frozen experiment proves it cannot** — L1, L2 and L3 are each run and each fails closed,
  at which point, and only at which point, "the existing grammar cannot express the required
  complementarity" is an evidenced statement and the smallest new primitive becomes admissible.

**What is not a success:** declaring the surface closed today. This lock's central finding is
that the strongest existing-grammar candidate has never been in the simulator's content
projection at all, so no prior negative result speaks to it. **The prior tool-less (f)
FAIL-CLOSED-the-whole-hunt disposition is INVALID and, had it stood, would have authorised a new
primitive to replace a card the project had already written.**

## What not to do

- Do not design or tune a **card, relic or system**. Nothing in `content/` or `domain/`.
- Do not touch **P9 / #108**, any denominator, estimand, threshold or bound.
- Do not reopen **Emberglass**, **Kindle**, **EP4 ward-mirror-edge**, **STREAM-B
  spend-Ward/facetBurst**, or any of the four capacity-closed families; do not pool them with
  this exam.
- Do not **unbundle Stun from Shatter**, and do not lift the `run.aspect != 0` guard in
  `apply_chips`.
- Do not use the **(f) FAIL-CLOSED-the-whole-hunt** disposition as authority for anything.
- Do not **parameter-rescue**: the thresholds, the vow set, the seed band and the deed
  thresholds are frozen and none of them moves here.
- Do not run **L2 or L3** under this registration. Cheapest decisive gate first.
- Do not touch **acceptance seeds `3000–5199`** or **reserve `5200–5399`**.
- Do not read an L0 row as a **twin** of its L1 coordinate. The arms diverge from the first card
  reward.
- Do not treat a passing L1 as a **P9 claim**. It is one package candidate; P9 needs two per
  aspect and gated vow, and Ash's second package is untouched by this lock.

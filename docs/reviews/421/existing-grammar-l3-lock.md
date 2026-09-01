# Existing-grammar L3 registration — #421 surface (b), level L3

## Status

**DESIGN LOCK ONLY. Not implemented. Zero rows run. No P9 claim. No detector, holdout,
protected seed or promotion authorised. This lock edits zero lines of the harness and zero
lines of product content.**

This is a **fresh registration for L3 only**. It is not an amendment to the L1 lock or the L2
lock, not a correction of either protocol, not a rescue of the L1 result, and — stated first
because it is the single most likely misreading — **not a re-run of L2 under a new name.**

Level ordering, arms, estimands and thresholds were frozen before the L1 exam ran and are
re-used here unchanged. What this lock adds is exactly one thing: authority to run the last
level in that frozen ranking, against the deed unlocks the game already ships.

> **L1 FAIL CLOSED is immutable and is not a tuning target. L2 is INCONCLUSIVE and its ungraded
> numbers are not a result.** No number, bound, band, policy or estimand is moved in order to
> give L3 a better chance than L1 or L2 had.

## Authority and inputs

Read and measured in-session out of the trees named, at the heads named. Nothing here is
restated from a summary.

| Fact | Value |
|---|---|
| Binding current-main source | `c28ae38824f7ba2168b573002ab8b90dadd5bde1` |
| Repo | `fol2/glassvow` |
| This lock's worktree | `.claude/worktrees/421-existing-grammar-l3-lock` |
| This lock's branch | `claude/421-existing-grammar-l3-lock` |
| Local `main` head at lock time | `52a56e726da70c2dd57254e8c6618682c7558f90` |
| Grant | ChatGPT Pro, VALID: **register and run L3 only**. Not a P9 rewrite, not a new primitive |
| Prior L1 design lock (READ, not rewritten) | `.claude/worktrees/421-existing-grammar-expression-lock/docs/reviews/421/existing-grammar-expression-lock.md`, commit `a19e6a33dc75f14a7aa2d9417c822d126ed6b5d2`, sha256 `1ad052834150888c620d6656f387b95a1e3b0110257fc01e9bc648e15dee3daf` |
| Prior L2 design lock (READ, not rewritten) | `.claude/worktrees/421-existing-grammar-l2-lock/docs/reviews/421/existing-grammar-l2-lock.md`, head `a96f08f3`, sha256 `6fd92a0f0e31b223c0b8d0df29d98de51b9d47b76c51a283ae99feff83c90d71` |
| L2 stall-diagnosis lock (READ) | same tree, `existing-grammar-l2-stall-diagnosis-lock.md`, sha256 `44b74aeb92b62ed9a250aa6b9fc57c19b28132f7dae8e11c7c2f22505da31d8b` |
| L2 stall diagnosis finding (READ) | `.codex/worktrees/421-existing-grammar-l2-stall-diagnose`, head `ea766fe818cf2d56f471e66d15a25242feb35f01`, sha256 `3549c6e520c45f774efed60bd8960cc9c6b30845f02c40041ac7b1671f536f05` |
| L1 exam packet (READ, immutable) | `.codex/worktrees/421-existing-grammar-l1`, head `5387c9b6`, protocol `existing-grammar-l0-l1-v2`, json sha256 `051e7935155426042a8d59e4a716ecc8975449b17722448445e543b252fc4789` |
| L2 exam packet (READ, frozen) | `.codex/worktrees/421-existing-grammar-l2`, head `51fe17dbc57502a8f2557d43671c1628a6cbd1f3`, protocol `existing-grammar-l1-l2-v1`, json sha256 `3631977a33a25c977421046a176d5d24adf891e3b57419ac6d26262c846af036` |
| Content DB read | `content/full-content.json` at `c28ae388` |
| Engine read | `domain/rules/rewards.gd`, `domain/rules/combat.gd`, `domain/state/run_state.gd`, `domain/state/vigil_state.gd` at `c28ae388` |
| Harness read | `tools/balance_sim.gd` at `c28ae388`, and the L2 packet's edited copy at `51fe17db` |
| Frozen baseline outcome digest | `b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf` |

**Sealed and not reopened, reused or pooled anywhere in this lock:** STREAM-B
(`spend-Ward`/`facetBurst`, p9-w0-v4, FAIL CLOSED, causal, `Played=0`), Emberglass Memory,
Kindle, EP4 ward-mirror-edge (VETO), Stun-in-Shatter, P9/#108, #461, and the four
capacity-closed families (Dimmed v1, Chisel/Splinter/Glass Rain v2, the v4 follow-up guard,
Three Disciplines + Eclipse v5). `lanternFed` and Kindle remain excluded from the deed set;
`ashSermon` remains reserved, unspent, for a later Ash exam.

## The prior, stated exactly — and one half of it is not a result

This is the section that decides whether this registration is honest, so it is placed before
the design.

### L1 — graded, FAIL CLOSED

| L1 outcome | Value |
|---|---|
| Matrix | 2,048 / 2,048 rows, complete |
| Verdict | **FAIL CLOSED** (L1 only) |
| Preflight | PASS |
| `resonantLance` played | ≈ 28–30% of L1 rows |
| Win complementarity, Vow 0 | `-0.050781` |
| Win complementarity, Vow 5 | `+0.039063` |
| Pooled win complementarity | `-0.005859` (threshold `≥ +0.02`) |
| Bootstrap positive-sign agreement | `0.4215` (threshold `≥ 0.90`) |
| `paneBreaker` reachability | reachable |

L1 did not fail for want of availability. The authored consumer was offered, drawn and played in
roughly three rows in ten, its gate was reachable, and the package still did not convert
participation into win complementarity.

### L2 — STOP, then INCONCLUSIVE. **Never graded.**

| L2 outcome | Value |
|---|---|
| Matrix | 2,048 / 2,048 rows, complete, row index sequence intact |
| `errors` | `0` |
| `protectedReserveRows` | `0` |
| `additionalStalls` | `1` |
| `integrityFailures` | `["1 additional L2 stall(s)"]` |
| Reported verdict | **`STOP`** |
| Diagnosis branch fired | **2 — real L2 stall**, seed `7191`, `rowIndex 1472` |
| Fixed branch-2 disposition | **L2 INCONCLUSIVE** |

`research/issue-421-grammar-only/tools/existing_grammar_l2_exam.py` › `_analyse` sets
`verdict = "STOP" if integrity else ("FAIL_CLOSED" if scientific else "PASS")`. **Integrity
outranks science, so L2's three recorded scientific misses were never graded.** They exist in
the artifact as recorded numbers. They are not a verdict, this lock does not treat them as one,
and no section below cites them as evidence for anything.

The diagnosis replayed exactly one coordinate off the frozen packet and reproduced the row, the
terminal RNG `2044296083` and the outcome digest
`850eac40cff34b5dd8d7a73bbcd626fb22c2fe189027f22ee59fafc51db4450a` exactly. At the turn-30
ceiling the Act 3 Sovereign fight was still open — player `27/64` HP, Sovereign `75/650` HP,
`combatOver = false`. A real fight cut by the ceiling, not a harness fault and not a determinism
mismatch. Branch 2 therefore fired, and branch 2's disposition was fixed **before** the answer
was seen.

**Same-identity L2 re-run is NOT authorised.** Branch 1 — the only branch that could have
authorised one — did not fire. Nothing in this lock re-runs, re-bands, re-analyses or rescues
`existing-grammar-l1-l2-v1`.

### What the two priors jointly permit, and what they do not

**Ungraded complementarity is not a result.** The surface currently has **one** graded closure
(L1) and **one** ungraded level (L2). Anyone counting two closures has miscounted.

The issue's second success condition — *"the existing grammar cannot express the required
complementarity"* — requires L1, L2 **and** L3 each run and each **failed closed**. L2 is not
failed closed. Therefore:

> **Even a FAIL CLOSED at L3 does not complete the second success condition, and does not
> authorise a new primitive.** It closes L3. The surface would then stand at two graded closures
> and one ungraded level, which is not three.

This is stated here, in advance, because it is precisely where the pressure will be after an L3
result lands.

**No pooling.** L1 rows, L2 rows, their cell means, their seed bands and their bootstraps are
never combined with L3's. The three exams share thresholds so they can be *compared*; they do
not share data.

## Why L3 is registrable anyway

Because the ranking frozen in the L1 lock enumerates it, because it is the last enumerated
level, and because the alternative — declaring the surface closed on an untested level while
another level sits ungraded — is exactly the invalid `(f)` disposition the L1 lock overturned.

L3 is not being run because L1 looked close, and it is not being run to substitute for L2's
missing grade. It is being run because it is the remaining enumerated measurement, and a
registration whose prior is unfavourable is still worth running.

## Arms — frozen before any row

### L2 (control arm)

Exactly the array the L2 exam ran, verbatim, unchanged, taken from
`existing-grammar-l1-l2-v1.json` › `arms.L2.unlocks`:

```
["aspect2", "card:quakeblow", "card:resonantLance",
 "card:shardstorm", "relic:bellOfEndings",
 "card:flawlessForm", "relic:prismCharm"]
```

**No id is dropped from the control.** The full `hundredShards` + `untouched` set is carried,
including `resonantLance` and `quakeblow`.

### L3 (treatment arm)

L2 **plus the complete authored `unlocks` array of `darkWalker` and `spendthrift`**. Both deeds
are taken whole. No authored id is dropped, deferred or substituted.

Cited from `content/full-content.json` › `deeds` at `c28ae388`:

```json
"darkWalker":   { "stat": "unlitVisited", "n": 6,  "unlocks": ["card:nightSight", "relic:thiefOfWicks"] },
"spendthrift":  { "stat": "embersSpent",  "n": 30, "unlocks": ["card:novaflare",  "card:emberdance"] }
```

Frozen L3 array, in this exact order (the order is load-bearing — see CRN below):

```
["aspect2", "card:quakeblow", "card:resonantLance",
 "card:shardstorm", "relic:bellOfEndings",
 "card:flawlessForm", "relic:prismCharm",
 "card:nightSight", "relic:thiefOfWicks",
 "card:novaflare", "card:emberdance"]
```

Four ids added. Deed order is `darkWalker` then `spendthrift`, which is the L1 lock's frozen
lexicographic tie-break applied unchanged (`d` < `s`, exactly as L2 used `h` < `u`); within a
deed, the authored array order is preserved. This matches the L1 lock's ranking row for L3
(`+4`) exactly.

### The four added ids, cited from content

| Id | Kind | Rarity | Cost | Authored effect | Deed |
|---|---|---|---:|---|---|
| `nightSight` | power | **uncommon** | 1 | `status self nightsight n=1` — at the start of each turn, draw 1 extra card. `up` → cost 0 | `darkWalker` |
| `thiefOfWicks` | relic | **uncommon** | — | unlit lanterns pay double bounty | `darkWalker` |
| `novaflare` | attack | **rare** | 2 | `special emberNova n=3` — 3 damage per Ember in the lantern | `spendthrift` |
| `emberdance` | skill | **uncommon** | 0 | `special emberdance n=3`, `exhaust` — spill the lantern, 3 Ward per Ember spent, Kindle | `spendthrift` |

All four are implemented in the engine at `c28ae388`; none is dead content:

- `emberNova` and `emberdance` are both in `domain/rules/combat.gd`'s special allowlist (line 18)
  and both have live branches (lines ~990 and ~1002).
- `nightsight` is read by `domain/rules/combat.gd` line 367, in the per-turn draw count.
- `thiefOfWicks` is read by `tools/balance_sim.gd` line 164 — **the simulator already models
  it** — and mirrored in `application/scenario_kernel.gd:173` and `application/main.gd:1600`,
  neither of which the simulator uses.

`nightSight` being a `power` is not novel to the pilot: the base `cardPools` already carry 4
uncommon and 4 rare powers at `c28ae388`.

**Neither deed is a sealed-family reopen.** `spendthrift` is shatter-coupled only through
`gain_embers(2)` → `emberNova`; the L1 lock recorded on the record that it is **not Emberglass
Memory**, which was the persistent-contract family and stays closed. `darkWalker` is admissible
but not shatter-coupled. Nothing in L3 spends Ward, kindles by hand, or touches Smolder, and no
STREAM-B, Emberglass, Kindle or Stun artefact, threshold, seed or row is touched, cited or
pooled.

### Why these ids have never been measured

Verified mechanically against `content/full-content.json` at `c28ae388`:

- `cardPools.uncommon` (17 ids) contains neither `nightSight` nor `emberdance`.
- `cardPools.rare` (12 ids) does not contain `novaflare`.
- `relicPools.uncommon` (7 ids) does not contain `thiefOfWicks`.
- All four carry a `"locked"` field and appear in no pool array at any tier.

`domain/rules/rewards.gd` › `card_pool` / `relic_pool` is the sole path in: after filtering the
base array through `_pool_open`, each function walks `run.unlocks` and appends an id when the
prefix matches (`card:` / `relic:`) **and the id's own `rarity` equals the requested tier**, and
the id is not already present. This is the same defect the L1 lock named, extended to the four
ids L2 did not carry.

`thiefOfWicks` is additionally gated at the point of use: `tools/balance_sim.gd` › `_enter_node`
reads `run.has_relic("thiefOfWicks")` on the `node.unlit` branch only. Under L0–L2 that branch's
doubled arm is unreachable dead code. Under L3 it is reachable **only if the relic is actually
offered and taken, and only on an unlit node** — which is why relic attribution below cannot
stop at ownership, and why this relic needs a different instrument from L2's two.

## The contrast

**Incremental on top of L2, between-subjects.** The contrast is L2 vs L3. It is not L0 vs L3,
not L1 vs L3, and neither L0 nor L1 appears in this exam.

| Dimension | Frozen at |
|---|---|
| Arms | L2 (control), L3 (treatment) |
| Aspect | `duskblade` only |
| Vows | 0 and 5 |
| Policies | 2 witnesses — the competent panel policy and the RandomBuild control, identical across arms |
| Seeds | 256 fresh seeds, band **8000–8255** |
| Rows | 2 × 2 × 2 × 256 = **2,048** — the same capacity budget L1, L2, v4 and v5 used |
| Correction cap | 2 corrected versions, per the issue's default family rule |
| Protected / reserve seeds | `0`. Acceptance `3000–5199` and reserve `5200–5399` are untouched |

**The control arm is re-run on fresh seeds. It is not the frozen L2 packet's rows.** No row from
`existing-grammar-l1-l2-v1` is reused, replayed, pooled or compared row-wise. Seed `7191` and its
stall are outside this exam entirely; band `8000–8255` is disjoint from `7000–7255`.

Cell order for every complementarity, carried across from the L1 and L2 protocols with the arms
relabelled and nothing else changed:

| Cell | Meaning |
|---|---|
| `PC` | L3 competent |
| `P` | L3 RandomBuild |
| `C` | L2 competent |
| `O` | L2 RandomBuild |

Complementarity is `PC - P - C + O`, formed from four cell means. **No per-row causal twin
effect is formed.**

### CRN — and L3 diverges earlier than L2 did

`card_pool` and `relic_pool` rebuild their arrays in order, and `gen_combat_rewards` draws
`crng.pick_index(pool.size())`.

Measured at `c28ae388`, the L2→L3 step changes pool **sizes**, and — unlike L2 — it changes them
at the **uncommon** tiers:

| Pool | base | L2 | L3 |
|---|---:|---:|---:|
| `card_pool(common)` | 11 | 11 | 11 (unchanged) |
| `card_pool(uncommon)` | 17 | 18 | **20** (`+ nightSight + emberdance`) |
| `card_pool(rare)` | 12 | 15 | **16** (`+ novaflare`) |
| `relic_pool(common)` | 8 | 8 | 8 (unchanged) |
| `relic_pool(uncommon)` | 7 | 7 | **8** (`+ thiefOfWicks`) |
| `relic_pool(rare)` | 5 | 7 | 7 (unchanged) |

Because unlocked ids are appended **after** the base array and in `run.unlocks` order, the frozen
L3 ordering above preserves every L2 index: `quakeblow` stays at uncommon 17, `resonantLance` at
rare 12, `shardstorm` at rare 13, `flawlessForm` at rare 14, `bellOfEndings` at relic-rare 5 and
`prismCharm` at relic-rare 6. That is a tidy property and it is **not** a claim of shared
trajectory.

**Where the arms separate, and why it is sooner than L2's separation.** L2 moved only rare pools,
so L2 and L1 diverged at the first *rare* reward. L3 moves the uncommon pools, and the uncommon
tier is drawn far more often:

- `domain/rules/rewards.gd` › `_rarity_cuts` returns `(0.6, 0.92)` for a normal combat, so a card
  reward draw is common below `0.6`, **uncommon on `[0.6, 0.92)` — 32% of draws** — and rare at
  8%. `_roll_card_reward` takes 3 such draws per reward by default.
- `_random_relic` weights `{common 0.5, uncommon 0.35, rare 0.15}`, so `thiefOfWicks` sits in a
  35% band where L2's two relics sat in a 15% one.

**So the L2 and L3 arms are expected to diverge at the first normal-combat card reward, not at
the first rare one.** This is recorded as a property of the design, not as a defect, and it is
recorded *before* the run so nobody later reads earlier divergence as evidence of anything.

**This is a between-subjects contrast. CRN pins the seed, not the trajectory.** The seed band is
shared across arms for variance reduction only.

**Do not twin-match.** Anyone who later reads an L2 row as a same-trajectory twin of its L3
coordinate has repeated the exact error the STREAM-B v3 attribution instrument made, and the
error the L2 stall diagnosis was careful not to make when it read `rowIndex 448` as a cell and
not a twin. Per-row causal attribution comes from participation, not from twin lookup.

## Estimands and thresholds — carried across verbatim

**Not re-decided here. Not retuned. Reusing the numbers that closed four families, then L1, and
that L2 was measured against is the only way this exam can be compared to them, and it removes
any room to tune a pass.**

| Estimand | Definition |
|---|---|
| `winComplementarity` | Per vow, `Pr(win)[PC] - Pr(win)[P] - Pr(win)[C] + Pr(win)[O]` |
| `pooledWinComplementarity` | Arithmetic mean of the Vow-0 and Vow-5 win complementarities |
| `activationComplementarity` | Per vow, the same four-cell form on `Pr(<id> activated > 0)` |
| `participation` | `Offered`, `Drawn`, `Played`, `InDeck` per row for the tracked cards; `Offered`, `Owned`, `Procs` per row for the tracked relics |
| `deedReachability` | Within the **L2** arm, the per-run distributions of `embersSpent` and `unlitVisited`, and the derived cumulative runs-to-threshold |

| Threshold | Value |
|---|---|
| Pooled win complementarity | `≥ +0.02` |
| Win complementarity at each vow | strictly positive at **both** Vow 0 and Vow 5 |
| Bootstrap positive-sign agreement | `≥ 0.90` |
| Natural activation rate | at each vow, `≥ 5%` of the **512** L3 rows |
| Positive-sign convention | strictly greater than zero |

`512` is `2 policies × 256 seeds`, the L3-arm row count at one vow, exactly as L2's was.

Statistics, carried across unchanged from `existing-grammar-l0-l1-v2` and
`existing-grammar-l1-l2-v1`:

- Bootstrap: 2,000 resamples, whole-seed-block, sampling 256 seed blocks with replacement; each
  block retains all arms, policies and vows; cell means computed before `PC - P - C + O`.
- Bootstrap seed root: derived for this identity as `4218000` (L1's `4216000` and L2's `4217000`
  are spent and are not reused; the increment is the only new number in this section and it
  selects a stream, not a result).
- Interval: two-sided 95% percentile, sorted indices `floor(0.025B)` and `ceil(0.975B)-1`.
- Rate interval: two-sided Wilson 95%. Quantiles: nearest-rank.

### Reliability budget — for THIS protocol

`errorsAllowed 0`, `productMutationsAllowed 0`, `protectedReserveRowsAllowed 0`,
`additionalStallsAllowed 0`, where additional stalls are re-based onto this exam's own arms:

```
additionalStalls = sum over (vow, policy) cells of max(0, L3 stalls - L2 stalls)
```

Both counts are measured **inside this exam, on band `8000–8255`**. The frozen L2 packet's stall
count is not an input, and seed `7191` is not in this exam.

**Integrity outranks science, and STOP is not FAIL CLOSED.** If an integrity assertion fails, the
exam reports `STOP` and no scientific gate is graded — the L2 outcome is the precedent and it
must be repeated, not worked around. In particular:

- **Do not restate ungraded scientific numbers as a verdict.** If L3 stops, its recorded
  complementarities are numbers in an artifact, exactly as L2's are.
- **Do not raise `additionalStallsAllowed` to absorb a stall.** That is parameter-rescue and it
  is forbidden.
- A stall STOP at L3 requires a **fresh diagnosis registration** on the L2 precedent's pattern.
  This lock does not pre-authorise one, does not pre-write its branches, and does not
  pre-authorise any re-run.

**The 30-turn ceiling is a known, still-unseparated mode.** `tools/balance_sim.gd` contains zero
occurrences of `turnCeiling` at `c28ae388`; the separation proposed in
`.claude/worktrees/421-stream-b-reliability-lock/docs/reviews/421/stream-b-reliability-lock.md`
was never landed. `_fight` breaks on `game.cb.turn >= 30` (line 144) and `simulate` labels that
`"stall"`, so one label still carries both "the ceiling had to cut this" and "the ceiling
truncated an ordinary fight". **Landing that separation inside this exam is a STOP, not a fix.**

## Attribution

The v4 participation instrument, extended to the ids L3 adds. Keyed per row.

**Cards** — `<card>Offered`, `<card>Drawn`, `<card>Played`, `<card>InDeck`:

- `resonantLance`, `quakeblow` — carried from L1/L2; the L1 producer/consumer pair under a larger
  pool is the direct comparison to both prior results.
- `shardstorm`, `flawlessForm` — carried from L2; both are in the control arm.
- `nightSight` — L3-added.
- `novaflare` — L3-added.
- `emberdance` — L3-added.

**Relics** — `<relic>Offered`, `<relic>Owned`, `<relic>Procs`:

- `bellOfEndings`, `prismCharm` — carried from L2; both are in the control arm.
- `thiefOfWicks` — L3-added.

### `thiefOfWicks` needs a different instrument, and this lock says so rather than assuming L2's

**This is the one instrument question L3 has that L2 did not, and it is not a detail.**

L2's relic instrument counted `EventTypes.RELIC_PROC` entries in `game.cb.queue`, emitted by
`domain/rules/combat.gd` › `_proc(cb, relic_id)` inside `_shatter_enemy`. That channel is
**combat-only**, and `thiefOfWicks` never enters it: its sole effect site is the map-side
`_enter_node` bounty branch. **Reusing L2's proc reader for this relic would silently report
`Procs = 0` for a relic that fired.**

Frozen instrument requirements for `thiefOfWicks`:

| Field | Source, frozen |
|---|---|
| `thiefOfWicksProcs` | Bumped in `tools/balance_sim.gd` › `_enter_node`, on the `node.unlit` branch, exactly when `run.has_relic("thiefOfWicks")` is true and the doubled bounty is therefore paid |
| `thiefOfWicksOwned` | Read from `run.player.relics` at row end |
| `thiefOfWicksOffered` | Bumped at every path that can put an uncommon relic in front of the pilot |

**Offered has no uniform hook at `c28ae388` and the implementer must not pretend it does.**
Measured in `tools/balance_sim.gd`: `_claim_rewards` (elite) auto-gains at lines 187/190 with no
`Offered` bump for relics; `_resolve_shop` bumps `Offered` only for `stock["cards"]` (line 384),
never for relic rows, and purchase at line 394 is gold-gated so Offered and Owned genuinely
diverge there; `_claim_treasure` (line 412) gains through `claim_treasure` → `_random_relic` with
no bump at all; the boss path (lines 120–129) special-cases `hollowCrown` only and is `boss` tier,
which `thiefOfWicks` is not.

**The L2 protocol's `relicOfferSemantics` note does not transfer.** It reads: *"Both tracked
relics are rare. Every simulator path that selects a rare relic auto-gains it, so their row-level
Offered and Owned flags coincide."* `thiefOfWicks` is **uncommon**, and the shop path can offer it
without the pilot owning it. **Offered and Owned must be recorded separately for this relic, and
the coincidence claim must not be copied forward.**

If `thiefOfWicksOffered` cannot be carried on the digest-inert channel without a control-flow
change, that is a **STOP**, not a smaller instrument.

### Consumer-activation predicate

Frozen for the L3 arm:

```
resonantLancePlayed > 0  OR  shardstormPlayed > 0  OR  flawlessFormPlayed > 0
  OR  bellOfEndingsProcs > 0  OR  prismCharmProcs > 0
  OR  nightSightPlayed > 0  OR  novaflarePlayed > 0  OR  emberdancePlayed > 0
  OR  thiefOfWicksProcs > 0
```

The per-id rates are reported individually as well as under this disjunction; the disjunction is
the gate, the per-id rates are the reading.

**Report the `spendthrift` pair's internal tension as a reading, never as grounds to drop an id.**
`emberNova` scales with `cb.embers` while `emberdance` spends the lantern to zero for Ward, so the
two cards authored under the same deed pull against each other. That is an authored property of
the content and it is exactly what the exam is measuring. Dropping either id to relieve it is
forbidden.

## Deed reachability — cumulative, measured off the L2 arm, and why that arm specifically

`hundredShards` and `untouched` were cumulative and L2 measured them off its L1 arm. **L3's two
deeds are cumulative in the same way.** Measured at `c28ae388`:

- `run.stats["unlitVisited"]` is incremented in `tools/balance_sim.gd` › `_enter_node` (line 167)
  — per run.
- `run.stats["embersSpent"]` is incremented in `domain/rules/combat.gd` › `use_art` (line 1204,
  by the Lantern Art's cost) and in the `emberdance` special (line 1005, by the Embers spilled)
  — per run.
- `domain/state/vigil_state.gd` (lines ~196–200) folds `slain`, `shatters`, `kindles`, `perfects`,
  `smolderKills`, **`unlitVisited`, `embersSpent`** from `run.stats` into the persistent `deeds`
  dictionary at run end — **across runs**.

So `darkWalker` (`unlitVisited ≥ 6`) and `spendthrift` (`embersSpent ≥ 30`) are cumulative
meta-progression thresholds, and a per-run gate on either would be a gate that says nothing about
the mechanism.

**Frozen reachability rule for L3, measured off the L2 arm:**

1. Report the per-run distribution of `unlitVisited` and of `embersSpent` (mean, nearest-rank
   quartiles, max), per vow and pooled.
2. Report the implied cumulative runs-to-threshold: `ceil(6 / mean unlitVisited per run)` and
   `ceil(30 / mean embersSpent per run)`.
3. Report the fraction of L2 runs contributing a non-zero amount to each stat.

**Measuring off the L2 arm is not an arbitrary carry-over of L2's rule — for `spendthrift` it is
the only clean reading available.** `emberdance` is itself an `spendthrift` unlock and it bumps
`embersSpent` at `combat.gd:1005`. In the L3 arm the card that the deed unlocks inflates the very
stat that gates the deed. The L2 arm has no `emberdance`, so its `embersSpent` is the honest
answer to *"would a player ever reach 30 without already being past the gate?"* Reading that
number off the L3 arm would be circular, and this lock forbids it.

This is a **required reported output**, not a pass/fail threshold, and it is deliberately not
one. Turning a cumulative meta-progression stat into a per-exam bound would be inventing a
threshold, which this lock does not do. If the reported runs-to-threshold is implausible for a
real player, the exam says so in its report and that finding travels with the verdict.

`unlitVisited` and `embersSpent` are not currently emitted per row; see the harness note below
for the digest-inert channel that carries them.

## Protocol identity

**Fresh identity. No prior protocol file is edited, superseded or reinterpreted.**

| Field | Value |
|---|---|
| `protocolId` | `existing-grammar-l2-l3-v1` |
| Files | `research/issue-421-grammar-only/protocols/existing-grammar-l2-l3-v1.{md,json,sha256}` |
| Relationship to L1 | Design prior only. `existing-grammar-l0-l1-v2` stays immutable with its 2,048 rows and its FAIL CLOSED verdict |
| Relationship to L2 | Successor level under the same frozen ranking. **Not** a correction, re-run, re-band or rescue of `existing-grammar-l1-l2-v1`, which stays immutable with its 2,048 rows and its **INCONCLUSIVE** disposition |
| Correction cap | 2 |

### Seed bands

| Band | Range | Size | Use |
|---|---|---:|---|
| Cohort | **8000–8255** | 256 | The 2,048 protocol rows |
| Positive preflight | **9700–9749** | 50 | Preflight consumer-firing sweep only; never pooled with protocol rows |

Disjointness, asserted mechanically in preflight against every band named in the binding, in the
L1 protocol's `seedBands` and in the L2 protocol's `seedBands.ledger`. Verified in-session at lock
time; all sixteen pairs are disjoint, as are the two new bands from each other:

| Prior band | Range | vs 8000–8255 | vs 9700–9749 |
|---|---|---|---|
| Protected acceptance | 3000–5199 | disjoint | disjoint |
| Reserve | 5200–5399 | disjoint | disjoint |
| Prior STREAM-B v4 cohort | 4000–4199 | disjoint | disjoint |
| Prior STREAM-B v4 preflight | 9000–9049 | disjoint | disjoint |
| L1 cohort | 6000–6255 | disjoint | disjoint |
| L1 positive preflight | 9500–9549 | disjoint | disjoint |
| L2 cohort | 7000–7255 | disjoint | disjoint |
| L2 positive preflight | 9600–9649 | disjoint | disjoint |

## Zero-row preflight

Runs before any cohort row exists; emits no protocol row. **Failure of any assertion is STOP,
not FAIL CLOSED** — nothing has been measured yet.

1. **Baseline digest sentinel.** One row on the stock projection (`["aspect2"]`, `duskblade`,
   vow 0, seed 1000) reproduces
   `b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf` exactly. This is the whole
   proof that the defaulted `unlocks` parameter — and every instrumentation field added for this
   exam, including the map-side `thiefOfWicksProcs` bump — is inert. If it does not match, stop
   and report.
2. **Pool-delta proof, zero rows, L2 vs L3 only.** Direct calls on a constructed `RunState`, no
   simulation. Under L2, `card_pool(run,"uncommon")` contains neither `nightSight` nor
   `emberdance`, `card_pool(run,"rare")` does not contain `novaflare`, and
   `relic_pool(run,"uncommon")` does not contain `thiefOfWicks`; under L3, all four are present
   at exactly those tiers. **Assert that the only ids differing between the two projections, at
   any card tier and any relic tier, are those four.** `quakeblow`, `resonantLance`,
   `shardstorm`, `flawlessForm`, `bellOfEndings` and `prismCharm` are present in both arms and
   must not appear in the delta. **Assert the pool sizes explicitly** — card `(11, 18, 15)` →
   `(11, 20, 16)` and relic `(8, 7, 7)` → `(8, 8, 7)` for `(common, uncommon, rare)` — because
   this step's whole point is that L3 moves the uncommon tiers and L2 did not.
3. **At least one L3 consumer fires, on the disjoint preflight band.** Sweep seeds
   **9700–9749** (outside every band in the table above) on the L3 projection, Duskblade,
   competent policy, vow 0, until at least one run satisfies the frozen activation disjunction.
   Assert the implications `Played > 0 ⇒ Drawn > 0 ⇒ Offered > 0` for each tracked card and
   `Procs > 0 ⇒ Owned > 0 ⇒ Offered > 0` for each tracked relic. **`thiefOfWicks` is asserted on
   the separate `Owned`/`Offered` semantics fixed above, not on L2's coincidence claim.** Write
   to a separate preflight artifact; **never pool with protocol rows. If none fires, the exam is
   not measuring what it claims and this is STOP.**
4. **`thiefOfWicks` proc-path positive.** Within the same preflight band, assert at least one run
   in which `thiefOfWicksOwned > 0` **and** an unlit node was entered while owned, and that
   `thiefOfWicksProcs` is non-zero in exactly that case. A relic whose only effect site is the
   map must be shown to fire on the map before the exam can read its zero as a mechanism finding.
   If ownership occurs but no unlit node is ever entered while owned across the whole preflight
   band, report it as an availability finding and **STOP** — do not proceed and later attribute
   the zero to mechanism.
5. **Between-subjects proof.** Assert L2 and L3 terminal `rng` differ on a non-zero count of the
   shared cohort seed coordinates. This confirms in data what the CRN section asserts in prose
   and forecloses any later twin reading.
6. **Band disjointness.** Assert `8000–8255` and `9700–9749` are disjoint from every band in the
   table above and from every band registered in the ledger, and that protected `3000–5199` and
   reserve `5200–5399` are untouched.
7. **Harness-scope proof.** `git diff c28ae388 --name-only` touches only
   `research/issue-421-grammar-only/`, `docs/reviews/421/existing-grammar-l3-lock.md` and
   `tools/balance_sim.gd`. Assert it mechanically; do not trust the diff by eye.

## Files / functions for the later implementer

**Not edited by this lock. This lock does not implement.** Baseline tree
`c28ae38824f7ba2168b573002ab8b90dadd5bde1`. The L2 packet's edited copy at `51fe17db` is the
reference for the edits L2 already made; they are carried forward, not re-invented.

| Path | Symbol | Change |
|---|---|---|
| `tools/balance_sim.gd` | `simulate` | The defaulted `unlocks: PackedStringArray = PackedStringArray(["aspect2"])` parameter, exactly as already written in the L2 packet at `51fe17db`. Default-preserving; every existing caller stays byte-identical |
| `tools/balance_sim.gd` | `_fight` | Carried from L2: bump `_probe` on `EventTypes.RELIC_PROC` for the tracked combat relics. **`thiefOfWicks` is not one of them and must not be added here** |
| `tools/balance_sim.gd` | `_enter_node` | **New for L3.** On the `node.unlit` branch, bump `thiefOfWicksProcs` exactly when `run.has_relic("thiefOfWicks")` is true |
| `tools/balance_sim.gd` | relic offer sites | **New for L3.** Bump `<relic>Offered` for the tracked relics at the elite-reward, shop-stock and treasure paths. `_resolve_shop` currently bumps `Offered` for `stock["cards"]` only |
| `tools/balance_sim.gd` | `_finish` | Carried from L2 (`slain`, `perfects`), extended to carry the per-run `unlitVisited` and `embersSpent` values from `run.stats` into `_probe` |
| `research/issue-421-grammar-only/tools/` | new L3 arm runner | Extend the L2 runner: build the L2/L3 projections by passing `unlocks`; emit the card participation fields and the relic `Offered`/`Owned`/`Procs` fields per row |
| `research/issue-421-grammar-only/tools/` | new L3 analyser | Apply the frozen estimands, thresholds, bootstrap and decision rule. Emit the L2-arm cumulative reachability report |
| `research/issue-421-grammar-only/protocols/` | — | `existing-grammar-l2-l3-v1.{md,json,sha256}` on the fresh identity. Every prior protocol file stays immutable |

Do **not** touch `content/`, `domain/`, `application/`, `presentation/`, `port_fixtures/`,
`tools/balance_metrics.gd`, `tools/balance_cem.gd`, `tools/balance_policy.gd`, or any closed
family's artefacts.

### Scope honesty on the harness

The L1 lock allowed one `tools/` change and called a second a STOP. The L2 lock recorded plainly
that it needed **three** edits in that one file rather than filing them under the existing
allowance. **L3 needs five, all still in that same one file, and this lock states that plainly
too.** Two of the five are carried unchanged from L2; three are new, and two of those three exist
only because `thiefOfWicks` fires on the map rather than in combat.

The reason it is nonetheless admissible is mechanical, not rhetorical:
`tools/balance_sim.gd` › `outcome_digest` computes its hash on a copy with
`copy.erase("packageEvents")` (line 537). `_probe` is returned as `packageEvents` and nothing
else (line 513). Therefore relic proc counts, relic offer counts and the
`unlitVisited`/`embersSpent` snapshot ride a channel that is **provably excluded from the
digest**, and preflight assertion 1 proves it rather than assuming it. Every edit sits inside a
loop or function that already executes; none reads the RNG, allocates in a decision path, or
changes control flow.

**The `_enter_node` bump is the one to scrutinise**, because unlike L2's edits it sits on the map
path rather than inside a combat event sweep. It must be a pure `_bump` on the existing
`node.unlit` branch — no reordering, no new RNG draw, no change to the bounty arithmetic. If it
cannot be written that way, that is **STOP, not a smaller edit.**

If preflight assertion 1 fails, this reasoning was wrong and that is **STOP, not a smaller
edit.**

**Anchor-gate warning, from L1's own history.** `existing-grammar-l0-l1-v1` had to be corrected
to `v2` because adding the `simulate` signature displaced a documentation anchor by one line. The
L2 packet absorbed its additions by removing blank lines to hold line counts stable. Run
`python3 tools/check_anchors.py` after every edit to `tools/balance_sim.gd`, before freezing the
protocol SHA — not after.

## PASS

All of:

1. The preflight passes in full, including the L3 consumer-firing positive on `9700–9749` and
   the `thiefOfWicks` map-proc positive.
2. L3 shows positive win complementarity at **both** Vow 0 and Vow 5.
3. Pooled win complementarity `≥ +0.02`.
4. Pooled bootstrap positive-sign agreement `≥ 0.90`.
5. Activation is natural — the frozen activation disjunction holds on `≥ 5%` of the 512 L3 rows
   at each vow, and participation is not concentrated in a handful of coordinates.
6. The L2-arm cumulative reachability report is emitted and is not implausible on its face.
7. Zero errors, zero additional stalls, zero protected/reserve rows, zero product mutations.

Verdict: **the existing grammar expresses a Duskblade package at L3.** The family becomes a
candidate for the P9 package-support requirement, and no new primitive is justified on this
evidence. Promotion, detector work and the second Ash package remain outside this lock.

A PASS at L3 says nothing retroactive about L1 or L2. L1's pair remains FAIL CLOSED; L2 remains
INCONCLUSIVE and does **not** become a closure by contrast. What would have passed is the larger
authored set, and the report must attribute the difference to the specific ids that carry it —
including whether the carrier is a `darkWalker` id, a `spendthrift` id, or the interaction.

## FAIL CLOSED

Any of:

- L3 fails any of PASS 2–5 on a complete, valid, integrity-clean matrix. **The authored
  `darkWalker` + `spendthrift` unlocks do not convert activation into win complementarity
  either.** Report the levels and bounds; do not retune, do not escalate the deed set inside this
  identity, do not reach past the ranking.
- Participation shows the L3 consumers never activate naturally despite firing in preflight.
  Report as an availability finding, not as a mechanism finding.

**A FAIL CLOSED here closes L3 only.** Stated explicitly because this is where the pressure will
be:

- **It does not authorise a new primitive.**
- **It does not complete the issue's second success condition.** That condition requires L1, L2
  and L3 each run and each *failed closed*. L2 is INCONCLUSIVE, not failed closed. Two graded
  closures and one ungraded level is not three closures, and no report may present it as one.
- It does not close the surface, and it does not retroactively grade L2.
- It does not authorise a P9 edit, a denominator change, or a detector.

The honest reading of an L3 FAIL CLOSED is: *two of three enumerated levels have been graded and
neither converted; the third was measured but never graded on an integrity fault.* That is a
strong signal about the grammar and it is still not the evidenced statement the issue asks for.

## STOP (nothing measured; report before running)

- Any preflight assertion fails.
- The baseline digest does not reproduce.
- `additionalStalls > 0` on the completed matrix. Report `STOP`, grade nothing, and do not raise
  the budget. A fresh diagnosis registration is required and this lock does not grant one.
- Any change to `content/`, `domain/`, `application/`, `presentation/`, `port_fixtures/`, or any
  `tools/` file other than `tools/balance_sim.gd`, turns out to be required.
- The `turnCeiling` separation would have to be landed to complete the exam.
- A required instrumentation field cannot be carried on the digest-erased `packageEvents`
  channel, or `thiefOfWicksProcs` / `thiefOfWicksOffered` cannot be recorded without a
  control-flow change.
- Any seed, policy, vow, estimand, threshold or bound would have to move.
- `python3 tools/check_anchors.py` fails after the harness edit and cannot be resolved without a
  semantic change.
- The fresh protocol identity is not authorised.
- An authored id in `darkWalker` or `spendthrift` — or any id in the L2 control array — would
  have to be dropped to make an arm work.

## What not to do

- Do not **parameter-rescue**: thresholds, vow set, seed bands, deed thresholds, the bootstrap
  root and the reliability budget are frozen.
- Do not **drop an authored id** from either new deed, or from the L2 control array, to shape an
  arm.
- Do not **twin-match**. Do not read an L2 row as a per-row causal twin of its L3 coordinate; the
  arms diverge from the first normal-combat card reward.
- Do not reopen or pool **sealed families** — STREAM-B, Emberglass Memory, Kindle,
  ward-mirror-edge, Stun-in-Shatter, P9/#108, #461, or any capacity-closed family. `emberdance`
  granting Ward is not a STREAM-B reopen and is not a licence to look at one; `spendthrift` is not
  Emberglass Memory.
- Do not **edit P9 / #108**, any denominator, estimand, threshold or bound.
- Do not **push**, open a **PR**, or merge.
- Do not **implement** under this lock, and do not **run rows** under this lock.
- Do not **re-run L2** under this or any identity. Branch 1 did not fire; a same-identity L2
  re-run is not authorised.
- Do not restate L2's **ungraded** scientific numbers as a result, a closure, or a prior that
  carries evidential weight.
- Do not treat an L3 FAIL CLOSED as authority for a **new primitive**, or as the third closure the
  issue's success condition requires.
- Do not design or tune a **new card, relic, effect kind, special, status or system**. Nothing in
  `content/` or `domain/`.
- Do not include **`lanternFed`** or any Kindle id, and do not include `ashSermon` — it stays
  reserved, unspent, for a later Ash exam.
- Do not **unbundle Stun from Shatter**, and do not lift the `run.aspect != 0` guard in
  `apply_chips`.
- Do not touch **acceptance seeds `3000–5199`** or **reserve `5200–5399`**.
- Do not treat a passing L3 as a **P9 claim**. It is one package candidate; P9 needs two per
  aspect and gated vow, and Ash's second package is untouched by this lock.

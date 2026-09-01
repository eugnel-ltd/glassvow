# Existing-grammar L2 registration — #421 surface (b), level L2

## Status

**DESIGN LOCK ONLY. Not implemented. Zero rows run. No P9 claim. No detector, holdout,
protected seed or promotion authorised. This lock edits zero lines of the harness and zero
lines of product content.**

This is a **fresh registration for L2 only**. It is not an amendment to the L1 lock, not a
correction of the L1 protocol, and not a rescue of the L1 result.

Level ordering, arms, estimands and thresholds were frozen before the L1 exam ran and are
re-used here unchanged. What this lock adds is exactly one thing: authority to run the next
level in that frozen ranking, against the deed unlocks the game already ships.

> **L1 FAIL CLOSED is immutable and is not a tuning target.** No number, bound, band, policy
> or estimand is moved in order to give L2 a better chance than L1 had.

## Authority and inputs

Read and measured in-session out of the trees named, at the heads named. Nothing here is
restated from a summary.

| Fact | Value |
|---|---|
| Binding current-main source | `c28ae38824f7ba2168b573002ab8b90dadd5bde1` |
| Repo | `fol2/glassvow` |
| This lock's worktree | `.claude/worktrees/421-existing-grammar-l2-lock` |
| This lock's branch | `claude/421-existing-grammar-l2-lock` |
| Prior L1 design lock (READ, not rewritten) | `.claude/worktrees/421-existing-grammar-expression-lock/docs/reviews/421/existing-grammar-expression-lock.md`, commit `a19e6a33dc75f14a7aa2d9417c822d126ed6b5d2`, sha256 `1ad052834150888c620d6656f387b95a1e3b0110257fc01e9bc648e15dee3daf` |
| L1 exam packet (READ, immutable) | `.codex/worktrees/421-existing-grammar-l1`, head `5387c9b6` |
| L1 protocol identity | `existing-grammar-l0-l1-v2`, json sha256 `051e7935155426042a8d59e4a716ecc8975449b17722448445e543b252fc4789` |
| Content DB read | `content/full-content.json` at `c28ae388` |
| Engine read | `domain/rules/rewards.gd`, `domain/rules/combat.gd`, `domain/state/vigil_state.gd` at `c28ae388` |
| Harness read | `tools/balance_sim.gd` at `c28ae388`, and the L1 packet's edited copy |
| Frozen baseline outcome digest | `b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf` |

**Sealed and not reopened, reused or pooled anywhere in this lock:** STREAM-B
(`spend-Ward`/`facetBurst`, p9-w0-v4, FAIL CLOSED, causal, `Played=0`), Emberglass Memory,
Kindle, EP4 ward-mirror-edge (VETO), Stun-in-Shatter, P9/#108, #461, and the four
capacity-closed families (Dimmed v1, Chisel/Splinter/Glass Rain v2, the v4 follow-up guard,
Three Disciplines + Eclipse v5). `lanternFed` and Kindle remain excluded from the deed set.

## What L1 established, stated as the prior

The L1 exam is closed and its numbers are inputs here, not targets.

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

**Read this prior honestly, because it is unfavourable to L2.** L1 did not fail for want of
availability. The authored consumer was offered, drawn and played in roughly three rows in ten,
its gate was reachable, and the package still did not convert participation into win
complementarity. The failure mode L1 diagnosed in v1 — *the card was never in the projection* —
was repaired and did not recur.

So L2 is not being run because L1 looked close. L2 is being run because the ranking frozen in
the L1 lock enumerates it, because the L1 verdict explicitly closes **L1 only**, and because
the surface is not exhausted until every enumerated level has been measured. A registration
whose prior is unfavourable is still worth running when the alternative — declaring the surface
closed on an untested level — is exactly the invalid `(f)` disposition the L1 lock overturned.

**No pooling.** L1 rows, L1 cell means, the L1 seed band and the L1 bootstrap are never
combined with L2's. The two exams share thresholds so they can be *compared*; they do not share
data.

## Arms — frozen before any row

### L1 (control arm)

Exactly the array the L1 exam ran, verbatim, unchanged:

```
["aspect2", "card:quakeblow", "card:resonantLance"]
```

### L2 (treatment arm)

L1 **plus the complete authored `unlocks` array of `hundredShards` and `untouched`**. Both
deeds are taken whole. No authored id is dropped, deferred or substituted.

Cited from `content/full-content.json` › `deeds` at `c28ae388`:

```json
"untouched":      { "stat": "perfects", "n": 3,   "unlocks": ["card:flawlessForm", "relic:prismCharm"] },
"hundredShards":  { "stat": "slain",    "n": 100, "unlocks": ["card:shardstorm",   "relic:bellOfEndings"] }
```

Frozen L2 array, in this exact order (the order is load-bearing — see CRN below):

```
["aspect2", "card:quakeblow", "card:resonantLance",
 "card:shardstorm", "relic:bellOfEndings",
 "card:flawlessForm", "relic:prismCharm"]
```

Four ids added. Deed order is `hundredShards` then `untouched`; within a deed, the authored
array order is preserved. This matches the L1 lock's ranking row for L2 (`+4`) exactly.

### The four added ids, cited from content

| Id | Kind | Rarity | Cost | Authored effect | Deed |
|---|---|---|---:|---|---|
| `shardstorm` | attack | rare | 3 | `dmg 5 ×2` to `allEnemies` | `hundredShards` |
| `bellOfEndings` | relic | rare | — | on any Shatter, every other living enemy takes 4 | `hundredShards` |
| `flawlessForm` | skill | rare | 1 | `special flawless n=8` — Ward 8, doubled if unscratched this combat | `untouched` |
| `prismCharm` | relic | rare | — | first Shatter each combat spills 2 extra Embers | `untouched` |

**`flawlessForm` is not a STREAM-B reopen and must never be read as one.** STREAM-B tested a
*proposed* `spend-Ward` primitive and `facetBurst`, and it is sealed. `flawlessForm` is an
already-authored card that has shipped in `content/full-content.json` since before that family
existed; it enters here only because dropping it would mean running a partial `untouched`,
which this lock forbids. Nothing in L2 spends Ward, and no STREAM-B artefact, threshold, seed or
row is touched, cited or pooled.

### Why these ids have never been measured

`content/full-content.json` gives all four a `"locked"` field and lists none of them in any
pool array. Verified mechanically at `c28ae388`:

- `cardPools.rare` (12 ids) contains neither `shardstorm` nor `flawlessForm`.
- `relicPools.rare` (5 ids) contains neither `bellOfEndings` nor `prismCharm`.

`domain/rules/rewards.gd` › `card_pool` / `relic_pool` is the sole path in: after filtering the
base array through `_pool_open`, each function walks `run.unlocks` and appends an id when the
prefix matches (`card:` / `relic:`) **and the id's own `rarity` equals the requested tier**.
This is the same defect the L1 lock named, extended to the four ids L1 did not carry.

Both relics are additionally gated at the point of use, in `domain/rules/combat.gd` ›
`_shatter_enemy`: `run.has_relic("prismCharm")` and `run.has_relic("bellOfEndings")`. Under L0
and L1 these branches are unreachable dead code. Under L2 they are reachable **only if the relic
is actually offered and taken** — which is why relic attribution below cannot stop at ownership.

## The contrast

**Incremental on top of L1, between-subjects.** The contrast is L1 vs L2. It is not L0 vs L2,
and L0 does not appear in this exam.

| Dimension | Frozen at |
|---|---|
| Arms | L1 (control), L2 (treatment) |
| Aspect | `duskblade` only |
| Vows | 0 and 5 |
| Policies | 2 witnesses — the competent panel policy and the RandomBuild control, identical across arms |
| Seeds | 256 fresh seeds, band **7000–7255** |
| Rows | 2 × 2 × 2 × 256 = **2,048** — the same capacity budget L1, v4 and v5 used |
| Correction cap | 2 corrected versions, per the issue's default family rule |
| Protected / reserve seeds | `0`. Acceptance `3000–5199` and reserve `5200–5399` are untouched |

Cell order for every complementarity, carried across from the L1 protocol with the arms
relabelled and nothing else changed:

| Cell | Meaning |
|---|---|
| `PC` | L2 competent |
| `P` | L2 RandomBuild |
| `C` | L1 competent |
| `O` | L1 RandomBuild |

Complementarity is `PC - P - C + O`, formed from four cell means. **No per-row causal twin
effect is formed.**

### CRN — stated honestly before the run

`card_pool` and `relic_pool` rebuild their arrays in order, and `gen_combat_rewards` draws
`crng.pick_index(pool.size())`.

Measured at `c28ae388`, the L1→L2 step changes pool **sizes**, not merely contents:

| Pool | L1 | L2 |
|---|---:|---:|
| `card_pool(rare)` | 12 base + `resonantLance` = 13 | 12 base + `resonantLance` + `shardstorm` + `flawlessForm` = 15 |
| `card_pool(uncommon)` | 17 base + `quakeblow` = 18 | unchanged, 18 |
| `relic_pool(rare)` | 5 base = 5 | 5 base + `bellOfEndings` + `prismCharm` = 7 |

Because unlocked ids are appended **after** the base array and in `run.unlocks` order, the frozen
L2 ordering above preserves `resonantLance` at rare index 12 and `quakeblow` at uncommon index
17 in both arms. That is a tidy property and it is **not** a claim of shared trajectory: the
rare card pool and the rare relic pool change size, so `pick_index` returns different draws from
the first rare reward onward, and the runs diverge from there.

**This is a between-subjects contrast. CRN pins the seed, not the trajectory.** The seed band is
shared across arms for variance reduction only.

**Do not twin-match.** Anyone who later reads an L1 row as a same-trajectory twin of its L2
coordinate has repeated the exact error the STREAM-B v3 attribution instrument made, and this
paragraph exists so that cannot be done silently. Per-row causal attribution comes from
participation, not from twin lookup.

## Estimands and thresholds — carried across verbatim

**Not re-decided here. Not retuned. Reusing the numbers that closed four families and then L1
is the only way this exam can be compared to them, and it removes any room to tune a pass.**

| Estimand | Definition |
|---|---|
| `winComplementarity` | Per vow, `Pr(win)[PC] - Pr(win)[P] - Pr(win)[C] + Pr(win)[O]` |
| `pooledWinComplementarity` | Arithmetic mean of the Vow-0 and Vow-5 win complementarities |
| `activationComplementarity` | Per vow, the same four-cell form on `Pr(<id> activated > 0)` |
| `participation` | `Offered`, `Drawn`, `Played`, `InDeck` per row for the tracked cards; `Offered`, `Owned`, `Procs` per row for the tracked relics |
| `deedReachability` | Within the **L1** arm, the per-run distributions of `slain` and `perfects`, and the derived cumulative runs-to-threshold |

| Threshold | Value |
|---|---|
| Pooled win complementarity | `≥ +0.02` |
| Win complementarity at each vow | strictly positive at **both** Vow 0 and Vow 5 |
| Bootstrap positive-sign agreement | `≥ 0.90` |
| Natural activation rate | at each vow, `≥ 5%` of the 512 L2 rows |
| Positive-sign convention | strictly greater than zero |

Statistics, carried across unchanged from `existing-grammar-l0-l1-v2`:

- Bootstrap: 2,000 resamples, whole-seed-block, sampling 256 seed blocks with replacement; each
  block retains all arms, policies and vows; cell means computed before `PC - P - C + O`.
- Bootstrap seed root: derived for this identity as `4217000` (the L1 root `4216000` is spent and
  is not reused; the increment is the only new number in this section and it selects a stream, not
  a result).
- Interval: two-sided 95% percentile, sorted indices `floor(0.025B)` and `ceil(0.975B)-1`.
- Rate interval: two-sided Wilson 95%. Quantiles: nearest-rank.

Reliability budget, unchanged: `errorsAllowed 0`, `productMutationsAllowed 0`,
`protectedReserveRowsAllowed 0`, `additionalStallsAllowed 0`, where additional stalls are
`sum over cells of max(0, L2 stalls - L1 stalls)`.

## Attribution

The v4 participation instrument, extended to the ids L2 adds. Keyed per row.

**Cards** — `<card>Offered`, `<card>Drawn`, `<card>Played`, `<card>InDeck`:

- `resonantLance` — **still tracked.** It is the L1 consumer and its behaviour under a larger
  pool is the direct comparison to the L1 result.
- `quakeblow` — the L1 producer, tracked for the same reason.
- `shardstorm` — L2-added.
- `flawlessForm` — L2-added.

**Relics** — `<relic>Offered`, `<relic>Owned`, `<relic>Procs`:

- `bellOfEndings` — L2-added.
- `prismCharm` — L2-added.

**Ownership is not participation, and this is the one instrument question L2 has that L1 did
not.** A relic that is drafted and never fires is exactly the "availability, not mechanism"
confound the L1 lock was written to prevent, so the count of firings is required, not optional.
The hook already exists: `domain/rules/combat.gd` › `_proc(cb, relic_id)` appends
`{"t": EventTypes.RELIC_PROC, "id": relic_id}` for both relics inside `_shatter_enemy`.

Consumer-activation predicate for the L2 arm, frozen:

```
resonantLancePlayed > 0  OR  shardstormPlayed > 0  OR  flawlessFormPlayed > 0
  OR  bellOfEndingsProcs > 0  OR  prismCharmProcs > 0
```

The per-id rates are reported individually as well as under this disjunction; the disjunction is
the gate, the per-id rates are the reading.

## Deed reachability — cumulative, and why the L1 rule cannot be transplanted

`paneBreaker` (`shatters ≥ 15`) was measurable as a per-run witness, and L1 measured it that
way. **L2's two deeds cannot be.** Measured at `c28ae388`:

- `domain/rules/combat.gd` increments `run.stats["slain"]` (line ~616) and
  `run.stats["perfects"]` (line ~514) — per run.
- `domain/state/vigil_state.gd` (lines ~196-200) folds `slain`, `shatters`, `kindles`,
  `perfects`, `smolderKills`, `unlitVisited`, `embersSpent` from `run.stats` into the persistent
  `deeds` dictionary at run end — **across runs**.

So `hundredShards` (`slain ≥ 100`) and `untouched` (`perfects ≥ 3`) are cumulative
meta-progression thresholds. A per-run `slain ≥ 100` gate would be a gate that can essentially
never fire, and adopting one would manufacture a failure that says nothing about the mechanism.
*A gate that has never seen a positive is not a gate* — the v2 lock's rule, applied in the
direction that costs the treatment arm nothing it has earned.

**Frozen reachability rule for L2, measured off the L1 arm:**

1. Report the per-run distribution of `slain` and of `perfects` (mean, nearest-rank quartiles,
   max), per vow and pooled.
2. Report the implied cumulative runs-to-threshold: `ceil(100 / mean slain per run)` and
   `ceil(3 / mean perfects per run)`.
3. Report the fraction of L1 runs contributing a non-zero amount to each stat.

This is a **required reported output**, not a pass/fail threshold, and it is deliberately not
one. Turning a cumulative meta-progression stat into a per-exam bound would be inventing a
threshold, which this lock does not do. What it does do is make the answer to "is a player ever
actually in the L2 state?" a printed number rather than an assumption. If the reported
runs-to-threshold is implausible for a real player, the exam says so in its report and that
finding travels with the verdict.

`slain` and `perfects` are not currently emitted per row; see the harness note below for the
digest-inert channel that carries them.

## Protocol identity

**Fresh identity. No prior protocol file is edited, superseded or reinterpreted.**

| Field | Value |
|---|---|
| `protocolId` | `existing-grammar-l1-l2-v1` |
| Files | `research/issue-421-grammar-only/protocols/existing-grammar-l1-l2-v1.{md,json,sha256}` |
| Relationship to L1 | Successor level under the same frozen ranking. **Not** a correction of `existing-grammar-l0-l1-v2`, which stays immutable with its 2,048 rows and its FAIL CLOSED verdict |
| Correction cap | 2 |

### Seed bands

| Band | Range | Size | Use |
|---|---|---:|---|
| Cohort | **7000–7255** | 256 | The 2,048 protocol rows |
| Positive preflight | **9600–9649** | 50 | Preflight consumer-firing sweep only; never pooled with protocol rows |

Disjointness, asserted mechanically in preflight, against every band named in the binding and in
the L1 protocol's `seedBands`:

| Prior band | Range | vs 7000–7255 | vs 9600–9649 |
|---|---|---|---|
| Protected acceptance | 3000–5199 | disjoint | disjoint |
| Reserve | 5200–5399 | disjoint | disjoint |
| Prior STREAM-B v4 cohort | 4000–4199 | disjoint | disjoint |
| Prior STREAM-B v4 preflight | 9000–9049 | disjoint | disjoint |
| L1 cohort | 6000–6255 | disjoint | disjoint |
| L1 positive preflight | 9500–9549 | disjoint | disjoint |

## Zero-row preflight

Runs before any cohort row exists; emits no protocol row. **Failure of any assertion is STOP,
not FAIL CLOSED** — nothing has been measured yet.

1. **Baseline digest sentinel.** One row on the stock projection (`["aspect2"]`, `duskblade`,
   vow 0, seed 1000) reproduces
   `b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf` exactly. This is the whole
   proof that the defaulted `unlocks` parameter — and every instrumentation field added for this
   exam — is inert. If it does not match, stop and report.
2. **Pool-delta proof, zero rows, L1 vs L2 only.** Direct calls on a constructed `RunState`, no
   simulation. Under L1, `card_pool(run,"rare")` contains neither `shardstorm` nor
   `flawlessForm`, and `relic_pool(run,"rare")` contains neither `bellOfEndings` nor
   `prismCharm`; under L2, all four are present at exactly those tiers. **Assert that the only
   ids differing between the two projections, at any card tier and any relic tier, are those
   four.** `quakeblow` and `resonantLance` are present in both arms and must not appear in the
   delta.
3. **At least one L2 consumer fires, on the disjoint preflight band.** Sweep seeds
   **9600–9649** (outside every band in the table above) on the L2 projection, Duskblade,
   competent policy, vow 0, until at least one run satisfies the frozen activation disjunction.
   Assert the implications `Played > 0 ⇒ Drawn > 0 ⇒ Offered > 0` for each tracked card and
   `Procs > 0 ⇒ Owned ⇒ Offered` for each tracked relic. Write to a separate preflight artifact;
   **never pool with protocol rows. If none fires, the exam is not measuring what it claims and
   this is STOP.**
4. **Between-subjects proof.** Assert L1 and L2 terminal `rng` differ on a non-zero count of the
   shared cohort seed coordinates. This confirms in data what the CRN section asserts in prose
   and forecloses any later twin reading.
5. **Band disjointness.** Assert `7000–7255` and `9600–9649` are disjoint from every band in the
   table above and from every band registered in the ledger, and that protected `3000–5199` and
   reserve `5200–5399` are untouched.
6. **Harness-scope proof.** `git diff c28ae388 --name-only` touches only
   `research/issue-421-grammar-only/`, `docs/reviews/421/existing-grammar-l2-lock.md` and
   `tools/balance_sim.gd`. Assert it mechanically; do not trust the diff by eye.

## Files / functions for the later Codex implementer

**Not edited by this lock. This lock does not implement.** Baseline tree
`c28ae38824f7ba2168b573002ab8b90dadd5bde1`.

| Path | Symbol | Change |
|---|---|---|
| `tools/balance_sim.gd` | `simulate` | The defaulted `unlocks: PackedStringArray = PackedStringArray(["aspect2"])` parameter, exactly as already written in the L1 packet at `5387c9b6`. Default-preserving; every existing caller stays byte-identical |
| `tools/balance_sim.gd` | `_fight` | In the **existing** `for event in game.cb.queue` loop that already counts `smolderKills`, additionally bump `_probe` on `EventTypes.RELIC_PROC` for the two tracked relic ids |
| `tools/balance_sim.gd` | `_finish` | Carry the per-run `slain` and `perfects` values from `run.stats` into `_probe` |
| `research/issue-421-grammar-only/tools/` | new L2 arm runner | Extend the L1 runner: build the L1/L2 projections by passing `unlocks`; emit the card participation fields and the new relic `Offered`/`Owned`/`Procs` fields per row |
| `research/issue-421-grammar-only/tools/` | new L2 analyser | Apply the frozen estimands, thresholds, bootstrap and decision rule. Emit the L1-arm cumulative reachability report |
| `research/issue-421-grammar-only/protocols/` | — | `existing-grammar-l1-l2-v1.{md,json,sha256}` on the fresh identity. Every prior protocol file stays immutable |

Do **not** touch `content/`, `domain/`, `application/`, `presentation/`, `port_fixtures/`,
`tools/balance_metrics.gd`, `tools/balance_cem.gd`, or any closed family's artefacts.

### Scope honesty on the harness

The L1 lock recorded that its exam needed exactly one `tools/` change and called any second one
a STOP. **L2 needs three edits, all in that same one file, and this lock states that plainly
rather than filing it under the existing allowance.**

The reason it is nonetheless admissible is mechanical, not rhetorical:
`tools/balance_sim.gd` › `outcome_digest` computes its hash on a copy with
`copy.erase("packageEvents")`. `_probe` is returned as `packageEvents` and nothing else.
Therefore relic proc counts and the `slain`/`perfects` snapshot ride a channel that is
**provably excluded from the digest**, and preflight assertion 1 proves it rather than assuming
it. Both edits sit inside loops and functions that already execute; neither reads the RNG,
allocates in a decision path, or changes control flow.

If preflight assertion 1 fails, that reasoning was wrong and this is **STOP, not a smaller
edit.**

**Anchor-gate warning, from L1's own history.** `existing-grammar-l0-l1-v1` had to be corrected
to `v2` because adding the `simulate` signature displaced a documentation anchor by one line.
Run `python3 tools/check_anchors.py` after every edit to `tools/balance_sim.gd`, before freezing
the protocol SHA — not after.

## PASS

All of:

1. The preflight passes in full, including the L2 consumer-firing positive on `9600–9649`.
2. L2 shows positive win complementarity at **both** Vow 0 and Vow 5.
3. Pooled win complementarity `≥ +0.02`.
4. Pooled bootstrap positive-sign agreement `≥ 0.90`.
5. Activation is natural — the frozen activation disjunction holds on `≥ 5%` of the 512 L2 rows
   at each vow, and participation is not concentrated in a handful of coordinates.
6. The L1-arm cumulative reachability report is emitted and is not implausible on its face.
7. Zero errors, zero additional stalls, zero protected/reserve rows, zero product mutations.

Verdict: **the existing grammar expresses a second Duskblade package at L2.** The
Shatter-consumer family becomes a candidate for the P9 package-support requirement, and no new
primitive is justified on this evidence. Promotion, detector work and the second Ash package
remain outside this lock.

A PASS at L2 says nothing retroactive about L1. L1's pair remains FAIL CLOSED; what would have
passed is the larger authored set, and the report must attribute the difference to the specific
ids that carry it.

## FAIL CLOSED

Any of:

- L2 fails any of PASS 2–5. **The authored `hundredShards` + `untouched` Shatter consumers do
  not convert activation into win complementarity either.** Report the levels and bounds; do not
  retune, do not escalate the deed set inside this identity, do not reach for L3 without a fresh
  registration.
- Participation shows the L2 consumers never activate naturally despite firing in preflight.
  Report as an availability finding, not as a mechanism finding.

**A FAIL CLOSED here closes L2 only.** It does not close the surface, it does not auto-authorise
L3, and — stated explicitly because this is where the pressure will be — **it does not authorise
a new primitive.** L3 (`spendthrift` + `darkWalker`) remains enumerated, ranked and untested. The
issue's second success condition requires L1, L2 **and** L3 each run and each failed closed
before "the existing grammar cannot express the required complementarity" is an evidenced
statement.

If L2 fails closed with high participation, as L1 did, the honest reading is that two of three
enumerated levels have now converted availability into a real mechanism test and neither
converted. That is a strong signal and it is still not the third level.

## STOP (nothing measured; report before running)

- Any preflight assertion fails.
- The baseline digest does not reproduce.
- Any change to `content/`, `domain/`, `application/`, `presentation/`, `port_fixtures/`, or any
  `tools/` file other than `tools/balance_sim.gd`, turns out to be required.
- A required instrumentation field cannot be carried on the digest-erased `packageEvents`
  channel.
- Any seed, policy, vow, estimand, threshold or bound would have to move.
- `python3 tools/check_anchors.py` fails after the harness edit and cannot be resolved without a
  semantic change.
- The fresh protocol identity is not authorised.
- An authored id in `hundredShards` or `untouched` would have to be dropped to make the arm work.

## What not to do

- Do not run **L3** under this registration. Cheapest decisive gate first, one level at a time.
- Do not design or tune a **new card, relic, effect kind, special, status or system**. Nothing
  in `content/` or `domain/`.
- Do not treat a FAIL CLOSED at L2 as authority for a **new primitive**. L3 is untested.
- Do not attempt an **L1 rescue**. L1 is closed, immutable, and is not a tuning target; do not
  re-run it, re-analyse it, re-band it, or pool its rows with L2's.
- Do not reopen or pool **STREAM-B**, **Emberglass**, **Kindle**, **ward-mirror-edge**,
  **Stun-in-Shatter**, **P9/#108**, **#461**, or any capacity-closed family. `flawlessForm`
  granting Ward is not a STREAM-B reopen and is not a licence to look at one.
- Do not touch **P9 / #108**, any denominator, estimand, threshold or bound.
- Do not include **`lanternFed`** or any Kindle id. Do not include `ashSermon` — it stays
  reserved, unspent, for a later Ash exam.
- Do not **unbundle Stun from Shatter**, and do not lift the `run.aspect != 0` guard in
  `apply_chips`.
- Do not **parameter-rescue**: thresholds, vow set, seed bands and deed thresholds are frozen.
- Do not touch **acceptance seeds `3000–5199`** or **reserve `5200–5399`**.
- Do not read an L1 row as a **twin** of its L2 coordinate. The arms diverge from the first rare
  reward.
- Do not treat a passing L2 as a **P9 claim**. It is one package candidate; P9 needs two per
  aspect and gated vow, and Ash's second package is untouched by this lock.
- Do not **drop an authored id** from either deed to shape the arm.

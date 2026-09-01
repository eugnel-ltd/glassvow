# STREAM-B attribution repair lock — #421

## Status

**DESIGN LOCK ONLY. Not implemented. Not a P9 claim. No landscape authorised. This lock ran zero
rows and edits zero lines of the harness.**

The p9-w0-v3 Phase A VETO stands. This lock names one defect in the v3 *attribution instrument*,
one repair, and the preregistered conditions for exactly one matched re-exam of the affected
cohort. It designs no card, no relic and no system, and it moves no bound.

Scope boundary, unchanged: Dusk keeps its stun/shatter identity, Stun stays inside Shatter, Ash
stays burn-only, the P9/#108 bar is untouched, and #421 remains the single integration boundary.

## Evidence this lock is built on

Read and measured in-session out of the on-disk artifacts, not restated from a summary.

| Fact | Value |
|---|---|
| current-main source | `c28ae38824f7ba2168b573002ab8b90dadd5bde1` |
| STREAM-B v3 implementation head | `07533cc3b870d2a673d2b8d5edbb7e6f8bc3036a` |
| STREAM-B v3 execution head | `974fc71ef162eeb9e7d6a774bafd81a3cc782884` |
| Protocol SHA-256 | `1321b143e42187e9f1c81f4cb15c671728e0939f72ea96af4ce8c09c03f331b3` |
| Worktree read | `/Users/jamesto/.codex/worktrees/421-stream-b-reliability-v3/glassvow`, branch `codex/421-stream-b-reliability-v3` |
| Artifacts | `research/issue-421-grammar-only/artifacts/p9-w0-v3-phase-a/` at `974fc71e` — `phase-a-result.json`, `raw-rows.jsonl` (6400 rows) |
| Prior lock | `docs/reviews/421/stream-b-reliability-lock.md` (the v2→v3 reliability lock) |

Run outcome: **VETO**, 6400/6400 rows, 0 simulator errors, 228.14 s, sole reason
`"unmatched turnCeiling in 6 row(s)"`. Every rate bound held: Dusk arm-3 control 3/400 = 0.75%
against a 2.0% bound vetoing at 9; whole-run 10/6400 = 0.156% against a 0.5% bound.

**The rate bounds are not the problem and are not touched anywhere in this lock.** The single
failing gate is attribution.

## Diagnosis of the unmatched-6 gap

### What the v3 matcher asks

In `p9_w0_v2_phase_a.py` (`_reliability`, at `974fc71e`) the harness indexes every arm-3
`null-card` comparator row by `(aspect, vow, seed)`, then walks every `turnCeiling` row in the
6400 and marks it unmatched unless its arm is 3 **and** the null-card row at that same
`(aspect, vow, seed)` also hit the ceiling. The key carries no `variant`, no `cohort` and no
policy.

### What the 6400-row matrix actually contains

From `p9_w0_v2_phase_a_rows.gd` (`_write_panel`, `_write_row`, at `974fc71e`) the matrix holds four
variants over **two different ContentDBs**:

| variant | cohort | ContentDB | `wardSurplus` |
|---|---|---|---|
| `omitted` | control | candidate (`ContentDB.load_full`) | 4.5 (default) |
| `explicit-off` | comparator | candidate | 0.0 (forced) |
| `current-main` | comparator | pre-candidate tree | 4.5 |
| `null-card` | comparator | candidate **minus `facetBurst`** | 4.5 |

Note the variant names describe the *policy override*, not the card: `omitted` means the policy
dict is empty, and it runs the **candidate** content with `facetBurst` present. Only `null-card`
and `current-main` run content without the candidate card.

Measured over all 400 arm-3 duskblade coordinates (200 seeds × 2 vows):

| Pairing | terminal `rng` identical | `outcome` identical | `outcomeDigest` identical |
|---|---|---|---|
| `current-main` vs `null-card` | **400/400** | 400/400 | **400/400** |
| `omitted` vs `explicit-off` | **400/400** | 400/400 | **0/400** |
| `omitted` vs `current-main` | **13/400** | — | — |

So the matrix contains two execution families, not four variants. Within a family the runs are the
same execution; across families they are different executions that merely share a seed.

### The matcher's pass condition is family membership, not causation

All ten v3 ceilings are arm 3, duskblade. They separate perfectly by family:

| coordinate | `omitted` | `explicit-off` | `current-main` | `null-card` | matcher verdict |
|---|---|---|---|---|---|
| vow 0 seed 4060 | loss | loss | **turnCeiling** | **turnCeiling** | matched ×2 |
| vow 0 seed 4096 | loss | loss | **turnCeiling** | **turnCeiling** | matched ×2 |
| vow 0 seed 4151 | **turnCeiling** | **turnCeiling** | loss | loss | unmatched ×2 |
| vow 5 seed 4064 | **turnCeiling** | **turnCeiling** | loss | loss | unmatched ×2 |
| vow 5 seed 4079 | **turnCeiling** | **turnCeiling** | loss | loss | unmatched ×2 |

The four "matched" rows are exactly the four rows drawn from the oracle's own projection: a
`null-card` ceiling matches **itself** (it is present in its own twin index), and a `current-main`
ceiling matches because current-main is byte-identical to null-card at 400/400. The six "unmatched"
rows are exactly the six candidate-content rows.

**The v3 test's output is a deterministic function of `variant`. Not one bit of information about
the candidate card enters it.** Its pass condition is unreachable for every row whose attribution
actually matters, and trivially satisfied for every row whose attribution is already known. Had the
families ceilinged in the opposite pattern the verdict would have been identical, with the labels
swapped.

### Why the counterfactual it assumes cannot exist

The test presumes the null-card row is a *same-trajectory twin* — that CRN pins the trajectory and
only the treatment differs. It does not. `_null_card_content` erases `facetBurst` from
`content.cards` and from every entry of `content.card_pools`. In `domain/rules/rewards.gd`
(`card_pool`) the pool array is rebuilt from that base in order, and in `gen_combat_rewards` the
offer is `crng.pick_index(pool.size())`. Removing one id therefore shifts the index→id mapping for
every id after it: the same RNG draw yields a different offered card, the pilot drafts a different
deck, and the run diverges from its first card reward onward. The 13/400 cross-family `rng`
agreement above is that divergence measured.

A fixed seed pins the **seed**, not the **trajectory**, once content changes. The v3 comparison is
a between-subjects comparison wearing a within-subjects name, and no key repair fixes that — the
twin it wants to look up was never executed and cannot be, because any content edit that removes
the card also moves the trajectory.

**Answer to the question asked:** the gap is not in the twin matching keys. It is in **null-card arm
semantics** — the null-card projection is not a counterfactual for a candidate-content row — with a
second, smaller fault in the **key**, which omits `variant`, `cohort` and policy and so silently
resolves a wardSurplus-0.0 `explicit-off` ceiling against a wardSurplus-4.5 null-card row.

### Two secondary faults, both real, neither the root cause

**`unmatchedCount: 6` over-counts the incident by 2×.** The three unmatched coordinates each carry
one `omitted` and one `explicit-off` row with identical terminal `rng`, identical `outcome` and
identical `shatters`. There are **three executions**, observed twice each under different policy
labels. On arm 3 the wardSurplus override is trajectory-neutral at 400/400 coordinates — but it is
not neutral in general: on arm 1 it moves 7 of 400 trajectories and flips 1 outcome (vow 5 seed
4153). The neutrality is a measured fact about arm 3, not a property to rely on.

**`outcomeDigest` cannot serve as a trajectory identity.** In `tools/balance_sim.gd`
(`outcome_digest`) the digest hashes the whole result dict less `packageEvents`, and
`tools/balance_sim.gd` (`_result`) puts `"policy": Pilot.policy_snapshot()` inside that dict. The
policy label is therefore inside the fingerprint, which is why `omitted` vs `explicit-off` reads
0/400 identical while the underlying executions are the same. Any future harness that reaches for
`outcomeDigest` to prove two rows are the same run will get the wrong answer.

## Exact repair

**Replace an unanswerable predicate with an answerable one. Move no bound, no seed, no policy, no
estimand.**

A ceiling is attributable to the candidate only if the candidate participated in the run.
Participation is a within-run fact, needs no twin, and is **already instrumented on the current
tree** — the harness receives it and throws it away.

In `tools/balance_sim.gd` (`_bump`) the probe is keyed by card id at three offer sites
(`_claim_rewards`, the event-node card branch, `_resolve_shop`), at the draw branch and at the play
branch of `_harvest_fight`, and the whole probe is copied into `row["packageEvents"]` by
`tools/balance_sim.gd` (`_result`). Every run therefore already produces `facetBurstOffered`,
`facetBurstDrawn` and `facetBurstPlayed`, and `_result` already returns `deckIds`. The row writer
serialises only `facetBurstPlayed`.

*(Code-read claim, not yet executed: `facetBurstPlayed` is demonstrably live — the v2 lock reports
it at 105/400 on Dusk arm 1 — and `Offered`/`Drawn` are the same `_bump` mechanism at different
event kinds. The preflight below must prove all three fire before any cohort row is written.)*

### R1 — serialise what is already in hand (row writer, ~8 lines)

Add to the row dict, all read off the `row` the harness already holds:

- `facetBurstOffered`, `facetBurstDrawn` — from `packageEvents`, beside the existing
  `facetBurstPlayed`.
- `facetBurstInDeck` — `1` if `facetBurst` appears in `row["deckIds"]`, else `0`.
- `ceilingFight` — for a `turnCeiling` row only, the `{act, kind, enemies, turns}` of the fight in
  `row["fights"]` whose `result` is `turnCeiling`. Diagnostic; not a gate.
- `trajectoryDigest` — the digest recomputed in the harness over `row` with **both**
  `packageEvents` and `policy` erased. Diagnostic; this is what proves the six rows are three
  executions. Do **not** change `tools/balance_sim.gd` (`outcome_digest`) — compute it locally.

### R2 — the attribution test (analyser)

For each `turnCeiling` row:

```
participation = facetBurstOffered + facetBurstDrawn + facetBurstPlayed + facetBurstInDeck
candidate-free   <=> participation == 0
candidate-touched <=> participation  > 0
```

Veto on **candidate-touched at a count of one**, exactly as the v3 rule vetoed on unmatched at a
count of one. Retire the null-card twin lookup as a ceiling oracle. **Keep the null-card panel** —
it still carries the `currentMainNullCardPairsIdentical` identity check (400/400) and the
manufactured-activation check, and both stay.

The per-cell 2.0% / whole-run 0.5% bounds are **carried across verbatim**. They remain the correct
and only instrument for the routing channel described next.

### What this repair does and does not exonerate — stated before the run

Participation closes the **effect** channel: if the candidate was never offered, never drawn, never
held and never played, its rules text did not execute and the ceilinged run's card set exists
unchanged on current-main.

It does **not** close the **routing** channel. `facetBurst` sitting in the uncommon pool shifts the
`pick_index` mapping at `domain/rules/rewards.gd` (`gen_combat_rewards`), so the candidate
determines *which* seeds reach a ceiling even in runs it never enters. That is a distributional
property, not a per-row one, and it is precisely what the preregistered rate bounds measure — v3
scored 0.75% against 2.0% and 0.156% against 0.5%. No new instrument is needed and no number moves.
Anyone reading this repair as "the card is exonerated" has read half of it.

### This is a protocol amendment and must be honest about that

The frozen v3 rule said any unmatched ceiling vetoes. The run produced six. **VETO was the correct
application of the frozen rule.** Amending it on the same identity after seeing the result would be
post-hoc rescue.

It is admissible only because the v3 rule is *measurably incapable of the discrimination it claims
to make* — its verdict is a function of `variant` alone, shown above — and only on a **fresh
`p9-w0-v4` identity**, with v3's protocol, result and packet preserved immutable, never patched,
recoded, pooled or promoted. That is the pattern v1→v2→v3 already used, and it is the only form in
which this repair may proceed. **Ash's authorisation is required for the v4 identity; this lock
does not grant it.**

The new rule can fail. If any of the three executions shows participation > 0, v4 is FAIL CLOSED
and the repair has strengthened the finding rather than rescued it. A rule that cannot fail is not
worth adopting; this one can.

### Grammar check — the repair stays inside every stop condition

| Stop condition | Status |
|---|---|
| New keyword or effect grammar | Not needed. No `content/`, no `domain/`. |
| Hidden Ward semantics | Not needed. Ward untouched. |
| New card resolution model | Not needed. |
| Unbundling Stun from Shatter | Not needed, not proposed. |
| Changing P9/#108 | Not needed. Denominators and win-rate estimands numerically unchanged. |
| Any `tools/` change | **Not needed.** Unlike the v2→v3 repair, everything here lands inside `research/issue-421-grammar-only/`. |

If implementing this turns out to require any row in that table — in particular if the probe keys
do not exist and instrumenting them needs a `tools/` or `domain/` edit — **stop and report; do not
widen the scope.**

## Files / functions for the later Codex implementer

Not edited by this lock. Baseline tree is the v3 implementation head `07533cc3`, **not**
`c28ae388` — the `turnCeiling` token does not exist on main.

| Path | Symbol | Change |
|---|---|---|
| `research/issue-421-grammar-only/tools/p9_w0_v2_phase_a_rows.gd` | `_write_row` | R1. Serialise `facetBurstOffered`, `facetBurstDrawn`, `facetBurstInDeck`, `ceilingFight`, `trajectoryDigest`. Serialisation only — no new `Sim` call, no policy or content change. |
| `research/issue-421-grammar-only/tools/p9_w0_v2_phase_a.py` | `_reliability` | R2. Replace the `null_twins` lookup with the participation predicate. Keep `perCell` and `wholeRun` byte-for-byte. |
| `research/issue-421-grammar-only/tools/p9_w0_v2_phase_a.py` | `_analyse` | Veto text: `candidate-touched turnCeiling in N row(s)`. Keep every other veto clause unchanged. |
| `research/issue-421-grammar-only/tools/p9_w0_v2_phase_a.py` | `_preflight` | Extend with the four preflight assertions below. Keep the existing synthetic self-tests. |
| `research/issue-421-grammar-only/protocols/` | — | New `p9-w0-v4-phase-a` protocol + JSON + SHA. v3 files untouched. |

Do **not** touch `tools/balance_sim.gd`, `tools/balance_metrics.gd`, `tools/balance_cem.gd`,
`domain/`, `content/`, `presentation/`, `application/` or `port_fixtures/`.

## Zero-row preflight

Runs before any cohort row exists; emits no protocol row. Failure of any assertion is STOP, not
FAIL CLOSED — nothing has been measured yet.

1. **Harness-only proof.** `git diff 07533cc3 --name-only` touches zero paths outside
   `research/issue-421-grammar-only/`. This is the mechanical form of the scope promise; assert it,
   do not trust the diff by eye.
2. **The signal actually fires.** Execute one probe run at a seed **outside every protocol band**
   (not 4000–4199, not 5000–5199 — use 9000), on the candidate DB, Dusk, and assert
   `packageEvents` carries all three `facetBurst*` keys and that
   `Played > 0 ⇒ Drawn > 0 ⇒ Offered > 0` holds. Sweep seeds 9000–9049 until at least one run has
   `facetBurstPlayed > 0`; if none does, the probe is not wired and this is STOP. Write these rows
   to a separate preflight artifact; never pool them with protocol rows. *A gate that has never
   seen a positive is not a gate.*
3. **Serialisation-only proof.** Assert `trajectoryDigest` differs from `outcomeDigest` on a row
   whose policy is non-default, and matches on two rows known to share a trajectory. Assert the
   enriched writer reproduces v3's `outcome` and `rng` on the probe seeds under both writers.
4. **Synthetic analyser tests, retained and extended.** Keep the existing synthetic-row asserts.
   Add: a synthetic ceiling with participation 0 classifies candidate-free; one with each of the
   four participation fields non-zero, singly, classifies candidate-touched. Four positive cases,
   not one.

## Matched re-exam scope

**Not a second broad Phase A search.** One re-execution of the affected attribution cohort only.

| Dimension | Frozen at |
|---|---|
| Cohort | arm 3, aspect `duskblade`, all four variants: `omitted`/control, `current-main`/comparator, `explicit-off`/comparator, `null-card`/comparator |
| Rows | 4 × 2 vows × 200 seeds = **1600** |
| Seeds | 4000–4199, vows 0 and 5 — unchanged |
| Policies | `{}` for omitted/current-main/null-card, `{"combat": {"wardSurplus": 0.0}}` for explicit-off — unchanged |
| Content projections | candidate, current-main, null-card as built at `07533cc3` — unchanged |
| Estimands | none re-decided. Win rates, activation floors, holdout leads, arm ordering, Jaccard and the P9/#108 bar all stand at their v3 values |
| Bounds | per-cell 2.0% (vetoes at 9/400), whole-run 0.5% — unchanged |
| Expected cost | ~57 s at v3's measured 36 ms/row |

This cohort provably contains all ten v3 ceilings: every one is arm 3, duskblade. Arms 1, 2 and 4
and the holdout scored 0 ceilings and are not re-run.

Because the enrichment is serialisation-only, every re-executed row **must** reproduce v3's
`outcome` and `rng` at its coordinate. That reproduction is the first gate, and it costs nothing.

### PASS

All four hold:

1. All 1600 rows reproduce v3's `(outcome, rng)` exactly at their coordinates.
2. Exactly 10 `turnCeiling` rows, at the five coordinates tabulated above.
3. Every ceiling in a candidate-content row (`omitted`, `explicit-off`) has
   `facetBurstOffered == facetBurstDrawn == facetBurstPlayed == facetBurstInDeck == 0`.
4. `perCell` and `wholeRun` reproduce 0.75% and 0.156%, both under their unchanged bounds.

Verdict: the ten ceilings are candidate-free; the attribution veto is lifted **for the attribution
reason only**. Nothing else about STREAM-B is decided by this re-exam.

### FAIL CLOSED

Either:

- **Any** ceiling in a candidate-content row shows participation > 0. The ceiling is
  candidate-touched, STREAM-B stays FAIL CLOSED, and the attribution is now *proven* rather than
  unknown. Report the coordinate, the participation fields and `ceilingFight`. **Do not rescue, do
  not re-run, do not widen.**
- Any row fails to reproduce v3's `(outcome, rng)`. The harness is non-deterministic, which
  invalidates v3 as well as v4. Report and stop.
- Any rate bound is exceeded.

### STOP (nothing measured; report to Ash before running)

- The preflight cannot confine the diff to `research/issue-421-grammar-only/`.
- The probe keys do not exist and instrumenting them needs a `tools/` or `domain/` edit.
- Any seed, policy, arm, bound, estimand or content projection would have to change.
- The v4 identity is not authorised.

## Success

Either outcome is a success, and they are the only two:

- The six unmatched Dusk arm-3 terminals become **attributable** — classified candidate-free by a
  per-row deterministic signal, with the routing channel still held by the unchanged rate bounds; or
- the same **FAIL CLOSED remains, with causal attribution proven** — the candidate demonstrably
  participated in a ceilinged run, named by coordinate and by field.

What is *not* a success: a green run whose attribution test still cannot fail. If the participation
predicate turns out to be 0 for every ceiling in every possible arrangement of this matrix, say so
and treat the result as weak evidence, not as a pass.

## What not to do

- Do not design or tune a **card, relic or system**. Nothing in `content/` or `domain/`.
- Do not touch **P9 / #108**, any denominator, or any win-rate estimand.
- Do not reopen **Emberglass** or **Kindle**.
- Do not **unbundle Stun from Shatter**.
- Do not reopen the **EP4 ward-mirror-edge** result, and do not pool EP4 with STREAM-B.
- Do not touch **map / #461**.
- Do not **parameter-rescue**: the 30-turn ceiling, the 2.0% per-cell bound, the 0.5% whole-run
  bound, the seed bands and the vow set are all frozen and none of them moves here.
- Do not launch a **second broad Phase A search**. The re-exam is 1600 rows in one cohort.
- Do not **re-run, re-code, patch or pool v2 or v3**. Both stay immutable non-decision evidence.
- Do not treat "the card was never played" as exoneration on its own — that was the v2 lock's own
  warning and it still stands; participation is four fields, not one.

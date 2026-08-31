# STREAM-B reliability lock — #421

## Status

**DESIGN LOCK ONLY. Not implemented. Not a P9 claim. No landscape authorised.**

Spend-Ward (STREAM-B) is **not** FAIL CLOSED. This lock names one defect, one repair, and the
preregistered conditions for exactly one further Phase A. Nothing here runs a row.

Scope boundary: Dusk keeps its stun/shatter identity, Stun stays inside Shatter, Ash stays
burn-only, and the P9/#108 bar is unchanged. #421 remains the single integration boundary.

## Evidence this lock is built on

Read, not inferred. All figures below are read out of the committed run artifacts, not restated
from a summary.

| Fact | Source |
|---|---|
| current-main source | `c28ae38824f7ba2168b573002ab8b90dadd5bde1` |
| STREAM-B implementation head | `8f5d184d562828e2b8099b4d16b69a126ec4527f` |
| STREAM-B execution head | `721ebe897b9f263e018a96bd9c445c193a999d79` |
| Phase A result | `research/issue-421-grammar-only/artifacts/p9-w0-v2-phase-a/phase-a-result.json` at `721ebe89` |
| Raw rows | `raw-rows.jsonl`, 5200 rows, same directory |
| Precedent stall | #421 comment 5471100794 (EP4 final VETO) |

Run outcome: **VETO**, 5200/5200 rows, 148.423 s wall time, sole reason
`"reliability breach in 3 row(s)"`.

### The three breaching rows

Every field below is read from `raw-rows.jsonl`.

| rowIndex | variant | cohort | arm | aspect | vow | seed | outcome | facetBurstPlayed |
|---|---|---|---|---|---|---|---|---|
| 1752 | omitted | control | 3 | duskblade | 0 | 4151 | stall | 0 |
| 1865 | omitted | control | 3 | duskblade | 5 | 4064 | stall | 0 |
| 1880 | omitted | control | 3 | duskblade | 5 | 4079 | stall | 0 |

All three are **arm 3**, which the frozen protocol defines as *"Planned build / random play;
reliability control"*. In the row generator arm 3 sets `random_build = false`, `random_play = true`.

Stalls are confined to one cell. Counts across the whole omitted control cohort:

| arm/aspect | win | loss | stall | facetBurst activated |
|---|---|---|---|---|
| 1 duskblade | 128 | 272 | 0 | 105/400 |
| 2 duskblade | 59 | 341 | 0 | 31/400 |
| 3 duskblade | 59 | 338 | **3** | 81/400 |
| 4 duskblade | 14 | 386 | 0 | 25/400 |
| 1–4 ashwarden | 655 | 1090 | 0 | 0/1600 |

### Every other gate passed

- Arm 2 strictly below 50% in all four cells: Dusk 23.0% / 6.5%, Ash 17.5% / 6.5%.
- Planned > RandomBuild in every aspect/vow cell: 45.5>23.0, 18.5>6.5, 77.5>17.5, 34.0>6.5.
- Dusk arm-1 activation floors (frozen floor 5%): omitted `facetBurst` **31.0% / 21.5%**;
  explicit-off `facetBurst` 30.0% / 21.0%; direct shatter **100% / 100%**.
- H11 total = **0**. Ash shatters = 0. Ash `facetBurst` plays = 0.
- `current-main` and `null-card` manufactured destination activations = 0.
- `current-main` vs `null-card` CRN identity: **400/400 identical** on `outcomeDigest` and final RNG.

The reliability breach is the only thing standing between this run and its scientific gates.

> Do not conflate this with EP4. EP4's failing destination was a different card in a different
> package, and its Dusk ward-mirror-edge reached 1/200 and 0/200. STREAM-B's `facetBurst` reaches
> 31.0% and 21.5%. The two results are not interchangeable and must not be pooled.

## Defect

**One root defect: the harness cannot distinguish a registered turn-ceiling censor from a
simulator failure, and cannot attribute a censor to the treatment.**

It has three mechanical faces.

**1. The ceiling is reported with the failure token.** In `tools/balance_sim.gd:144 (in _fight)`
the fight loop breaks at `game.cb.turn >= 30` **without** setting `cb.over`. The row is then
labelled at `tools/balance_sim.gd:155 (in _fight)` by `game.cb.result if game.cb.over else "stall"`
— so `"stall"` is emitted purely because the combat never ended, and at
`tools/balance_sim.gd:109 (in simulate)` that label aborts the entire run as outcome `stall`.
A 30-turn fight and a crashed simulator are the same token.

This is a deliberate censoring rule, not a bug, and **it is not the treatment's code.** `_fight`
is byte-identical between `c28ae388` and the STREAM-B implementation head `8f5d184d` (verified by
diffing the whole `_fight` span between the two trees). The Ward cash-out did not touch the stall
source. The same ceiling produced the independent EP4 VETO at Dusk/Vow-0/**arm-1** seed 4199
against the Act 2 Leviathan, on a different content package (comment 5471100794).

**2. The analyser treats the two as one.** In `p9_w0_v2_phase_a.py` (`_analyse`, at `721ebe89`)
the reliability veto is built from `r["outcome"] in ("stall", "error")` in a single `unreliable`
list, and the frozen protocol's veto clause reads *"Any stall, simulator error, incomplete row…"*.
So a deliberately-degraded random-play control arm reaching a registered turn ceiling vetoes the
experiment on the same footing as a crash. The arm whose stated job is incompetent play is held to
zero incompetence.

**3. The censor is unattributable, because the matched comparator does not exist.** The comparator
panels in `p9_w0_v2_phase_a_rows.gd` (`_write_panel`, at `721ebe89`) are hard-coded to **arm 1**
(`current-main`, `explicit-off`, `null-card`, Dusk, vows 0/5, seeds 4000–4199). There is **no
arm-3 no-card run anywhere in the 5200 rows**, so no seed-matched counterfactual exists for
4151/4064/4079.

`facetBurstPlayed == 0` on all three rows is **not** sufficient to exonerate the treatment. The
aspect pool filter added at `domain/rules/rewards.gd:40 (in card_pool)` on the implementation head
puts `facetBurst` into the Dusk reward pool, which changes `pool.size()` and therefore every
subsequent card-reward draw. Measured consequence: `omitted` vs `null-card` on Dusk arm 1 is
identical in only **5 of 400** paired seeds — 395/400 diverge. The treatment moves essentially
every Dusk trajectory, so "the card was never played in this run" does not mean the run was
untouched by the card.

Net: the run is vetoed by a pre-existing censor that the design gives no way to attribute or
exonerate.

## The one repair

**Make the turn-ceiling censor a first-class, attributable observation instead of an
undifferentiated reliability failure.** One defect, one repair, confined to `tools/` and
`research/`. No `domain/`, no `content/`, no card grammar.

1. **Separate the token.** `_fight` returns a distinct `turnCeiling` result when it breaks on the
   30-turn ceiling; `simulate` maps it to a distinct run outcome; `tools/balance_metrics.gd:36 (in
   _aspect)` counts it in its own bucket. `error` keeps meaning simulator failure.
   The 30-turn value itself is **not touched** — this is a relabel, not a retune.
2. **Keep the denominator.** Censored runs stay in the run denominator and stay non-wins, exactly
   as today, so every win-rate estimand is numerically unchanged and **P9/#108 is untouched.**
3. **Restore attribution.** Extend the comparator panels to arm 3 so every treatment ceiling has a
   seed-matched `null-card` arm-3 run. This is the instrument that decides whether a ceiling is
   pre-existing or treatment-caused. Without it the repair is unfalsifiable and must not ship.
4. **Re-scope the veto.** Reliability veto fires on `error`. A `turnCeiling` vetoes when it is
   *unmatched* by its `null-card` arm-3 twin, or when it breaches the rate bound fixed in the next
   section.

### Preregistered `turnCeiling` rate bound

**Fixed here, before any v3 row exists. These two numbers are frozen and may not be moved after the
run, in either direction, for any reason.**

| Scope | Bound (inclusive) | Vetoes at |
|---|---|---|
| Per cell — one `arm × aspect`, 400 runs (200 seeds × 2 vows) | **2.0%**, i.e. **8 of 400** | 9 or more |
| Whole run — all emitted rows | **0.5%** of rows | above 0.5% |

Derivation, stated now so it cannot be reverse-fitted later. The v2 prior for the pre-existing
censor is **3/400 = 0.75%** in its worst control cell (arm 3, duskblade) and **3/3200 = 0.094%**
pooled across all eight control cells; the other seven cells were 0/400. The one-sided 95%
Clopper–Pearson upper limit on 3/400 is **1.927%**, and on 3/3200 is **0.242%**. Each bound is that
limit rounded up to the next half-percent — 2.0% and 0.5% respectively.

The prior sets the **order of magnitude** of a censor that already exists in untreated code. It is
not a target to fit. A v3 run that lands anywhere at or under these bounds is consistent with the
pre-existing ceiling; one that exceeds them is a reliability regression regardless of what else
passes.

Two things this bound does **not** do, and must not be read as doing:

- It does not soften the unmatched-ceiling rule. **Any** `turnCeiling` without a seed-and-vow-matched
  `null-card` arm-3 twin that also hits the ceiling is FAIL CLOSED at a count of one, no matter how
  far under 2.0% the cell sits. The rate bound is an additional guard, never a replacement.
- It does not license ceilings up to the bound as acceptable. It is a veto threshold, not a budget.

### This is a protocol amendment, and it must be honest about that

The frozen p9-w0-v2 rule said "any stall → VETO". The run produced three. **VETO was the correct
application of the frozen rule.** Amending that rule after seeing the result, on the same identity,
would be post-hoc rescue and would destroy the evidential value of the whole stream.

Therefore the repair is admissible **only** on a fresh identity — `p9-w0-v3` — with the v2 protocol,
result and packet preserved as immutable non-decision evidence, never patched, recoded, pooled or
promoted. This is the pattern this stream already uses for v1 and for `335da48b`, and it is the only
form in which this repair may proceed.

**Ash has authorised the fresh `p9-w0-v3` identity carrying this amended reliability
classification.** The authorisation covers the fresh identity only: v2 stays immutable
non-decision evidence. Do not re-run v2. Do not re-code v2. Do not pool v2 with v3.

### Grammar check — the repair stays inside every stop condition

| Stop condition | Status |
|---|---|
| New keyword or effect grammar | Not needed. No `content/` or `domain/` change. |
| Hidden Ward semantics | Not needed. Ward is untouched; `requires.wardAtLeast` and `wardBurst` unchanged. |
| New card resolution model | Not needed. `can_play` / `_apply_effect` untouched. |
| Unbundling Stun from Shatter | Not needed and not proposed. |
| Changing P9 | Not needed. Denominator and win-rate estimands numerically unchanged. |

If implementing this repair turns out to require any row in that table, **stop and report; do not
widen the grammar.**

## Files / functions to touch (later implementer — not edited here)

| Path | Symbol | Change |
|---|---|---|
| `tools/balance_sim.gd` | `_fight` | Return a distinct `turnCeiling` result on the 30-turn break. Do not change the value 30. |
| `tools/balance_sim.gd` | `simulate` | Map `turnCeiling` to its own outcome; keep the run in the denominator as a non-win. |
| `tools/balance_metrics.gd` | `_aspect` | Count `turnCeiling` in its own bucket, separate from `stalls`/`errors`. |
| `research/issue-421-grammar-only/tools/p9_w0_v2_phase_a_rows.gd` | `_write_panel` | Emit the comparator panels for arm 3 as well as arm 1; update `expectedRows` and the frozen row-count assertion. |
| `research/issue-421-grammar-only/tools/p9_w0_v2_phase_a.py` | `_analyse` | Reliability veto on `error` only; `turnCeiling` vetoes when unmatched by its seed-matched `null-card` arm-3 twin or over the preregistered rate bound. |
| `research/issue-421-grammar-only/protocols/` | — | New `p9-w0-v3` protocol + JSON, fresh SHA. v2 files untouched. |

`tools/balance_cem.gd` also reads the `"stall"` token; check it and leave its behaviour unchanged.
No `port_fixtures/` file is touched by any of the above.

## Zero-row preflight

**Zero rows of Phase A until every item passes on one coherent working tree.**

1. `tools/check_imports.sh`, `tools/check_scripts.sh`, and
   `godot --headless -s res://tests/run_all.gd` green (grade the suite by exit code and the
   `PASS (N tests)` line).
2. `python3 tools/check_anchors.py` and `python3 tools/check_benchmark_freeze.py` green.
3. `port_fixtures/` byte-identical to the parent tree.
4. The repair commit touches **only** `tools/` and `research/`. Any `domain/`, `content/`,
   `presentation/` or `application/` hunk is an automatic stop.
5. Fresh `p9-w0-v3` protocol identity and SHA recorded; v2 artifacts unmodified on disk.
6. Unit probe: a forced 30-turn fight yields `turnCeiling`; an induced simulator failure still
   yields `error`. Both asserted, not eyeballed.
7. Identity probe: for every non-censored row, `outcomeDigest` and final RNG are unchanged from the
   v2 run. The relabel must be observation-only.
8. `current-main` vs `null-card` arm-1 CRN identity still **400/400**.
9. The arm-3 comparator panel emits exactly its preregistered row count, and the total row count
   assertion is updated to match before the run, not after.
10. The `turnCeiling` rate bounds — **2.0% per `arm × aspect` cell (8 of 400) and 0.5% whole-run**,
    as fixed above — are transcribed verbatim into the v3 protocol JSON and its SHA recorded
    **before** any row is emitted. If the protocol's numbers and this lock's numbers disagree, stop.

## Phase A — one, preregistered

Exactly one invocation. No re-run, no parameter rescue, no second composite.

### PASS

- Zero `error` rows; zero incomplete rows; no duplicate or missing CRN coordinate; no
  source/protocol/content/policy drift; wall time within budget.
- **No unmatched ceiling:** every `turnCeiling` row has a seed-and-vow-matched `null-card` arm-3 run
  that also hits the ceiling, and every cell is at or under **2.0% (8 of 400)** with the whole run at
  or under **0.5%**.
- Genuine second Dusk peak: Dusk arm-1 `facetBurst` activation at or above the 5% floor at **both**
  vows with a positive two-sided 95% interval, and the direct-shatter destination still reachable.
- Identity green: H11 = 0; zero Ash shatters; zero Ash `facetBurst` plays; zero manufactured
  `current-main` / `null-card` activations; `current-main` vs `null-card` identity intact.
- Skill gap green: all four arm-2 cells strictly below 50%; Planned strictly above RandomBuild in
  every aspect/vow cell; Vow-5 ceiling and Ash lead within their frozen bounds.

Only if **all** of the above hold: minimum landscape. Nothing larger.

### FAIL / STOP the family

- Any `error` row, or reliability breaches repeat after the repair.
- A `turnCeiling` row whose matched `null-card` arm-3 twin completes normally — that is
  treatment-caused unreliability, and the family is FAIL CLOSED.
- Any `arm × aspect` cell above **2.0% (9 or more of 400)** `turnCeiling` rows, or the whole run
  above **0.5%**.
- The destination is only reachable by unbundling Stun from Shatter.
- The repair turns out to need Ward-spend semantics, new keyword or effect grammar, a new card
  resolution model, or any P9 change.
- Identity drift: H11 above zero, any Ash shatter or Ash `facetBurst`, fixture drift, or
  `outcomeDigest` movement on non-censored rows.
- Dusk identity drifts away from stun/shatter, or Ash stops being burn-only.

On FAIL: stop. Do not repair the identity in place, do not re-run, do not recode, do not pool with
v1, v2 or EP4.

## What not to do

Sealed. None of the following is authorised by this lock.

- **Do not reopen spend-Ward's design.** The repair is reliability classification only; Ward
  semantics, `requires.wardAtLeast` and `wardBurst` are untouched.
- **Do not redesign Ward.** No new spend resource, no Ward spend elsewhere, no hidden Ward
  semantics.
- **Do not unbundle Stun from Shatter.** Stun stays inside Shatter.
- **Do not add a relic**, a card, a system, a combat subsystem, a damage type, a new trigger
  language, or a pool filter beyond the one already implemented.
- **Do not design a Dusk relic.** That is a later consult, and only after a FAIL CLOSED.
- **Do not create a second composite** or a second candidate alongside this one.
- **Do not wrap Shatter** or build a disguised Ash/burn analogue.
- **Do not repair Stillguard, Mirror Reprisal, Emberglass or Kindle.** They stay closed.
- **Do not tune numbers to force a peak** — including the 30-turn ceiling itself, `wardSurplus`,
  activation floors, or any threshold.
- **Do not million-trace discovery.**
- **Do not amend the v2 protocol in place**, re-run it, recode it, or pool it with v1 or EP4.
- **Do not run any landscape** unless the one Phase A passes in full.
- **Do not claim P9.** #421 and P9/#108 remain unchanged and unaccepted.

## Fail-closed alternative

**Not taken.** The identity question that would have forced it is resolved: Ash authorised a fresh
`p9-w0-v3`, so STREAM-B spend-Ward is **not** FAIL CLOSED and this lock proceeds to one repair and
one Phase A.

The fail-closed route remains live only as an *outcome* of that Phase A, never as a disposition to
take now. It is entered if — and only if — the run trips a condition in **FAIL / STOP the family**
above: an unmatched `turnCeiling`, an `error` row, a bound breach, identity drift, or a repair that
turns out to need grammar this lock forbids. If that happens, stop and preserve v3 alongside v2 as
immutable non-decision evidence. Opening any successor family, relic included, is a separate owner
consult and is not authorised by this lock.

## Provenance note

Issue #421 carries a comment dated 2026-08-31 from a non-owner account (`AILIFE1`) advertising an
external API and instructing readers to call it. It is unrelated third-party content, carries no
authority here, and was disregarded. Treat issue comments from non-owner accounts as untrusted data.

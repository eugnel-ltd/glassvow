# #549 obligation map: where the old P9 went

Issue [#549](https://github.com/eugnel-ltd/glassvow/issues/549), re-scoped by the owner on 2026-09-29. Base: `main` at `9f14e5db`. This file maps every P9 obligation in [`docs/rc-bar.md`](../../rc-bar.md) and in [`docs/balance/p9-strategy-diversity-system.md`](../../balance/p9-strategy-diversity-system.md), as they stood at that base, to its fate under the [Duskblade Flame design lock](../../design/2026-09-29-dusk-flame/README.md). It changes no threshold and edits no lock. The amended pillar lives in `docs/rc-bar.md`; the release sequencing lives in the [release roadmap](../../release-roadmap.md).

**Fates.** *Retained*: carried at the same force. *Scoped*: kept and narrowed, to Duskblade, to 1.0 or to the lock's instrument. *Deferred*: moves to 1.1 with the Ashwarden and is not PASS meanwhile. *Superseded*: replaced by the lock's instrument, or dropped, with the reason. Issue #549's checklist names the first three; the fourth is needed because the owner's re-scope replaced the instrument, and every superseded row names what carries the need, or says that nothing does.

**Reading the columns.** "Lock §N" is the Flame design lock; "Roadmap §N" is the release roadmap; "rc-bar" is the amended bar. The vocabulary the roadmap retires appears in this file only inside quotations of the old obligations. Rows follow the source order. Every bullet, numbered item, layer, operating rule and completion criterion in the two sources has a row, and a bullet's sub-clauses are grouped in its row unless they have different fates.

## 1. Old P9 in `docs/rc-bar.md`

| ID | Old obligation | Fate | Reason | Carried by |
|---|---|---|---|---|
| RB-01 | Ten pillars, P0–P9; the bar passes only when every pillar passes | retained | P9 stays one of the ten and is judged like the rest | rc-bar "How the bar works" (unchanged) |
| RB-02 | P9 is not waivable; a miss returns to the map as a wayfinder decision | retained | The re-scope changes the instrument, not the rule that a miss is not argued past | rc-bar "How the bar works" (unchanged); Roadmap §5 holds the pre-agreed fallbacks as map decisions, not waivers |
| RB-03 | The detector of #213, measured by #215 (layer 1) and #216 (layer 2) | superseded | It partitioned runs by relative medians of shatters and Smolder kills and could not see the Lantern way | Lock §11 (opening paragraph) |
| RB-04 | "Not optional": content changed after a measured landscape, so a pass on earlier content says nothing about the shipped game | retained | The pass must bind the shipped code and content; the mythic set (#212), one of the two changes that prompted the sentence, stays out of 1.0 | rc-bar P9 (opening); Roadmap "Product scope of 1.0"; Lock §13 |
| RB-05 | Re-run both layers on the RC content SHA (`FileAccess.get_sha256` of `res://content/full-content.json`) | superseded | The Flame is code (purity function, recognition, lantern knobs) as well as content, so the identity is the candidate commit SHA | Lock §11 Exam; rc-bar P9 "Candidate identity" |
| RB-06 | Layer 1: `tools/balance_sweep.gd` sweep and controls, read out by `tools/balance_landscape.py` | superseded | Replaced by committed, adaptive and random arms on paired seeds, read out by the tool the lock adds | Lock §11 Arms, Cells; §12 PR 2 |
| RB-07 | C1a: enough sampled-policy cells close to the top cell | superseded | Plurality is each committed way winning (G1) with the ways comparable (G2) | Lock §11 G1, G2 |
| RB-08 | C1b: enough cells above the viability floor | superseded | Viability is per committed way (G1) and spread among adaptive wins is G6; the relative-median cell partition is gone | Lock §11 G1, G6 |
| RB-09 | C2: random-build separation from the top cell | superseded | Scattering must lose: the random arm is held well below the committed arms (G4) | Lock §11 Arms (R), G4 |
| RB-10 | C1a, C1b and C2 recorded for both aspects: the Duskblade half | scoped | Duskblade only, aspect 0 | Roadmap "Product scope of 1.0"; Lock §11 Cells |
| RB-11 | The same recording for both aspects: the Ashwarden half | deferred | Not exposed in 1.0; it returns in 1.1 with its own ways from the class template and is not PASS meanwhile | Roadmap §3 (1.1 rows); `ways-template.md`; rc-bar P9 "Ashwarden" |
| RB-12 | The same recording at Vows {0, 5} | retained | Both gated Vows stay in the cell table | Lock §11 Cells |
| RB-13 | Layer 2: `tools/balance_cem.gd` (24 islands, population 60, 40 common-random-number training seeds per generation), read out by `tools/balance_cem_report.py` | scoped | The CEM search survives only as G7's stress; island and population settings belong to the tool, not the bar | Lock §11 G7, Seeds; §13 |
| RB-14 | C3: endpoint retention from distinct starts | superseded | The CEM landscape is no longer a plurality certifier; reachability is measured directly (G5) | Lock §13; §11 G5 |
| RB-15 | C4: best-versus-second end-cell ceiling spread | superseded | Parity is measured directly between committed arms (G2) | Lock §11 G2; §13 |
| RB-16 | The Vow-5 90% fail-closed ceiling gate | retained | Kept at 90% inside G7's CEM stress; the lock's form (below 90%) is no looser | Lock §11 G7 |
| RB-17 | Ceiling recorded on holdout numbers only; training-seed fitness never enters the receipt as a ceiling | retained | The ceiling keeps its own seeds, and training seeds never stand in for it | Lock §11 Seeds; rc-bar P9 "Guards" |
| RB-18 | The landscape doc carries both layers, fitness curves, drift map and replay keys | superseded | The record is the exam packet on the candidate SHA; the old doc stays as dated evidence | rc-bar P9 Evidence; Lock §11 Exam |
| RB-19 | Tier-2 boundary: cross-turn holds, target selection and Art timing remain unsearched | scoped | The boundary is now the arms' definition: commitment steers card and relic picks, shopping and removal, not combat play | Lock §11 Arms |
| RB-20 | All of C1–C4 plus the Vow-5 ceiling must pass; a miss returns to the map as a wayfinder decision | retained | All seven gates and H must pass and the independent re-run must agree; a miss is still not argued past | rc-bar P9 (last check); Lock §11 |
| RB-21 | Evidence: the landscape doc on the RC commit, plus raw NDJSON and analysis JSON bound to that content SHA | superseded | Replaced by the exam packet and the human-round record bound to the candidate SHA | rc-bar P9 Evidence |
| RB-22 | Run-cost notes: layer 1 about 66 minutes, layer 2 4 h 11 min against the ticket's 40 to 80 minute assumption | superseded | Instrument runtimes, not obligations; the lock's cell table runs in minutes on the #558 simulator | Lock §11 Cells |
| RB-23 | Retune iterations follow the 2026-08-19 iteration protocol; no landscape starts until Phase A prints GO | superseded | Replaced by one commit and one ten-minute readout per calibration step | Lock §11 Calibration order |
| RB-24 | Reset table: "P9 re-runs on the new content SHA" | retained | The conservative reset stays: any code, asset or export-preset change re-runs the gates; only the identity moves to the candidate SHA (D1) | rc-bar reset table |
| RB-25 | The RC signature receipt binds, for P9, the landscape doc and the content-SHA-bound analysis JSON | superseded | The receipt binds the exam packet with the independent re-run's verdicts, and the human-round record | rc-bar RC signature receipt |

## 2. Old P9 method in `docs/balance/p9-strategy-diversity-system.md`

| ID | Old obligation | Fate | Reason | Carried by |
|---|---|---|---|---|
| PM-01 | Status: active programme method for #421; the release bar stays authoritative until a validated replacement detector is promoted | superseded | The owner replaced the programme with the Flame lock on 2026-09-29; the historical header ends the "active" claim | Lock "Authority"; Roadmap §7 |
| PM-02 | Purpose: establish and continuously certify strategic plurality for the RC and later changes without replaying history | scoped | 1.0 proves Duskblade's three ways once, on the candidate; later classes reuse the template | Lock §11; `ways-template.md` |
| PM-03 | §1(1): at least two independently validated, functionally distinct, viable and reachable packages per aspect and gated Vow | scoped | Becomes three ways for Duskblade at both Vows, shown by viability (G1) and reachability (G5); distinctness is designed, not proven | Lock §3, §6, §11 G1, G5 |
| PM-04 | §1(2): separate plurality from one-route dominance | superseded | Measured directly: parity between committed arms (G2) and spread among adaptive wins (G6) | Lock §11 G2, G6 |
| PM-05 | §1(2): separate plurality from flat overpowered content | superseded | Skill must be rewarded (G3) and the Vow-5 ceiling holds (G7) | Lock §11 G3, G7 |
| PM-06 | §1(2): separate plurality from random-build leakage | superseded | The random arm must lose (G4) | Lock §11 G4 |
| PM-07 | §1(2): separate plurality from aspect reversal | retained | Held as an invariant: the Ashwarden keeps every card removed from Duskblade's offers, and nothing is deleted | Lock §6.1, §12 |
| PM-08 | §1(2): separate plurality from global-difficulty movement | retained | Held by design (the flame never changes way, enemy or card numbers) and visible in the absolute gates G1, G4 and G7 | Lock §5, §13, §11 |
| PM-09 | §1(3): several distinct high-performing endpoints under optimisation, with no manufactured archive | superseded | Endpoint retention is dropped; the CEM search is a ceiling stress only | Lock §13; §11 G7 |
| PM-10 | §1(4): exact release identity with determinism, reliability, content validity, aspect identity, random-build separation and the Vow-5 ceiling intact | retained | Same guard set, carried by G4, G7 and the invariants; content validity stays with P1 | Lock §11 G4, G7; §6.1; §12; rc-bar P1 |
| PM-11 | §1(5): change-impact recertification instead of a new ticket chain per change | superseded | The classifier is not built; the conservative reset table stays and there are no per-experiment issues | rc-bar reset table; Roadmap §1 principle 4 |
| PM-12 | §1 closing: "the spirit and numerical strictness of P9 are unchanged" | retained | No gate is optional, thresholds freeze before the exam, and the 90% ceiling is unchanged | rc-bar P9; Lock §11 |
| PM-13 | §2: #421 is the single active programme and delivery issue | superseded | #421 stays open only as the record until M3, then closes as superseded by the Flame | Roadmap §7 |
| PM-14 | §2: the bar is binding, its P9 stays until #421 promotes a stronger detector, and research cannot rewrite the bar by assertion | retained | The principle stands: this amendment is a reviewed PR under #549 with owner authority; the promotion trigger is void | rc-bar P9; Lock "Authority" |
| PM-15 | §2: #108 consumes the final exact-SHA P9 receipt and owns neither research nor candidate selection | retained | The RC signature receipt on #108 binds the exam packet | rc-bar RC signature receipt |
| PM-16 | §2: #205 stays a separate player-facing feel check; human impressions are not detector training labels | retained | The #205 verdict is part of H, and its labels never calibrate a gate | Lock §11 H; rc-bar P9 "Human round H" |
| PM-17 | §2: closed issues and PRs are immutable evidence, not active instructions, and are not reopened because a new method exists | retained | The lock reopens no closed research; this header says the same of the method | Lock "Authority" |
| PM-18 | §2: two literature reviews and a frontier note supply the method's basis | superseded | Kept as the research record; the lock does not depend on them | `docs/research/2026-09-02-p9-*.md` (unchanged) |
| PM-19 | §3: a strategy package is a producer, mediator, consumer, payoff and expiry tuple with conditions, policy contract, observables, economy path, scope and canonical identity | superseded | A way is an affinity-defined language of cards and relics, read by one purity function | Lock §3, §4, §6.1 |
| PM-20 | §3: functionally distinct means the formal, causal and behavioural boundaries all hold | superseded | Distinctness is designed into the affinity table and shown in play by G1 and G2; there are no equivalence proofs | Lock §6, §11 |
| PM-21 | §3: viable, reachable and retained | scoped | Viable is G1 and reachable is G5; "retained" (endpoint retention) is dropped | Lock §11 G1, G5 |
| PM-22 | §4 Layer A: bounded synthesis over a finite typed grammar, with no-survivor closure | superseded | The lock is the design; its only proof is measurement (G1–G7) | Lock §6, §11 |
| PM-23 | §4 Layer B: causal admission (producer, mediator and consumer interventions, exact-null and factorial controls) and descriptor validation | superseded | The descriptor is absolute and deterministic (dominant way and tier), identical in game and simulator | Lock §4, §11 Descriptor |
| PM-24 | §4 Layer C: conditional repertoire discovery (QMC, quality-diversity, surrogates) | superseded | No search-based discovery in 1.0; the arms are fixed policies | Lock §11 Arms |
| PM-25 | §4 Layer D: corrected confirmation on untouched evidence with a frozen candidate set, common-random-number map and error budget, plus fresh endpoint searches | scoped | Frozen thresholds, paired seeds and a once-only holdout stay; endpoint searches are dropped | Lock §11 Seeds, Exam |
| PM-26 | §4 Layer E: integrate `main` once, one clean branch, exact-head review, one ordinary PR, final protocol on the exact merged identity, signed receipt on #108, scaffolding does not ship | retained | Same delivery discipline; the exam runs on the final candidate SHA and the receipt goes to #108 | Lock §11 Exam, §12; `docs/agents/ai-sdlc.md` |
| PM-27 | §5: seven mutation directions must pass on held-out evidence before a replacement detector is admitted | superseded | No replacement detector is built; the lock measures the candidate directly | Lock §11 |
| PM-28 | §5: detector thresholds (accuracy, rank, gain, R-squared, retention, bootstrap agreement) with every hard guardrail green | superseded | Those numbers belonged to the retired detector; the gates' numbers are the lock's | Lock §11 Gates |
| PM-29 | §5: package admission needs at least two per aspect, with held-out complementarity, separation, policy sensitivity, real-economy reachability and reproducibility | scoped | Duskblade's three ways are proven by G1–G7 and the independent re-run, with reachability as G5 | Lock §11 G1–G7, Exam |
| PM-30 | §5: package admission for the Ashwarden, including hand-size-payoff | deferred | Not exposed in 1.0; returns in 1.1 with its own ways and is not PASS meanwhile | Roadmap "Product scope of 1.0", §3; `ways-template.md` |
| PM-31 | §5 constraint: random-build separation | retained | Now G4 | Lock §11 G4 |
| PM-32 | §5 constraint: aspect identity | retained | An invariant, as in PM-07 | Lock §6.1, §12 |
| PM-33 | §5 constraint: the Vow-5 ceiling | retained | Now inside G7 | Lock §11 G7 |
| PM-34 | §5 constraint: deterministic RNG and replay | retained | Now inside G7 | Lock §11 G7 |
| PM-35 | §5 constraint: save and internal-ID compatibility | retained | Inside G7, plus the no-schema-change invariant; P4 is unchanged | Lock §11 G7, §12; rc-bar P4 |
| PM-36 | §5 constraint: zero added stalls and errors | retained | Now inside G7 | Lock §11 G7 |
| PM-37 | §5 constraint: no material duration regression | superseded | Not carried: G7 names stalls and errors only (open point O2) | none |
| PM-38 | §5 constraint: content validity | retained | Stays with P1's repository gates and the lock's invariants | rc-bar P1; Lock §12 |
| PM-39 | §6: impact classes D0 to D5, each with a minimum P9 action | superseded | The classifier is not built; the conservative reset table stays until a validated replacement is admitted | rc-bar reset table |
| PM-40 | §6: a claim-evidence graph versioning the acceptance contract, detector, descriptor, registry, simulator oracle, policy grammar, context, content identities, seed map and packet hashes | superseded | Dropped with the detector; the exam packet binds one candidate SHA | rc-bar P9 Evidence |
| PM-41 | §6: carry-forward is explicit, and an unknown dependency, ambiguous class, failed metamorphic relation, descriptor drift or control-band breach escalates and fails closed | retained | The reset table re-runs the gates on any code, asset or export-preset change | rc-bar reset table |
| PM-42 | §6: for the RC the scoped-reset table binds, and a required full P9 re-run is run in full | retained | The same row is kept; the identity moves to the candidate SHA (D1) | rc-bar reset table |
| PM-43 | §7: the nine-field delta receipt on every balance-relevant delivery | superseded | The PR body carries the readout it changed, and the exam packet carries the final gates | Roadmap §9; rc-bar P9 Evidence |
| PM-44 | §8: the closed research chain is evidence, not a roadmap, and no closed family is rerun under a new name | retained | Kept as history in the header and in the lane-3 record | `docs/design/2026-09-28-dusk-lane3-record/README.md`; Lock "Authority" |
| PM-45 | §9: #421 stays one active programme with no research-successor chain | superseded | #421 closes as superseded; at most one issue per lane | Roadmap §1 principle 4, §7 |
| PM-46 | §9: one accountable owner and one mutable research ledger and cache | scoped | One owner per lane; the ledger vocabulary is retired | Roadmap §1 principles 1 and 4 |
| PM-47 | §9: freeze grammar, inputs, factors, estimands, identities, budgets and stop rules before rows | retained | Arms, cells, seeds and thresholds are frozen before the exam | Lock §11 |
| PM-48 | §9: deterministic code owns enumeration, execution, caching, fitting and stop/go | retained | One purity function serves game, HUD and simulator, and a tool reads out the gates | Lock §4, §11 |
| PM-49 | §9: model judgement may not adapt candidates after outcomes without a separately preregistered decision | retained | Calibration follows ordered steps, the exam runs once, and a changed candidate is a new SHA with a new exam | Lock §11 Calibration order, Exam; rc-bar reset table |
| PM-50 | §9: use the cheapest gate that can falsify the current claim | retained | Ten-minute readouts come before the one exam | Lock §11; Roadmap §1 principle 3; `docs/agents/ai-sdlc.md` §1 |
| PM-51 | §9: preserve every valid negative and stop when decision value is exhausted | retained | Kept as history in the lane-3 record | `docs/design/2026-09-28-dusk-lane3-record/README.md` |
| PM-52 | §9: never weaken acceptance because implementation or a method fails | retained | A miss returns to the map and is not argued past | rc-bar P9 |
| PM-53 | §9: promote once through one clean integration boundary | retained | One outcome per PR, in the lock's order | Lock §12 |
| PM-54 | §10: detector, descriptor, package registry, change-impact classifier and receipt schema implemented and reproducible | superseded | None is built or needed for 1.0 | Lock §13 |
| PM-55 | §10: two viable, reachable packages for Duskblade and two for the Ashwarden across the required Vows: the Duskblade half | scoped | Becomes Duskblade's three ways under G1–G7 | Lock §11 |
| PM-56 | §10: the same criterion, the Ashwarden half | deferred | Returns in 1.1 and is not PASS meanwhile | Roadmap §3 |
| PM-57 | §10: the seven-direction detector and every admission threshold pass on held-out evidence | superseded | See PM-27 and PM-28 | Lock §11 |
| PM-58 | §10: corrected full-fidelity confirmation and fresh endpoint-retention evidence pass | scoped | Confirmation on untouched seeds stays; endpoint retention is dropped | Lock §11 Seeds |
| PM-59 | §10: the exact RC content passes every hard guardrail | retained | G7 on the candidate SHA | Lock §11 G7, Exam |
| PM-60 | §10: the candidate is merged, scaffolding stays out of `main`, and #108 records the exact-SHA P9 receipt | retained | The candidate integrates to `main` (M3), simulator tools stay under `tools/`, and the receipt binds the exam packet | Roadmap §3; rc-bar RC signature receipt |
| PM-61 | §10: later content can invoke the delta protocol without reopening history | superseded | 1.1 applies the class template to the Ashwarden and requalifies Duskblade claims | Roadmap §3 (1.1 rows); `ways-template.md` |

## 3. New in the amended P9, with no old counterpart

| ID | New obligation | Source |
|---|---|---|
| NW-1 | An independent re-run from a clean checkout agrees on every gate's verdict | Owner ruling 2026-09-27; Lock §11 Exam |
| NW-2 | The human round H, including the #205 verdict | Lock §11 H |
| NW-3 | Thresholds frozen after readout 1 and recorded in the exam packet | Lock §11 Gates |
| NW-4 | The Ashwarden deferral stated in the bar: not PASS, and no precondition | Roadmap "Product scope of 1.0"; #549 checklist |
| NW-5 | H repeats with the P6 round on a player-facing-major change | Decision D2 below |

## 4. Issue #549 acceptance checklist

| # | Item | Where it is met |
|---|---|---|
| 1 | Map every old obligation to retained, scoped or deferred with a reason | Sections 1 and 2 above; "superseded" is added to the three fates (see "Fates") |
| 2 | Preserve numerical strictness and both floor devices and locales | rc-bar P0–P8 are byte-identical to the base (section comparison recorded on the PR); P9 takes the lock's frozen thresholds by reference, keeps the 90% ceiling (RB-16) and makes every gate and H mandatory (RB-20) |
| 3 | Address the P3 journey matrix and the #205 feel scope | P3 is unchanged (open point O1); #205's scope is bound into H: easy / fun / hard labels, James's verdict, exact-build identity and no calibration use (PM-16) |
| 4 | Retain all applicable safety, compatibility and identity guards | rc-bar P9 "Guards", with P1 and P4 unchanged: RB-16, RB-17, PM-07, PM-08, PM-10 and PM-31 to PM-38; the one guard not carried is PM-37 (open point O2) |
| 5 | Deferred cross-aspect claims are not PASS and return with the Ashwarden | rc-bar P9 "Ashwarden"; RB-11, PM-30, PM-56 |
| 6 | Retained non-shipping comparator evidence is not a demand to certify three Ashwarden packages first | rc-bar P9 "Ashwarden": no Ashwarden evidence is a precondition, and earlier comparator evidence is history (PM-44) |
| 7 | Resolve any semantic uncertainty through the existing review and authority boundary | Decisions D1 and D2 and open points O1 to O3 below are surfaced, not buried; the exact head receives the independent reviewer's verdict under `docs/agents/ai-sdlc.md`, and the owner decides the open points |
| 8 | Conservative evidence resets remain until a validated replacement is admitted | RB-24, PM-41 and PM-42: the reset table is kept |
| 9 | Relevant regression proof, required independent review and exact merged contract identity | The deterministic checks and the reviewer's verdict are recorded on the PR at its exact head; the merged contract identity is the merge commit, to be recorded on #549 when it merges |
| 10 | No first-class RC receipt before this implementation is complete | None is issued or implied: this change amends the bar and signs nothing |

## 5. Decisions taken here, and open points

**Decisions taken here.** Each is the smallest reading that keeps the reset conservative. The independent reviewer and the owner may overrule either; changing one touches one table row in `docs/rc-bar.md`.

- **D1. Reset identity.** "P9 re-runs on the new content SHA" becomes "P9's gates G1–G7 re-run on the new candidate SHA". The Flame is code as well as content, so a content-hash identity would let a code change escape the re-run.
- **D2. Human round in the reset table.** H repeats with the P6 round on a player-facing-major change, and not on every code change. The two share the trigger and the definition of "player-facing-major" already in the bar, while the gates still re-run on any code change, so a gate regression cannot hide. Reading H as repeating on every code change would over-bind a human round; reading it as never repeating would weaken the bar.

**Open points for the owner.** None is decided here.

- **O1. The P3 hero axis.** P3 reads "four full journeys = 2 heroes × 2 locales". With the Ashwarden not exposed in 1.0 there is one exposed hero, while the roadmap still counts four journeys (Roadmap §6). This change freezes P0–P8, so P3 is untouched; the owner, or #543 when it exposes Duskblade first-class, should say how the four journeys map onto one exposed class.
- **O2. The duration guard.** The old method's "no material duration regression" is not in the lock's G7, which names stalls and errors only. Carrying it means changing the lock and the bar together, so it is not added here.
- **O3. The roadmap's Edge fallback.** If Edge misses G1 and G2, Roadmap §5 ships Shatter and Lantern as the two clear ways. The bar's claim is three ways, so exercising that fallback is a map decision that amends P9 by a new decision. It is not a waiver, because P9 is not waivable.

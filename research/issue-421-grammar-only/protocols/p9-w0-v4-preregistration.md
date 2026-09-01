# STREAM-B-v4 attribution re-exam preregistration

## Identity and authority

- Protocol identity: `p9-w0-v4-phase-a`.
- Ash authorised this fresh identity under the attribution repair lock at commit
  `5a430b948330a6baf2d9092e81d039978a067fe8`.
- The v3 protocol, result, packet and VETO remain immutable. They are neither
  recoded, pooled nor promoted.
- Implementation baseline: `07533cc3b870d2a673d2b8d5edbb7e6f8bc3036a`.
- Execution parent: `974fc71ef162eeb9e7d6a774bafd81a3cc782884`.

## Repair

The row writer serialises `facetBurstOffered`, `facetBurstDrawn`,
`facetBurstPlayed`, `facetBurstInDeck`, `ceilingFight` and a locally computed
`trajectoryDigest` which erases both `packageEvents` and `policy`.

For every `turnCeiling` row, participation is the sum of the four
`facetBurst*`/in-deck fields. Zero is candidate-free; any positive value is
candidate-touched and fails closed at the first row. The v3 null-card twin is
retired as the attribution oracle. The null-card panel remains an identity and
manufactured-activation check.

## Zero-row preflight

Before a cohort row exists, the runner proves the repair diff is confined to
`research/issue-421-grammar-only/`, while recognising the four documentation
re-anchors already present in the required execution parent. It verifies the
binding lock and every v3 packet digest. On candidate Dusk arm 3 it sweeps
seeds 9000–9049 only until `facetBurstPlayed` becomes positive, proves the
offer/draw/play implication, compares legacy and enriched outcome/RNG fields,
and exercises the policy-erased trajectory digest. Probe rows go only to
`/tmp/glassvow-421-v4-preflight.jsonl` and carry `protocolRows: 0`.

Any preflight failure is `STOP`; no matched-cohort row may then be written.

## Sole matched re-exam

- Arm 3, Duskblade, all four frozen variants.
- Vows 0 and 5; seeds 4000–4199.
- 400 omitted controls and 1,200 comparator rows; exactly 1,600 rows total.
- Policies and content projections are unchanged from v3.
- Every row must reproduce v3 `(outcome, rng)` at its coordinate.
- Exactly ten ceilings must reproduce at the five locked seed/vow coordinates.
- The per-cell bound remains 2.0% (veto at 9/400); the frozen whole-run bound
  remains 0.5% over the original 6,400-row denominator.

`PASS` requires 1,600/1,600 outcome/RNG reproduction, the exact ten ceilings,
zero participation on every ceiling, 3/400 omitted Dusk arm-3 ceilings, and
10/6,400 whole-run ceilings. Any participation, reproduction fault or rate
breach is `FAIL_CLOSED`. Either terminal verdict ends the work: no rescue,
repeat, widening, landscape, P9 claim, push, pull request or merge.

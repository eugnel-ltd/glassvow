# STREAM-B-v3 reliability amendment — p9-w0-v3

This is the fresh identity authorised by Ash in the STREAM-B reliability lock. The lock at
`docs/reviews/421/stream-b-reliability-lock.md` is copied byte-for-byte from commit `8e457351` and
remains the scientific authority. This amendment implements its one observation repair; it does
not re-derive or change the design.

`p9-w0-v2`, execution head `721ebe897b9f263e018a96bd9c445c193a999d79`, and its Phase A packet
remain immutable non-decision evidence. They are not rerun, recoded, pooled or promoted.

## Frozen repair

1. A fight stopped by the unchanged 30-turn ceiling is observed as `turnCeiling`.
2. `turnCeiling` remains in every win-rate denominator and remains a non-win.
3. `turnCeiling`, `stall` and `error` have separate metric buckets. The existing CEM `stall`
   behaviour is unchanged.
4. Every current-main, explicit-off and null-card comparator panel contains arm 3 as well as arm 1.
5. Reliability vetoes on `error`. A `turnCeiling` vetoes if its seed-and-vow-matched null-card
   arm-3 twin does not also yield `turnCeiling`, or if either frozen rate bound is exceeded.

## Frozen rate bounds

- Per `arm × aspect` control cell: **2.0% inclusive, 8 of 400; veto at 9 of 400**.
- Whole run: **0.5% inclusive across all 6,400 emitted rows; veto above 0.5%**.

These are veto thresholds, not a budget, and the unmatched-ceiling rule still binds at one.

## Zero-row admission

Before the sole Phase A invocation, one coherent, clean execution tree must pass all repository
gates named by the lock; retain byte-identical `port_fixtures/` and v2 packet files; prove the
30-turn classification and induced `error` separately; preserve `outcomeDigest` and final RNG for
all 5,197 non-censored v2 rows; retain arm-1 current-main/null-card CRN identity at 400/400; and
assert 1,200 added arm-3 comparator rows and 6,400 total rows.

Any miss stops with zero Phase A rows. Once admitted, invoke Phase A exactly once. There is no
retry, replacement row, parameter rescue, second composite, P9 claim or landscape unless every
locked Phase A gate passes.

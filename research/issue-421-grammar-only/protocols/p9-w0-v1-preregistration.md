# P9 Ward cash-out pilot preregistration — p9-w0-v1

Frozen before any simulator row is executed. This note declares the new pilot identity and its only new valuation law; it does not authorise Phase A or any row.

- Pilot identity: `p9-w0-v1`.
- Acquisition law: each `wardBurst` effect contributes `spend * per` to `card_score`, without an additional coefficient.
- Combat law: when current Ward is strictly greater than both `requires.wardAtLeast` and `_incoming(game)`, add `(spend * per) * wardSurplus` to the play score.
- Frozen `wardSurplus` weight: `4.5`. At the locked fixture's `10 * 2`, this contributes `90`, deliberately anchored near the existing `shatterDusk = 86.1521802982367` term rather than fitted to an outcome.
- Null-card expectation: zero destination activation when content has no `wardBurst` card.
- No simulator row was used to choose or inspect these values. Policy-sensitivity rows remain outside this implementation authority.

# Existing-grammar L2 single-stall diagnosis — #421 surface (b), level L2

## Status

**DECISION BRANCH 2 FIRED — L2 INCONCLUSIVE.**

Exactly one coordinate was replayed from the frozen L2 packet: `L2`, Duskblade, Vow 0,
`RandomBuild`, seed `7191`, raw `rowIndex 1472`. It reproduced the locked stall, terminal RNG
and outcome digest exactly. At the turn-30 cutoff, the Act 3 Sovereign fight was still open and
both combatants had positive HP. This is a real L2 fight cut by the ceiling, not a completed
fight mislabelled by the harness, an execution error, or a determinism mismatch.

The fixed branch-2 disposition is **L2 INCONCLUSIVE**. It is not FAIL CLOSED. It authorises no
same-identity re-run, L3, new primitive, P9 claim, push, or pull request.

## Authority and identity

| Field | Value |
|---|---|
| Diagnosis branch | `codex/421-existing-grammar-l2-stall-diagnose` |
| Diagnosis base | `c28ae38824f7ba2168b573002ab8b90dadd5bde1` |
| Frozen packet head | `51fe17dbc57502a8f2557d43671c1628a6cbd1f3` |
| Protocol | `existing-grammar-l1-l2-v1` |
| Protocol JSON SHA-256 | `3631977a33a25c977421046a176d5d24adf891e3b57419ac6d26262c846af036` |
| Engine | `4.7.2.stable.official.ed1daf0bf` |
| Raw SHA-256 before and after replay | `e6494571d305ef2f93b54e7bef8bf24dc8a9f601e0343f32d4b7186c3c07b092` |
| Scratch replay | `/tmp/glassvow-421-l2-stall-replay.json` |
| Scratch replay SHA-256 | `9d1eb67b8f44506e66729a9f2288aeb251bf632db173d93e791b25a57a7fc347` |
| Diagnosis status | `/tmp/glassvow-421-l2-stall-diagnose-status.json` |
| Diagnosis report | `/tmp/glassvow-421-l2-stall-diagnose-report.md` |

The raw manifest was read from line 1. The diagnosed row was read from raw line 1473. A
parser-only check of the scratch driver produced no replay artifact; the coordinate was then
executed exactly once. The driver invoked the frozen packet's existing simulation helpers and
wrote only to its fresh scratch artifact.

## Locked coordinate reproduced

| Field | Raw and replay value |
|---|---|
| Arm / aspect | `L2` / `duskblade` |
| Vow / policy / seed | `0` / `RandomBuild` / `7191` |
| Raw row | `1472` |
| Outcome / error | `stall` / `""` |
| RNG | `2044296083` |
| Outcome digest | `850eac40cff34b5dd8d7a73bbcd626fb22c2fe189027f22ee59fafc51db4450a` |
| Full replay row equality | exact JSON-object equality with raw row 1472 |

The L2 additions' row-level participation was `shardstorm` offered 2, drawn 0, played 0,
in-deck 0; `flawlessForm` offered 2, drawn 0, played 0, in-deck 0; and zero offer, ownership or
proc counts for `bellOfEndings` and `prismCharm`. These observations do not attribute the row
to an individual ID; the frozen L2 projection is the unit under diagnosis.

## Terminal fight evidence

| Field | Replay value |
|---|---|
| Act / node / encounter | Act 3 / boss `14,3` / `sovereign` |
| Ceiling state | turn `30`, `combatOver = false`, combat result empty |
| Player | HP `27 / 64`, Ward `4`, energy `0` |
| Player statuses | `frail: 1`, `metallicize: 3`, `poison: 2`, `regen: 8`, `weak: 1` |
| Sovereign | HP `75 / 650`, Ward `0`, next move `annihilation` |
| Sovereign statuses | `str: 11`, `vulnerable: 22`, `weak: 52` |

The player and Sovereign were alive, the enemy had lost 575 HP, and combat truth remained
open. The ceiling therefore stopped an active, unresolved fight. Combined with exact row,
RNG and digest reproduction and empty replay stderr, this fires branch 2 rather than the
harness/reliability or unknown branches.

## L1 context boundary

Raw line 449, `rowIndex 448`, was read only as the permitted L1 cell context. It records a win,
RNG `-1427011952` and digest
`5385b68e90beb53f891f897e6a665b73733e47347c4a31e7e18e4e7021e662d0`. It was not treated as a
trajectory twin and supports no per-row causal comparison.

## Decision and non-effects

The diagnosis is complete at branch 2. L2 remains **INCONCLUSIVE**; no ungraded scientific
observation is restated as a verdict.

- The 2,048-row matrix was not re-run and no protocol row was appended.
- The raw, result, status and report input artifacts were not overwritten.
- No seed outside `7191` was replayed; protected and reserve seeds were untouched.
- No product, content, domain, application, presentation, fixture or tool file was edited.
- Main, the diagnosis-lock tree and the frozen exam packet remained clean.
- No push, pull request or follow-on execution was performed.

**STOP.**

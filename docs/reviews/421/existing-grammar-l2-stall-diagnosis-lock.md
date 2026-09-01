# Existing-grammar L2 single-stall diagnosis — #421 surface (b), level L2

## Status

**DIAGNOSIS LOCK ONLY. Not implemented. Zero protocol rows run by this file. No re-run
performed or authorised here. No P9 claim, no L3, no new primitive, no content, domain or
harness edit.**

It does exactly one thing: it bounds the diagnosis of **one row** — the single additional L2
stall that made the exam report `STOP` — and fixes, in advance of the answer, what each possible
finding is allowed to conclude. It is written before the diagnosis precisely so the conclusion
cannot be selected after seeing it.

This is not an amendment to `existing-grammar-l2-lock.md`, not a correction of the protocol, and
not a rescue of the L2 run.

## Authority and inputs

Read and measured in-session, at the heads named. Nothing restated from a summary.

| Fact | Value |
|---|---|
| Parent design lock (READ, not rewritten) | `docs/reviews/421/existing-grammar-l2-lock.md`, sha256 `6fd92a0f0e31b223c0b8d0df29d98de51b9d47b76c51a283ae99feff83c90d71` |
| Exam packet (READ, frozen) | `.codex/worktrees/421-existing-grammar-l2`, head `51fe17dbc57502a8f2557d43671c1628a6cbd1f3` |
| Protocol identity | `existing-grammar-l1-l2-v1`, json sha256 `3631977a33a25c977421046a176d5d24adf891e3b57419ac6d26262c846af036` |
| Exam base tree | `c28ae38824f7ba2168b573002ab8b90dadd5bde1` |
| Local `main` head at diagnosis time | `52a56e726da70c2dd57254e8c6618682c7558f90` |
| Raw rows | `/tmp/glassvow-421-l2-raw.jsonl`, sha256 `e6494571d305ef2f93b54e7bef8bf24dc8a9f601e0343f32d4b7186c3c07b092` |
| Result | `/tmp/glassvow-421-l2-result.json`, sha256 `cc89cb40bc90d62255fda4fa15a0796e7a1cfb163b1319d2482f23494d318d2e` |
| Status / report | `/tmp/glassvow-421-l2-status.json`, `/tmp/glassvow-421-l2-report.md` |

## What the run actually reported

| Field | Value |
|---|---|
| Rows | `2048 / 2048`, complete, row index sequence intact |
| `errors` | `0` |
| `protectedReserveRows` | `0` |
| `additionalStalls` | `1` |
| `integrityFailures` | `["1 additional L2 stall(s)"]` |
| Verdict | **`STOP`** |

`research/issue-421-grammar-only/tools/existing_grammar_l2_exam.py` › `_analyse` sets
`verdict = "STOP" if integrity else ("FAIL_CLOSED" if scientific else "PASS")`. **Integrity
outranks science, so the three recorded scientific misses were never graded.** They are in the
artifact as recorded numbers, not as a verdict, and this lock does not treat them as one.

## The row under diagnosis — exactly one

| Field | Value |
|---|---|
| Arm / aspect | `L2` / `duskblade` |
| Vow / policy | `0` / `RandomBuild` |
| Seed | `7191` |
| `rowIndex` | `1472` |
| `outcome` | `stall` |
| `error` | `""` (empty) |
| `rng` | `2044296083` |
| `outcomeDigest` | `850eac40cff34b5dd8d7a73bbcd626fb22c2fe189027f22ee59fafc51db4450a` |
| `slain` / `perfects` | `32` / `7` |

Cell arithmetic, counted over all 2,048 rows: this is the **only** stall in the matrix. L1
`V0.RandomBuild` stalls `0`, L2 `V0.RandomBuild` stalls `1`, every other cell `0`, so
`additional = max(0, 1 - 0) = 1`.

The L1 row at the same coordinate — `rowIndex 448`, `outcome win`, `rng -1427011952` — is
recorded here as a **cell** comparison only. The arms diverge from the first rare reward; it is
not a trajectory twin and must not be read as one.

## The `turnCeiling` question, settled by measurement

`tools/balance_sim.gd` contains **zero** occurrences of `turnCeiling` at `c28ae388` (exam base),
at `52a56e72` (local `main` head), and at `51fe17db` (execution head — the L2 packet's own edited
copy). The separation proposed in
`.claude/worktrees/421-stream-b-reliability-lock/docs/reviews/421/stream-b-reliability-lock.md`
was never landed in any of the three trees, so the packet does not carry it either.

The consequence, read from the packet's code rather than inferred: `_fight` leaves its loop
either with `game.cb.over` true — which yields `win` or `loss` — or on `game.cb.turn >= 30`, and
`simulate` labels the second case `"stall"`. A hang, a crash, an unreachable node or an exhausted
route surfaces as `outcome: "error"` with a non-empty `error` string; **this row's `error` is
empty.**

So `stall` here is the 30-turn ceiling and nothing else, and the one label carries two different
worlds without distinguishing them: a fight the ceiling genuinely had to cut, and an ordinary
fight the ceiling truncated. **That ambiguity is why this is a diagnosis and not a verdict.**

## Allowed diagnosis actions — exhaustive

1. **Replay that one coordinate.** L2 projection, `duskblade`, vow `0`, `RandomBuild`, seed
   `7191`, off the frozen packet at `51fe17db`, and read the fight it ends on: act, node kind,
   enemies, turn count at the break, and both sides' hp/ward/status there.
2. **Read the raw row** at `rowIndex 1472` in the raw artifact, including its participation
   fields, and the manifest line.
3. **Read the L1 cell row** at the same coordinate (`rowIndex 448`) for context.

Any replay writes to a fresh scratch path. It does not overwrite the raw, result, status or
report artifacts, does not append a protocol row, and does not change the raw SHA-256.

## Forbidden

- Re-running the 2,048-row matrix. Only decision-rule branch 1 below can authorise that, and
  only after the diagnosis.
- Retuning any threshold, bound, band, vow set, seed band, estimand, bootstrap root, or the
  `additionalStallsAllowed 0` budget.
- Dropping an authored id from `hundredShards` or `untouched` to make the row behave.
- **Twin-matching.** Do not read the L1 row as a per-row causal twin of the L2 row, and do not
  form any complementarity from twin lookup. This is the STREAM-B v3 attribution error and it is
  named here so it cannot happen quietly.
- L3, under this lock or as a consequence of any finding below.
- New content or a new primitive; any edit under `content/`, `domain/`, `application/`,
  `presentation/`, `port_fixtures/`, or `tools/`.
- Any P9 / #108 change, denominator, threshold or claim.
- Reopening or pooling STREAM-B, Emberglass, Kindle, ward-mirror-edge, Stun-in-Shatter, #461, or
  any capacity-closed family.
- Touching acceptance seeds `3000–5199` or reserve `5200–5399`.

## Decision rule — fixed now, applied after the diagnosis

1. **Harness or reliability fault** → authorise **ONE** re-run of the **same** protocol
   `existing-grammar-l1-l2-v1`, same seeds `7000–7255`, same arms, policies and vows, **no
   identity change** — no new version, no correction increment, no band move. One. If the re-run
   stalls again, the finding is branch 2 or branch 3, never a second re-run.
2. **L2-caused real stall** — the added ids produced a fight the ceiling genuinely had to cut →
   **L2 is INCONCLUSIVE.** Do **not** record FAIL CLOSED: integrity outranked science and the
   science was never graded. Do **not** proceed to L3. Do **not** authorise a new primitive. Do
   not restate the recorded scientific misses as a result.
3. **Unknown** → **STOP.** Report the coordinate, the fight, and exactly what could not be
   determined. Do not guess, and do not pick whichever branch unblocks the next piece of work.

Nothing in any branch authorises promotion, detector work, a second package, or a P9 claim.

## STOP conditions for the diagnosis itself

- The replay does not reproduce the stall at seed `7191`. That is a determinism finding larger
  than the stall — stop and report it as such.
- The diagnosis would require editing `tools/`, `content/`, `domain/`, `application/`,
  `presentation/` or `port_fixtures/`.
- The diagnosis would require any row outside seed `7191`.
- The raw artifact's SHA-256 no longer matches the value recorded above.

## What this lock does not do

- It runs zero protocol rows and edits zero harness or product lines.
- It does not diagnose, and it does not pre-judge which branch fires.
- It does not authorise the re-run; branch 1 does, and only after a finding.
- No push, no PR, no Codex dispatch, no P9 touch.

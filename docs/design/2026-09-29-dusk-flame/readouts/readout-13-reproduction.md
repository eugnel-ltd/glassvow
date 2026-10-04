# Readout 13, reproduced from the repository

> **What this is.** An independent re-run of the Duskblade Flame's reading of record (readout 13) with `tools/balance_readout.py`, the readout runner that #544 P2 puts in the repository. Every run row matches the archived rows of readout 13, so the runner reproduces the reading and the reading stands. It ships no content or simulator change.
>
> **Runner head.** `ed902396` (the commit that adds `tools/balance_readout*.py`, on `e0d313e2`, #544 P1). Content file SHA-256 `e9c4d48fbe38542e65a9c73f73b4c50f72116026d4be51a81b7a9b04ec33ca7b`, driver SHA-256 `455911721ffadcf17582e92467ed765eb087c4480bd81e6d55abf1d2d2c5a910`, pilot `p8-d0-v3`, search `s1`, Godot 4.7.2-stable: all identical to readout 13's manifests (`1190be25`). `ed902396` is the runner's commit before this branch was rebased onto main for merging; the runner's files (`tools/balance_readout*.py`) and `tools/balance_ways.py` are byte-identical at the merged head, so the run is the merged code's.

## What was re-run

Readout 13's final tables, search player, with the three-seed arm-A replay per cell, in 50-seed chunks:

| Table | Seeds | Cells | Arms |
|---|---|---|---|
| V0 | 13000–13999 | v0-fresh, v0-full | C_shatter, C_lantern, C_edge, A, A_lit, R, and the replay |
| V5 | 13000–14999 | v5-fresh, v5-full | the same |
| G3 extension | 15000–16999 | v5-full | C_shatter, C_lantern, C_edge, A_lit |

Readout 13's G3 figure at V5 full is read on 4,000 common seeds, the V5 table's band joined to the extension.

## Exact commands

Run from a clean detached worktree at `ed902396` (no commit was made during the run, so every chunk names one commit), with `override.cfg` setting `config/use_custom_user_dir=true` and `config/custom_user_dir_name="glassvow-readout-p2"` under `[application]`; the runner refuses to start without it.

```sh
python3 -B tools/balance_readout.py run s/final-v0 --seeds 13000-13999 --cells v0-fresh,v0-full --play search --replay --chunk 50 --jobs 8
python3 -B tools/balance_readout.py run s/final-v5 --seeds 13000-14999 --cells v5-fresh,v5-full --play search --replay --chunk 50 --jobs 8
python3 -B tools/balance_readout.py run s/ext-v5 --seeds 15000-16999 --cells v5-full \
    --arms C_shatter,C_lantern,C_edge,A_lit --play search --chunk 50 --jobs 8
python3 -B tools/balance_readout.py join s/g3-4000 v5-full C_shatter,C_lantern,C_edge,A_lit s/final-v5 s/ext-v5
python3 -B tools/balance_readout.py compare s/final-v0 <archive>/final-v0     # and final-v5, ext-v5, g3-4000
python3 -B tools/balance_readout.py table s/final-v0 s/final-v5 --v0-seeds 13000-13999 --v5-seeds 13000-14999
python3 -B tools/balance_readout.py g3 s/final-v5 v5-fresh,v5-full
python3 -B tools/balance_readout.py g3 s/g3-4000 v5-full
```

The archive of readout 13 (the NAS scratch archive) kept the 50-seed chunk reports but not the merged reports, so `compare` merges the archived chunks on the fly with the same manifest checks. The archived chunks were also merged (`balance_readout.py merge`) and graded with the new commands, to confirm that the new graders read the archive as readout 13 printed it.

## Host and time

MacBook Pro (Apple M1 Max, 10 cores), macOS 27.0, Godot 4.7.2.stable.official. The host was shared and heavily loaded throughout (load average 46 at the start, above 200 for much of the run), with eight jobs from this run among them.

| Step | Wall time | Readout 13 (ten processes, lighter host) |
|---|---:|---:|
| V0, 242 chunks | 5,364 s | 2,646 s |
| V5, 482 chunks | 4,885 s | 2,953 s |
| Extension, 80 chunks | 2,198 s | about 1,560 s |
| Total | 12,447 s (3 h 27 min; 12:12 to 15:40 UTC, 4 Oct 2026) | about 7,160 s |

## Match result

| Row set | Reports | Rows compared | Identical | Different | Missing |
|---|---:|---:|---:|---:|---:|
| V0 final | 14 | 12,006 | 12,006 | 0 | 0 |
| V5 final | 14 | 24,006 | 24,006 | 0 | 0 |
| G3 extension | 4 | 8,000 | 8,000 | 0 | 0 |
| G3 4,000-seed join (derived) | 4 | 16,000 | 16,000 | 0 | 0 |
| **Run rows re-run** | | **44,012** | **44,012** | **0** | **0** |

A row is identical when the whole row (outcome, deck, fights, flame descriptor, rng and the rest) is equal. The only manifest field that differs in any report is `commit` (`1190be25` then, `ed902396` now); content, driver, pilot, search, policy and Godot version are equal.

Digest of every row set, report by report in directory order (SHA-256 over each report's rows with sorted keys): the re-run `c5e0d89565d092b2681cec988343093889208d6abaf95777cb63666f594b6e8d`, the archive `c5e0d89565d092b2681cec988343093889208d6abaf95777cb63666f594b6e8d`. Identical.

## The tables

The merged tables, gate verdicts, row B and paired G3 are text-identical between the re-run and the archived rows graded by the same commands (table digest `ec92ccdd4fddfc0f599dfb299833518803fcca9f838a112531f4ed1de4c16849` for both). They also agree with readout 13's own record: the archived `fulltable-final.md` matches on every win rate, measured value, point verdict, interval and interval verdict, and all 36 gate interval strings and the eight row B rows of the cells appear verbatim in `readout-13.md`.

| Cell | C_shatter | C_lantern | C_edge | A | A_lit | R |
|---|---|---|---|---|---|---|
| V0 fresh | 20.8% (18.4–23.4) | 33.6% (30.7–36.6) | 21.2% (18.8–23.8) | 24.1% (21.6–26.8) | 32.0% (29.2–35.0) | 7.1% (5.7–8.9) |
| V0 full | 49.3% (46.2–52.4) | 47.6% (44.5–50.7) | 39.6% (36.6–42.7) | 38.8% (35.8–41.9) | 47.1% (44.0–50.2) | 17.6% (15.4–20.1) |
| V5 fresh | 1.2% (0.8–1.8) | 3.8% (3.0–4.7) | 1.5% (1.0–2.1) | 2.0% (1.5–2.7) | 3.5% (2.8–4.5) | 0.4% (0.2–0.9) |
| V5 full | 17.3% (15.7–19.0) | 12.2% (10.8–13.7) | 12.2% (10.9–13.8) | 11.8% (10.4–13.2) | 13.8% (12.4–15.4) | 3.9% (3.1–4.8) |

Paired G3 (A_lit minus the best committed arm, Newcombe 1998 method 10 for paired proportions, built from the two Wilson intervals and the phi correlation):

| Cell | Best committed | Point | Paired 95% interval | Verdict (point / paired) | phi |
|---|---|---:|---|---|---:|
| V5 fresh, 13000–14999 | C_lantern | −0.3 pp | −1.4 to +0.9 pp | PASS / PASS | 0.00 |
| V5 full, 13000–14999 | C_shatter | −3.5 pp | −5.6 to −1.4 pp | FAIL / UNDECIDED | 0.11 |
| V5 full, 13000–16999 (4,000 seeds) | C_shatter | −3.5 pp | −5.0 to −2.0 pp | FAIL / UNDECIDED | 0.11 |

These are readout 13's figures (`readout-13.md`, "G3 at V5 full, on 4,000 common seeds"). Row B at V0 reads as printed there, for example C_edge B2 PASS in both pools, A_lit B2 FAIL in the fresh pool.

## What was not reproduced

- The reference columns of readout 13's tables (the improved-bot baseline and readout 12). Their reports are not in the archive (the baseline's merged copies and readout 12's reports are absent), so only the columns measured by this table are compared. Those columns carry no new information about the Duskblade.
- `merge13.py`, which stamped scratch copies of mixed-commit reports for the baseline table, has no counterpart: the runner refuses to merge reports of different content, tools or instruments.

## Findings

No difference was found, so there is no runner bug and no drift to diagnose. Content, simulator sources and the pilot and search versions are unchanged since readout 13, and the run is deterministic: Duskblade's reading of record is reproducible from the repository at this head. The wall time was about 1.7 times readout 13's because the host was shared and loaded, not because of the runner.

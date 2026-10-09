# The Flame balance runbook — running a class's programme with the repository's tools

**Status:** active runbook, 2026-10-05 (#544 step P4b). Owner: James. Companion to the Duskblade's lock ([`README.md`](README.md)) and the class template ([`ways-template.md`](ways-template.md)).

This file says how a class's Flame balance programme is run, end to end, with the repository's own tools. It binds nothing new. The measurement contract is the class's lock §11; what every class inherits is the template's §3; which gates are graded, and how a verdict binds a release, is [`docs/rc-bar.md`](../../rc-bar.md) P9. Where this file and those differ, they are current and this file is wrong. Every command below was checked against the code and its `--help` at `271ce1b1`, and what #544 P7 changed (the graders' pools and catalogues, the isolation guard, the identity, the holdout and the equivalence comparer) against that PR's code; none was run to write it.

The Ashwarden programme (#544) is the first to run on these tools from its first step, and the pipeline is its point (owner, 4 October 2026: "by doing ash, you solid the pipeline/workflow"). PR #692's Ash lock and its readout A0 are the worked example of a new class's first steps.

## 0. A programme, in order

1. Isolate every worktree that will run Godot (§1).
2. Check that the bots can play the class's verbs. If they cannot, the instrument changes first, and every class already shipped is read again under it (§10).
3. A development baseline and tagging screens on development seeds (readout A0).
4. The class's lock: its ways, affinity, cells and thresholds, with §11 by reference to the Duskblade's.
5. The content lands dormant, and no other class's run moves (§7, §8).
6. The first reading on the bands of record. The thresholds freeze after it (template §3).
7. Wall lanes: diagnose, screen at most three single-lever candidates per way on development seeds, and read the survivors on the bands of record.
8. The reading of record and the verdict (§6); then the exam on the release candidate.

## 1. Isolation

Before the first Godot command in a worktree, the import included, put an `override.cfg` beside `project.godot` holding exactly these three lines:

```
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="glassvow-<purpose>"
```

- **Why both keys and the header.** Godot ignores `config/custom_user_dir_name` unless `config/use_custom_user_dir` is true. Keys written above any section header are not application settings, so a file without `[application]` isolates nothing, however correct its keys.
- **The hazard.** An unisolated run writes into the owner's real profile, `~/Library/Application Support/Godot/app_userdata/Glassvow/`, beside the real run save, the Vigil and the settings (`glassvow_run_v2.json`, `glassvow_vigil_v2.json`, `settings.cfg`). Never read, write, move or delete anything under `app_userdata`. Isolated, the data lands in `~/Library/Application Support/glassvow-<purpose>/`; list that folder after the first command to see that it did.
- **What refuses.** Every balance tool that starts Godot checks the file (`tools/balance_readout_guard.py`) before it writes anything and again where it launches Godot, names what is missing and prints the block: `tools/balance_readout.py run`, `tools/balance_ways.py` without `--from-dir`, and the #421 and exam tools (`balance_exam.py`, `balance_f0.py`, `balance_f1_cem.py`, `balance_phase_a.py`, `balance_host_qualify.py`; #544 P7). Nothing else checks: `godot --headless --import`, a direct `godot -s res://tools/balance_sim.gd` and the test suite all start Godot without it.
- **Never commit it.** `override.cfg` is not in `.gitignore`. Stage by name.
- **One name per lane** (`glassvow-readout13`, `glassvow-ash-a0`), so no two lanes share a user directory.
- **One name per worktree.** A lane's authoring worktree and its run worktree (§4) each take their own name (`glassvow-ash-a2` and `glassvow-ash-a2-run`). Then a test suite in one never shares a user directory with a simulator in the other.

## 2. Instruments and seeds

**The instruments.** A run is built by a pilot and, under `--play search`, played by a search player. The pair is the instrument.

| Instrument | Pilot | Search player | Where it is used |
|---|---|---|---|
| 1.0's, of record | `p8-d0-v3` | `s1` | The tools' default. Readout 13, 1.0's reading of record. The 1.0 release candidate's independent re-run, which names it explicitly (P9) |
| 1.1's | `p9` | `s3` | Every Ashwarden run and the Duskblade's 1.1 requalification, named on every run |
| 1.1's first | `p9` | `s2` | [Readout 14](readouts/readout-14.md), the Duskblade's interim reading; kept selectable |

By the orchestrator's ruling of 5 October 2026, the 1.1 search player is `s3` (#544 P6b): `s2`'s honest play plus the credit for a Smolder tick that kills before the enemy acts. Readout 14's interim reading was made under `s2`. `s3` differs from it for the Duskblade only in `full` cells, through the Ashfall omen's starting Smolder (sample: 200 seeds a cell, 13000–13199: 485 of 2,400 V0 and V5 `full` rows changed and 55 outcomes flipped, no arm's paired change significant, every p ≥ 0.45; one graded point verdict crossed its line, G6 at V0 full, edge 60.6% → 59.8% of A_lit's wins, UNDECIDED on interval under both). The Duskblade is re-read under `s3` on the combined product at A9, and the cross-class reading uses `s3` for both classes.

- Name the bots on every run, whichever they are: `--play search --pilot p9 --search s3`. Greedy play names `--pilot` alone; the runner, the grader and the simulator refuse a search player without `--play search`. Every chunk's command and every report's manifest record the pair, and the grader refuses a table that mixes pairs.
- The default stays 1.0's until 1.0 ships. Moving it is a change of two constants, `Pilot.VERSION` and `Search.VERSION`, once the 1.0 re-run is done (readout 14, *What the orchestrator must decide*, item 8).
- **Selection is static.** `Pilot.select` and `Search.select` set state that outlives the call. A test that selects the 1.1 bots ends by restoring 1.0's, `Pilot.select(Pilot.VERSION)` and `Search.select(Search.VERSION)`, as `tests/test_balance_invariance.gd` and `tests/test_balance_bots_hand.gd` do (§12).

**The seed bands.** A class reads on the Duskblade's bands, so its figures pair with the Duskblade's on the same seed.

| Band | Use |
|---|---|
| 12000–12999 | Development: screens, probes, baselines not of record, and the invariance panel (12000, 12001). **Never in a verdict** |
| 13000–13999 | The V0 cells of a reading of record: 1,000 paired seeds a cell |
| 13000–14999 | The V5 cells: 2,000 a cell |
| 15000–16999 | G3 at V5 full only: joined to 13000–14999 for 4,000 common seeds |
| 3000–5199 | The acceptance band, kept for the exam. The CEM stress trains on 4200–4999 and reads its ceiling once, on the historical holdout 5000–5199. The runner and the grader refuse any band that touches 3000–5199 |
| 17000–18999 | 1.1's holdout, reserved (#544 decision 7) for the A9 exam. **Refused** unless named: `--holdout-1-1` on `balance_ways.py` and on `balance_readout.py run` and `table`, which pass `--holdout=1.1` to the simulator; the simulator, the sweep and the CEM refuse it without that option, and with it every manifest records `"holdout": "1.1"` (#544 P7). The seed contract's stages and phase A never reach it |

The lock's floor is 200 paired seeds a cell. Every arm of a cell plays the same seeds (common random numbers), which is what makes the paired tests and paired G3 possible.

## 3. Arms and cells

**Cells.** Vows {0, 5} × two pool states. A class playable from a new Vigil reads `fresh` and `full`. A class that unlocks later reads `entry` in `fresh`'s place (template §3; §8 below). The simulator's pools (`--pool`):

- `fresh`: a new Vigil, no reveals and no unlocks;
- `entry`: the Vigil just after the class unlocks (§8);
- `full`: every reveal and every deed's unlocks.

The simulator's own default, `mature`, is historical; the runner always names a pool. **The graders read the class's own cells** (#544 P7; §8): `fresh` and `full` for a class playable from a new Vigil, `entry` and `full` for one whose content row names an `unlock`. `table`, `rowb` and `balance_ways.py --from-dir` grade those, and `g3` and `paired` refuse a cell the class does not have. `run` takes its cells as given, so name the class's own: `--cells v0-entry,v0-full` for the Ashwarden.

Which cells each gate grades is the lock's §11 (G1 and G5 are not graded at V5 `fresh`; row B is read at V0).

**Arms.** Each is one `balance_sim.gd` policy, and every arm plays its fights alike; arms differ only in how they build.

| Arm | Flags | How it builds | What reads it |
|---|---|---|---|
| `C_<way>` | `--way=<way> --build=adaptive` | The committed bot (readout 13, from `p8-d0-v3`): its way's glass ×3.0 (`commit`) for the first two copies of a card, a further copy weighed as clear glass; other coloured glass ×0.5; it steers shops and removals the same way and removes its off-colour starter seeds first whenever a removal is offered | G1, G2, G5, row B |
| `A` | `--way=none --build=adaptive` | Reads the offers, not its lantern | G3 and G6 floors, reported |
| `A_lit` | `--way=none --build=lit` | As A until its lantern burns a way's colour, Steady or True; then that way's glass ×2.0 (`litLean`) and other coloured glass ×0.5 (`litOff`), until the flame dims. It keeps A's removal | G3, G6; its B2 read beside the committed arms' |
| `R` | `--way=none --build=random` | At random | G4 |
| replay | arm A, the first three seeds of the cell (`--replay`) | | G7's deterministic replay |

The committed arms come from content: one `C_<way>` per way, in content order. A class that declares no ways has A, A_lit and R only (A_lit then plays as A, row for row), and every grader that reads the committed arms refuses it with a message.

## 4. The runner

`tools/balance_readout.py` runs a cell table in chunks and reads it; `tools/balance_ways.py` is the grader it calls. Run both from the worktree root with `python3 -B`.

**The run worktree.** Run from a clean, detached worktree at the commit under test, and make no commit in it while a run lasts: every report's manifest names `git rev-parse HEAD`, and a merge, join or table refuses reports that name different commits. Author in another worktree.

```sh
git worktree add --detach <scratch>/wt-<lane> <commit>
# override.cfg in <scratch>/wt-<lane> (§1), then, from that root:
godot --headless --import      # once per worktree, and again after moving its head
```

**The commands.** The table runs are readout 14's commands with the 1.1 search player as ruled on 5 October 2026, `s3`; readout 14 itself ran `s2`.

| Command | What it does and writes |
|---|---|
| `run s/v0 --seeds 13000-13999 --cells v0-fresh,v0-full --play search --pilot p9 --search s3 --replay --jobs 6` | Plans every chunk (cell × arm × seed band), runs those not done, `--jobs` at a time, and merges them. Writes `s/v0/parts/<cell>-<arm>-<first seed>.json` (one simulator report a chunk), its `.chunk.json` sidecar and its `.log`; then one merged `s/v0/<cell>-<arm>.json` per cell and arm, and `<cell>-replay.json` under `--replay`. Options: `--cells` (default `v0-fresh,v0-full`), `--aspect` (default `duskblade`), `--arms` (default every arm of the class), `--chunk` (50 seeds), `--jobs` (4; 1 to 16), `--content` (a scratch catalogue), `--way-weights COMMIT/OFF`, `--godot` |
| `run s/v5 --seeds 13000-14999 --cells v5-fresh,v5-full --play search --pilot p9 --search s3 --replay --jobs 6` | The V5 table, likewise |
| `run s/ext-v5 --seeds 15000-16999 --cells v5-full --arms C_shatter,C_lantern,C_edge,A_lit --play search --pilot p9 --search s3 --jobs 6` | G3's second V5 full band: the four arms G3 reads, no replay |
| `join s/g3-4000 v5-full C_shatter,C_lantern,C_edge,A_lit s/v5 s/ext-v5` | Joins one cell's arms across directories of disjoint bands into `s/g3-4000/<cell>-<arm>.json`, and prints each arm's count, first and last seed. The bands must share their manifests apart from the seeds: the same commit, content and bots |
| `merge <dir> [--out <dir>]` | Merges a directory's `parts/` into one report per cell and arm, with the same checks, for an archive that kept only its chunks |
| `table s/v0 s/v5 --v0-seeds 13000-13999 --v5-seeds 13000-14999 [--ref <v0 dir> <v5 dir>]… [--tidy]` | Prints the complete §11 table: win rates, every gate in every cell on point and interval, and row B. Each `--ref` pair adds a column of that table's verdicts. `--tidy` prints the readout's gate table, bold where a verdict moved from the last reference; it needs one `--ref`. It reads the replay reports, so the two tables must run with `--replay` |
| `g3 s/g3-4000 v5-full` (and `g3 s/v5 v5-fresh,v5-full`) | Prints paired G3 on common seeds: the best committed arm, the point, Newcombe's paired 95% interval, the verdicts on point and interval, the 2 × 2 counts and phi. `--adaptive` defaults to A_lit |
| `rowb s/v0 [--ref <dir>]` | Prints row B at V0 (`--vow`): B1 and B2 for each committed arm and A_lit in both pools, with the reference's verdicts beside |
| `paired <new> <base> v0-fresh,v0-full [--arms …]` | Prints each arm's paired change between two runs on the same seeds: points, seeds gained and lost, the exact two-sided binomial p, and the rows identical. It reads rows, not manifests, so name and check the two heads yourself |
| `compare <a> <b> [--reports …]` | Compares every run row of every shared report, seed by seed; exits 2 on any difference or missing seed, and lists the manifest fields that differ (the commit is expected to; content, tools and bots are not). The proof that a re-run reproduces a reading |
| `equivalence <candidate> <reading> [--commit <full SHA>]` | P9's content equivalence for the class: every run of either directory paired by cell, arm and seed on the graded fields, each replay against its arm-A run, and the manifests' instrument (bots, player, Godot, cell, arm and the arm's `policy`); exits 2 unless equivalent. `--commit` also requires every report of the candidate to name that commit, the RC's |
| `candidates content/full-content.json <spec.json> <out dir> [--names …]` | Writes scratch catalogues for `run --content`, one per candidate, each a minimal text edit per lever (`affinity`, `knob`, `strip_rider`; `a+b` joins candidates). Keep them out of the repository |

`tools/balance_ways.py --from-dir <dir> --seeds 13000-13999 --vows 0` re-grades one vow's saved reports and prints each cell's tables: rates, per-fight stats, the feel table and the gates. Its own run mode (`--out-dir`) checks isolation but is neither chunked nor resumable: run through `balance_readout.py run` instead.

**Grading a scratch catalogue.** `table`, `g3`, `rowb`, `paired` and `balance_ways.py --from-dir` take `--content <catalogue>`, the file the reports ran on (`run --content`): the class's ways and pools come from it, and every report graded must name its SHA-256 (`contentFileSha256`), or the grader refuses. A `--ref` table and the base of `paired` may stand on other content and are not checked. Without `--content` the ways are `content/full-content.json`'s, and a directory holding a committed arm the class does not have is refused, so a catalogue that adds ways is graded with `--content` or not at all (§8).

**Chunking and resume.** A chunk is one simulator command over 50 seeds of one cell and arm. Its sidecar records the command and an identity: the SHA-256 of the content file (or of `--content`), of each file the simulator loads outside `domain/` (`TOOL_SOURCES`: `balance_sim.gd`, `balance_search.gd`, `balance_pilot.gd`, `balance_policy.gd`, `balance_metrics.gd`, `balance_classes.gd`, `balance_classes.json`, `balance_catalogue.gd` and `vow_incentives.gd` under `tools/`, and `content/content_db.gd` and `content/line-table.json`), and one digest over every `.gd` file under `domain/`, committed or not. The manifest's `driverSha256` (`BalanceCatalogue.DRIVER`) covers the same files with the sweep and the CEM, and `tests/test_balance_readout.py` derives the simulator's load graph and fails when either list lacks a file in it.

- Rerunning the same command into the same directory resumes: a chunk with its report and its sidecar is never run again, and the summary line counts how many ran.
- A chunk whose sidecar names another identity, or another command (play, bots, weights, chunking, arm or `--content` path; only the report path may differ), is refused, never reused: start a new directory.
- A Godot `ERROR:` or `SCRIPT ERROR:` line in a chunk's log fails the run. Fix the cause and rerun the same command; finished chunks are kept.
- The identity covers every file the simulator loads (#544 P7 added `vow_incentives.gd`, `balance_catalogue.gd`, `content_db.gd` and the line table), but a dirty tree is not detected at merge: the manifest names the commit, not the working tree. The clean, detached run worktree is the guard.

**Manifests.** Every report carries the manifest the simulator writes: the commit, the content's file and semantic SHA-256, the simulator's driver digest, the Godot version, the pilot, the player, the search version and line cap, the class, vow, pool, way, build, policy, mix and seeds. `merge` and `join` refuse reports whose manifests differ apart from the seeds; the grader refuses a table that mixes commits, content, players, bots or committed weights. So no table can mix instruments. Instruments are compared only by pairing two tables (`paired`), never by merging them.

**Jobs and load.** One host is usually shared with other lanes.

- Cap `--jobs` at what the host bears beside them: readout A0 ran six on a host shared with three other lanes. The runner sets no niceness; prefixing the command with `nice -n 10` passes it to every Godot child.
- Run in the background with a status log: each step's start and end time, exit code, seconds, load average and free disk.
- Never kill a Godot process you did not start.
- **Durable storage, a detached driver, a resumable runner.** A long batch's raw rows, its driver script and its handoff belong in durable storage (the repository's git-ignored `.claude/worktrees/`, or the archive of §11), never in `/private/tmp`, which macOS empties on reboot (§12). Start the driver detached, `nohup caffeinate -i <driver> &`, so that neither a closed session nor the host's sleep stops it. Let it run one batch at a time, check free disk before each, and append each batch's START and END lines (wall time, exit code, load average, free disk) to a `status.log`. The runner resumes: rerunning the same command into the same directory keeps every finished chunk.
- Plan on 1.7–1.8 s a run per process on a quiet host (readout 13) and about twice that under load (readout 14, *Cost*). Measured:

| Work | Runs | Jobs | Wall time | Host |
|---|---:|---:|---|---|
| Readout 13's V0 and V5 tables; its second V5 full band | 36,012; 8,000 | 10 | 44 + 49 min; 26 min | Lightly loaded |
| #544 P2's re-run of the same | 44,012 | 8 | 3 h 27 min | Load average 46 at the start, above 200 for much of it |
| Readout 14, first candidate (`516be99f`) | 48,812 | 8 | 3 h 42 min | Shared |
| Readout 14 at its fixed head (`3dcbe37b`) | 48,812 | 6 | 5 h 42 min | Load average 160 to above 900 |
| Ash readout A1 (`faa98347`, `s3`): V0; V5; G3's second band; the Duskblade's A_lit | 12,006; 24,006; 8,000; 1,000 | 4 | 2 h 9 min; 3 h 1 min; 1 h 18 min; 11 min (6 h 38 min in all) | Shared with another project's CI, `nice -n 10`; load average 5 to 47 at each batch's start and end |

Per run per process (wall time × jobs ÷ runs), Ash readout A1 read 2.57 s for V0, 1.81 s for V5, 2.33 s for the second band and 2.61 s for the Duskblade's A_lit at V0 full. Readout 14 read 3.76 s (V0) and 2.11 s (V5) under `s2`, on six jobs at a far heavier load. A V5 table costs less a run because its runs are shorter: more of them die early.

## 5. Grading

**What each gate is read from.** Thresholds are the lock's §11 with its recorded amendments; P9 says which gates are graded.

| Gate | Role (P9) | Read from | Interval |
|---|---|---|---|
| G1 | Reading | `table` | Wilson, each committed arm |
| G2 | Graded | `table` | Newcombe's hybrid score interval for each pair of committed arms: PASS only when every pair's lies within ±10 pp, FAIL when any pair's lies wholly beyond |
| G3 | Graded | `g3`, paired on common seeds; at V5 full on the 4,000-seed join | Newcombe's paired interval. The `table` row is the independent interval, wider where the arms' outcomes on a seed correlate |
| G4 | Reading | `table` | Newcombe for R − worst, Wilson for R |
| G5 | Graded | `table`, over the runs alive at the act's end, the all-runs figure beside it | Wilson over the survivors |
| G6 | Graded (A_lit) | `table` | Wilson on each way's share of A_lit's wins |
| G7 | Graded; a miss is always NOT ACCEPTED | `table`: stalls, errors, the replay | None (counts). The CEM stress and the save-lineage and id checks are the exam's (§6) |
| B | Graded | `rowb` | Wilson over runs (B1) and over fights (B2) |

The G3 and G6 floors (arm A) are reported, never graded.

- **Point and interval.** Every gate is graded twice: on the point estimate and on its 95% interval. An interval that straddles the threshold is UNDECIDED; a FAIL on interval is a *decided* FAIL.
- **Short of its threshold** means FAIL on point or FAIL on interval (P9). A figure that passes on point and is UNDECIDED on interval is not short; it stays in the table.
- **Wilson, Newcombe, paired.** A rate's interval is Wilson's. A difference between two arms in the grader is Newcombe's hybrid score interval (method 10), built from the two Wilson intervals as if the arms were independent; on common seeds that is conservative. G3 is graded paired (from readout 13): Newcombe's method 10 for paired proportions, from the two Wilson intervals and the phi correlation of the 2 × 2 table, narrower than the independent one when the arms' outcomes on a seed correlate.
- **Paired changes.** `paired` counts the seeds one configuration wins and the other loses, with the exact two-sided binomial (McNemar) p. Across many arm-cell tests, correct for their number before calling one significant: readout 14 read 28 at 0.05 / 28 ≈ 0.0018, and none survived.
- **Clustering.** B2's expression and close calls are counted over fights, and their Wilson intervals treat each fight as independent. Fights of one run share its deck, so the honest interval is wider. Where a verdict turns on a B2 figure within a point of its line (A_lit's feel at V0 fresh: 58.6%, 57.9–59.4, against 60%), read it again clustered by run before calling it decided; #691's calibration reported case-clustered bootstrap intervals beside Wilson for the same reason. No repository command does this yet. Ash readout A1 used a scratch run-clustered bootstrap (2,000 resamples of whole runs), under which two of its B2 FAILs, expression a point under 60%, became UNDECIDED. The other gates count runs and need no such correction.
- **Deciding an UNDECIDED.** The half-width shrinks with the square root of the seeds. State how many seeds would decide a figure rather than run them by default: readout 13 put G3 at V5 full's at about 36,000 paired seeds an arm, and stopped.
- **The cross-class reading.** The new class's A_lit minus the Duskblade's at V0 full, on the same seeds, instrument and commit: reported, not gated; above +15 pp it triggers a diagnosis (template §3). `paired <new class dir> <Duskblade dir> v0-full --arms A_lit` gives the gap and its exact p; the paired interval is not a repository command yet: readouts A0 and A1 computed it with a scratch script through `balance_readout_stats.paired_difference`.

## 6. The verdict

- **Who.** The orchestrator, under the owner's delegation of design calls (30 September 2026). James's play reports are input, never a gate.
- **On what.** One reading of record: a readout's complete §11 table, the content SHA-256 it ran on and its instrument. A readout gives no verdict; it ends with what the orchestrator must decide.
- **Its form** (P9; template §3). ACCEPT or NOT ACCEPTED on whether the design's intent holds, with the gate figures as its evidence, not a count of passes. For every graded figure short of its threshold, the record says why the gate's intent still holds or names a reservation that carries it. A reservation states its figures and the readout that will answer it; it is part of the verdict, not a waiver. A G7 miss is NOT ACCEPTED. A release reviewer checks that every short figure has its answer, and does not re-derive the judgement.
- **Its record.** The class's lock §11, under *Verdict*, as it happened: numbered and dated, each ruling with its grounds, the replaced ones kept. P9 binds it. A ruling given on a readout is also appended to it as its last section (readout 14, *The orchestrator's ruling*).
- **Interim readings.** A reading on content that is not the product's, or before the combined product exists, is an interim reading, not a verdict, and says so in its head note and in the record. Readout 14 is one: on 1.0's content under the 1.1 instrument, the Duskblade's intent holds with the same one reservation, and the 1.1 verdict is given at step A9 on the combined product.
- **A ruling re-made on fixed evidence.** Readout 14's first ruling (4 October) rested on the first candidate's `s2` (`516be99f`). Review found that its payoff credit could use a card the line had only just drawn; the fix round (`5ff8c1b1`, `3dcbe37b`) also priced the drawn cards against the Energy left. Every table was played again at `3dcbe37b`, and G2 at V0 fresh moved from a decided FAIL (16.8 pp) to 13.5 pp, UNDECIDED, so the first ruling's items 3 and 4 lost their ground. The restated ruling (5 October) replaced them, and the readout keeps both: *How the ruling changed*, the rows that changed, and the figures that changed class. When the instrument a ruling rests on changes, play every table it cites again at the new head and make the ruling again; never edit the first in place.
- **The exam** (P9, *On the exact candidate*). The release-candidate commit carries the reading of record's content SHA-256, or its content is equivalent for the class (P9 route (b): for each of the reading's run directories, `equivalence <candidate's directory> <reading's directory> --commit <the RC commit's full SHA>`, and the graders run on the candidate's directories, all recorded in the exam packet); an independent re-run from a clean checkout plays the reading's cell table on the bands of record, naming the instrument of record whatever the default (`run … --play search --pilot p8-d0-v3 --search s1` for 1.0), and agrees with the reading on every graded gate's verdict, the numbers free to differ; and the exam's own items run: the CEM stress, read once on the historical holdout, the save-lineage and id checks, and the lock's §12 invariants.

## 7. Invariance and other classes

**The panel.** `tests/test_balance_invariance.gd` pins the Duskblade's play, each pin the SHA-256 of one whole run row:

- 72 pins (`PINS`) under 1.0's bots, named explicitly: six arms × four cells (V0 and V5, `fresh` and `full`) × three runs, the greedy pilot on seeds 12000 and 12001 and the search player on 12000;
- 48 pins (`PINS_1_1`) under `p9` and `s2`: the same arms and cells on seed 12000, greedy and search;
- 48 pins (`PINS_S3`) under `p9` and `s3` (#544 P6b), on `PINS_1_1`'s keys: 45 equal `PINS_1_1`'s, and three `full` search rows differ through the Ashfall omen's starting Smolder.

It runs in the Godot suite and leaves 1.0's bots selected. A pin moves only with a deliberate change to the Duskblade's play (its instrument, its content or the rules it runs), re-pinned in an explicit commit that says why.

**Adding a class without moving another's rows** (#544 decisions 1, 3 and 6):

- The class lands dormant, its content row marked `"deferred": true`.
- Every id only it uses enters every other class's `excludes` (`cards`, `relics`, `potions`, `boons`, `arts`, `deeds`) in the same commit, so their offers, draws and RNG streams stay byte-identical.
- Way ids are unique across classes and never reused: `shatter`, `lantern` and `edge` are the Duskblade's. A lit rider resolves only when its way id is the fight's lit way, so a unique id is what keeps a rider from resolving for another class.
- Riders are scoped to their class: `p9` scores a rider of a way the run's class does not have at 0; printing it only for its class is #544 step A4 (template §3).
- The proof is the panel, unchanged. For more, play the old reading's commands on a slice and compare its rows with the stored rows of the same seeds (§10, item 4). `compare` counts the stored seeds beyond the slice as missing, so cut the stored run first: copy its `parts/` chunks for those seeds into a new directory and `merge` it.

**P9's same-content rule.** A verdict describes the content it was given on: the Duskblade's 1.0 verdict binds `content/full-content.json` at `e9c4d48fbe38542e65a9c73f73b4c50f72116026d4be51a81b7a9b04ec33ca7b`, and any change to that file moves its SHA-256, even when no Duskblade row moves. That is why a class's per-way stats live in `tools/balance_classes.json`, not in content. P9's route (b), content equivalence for the class, is in force since #697 (`8d1fd9f2`); §6 says how the exam records it.

## 8. Adding a class

- **Content.** The class's aspect row: its `ways` (id, `affinity`, `relics`, `crown`, `crownAlts`, `capstones`), `flame`, `sootCrown`, `excludes` and `"deferred": true`, as the template's §1 and its implementation note give them.
  - An `excludes` key the row lacks is added whole: the Ashwarden had no `arts` list until A2 gave it `beacon`.
  - `crownAlts` is optional. Give a way none when every crown left in the class's boss pool belongs to another way: an alternate would then offer another way's crown (the Ash lock §6.4 and §7).
  - `handSize` has been the turn's deal since #544 A2 (`_hand_size` in `domain/rules/combat.gd`), but the pilot still assumes a hand of 5 (`TURN_DRAW` in `tools/balance_pilot.gd`). A `handSize` other than 5 is therefore an instrument change (the Ash lock §10): the pilot reads it first, and every shipped class is read again.
- **The content commit** (#544 A2, PR #702). These move in the same commit as the class's ways:
  - **The catalogue pins.** Re-pin `LIVE_FILE` and `LIVE_SEMANTIC` in `tests/test_balance_catalogue.gd`, saying in the commit which SHA they leave. Take the file SHA-256 with `shasum -a 256 content/full-content.json`, and the semantic SHA-256 with the formula of `_semantic_sha` in `tools/balance_catalogue.gd`: `python3 -c "import json,hashlib;print(hashlib.sha256(json.dumps(json.load(open('content/full-content.json',encoding='utf-8')),ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest())"`.
  - **The tests that pin "no ways" for the class.** Flip them on purpose and name each in the commit message. Find them by running the full Godot suite and every `tests/test_balance_*.py` on the content edit before writing a test. The Ashwarden's were in `test_flame.gd`, `test_flame_lantern.gd`, `test_flame_recognition.gd`, `test_lantern_flame.gd` and `test_line_table.gd`, and in `tests/test_balance_ways.py`'s `CatalogueTest`. Keep each "aspect without ways" check alive by removing the ways from a fresh `ContentDB.load_full(false)` copy, not by deleting the check.
  - **The codex.** `test_line_table.gd` requires a codex sentence, `codex.lantern.<way id>`, for every way of a class on offer. A deferred class's sentences are owed by name in its `CODEX_OWED` until the class's lines step lands them, and the test fails as soon as one lands while it is still listed.
  - **The lanterns.** The HUD, reward, shop and event lanterns appear for the class as soon as its ways land, because they show wherever `Flame.ways` is not empty. A way id with no `COLOUR` or `WAY_SHAPE` entry in `presentation/combat/lantern_flame.gd` burns as painted at Kindling and plain at Steady, until the class's flame step gives it a colour and a shape.
  - **A saved run of the deferred class** resumes as itself (`ClassScope`). From the content commit on, it plays the class as the build has it, flame included, and it hears and uses up the class-neutral flame lines until the lines step gates them by class (the Ash lock §14).
  - **The release's content.** The commit moves `content/full-content.json` off the SHA a shipped verdict binds, so the release candidate takes P9's route (b); say so in the PR.
- **`tools/balance_classes.json`.** One entry, `"<aspect id>": {"wayStats": {"<way id>": "<run stat>", …}}`, naming for every content way the run stat its play produces; the Duskblade's are `shatters`, `kindles` and `cracked`. The search player scores those stats as the way's verbs and the simulator records their per-fight rates. The stat must be one `domain/` increments in `run.stats`: the simulator reads `run.stats.get(<stat>, 0)`, so a stat nothing increments reads 0 in every row, without an error.
- **The `entry` pool.** `--pool=entry` (`_apply_entry` in `tools/balance_sim.gd`) is the Vigil after one run played and won, read from the domain's own unlock rules; the deed that one win meets, `firstDawn`, grants `aspect2`, the Ashwarden's unlock.
- **The graders' pools** (fixed by #544 P7; readout A0 graded its `entry` screens with a scratch script). The class's content row decides them: with an `unlock`, the graders read `entry` and `full` (`LATER_POOLS` in `tools/balance_ways.py`), without one `fresh` and `full` (`POOLS`). `entry` takes `fresh`'s thresholds wherever the Duskblade's lock grades `fresh` (the Ashwarden lock §10): `G1_FLOOR` and `G5_FLOOR` at V0, `B1_FLOOR` in `tools/balance_readout_tables.py`; V5 `entry` is ungraded for G1 and G5, as V5 `fresh` is. The Duskblade's output is byte-identical: P2's reproduction regraded by every grader before and after the change.
- **The graders' ways** (fixed by #544 P7). `paired`, `g3`, `rowb`, `table` and `balance_ways.py --from-dir` take the class's ways from `content/full-content.json`, or from `--content`, the scratch catalogue the reports ran on, and then refuse any report whose manifest names another content SHA-256 (§4, *Grading a scratch catalogue*). So a catalogue that adds ways (a new class's tagging screen) is graded with `--content`; without it, a directory holding a committed arm the class does not have is refused rather than graded on the ways it knows. Every way still needs its `wayStats` entry in `tools/balance_classes.json` first, to run and to grade: the roster is built with `read_class`, which refuses a way without one before any chunk starts or any report is read.
- **The bots.** The class's verbs are playable before any reading of it counts (#544 decision 4; §10).

**The third-class guards** (the P3 review, PR #687). Each lands in the PR that adds the third class:

- [ ] **The `entry` unlock.** `_apply_entry` is fixed at one run played and one win, which is right for the Ashwarden. A third class reads its unlock from content, or asserts that the entry profile's unlocks contain its `unlock` id.
- [ ] **A content way with no class-file stat fails closed at start-up in a direct `godot -s` run.** Today the Python side refuses it first (`read_class`), and the runner fails the chunk on the `ERROR:` line `expression_stats` logs; a direct run logs the error, drops the stat and carries on.
- [ ] **Two-class assumptions get fail-closed guards.** The pilot's `aspect == 0` and `aspect == 1` branches (its card-score tables, the Ashwarden's poison lines, the class relic preferences), the search player's `dusk` flag and `balance_metrics.gd`'s calibration, which names `duskblade` and `ashwarden`, all assume two classes. A third class refuses to run until each branch knows it.

## 9. The readout write-up

A readout is `readouts/readout-<n>.md` in the class's lock folder. Readouts 13 and 14 set the form; each section below holds what is listed, and a section with nothing to say is left out.

- **Title.** `# Readout <n>: <what it answers>`.
- **Head note** (a block quote, two paragraphs).
  - *What it is:* a research readout (AI-SDLC discovery); whether it is a reading of record, and that it gives no verdict. What the PR ships (instrument, rule or content commits) and what did not move (ids, numbers, save fields, RNG draws, `port_fixtures/`), with the content SHA-256 before and after.
  - **Head.** The commit every report ran at and every manifest names; how it maps to the merged commits after a rebase; and the proof that nothing the reports depend on moved since: `git diff --stat <run head> HEAD -- domain content 'tools/balance_*'` empty. Superseded candidates are named here, their rows counted under *How it was run*.
    - When the readout's own PR edits a `tools/balance_*.py` file, a docstring or usage text say, that file shows in the diff. Name it there as the PR's own text-only change, as Ash readout A1 did, rather than leave the diff unexplained.
    - When the run worktree sits on a later commit than the merge it reads (Ash readout A1 ran at `faa98347`, two documentation merges after #702's `eda4f869`), show that nothing in `tools`, `content` or `domain` differs between the two, and record the run's commit.
- **The opening.** One paragraph: what the last readout left open and what this one does.
- **The answer in brief.** Each finding with its figures and intervals.
- **The question.** Stated so that a figure can answer it.
- **The instrument**, when one changed: what changed in the bots, the probes, the mutants, the default and the cost (§10).
- **How it was run.** The exact commands, from the isolation line (the `override.cfg` purpose name, never committed) to the last grader; then four labelled items: *Cells, arms, seeds*; *Measures*; *Budget and stop rule*, fixed before the first run; *Wall time*, with jobs, host and load. Rows changed against a superseded candidate, if any.
- **The paired comparison** against the previous reading: the instrument alone or the lever alone, arm by arm, with the exact p.
- **Diagnosis and candidates**, in a wall lane: the diagnosis in a few numbered lines; at most three single-lever candidates per way, each following from a line of it; the development screen; the choice.
- **The cell table.** Win rates with Wilson intervals; committed reach (G5 over survivors, the all-runs figure beside it); every gate in every cell on point and interval, the previous reading's verdicts beside it, bold where a verdict moved; G3 on the 4,000 common seeds; row B.
- **Every graded gate and reading, under P9's definition.** The graded figures short of their thresholds, the ones no longer short, and the readings.
- **What the orchestrator must decide**, for a reading; **Decision**, for a lane: what worsened and why, and the targets not reached.
- **A plain reading of intent**, for a reading of record: the design's intent, clause by clause, in words.
- **Tests and pins.** New tests; pins moved and why; tests unchanged and passing; anchors re-pointed.
- **What the next readout should ask.**
- **The orchestrator's ruling**, appended by the orchestrator and dated; a ruling made again keeps the first beside it (§6).
- **Appendix: the scripts.** Every scratch script that produced a figure, one line each. The repository's commands are preferred; a figure a ruling rests on should come from them.

## 10. Instrument changes

When the bots learn new verbs, the new instrument is proved before any reading under it counts (readout 14 is the worked example):

1. **Probes whose best line is known by hand.** Fixed positions (`tests/test_balance_bots_hand.gd`), each played as the simulator plays it and each stating whether the old bots find it. Include one the new credit alone decides, and a guard the old bots already solve, so the new bots keep what the old ones played.
2. **Honest play.** The search never plans with a card the player has not seen. Readout 14's review found exactly this: `s2` credited a hand-size payoff from a card the line had only just drawn, and because the cloned RNG deals what live play will, that was a peek. A check now plants a win behind an unseen draw, and the bot must not credit it. Every new credit gets such a check.
3. **Mutants.** Remove or revert each new credit and each fix in turn; each mutant must fail a test. Back the file up and copy it back afterwards; `git checkout --` also wipes the unstaged fixes beside it.
4. **The old instrument, row for row.** Its pins pass unchanged with the bots named (§7), and the old reading's commands, the bots unnamed, reproduce stored rows on a slice: readout 14 played 13000–13099 in all four cells, 2,412 rows, identical to #544 P2's reproduction; the manifests differed only in the commit and the simulator's digest.
5. **New pins** for the new bots beside the old (`PINS_1_1`), moved only in an explicit commit.
6. **Cost**, side by side on the same seeds and host: time per turn.
7. **A requalification reading** of every class already shipped: its complete §11 table under the new bots on its reading of record's bands and content, paired run for run against that reading. It is a new reading, not a re-run, and the old reading stays of record for its release.
8. **The default does not move** until the release it would change has its re-run (§2).

## 11. Archiving

- Raw rows never enter the repository. A readout's run directories take about 1 GB (#544 P2, readout 14 and readout A0 each took 0.9–1.1 GB) and live in the lane's scratch folder.
- Keep `df -h /` in view, in the status log and before every table. Readout A0 logged it at every step: 92–107 GB free, against the 60 GB floor its lane was set.
- Before deleting anything, archive it:
  1. pack the run directories and every scratch script a figure came from into a tarball;
  2. take its SHA-256;
  3. copy it to the NAS under `~/Archives/glassvow-scratch-<date>/`;
  4. stream it back (`ssh <nas> cat <path> | shasum -a 256`) and check that the digest matches (`scp` could not see that path when P2 recovered an archive; streaming works);
  5. record the digest in the readout's appendix or its PR;
  6. only then delete the local copy.
- P2's reproduction recovered readouts 9–13's scratch scripts and readout 13's chunk reports from such an archive, and `compare` and `merge` read archived chunks directly.

## 12. Pitfalls actually hit

| Pitfall | What happened | Fix |
|---|---|---|
| An override without its header | 4 October 2026: a brief named "both keys" but not `[application]`, so the P2 agent's first `godot --headless --import` in a fresh worktree ran unisolated. The saves were unchanged, and the agent caught it | Paste the three-line block verbatim (§1), before the first Godot command, the import included. Every balance tool that starts Godot refuses a headerless file (the runner from the start; the rest from #544 P7); the import, a direct `godot -s` and the test suite do not |
| A resume hole | #684's review: resuming into a directory with a changed `--play`, `--way-weights` or `--chunk` reused every finished chunk silently, and a merge of uniformly stale chunks passed | `f7b2c782`: a resume compares the sidecar's command and digests `domain/`. Still: new parameters, new directory; run from a clean detached worktree (§4) |
| Stale static bot selection in tests | #690: the first full-suite gate caught `test_balance_pilot_cache` reading `p9` scores left selected by the invariance panel | Restore `Pilot.select(Pilot.VERSION)` and `Search.select(Search.VERSION)` at the end of any test that selects (§2); run the full suite, not the one test |
| A recovered scratch script | Readouts 9–13 came from scratch scripts never committed; #544 P2 had to recover them from the NAS archive to rebuild the runner and reproduce readout 13 | Read with the repository's commands; list and archive every scratch script a figure came from (§9, §11); a script a second readout needs is promoted into the runner, with tests |
| An over-counted false-positive rate | #691: the round-2 calibration pooled one false-positive rate (36.0% for the judge it kept) over every claim on the corrupted field. An adjudication after scoring split it into the judge's leniency on claims the corruption does falsify (3 of 41, 7.3%) and missing coverage (21 of 70 wrong answers had no such claim) | Fix each rate's denominator to the units its claim is about, before scoring, and report the parts. Balance's case is G5: graded over every run until readout 13, where at V5 it read survival, not reach; it is now read over survivors with the all-runs figure beside it |
| A reviewer's turn cap | `ai-sdlc-reviewer` stops at 12 turns. P3's review resumed once; P6's re-review and #691's resumed twice, the second time only to write the report | Brief it with the exact head, the paths and the questions, not the history. Resume the same reviewer (`SendMessage`) rather than starting a new one; a capped run is no verdict until it reports one |
| Python tests run as a module | #544 A2: `python3 -B -m unittest tests/test_balance_ways.py` failed every file with an import error, not a test failure | Run each as a script, as CI does (`.github/workflows/ci.yml`): `python3 -B tests/test_balance_<name>.py`. `tests/test_balance_exam.py`, which CI does not run, also needs an `override.cfg` in the worktree's root since #544 P7 (one test meets the isolation guard): in a docs worktree, write one for the run and remove it after, as CI's host-qualify step does (Ash readout A1) |
| A reboot that took the rows | 5 October 2026: Ash readout A1's first batches, their driver and their handoff lived in a session scratchpad under `/private/tmp`. The host rebooted at 15:55 and took them, with readout A0's raw rows. The batches ran again from nothing on 9 October (6 h 38 min), and `killshare.py`, last checked on A0's rows, had to be validated again without them | From the first command, keep raw rows, drivers and handoffs in durable storage and run long batches detached with `nohup caffeinate -i` and a `status.log` (§4). Archive (§11) the rows a later readout compares against |
| A disk guard that read nothing | #544 A2's batch driver checked free space with BSD `df -g`. The host's `df` is GNU coreutils (Homebrew's `gnubin` comes first on the `PATH`), so the option failed, the guard read an empty number and stopped the run before it began | Use a form both understand, `df -k / \| awk '{print int($4/1048576)}'`, and print what a guard read before acting on it |

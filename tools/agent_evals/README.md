# Agent evals and hill-climbing

A repository tool for measuring, and then improving, a file that steers an agent (a
"surface", for example `.claude/skills/glassvow-godot/SKILL.md`). It follows the method
of Anthropic's article "Automating eval design and hillclimbing with Claude" (the
`build-eval` and `hillclimb` workflows). Pure Python standard library; no Godot.

The first eval is `repo_traps` (see `evals/repo_traps/README.md`).

## Commands

Run from the repository root. `<eval>` is a directory name under `tools/agent_evals/evals/`.

```bash
python3 tools/agent_evals/cli.py init repo_traps             # validate cases, write split.json
python3 tools/agent_evals/cli.py review repo_traps           # build/agent_evals/repo_traps/review.html
python3 tools/agent_evals/cli.py approve-inputs repo_traps   # human checkpoint 1
python3 tools/agent_evals/cli.py baseline repo_traps --run-id b1            # haiku, sonnet, opus x 3 reps
python3 tools/agent_evals/cli.py approve-grader repo_traps --run b1         # prints N transcripts to open
python3 tools/agent_evals/cli.py approve-grader repo_traps --run b1 --read <the printed list>
python3 tools/agent_evals/cli.py hillclimb repo_traps --goal accuracy       # refuses without both approvals
```

`baseline` also takes `--models haiku,sonnet`, `--reps N`, `--only id1,id2` (a smoke run),
`--workers N`, `--timeout S`, `--infra-threshold 0.05` and `--backend cli|api`.
`hillclimb` takes `--goal accuracy|cost-at-parity`, `--model`, `--proposer-model opus`,
`--reps 3`, `--round-reps 1`, `--rounds 8`, `--stall 3` and `--min-gain 0.05`.
Model names are family aliases (`haiku`, `sonnet`, `opus`); no version id is ever pinned.

Runs go to `build/agent_evals/<eval>/<run-id>/` (git-ignored). A baseline writes:

- `transcripts/<model>/<case>__r<N>.json`: prompt, surface sha256, model, output, grade with
  per-claim verdicts, error flags, timing, usage and the exact `claude -p` flags used;
- `results.json` and a static `results.html` linking each case score to its transcripts.

A hill-climb run writes `noise/{train,test}/`, `rounds/NN/{train,test}/` (test transcripts
live in their own directory), `rounds/NN/round.json`, `work/surface.md` (the working copy;
the repository file is never edited), `best_surface.md`, `best.diff`, `report.md`,
`summary.json` and, on a stall, `reflection.md`.

## Method rules the tool enforces

**Cases.** Each case carries `source` (a repo path or an issue/PR ref; validated) and
`why_hard` (stated before inclusion). Never select cases because a model fails them. Cases
may not share a verbatim span of 40 characters or more (otherwise the leak guard could not
tell train from test).

**Graders.** Programmatic first: each claim is a regex `must_match` or `must_not_match`, or a
JSON `equals`, applied to one field of the model's JSON reply. A case score is the share of
claims that hold. An LLM judge (`"type": "judge"`) exists for open-ended outputs only; it is
given yes/no claims (never a scale) and sees the task, the answer and the claims, with no
baseline or candidate label. Scoring is per output, so there is no pair to randomise.

**Baseline diagnostics** (in `results.json` and printed as warnings):

- headroom: warn when any model scores above 95%;
- ordering: warn when a weaker model beats a stronger one beyond the 95% bootstrap CI of the
  paired per-case difference;
- grader consistency: every output is graded twice; programmatic grades must be identical and
  the judge disagreement rate is reported;
- infrastructure reliability: timeouts, API or CLI errors and truncated outputs are counted;
  above `--infra-threshold` (default 5%) the run is marked `failed` and the command exits 2.

**Human checkpoints.** `review` writes every case input with its source and why_hard.
`approve-inputs` and `approve-grader` record who, when and the sha256 of `cases.jsonl` in
`approvals.json` in the eval directory. `approve-grader` prints a deterministic sample of five
scored transcripts and only records approval when `--read` lists them all. `hillclimb` refuses
to run unless both approvals exist and match the current cases hash.

## Hill-climbing

- **Split.** `init` ranks cases by `sha256(seed:case id)` and cuts 60/40 into train and test,
  persisted in `split.json` (disjoint; refused if the cases changed since).
- **Proposer.** Each round, the proposer (default alias `opus`) reads the current surface and the
  failing train transcripts and returns JSON `{root_cause, patch, expected_effect}`, where the
  patch is one unified diff aimed at a root cause. The prompt is assembled by exactly one
  function, `proposer.build_proposer_prompt`, from train data only; `assert_no_test_leak`
  raises if any test case id, input or expected answer appears in a prompt, and it runs on
  every prompt. The only test-derived signal the proposer receives is whether each earlier
  round was kept or reverted.
- **No failure injection.** A patch whose added lines contain a verbatim span of 40 characters or
  more (whitespace-normalised, case-folded; `HillclimbConfig.min_span`) from any case input or
  expected answer, train or test, is rejected and counts as a non-kept round.
- **Keep or revert** (`improved(delta, noise) := delta > noise`; deltas are candidate minus
  incumbent). Goal `accuracy`: keep only if train and test both improved. Revert codes:
  `overfit` (train improved, test did not), `regress` (either set fell below minus noise),
  `no-gain`. Goal `cost-at-parity`: keep only if mean tokens per call fall by more than the cost
  noise and neither set's accuracy fell below minus noise (codes `regress`, `no-gain`).
  Cost is the measured input plus output tokens of each call (surface included), else a
  four-characters-per-token estimate.
- **Stall.** After `--stall` consecutive non-kept rounds, or at the start if the noise floor
  exceeds `--min-gain` (a gain that small cannot be measured), the proposer writes
  `reflection.md` (ambiguous cases, harness errors, run-to-run variance, grader flaws) and the
  run stops. More repetitions or more cases are the fix for noise.
- **Finish.** The version with the highest test score is restored (ties go to the cheaper
  surface, then the earlier round) as `best_surface.md` with `best.diff`, and `report.md` lists
  train and test scores (mean and 95% CI) for baseline and best, every round's decision and
  reason, and a verdict: `merge recommended` only if the test gain over baseline exceeds the
  test noise (for `cost-at-parity`: the cost drop exceeds the cost noise without a test loss
  beyond noise); otherwise `do not merge (within noise)`. Choosing the best by test score is
  a mild selection effect; treat a barely-above-noise gain with suspicion and re-run it.

## Estimators

- **Mean and CI.** The score of a set is the mean over cases of the per-case mean over
  repetitions. Its 95% CI is the percentile bootstrap (2,000 resamples of the cases with
  replacement, fixed seed) of that mean.
- **Noise floor.** For every pair of repetitions `(i, j)` of the unchanged surface, take the
  per-case differences `s_i - s_j`, bootstrap their mean over cases (same procedure) and take
  half the width of the 95% interval. The noise is the mean of those half-widths over all
  pairs. It is the scatter of the accuracy difference between two single runs of the same
  surface, which is exactly what a candidate evaluated once per round is compared with
  (`--round-reps` above 1 makes the test conservative). It is computed separately for train,
  test and per-call cost. Needs at least two repetitions.
- **Ordering check.** Mean and 95% bootstrap CI of the per-case difference between two models;
  a weaker model trips the warning when the lower bound is above zero.

## Backends

`Backend.complete(system, prompt, model, timeout_s) -> Completion(text, error, timed_out,
truncated, usage)`.

- `FakeBackend`: scripted by a callable; every test uses it, none touches the network.
- `ClaudeCliBackend` (default): `claude -p` as a subprocess, surface as the system prompt, prompt
  on stdin, empty temporary working directory, `--output-format json` for usage and cost. The
  flags, recorded in every transcript, are:

  ```text
  claude -p --output-format json --model <alias> --safe-mode --setting-sources "" --tools ""
         --strict-mcp-config --disable-slash-commands --no-session-persistence
         --system-prompt <surface>
  ```

  `--safe-mode` disables CLAUDE.md files, memory, skills, plugins, hooks and MCP servers.
  Measured on Claude Code 2.1.289: it did not stop the user settings file leaking (the
  `language` setting made the model answer in Cantonese), so `--setting-sources ""` is also
  passed; with both, the reply was English and the input was just the surface plus the case
  (about 2,350 tokens). The backend checks `claude --help` for every flag and refuses to run
  if one is missing unless `--allow-ambient-context` is given, in which case CLAUDE.md,
  memory, hooks and settings may leak and the transcripts say `"isolation": "ambient"`.
  Not covered: admin-managed policy settings (none on this machine), inherited environment
  variables and the account's own auth. Isolation is therefore strong but not proven by the
  CLI contract; the input-token count in each transcript is the quick leak check.
- `AnthropicApiBackend`: optional, over the installed `anthropic` SDK when `ANTHROPIC_API_KEY` is
  set (read from the environment, never printed or stored). A family alias is resolved to the
  newest model whose id contains it, so no version is pinned in this repository.

## Cost notes

A baseline is `cases x reps x models` calls (35 x 3 x 3 = 315 for `repo_traps`; use
`--models` and `--reps` to cut). A hill-climb costs two noise sets (`reps` x all cases), then per
round one proposer call plus `round-reps` x all cases. Start with `--only` on one case and
`--models haiku` to prove the path before spending quota.

## Tests

```bash
python3 -B tests/test_agent_evals.py
```

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

**Decision gate.** In a case with a boolean decision claim (`equals` true or false), a wrong or
missing decision caps the case score at 0, so a coin-flip boolean cannot earn partial credit; a
right decision with weak reasoning still earns partial credit. A case with no boolean marks one
structural claim `"gate": true` instead, and a failed gate caps the case at 0 in the same way. The
gate is the claim a keyword list cannot satisfy: a statement in a fixed shape, a code shape or an
anchored value (`validate_grader_spec` accepts `gate` only as `true`, and never on a boolean). A
text field over 1,000 characters fails every claim on it (a keyword dump, not an answer). A reply
that wraps its fields in a single key, such as `{"answer": {...}}`, is unwrapped. Write
`must_not_match` only for text a wrong answer alone would contain, because a correct refusal can
name the forbidden word ("do not ignore it"), and anchor a keyword `must_match` to an affirmative
statement or pair it with a forbid of a nearby `not|no|never`.

**Hit-count limit.** A claim's keywords are the runs of plain text in its `must_match` pattern,
between the regex syntax: escaped punctuation counts as text (`check_scripts\.sh` gives
`check_scripts.sh`), the runs are case-folded and runs shorter than three characters are dropped
(`graders.claim_keywords`). A field's hit count for the claim is the number of those keywords it
names as whole words, ignoring case (`keyword_hits`). The claim fails, even when its pattern
matches, if the hit count is above `max(5, ¾ × the number of keywords)` (`hit_limit`). A statement
names one alternative per slot, so even a thorough one names few of a claim's synonyms; a list
names nearly all of them, and the one alternative it happens to contain does not complete the
claim. Patterns of the form `X ... Y` should keep their alternatives few and their gaps short,
because a list of their words can fall into that order by chance.

**Baseline diagnostics** (in `results.json` and printed as warnings):

- headroom: warn when any model scores above 95%;
- ordering: warn when a weaker model beats a stronger one beyond the 95% bootstrap CI of the
  paired per-case difference;
- grader consistency: every output is graded twice; programmatic grades must be identical and
  the judge disagreement rate is reported;
- trivial answerers (no model call), graded by the real grader: the empty answer `{}`, and every
  text filler paired with every boolean mode. The text fillers are empty text (constant), the case
  prompt (echo), the full keyword soup (one fixed list of every domain word in every reference and
  keyword claim, about 5,300 characters, so the field cap rejects it), the compact generic soup
  (the claim keywords most claims use, most widely used first, cut to fit under the 1,000-character
  cap) and the compact case-aware soup (every keyword of that case's own claims, sorted, under the
  cap). The boolean modes are all false, all true and the correct values (oracle); constant text
  with oracle booleans is named `oracle_booleans`. Any of them scoring above 25% warns, and
  `approve-grader` refuses such a run; it also rescores the current cases itself, so a run
  recorded before a new answerer existed cannot back an approval;
- infrastructure reliability: timeouts, API or CLI errors and truncated outputs are counted;
  above `--infra-threshold` (default 5%) the run is marked `failed` and the command exits 2.

**Human checkpoints.** `review` writes every case input with its source and why_hard.
`approve-inputs` and `approve-grader` record who, when and the sha256 of `cases.jsonl` in
`approvals.json` in the eval directory, and refuse unless stdin is an interactive terminal, so an
agent shell cannot approve. `approve-grader` also checks that the run's `results.json` carries the
current cases hash, status `ok`, every case (not an `--only` smoke run), an infrastructure rate within
its threshold and no trivial answerer above 25%; it then prints a deterministic sample of five scored
transcripts and only records approval when `--read` lists them all. `hillclimb` refuses to run unless
both approvals exist and match the current cases hash, and refuses when the approved baseline scored
above 95% for any model (no headroom) unless `--allow-no-headroom` is passed.

**Delegated approval.** The interactive-terminal guard is the default. The only non-interactive
path is for an owner's explicit delegation, and it is recorded in the approval file:

```bash
python3 tools/agent_evals/cli.py approve-inputs repo_traps \
  --delegated "<who delegated, when, why>" --evidence <path to the council report>
python3 tools/agent_evals/cli.py approve-grader repo_traps --run b1 --read <list> \
  --delegated "<who delegated, when, why>" --evidence <path to the council report>
```

With both flags the terminal check is skipped and the approval records `by: "orchestrator"`,
`delegated_by` (the text), `evidence` (the path and its sha256), the cases hash and the time.
Giving only one flag is an error. Every other check stands: `approve-grader` still needs a
healthy full run and the sampled transcripts in `--read`.

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
- **Keep or revert** (`improved(delta) := delta > max(noise, --min-gain)`; deltas are candidate minus
  incumbent). Goal `accuracy`: keep only if train and test both improved. Revert codes:
  `overfit` (train improved, test did not), `regress` (either set fell below minus noise),
  `no-gain`. Goal `cost-at-parity`: keep only if mean tokens per call fall by more than the cost
  noise and parity holds against the ORIGINAL baseline on both sets (candidate minus baseline is
  not below minus noise), so small losses cannot accumulate over kept steps (codes `regress`,
  `no-gain`).
  Cost is the measured input plus output tokens of each call (surface included), else a
  four-characters-per-token estimate.
- **Stall.** After `--stall` consecutive non-kept rounds, or at the start if the noise floor
  exceeds `--min-gain` (a gain that small cannot be measured), the proposer writes
  `reflection.md` (ambiguous cases, harness errors, run-to-run variance, grader flaws) and the
  run stops. More repetitions or more cases are the fix for noise.
- **Finish.** For `accuracy` the version with the highest test score is restored (ties go to the
  cheaper surface, then the earlier round); for `cost-at-parity` it is the cheapest version that holds
  parity against the baseline. The result is written as `best_surface.md` with `best.diff`.
- **Confirmatory rerun.** Before any `merge recommended`, the original surface and the chosen best are
  both re-run on the test set at `--reps` repetitions, and the verdict rests on those paired runs:
  `accuracy` needs the test gain to exceed the test noise; `cost-at-parity` needs the cost drop to
  exceed the cost noise with parity held. Both are recorded in `report.md`, with train and test
  scores (mean and 95% CI) for baseline and best and every round's decision and reason. Otherwise the
  verdict is `do not merge (within noise)`. This rerun also removes most of the selection effect of
  choosing the best version by its test score.

## Will the first run measure anything?

With 35 cases there are about 14 test cases. One test case moves the score by 7 points, so the test
noise floor will probably exceed the default `--min-gain 0.05`. If it does, the first `hillclimb` stops
as `unmeasurable`: it writes `reflection.md` and makes no edit. That is the tool working. The fix is
more cases or more repetitions (`--reps`); lowering `--min-gain` only hides the problem.

**What the proposer learns about the test set.** The proposer never sees test cases, transcripts or
scores. Its history of earlier rounds does carry one bit per round that depends on the test set:
whether the round was kept or reverted (a keep requires a test gain). Reason codes and numbers are
withheld.

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
  `python3 tools/agent_evals/cli.py smoke-isolation` is an opt-in negative control: it plants a canary
  instruction ("end every reply with PINEAPPLE-7731") in CLAUDE.md files in the backend's temporary
  working directory and in a throwaway HOME (never the real one), asks for one word, and fails if the
  reply follows the canary. It costs one or two haiku calls. On this machine the throwaway-HOME variant cannot authenticate
  ("Not logged in"), so the run falls back to the working-directory canaries; the home-level canary is
  therefore untested here. Result of the one recorded run: reply `OK`, 420 input tokens, canary not followed.
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
python3 -B tests/test_agent_evals_review.py
```

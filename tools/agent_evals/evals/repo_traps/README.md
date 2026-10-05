# repo_traps

Measures whether an agent working in Glassvow makes the right call on the repository's
documented traps. Surface under test: `.claude/skills/glassvow-godot/SKILL.md`, given to the model
as its system prompt (nothing else from the repository is visible to it).

## Cases

`cases.jsonl` holds 35 cases. Every case is a concrete situation (a code excerpt, a command and
its output, or a task step) that asks for a short JSON decision, graded by checkable claims on
named fields. Each case names its `source` (the note or doc recording the real failure) and
states `why_hard` before inclusion. They were derived from these records:

- `docs/solutions/runtime-errors/typed-array-from-ternary-branch-throws-at-runtime.md` (2)
- `docs/solutions/logic-errors/const-typed-dictionary-drops-its-packed-array-type.md` (2)
- `docs/solutions/test-failures/canary-pins-the-rule-not-the-bugs-shape.md`
- `docs/solutions/test-failures/a-script-error-in-a-test-used-to-pass-silently.md` (2, in opposite directions)
- `docs/solutions/ui-bugs/` notes on borrowed shader consts, scaling and centres (2), hit areas, label
  metrics, the hero ward stone, the flat billboard shadow and the Web canvas
- `docs/solutions/design-patterns/` notes on node-per-layer in Godot (2, one each way) and procedural glass
- `docs/solutions/conventions/` notes on per-recipe shader knobs, gating where the change is
  deterministic, citing the symbol and a hypothetical in review
- `docs/solutions/tooling-decisions/` notes on the long-lived capture host, driving the Enemy Lab with the
  game's own setup call (`lab-actor-without-profile`) and sparse complete-entry mob overrides
  (`mob-override-complete-entry`)
- `docs/solutions/workflow-issues/` notes on save fixtures, shared documents, citation annotation and
  whole-run route verification
- `docs/solutions/architecture-patterns/live-language-switching-is-one-main-owned-transaction.md`
- `docs/solutions/integration-issues/` notes on Funplay `-32000` and verifying the artifact
- `tools/check_scripts.sh` (why `--check-only` exits 0 on a parse error)
- `docs/dev-tools.md` (override.cfg isolation, never deleting a real save)

The surface under test is the skill, so no case comes from `CLAUDE.md` (its rules would only be copied into
the skill), and no case rests on a design README that merely mentions a rule.

Some cases test the opposite error (treating harmless renderer noise as a failure; collapsing nodes that
need their own input; adding a helper on a belief that was never measured), so the eval does not reward an agent that is merely suspicious.
Some cases are answered by the surface already; that is intended (it measures whether the surface
carries the trap) and the headroom diagnostic will say if the eval saturates. Half of the boolean claims
expect `true` and half `false`. A wrong boolean decision scores its case 0 (the decision gate); each of
the 13 cases with no boolean has one gate claim instead. See Grader below.

## Files

- `eval.json`: surface path, grader type (`claims`), default models (`haiku`, `sonnet`, `opus`),
  the hill-climb model (`sonnet`), the judge model (`sonnet`) and the judge arm (`plain`; `reference`
  is the pre-registered alternative, see Grader below).
- `cases.jsonl`: `id`, `source`, `why_hard`, `prompt`, `answer_format`, `reference` (the intended
  answer, for reviewers and for the failure-injection check) and `grader`.
- `split.json`: the seeded 60/40 train/test split, written by `init`. Re-run `init` if cases change.
- `answers.jsonl`: per case, the reference answer field by field (each text value is a verbatim span of
  the case's `reference`; the one exception is the typed-array-ternary fix, which the reference states in
  prose) and two correct answers in other words. The offline tests require all three to score 100%, so a
  claim edit that rejects a correct answer fails. The harness itself never reads this file.
- `answers_independent.jsonl`: two correct answers per case from a separate writer, who worked from each
  case's prompt, answer format and reference without sight of any grader (its first line says so and
  records the sha256 of the rest). The answers are copied byte for byte and never edited to suit a claim.
- `council-2026-10-04.md` and `council-2026-10-05.md`: the two councils' records. The second decided
  the hybrid grader and the evidence its approval needs; its round 3 decided the two judge arms, the
  claims rewrite and the fresh calibration.
- `calibration-2026-10-05.md` and `calibration/`: the round-2 calibration record, with its spent sets
  (`answers-a`, `-b`, `-c` and the wrong answers) and verdicts. Round 3 uses them as development
  material only.

## Adding a case

Take it from a real transcript, bug report or note first, then a hand-written case, then a synthetic
one anchored to a real one. Write `why_hard` before running anything. Keep the prompt
self-contained, avoid sharing a 40-character span with another case, check booleans, commands, paths,
numbers and code by program and write every free-text claim as a judge question from the reference
alone ("The answer states ..."), give a case with no boolean one `"gate": true` claim, add its line to
`answers.jsonl`, run `init`, then `review` and the approvals again (a changed `cases.jsonl` invalidates
both, and a changed claim also needs the calibration again).

## Grader

The grader is a hybrid (`council-2026-10-05.md`). Two rounds of tighter regular expressions on free
text took the worst trivial answerer from 92.9% to 24.0%, but held-out correct answers fell from 88.5%
on main to 68.2%, with seven scored 0: a regex trades resistance to keyword lists for false negatives,
and overfits the answers it is tuned on. Free text is now judged; the regexes that remain check
structure.

| Case type | Programmatic claims | Judge claims | Gate |
|---|---|---|---|
| 22 cases with a boolean | 22 booleans; 4 structured (a command path and three code checks) | 36 | the boolean |
| 13 cases with no boolean | 10 structured (code, a citation, a number, the owner phrase) | 20 | 7 by program, 6 by judge (majority of three) |
| all 35 | 36 (22 booleans, 14 structured) | 56 | |

Every judge question begins "The answer states". The judge runs in one of two pre-registered arms,
both on `sonnet` with three votes and a majority: P (`plain`, the default) sees the claims and the
fields; R (`reference`) also sees the case's reference, labelled as the expert's reference.

**Round 3: claims rewritten for coverage, then frozen.** Round 2's calibration failed for both judges,
and the adjudication that followed found that 21 of the 70 development wrong answers had no claim
their corruption falsifies. Round 3 (`council-2026-10-05.md`) rewrote the claims from the
development material alone: the references, `calibration/answers-a`, `-b` and `-c`, the round-2
wrong set and its adjudication labels. The fresh held-out sets were never opened.

- Every reference point that a development wrong answer corrupted now has a claim. One judge claim is
  new (`typed-array-ternary` / `untyped-branch-fails`, on a field no claim read).
- Each structured target has a `must_not_match` for its siblings: another `check_*` script, another
  `_*_choices` or `_*_pile`, another `*_SHADER` or `*View`, another `get_center()` receiver or a scale
  factor, a subtracted descent, another `ward_hit` receiver or heading, another `.gd` file or a line
  number, another owner, and the locale or the definition in place of the art. A test swaps each
  target for each sibling in all 315 committed correct answers, and also offers the sibling beside the
  target; every mutant fails.
- Judge questions keep round 2's wording unless a development wrong answer showed a gap. Where one
  did (20 questions), a trailing "False if it says ..." names the concrete wrong alternative. Two
  trial versions that wrote a contrast into every question made the judge fail correct answers that
  never mention the alternative (10.9% of judge claims on 150 correct answers in the first), so
  contrasts are kept to the questions with evidence.
- No claim looks for hedge wording; the judge's brief already counts a set of alternatives as false.
- Six questions were then reworded because they failed correct development answers on a literal
  detail (`single-line`, `identity-default`, `states-rule`, `explains-stderr`, `checks-reach`,
  `throwaway-driver`). The `per-recipe-uniform` gate now says that `confetti()` lives in
  `card_surface.gdshader`, which the judge cannot otherwise know; three wordings were tried on that
  case's development answers alone. In all, 27 of the 56 judge questions and 11 of the 14 structured
  claims differ from round 2.

Development check on the frozen claims, `sonnet`, majority of three (the third ballot is cast only
when the first two disagree, which gives the same majority), on 245 correct answers (the 35
references and sets a, b and c) and the 70 wrong answers:

| | P (plain) | R (reference) |
|---|---|---|
| Judge claims failed on correct answers | 7/392 (1.8%) | 2/392 (0.5%) |
| Decision or gate failures on correct answers | 0 | 0 |
| COVERED judge claims passed on wrong answers | 0/58 | 0/58 |
| Wrong answers at 100% | 0/70 | 0/70 |
| Coverage (labelled by the claim writer) | 70/70 | 70/70 |

These figures are in-sample: the claims were rewritten on this material, so they prove nothing about
held-out answers. The fresh sets and the blind adjudication decide (`calibration.py` computes the
bars; see `tools/agent_evals/README.md`).

**Frozen claims.** The sha256 over every claim, programmatic and judge, in file order
(`graders.claims_sha256`) is

`0235c5bc81daa4e8ae1ce08109ce95a363631605b54ed8b7f87d85db81e374e8`

and a test pins it. Changing any claim changes the hash, and then the calibration and the grader
approval must be done again.

**Offline results (no model call).** With a fake judge that credits nothing, the programmatic claims
give every trivial answerer nothing beyond the correct booleans: all 28 answerers score at most 23.8%,
the `oracle_booleans` share. With a fake judge that credits everything, all 315 committed correct
answers score 100% (the references, `answers.jsonl`, `answers_independent.jsonl` and calibration sets
b and c), so no programmatic claim rejects a known correct answer.

**Climb noise (unapproved).** One baseline of `sonnet` x 3 repetitions on the round-2 claims (judge
`sonnet`, arm P), run only to see whether a climb can measure anything; it is not an approval run and
was never offered to `approve-grader`. Its mean was 64.7%. The test split's noise floor was 0.060
(14 cases) and the train split's 0.081 (21 cases): both above `min_gain` 0.05, so a climb's gain on
the test split must exceed 0.060 to count, and the number of cases, not `min_gain`, sets the limit.

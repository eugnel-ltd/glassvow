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
  the hill-climb model (`sonnet`) and the judge model (unused by this eval).
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
  the hybrid grader and the evidence its approval needs.

## Adding a case

Take it from a real transcript, bug report or note first, then a hand-written case, then a synthetic
one anchored to a real one. Write `why_hard` before running anything. Keep the prompt
self-contained, avoid sharing a 40-character span with another case, check booleans, commands, paths,
numbers and code by program and write every free-text claim as a judge question from the reference
alone ("The answer states ..."), give a case with no boolean one `"gate": true` claim, add its line to
`answers.jsonl`, run `init`, then `review` and the approvals again (a changed `cases.jsonl` invalidates
both, and a changed judge question also needs the calibration again).

## Grader

The grader is a hybrid (`council-2026-10-05.md`). Two rounds of tighter regular expressions on free
text took the worst trivial answerer from 92.9% to 24.0%, but held-out correct answers fell from 88.5%
on main to 68.2%, with seven scored 0: a regex trades resistance to keyword lists for false negatives,
and overfits the answers it is tuned on. Free text is now judged; the regexes that remain check
structure.

| Case type | Programmatic claims | Judge claims | Gate |
|---|---|---|---|
| 22 cases with a boolean | 22 booleans; 4 structured (a command path and three code checks) | 35 | the boolean |
| 13 cases with no boolean | 10 structured (code, a citation, a number, the owner phrase) | 20 | 7 by program, 6 by judge (majority of three) |
| all 35 | 36 (22 booleans, 14 structured) | 55 | |

Every judge question begins "The answer states", was written from the case's reference alone and is
frozen: the sha256 over all judge claim texts (`graders.judge_questions_sha256`) is

`3d805fadb9d088f687fc2b5cd4ce7279739d6d8aa0dbfdfaec0ed55c98cfe719`

and a test pins it. Changing a question changes the hash, and then the calibration and the grader
approval must be done again.

**Offline results (no model call).** With a fake judge that credits nothing, the programmatic claims
give every trivial answerer nothing beyond the correct booleans: all 31 answerers score at most 24.0%,
the `oracle_booleans` share. With a fake judge that credits everything, every reference answer, both
correct answers per case in `answers.jsonl` and all 70 answers in `answers_independent.jsonl` score
100%, so no programmatic claim rejects a known correct answer. What the real judge accepts is measured
by the calibration run, which `council-2026-10-05.md` specifies: false negatives on blind correct sets,
false positives on minimal-pair wrong answers, the trivial and adversarial answerers through the real
judge (none above 25% or more than 2 points over `oracle_booleans`), the ballot flip rate, and
agreement with independent labels on real outputs.

# repo_traps

Measures whether an agent working in Glassvow makes the right call on the repository's
documented traps. Surface under test: `.claude/skills/glassvow-godot/SKILL.md`, given to the model
as its system prompt (nothing else from the repository is visible to it).

## Cases

`cases.jsonl` holds 35 cases. Every case is a concrete situation (a code excerpt, a command and
its output, or a task step) that asks for a short JSON decision, graded by checkable claims on
named fields. Each case names its `source` (the note or doc recording the real failure) and
states `why_hard` before inclusion. They were derived from these records:

- `docs/solutions/runtime-errors/typed-array-from-ternary-branch-throws-at-runtime.md` (3)
- `docs/solutions/logic-errors/const-typed-dictionary-drops-its-packed-array-type.md` (2)
- `docs/solutions/test-failures/canary-pins-the-rule-not-the-bugs-shape.md`
- `docs/solutions/test-failures/a-script-error-in-a-test-used-to-pass-silently.md` (2, in opposite directions)
- `docs/solutions/ui-bugs/` notes on borrowed shader consts, scaling and centres (2), hit areas, label
  metrics, the hero ward stone, the flat billboard shadow, centring versus animation
  (`two-rules-one-property`) and the Web canvas
- `docs/solutions/design-patterns/` notes on node-per-layer in Godot (2, one each way) and procedural glass
- `docs/solutions/conventions/` notes on per-recipe shader knobs, gating where the change is
  deterministic, citing the symbol, a hypothetical in review, and numbers that matched
- `docs/solutions/workflow-issues/` notes on save fixtures, shared documents, citation annotation and
  whole-run route verification
- `docs/solutions/tooling-decisions/long-lived-capture-host-not-process-per-shot.md`
- `docs/solutions/architecture-patterns/live-language-switching-is-one-main-owned-transaction.md`
- `docs/solutions/integration-issues/` notes on Funplay `-32000` and verifying the artifact
- `docs/dev-tools.md` (override.cfg isolation, never deleting a real save)

The surface under test is the skill, so no case comes from `CLAUDE.md` (its rules would only be copied into
the skill), and no case rests on a design README that merely mentions a rule.

Some cases test the opposite error (treating harmless renderer noise as a failure; collapsing nodes that
need their own input; adding a helper on a belief that was never measured), so the eval does not reward an agent that is merely suspicious.
Some cases are answered by the surface already; that is intended (it measures whether the surface
carries the trap) and the headroom diagnostic will say if the eval saturates. Half of the boolean claims
expect `true` and half `false`, and the trivial-answerer diagnostic (constant and echo answers) scores
12.6% at most on these cases (it was 51.2% before the rebalance).

## Files

- `eval.json`: surface path, grader type (`claims`), default models (`haiku`, `sonnet`, `opus`),
  the hill-climb model (`sonnet`) and the judge model (unused by this eval).
- `cases.jsonl`: `id`, `source`, `why_hard`, `prompt`, `answer_format`, `reference` (the intended
  answer, for reviewers and for the failure-injection check) and `grader`.
- `split.json`: the seeded 60/40 train/test split, written by `init`. Re-run `init` if cases change.

## Adding a case

Take it from a real transcript, bug report or note first, then a hand-written case, then a synthetic
one anchored to a real one. Write `why_hard` before running anything. Keep the prompt
self-contained, avoid sharing a 40-character span with another case, run `init`, then `review`
and the approvals again (a changed `cases.jsonl` invalidates both).

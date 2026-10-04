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
expect `true` and half `false`. A wrong boolean decision scores its case 0 (the decision gate), and the
trivial-answerer diagnostic scores 24.0% at most; see Grader diagnostics below.

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

## Grader diagnostics

Trivial answerers graded by the real grader on the 35 cases (`trivial_answerer_scores`; no model is
called; limit 25%). "Old" is the previous 35 cases under the previous grader (no decision gate, no field
cap); the soup and oracle rows did not exist then and were measured on that state for comparison.

| Answerer | Old | Now |
|---|---|---|
| constant false (booleans false, empty text) | 11.0% | 11.9% |
| constant true (booleans true, empty text) | 11.2% | 12.1% |
| echo false (booleans false, text = prompt) | 12.4% | 19.0% |
| echo true (booleans true, text = prompt) | 12.6% | 15.5% |
| keyword soup false (every text field = one list of all domain words) | 68.3% | 11.9% |
| keyword soup true | 68.6% | 12.1% |
| oracle booleans (correct booleans, empty text) | 22.1% | 24.0% |
| empty answer `{}` | 0.0% | 0.0% |
| maximum | 68.6% | 24.0% |

The decision gate alone brought the full soup from 68.6% to 59.0% (with the replacement cases), not
under the limit; the 1,000-character field cap does the rest, because the soup is about 5,300
characters. The oracle row is the least slack: it is the share of the score a model earns from the
booleans alone, so a new case with a boolean and little else raises it.

Known residual: a compact soup that fits under the cap (the most frequent claim words, 300 to 950
characters) still scores 27% to 41%, because a few common words satisfy many keyword regexes and the
booleans are right in half the cases. It is not part of the gate; tightening the keyword claims is the
fix, and `approve-grader` does not yet measure it.

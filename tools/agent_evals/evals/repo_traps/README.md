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
the 13 cases with no boolean marks one structural claim as its gate instead, so a keyword list scores 0
there too. The trivial-answerer diagnostic scores 24.0% at most; see Grader diagnostics below.

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
  case's prompt, answer format and reference without sight of any grader (its first line says so). The
  answers are copied verbatim and are never edited to suit a claim; the offline tests require every one
  to score 100%. A further held-out set, written the same way, is kept outside the repository for review.

## Adding a case

Take it from a real transcript, bug report or note first, then a hand-written case, then a synthetic
one anchored to a real one. Write `why_hard` before running anything. Keep the prompt
self-contained, avoid sharing a 40-character span with another case, give a case with no boolean one
`"gate": true` claim, add its line to `answers.jsonl`, run `init`, then `review` and the approvals again
(a changed `cases.jsonl` invalidates both).

## Grader diagnostics

Trivial answerers graded by the real grader on the 35 cases (`trivial_answerer_scores`; no model is
called; limit 25%). The council round (`council-2026-10-04.md`) added the decision gate and the
1,000-character field cap, which took the full keyword soup from 68.6% to 11.9%. Each column below is
scored with today's answerers: origin/main before this work, the first candidate of PR #691 (0975aca4;
structural gates, hit-count limit, keyword-tightened claims), and now (statement-shaped claims).

| Answerer (text filler; booleans false / true / oracle) | origin/main | 0975aca4 | Now |
|---|---|---|---|
| empty answer `{}` | 0.0% | 0.0% | 0.0% |
| constant (empty text; oracle is `oracle_booleans`) | 11.9 / 12.1 / 24.0 | 11.9 / 12.1 / 24.0 | 11.9 / 12.1 / 24.0 |
| echo (text = prompt) | 19.0 / 15.5 / 32.1 | 11.9 / 12.1 / 24.0 | 11.9 / 12.1 / 24.0 |
| full keyword soup | 11.9 / 12.1 / 24.0 | 11.9 / 12.1 / 24.0 | 11.9 / 12.1 / 24.0 |
| compact generic soup | 41.9 / 47.1 / 70.0 | 11.9 / 12.1 / 24.0 | 11.9 / 12.1 / 24.0 |
| compact case-aware soup | 57.6 / 60.5 / 89.0 | 11.9 / 12.1 / 24.0 | 11.9 / 12.1 / 24.0 |
| capped soup (first keywords up to the hit limit) | 56.2 / 59.0 / 87.6 | 32.9 / 33.8 / 55.2 | 11.9 / 12.1 / 24.0 |
| keyword run (grader-searched, sorted or reversed) | 61.4 / 63.3 / 92.9 | 43.8 / 46.4 / 73.1 | 11.9 / 12.1 / 24.0 |
| maximum | 92.9% | 73.1% | 24.0% |

The council's own constructions, rescored the same way, now: the hand-made generic soup 11.9 / 12.1 /
24.0 (33.8 / 32.4 / 55.7 on origin/main), and each field filled with the regex fragments of its own
claims in pattern order 11.9 / 12.1 / 24.0 (54.5 / 56.2 / 84.0).

No text filler earns anything beyond the booleans it is handed: every oracle row equals
`oracle_booleans`, which stays the least slack (it is the share of the score the booleans alone carry,
so a new case with a boolean and little else raises it).

**Where the line is.** The answerers above list keywords in a fixed order; the keyword run may choose
which run of them to send, but not their order. An answerer that also chooses the order, with the grader
telling it what passes, is composing statements rather than listing words. Two such searches were run
by hand and are not part of the diagnostic. 200 random orders of each claim's keywords per claim score
42.4 / 42.9 / 68.1%, and runs taken in the pattern's own order satisfy 18 claims. What they find is
mostly a short correct statement in the claim's own words ("never calls set_profile", "doesn't apply",
"isn't empty", "into the vertex stage"). The grader has to accept those, because a terse correct answer
must not lose credit, so this is the floor for any grader that credits short answers.

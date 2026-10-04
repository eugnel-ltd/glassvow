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

## Adding a case

Take it from a real transcript, bug report or note first, then a hand-written case, then a synthetic
one anchored to a real one. Write `why_hard` before running anything. Keep the prompt
self-contained, avoid sharing a 40-character span with another case, give a case with no boolean one
`"gate": true` claim, add its line to `answers.jsonl`, run `init`, then `review` and the approvals again
(a changed `cases.jsonl` invalidates both).

## Grader diagnostics

Trivial answerers graded by the real grader on the 35 cases (`trivial_answerer_scores`; no model is
called; limit 25%). The council round (`council-2026-10-04.md`) added the decision gate and the
1,000-character field cap, which took the full keyword soup from 68.6% to 11.9%. "Before" below is that
state (origin/main at cbfac106), rescored with today's answerers; "After" adds the structural gates, the
hit-count limit and the tightened claims.

| Answerer (text filler; booleans) | Before | After |
|---|---|---|
| empty answer `{}` | 0.0% | 0.0% |
| constant (empty text); false / true | 11.9% / 12.1% | 11.9% / 12.1% |
| constant; oracle (`oracle_booleans`) | 24.0% | 24.0% |
| echo (text = prompt); false / true | 19.0% / 15.5% | 11.9% / 12.1% |
| echo; oracle | 32.1% | 24.0% |
| full keyword soup; false / true / oracle | 11.9% / 12.1% / 24.0% | 11.9% / 12.1% / 24.0% |
| compact generic soup; false / true | 41.9% / 47.1% | 11.9% / 12.1% |
| compact generic soup; oracle | 70.0% | 24.0% |
| compact case-aware soup; false / true | 57.6% / 60.5% | 11.9% / 12.1% |
| compact case-aware soup; oracle | 89.0% | 24.0% |
| maximum | 89.0% | 24.0% |

The council's own constructions, rescored the same way:

| Construction | Before | After |
|---|---|---|
| hand-made generic soup (263 characters); false / true / oracle | 33.8% / 32.4% / 55.7% | 11.9% / 12.1% / 24.0% |
| each text field filled with the regex fragments of its own claims, in pattern order; false / true / oracle | 54.5% / 56.2% / 84.0% | 12.6% / 12.1% / 24.8% |

The second construction reads the grader (it knows which field each claim checks and the order of
its words), so it is an upper bound rather than a trivial answerer, and the diagnostic does not run it.

After the change no text filler earns anything beyond the booleans it is handed: every oracle row
equals `oracle_booleans`, which stays the least slack (it is the share of the score the booleans alone
carry, so a new case with a boolean and little else raises it). Each mechanism is needed: without the
hit-count limit the case-aware soup with oracle booleans scores 46.0%; without the structural gates the
compact soups with oracle booleans score 32.1% and 32.6% and the echo 26.2%; the tightened claims close
the rest (claims that one topic word, or a word inside another word, used to satisfy).

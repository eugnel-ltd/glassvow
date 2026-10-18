# Structured repo traps: unapproved development candidate

This is issue #694's programmatic fallback candidate. It contains 80 source-backed cases:
35 existing development situations expressed with single-valued decisive fields, and 45
additional anchored situations. Each case carries its source and reason for inclusion before
any model run. The seeded split contains 48 training and 32 test cases.

The original `../repo_traps/` corpus, its approvals, council records and spent calibration
sets remain frozen. This directory has no approvals. No real-model baseline, judge calibration
or hill-climb has been run on this candidate. The predecessor at `014f58ba` failed offline
programmatic calibration; its results and single-use answer sets remain unchanged and spent.

Every scored field uses strict scalar equality or a fully anchored citation pattern.
`decision_gate_audit.jsonl` records the once-through source audit of all 80 cases and all 138
scored claims against the source tree at `014f58ba3c4a62bbb3c41e19944caae6df47a81d`, with
source hashes, locations and a reason for every classification. All 137 required selected
decisions are gates (136 explicit scalar/pattern gates and one implicit boolean gate).
The one non-gate claim is Funplay's `likely-cause`: the task asks for the first check, while
its source says an absent editor is only one possible explanation, alongside a disabled
server or a fallback port. The endpoint and probe action both gate. This exception is
source-based; it makes no promise that a future adversarial metric will pass.

The font case now defines `baseline_offset` as `Label.position.y - NUM_BASELINE`, with the
intended glyph baseline as the anchor. The source explicitly computes that top coordinate
by subtracting ascent. The old response field did not name its coordinate relation, so the
future prompt is clarified rather than broadening accepted values from scored answers.
The two predecessor false negatives and their frozen classification remain historical
results; this clarification does not retrospectively establish that those writers were wrong.

Free-text reasoning is a `report_only` judge
claim: its field, verdicts, ballots, model identity and any failure are reported separately
and cannot affect accuracy, pass status or scoring infrastructure status. Without a judge
backend the transcript records the claim as not evaluated. The Sonnet judge alias and plain
arm stay unchanged; this work does not calibrate or approve them.

The citation case accepts plain symbols and matching single or double backticks. The four
known vulnerable families use exact command, origin, formula, receiver, heading, path and
symbol fields; a hedge or retraction in one of these fields fails its programmatic check.

`development_answers.jsonl` contains the author's construction fixtures. They are development
material, derived alongside the claims. They are neither independent answers nor blind sets,
and their passing tests establish no statistical calibration bar or real-model noise floor.
Fresh evaluation material must stay separate from these fixtures and every spent round-3 set.

Offline commands, from the repository root:

```bash
python3 -B tools/agent_evals/cli.py init repo_traps_structured
python3 -B tools/agent_evals/cli.py review repo_traps_structured
python3 -B tests/test_agent_evals_review.py
python3 -B tests/test_agent_evals_decision_gates.py
```

Before #694 or its parent #672 can close, the remaining work is:

- Freeze this candidate's cases and claims hashes before commissioning fresh blind answers.
- Obtain correct answers from at least two independent writers, balanced wrong answers and
  the prescribed adversarial transforms; hash them before scoring and adjudicate them blind.
- Evaluate the programmatic claims against the pre-registered bars in #694, using fresh sets.
  Do not start another judge-calibration campaign.
- Obtain an actual isolated Sonnet baseline with three repetitions, its resolved model and
  input hashes, and test-split noise below `min_gain`. A scripted backend cannot supply this.
- Record the current-hash inputs and grader approvals through their authorised path. This
  implementation and its author-written fixtures supply neither approval.

No local Claude executable, Anthropic API key or Claude OAuth configuration was available
during implementation. No provider call or paid evaluation was attempted. The existing
approval guards continue to refuse a climb on this unapproved corpus.

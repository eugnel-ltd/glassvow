# LESSONS.md

Short live log of repeatable mistakes. Read it before every task. At most fifteen entries; older ones live in `docs/solutions/`, searched when a task touches their area.

- Add an entry as soon as a review finding, revert, follow-up fix, failed CI run, rework or incident shows a repeatable mistake. Add one at once when an agent makes the same mistake twice.
- The nightly audit bumps `Seen` (one count per day), merges duplicates, deletes obsolete entries and moves overflow to `docs/solutions/`.
- A lesson seen on three different days moves by PR into the governing doc for its area (`docs/agents/ai-sdlc.md` for process, `AGENTS.md` for invariants, the matching skill under `.claude/skills/`, or a `docs/solutions/` entry otherwise) and leaves this file. This repo has no `docs/code-standards.md`.

Entry format (newest first):

```markdown
### <one-line rule, imperative>
- Cause: <what went wrong and why>
- Fix: <commit sha or PR #>
- Done right: <what the correct approach looks like>
- Seen: 1× (YYYY-MM-DD)
```

## Entries

### Gate every structured choice required for an actionable answer
- Cause: Exact checks rejected wrong secondary choices, but only the first selected decision gated; a wrong heading or corrected expression still earned partial credit.
- Fix: e93d5c43 (source audit and regression), issue #694 gate repair; keep optional background hypotheses separate from required decisions.
- Done right: Audit each selected field against its source and prove that a wrong or missing required choice scores zero; keep free-text reasoning reported only.
- Seen: 1× (2026-10-18)

### Keep animation regression budgets on the simulation clock
- Cause: Card and pile regressions compared wall-clock deadlines and frame samples with variable-step animations, so heavy host load could change which states they observed.
- Fix: 431b6363 (issue #661), fixed-step children for the two affected suites.
- Done right: Exercise the real timers, tweens and event sequence; verify the fixed delta across a wall delay and prove a slower flight still fails the original checks.
- Seen: 1× (2026-10-18)

This repo's long record of solved problems is `docs/solutions/`, by category. Short repeatable lessons go here.

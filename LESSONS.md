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

### Parse a new regression fixture before freezing its first test commit
- Cause: a new locked fixture passed Variant comparisons to a bool parameter; its first replacement also omitted parentheses around a multiline comparison. Neither parsed, so neither proved a behavioural failure.
- Fix: a85b52f3 (runnable immutable fixture), f009a32e (source fix).
- Done right: run the explicit-path parser before the first test commit, commit the runnable test, observe its named failure on unchanged source, then apply the fix and observe green. Preserve abandoned candidates and their failed logs without rewriting them.
- Seen: 1× (2026-10-18)

### Gate every structured choice required for an actionable answer
- Cause: Exact checks rejected wrong secondary choices, but only the first selected decision gated; a wrong heading or corrected expression still earned partial credit.
- Fix: e93d5c43 (source audit and regression), issue #694 gate repair; keep optional background hypotheses separate from required decisions.
- Done right: Audit each selected field against its source and prove that a wrong or missing required choice scores zero; keep free-text reasoning reported only.
- Seen: 1× (2026-10-18)

This repo's long record of solved problems is `docs/solutions/`, by category. Short repeatable lessons go here.

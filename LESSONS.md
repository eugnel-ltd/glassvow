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

### Pass one platform snapshot through each shared update
- Cause: The hologram's shared update and its pointer helper each built the same platform-facts dictionary, doubling that work every active frame.
- Fix: bf786ce7b004179b75ed767a84c586ab414d53a7
- Done right: Read once after the still and forced-pose exits, then pass the snapshot to both consumers. Count provider calls through the real shared-update dispatch and check same-frame reuse.
- Seen: 1× (2026-10-18)

This repo's long record of solved problems is `docs/solutions/`, by category. Short repeatable lessons go here.

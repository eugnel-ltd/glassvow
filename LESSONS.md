# LESSONS.md

Short live log of repeatable mistakes. Read it before every task. At most fifteen entries; older ones live in `docs/solutions/`, searched when a task touches their area.

- Add an entry as soon as a review finding, revert, follow-up fix, failed CI run, rework or incident shows a repeatable mistake. Add one at once when an agent makes the same mistake twice.
- The nightly audit bumps `Seen` (one count per day), merges duplicates, deletes obsolete entries and moves overflow to `docs/solutions/`.
- A lesson seen on three different days moves by PR into the governing doc for its area (`docs/agents/ai-sdlc.md` for process, `AGENTS.md` for invariants, the matching skill under `.claude/skills/`, or a `docs/solutions/` entry otherwise) and leaves this file. This repo has no `docs/code-standards.md`.

## Recent entry

### Cast Variant values before passing them to typed GDScript boundaries
- Cause: Dictionary values passed to typed bool parameters caused warning-as-error parse failures in two test additions.
- Fix: ad90cb8396fc6755dbe1ef2152ae605cdec88117
- Done right: Assign an explicitly typed local before a typed call, or use the existing Variant-aware test assertion helper and compare its value with true.
- Seen: 1× (2026-10-18)

Entry format (newest first):

```markdown
### <one-line rule, imperative>
- Cause: <what went wrong and why>
- Fix: <commit sha or PR #>
- Done right: <what the correct approach looks like>
- Seen: 1× (YYYY-MM-DD)
```

## Current entry

### Refresh pending cache retention from the latest selection
- Cause: Choosing a different card back cleared the first bake's retention flag permanently, so selecting it again before completion discarded its result and rendered it twice.
- Fix: fcc606f6af07291c9b7e4eb648e71becc141ed29
- Done right: Set every pending job's retention from the latest choice. A signal-gated A to B to A regression keeps the shared A result, drops B and proves a repeated request does not render again.
- Seen: 1× (2026-10-18)

## Entries

### Pass one platform snapshot through each shared update
- Cause: The hologram's shared update and its pointer helper each built the same platform-facts dictionary, doubling that work every active frame.
- Fix: bf786ce7b004179b75ed767a84c586ab414d53a7
- Done right: Read once after the still and forced-pose exits, then pass the snapshot to both consumers. Count provider calls through the real shared-update dispatch and check same-frame reuse.
- Seen: 1× (2026-10-18)

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

### Reject duplicate dictionary keys before qualifying external metadata
- Cause: plistlib silently kept the last repeated Xcode build, allowing conflicting IPA identity metadata to pass the upload guard.
- Fix: 05533b2082664a787a17497b91a2b1619d32d6e4.
- Done right: use a duplicate-rejecting dict_type for both XML and binary plists, and prove that raw conflicting metadata cannot reach the release upload boundary.
- Seen: 1× (2026-10-18)

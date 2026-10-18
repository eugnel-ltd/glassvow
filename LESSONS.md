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

### Check profile ownership before persisting player defaults
- Cause: onboarding deliberately kept story flow active on the Development profile, so a narrative-flow check let synthetic departures overwrite player Preferences.
- Fix: `edd0084876e99f47db862fce978b64910ac71b1f`.
- Done right: use the installed profile boundary at every write-entry marker; prove byte preservation for synthetic starts and resumed choices while preserving the explicit production-profile opt-out.
- Seen: 1× (2026-10-18)

### Keep report provenance complete in statistical fixtures
- Cause: A B2 reporting fixture used an empty manifest, concealing a path that accepted another class and cell under the requested report filename.
- Fix: The #661/#544 B2 sensitivity correction shares the grader's complete report-identity validation and adds a public CLI regression with matching content but conflicting class/cell metadata.
- Done right: Synthetic reports preserve the production manifest identity and seed metadata; numerical regression claims do not excuse missing provenance.
- Seen: 1× (2026-10-18)

### Refresh retained faces when their resolved definition changes
- Cause: The discard top reused a snapshot by card UID, so the Unbroken power changed the rider text while the same top card kept its old face.
- Fix: ff3cfae9b475b93f746f7cfb176adbdd79c94bab
- Done right: Compare the resolved definition key, reject stale handoff and bake results, and prove an unchanged UID updates without rebaking unchanged definitions.
- Seen: 1× (2026-10-18)

### Prewarm real fights through every development entry
- Cause: The onboarding bench built the real combat screen but skipped the shared card-back bake and shader hold used by both normal fight entries.
- Fix: Issue #661, onboarding card prewarm follow-up.
- Done right: Exercise the actual onboarding entry with cold, chosen and cached backs, and check that its screen owns the generated-material hold.
- Seen: 1× (2026-10-18)

### Recheck each waiter's lifetime after a shared async job completes
- Cause: A successful shared card-back bake reached a waiter whose host was freed; the existing freed-waiter regression exercised only a failed render.
- Fix: #657 successful-owner / freed-waiter follow-up.
- Done right: Validate the waiting caller after the shared await. Use one signal barrier to require a live owner's result and cache, a live waiter's shared result, a freed waiter's null result, and no extra render.
- Seen: 1× (2026-10-18)

### Parse a new regression fixture before freezing its first test commit
- Cause: a new locked fixture passed Variant comparisons to a bool parameter; its first replacement also omitted parentheses around a multiline comparison. Neither parsed, so neither proved a behavioural failure.
- Fix: a85b52f3 (runnable immutable fixture), f009a32e (source fix).
- Done right: run the explicit-path parser before the first test commit, commit the runnable test, observe its named failure on unchanged source, then apply the fix and observe green. Preserve abandoned candidates and their failed logs without rewriting them.
- Seen: 1× (2026-10-18)

### Compare retained floating values without a text round trip
- Cause: A p10 regression converted a saved float through `str`, whose display precision rounded it and falsely rejected an identical score. The invalid attempt and logs remain preserved; a new canonical first fixture was strictly parsed and failed unchanged source before production edits.
- Fix: d86a67d4a2337a0186f022b2c572a9cb082d096c
- Done right: Assign a Dictionary value to an explicitly typed float before comparing it. Never round production calculations to satisfy a faulty fixture.
- Seen: 1× (2026-10-18)

# REVIEW.md

What the independent reviewer checks on every PR. The reviewer reads this file first, then uses the AI-SDLC review prompt (`references/review-prompt.md`). Changed by PR.

This repo's own review rule stays in force: one fresh-context final-candidate review for semantic or policy changes and for non-mechanical multi-file changes with interacting risks; fully mechanical changes with decisive deterministic proof need none (`AGENTS.md`, `docs/agents/ai-sdlc.md`, `.claude/agents/ai-sdlc-reviewer.md`). This file names who reviews and what they check.

## Reviewer

- Primary: codex (its default model), read-only: no file edits, no state-changing git commands, no network writes.
- Fall-backs when the primary's quota is spent or it cannot sign in, in order: Grok Build, Antigravity CLI when it runs headless.
- Last resort: the repo's `.claude/agents/ai-sdlc-reviewer.md` in a fresh context. The PR says so, and the task type cannot merge above level 2 on that review.

Findings P0–P3, each with `file:line`, posted on the PR as a comment with `VERDICT:` and `Reviewed head: <sha>` lines. Re-reviews cover only the fix diff.

## Passes

Run all three, in order, against the PR's diff:

1. **Bugs and logic:** correctness on real inputs (empty and missing values, boundaries, seeded randomness, save load and migration, locale text), `domain/` purity (commands through `GlassvowGame.apply`, presentation never owns game truth), failure behaviour, silent failures, and whether the regression test really fails on the old code.
2. **Security:** secrets (Sentry, signing, store credentials), untrusted input, new dependencies and addons.
3. **Compliance:** the diff against the issue, `docs/agents/ai-sdlc.md` (this repo's process authority), `AGENTS.md` invariants, accepted ADRs, `docs/owner-decisions.md` when it exists and `docs/north-star.md`. A diff that spends money without an `Expenditure:` decision fails this pass.

## Severity

- **Important** (blocks): P0 data loss, security hole, outage or irreversible damage; P1 wrong behaviour on a real path, or an acceptance criterion fails; P2 edge-case bug, weak or missing test, undisclosed unrun check, missing docs.
- **Nit** (never blocks): P3. Report at most **5** per review; drop the rest.
- **Pre-existing** (never blocks): a fault the base already has, on a path this PR does not change, whatever its severity. A fault the PR newly exposes is its own finding. It becomes a follow-up intent.

## What failure looks like

- Game logic: a save that no longer loads, a seeded run that plays differently, a silently regenerated golden in `port_fixtures/`.
- Presentation: it compiles but does not render, or renders wrong at a reference shape.
- Docs and agent instructions: it lies, or `tools/check_agent_contracts.py` fails.

## Exclusions

Do not review:

- generated files and vendored code: `addons/`, `.import` files, `port_fixtures/` bulk data (review the commit that explains a golden change, not the data);
- anything CI already enforces: `tools/check_imports.sh`, `tools/check_scripts.sh`, `tools/ci_scope.py` selections.

## Doc-only fast lane

A diff takes the doc-only fast lane when it changes nothing that runs, is copied, or is read as an instruction. In: `README.md`, `LESSONS.md`, `docs/solutions/`, and prose under `docs/` that no agent or tool acts on. Out, always the full lane: `AGENTS.md`, `CLAUDE.md`, `REVIEW.md`, `docs/agents/`, `docs/owner-decisions.md`, `docs/autonomy-ledger.md`, `docs/north-star.md`, `product.yaml`, skills, prompts, agent definitions, hooks, workflows, scripts, templates of any kind, configuration, code and tests. The lane gets the compliance pass and the writing check (`modules/writing.md`). No regression test is required.

## Human review required

Paths that get the full review lane and extra care. A PR that touches them merges at its type's level and the digest names it; it does not wait for the owner (AI-SDLC `modules/autonomy.md`).

- `docs/owner-decisions.md`: the owner (append-only; CI checks it). The owner's first entry creates it.

## Separation of duties

- The agent that wrote the change never reviews or approves it.
- A security fix is never approved by the agent that wrote it.

## Feedback

A kind of finding seen on two PRs becomes a `LESSONS.md` entry. A promoted lesson that a machine can check becomes a hook, lint or CI check, not another review pass.

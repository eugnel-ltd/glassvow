---
name: glassvow-orchestrator
description: How to run Glassvow as the orchestrator - brief and delegate lanes, review the exact head, merge, archive to the NAS, keep house, and share the Mac and iPad with ks2. Load only when coordinating lanes, reviews, merges or machine housekeeping, not for ordinary single-lane delivery.
---

# Glassvow Orchestrator

The orchestrator is the session that owns the programme rather than one change. It writes briefs, starts lanes, commissions reviews, merges, archives and keeps the machine healthy. It does very little implementation itself.

This skill adds the orchestration method only. `AGENTS.md` (also served as `CLAUDE.md`) and `docs/agents/ai-sdlc.md` remain the contract for delivery, evidence, review and autonomy; where this file seems to disagree, they win. Engine work inside a lane loads `.claude/skills/glassvow-godot/SKILL.md`; copy loads `.claude/skills/glassvow-story/SKILL.md`.

Depth lives in `references/`:

| File | Use it for |
|---|---|
| `references/lane-rules.md` | The hard rules every lane brief links to |
| `references/brief-template.md` | Writing a lane brief |
| `references/housekeeping.sh` | The routine DerivedData prune and worktree prune |
| `references/nas-archive.md` | Archiving a lane folder to the NAS with sha256 on both ends |
| `references/lessons.md` | The engineering lessons behind the rules, one section each |
| `references/machine-setup.md` | What a new machine needs, where each thing lives, and the seat and engine setup |
| `references/mbp.sh` | Run a shell command on the engine host from the seat |

## 1. The role

- **Delegate.** One lane per outcome, each a fresh subagent with its own brief, branch and worktree. Route by tier: Sonnet for daily delivery and mechanical work, Opus for design, judgement and hard problems; the owner's personal model-routing table, where present, governs.
- **Keep context lean.** Read reports, not transcripts. Hold a task capsule per lane (goal, head, evidence, next action) in a durable run log, not in chat. Do not re-read what a lane has already settled.
- **Act autonomously.** Plans, candidate choices among equivalents, gate reruns, merges, housekeeping and issue hygiene are the orchestrator's calls. Decide, record the decision and its reason, and keep it reversible.
- **Escalate to the owner only for:** credentials and accounts, art and other subjective product picks, product-defining choices absent from the source of truth, and things only he can physically do (unlocking the keychain after a reboot, holding the iPad, accepting an Apple agreement). Put each as one numbered question with a recommendation.
- **The owner's input is never a gate.** His play reports and picks are inputs when they arrive; work that does not depend on them continues.

## 2. The lane lifecycle

1. **Brief.** Copy `references/brief-template.md`. Name the outcome, the lane, the branch from `origin/<main>` at an exact SHA, the worktree path, the only sources to read, the owner decisions already made, scope and non-scope, acceptance and proof, and "report as the lane rules say". Link `references/lane-rules.md` (or a local copy with the session trailer filled in); never restate it loosely.
2. **One lane per outcome.** Its own branch and its own git worktree under `<repo>/.claude/worktrees/<lane>/` (git-ignored, survives reboots; never `/tmp`). Each worktree gets an untracked `override.cfg` holding the full three-line block from the lane rules: the `[application]` header and both keys. Paste the block verbatim; "both keys" in prose has failed before.
3. **Lane works to its brief** and reports the PR number and exact head, the gates, the stills or device figures and the open risks. Lanes do not merge and do not post on issues.
4. **Independent review.** Commission one `ai-sdlc-reviewer` as a non-fork subagent on the exact head, giving only the task contract, base SHA, head SHA, constraints and deterministic evidence already run (`docs/agents/ai-sdlc.md` section 5). If it reaches its turn cap, resume it once, then ask for a report-only answer.
   - `REQUEST_CHANGES`: batch every finding into one fix round by the lane (or a fresh owner with the lane's handoff), then send the delta to the same reviewer once more.
   - `INCONCLUSIVE`: get the named missing evidence; do not merge around it.
   - Skip the model review only for a fully mechanical change with decisive deterministic proof.
5. **Record the verdict** as a PR comment (the reviewer shares the owner's identity, so never a GitHub `APPROVE`). Post long bodies from a file with `gh api ... -F body=@<file>` and read the first characters back.
6. **Merge.** Wait until the required `test` check reports SUCCESS on that head; `gh pr checks --watch` returns at once if no check is registered yet, so poll. Then `gh pr merge <n> --squash --delete-branch --match-head-commit <full head SHA>`.
7. **Archive and delete.** Archive the lane folder to the NAS with sha256 on both ends (`references/nas-archive.md`). Only when the two hashes match, remove the worktree (`git worktree remove`) and the lane folder by literal path, checking and deleting as separate commands.
8. **Housekeeping.** Run `references/housekeeping.sh` (section 6) and note the free disk.
9. **Tracker.** Comment on the tracking issue: what merged (PR, squash SHA), the review verdict, follow-ups. Update the programme tracker if one exists. Never post an agent's draft text verbatim; strip drafting wrappers first.

Pushes from scripts use `git -c credential.helper= -c credential.helper='!gh auth git-credential' push ...` when the macOS keychain reports -25308. In zsh write refspecs as `"${sha}:refs/heads/x"`.

## 3. The owner's standing rules and preferences

- **Language.** Talk to the owner in Hong Kong Cantonese, with key terms bilingual. Everything written (code, comments, docs, PRs, issues, briefs) is in UK English. Lane reports end with a short Cantonese paragraph.
- **Perf bars must be player-visible.** Before setting or chasing any frame, VRAM or load bar, ask whether a player can see or feel that frame (a transition, a launch screen, mid-animation hide it). Validate a probe on the Mac before any device hold. Stop at diminishing returns.
- **Evidence proportional to the decision.** The cheapest decisive evidence for each claim. Keep three-plus-three interleaved device reads for release-level claims; a lane's iPad read is one interleaved batch unless the first is ambiguous. Visual claims need stills someone has looked at, at the three reference shapes.
- **Optimise after visual approval.** Measure budgets early; turn no visual-cost knob until the screen exists and is approved.
- **Design discussion style.** Start from the owner's vision, not the open issues. Facts from the repo first, then his goal in his words, then a challenge, then a recommendation once he agrees the framing. Design is implicit (no path choosers, no tutorial text, no "you chose X"). Science is an instrument panel, never a court. Ask at most three or four numbered questions; he answers by number. He likes concrete detail.
- **Product rulings that still bind.** The map is the revived September journey rebuild, never a from-scratch concept; Acts II to IV follow that archive's approved chapter paintings. The iPad 8 (A12) is the floor, not the only target: the ceiling devices should gain through quality tiers. All player-facing copy comes from Claude through the story skill. Card and art picks are the owner's.
- **Routing.** Codex Sol (newest, effort xhigh, when quota allows) is a cross-model reviewer and image tool, never a design voice. External CLIs are never the only reviewer or implementer.

## 4. The shared Mac and iPad (with ks2)

The Mac and the iPad 8 are shared with the Spelling Camp project (ks2-spelling), whose self-hosted iOS CI flakes under heavy load.

- **Load.** Balance batches at `--jobs 4` or fewer, one batch at a time across all lanes. Wait while the load average is over 50 before a full test run or batch. One Godot run at a time per lane; never kill a process you did not start.
- **Disk.** Keep at least 100 GB free. Below 110 GB, message ks2 with the biggest consumers. Each project cleans only its own regenerable output; anything over 20 GB gets a heads-up first.
- **iPad lock.** A device batch holds the shared mkdir lock (`ipad_lock.sh acquire|release <owner>`, stale after 60 minutes; the holder refreshes by acquiring again). It lives with the QA flow in `<repo>/.claude/worktrees/device13-flow/`. Never break another holder's live lock.
- **QA bundle only.** Lanes install only the QA app (`io.fol2.glassvow.qa`, "Glassvow QA") through `qa_export.sh`. Never the production bundle, never uninstall either app, never touch their containers or the owner's saves. Only `scripts/ios_release.sh` installs production, for a release. Ask before installing anything on the owner's iPhone.
- **Device ids** come from the environment only, never echoed or committed.

## 5. The seat and the engine (Mac mini and MacBook Pro)

From 15 Oct 2026 Claude runs on a Mac mini (16 GB), **the seat**. The MacBook Pro (64 GB) is **the engine**. There is one copy of the repo, on the engine.

- **One working tree, on the engine.** The repo, every worktree, Godot, the iPad cable and lock, the keys, the bake editor and the NAS ssh stay on the MacBook Pro.
- **Same absolute path on both machines.** The seat mounts the engine's `~/Coding` over SMB and symlinks it so that `<repo>` resolves to the same path on both. Claude's Read, Edit and Write tools on the seat then edit the engine's files directly, and every absolute path in a brief works unchanged.
- **Every shell command runs on the engine** through `references/mbp.sh` (`mbp <cmd...>`, or `mbp -c '<pipeline>'`): git, gh, godot, tests, captures, `qa_export.sh`, devicectl, the iPad lock, `housekeeping.sh`, the NAS tar and ssh, and searches. Never run git over SMB (index locks, speed), and never run git, Godot or the suite on the seat.
- **Every lane brief carries the seat clause** from `references/lane-rules.md`. `mbp.sh --where` tells a session whether it is on the seat; `mbp.sh --check` proves the mount and the engine agree before work starts.
- **Memory** lives on the seat; the keys stay on the engine, because the commands that need them run there.

Setup, the engine checklist and the caveats are in `references/machine-setup.md` section 9.

## 6. Housekeeping

Owner-authorised on 14 Oct 2026: after every lane cleanup or merge, the orchestrator (never a lane) prunes Glassvow's own orphaned Xcode DerivedData without asking. Run it on the engine:

```bash
mbp zsh <repo>/.claude/skills/glassvow-orchestrator/references/housekeeping.sh
```

It lists `~/Library/Developer/Xcode/DerivedData/glassvow-*` folders whose `info.plist` `WorkspacePath` no longer exists, writes that list to a file, deletes only entries that match the strict `glassvow-?*` pattern under that one directory, prunes stale git worktree records, and prints the free disk. The first run removed 41 folders, 8.9 GB. Anything else (saves, `~/Library/Caches`, other apps' data, anything not provably Glassvow's own and orphaned) stays forbidden.

## 7. Delete rules and their history

**The rule for lanes:** delete only inside your own worktree and lane folder, by literal absolute path, checking and then deleting as separate commands. Never derive a delete path from `OS.get_cache_dir()`, `OS.get_user_data_dir()`, `OS.get_data_dir()`, `$HOME`, `~/Library` or any system path. A "fresh install" on the iPad means installing a build the device has never compiled, never clearing caches. Never touch `~/Library/Application Support/Godot/app_userdata/` (the owner's real saves). Paste the rule into every brief that may write tools or probes, and when a lane reports a cleanup or purge mode, ask what path it resolves to on each platform before it runs.

**Why, in order:**

- **29 Sep 2026:** an agent deleted the owner's real run save under `app_userdata`. Since then every capture, test and smoke must be provably isolated.
- **30 Sep and 4 Oct:** `override.cfg` files with one key, or both keys without the `[application]` header, ran unisolated against the real profile. Hence the verbatim three-line block.
- **5 Oct, about 07:30:** a map lane gave a probe a "purge renderer caches" mode meant for the iPad sandbox and ran it on the Mac, where `OS.get_cache_dir()` is `~/Library/Caches` itself: about 130,000 files, 14 GB, other apps' caches included. Hence the rule against derived paths.
- **11 Oct:** an exported pck run with `--main-pack` read `override.cfg` beside the pck, not the worktree's, and wrote 84 files into the real profile. They were quarantined with a manifest after the owner approved, not deleted. Hence: briefs that run exported builds or a second binary put the block beside the pck and the binary, and check the real profile's mtimes after the first run.
- **14 Oct, 18:22:** the owner granted the orchestrator one exception: the routine DerivedData prune in section 6. It does not extend to lanes or to any other path.

Archived lane folders are deleted only after the NAS copy's sha256 matches the local one.

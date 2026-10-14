# Machine setup

What a Glassvow orchestrator machine needs, and where each thing lives. **Locations and procedures only.** No value in this file is a secret, and none may be added: name the file or environment variable instead. The owner moves keys by hand, securely; never paste one into a session, a brief, a commit or an issue.

Since 15 Oct 2026 there are two machines. The **seat** (a Mac mini) runs Claude. The **engine** (the MacBook Pro) holds the repo and runs every command. Sections 1 to 8 describe the engine unless they say otherwise; section 9 is the seat and engine setup.

## 1. Godot and the bake editor

- `godot` on `PATH`: Godot 4.7.2 stable or newer (see `.claude/skills/glassvow-godot/SKILL.md`).
- **iOS export template.** Until 4.7.3 ships, the iOS template is a local build of the 4.7 branch with the A12 sampler fix, dropped into the 4.7.2 export-templates folder with the official zip kept beside it. See `references/lessons.md`, "The A12 Metal sampler limit".
- **The bake editor (`GLASSVOW_BAKE_EDITOR`).** Since #712 the iOS release bakes shaders at export and `scripts/ios_release.sh` stops unless `GLASSVOW_BAKE_EDITOR` points at the patched 4.7.3-rc editor binary. It lives in `~/Coding/glassvow-bake-editor/` (`godot-src/bin/godot.macos.editor.arm64`) and is built from the engine's 4.7 branch plus `tools/godot/patches/glassvow-682-ios-shader-bake.patch`; the folder's README has the build steps. Rebuild it when the patch or the iOS template changes. Bakes are not byte-deterministic: compare their MSL source, not file hashes. A fresh worktree needs `godot --headless --import` before a baked export.

## 2. Xcode

- Export with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (the release Xcode). `xcode-select` may point at a beta, and App Store Connect rejects beta-SDK uploads by email only (ITMS-90534), burning the build number. Check the ipa's `DTXcodeBuild` has no beta letter suffix before uploading.

## 3. App Store Connect and TestFlight

- **Procedure:** `docs/release-signing.md` (read it first) and `scripts/ios_release.sh <build> <main sha>`, whose header lists every environment variable it needs.
- **Credentials:** `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_PRIVATE_KEY_PATH`, exported by a scratch launcher that reads them from where the owner keeps them (the `.p8` under `~/.appstoreconnect/private_keys/`; the issuer from the owner's existing TestFlight upload script). Never printed.
- **Rules:** marketing version stays 1.0.0; bump only the build number in both iOS presets, after checking `asc builds list` for the highest. Run the release from a clean worktree detached at the merge SHA, with no `override.cfg`. A launcher that holds the iPad lock must not `exec` the release script, or its EXIT trap never frees the lock. The keychain must be unlocked (section 9).
- **QA builds** use the separate bundle `io.fol2.glassvow.qa` with its own development profile, via `qa_export.sh` in `<repo>/.claude/worktrees/device13-flow/` (README beside it; also in the NAS orchestrator archive).

## 4. ElevenLabs

- The key is `ELEVENLABS_API_KEY` in `~/.config/elevenlabs/.env` (mode 600), not in any shell profile. Read it inside the command that needs it, never print it, and follow `.claude/skills/glassvow-elevenlabs/SKILL.md`.

## 5. Cloudflare and Sentry

- **Privacy site (Cloudflare Pages):** source `site/`, built by `tools/build_site.py` from `docs/privacy/`; see `docs/privacy/README.md` and `docs/release-signing.md`. Wrangler keeps its OAuth login under `~/Library/Preferences/.wrangler/`; it lacks DNS scope, so DNS changes go to the owner. Create Pages projects through the API, not `wrangler pages project create` (it made a Worker).
- **Sentry:** `docs/release-signing.md` and `docs/research/crash-reporting-godot-4-7-mobile.md`. `sentry-cli` needs its auth token in the environment for dSYM upload; access stays Glassvow-bound.

## 6. The NAS

- Host alias `ds1819-clawdbot` in `~/.ssh/config`, key-based, BatchMode. Archives under `~/Archives/glassvow-scratch-<date>/`. See `references/nas-archive.md`.

## 7. Devices

- The iPad 8 stays cabled to the engine, Developer Mode on, paired. Its UDID comes from the environment (`IOS_DEVICE_UDID`), filled by the launcher from `xcrun devicectl list devices`; never echoed or committed.
- The shared lock and the QA flow live in `<repo>/.claude/worktrees/device13-flow/`. The iPhone 16 Pro Max is the owner's: ask before any install.

## 8. Restoring Claude's memory

Claude's per-machine memory does not travel with git. The 14 Oct 2026 copy is on the NAS at `~/Archives/glassvow-scratch-2026-10-14/claude-memory-2026-10-14.tar`; its top-level folder is `memory/`.

1. **Find the slug.** It is the absolute repo path the session opens, with every `/` replaced by `-`. For `/Users/<user>/Coding/glassvow` it is `-Users-<user>-Coding-glassvow`. If unsure, start one Claude session in the repo and look at the new folder under `~/.claude/projects/`.
2. **Check and extract** on the machine where Claude runs (the seat). The seat reaches the NAS through the engine, so stream it, running from `<repo>` (`mbp` changes to the same directory on the engine):
   ```bash
   mbp -c "ssh -o BatchMode=yes ds1819-clawdbot 'sha256sum ~/Archives/glassvow-scratch-2026-10-14/claude-memory-2026-10-14.tar'"
   mkdir -p ~/.claude/projects/<slug>
   mbp -c "ssh -o BatchMode=yes ds1819-clawdbot 'cat ~/Archives/glassvow-scratch-2026-10-14/claude-memory-2026-10-14.tar'" \
     | tee >(shasum -a 256) | tar -xf - -C ~/.claude/projects/<slug>/
   ```
   The two hashes must match (the recorded local hash is `claude-memory.local.sha` in the archived orchestrator folder). The tar holds `._` AppleDouble entries; on macOS they merge back as attributes.
3. **Verify:** `~/.claude/projects/<slug>/memory/MEMORY.md` exists and lists 44 files. Memory paths that name the old machine's folders are historical; this skill is the current method.

## 9. The seat and the engine

**Design:** the Mac mini is the seat, the MacBook Pro is the engine, and there is one copy of the repo, on the engine.

### 9.1 One tree, same path on both machines
1. On the engine, turn on **File Sharing** (System Settings, General, Sharing) and share `~/Coding` to the owner's account.
2. On the seat, mount it: `open smb://<engine-host>.local/Coding` (Finder keeps the login in the keychain), or `mount_smbfs` with the same share (see `man mount_smbfs`). It appears under `/Volumes/Coding`.
3. Make the repo path identical on both machines. If both accounts share a user name: `ln -s /Volumes/Coding/glassvow /Users/<user>/Coding/glassvow` (move any local copy aside first). If the user names differ, create the engine's path on the seat (`sudo mkdir -p /Users/<engine-user>/Coding` then the same symlink) and open Claude from that path, so every absolute path in briefs and worktree `.git` files works unchanged.
4. Open Claude from the symlinked path. If `~/.claude/projects/` shows a slug built from `/Volumes/...` instead, Claude resolved the link: move the memory into that slug.

### 9.2 Every shell command on the engine
1. Add an ssh alias for the engine (default name `mbp`) in the seat's `~/.ssh/config`, key-based, so `ssh -o BatchMode=yes mbp true` succeeds with no prompt. Override the alias with `GLASSVOW_ENGINE_HOST`.
2. Link the wrapper onto the seat's `PATH`: `ln -s <repo>/.claude/skills/glassvow-orchestrator/references/mbp.sh ~/bin/mbp` (any `PATH` directory).
3. Use it for everything that is not a file read or edit: `mbp git status`, `mbp -c 'git log --oneline | head'`, `mbp godot --headless -s res://tests/run_all.gd`, `mbp gh pr view 123`, `mbp zsh <repo>/.claude/skills/glassvow-orchestrator/references/housekeeping.sh`, devicectl, the iPad lock, `qa_export.sh`, NAS archives, and `rg` or `grep` over the tree (faster than over SMB). It runs in the seat's current directory on the engine, streams output and keeps the exit code (255 means ssh failed).
4. **Never run git over SMB** (index locks, speed), and never run git, Godot or the test suite on the seat.
5. Before a session's work: `mbp --where` prints `seat` or `engine` (it compares `scutil --get LocalHostName` on both), and `mbp --check` (run from the repo) proves the engine is reachable and the mounted tree is the engine's tree.

### 9.3 Engine host checklist
- **Remote Login** on (System Settings, General, Sharing), with the seat's public key in the engine's `~/.ssh/authorized_keys`.
- **File Sharing** on, for SMB.
- **No sleep on AC power:** `sudo pmset -c sleep 0` (and `disksleep 0`), or keep a `caffeinate -s` running in a tmux session.
- **After a reboot** the login keychain is locked and codesign fails (errSecInternalComponent). Unlock it over ssh with `ssh -t mbp security unlock-keychain ~/Library/Keychains/login.keychain-db` typed by the owner, or ask the owner to unlock it at the machine. Agents never handle the password.
- **The iPad stays cabled** to the engine; the lock and QA flow live there.
- **ks2 (Spelling Camp) also uses this Mac:** the load, disk and iPad-lock rules in SKILL.md section 4 apply on the engine.
- **The mount can drop after sleep.** `mbp --check` fails with "not visible here" or "differs"; remount with `open smb://<engine-host>.local/Coding` and check again.
- A long engine job that must outlive the ssh connection runs under `tmux` or `nohup` on the engine, writing to the lane folder.

### 9.4 Caveats
- SMB is slow for many small file reads; prefer `mbp rg ...` for searching and read only the files you need.
- Godot's `.godot` import cache lives on the engine. Never open the project in a Godot editor on the seat.
- The session transcripts and the scratchpad live on the seat. Engine output meant to be kept, or viewed with the Read tool (captures, logs), is written inside the lane folder under `<repo>/.claude/worktrees/`, which the seat sees through the mount.
- Deletes follow the lane rules and run on the engine via `mbp`, never through the mount.

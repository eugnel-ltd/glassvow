# Cloud environment contract

This is the setup and capability contract for a cloud session. It applies to Claude Cloud and other isolated cloud checkouts. Local Mac setup stays in `.claude/skills/glassvow-orchestrator/references/machine-setup.md`.

## Select the execution mode

Use the session's known environment, not the presence of an arbitrary provider variable. A cloud launcher or the session sets `GLASSVOW_EXECUTION_MODE=cloud`; the seat/engine launcher sets `local`. Then run this from the checkout:

```bash
export GLASSVOW_EXECUTION_MODE=cloud
sh .claude/skills/glassvow-orchestrator/references/execution-mode.sh
```

The check prints exactly `cloud` or `local`, and fails if unset or unsupported. It does not contact a local machine. In local mode, use `mbp.sh --where` to distinguish seat from engine and `mbp.sh --check` on the seat. Cloud mode runs shell commands directly in its own checkout and branch; independent lanes need separate checkouts or worktrees, with no fixed parent directory. Do not call `mbp.sh`, NAS or Mac housekeeping tools in cloud mode. The local shared-Mac load threshold, 100 GB disk floor and device lock do not apply to the cloud host; respect the cloud host's actual resources.

## Confirm the toolchain before changing it

Required: Git with Git LFS, Python 3.10+ and Godot **4.7.2 stable**, the CI baseline (`chickensoft-games/setup-godot@v2`, `version: 4.7.2`, `use-dotnet: false` in `.github/workflows/ci.yml`). The normal Godot skill permits newer stable engines unless the active protocol pins an exact version. Core tests need no Python packages beyond the standard library.

```bash
git lfs version
python3 --version
command -v godot
godot --version
```

Check the session's provisioned-tool manifest or setup notes as well as `PATH`: a correct provisioned engine may exist outside `PATH`. Prepend its bin directory and confirm the version; do not replace it. An older or pre-release binary is not valid proof. If no supported engine is provisioned, install the CI baseline in a task-owned tools directory. For Linux x86_64:

```bash
mkdir -p work/toolchain/godot
curl --fail --location --output work/toolchain/godot.zip \
  https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
python3 -m zipfile -e work/toolchain/godot.zip work/toolchain/godot
chmod +x work/toolchain/godot/Godot_v4.7.2-stable_linux.x86_64
ln -s Godot_v4.7.2-stable_linux.x86_64 work/toolchain/godot/godot
export PATH="$PWD/work/toolchain/godot:$PATH"
godot --version
```

For a different host architecture use the matching official 4.7.2 stable asset, not the x86_64 binary. Missing system tools or libraries use the cloud image's package manager; on Ubuntu the bootstrap packages are `git-lfs python3 python3-venv curl unzip libfontconfig1 libx11-6 libxcursor1 libxinerama1 libgl1 libxi6 libxrandr2`. Do not alter a working provisioned toolchain. A blocked download or missing permission is a concrete setup blocker, never a reason to run an old engine.

Install Python extras only for the selected tool, in a task-owned virtual environment: `python3 -m venv work/venv`, then `work/venv/bin/python -m pip install ...`. CI uses `'fonttools[woff]>=4.63,<4.64'` for font coverage and `'Pillow>=10,<13'` for map asset checks; balance modelling uses `-r tools/requirements-balance-f2.txt`. Headed Linux captures additionally need `xvfb` and `libgl1-mesa-dri`. Native signing and the patched iOS bake editor are local-only capabilities.

## Isolate, import and test

Before importing or running the project, create an untracked `override.cfg` in the checkout with this complete block (replace `<lane>` with the lane name):

```ini
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="glassvow-<lane>"
```

Keep the same isolation beside any exported pck or second engine binary that reads its override there. Never touch a real profile. Initialise LFS and fetch objects before import when the checkout contains LFS pointers:

```bash
git lfs install --local
git lfs pull
tools/check_imports.sh
godot --headless -s res://tests/run_all.gd
```

`check_imports.sh` runs the fresh `godot --headless --import` and checks both status and import diagnostics. Grade the suite by exit 0 and its `PASS (N tests)` line. Record the exact product head, engine version, commands, exit codes and log location. A long job writes its log under `work/`; keep required evidence on the issue or PR before the ephemeral checkout expires. Run other gates only when the changed surface selects them.

## Hand off a local-only step

The cabled iPad QA flow and device reads, NAS, art lanes' local `generate.py` image-generation service, keychain/signing, TestFlight/store uploads and self-hosted runner administration need the local machines. Cloud cannot claim those steps passed. Stop that step, search for an existing issue for the same outcome, and add or update a `needs-local-machine` handoff containing the exact head, command or procedure, required machine/capability, expected proof, and available cloud evidence. The orchestrator owns tracker writes for delegated lanes. Continue independent cloud work. A handoff preserves the unmet acceptance; it does not close it. See `docs/agents/triage-labels.md`; #742 and #749 are initial examples. If tracker access is unavailable, report the complete handoff to the orchestrator instead of claiming an issue was written.

## Keep new large binaries in LFS

New binary art, video and binary datasets use Git LFS, never ordinary git blobs. Existing binary markers in the root `.gitattributes` do not enable LFS. Before staging a new binary, use a narrow path or directory pattern, for example `git lfs track 'research/my-study/*.mp4'`; stage that `.gitattributes` with the asset, and confirm `git check-attr filter -- <asset>` reports `lfs` and `git lfs ls-files` lists it. Do not migrate existing history or broadly retrack vendored/runtime assets as part of a lane. Keep generated intermediates under `work/` out of commits.

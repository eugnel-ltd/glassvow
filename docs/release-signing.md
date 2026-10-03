# Release Signing & Store Builds

How a signed store build of Glassvow is produced on this machine, and where
every credential lives. Set up interactively by `scripts/store_signing_wizard.sh`
(re-runnable; stages skip work already done). Requirements background:
`docs/research/2026-08-13-store-compliance-dossier.md` (wayfinder #162);
this pipeline is wayfinder #165.

## Toolchain (all pinned)

| Piece | Where | Why this one |
|---|---|---|
| Godot 4.7.2.stable | `godot` on PATH | engine pin (SKILL.md §1) |
| Export templates 4.7.2 | `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` — must contain `ios.zip`, `android_source.zip`, `android_debug.apk`, `android_release.apk`; the selected mobile, macOS and no-thread web templates were installed 2026-08-21 from the checksum-verified official `.tpz` | must match engine version exactly |
| **iOS template: local 4.7.3-rc build (since build 11, 2026-09-30)** | `export_templates/4.7.2.stable/ios.zip` is the official 4.7.2 zip with its device release slice (`libgodot.ios.release.xcframework/ios-arm64/libgodot.a`) replaced by a `scons platform=ios target=template_release arch=arm64 vulkan=no metal=yes` build of the Godot `4.7` branch at `83dec14` (4.7.3-rc, 2026-09-20) from `~/Coding/godot-4.7`; the official zip is kept beside it as `ios.zip.4.7.2-official`, and the zip carries `GLASSVOW-TEMPLATE-NOTE.txt`. The exported binary reports `Godot Engine v4.7.3.rc.custom_build` | Godot 4.7.2's Forward Mobile scene shader exceeds the 16 samplers per stage that Apple5/Apple6 GPUs allow under classic Metal binding, so every shaded 3D material fails to build its pipeline on the iPad 8 (A12): the map landscape and the enemy's shaded glass vanish. Fixed upstream by godot PR #121404 (remove AreaLight3D samplers), cherry-picked for 4.7.3. Reproduce on the Mac in seconds: `GODOT_MTL_DISABLE_ARGUMENT_BUFFERS=1 tools/shot.sh --rendering-driver metal --onboard=map-select --seed=1 --shape=pad --shot=/tmp/x.png` prints `Error compiling shader SceneForwardMobileShaderRD:…: 'sampler' attribute parameter is out of bounds`. Switch back to the official template when 4.7.3-stable ships and re-run that check |
| JDK 17 (Temurin 17.0.20) | `~/.local/share/jdk-17/Contents/Home`, wired into Godot's `export/android/java_sdk_path` editor setting | Godot 4.7's gradle template runs Gradle 8.11.1, which rejects JDK >23 ("Unsupported class file major version 69" on the machine's JDK 25); docs pin OpenJDK 17 |
| Android SDK | `~/Library/Android/sdk` (platform android-36, build-tools 36.0.0) | Play requires target API 36 from 2026-08-31 |
| Xcode 27.0 (27A266a) | `/Applications/Xcode.app`; a 27.0 beta also sits at `/Applications/Xcode-27.0-beta.app` and `xcode-select` points at the beta, so every store command below sets `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` | App Store uploads must be built with a release SDK; a beta-built upload is rejected |
| Android gradle template | `android/` (gitignored, machine-local) | reinstall any checkout: `mkdir -p android/build && unzip -o ~/Library/Application\ Support/Godot/export_templates/4.7.2.stable/android_source.zip -d android/build && echo 4.7.2.stable > android/.build_version && touch android/build/.gdignore` — the wizard's preflight does this automatically |
| Sentry for Godot **2.1.1** | `addons/sentry` ([release](https://github.com/getsentry/sentry-godot/releases/tag/2.1.1), tree `d288ad9`) | crash reporting on iOS store + Dev Review; do not follow `latest`. Client DSN lives in `project.godot` `[sentry]`; privacy-minimal (`attach_log=false`). Android Gradle injection is a later wave |

**4.7.2 template install receipt (2026-08-21):** the official
`Godot_v4.7.2-stable_export_templates.tpz` matched its published SHA-512,
`ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079`.
The selected iOS, Android, macOS and no-thread Web templates are installed
under the 4.7.2 directory; the old 4.7.1 directory remains available only for
replaying historical evidence.

## Credentials — where they live

- **Play upload keystore**: `~/Library/Application Support/Godot/keystores/glassvow-upload.keystore`
  (alias `glassvow-upload`, RSA 4096, 10,000-day validity; store pass == key
  pass, alphanumeric — a Godot requirement). Password lives in the password
  manager only, **never on disk**. Play App Signing holds the real app key;
  this upload key is resettable via a Play Console help form if lost.
- **Apple Team ID**: `application/app_store_team_id` in `export_presets.cfg`
  (not secret; committed).
- **Apple distribution cert + provisioning profile**: minted and stored by
  Xcode automatic signing (Keychain); nothing to manage by hand.
- **`export_credentials.cfg`**: written by the Godot editor if keystore fields
  are ever filled in the Export dialog; gitignored along with `*.keystore`.

### Sentry operator access

**Decision (2026-08-21):** Codex has a full-access Sentry Personal Token for
Glassvow operations. The Sentry record is named `Glassvow Codex Full Access` and
has the maximum permissions offered by the Personal Tokens UI: Project, Team,
Release, Issue & Event, Organization and Member are **Admin**; Alerts is
**Read & Write**. The resulting scopes are:

```text
alerts:read alerts:write event:admin event:read event:write member:admin
member:read member:write org:admin org:integrations org:read org:write
project:admin project:read project:releases project:write team:admin
team:read team:write
```

Sentry Personal Tokens have no project selector. The credential is therefore
technically organization-wide even though its operating boundary is Glassvow:

```text
SENTRY_ORG=pgnetwork
SENTRY_PROJECT=glassvow
SENTRY_BASE_URL=https://sentry.io
```

Godot release exports arrive in Sentry as environment `export_release`, not
`prod` or `production`. Pass `--environment export_release` explicitly to the
read-only Sentry helper; relying on its `prod` default hides live release
issues. `GLASSVOW-1` exposed this distinction on 2026-08-21.

On James's Mac the token value is stored in macOS Keychain, service
`codex-sentry-glassvow-full-access`, account equal to the local macOS user. It
is not stored in this repository. The mode-`0600` loader
`~/.config/glassvow/sentry.sh` exports the three defaults above and reads
`SENTRY_AUTH_TOKEN` from Keychain at runtime:

```bash
source ~/.config/glassvow/sentry.sh
```

Full credential scope does not broaden the task boundary: use it only against
the `glassvow` project. Credential possession records capability, not standing
approval for an unrelated project or an unrequested production mutation. Never
print the token, paste it into issues/evidence, write it to a repo `.env`, or
commit it. A Cloud Agent has no access to this Mac's Keychain; provision its
secret environment separately when that execution surface is intentionally
used.

To rotate, create the replacement first, update the same Keychain service with
`security add-generic-password -U`, verify one authenticated Glassvow request,
then revoke the superseded Sentry token. This avoids an observability gap.

## Export recipe

Presets live in `export_presets.cfg`: `iOS` (project-only export) and
`Android (Play AAB)` (gradle build, AAB, target SDK 36, arm64-v8a only — all
four floor devices are 64-bit). Godot does not create target folders:
`mkdir -p build/android build/ios` first.

**Android dev build** (debug keystore, auto-configured):

```bash
godot --headless --export-debug "Android (Play AAB)" build/android/glassvow-dev.aab
```

**Android store build** (signed with the upload key; password prompted from the
password manager — the env vars keep it out of shell history and repo files):

```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/Library/Application Support/Godot/keystores/glassvow-upload.keystore" \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=glassvow-upload \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<from password manager> \
  godot --headless --export-release "Android (Play AAB)" build/android/glassvow.aab
jarsigner -verify build/android/glassvow.aab
```

Bump `version/code` in the Android preset before every Play upload. Play's
upload screen re-verifies the target API level (must read 36).

**iOS store build** (Godot signs nothing; Xcode does). The shipping iOS
family is iPhone **and** iPad — both iOS presets already emit Apple
`TARGETED_DEVICE_FAMILY = "1,2"` from Godot enum `2` (see the tethered
path below). Release order note: Android is deferred — it ships after
the iOS release, before desktop/Steam (map #156 decision, 2026-08-13) —
so iOS is the release path that matters now.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
mkdir -p build/ios
godot --headless --export-release "iOS" build/ios/glassvow.ipa   # emits build/ios/glassvow.xcodeproj
# archive UNSIGNED (verified headless 2026-09-30, build 6); -exportArchive signs everything:
xcodebuild -project build/ios/glassvow.xcodeproj -scheme glassvow \
  -destination "generic/platform=iOS" archive \
  -archivePath build/ios/glassvow.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
# sign with Apple Distribution through the team API key + export the .ipa:
xcodebuild -exportArchive -archivePath build/ios/glassvow.xcarchive \
  -exportPath build/ios/export \
  -exportOptionsPlist scripts/ios_export_options.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_<key-id>.p8 \
  -authenticationKeyID <key-id> -authenticationKeyIssuerID <issuer-id>
# verify, then upload (asc reads ASC_KEY_ID / ASC_ISSUER_ID / ASC_PRIVATE_KEY_PATH from the environment):
codesign --verify --deep --strict build/ios/export/Payload/glassvow.app 2>/dev/null || true
asc builds upload --app io.fol2.glassvow --ipa build/ios/export/glassvow.ipa
asc builds list --app io.fol2.glassvow --build-number <n>   # processingState VALID before testers see it
```

Why the archive is unsigned: Xcode's automatic development signing picks the
first matching "Apple Development" identity across every keychain in the
search list, and on this Mac those identities live in locked per-agent
keychains (`octomiser-agent`, `octomiser-independent-166`), so `codesign` fails
with `errSecInternalComponent`; forcing another identity trips the
"conflicting provisioning settings" check, and manual signing fails because
the managed wildcard profile does not include the login keychain's
`iPhone Developer` certificate. Signing only at `-exportArchive` with the
Apple Distribution identity (login keychain) needs none of that. The login
keychain must be unlocked for this process tree (`security unlock-keychain`),
and its keys pre-authorised once with `security set-key-partition-list -S
apple-tool:,apple: -s`; hand the password over in a 0600 temp file that is
deleted after use, never on the command line.

`scripts/ios_export_options.plist` keeps `method = app-store-connect`,
`teamID = V45S7U2LZB`, and `signingStyle = automatic`. It also pins
`manageAppVersionAndBuildNumber = false` so App Store Connect cannot rewrite
the tracked marketing version and build number (currently **1.0.0 (18)**; TestFlight already holds 1–17), and
`uploadSymbols = true` so a direct
App Store Connect upload includes symbols. With `destination = export`, retain
the archive's `dSYMs/` for the later Apple and Sentry symbol-upload steps; dSYMs
are not embedded in the IPA.

Headless, `-exportArchive` alone fails with **"No Accounts"** (the CLI can't
reach Xcode's Apple ID session). The working path — verified 2026-08-13, it
produced a distribution-signed `glassvow.ipa` (Team V45S7U2LZB, full Apple
chain) — authenticates with the existing App Store Connect **team API key**:
append `-authenticationKeyPath` / `-authenticationKeyID` /
`-authenticationKeyIssuerID` to the `-exportArchive` command above. The `.p8`
lives under `~/.appstoreconnect/private_keys/`; its key + issuer IDs are in
`~/.appstoreconnect/octomiser-api-key.json` (a team-wide key, first created
for Octomiser's TestFlight uploads — IDs deliberately not reproduced here:
public repo). The same key later serves upload/TestFlight automation.

## One-script release

`scripts/ios_release.sh` runs the whole TestFlight route above in one go: export,
unsigned archive, Apple Distribution export, development export, iPad install,
`asc` upload, Sentry dSYMs, a wait for processing, and attach to the beta group.
It was proven end to end on 2026-10-01 (TestFlight 1.0.0 build 11). The manual
recipe above stays as the reference for what each step does and for debugging a
single step.

```bash
export ASC_KEY_ID=<key-id> ASC_ISSUER_ID=<issuer-id> \
       ASC_PRIVATE_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_<key-id>.p8
source ~/.config/glassvow/sentry.sh        # SENTRY_AUTH_TOKEN for the dSYM upload
scripts/ios_release.sh <build-number> <expected-main-sha> [--no-upload] [--no-device]
```

It refuses, before building anything, when HEAD is not `<expected-main-sha>`,
when the tree is dirty (the machine-local `.wrangler/` folder is tolerated),
when `application/version` in the **`iOS`** preset of `export_presets.cfg` is
not `<build-number>`, when any of the three `ASC_*` variables is missing, or
(without `--no-device`) when the iPad is not known to `devicectl`. Bump and
commit the pin first, merge, then run from a clean `main`. `--no-upload` stops
after the signed App Store `.ipa` (no `asc`, Sentry, wait or attach);
`--no-device` skips the development export and the iPad install.

Preconditions (the script cannot satisfy these for you):

- **Login keychain unlocked** for this process tree, with its keys pre-authorised
  once (see "Why the archive is unsigned" above). A locked keychain fails the
  export step.
- **Patched iOS template** installed, the 4.7.3-rc device slice described in the
  "iOS template" row of the toolchain table. The script prints
  `GLASSVOW-TEMPLATE-NOTE.txt` and the engine version string found in the
  archived binary; a release engine should read `Godot Engine v4.7.3.rc.custom_build`
  until 4.7.3-stable replaces it, so check that line before trusting the build.
- **iPad 8 tethered, unlocked and trusted** (`tunnelState: connected`; see the
  tethered-device section). The device UDID is read from `IOS_DEVICE_UDID`,
  which lives only in the operator's shell (take it from
  `xcrun devicectl list devices`). The repository is public, so no UDID is
  committed anywhere and the script has no default: without it the run refuses
  before building, unless `--no-device` is given.
- Xcode 27.0 release at `/Applications/Xcode.app` (override with `DEVELOPER_DIR`),
  and `godot`, `asc` and `sentry-cli` on `PATH`. `sentry-cli` must be
  authenticated (`SENTRY_AUTH_TOKEN`, see above); the script checks it with
  `sentry-cli info` before building, so a missing token cannot abort the run
  after the TestFlight upload.
- `pip install pyjwt cryptography` for the group-attach step, which is
  `scripts/asc_attach_build.py` (an ES256 JWT, then a POST to the beta group's
  builds relationship). ASC also answers 409 for a build in an invalid state or
  missing compliance, so on a 409 the script lists the group's builds and
  succeeds only if the build id is already there; otherwise it prints the error
  body and fails.

Where things live. Credentials are only ever read from the environment; the key
and issuer IDs are not in the repository. The numeric App Store Connect app id
(`ASC_APP_ID`) and the internal beta group id (`ASC_BETA_GROUP_ID`) are defaults
in the script header, overridable from the environment; that header is their
single source. `scripts/ios_export_options_development.plist` holds the
development signing pin for the iPad install: manual signing with the Apple
Development certificate's SHA-1 fingerprint and the profile name
`Glassvow device QA 2026-09-30` for `io.fol2.glassvow`. A fingerprint and a
profile name are identifiers, not secrets (the private key stays in the
keychain). When the profile is regenerated or the certificate renewed, update
both values in that file.

Output: every step logs to `build/ios/logs/<step><build-number>.log` (gitignored
with the rest of `build/`, kept between runs; the rest of `build/ios` is wiped
at the start of each run). The closing summary prints the `.ipa` SHA-256, the
engine version string, the iPad install result, the App Store Connect build id
and the group-attach status. The script exits non-zero (2) when the iPad install
fails, App Store Connect reports the build `INVALID`, processing does not reach
`VALID` within `PROCESSING_POLL_LIMIT` polls (default 60 at 45 s), or the group
attach is refused.

## iOS build on a tethered device — the measurement path, not the store path

Performance tickets need a `dev_tools` build running on real hardware (#233
measures the map scene on iPad 8). That is a **different route** from the store
recipe above and the two must not be confused: `scripts/ios_export_options.plist`
declares `method = app-store-connect`, which produces an artifact that cannot be
installed on a tethered device. It is not needed here at all — Godot's own
`--export-debug` writes a `glassvow/export_options.plist` next to the project
with `method = development` and the team already filled in.

Verified end to end on this machine, 2026-08-14, against an iPhone 16 Pro Max:

```bash
mkdir -p build/ios-dev                       # Godot will not create it
godot --headless --export-debug "iOS Dev Review" build/ios-dev/glassvow.ipa
xcodebuild -project build/ios-dev/glassvow.xcodeproj -scheme glassvow \
  -configuration Debug -destination 'id=<devicectl identifier>' \
  -allowProvisioningUpdates -derivedDataPath build/ios-dev/dd build
xcrun devicectl device install app --device <devicectl identifier> \
  build/ios-dev/dd/Build/Products/Debug-iphoneos/glassvow.app
```

`xcrun devicectl list devices` gives the identifier. Signing needs no new
profile: automatic signing picked `Apple Development: James TO` under the
wildcard `iOS Team Provisioning Profile: *`, and **BUILD SUCCEEDED** without a
portal visit.

Three things that will stop you:

- **Do not confuse Godot's family enum with Apple's.** Both iOS presets
  (`iOS` store and `iOS Dev Review`) set
  `application/targeted_device_family=2`. That is Godot's INT enum for
  **iPhone & iPad** (hint: `iPhone,iPad,iPhone & iPad`; default 2). The
  exporter writes Xcode `TARGETED_DEVICE_FAMILY = "1,2"`. Apple's family
  `2` is iPad-only; Godot's enum `1` is the iPad-only value. Writing the
  Apple string `1,2` into that INT field is out of range and can emit an
  empty family (godotengine/godot#122262). A store-recipe IPA already
  installs on a phone; do not append `TARGETED_DEVICE_FAMILY="1,2"` at
  `xcodebuild`.
- **The device must be tethered and unlocked.** A Wi-Fi-paired device reports
  `available (paired)` from `devicectl list devices` while
  `tunnelState: disconnected` and `tunnelIPAddress: nil`; installing then fails
  with `com.apple.dt.CoreDeviceError error 4`. Check `tunnelState` before
  blaming the build.
- **`IPHONEOS_DEPLOYMENT_TARGET` is 15.0, which is below the renderer's floor.**
  `project.godot` selects the Mobile renderer, whose documented minimum is
  iPadOS 16 + Metal 3 (see the mobile performance-floor research note). The app
  therefore *installs* on an OS where the renderer is not supported, and it will
  produce numbers that look valid. Read the OS version off the device before
  trusting any measurement taken on it.

Benches launch through `main.gd` user-arg routes (`--map-bench`, `--perf-out=`),
never `-s`: measured 2026-08-14 on iPad 8, the iOS release template silently
ignores `-s` both as a `devicectl` launch argument and via the Info.plist
`godot_cmdline` array — the app boots `main.tscn` either way — while generic
options from the same array (`--log-file`, `--verbose`) are honoured. The
working recipe: set `godot_cmdline` to
`["--log-file","user://bench.log","--","--map-bench"]` in the generated
project's Info.plist (plutil, then rebuild — the exporter regenerates the plist
on every export), and pull the log with
`xcrun devicectl device copy from … --domain-type appDataContainer
--domain-identifier io.fol2.glassvow --source Documents/bench.log`, since
`print()` output never reaches `devicectl --console` (also measured; `user://`
maps to `Documents/`).

Use `--export-debug` only to rehearse the plumbing. Timings for a ticket must
come from `--export-release`: the debug engine slice is a different binary, and
`tools/bench_map_scene.gd` stamps a DEBUG BUILD warning across its own output to
stop a rehearsal run being pasted in as evidence.

## Store accounts

Apple Developer Program (US$99/yr) and Play Console (US$25 one-time) are
walked through by wizard stages 2–4, including identity verification, the
payments profiles, and the EU DSA trader notes. Compliance detail and
deadlines: the store-compliance dossier.

# Privacy policy drafts (issue #415, text slice)

**Status: draft for James, written 2026-09-29 against `main` at `9f14e5db`.** Part of [#415](https://github.com/fol2/glassvow/issues/415); it does not close it. Nothing here is hosted, entered in App Store Connect or shipped in the app, and none of it is legal advice or a compliance finding.

Every practice described comes from this repository's configuration and source, and from the pinned Sentry sources (sentry-godot 2.1.1, sentry-cocoa 9.24.0). None of it has been observed in a live payload. The tethered-device check still owed on #420 is what turns "configured" into "observed".

| File | Purpose |
|---|---|
| `privacy-policy.en.md` | English policy (UK English) for the App Store listing and the future in-app link |
| `privacy-policy.zh-Hant.md` | Traditional Chinese policy in Hong Kong written register (書面語): same meaning, not a literal translation |
| `README.md` | this note |

Both policies cover Glassvow on iPhone and iPad, as built by the store preset `iOS`. The Android wave will need its own Play Data safety mapping and a policy revision.

## 1. Decisions that change the policy text or the App Privacy answers

**D1. Consent and withdrawal (Apple guideline 5.1.1(ii)).** Sentry starts on every launch outside the editor. There is no first-run notice and no setting to turn it off, so both policies say in section 5 that there is no setting rather than claim otherwise. Apple's text: "Apps that collect user or usage data must secure user consent for the collection, even if such data is considered to be anonymous … Apps must also provide the customer with an easily accessible and understandable way to withdraw consent." `docs/rc-bar.md` (P7) asks for "a consent posture per Apple 5.1.1(ii)", but the repository does not define one, so this is your call.

| Option | What it means | Cost |
|---|---|---|
| A. Opt-in | First-run card; diagnostics stay off until accepted; switch in Settings | Strictest reading of 5.1.1(ii). You lose crash data, and the P8 crash-free-sessions rate, from everyone who declines |
| B. Notice plus off switch | One-line notice; switch in Settings, on by default | Common practice, but weaker than the letter of 5.1.1(ii) |
| C. Disclosure only (as built) | Policy and App Privacy answers only | Weakest. This draft describes it |

A and B need code, and they change section 5. The switch has to be read from `user://settings.cfg` by the main loop, because Sentry is initialised there before `Main` loads `Preferences`. My recommendation is B as the minimum, and A if you want no review risk on this point. If you pick B, replace the sentence "The game currently has no setting to switch diagnostics off." with:

- English: "You can switch diagnostics off at any time in Settings. Reports already sent are deleted automatically after the period above."
- 繁體中文：「你可隨時在「設定」中關閉診斷資料。已傳送的報告會在上述期限屆滿後自動刪除。」

**D2. Session records.** sentry-cocoa's automatic session tracking is on by default and sentry-godot 2.1.1 does not override it, so each play session also sends a session record (start, duration, ended normally or crashed, release) keyed to the random ID. That is app-launch data, and "app launches" is Apple's own example for Usage Data: Product Interaction, so the table below declares it. The alternative is to switch session tracking off in the follow-up code slice and answer No, but `docs/rc-bar.md` P8 asks for the crash-free-sessions rate, which needs those records. I recommend keeping them and declaring them.

**D3. Sentry project settings (only you can see or change these).**

1. Turn on "Prevent Storing of IP Addresses" (project, Security & Privacy). By the SDK source the app already sends `infer_ip: never`, because `send_default_pii` is off. But the Cocoa source contains a stale comment saying the opposite (see section 6), so this setting is the belt to those braces and is Sentry's documented way to stop IP storage.
2. Confirm the organisation's Data Storage Location says EU. The DSN host is the EU ingest host, and both policies say Frankfurt, Germany, which is what Sentry documents for EU storage.
3. Confirm the plan. Sentry's retention page lists errors at 30 days (Developer) or 90 days (Team, Business, Enterprise), so "up to 90 days" holds either way. It publishes no period for release-health data, which is why the policies defer to Sentry's policy for session summaries.

**D4. "Linked to user" for the installation ID.** The table answers No throughout (note 1). Apple counts "Personal Data" under privacy laws as linked, and a persistent per-installation ID may be personal data under the GDPR, so this is the weakest answer exactly where Apple's rule bites. I have made no legal finding. Decide it on purpose: if you or counsel read it the other way, answer Yes for Device ID and for the Diagnostics rows that carry it, and say so in the policy.

## 2. App Store Connect "App Privacy" answers

Top-level questions: **Do you or your third-party partners collect data from this app? Yes.** **Is any of it used for tracking? No.** Apple defines tracking as linking your data with third-party data for targeted advertising or advertising measurement, or sharing it with a data broker. Nothing in source does either, and Sentry states it does not use data to track users.

| Apple data type | Collected? | Linked to user? | Used for tracking? | Purposes | Justifying source (files) |
|---|---|---|---|---|---|
| Diagnostics: Crash Data | Yes | No (note 1) | No | App Functionality | `project.godot` `[sentry]`; `application/sentry_loop.gd`; Sentry Cocoa manifest under `addons/sentry/bin/ios/` (pinned by `tests/test_sentry_release.gd`) |
| Diagnostics: Performance Data | Yes | No | No | App Functionality | `project.godot` with `options/app_hang/tracking=true` and the 5 s default threshold; Cocoa extra context (memory, thermal state, battery); same manifest |
| Diagnostics: Other Diagnostic Data | Yes | No | No | App Functionality | non-fatal engine and script error events and breadcrumbs (`project.godot` `godot_logger/*`, `application/sentry_privacy.gd`); device, locale and time zone contexts; same manifest |
| Identifiers: Device ID | Yes (note 2) | No | No | App Functionality, Analytics (note 3) | random installation ID sent as the Sentry user id: sentry-godot `runtime_config.cpp` and `sentry_user.cpp`, sentry-cocoa `SentryInstallation.swift` |
| Usage Data: Product Interaction | Yes (D2) | No | No | Analytics, App Functionality (note 3) | session records: sentry-cocoa `Options.swift` default, `SentrySession.swift`, not overridden by sentry-godot `cocoa_sdk.mm` |
| Usage Data: Advertising Data; Other Usage Data | No | n/a | n/a | n/a | no advertising or analytics SDK (source search; `project.godot`) |
| Identifiers: User ID | No | n/a | n/a | n/a | no account or sign-in in source; Sentry user name and email are never set |
| Location: Precise; Coarse | No (note 4) | n/a | n/a | n/a | exported Info.plist has no location key (`docs/reviews/432/after-glassvow-Info.plist`); no location API in source |
| Contact Info; Contacts | No | n/a | n/a | n/a | no fields, no permission keys; Sentry's feedback form in `addons/sentry/user_feedback/` is never opened |
| User Content: Gameplay Content, Emails or Text Messages, Photos or Videos, Audio Data, Customer Support, Other User Content | No | n/a | n/a | n/a | saves stay in `user://` (`application/save_service.gd`, `application/preferences.gd`); Apple: data processed only on device is not "collected"; no network API in first-party code; no text entry; screenshot, log and scene-tree attachments are off |
| Purchases; Financial Info | No | n/a | n/a | n/a | no in-app purchase, StoreKit or other plugin option in `export_presets.cfg` |
| Health & Fitness; Sensitive Info; Browsing History; Search History; Surroundings; Body; Other Data | No | n/a | n/a | n/a | no such code or permission keys |

Also in App Store Connect: **Privacy Policy URL** is required, one per localisation (en and zh-Hant). **Privacy Choices URL** is optional; use it only if D1 adds a control. Apple's category names and wording drift, so re-read the live form at submission. The definitions above were read from Apple's [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) page on 2026-09-29.

**Notes on the judgement calls.**

1. **Linked = No.** Apple says data is linked unless it is de-identified before collection, and that "Personal Information" or "Personal Data" under privacy laws counts as linked. The events carry a random installation ID, but no account, name, email or IP-derived location, and nothing joins them to other data. Sentry's own manifest also says unlinked. This is a judgement, not a legal finding. It flips to Yes if you ever tie these events to an account, purchase or email address.
2. **Device ID.** Apple's definition is "the device's advertising identifier, or other device-level ID". The random ID is per installation, not the advertising identifier or the vendor identifier, but I declare it conservatively. Separately, Sentry's Cocoa crash recorder computes a SHA-1 `device_app_hash` from the vendor identifier, hardware model and bundle ID. I could not confirm from source that it reaches the uploaded payload in 9.24.0; the #420 payload check should look for it.
3. **Purposes.** Sentry's own manifest declares App Functionality only. Analytics is added for Device ID and Product Interaction because release health counts sessions and distinct installations, and Apple's Analytics definition includes "measure audience size". The 2026-08-13 crash-reporting note ticked both purposes on every row; I limited Analytics to the two rows where counting sessions or installations is the use. Drop Analytics if you treat the data purely as stability ("minimize app crashes" is Apple's App Functionality example).
4. **Location.** Language and region settings and the time zone are sent, but I treated them as diagnostics rather than location, because Apple's Coarse Location is about the location of the user or device (for example Approximate Location Services) and nothing here comes from a location service or from IP geolocation.

## 3. Hosting the two pages

The repository is public today (`fol2/glassvow`), and GitHub Pages is not enabled (the API returned 404 on 2026-09-29).

| Option | Effort | What only James can do |
|---|---|---|
| **1. GitHub Pages from this repo** | Medium: one small PR plus a setting. The default Pages build does not turn Markdown without front matter into web pages, and publishing all of `docs/` would expose the internal research and review packets, so use a workflow that publishes only `docs/privacy/`. A `.github/` change also triggers the fail-closed full CI gate in `tools/ci_scope.py`. URL shape, to confirm after enabling: `https://fol2.github.io/glassvow/…` | Enable Pages in the repository settings (admin) with source "GitHub Actions"; optionally point a custom domain at it |
| **2. Static page on a domain you already control** | Low to medium: convert each Markdown file to HTML once (for example with `pandoc -s`), upload under stable paths such as `/glassvow/privacy/en` and `/glassvow/privacy/zh-hant`, and repeat on every policy change | Hosting and DNS access; choose the URLs; keep the pages up, because App Review fetches them |
| **3. App Store Connect points straight at GitHub** | Minutes. Use the rendered file pages `https://github.com/fol2/glassvow/blob/main/docs/privacy/privacy-policy.en.md` and its `.zh-Hant.md` twin. `raw.githubusercontent.com` serves the Markdown as plain text, which reads badly. The URLs break if the files are renamed or the repository turns private, and each policy change needs a merged PR | Paste the two URLs into App Store Connect (one per localisation); decide whether a repository URL is acceptable on the listing; keep the repository public |

The in-app link (section 4) is compiled into the build, so the URL you choose now is the one every shipped build points at. If you want the fastest path, take option 3 and treat the two GitHub URLs as permanent: never rename the files. If you want to be able to move later without an app update, choose option 2 now, because a URL on your own domain can redirect anywhere. Either way, App Store Connect and the in-app link must use the same two URLs.

## 4. Next step (not done here): in-app link slice

**#415 slice 2: in-app privacy link (settings, en and zh-Hant).** Guideline 5.1.1(i) requires the policy link in the app "in an easily accessible manner" as well as in App Store Connect.

- A Privacy row in the settings panel (`presentation/run/settings_panel.gd`) that opens the locale-matched URL with `OS.shell_open`. This opens the browser and sends no app data, so it changes neither the policy nor the App Privacy answers.
- Locale keys in `locale/en.json` and `locale/zh-Hant.json` (for example `ui.settings.privacy`), with the term 私隱政策 added to `docs/zh-hant-glossary.md`; `tests/test_locale.gd` already enforces paired keys.
- The two URLs held in one place, identical to the App Store Connect values.
- If you pick D1 option A or B: a `Preferences` key, read by the main loop in `application/sentry_loop.gd` before `SentrySDK.init`, plus the first-run notice or card.
- Done when: both-locale in-app screenshots at the reference shapes, the live pages, App Store Connect readback of the policy URL and App Privacy answers, and the #420 payload evidence all agree on the same candidate. The local core gate in `CLAUDE.md` applies, because `presentation/`, `locale/` and `application/sentry_*` are production scopes.

## 5. Checklist for you

Placeholders (each appears in both policies; search for `[`):

- [ ] `[effective date]` and `[生效日期]`: the publication date (2 places).
- [ ] `[developer name, as shown on the App Store listing]` and `[開發者名稱，須與 App Store 上架資料所示一致]`: the seller name exactly as the listing shows it (4 places). No company name has been invented.
- [ ] `[contact email]` and `[聯絡電郵]`: a monitored address (8 places).
- [ ] Delete the HTML comment at the top of each policy.

Confirmations before publishing (facts I could not confirm from source):

- [ ] D1 to D4 above decided; the policy edited if D1 is A or B, or if D4 is Yes.
- [ ] Sentry organisation region is EU (Frankfurt) and the plan's retention is at most 90 days.
- [ ] "Prevent Storing of IP Addresses" turned on.
- [ ] Guideline 5.1.1(i) asks the policy to confirm that third parties give the same or equal protection. The draft states Sentry's own documented position (it processes reports to provide its service to you) and links Sentry's privacy policy. Add an explicit "equal protection" sentence only after checking the Sentry terms and data processing agreement on your account.
- [ ] `https://sentry.io/privacy/` still resolves.
- [ ] Both policy URLs and the App Privacy answers entered in App Store Connect, then read back.
- [ ] #420 device payload check done against sections 2 and 3 of the policy (see section 7).

Re-open this note when any of these change: the Sentry pin or any `[sentry]` option; a feedback form, account, advertising, analytics or in-app purchase appears; networking code appears (Cocoa's network breadcrumbs and failed-request capture are on by default); the Android wave starts; a consent switch ships; the export presets change.

## 6. What the shipped configuration does (evidence)

**In this repository.**

| Claim | Files |
|---|---|
| The only outbound connection is to Sentry's EU ingest host | `project.godot` `[sentry]` (host classified, not reproduced here). A source search of `application/`, `domain/`, `presentation/` and `content/` finds no network API. The only other GDScript networking code is the Funplay MCP editor plugin under `addons/`, which the store presets exclude in `export_presets.cfg` |
| Sentry starts unconditionally outside the editor; there is no consent or off switch | `application/sentry_loop.gd`; `application/preferences.gd` holds audio, display, motion and language only; `presentation/run/settings_panel.gd` and both locale files contain no privacy or diagnostics text |
| Privacy-minimal options: `send_default_pii=false`, `attach_log=false`, `attach_scene_tree=false`, `experimental/attach_screenshot=false`, `enable_logs=false`, `enable_metrics=false`, `godot_logger/include_variables=false`, `godot_logger/logs=0`, `godot_logger/breadcrumbs=15` (errors and warnings only, so `print()` output is excluded), app-hang tracking on | `project.godot` `[sentry]`, pinned by `tests/test_sentry_release.gd` |
| Error text is filtered before sending: `user://` paths stripped, save-shaped JSON replaced, 240-character cap, repeats of one non-fatal error capped at 8, editor events dropped. It applies to exception values and the event message, not to breadcrumbs, so the policies say the main error message is filtered and the trail of recent events is not. The `user://` rule matches only paths inside the game's own storage, and the save-shaped rule matches only a message that starts with `{` and contains `"seed"`, `"deck"` or `glassvow_run` | `application/sentry_loop.gd`, `application/sentry_privacy.gd` |
| Saves and settings are local files that the game never uploads | `application/save_service.gd` writes `user://glassvow_run_v2.json` and `user://glassvow_vigil_v2.json`; `application/preferences.gd` writes `user://settings.cfg` |
| No permission strings, no tracking-prompt key, no iOS plugin options | `export_presets.cfg` sets `modules/camera=false` and empty usage strings; `addons/glassvow_ios_export/`, `tests/test_ios_plist_privacy.gd`; the export recorded in `docs/reviews/432/` also has file sharing off. The export was not re-run for this draft |
| No text entry a player can reach, and no feedback form | text controls exist only in the developer console (`presentation/dev/`, excluded from the store presets), the card studio lab (`presentation/lab/`, packed but started only by the `--studio` command-line flag, and `export_presets.cfg` sets no `godot_cmdline`), and Sentry's own feedback form in `addons/sentry/user_feedback/`, which no first-party code references. The run seed is random, not typed |
| No accounts, advertising, analytics SDK or in-app purchase | source search; `export_presets.cfg` has no plugin options; `docs/commercial-game-delivery.md` treats in-app purchase as a separate deliverable |
| `ITSAppUsesNonExemptEncryption` is false | hard-coded by Godot's iOS template, not a preset field: `docs/reviews/432/evidence.md`, `docs/reviews/420/export-proof.md`. Not re-verified here |
| Sentry's own privacy manifest declares Crash, Performance and Other Diagnostic data, unlinked, no tracking, App Functionality | `addons/sentry/bin/ios/Sentry.xcframework/` (hash pinned in `tests/test_sentry_release.gd`); copy in `docs/reviews/420/` |
| What testers have been told | `docs/external-beta-playbook.md` says only "Crash telemetry (Sentry) in the build … No additional analytics; stay privacy-minimal", and that round is skipped. `docs/release-signing.md` records the pin and `attach_log=false` |

**Upstream, read at the pinned tags** ([sentry-godot 2.1.1](https://github.com/getsentry/sentry-godot/tree/2.1.1), commit `d288ad9`; [sentry-cocoa 9.24.0](https://github.com/getsentry/sentry-cocoa/tree/9.24.0)). These are SDK defaults the project does not override, so they are not visible in this repository.

| Claim | Upstream files |
|---|---|
| iOS init passes only DSN, release, dist, environment, sample rate, breadcrumb limit, PII flag, app-hang settings, logs and metrics to Cocoa; everything else keeps Cocoa's defaults | sentry-godot `src/sentry/cocoa/cocoa_sdk.mm` |
| Every event carries a random UUID as the user id, generated on first run and stored as `sentry.dat` in the user data directory; Cocoa keeps its own random installation ID in the caches directory | sentry-godot `src/sentry/sentry_user.cpp`, `src/sentry/runtime_config.cpp`; sentry-cocoa `Sources/Swift/Helper/SentryInstallation.swift`, `Sources/Sentry/SentryClient.m` |
| IP: the SDK does not send one, and by code sends `infer_ip: never` unless `send_default_pii` is on. A comment in `Options.swift` claims Cocoa defaults to `auto`, which contradicts the code; hence D3 and the payload check | sentry-cocoa `Sources/Swift/Helper/SentrySdkInfo.swift`, `Sources/Swift/Protocol/SentrySDKSettings.swift`, `Sources/Swift/Options.swift`; Sentry docs "Data Collected" for Apple and Godot |
| Sessions, watchdog-termination reports and automatic breadcrumbs are on by default; tracing, profiling, replay and MetricKit are off | sentry-cocoa `Sources/Swift/Options.swift`; Sentry docs "Releases & Health" (Godot) |
| Session payload: id, distinct id, start, duration, status, error count, release and environment | sentry-cocoa `Sources/Swift/SentrySession.swift` |
| Breadcrumbs: app foreground and background, battery level and charging, orientation, keyboard, time-zone change, "screenshot taken" (the image is not captured) | sentry-cocoa `Sources/Swift/Integrations/Breadcrumbs/SentrySystemEventBreadcrumbs.swift` |
| Device model, OS name, OS version and build, and CPU architecture are read by Cocoa | sentry-cocoa `Sources/Sentry/SentryDevice.m` |
| Extra device context: free memory, app memory, processor count, thermal state, low-power mode, orientation, charging, battery level | sentry-cocoa `Sources/Swift/Helper/SentryExtraContextProvider.swift` |
| Culture context: locale, calendar, 24-hour setting, time zone | sentry-cocoa `Sources/Sentry/SentryClient.m` |
| On iOS the Godot layer adds culture, GPU, display, engine and environment contexts, and a performance context on non-crash events | sentry-godot `src/sentry/contexts.cpp`, `src/sentry/sentry_sdk.cpp`, `src/sentry/processing/process_event.cpp` |
| Godot logger: default event mask is errors, script errors and shader errors; breadcrumb mask 15 excludes `print()` messages | sentry-godot `doc_classes/SentryGodotLoggerOptions.xml`, `src/sentry/logging/sentry_godot_logger.cpp` |
| `device_app_hash` is computed from the vendor identifier, hardware model and bundle ID | sentry-cocoa `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_System.m` |

Sentry documentation used: [data retention periods](https://docs.sentry.io/security-legal-pii/security/data-retention-periods/), [data storage location](https://docs.sentry.io/organization/data-storage-location/), [mobile privacy FAQ](https://docs.sentry.io/security-legal-pii/security/mobile-privacy/), [identify user](https://docs.sentry.io/platforms/godot/enriching-events/identify-user/) (Prevent Storing of IP Addresses). Apple: [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) and [App Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage). The 2026-08-13 dossier and crash-reporting note in `docs/research/` reached the same Diagnostics and Device ID answers, and this draft adds Product Interaction and the consent finding.

To repeat the repository searches: `git grep -nE "HTTPRequest|HTTPClient|WebSocketPeer|StreamPeerTCP|TCPServer|OS\.shell_open" -- application domain presentation content` and `git grep -nE "LineEdit|TextEdit|virtual_keyboard" -- application domain presentation content` (the hits are a theme definition in `presentation/combat/glass_style.gd`, the developer console and the command-line-only card studio), plus `git grep -n "Sentry" -- . ':!addons' ':!docs' ':!tests'` for every first-party Sentry call.

## 7. What I could not confirm

- **A live payload.** Nothing here was captured from a running build. The #420 device check (one GDScript error, one native crash, one hang) should be compared with sections 2 and 3 of the policy, looking specifically for `user.id`, `sdk.settings.infer_ip`, no `user.ip_address`, the culture and device contexts, breadcrumb content, the session envelope, and `device_app_hash`.
- **The full Cocoa device-context field list.** I traced the fields the policy names, but did not enumerate every field Cocoa puts in the `device` and `os` contexts (storage and boot time, for example, may be there). The policy's device bullet ends with "and similar technical details" for that reason; the payload check settles it.
- **How Sentry treats the connection IP for session envelopes**, and whether "Prevent Storing of IP Addresses" is already on.
- **The Sentry organisation's region, plan and data processing terms**, which live in your account.
- **The `iOS Dev Review` preset.** It is not a store build. It carries the same Sentry configuration plus developer tooling, and I did not audit its extra files.
- **Export compliance.** `ITSAppUsesNonExemptEncryption` was not re-checked against a fresh export, and nothing here is an export-compliance conclusion.

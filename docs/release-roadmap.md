# Glassvow 1.0 — iOS release roadmap

**Status:** active, written 2026-09-29 (Monday). Owner: James. Author: Claude (Fable 5.1). The owner delegated the reframing of the roadmap on 2026-09-29 ("full authority to re-frame the entire roadmap to release"). This document supersedes the sequencing in #156's delivery index and #421's programme disposition. It does not close any issue by itself; §7 lists the tracker actions.

**Product scope of 1.0.** Duskblade, playable to the shipped terminus in en and zh-Hant on iPhone and iPad, with the Flame and three discoverable ways ([design lock](design/2026-09-29-dusk-flame/README.md)). The Ashwarden is not exposed in 1.0 and returns in 1.1 with its own ways, built from the [class template](design/2026-09-29-dusk-flame/ways-template.md). The mythic set (#212) stays out of 1.0.

**The bar.** `docs/rc-bar.md` P0–P8 unchanged. P9 becomes the flame gates G1–G7 plus the human round H, carried by #549.

## 1. Principles

1. **Parallel lanes, one owner each.** Eight lanes below. No lane edits another lane's mutable files without a handoff.
2. **The mechanism is time-boxed.** Three weeks, with a written fallback. The readout is minutes, not hours; a decision waits for evidence, never for ceremony.
3. **Science is an instrument panel.** Every candidate gets a ten-minute readout the same day; humans play the candidate the same week; the exam runs once on the final SHA.
4. **Issues are outcomes.** One issue per lane where tracking is needed, reusing existing numbers. No per-experiment issues, no certificates, oracles, containment, custody or ledgers.
5. **James's time is the scarce resource.** His hands are needed for device evidence, feel and store administration; everything else is agent work. §6 lists the dates.
6. **Execution routing** follows `~/.claude/CLAUDE.md` of 2026-09-29: in-house Claude subagents (Sonnet for daily implementation, Opus for design and UI, Fable for the hardest problems), `Explore` for search, external CLIs only for an independent view.

## 2. Lanes

| Lane | Outcome | Owner | Inputs | Exit evidence |
|---|---|---|---|---|
| A. Flame, domain and science | Purity function, pool hygiene, recognition, like-calls-to-like, lantern knobs, simulator metrics, committed arms, readout tool | Claude subagent (Sonnet; Opus for `flame.gd` and the arms) | design lock §4–§8, §11–§12 | readouts 1–3; unit tests; core gate green |
| B. Flame, presentation | HUD lantern flame shader, reward and shop lanterns, later VFX tint | Claude subagent (Opus, design tier) | design lock §9 | stills on the reference shapes; James's approval on device |
| C. Edge way content | Seven cards, Crown of the Eclipse, the deed, art, locale | Claude subagent (Sonnet for content and tests; `image-gen` for card art) | design lock §6.2 | readout 4 on the exam candidate; locale and font coverage |
| D. Stagecraft assets and lines | #559–#564 portraits, plates, cues; the six flame lines and codex reveal | Claude subagent (Sonnet); `image-gen` / `grok-media` | Stagecraft README, design lock §10 | `test_stagecraft` green; contact sheet reviewed |
| E. Release engineering | #549 rc-bar amendment; #543 class exposure and campaign integration; #541 export pipeline dry run and twin; #415 privacy; #420 telemetry; #545 icon; #546 screenshots; #427 listing | Claude subagent (Sonnet; Opus for #549) | rc-bar, release-signing, existing #413 upload knowledge | each pillar's checklist item ticked with its evidence |
| F. Device pillars | #172 P2 performance, #414 P4 save integrity, #416 P3 full-run QA on both floor devices | James, with an agent preparing routes, scripts and packets | the internal TestFlight build (M3) | immutable evidence packets |
| G. Beta and feel | #195 beta logistics, #205 feel verdict, P6 round, P8 ledger | James and two or three players; agent triage | M3 build | debrief forms; feel verdict; ledger complete |
| H. Store and launch | #425 launch control, #427 listing, #428 submission, #429 verification | James for App Store Connect; agent for copy and checks | M5 RC | processed build; approved; storefront verified |

Dependencies: C depends on A's PR 2 (affinity schema). B depends on A's `FLAME` event. E's #543 depends on A–C's integration to `main`. F and G depend on M3. H depends on M5.

## 3. Milestones

Dates are targets under the assumptions in §8. A milestone is met by its evidence, never by the calendar.

| Milestone | Target | Exit evidence |
|---|---|---|
| M0 Lock merged | Tue 30 Sep | this roadmap, the lock and the template on `main`; #421 comment pointing at them |
| M1 Flame playable | Tue 30 Sep (pulled forward from Fri 10 Oct on the owner's word, 30 Sep) | macOS dev build with the flame in the HUD, reward, shop and event screens handed to James; readouts 1–6 posted; James plays when he can |
| M2 Mechanism GO or fallback | Fri 17 Oct | Edge content in; readout 7 (each way's own wall) shipped or dropped; G2, G3, G5, G6 and G7 met on the candidate SHA with G1 and G4 reported as instrument readings (owner decision, 30 Sep: the game may be hard, the pilot is not a human); James's runs (H) recorded; lines in |
| M3 Internal TestFlight | Fri 31 Oct | selected candidate integrated to `main`; #549 merged; #543 done; RC-shape export and twin; processed TestFlight build installed on iPhone and iPad with smoke evidence |
| M4 Beta closed, feel signed | Fri 14 Nov | P6 round survived; #205 verdict recorded; P8 ledger current; player-facing-major changes re-evidenced |
| M5 RC frozen and submitted | Fri 21 Nov | P0–P9 evidence on the exact RC commit; RC signature receipt; #428 submitted |
| M6 Live | Fri 5 Dec (buffer to Fri 12 Dec) | #429: public storefront verified in both locales |
| 1.1 Ashwarden lock | by Fri 19 Dec | class template applied; Ash lock reviewed |
| 1.1 Live | late Jan 2027 | same bar on the combined product; Duskblade claims carried or requalified |

## 4. Week by week

| Week | A Flame domain | B Flame screen | C Edge content | D Stagecraft | E Release eng. | F / G / H James |
|---|---|---|---|---|---|---|
| W1 29 Sep–3 Oct | PR 2: affinity, `flame.gd`, hygiene, stats, event, sim arms, readout 1 | shader spike on the lab | card sketches to numbers | #560–#564 generation starts | #549 draft; #545 icon; #415 policy text | decisions on readouts (30 min) |
| W2 6–10 Oct | PR 3 recognition and steering, readout 2; PR 4 knobs, readout 3 | HUD lantern flame on device shapes | PR 6 content and art | assets landing; six lines authored | #546 screenshots plan; #420 Sentry on device prep | Fri: play two runs (M1) |
| W3 13–17 Oct | calibration; exam on candidate; independent re-run | fringe and soot motes; approval | numbers finalised from readout 4 | PR 7 lines and codex | #541 export dry run | Fri: GO / fallback call (M2) |
| W4 20–24 Oct | port_fixtures explicit update if readout 7 changed behaviour | VFX tint after approval | — | remaining assets | #415 / #420 evidence (#549 merged and #543 started in W1, pulled forward) | — |
| W5 27–31 Oct | support | — | — | — | RC-shape export, twin, upload (M3) | install and smoke on both devices |
| W6 3–7 Nov | fixes from beta | — | — | — | P7 checklist | P2 and P4 sessions; beta starts; P3 journeys begin |
| W7 10–14 Nov | fixes | — | — | — | ledger triage | beta close; feel verdict (M4) |
| W8 17–21 Nov | — | — | — | — | RC freeze; P0–P9 packets; receipt | submit (M5) |
| W9–10 24 Nov–5 Dec | — | — | — | — | review responses | App Review; storefront (M6) |

## 5. Fallbacks

- **Mechanism.** If at M2 the Edge way cannot meet G1 and G2 while Shatter and Lantern do: ship with Shatter and Lantern as the two clear ways, Edge present as a fringe, and keep the Edge content on a branch for 1.0.x. The flame, recognition and steering ship regardless; they are the product feature. If G4 cannot be met at any Soot severity that keeps G3: raise the question to James with the two readouts side by side; enemy scalars are the last lever. *Resolved 30 Sep:* readouts 5 and 6 showed no global lever reaches G1 or G4 and that enemy scalars lift every arm alike; the owner ruled that the game may be hard and that G1 and G4 are readings, not blockers. Calibration by global knobs is closed; the one remaining balance lane is each way's own wall (readout 7, one PR, then stop). *Readout 7, 30 Sep:* Shatter (Spall) and the Lantern (Hearthfall) ship level with each other (47.5% each at V0 full on seeds 13000-13199; 11 pp apart on 13200-13299) and Edge ships nothing, so G2 fails on Edge alone (21.5% at V0 full, 26 pp under them): the two-clear-ways shape above, with Edge the fringe, is what the game now is.
- **Presentation.** If the shader is not approved on device by W4: ship a two-state flame (colour and stability only, no fringe or motes) and finish the fringe in 1.0.1.
- **Devices.** If a floor device is unavailable: evidence on the other device plus the simulator for layout, with the missing device recorded as a known gap in the receipt; the bar's own rule decides whether that is a miss.
- **App Review rejection.** One buffer week is in M6. A second rejection moves M6 by the fix's size, not by a fixed amount.

## 6. What only James can do, with dates

| When | What | Time |
|---|---|---|
| W1–W3, Mondays | read the readout table, answer at most two questions | 30 min |
| Fri 10 Oct | play two runs on the dev build; say what the flame made you feel | 1 h |
| Fri 17 Oct | GO or fallback call | 30 min |
| W5 | install TestFlight on both devices; smoke | 1 h |
| W6 | P2 and P4 sessions on both devices | two half-days |
| W6–W7 | P3 journeys (four) and the beta round with two or three players | spread over two weeks |
| W7 | feel verdict on #205 | 1 h |
| W8 | RC signature; App Store Connect submission | 2 h |
| W9–W10 | reply to App Review if asked | as needed |

## 7. Tracker reset

- #421: one comment linking this roadmap and the lock; the issue stays open only as the record of the superseded programme until M3, then closes with "superseded by the Flame".
- #542, #548: close as superseded (they encode the certificate model). #547 is already closed.
- #543: re-scope to "integrate the selected Flame candidate and expose Duskblade first-class"; keep its completed preflight.
- #544: re-scope to "Ashwarden ways via the class template, 1.1"; stays parked until M3.
- #549: re-scope to "amend rc-bar P9 to G1–G7 plus H; historical header on the P9 method doc".
- #108: unchanged as the RC gate. #156: replace the delivery index with a pointer to this roadmap.
- Draft PRs #556, #557 stay closed; their branches remain as reference. Their scalar changes are not carried by default.
- New issues only where a lane needs a tracked handoff: at most one per lane.
- Vocabulary retired: certificate, oracle, containment, custody, ledger, N0, B1, DD1.

## 8. Assumptions and risks

Assumptions: agents work daily on each lane; the M1 Max and the Linux VM are available for readouts; both floor devices, the Apple team and signing are in order (P7 already names the team); James can give the hours in §6.

| Risk | Effect on dates | Mitigation |
|---|---|---|
| The mechanism needs a fourth week | M2–M6 slip one week | the time box and the fallback in §5 |
| Shader or HUD work does not read on device | none to M3 if the two-state fallback is taken | approval gate in W3 |
| Stagecraft assets late | none to M3 if placeholders are accepted for beta; P5 sign-off would then wait | start in W1; generation is parallel |
| Device evidence finds a performance miss | M4–M6 slip by the fix | P2 measured in W6, not W8 |
| App Review rejection | up to one week | buffer in M6 |
| Scope creep from 1.1 into 1.0 | every milestone | Ashwarden work does not start before M3 |

## 9. Cadence and reporting

Monday: one table per lane with three columns, done, blocked, next, and the latest readout. Friday: a playable and one human observation. Every PR body carries the readout it changed. Nothing else is reported unless it is a decision, a blocker or exact evidence.

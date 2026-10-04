# Glassvow 1.0 — iOS release roadmap

**Status:** active, written 2026-09-29 (Monday). Owner: James. Author: Claude (Fable 5.1). The owner delegated the reframing of the roadmap on 2026-09-29 ("full authority to re-frame the entire roadmap to release"). This document supersedes the sequencing in #156's delivery index and #421's programme disposition. It does not close any issue by itself; §7 lists the tracker actions.

**Product scope of 1.0.** Duskblade, playable to the shipped terminus in en and zh-Hant on iPhone and iPad, with the Flame and three discoverable ways ([design lock](design/2026-09-29-dusk-flame/README.md)). The Ashwarden is not exposed in 1.0 and returns in 1.1 with its own ways, built from the [class template](design/2026-09-29-dusk-flame/ways-template.md). The mythic set (#212) stays out of 1.0.

**The bar.** `docs/rc-bar.md` P0–P8 unchanged. P9 becomes the flame gates G1–G7 plus the human round H, carried by #549. *Superseded on 2026-10-04:* #549 made that change (PR #572, 2026-09-29), and #685 brought P9 in line with the owner's rulings. G1 and G4 are readings (30 Sep); the bot round, the lock's row B, replaces H (1 Oct); P9 records one verdict per shipped class, ACCEPT or NOT ACCEPTED, on the design's intent, with the gates as its evidence (2 Oct).

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
| G. Beta and feel | #195 beta logistics, #205 feel verdict, P6 round, P8 ledger | James and two or three players; agent triage | M3 build | debrief forms; feel verdict; ledger complete. *Superseded on 2026-10-01: the #205 feel verdict is no longer a gate. James's play reports, #205's included, are input to the P9 verdict (owner ruling; rc-bar P9, #685).* |
| H. Store and launch | #425 launch control, #427 listing, #428 submission, #429 verification | James for App Store Connect; agent for copy and checks | M5 RC | processed build; approved; storefront verified |

Dependencies: C depends on A's PR 2 (affinity schema). B depends on A's `FLAME` event. E's #543 depends on A–C's integration to `main`. F and G depend on M3. H depends on M5.

## 3. Milestones

Dates are targets under the assumptions in §8. A milestone is met by its evidence, never by the calendar.

| Milestone | Target | Exit evidence |
|---|---|---|
| M0 Lock merged | Tue 30 Sep | this roadmap, the lock and the template on `main`; #421 comment pointing at them |
| M1 Flame playable | Tue 30 Sep (pulled forward from Fri 10 Oct on the owner's word, 30 Sep) | macOS dev build with the flame in the HUD, reward, shop and event screens handed to James; readouts 1–6 posted; James plays when he can |
| M2 Mechanism GO or fallback | Fri 17 Oct | Edge content in; readout 7 (each way's own wall) shipped or dropped; G2, G3, G5, G6 and G7 met on the candidate SHA with G1 and G4 reported as instrument readings (owner decision, 30 Sep: the game may be hard, the pilot is not a human); James's runs (H) recorded; lines in. *Superseded:* H was replaced by row B, the bot round, on 1 Oct (James's runs are input), and on 2 Oct the owner ruled that the result is one verdict on the design's intent, the gates its evidence. *Met early:* the orchestrator's ACCEPT, with one reservation, was given on 2 Oct at 22:12 BST on readouts 11–13, with row B graded in readout 13's table, and the owner confirmed it on 4 Oct (lock §11, *Verdict*; rc-bar P9) |
| M3 Internal TestFlight | Fri 31 Oct | selected candidate integrated to `main`; #549 merged; #543 done; RC-shape export and twin; processed TestFlight build installed on iPhone and iPad with smoke evidence |
| M4 Beta closed, feel signed | Fri 14 Nov | P6 round survived; #205 verdict recorded; P8 ledger current; player-facing-major changes re-evidenced. *#205 is not a gate since 1 Oct: its reports are input to the P9 verdict (rc-bar P9).* |
| M5 RC frozen and submitted | Fri 21 Nov | P0–P9 evidence on the exact RC commit; RC signature receipt; #428 submitted |
| M6 Live | Fri 5 Dec (buffer to Fri 12 Dec) | #429: public storefront verified in both locales |
| 1.1 Ashwarden lock | by Fri 19 Dec | class template applied; Ash lock reviewed |
| 1.1 Live | late Jan 2027 | same bar on the combined product; Duskblade claims carried or requalified. *Settled 2026-10-04:* requalified, not carried. The Duskblade is re-read under the 1.1 instrument (search player `s2`) on the combined product, and readout 13 stays 1.0's reading of record (#544 decision 4; rc-bar P9) |

## 4. Week by week

| Week | A Flame domain | B Flame screen | C Edge content | D Stagecraft | E Release eng. | F / G / H James |
|---|---|---|---|---|---|---|
| W1 29 Sep–3 Oct | PR 2: affinity, `flame.gd`, hygiene, stats, event, sim arms, readout 1 | shader spike on the lab | card sketches to numbers | #560–#564 generation starts | #549 draft; #545 icon; #415 policy text | decisions on readouts (30 min) |
| W2 6–10 Oct | PR 3 recognition and steering, readout 2; PR 4 knobs, readout 3 | HUD lantern flame on device shapes | PR 6 content and art | assets landing; six lines authored | #546 screenshots plan; #420 Sentry on device prep | Fri: play two runs (M1) |
| W3 13–17 Oct | calibration (*closed 30 Sep: global calibration ended; each way's own wall from readout 7, then readouts 8–13*); exam on candidate; independent re-run | fringe and soot motes; approval | numbers finalised from readout 4 | PR 7 lines and codex | #541 export dry run | Fri: GO / fallback call (M2) (*given 2 Oct, confirmed 4 Oct*) |
| W4 20–24 Oct | port_fixtures explicit update if readout 7 changed behaviour | VFX tint after approval | — | remaining assets | #415 / #420 evidence (#549 merged and #543 started in W1, pulled forward) | — |
| W5 27–31 Oct | support | — | — | — | RC-shape export, twin, upload (M3) | install and smoke on both devices |
| W6 3–7 Nov | fixes from beta | — | — | — | P7 checklist | P2 and P4 sessions; beta starts; P3 journeys begin |
| W7 10–14 Nov | fixes | — | — | — | ledger triage | beta close; feel verdict (M4) (*not a gate since 1 Oct*) |
| W8 17–21 Nov | — | — | — | — | RC freeze; P0–P9 packets; receipt | submit (M5) |
| W9–10 24 Nov–5 Dec | — | — | — | — | review responses | App Review; storefront (M6) |

## 5. Fallbacks

- **Mechanism.** If at M2 the Edge way cannot meet G1 and G2 while Shatter and Lantern do: ship with Shatter and Lantern as the two clear ways, Edge present as a fringe, and keep the Edge content on a branch for 1.0.x. The flame, recognition and steering ship regardless; they are the product feature. If G4 cannot be met at any Soot severity that keeps G3: raise the question to James with the two readouts side by side; enemy scalars are the last lever. *Resolved 30 Sep:* readouts 5 and 6 showed no global lever reaches G1 or G4 and that enemy scalars lift every arm alike; the owner ruled that the game may be hard and that G1 and G4 are readings, not blockers. Calibration by global knobs is closed; the one remaining balance lane is each way's own wall (readout 7, one PR, then stop). *Readout 7, 30 Sep:* Shatter (Spall) and the Lantern (Hearthfall) ship level with each other (47.5% each at V0 full on seeds 13000-13199; 11 pp apart on 13200-13299) and Edge ships nothing, so G2 fails on Edge alone (21.5% at V0 full, 26 pp under them): the two-clear-ways shape above, with Edge the fringe, is what the game now is. *Superseded on 2 Oct:* readouts 9–13 changed that. Lit glass gave Edge a payoff only a committed deck collects ([readout 9](design/2026-09-29-dusk-flame/readouts/readout-9.md)), and in readout 13, the reading of record, every committed way wins at V0 in both pools (row B's first part) and G2 at V0 full passes on point. The fallback was not taken: the Duskblade ships three ways, accepted on 2 Oct with one reservation (lock §11, *Verdict*; rc-bar P9).
- **Presentation.** If the shader is not approved on device by W4: ship a two-state flame (colour and stability only, no fringe or motes) and finish the fringe in 1.0.1.
- **Devices.** If a floor device is unavailable: evidence on the other device plus the simulator for layout, with the missing device recorded as a known gap in the receipt; the bar's own rule decides whether that is a miss.
- **App Review rejection.** One buffer week is in M6. A second rejection moves M6 by the fix's size, not by a fixed amount.

## 6. What only James can do, with dates

| When | What | Time |
|---|---|---|
| W1–W3, Mondays | read the readout table, answer at most two questions | 30 min |
| Fri 10 Oct | play two runs on the dev build; say what the flame made you feel | 1 h |
| Fri 17 Oct | GO or fallback call. *Given early:* the orchestrator's ACCEPT on 2 Oct (22:12 BST), on the owner's delegation of design calls, confirmed by the owner on 4 Oct | 30 min |
| W5 | install TestFlight on both devices; smoke | 1 h |
| W6 | P2 and P4 sessions on both devices | two half-days |
| W6–W7 | P3 journeys (four) and the beta round with two or three players | spread over two weeks |
| W7 | feel verdict on #205 (*input to the P9 verdict, not a gate, since 1 Oct*) | 1 h |
| W8 | RC signature; App Store Connect submission | 2 h |
| W9–W10 | reply to App Review if asked | as needed |

## 7. Tracker reset

- #421: one comment linking this roadmap and the lock; the issue stays open only as the record of the superseded programme until M3, then closes with "superseded by the Flame".
- #542, #548: close as superseded (they encode the certificate model). #547 is already closed.
- #543: re-scope to "integrate the selected Flame candidate and expose Duskblade first-class"; keep its completed preflight.
- #544: re-scope to "Ashwarden ways via the class template, 1.1"; stays parked until M3. *Overridden on 4 Oct:* the owner activated #544 on 4 Oct 2026 (12:25 BST), before M3. Its plan of record (4 Oct, 13:20 BST) runs the pipeline steps P1–P6, then the Ash steps A0–A10. The Ash lock by Fri 19 Dec 2026 and 1.1 live in late January 2027 stand (§3). The Ashwarden stays `deferred` in 1.0, and the Duskblade's accepted figures must not move.
- #549: re-scope to "amend rc-bar P9 to G1–G7 plus H; historical header on the P9 method doc". *Done* (PR #572, 2026-09-29; #549 closed). *Amended on 2026-10-04* by #685, in line with the rulings of 30 Sep to 2 Oct: G1 and G4 are readings, row B replaces H, and P9 records one verdict per class.
- #108: unchanged as the RC gate. #156: replace the delivery index with a pointer to this roadmap.
- Draft PRs #556, #557 stay closed; their branches remain as reference. Their scalar changes are not carried by default.
- New issues only where a lane needs a tracked handoff: at most one per lane.
- Vocabulary retired: certificate, oracle, containment, custody, ledger, N0, B1, DD1. *(2026-10-04: B1 here is the certificate-era name; row B's parts B1 and B2 in the Flame readouts are not it; rc-bar P9, Naming.)*

## 8. Assumptions and risks

Assumptions: agents work daily on each lane; the M1 Max and the Linux VM are available for readouts; both floor devices, the Apple team and signing are in order (P7 already names the team); James can give the hours in §6.

| Risk | Effect on dates | Mitigation |
|---|---|---|
| The mechanism needs a fourth week | M2–M6 slip one week | the time box and the fallback in §5 |
| Shader or HUD work does not read on device | none to M3 if the two-state fallback is taken | approval gate in W3 |
| Stagecraft assets late | none to M3 if placeholders are accepted for beta; P5 sign-off would then wait | start in W1; generation is parallel |
| Device evidence finds a performance miss | M4–M6 slip by the fix | P2 measured in W6, not W8 |
| App Review rejection | up to one week | buffer in M6 |
| Scope creep from 1.1 into 1.0 | every milestone | Ashwarden work does not start before M3. *Overridden on 4 Oct by the owner (#544).* The mitigation is now #544's plan of record: the Ashwarden stays `deferred` in 1.0; Ash content lands dormant, and every new Ash-only id enters the Duskblade's `excludes` in the same commit, so the Duskblade's draws and RNG stream stay byte-identical (decision 6); the Duskblade's accepted figures must not move |
| The shipped map runs the fast layout, not Map Compiler v2 (2026-09-30): crossings, near-misses and the farthest zoom miss the governed quality contract, and the map build (about 0.7 s on the M1 Max) is unmeasured on the A12 | none if the floor devices accept it; a device miss adds the fix to M4 | compiler is an authoring opt-in only (`docs/map/production-layout.md`); check Continue-to-map and the map at phone and pad on the iPad 8 in the next TestFlight |

## 9. Cadence and reporting

Monday: one table per lane with three columns, done, blocked, next, and the latest readout. Friday: a playable and one human observation. Every PR body carries the readout it changed. Nothing else is reported unless it is a decision, a blocker or exact evidence.

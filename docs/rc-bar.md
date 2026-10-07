# The RC Bar — iOS Release Candidate

Written by the grilling on [#164](https://github.com/eugnel-ltd/glassvow/issues/164), part of the
commercial-push map [#156](https://github.com/eugnel-ltd/glassvow/issues/156). This document is the
falsifiable bar the release gate ([#108](https://github.com/eugnel-ltd/glassvow/issues/108)) checks a
build against — `docs/commercial-game-delivery.md` §6 made concrete. It composes decisions made
elsewhere; where a pillar's detail lives in another document or ticket, this file binds it by
reference and does not restate it.

**Scope.** This bar instantiates for the **iOS release candidate**: floor devices **iPhone SE
(2nd generation)** and **iPad (8th generation)** per
[#158](https://github.com/eugnel-ltd/glassvow/issues/158). The Android phase re-instantiates this same
bar with the Android floor pair (Galaxy A13 LTE, Galaxy Tab A8); nothing in this document
forecloses that, Steam/PC/Mac, or expansion-pack IAP.

## How the bar works

- **Ten pillars, P0–P9. The bar is passed when every pillar passes** and the RC signature
  receipt (below) is signed. There is no partial pass.
- **Evidence tiers.** P2/P3/P4 produce **immutable evidence packets** (house style: evidence
  commit with manifest and offline verifier, bound to exact hashes). P5/P7/P8 record as
  **ticket comments** (the rubric's own sign-off protocol; a linked compliance checklist; the
  defect ledger). P0/P1 evidence is recorded directly in the RC signature receipt.
- **Waivers.** Rubric criteria may be waived only through the rubric's recorded-waiver
  mechanism, on the executing ticket. P1, P2, P4, P7, and P9 are **not waivable**: a miss is not
  argued past the gate — it returns to the map as a new wayfinder decision, per
  [#158](https://github.com/eugnel-ltd/glassvow/issues/158)'s rule. P8 waivers (per-defect, by James,
  with reason) are part of that pillar's mechanism, not an escape from it.
- **Builds.** The RC artifact is the distribution-signed `glassvow.ipa` (P0). Where
  distribution signing denies evidence access — the app container, byte-level save
  fingerprints — evidence is captured on the **twin build**: the exact RC commit, the exact
  release export configuration (no `dev_tools`, never a Dev Review build), differing **only**
  in signing identity. The twin's equivalence claim is exactly that sentence; each packet that
  uses the twin states it.

### When evidence expires (scoped reset)

The bar binds one exact RC commit. If the RC commit changes:

| Diff since evidenced commit | Consequence |
|---|---|
| Docs-only | All evidence carries |
| Any code, asset, or export-preset change | P1 re-runs; P2, P3, P4 re-run; P5 re-verifies only the surfaces the change touches; P7 re-checks build-config items only (SDK, Info.plist keys, signing); **P9's independent re-run and the exam's own items repeat on the new candidate commit. If the candidate's content SHA-256 is not the reading of record's, the content-equivalence comparison repeats on the new commit too, and without it the verdict of record no longer describes the candidate (P9)** |
| Player-facing-major change (James's judgment) | Additionally, P6 beta round repeats |

"Player-facing-major" means a change that would read differently between the beta round's build
and this RC: gameplay balance, card/relic behaviour, encounter design, visible UI, or story
flow. An invisible fix (crash, soft-lock, data corruption) is not player-facing-major unless it
alters a gameplay rule. All evidence is captured on the final RC commit; evidence from an
earlier commit survives only through this table.

*Superseded in this table on 2026-10-04:* the P9 entries of 2026-09-29 read "P9's gates G1–G7
re-run on the new candidate SHA" and "and P9's human round H with it". G1 and G4 became readings
on 2026-09-30; the bot round (the lock's row B) replaced H on 2026-10-01 and re-runs with the
rest of P9's evidence.

*Superseded in this table on 2026-10-05:* the P9 entry of 2026-10-04 ended "and if the content
SHA-256 moved, the verdict of record no longer describes the candidate (P9)". P9 now also accepts
content equivalence for the class (P9, *History*).

## P0 — Build identity

- [ ] The RC commit is named. The distribution-signed `glassvow.ipa` is produced from it per
      `docs/release-signing.md`, from the pinned Godot 4.7.2 templates.
- [ ] The version stamp is honest: marketing version and build number identify this RC, build
      numbers increment monotonically across RC attempts, the submitted build number is
      recorded in the receipt, and no player-facing surface carries a foreign or benchmark
      hash.
- [ ] `dev_tools` is absent: no Developer Console entry point is reachable anywhere in the
      build ([#159](https://github.com/eugnel-ltd/glassvow/issues/159): a store or release-candidate
      build never carries that capability).
- [ ] Fresh-install boot: on each floor device, a clean install (no prior app data) cold-boots
      to the title screen.

## P1 — Repo gates green on the RC commit

All from the repo root, on the exact RC commit, plus CI green on the same head:

- [ ] `godot --version` prints 4.7.2.stable (the engine pin — a PASS from any other editor
      version is not evidence)
- [ ] `tools/check_imports.sh`
- [ ] `tools/check_scripts.sh`
- [ ] `godot --headless -s res://tests/run_all.gd` exits 0 (PASS)
- [ ] `python3 tools/check_anchors.py` and `python3 tools/check_benchmark_freeze.py`
- [ ] CI green on the exact RC head. A pass obtained by re-running a flaky job does not count
      until the flake itself is filed as a `bug` (it lands in P8's ledger like any other).

## P2 — Performance floor

The five gates of [#158](https://github.com/eugnel-ltd/glassvow/issues/158)'s resolution, bound by
reference, on **both floor devices**, both locales, release/profileable build, unplugged, fixed
50% brightness, controlled room temperature, cold run plus 30-minute heat-soaked run over the named route (cold
launch/save-load, worst visible map transition, act-1 Leviathan workload with 96 sustained VFX
particles):

- [ ] Frame pacing: post-warm-up whole-frame P95 ≤16.67 ms, P99 ≤25.00 ms, ≤1.0% missed display
      deadlines, no frame >50.00 ms. Averages alone do not pass.
- [ ] Sustained performance: final five minutes regress ≤10% vs the first measured five minutes
      (P95 frame time, missed-deadline rate).
- [ ] Thermals: never `serious`/`critical` (iOS/iPadOS); complete platform-native thermal trace
      preserved.
- [ ] Battery: ≤10 percentage points over the 30-minute route, device at ≥80% battery health
      where the OS exposes it; start/end levels and platform-native power trace recorded;
      charging runs invalid.
- [ ] Memory stability: no OS memory-pressure termination, no monotonic retained growth across
      the session's two consecutive route runs (the cold run, then the heat-soaked run);
      platform-native peak and post-route figures reported.
- [ ] **Cold save-load ≤2 s** on each floor device: from tapping Continue to the restored run
      being interactive. Cold launch → title-interactive is
      measured and recorded in the same packet, **report-only** for this RC — gating launch
      time would be a new decision.

Evidence: immutable packet. A miss on one device creates measured optimisation work; if the
gate cannot be met without a renderer, fidelity, frame-rate, or supported-device change, that
trade-off returns to the map ([#158](https://github.com/eugnel-ltd/glassvow/issues/158)).

## P3 — Full-run QA on device

The [#107](https://github.com/eugnel-ltd/glassvow/issues/107) protocol (`docs/p8-full-run-qa.md`)
re-instantiated on floor hardware, by touch, on the twin build:

- [ ] **Four full journeys = 2 heroes × 2 locales**, split two per floor device (each device
      runs two journeys — one hero in en, the other hero in zh-Hant — covering both aspect
      classes across the pair). A journey
      runs title → full run to the shipped terminus (the Act IV terminus once
      [#175](https://github.com/eugnel-ltd/glassvow/issues/175)'s arc lands) → Dawn → back to the
      Vigil/title. Touch only; no keyboard, no mouse, no editor.
- [ ] **One spot-check journey on the actual distribution-signed TestFlight build** (either
      device, either locale). Pass criteria: the journey completes without crash, soft-lock, or
      OS termination, and every defect found files into P8's ledger. A defect that reproduces
      on the distribution build but not on the twin voids the twin's equivalence claim for
      every packet that used it — that is a P0 problem, not a P3 note.
- [ ] Every defect found is filed as a `bug` issue before the pillar closes — P8's ledger is
      the fail-closed net; QA finding things is the protocol working, not the pillar failing.

Evidence: immutable packet (route boundaries, screenshots/recordings, run seeds).

## P4 — Save integrity across process death

The [#107](https://github.com/eugnel-ltd/glassvow/issues/107) process-kill matrix re-run on the
**iPhone SE 2**, on the twin build (container access requires development signing):

- [ ] All ten checkpoints — rest, event, shop, treasure, eventPending, map, combat, partial
      reward, boss-relic, progressed Dawn — each: true process kill (app terminated by the OS,
      not backgrounded; termination verified), fresh process on relaunch, durable-fingerprint
      equality on the restored state, and a real-input continuation by touch.
- [ ] A save/load comparison inside one process is not substituted for process-kill evidence
      (the [#107](https://github.com/eugnel-ltd/glassvow/issues/107) rule, unchanged).
- [ ] If a prior TestFlight round shipped builds to outsiders, the RC loads and continues a
      save created by the latest prior round without loss (one checkpoint suffices; absence of
      any prior round makes this row vacuously true and says so in the packet).

Evidence: immutable packet.

## P5 — Rubric sign-offs

`docs/commercial-rubric.md` is the bar's content here; this pillar binds its two tiers:

- [ ] **Tier 1 — sign-off.** Every rubric surface (Global inherited each time, the eight
      surfaces, Onboarding, and the cross-surface Story arc) is signed by James on the primary
      phone — **James's daily-driver iPhone, named by model in the RC signature receipt** (Tier
      1 checks real-world look-and-feel; floor coverage is Tier 2's job, not this tier's) — on
      a release export, both locales, recorded as sign-off comments on the executing tickets
      per the rubric's protocol. The endgame surfaces named below may instead be signed on a
      Dev Review build; that is an amendment of this protocol, not a waiver of any criterion.
- [ ] **Tier 2 — floor re-verify.** Every surface's full criteria list runs once on floor
      hardware: **iPhone SE 2 in zh-Hant** (smallest screen × riskiest script), **iPad 8 in
      en** (4:3 aspect axis). Both locales are inside the gate across the pair. Recorded as a
      consolidated re-verify table on the release-gate ticket
      ([#108](https://github.com/eugnel-ltd/glassvow/issues/108)).
- [ ] **Endgame amendment.** These surfaces may be signed on a Dev Review build reached
      through the Scenario kernel, both locales: the Vigil (Story-arc shard and quest-memory
      criteria), the sixth-Shard unsealing / sealed-door ceremony, the Act IV map, and the
      Act IV boss. Every other surface still requires a release export. This amends the
      sign-off protocol; it does not waive any criterion.
- [ ] Any waiver exists only as the rubric's recorded-waiver mechanism prescribes.

## P6 — Internal beta round

- [ ] One internal beta round completed and survived, against the pass criteria defined by
      [#166](https://github.com/eugnel-ltd/glassvow/issues/166): TestFlight internal track, 7 days,
      one RC-shape build, four testers (James + Wing zh-Hant; Nelson + Eugenia en). The
      receipt links whatever evidence #166 prescribes. (External beta consciously skipped —
      design preserved in `docs/external-beta-playbook.md`.)

**Waivability.** Running the round is **not waivable** — no RC without one completed internal
round. Whether the round *passed* is judged solely by #166's criteria; a round that fails them
returns to the map as a decision (fix and repeat, or a recorded release-policy call by James on
[#108](https://github.com/eugnel-ltd/glassvow/issues/108)) — it is never silently waived, and
beta testers hold no veto beyond what #166's criteria encode.

## P7 — Compliance checklist (iOS)

From the store-compliance dossier
(`docs/research/2026-08-13-store-compliance-dossier.md`, [#162](https://github.com/eugnel-ltd/glassvow/issues/162)):

**Accounts and declarations**

- [ ] Apple Developer Program membership active (Team `V45S7U2LZB`); **Paid Apps Agreement**
      signed by the Account Holder, banking and tax complete.
- [ ] **EU DSA trader status** declared and verified (address/phone/email; shown on the EU
      product page).
- [ ] Updated **age-rating questionnaire** answered honestly — expected 9+ (Cartoon or Fantasy
      Violence); Gambling, Simulated Gambling, Loot Boxes, Contests all No.

**Build and metadata**

- [ ] Built and archived with **Xcode 26 / iOS 26 SDK** (in force since 2026-04-28);
      distribution-signed per `docs/release-signing.md`.
- [ ] `ITSAppUsesNonExemptEncryption = false` in the exported project's Info.plist.
- [ ] **Privacy policy URL live in en and zh-Hant**, set in App Store Connect, **and linked
      inside the app** (settings/about — Apple 5.1.1(i); this is a product feature and ships in
      the build).
- [ ] **Privacy nutrition label** matches the shipped binary:
      - Baseline (no SDK): **"Data Not Collected"**.
      - If the Sentry SDK ([#161](https://github.com/eugnel-ltd/glassvow/issues/161)) is in the tree
        at RC: declare Diagnostics → Crash Data (plus Performance/Other Diagnostic Data and
        Identifiers as configured), not-linked/not-tracking posture per the SDK configuration,
        a consent posture per Apple 5.1.1(ii), and the privacy policy updated to match.
- [ ] **Store presence complete and compliant**: name ≤30 chars, subtitle ≤30, keywords ≤100,
      description, support URL, 1024×1024 icon in the asset catalog, screenshots for
      **6.9" iPhone and 13" iPad** (1–10 each, real gameplay screens per 2.3.3, all metadata
      appropriate for 4+ per 2.3.8, unique name with no keyword stuffing, trademarks, or
      pricing in metadata per 2.3.7), in **both locales with matching scope** (no field
      translated in one locale and missing in the other). Screenshots carry no debug overlay,
      placeholder text, or content absent from the shipped build. Content is produced by its
      own tickets; this pillar checks presence and compliance, not taste.

Evidence: a checklist comment linking each item's proof (screenshots of App Store Connect
state, the policy URL, the Info.plist diff).

## P8 — Fail-closed defect ledger

- [ ] At the RC snapshot, the ledger enumerates **all open `bug` issues** and every held/waived
      item referenced by the map. Zero open bugs, or each remaining one explicitly waived by
      James with a reason, in the ledger comment. Missing, duplicate, or unknown rows fail the
      ledger ([#107](https://github.com/eugnel-ltd/glassvow/issues/107) house style). The ledger is
      refreshed immediately before the RC is declared.
- [ ] If the Sentry SDK is in the RC build and the beta round produced sessions, the ledger
      records the crash-free-sessions rate; a rate below **99.0%** fails closed unless every
      contributing crash signature is itself in the ledger, fixed or waived.

## P9 — The ways of each shipped class (the Flame verdict)

Rewritten on 2026-09-29 under [#549](https://github.com/eugnel-ltd/glassvow/issues/549), and brought
in line with the owner's rulings of 30 September to 2 October on 2026-10-04 under
[#544](https://github.com/eugnel-ltd/glassvow/issues/544) (its plan of record, step P5). The
measurement contract is §11 of the
[Duskblade Flame design lock](design/2026-09-29-dusk-flame/README.md): its arms, cells, gates,
thresholds and seeds are bound here by reference. **Not optional and not waivable.** A verdict
given on different content says nothing about the shipped game. The wording this replaces is
kept, with the date each part stopped being in force, under *History* at the end of this pillar.

**Scope per shipped class.**

- **1.0, this RC: the Duskblade only.** The Ashwarden is hidden: its content row carries
  `"deferred": true`, and `domain/rules/class_scope.gd` stops a new run starting as it.
  Ashwarden claims, and any claim that compares the two classes, are deferred to 1.1
  ([release roadmap](release-roadmap.md)) and are never PASS. No Ashwarden evidence is a
  precondition for this pillar; comparator evidence kept from the earlier programme is history,
  not a demand.
- **1.1: both classes, on the combined product.** Each class gets its own verdict: the Ashwarden
  on its own lock and readings, built from the
  [class template](design/2026-09-29-dusk-flame/ways-template.md), and the Duskblade requalified
  under the 1.1 instrument (pilot `p9`, search player `s3`) on the combined product. By the
  orchestrator's ruling of 5 October 2026, the 1.1 search player is `s3` (#544 P6b): `s2`'s
  honest play plus the credit for a Smolder tick that kills before the enemy acts. Readout 14's
  interim reading was made under `s2`. `s3` differs from it for the Duskblade only in `full`
  cells, through the Ashfall omen's starting Smolder (sample: 200 seeds a cell, 13000–13199: 485
  of 2,400 V0 and V5 `full` rows changed and 55 outcomes flipped, no arm's paired change
  significant, every p ≥ 0.45; one graded point verdict crossed its line, G6 at V0 full, edge
  60.6% → 59.8% of A_lit's wins, UNDECIDED on interval under both). The Duskblade is re-read
  under `s3` on the combined product at A9, and the cross-class reading uses `s3` for both
  classes. The 1.0 verdict does not carry into 1.1: the requalification replaces it there, and
  readout 13 stays 1.0's reading of record. Read on 1.0's content under `s2`
  ([readout 14](design/2026-09-29-dusk-flame/readouts/readout-14.md)), the Duskblade's intent
  holds with the same one reservation, the fresh-pool Lantern lead. This is an interim reading,
  not a verdict; the 1.1 verdict is given at step A9 on the combined product (the lock's §11,
  *Verdict*, item 7). The gap between the classes is reported, not gated (#544's plan of record,
  decisions 4 and 5).

**The verdict.** For each shipped class P9 records one verdict, **ACCEPT** or **NOT ACCEPTED**,
on whether the design's intent holds: the three ways are viable and comparable; commitment is
rewarded and reading the offers is not a trap; scattering loses; the tiers are reachable;
adaptive play is diverse; every way can be won and has a feel; nothing is degenerate (owner
ruling, 2026-10-02: "just give me the acceptance result"). The gate figures are its evidence;
the verdict is not a count of gate passes. The orchestrator gives it under the owner's
delegation of design calls (2026-09-30). An ACCEPT may carry named reservations: each states its
figures and the readout that will answer it. A reservation is part of the verdict, not a
waiver. P9 passes only on ACCEPT.

**Which gates are graded and which are readings.** The arms, gates and thresholds are the lock's §11
as it stood at the reading of record, with its recorded amendments (G5's fresh-pool figure,
readout 5; G3 and G6 against A_lit, readout 10; G5 over survivors and the committed bot
`p8-d0-v3`, readout 13). The bar accepts no other thresholds.

| Gate | Role | How it is read |
|---|---|---|
| G1 viability | reading | Reported in every graded cell, point and 95% interval (owner ruling, 2026-09-30: "it is okay to be hard, this is roguelike") |
| G2 parity | graded | Best committed way minus worst, at each vow |
| G3 skill | graded | Against arm A_lit, the adaptive player that reads its own flame (from readout 10), and paired on common seeds (from readout 13). Arm A's row is the commit-blind floor, reported |
| G4 random loses | reading | Reported in every graded cell, point and 95% interval (owner ruling, 2026-09-30) |
| G5 reachability | graded | Over the runs alive at the act's end, with the all-runs figure beside it (from readout 13) |
| G6 diversity of adaptive play | graded | Among A_lit's wins (from readout 10). Arm A's row is the floor, reported |
| G7 guards | graded; a miss is always NOT ACCEPTED | Zero stalls and errors; deterministic replay; the CEM stress's Vow-5 ceiling read on holdout numbers only (training fitness never enters the receipt as a ceiling); save lineage and internal IDs unchanged. The [Duskblade lock's §12](design/2026-09-29-dusk-flame/README.md#12-implementation-map) invariants bind the candidate: no save-schema change, IDs only added, and `port_fixtures/` moved only in an explicit commit that says why |
| B bot round | graded | Both parts of the lock's row B, played by the search player: every committed way wins at V0, and every way has a feel. Row B replaced the human round H (owner ruling, 2026-10-01) |

- **A graded gate** is one the verdict must answer; under the owner's ruling of 2026-10-02 its
  threshold is evidence, not a switch. ACCEPT needs the intent each graded gate measures to hold
  in every graded cell, so a graded gate whose intent fails makes the verdict NOT ACCEPTED,
  whatever the other gates show. Every graded-gate figure short of its
  threshold, on point or on interval, stands in the verdict record: the reading's complete §11
  table and the verdict. A miss the verdict judges to need further work is carried as a named
  reservation. A G7 miss is never weighed against intent: it is NOT ACCEPTED.
- **Short of its threshold** means FAIL on point or FAIL on interval. A figure that passes on
  point and is UNDECIDED on interval is not short; it stays in the reading's table.
- **Whose judgement.** Whether a graded gate's intent holds is the orchestrator's judgement,
  recorded with the verdict: for every graded-gate figure short of its threshold, the verdict
  record states either why the gate's intent still holds or the reservation that carries it. A
  release reviewer checks that every short figure has one and does not re-derive the judgement.
- **A reading** is reported in every graded cell with its interval. Its threshold never decides
  the verdict; the verdict still reads the intent behind it (each way wins; scattering loses)
  from its figures.
- **Naming.** Readouts 8–13 call row B's two parts B1 and B2. That B1 is the lock's row-B part,
  not the retired certificate-programme name of the same spelling.
- **Play reports.** James's play reports, including those for
  [#205](https://github.com/eugnel-ltd/glassvow/issues/205), are input to the verdict and never a
  gate (owner ruling, 2026-10-01).

**The instrument of record and the exact candidate.** A verdict rests on one reading of record:
the readout whose complete §11 table it was given on.

- **1.0's reading of record is
  [readout 13](design/2026-09-29-dusk-flame/readouts/readout-13.md)** (#648):
  `content/full-content.json` at SHA-256
  `e9c4d48fbe38542e65a9c73f73b4c50f72116026d4be51a81b7a9b04ec33ca7b`; the committed arms built
  by pilot `p8-d0-v3`; every fight played by search player `s1` (`--play search`); arms
  C_shatter, C_lantern, C_edge, A, A_lit and R; graded by `tools/balance_ways.py`.
- **The seed bands of record.** The V0 cells on 13000–13999 (1,000 paired seeds a cell); the V5
  cells on 13000–14999 (2,000); G3 at V5 full also on 15000–16999, so on 4,000 common seeds in
  all. The lock's floor is 200 paired seeds a cell. Development seeds (12000–12999) never enter
  a verdict. The acceptance band 3000–5199 is kept for the exam: the CEM stress trains on
  4200–4999 and reads its ceiling on the historical holdout 5000–5199 only. 17000–18999 is
  reserved as 1.1's holdout (#544's plan of record, decision 7).
- **"On the exact candidate"** means all three of the following, on the RC commit the receipt
  binds:
  1. **The same content, or content equivalent for the class.** Either (a) the RC commit's
     `content/full-content.json` has the reading of record's SHA-256, or (b) its content is
     **equivalent for the class**:
     - At the RC commit, from a clean checkout, on the reading of record's host class
       (Apple-silicon macOS with the pinned Godot 4.7.2), the reading of record's complete cell
       table is played again with the instrument of record, named explicitly
       (`tools/balance_readout.py run … --play search --pilot p8-d0-v3 --search s1`), on the
       bands of record.
     - Every run's **graded fields** are identical to the reading of record's, run for run. The
       graded fields are the fields of a run that any part of the verdict's evidence reads: the
       §11 table, the G1–G7 gates, row B and the paired G3. They are named once, as
       `GRADED_FIELDS` beside the graders in `tools/balance_ways.py`, and the readout runner's
       tests fail when a grader reads a field the list does not name. G7's replay compares
       whole runs, so whether each replay is identical to its arm-A run is graded too. The CEM
       stress plays its own seeds and reads no run of the table.
     - Any other field that differs is listed, with the commit that caused it.
     - The comparison is recorded in the exam packet, with its commands and the comparer's
       output: `python3 -B tools/balance_readout.py equivalence --commit <RC commit SHA>
       <candidate's run directory> <reading of record's run directory>`, once for each of the
       reading's run directories (readout 13's
       [reproduction](design/2026-09-29-dusk-flame/readouts/readout-13-reproduction.md) names
       its archive and the digest of its rows). The comparer pairs the runs by cell, arm and
       seed, and exits 0 only when every graded field matches, both sides hold the same runs,
       every manifest names the same instrument, and every candidate manifest names the RC
       commit. The packet also runs the graders on the
       candidate's run directories (`tools/balance_readout.py table`, `g3` and `rowb`, as the
       reading of record was graded) and records their output beside the comparer's.

     If neither (a) nor (b) holds, the verdict of record does not describe the candidate: a new
     reading on the candidate and a new verdict are needed.
  2. **The independent re-run.** From a clean checkout of the RC commit, on any host, the
     reading's cell table is played again with the instrument of record (pilot `p8-d0-v3`,
     search player `s1`), named explicitly whatever the tools' default
     (`tools/balance_readout.py run … --play search --pilot p8-d0-v3 --search s1`), on the bands
     of record, and every report's manifest names the RC commit, the content SHA-256, the pilot
     and the search player. It agrees with the reading of
     record on every graded gate's verdict in every graded cell (on point and on interval where
     the gate has both, and on its single verdict for G7 and row B); the
     numbers need not match (owner ruling, 2026-09-27). A run under another instrument, such as
     1.1's `s3`, is a new reading, not this re-run. The Flame is code as well as content, so the
     re-run binds the commit and the verdict binds the content it was given on. A route (b) run
     made from a clean checkout of the RC commit, with the instrument of record and on the bands
     of record, also serves as this item's independent re-run: identical graded fields give
     identical verdicts.
  3. **The exam's own items.** The items the
     [Duskblade lock's §11](design/2026-09-29-dusk-flame/README.md#11-science-the-instrument-panel)
     *Exam* and *Seeds* keep for the final candidate, which no readout runs: the CEM stress, with
     its ceiling read on the historical holdout, used once; the save-lineage and internal-ID
     check; and the
     [Duskblade lock's §12](design/2026-09-29-dusk-flame/README.md#12-implementation-map) invariants
     (no save-schema change, new ids only added, `port_fixtures/` moved only in an explicit
     commit that says why). G7 passes on them.

**The 1.0 Duskblade verdict of record: ACCEPT, with one reservation.** The orchestrator's
verdict on readouts 11–13, given on 2 October 2026 at 22:12 BST on readout 13's complete §11
table (recorded in [#544's plan of record](https://github.com/eugnel-ltd/glassvow/issues/544),
decision 12, and entered with its history in the lock's §11 *Verdict* by #544's step P4a, #686). The reservation is the fresh-pool Lantern lead, 12.8 pp at V0 (G2 at V0 fresh, the
Lantern over Shatter, +8.9 to +16.6 pp: FAIL on point, UNDECIDED on interval), carried as a
1.0.x readout, not a reason to withhold the ACCEPT (readout 13, *What the next readout should
ask*, item 1). It carries no other reservation. The other graded-gate figures short of their
thresholds in readout 13, and why each gate's intent holds:

- **G3 at V5 full:** A_lit is 3.5 pp behind committed Shatter on 4,000 common seeds (−5.0 to
  −2.0 pp: FAIL on point, UNDECIDED on interval), 0.5 pp past the −3 pp line. Reading the offers
  is still not a trap: A_lit passes G3 on point in the other three cells, and at V5 full it leads arm A,
  arm R and the committed Lantern and Edge (13.8% against 11.8%, 3.9%, 12.2% and 12.2%; readout
  13 calls it the gate's edge).
- **A_lit's feel at V0 fresh** (59.2% against row B's 60%: a decided FAIL): row B's feel test is
  the committed ways' (lock §11, row B, part 2), and A_lit's own expression is read beside them
  (lock §11, arm A_lit). No committed way fails it, so every way still has a feel.

G1 and G4 fail in readout 13 as readings. On 4 October 2026 the owner confirmed that the Duskblade balance is complete. The
verdict binds the RC once the RC commit is the exact candidate defined above.

- [ ] **Verdict.** For every class the build ships, the verdict of record is ACCEPT, with its
      reservations named (1.0: the Duskblade verdict above).
- [ ] **Exact candidate.** The same content or content equivalent for the class, an agreeing
      independent re-run and the exam's own items, as defined above, on the RC commit the
      receipt binds. The scoped-reset table decides when they run again.
- [ ] **Deferred claims.** No Ashwarden claim, and no claim that compares the classes, is
      reported as PASS.
- [ ] A NOT ACCEPTED, a verdict that does not describe the candidate, a re-run that disagrees or
      a G7 miss is a miss. It returns to the map as a wayfinder decision; it is not argued past
      this pillar.

Evidence: the verdict of record for each shipped class with its reading and reservations, and
the exam packet on the RC commit (the content check, or the equivalence comparison with its
commands and the comparer's output; the independent re-run's verdicts; and the exam's own items).

**History.** The full text of 29 September is `git show db90a4f5:docs/rc-bar.md`.

- *In force from 2026-09-29 to 2026-10-04* (#549, PR #572, `db90a4f5`): "Duskblade ships with
  three ways (碎 Shatter, 燼 Lantern, 蝕 Edge) proven by the instrument of the Flame lock §11:
  gates G1–G7 on the exact candidate SHA, thresholds as frozen after readout 1 and recorded in
  the exam packet, plus the human round H", closing with "All of G1–G7 and H must pass, and the
  independent re-run must agree." It was superseded in these parts:
  - *G1 and G4 as pass conditions:* superseded on 2026-09-30, when the owner ruled that the game
    may be hard and that the G1 and G4 figures are the orchestrator's decision. They are
    readings.
  - *The human round H*, "played on a named build and recorded against that exact build: its
    wins, its easy / fun / hard labels and James's verdict for #205": superseded on 2026-10-01
    by the lock's row B, the bot round. Play reports are input, never a gate.
  - *G3 and G6 read against arm A:* superseded on 2026-10-01 by arm A_lit (readout 10). G3 is
    also paired on common seeds from readout 13 (2026-10-02).
  - *G5 over every run:* superseded on 2026-10-02 by G5 over the runs alive at the act's end
    (readout 13). Readouts 1–12 stay as recorded.
  - *"All of G1–G7 and H must pass":* superseded on 2026-10-02 by the verdict on the design's
    intent, with the gates as its evidence.
  - *"thresholds as frozen after readout 1":* replaced on 2026-10-04 by the lock's table with
    its recorded amendments, as above.
  - *"The Flame is code as well as content, so the identity is the commit, not a content hash":*
    kept for the re-run, and extended on 2026-10-04: the verdict also binds the reading's
    content SHA-256 and instrument.
- *In force from 2026-10-04 to 2026-10-05* (#544's step P5, PR #685, `6e04a8ea`): item 1 of
  "On the exact candidate" read "**Same content.** The RC commit's `content/full-content.json`
  has the reading of record's SHA-256. If it does not, the verdict of record does not describe
  the candidate: a new reading on the candidate and a new verdict are needed." The checklist
  line read "Same content, an agreeing independent re-run and the exam's own items", and the
  evidence line named only "the content check". Superseded on 2026-10-05 by route (b), content
  equivalence for the class, beside the same SHA-256 (#544). The Ashwarden's content lands
  dormant on main before the 1.0 RC is cut, behind `"deferred": true`, and every Ash-only id
  enters the Duskblade's `excludes`, so the RC's content SHA-256 is not the reading of record's
  while the Duskblade's draws and RNG stream stay byte-identical (the invariance panel,
  `tests/test_balance_invariance.gd`, pins them on every PR). The orchestrator ruled on
  5 October 2026 that step A2 is neither held for the RC cut nor kept on a long-lived branch,
  and that it merges only once this route is in force; the ruling is recorded in the
  [Ashwarden lock's §14](design/2026-10-05-ash-flame/README.md#14-fallback-time-box-and-open-items)
  (#692). Route (b)'s recording sentence, as #697 (`8d1fd9f2`) wrote it, named the comparer
  command as "`python3 -B tools/balance_readout.py equivalence <candidate's run directory>
  <reading of record's run directory>`" and said it "exits 0 only when every graded field
  matches, both sides hold the same runs and every manifest names the same instrument".
  Replaced the same day (#544 P7): the command names `--commit <RC commit SHA>`, and the
  comparer also requires every candidate manifest to name the RC commit, because a route (b)
  run serves as item 2's independent re-run, which binds the RC commit.
- *In force from 2026-10-04 to 2026-10-05* (#544 steps P5 and P6, PRs #685 and #690,
  `271ce1b1`): the 1.1 bullet named the Duskblade's 1.1 instrument "pilot `p9`, search player
  `s2`, accepted on readout 14", and read "Read on 1.0's content under the 1.1 instrument, the
  Duskblade's intent holds with the same one reservation". Superseded on 2026-10-05 by the
  orchestrator's ruling on #544 P6b: the 1.1 search player is `s3`, and readout 14 is an
  interim reading made under `s2`.
- *Before 2026-09-29:* the strategy-diversity method, kept as history in
  [`docs/balance/p9-strategy-diversity-system.md`](balance/p9-strategy-diversity-system.md);
  [`docs/reviews/549/obligation-map.md`](reviews/549/obligation-map.md) records where each of
  its obligations went.

## The RC signature receipt

The bar's final act, and the only place "RC" is pronounced: a signed comment by James on the
release-gate ticket ([#108](https://github.com/eugnel-ltd/glassvow/issues/108)) binding:

- the exact product head (the RC commit),
- the `.ipa` artifact hash,
- each pillar's evidence address (packet commits for P2/P3/P4; comment permalinks for
  P5/P7/P8; for P6, whatever evidence #166 prescribes; for P9, the verdict of record for each
  shipped class and the exam packet on the RC commit, with the independent re-run's verdicts;
  the human-round record named here until 2026-10-04 was superseded by the bot round on
  2026-10-01),
- P0/P1 evidence inline (gate log, CI run link),
- and the sentence "this build is the release candidate."

A verifier passing proves the evidence clears the gate; the signature is the distinct PM
approval — the two are never merged (`docs/commercial-game-delivery.md` §5's rule).

# repo_traps: judge calibration, round 3, 5 October 2026

**Outcome: the grader is not approved, in either arm, and the stop rule applies.** Both arms pass the
false-negative and stability bars. Both fail these bars:
- no gate failure on the correct set;
- false positives on COVERED judge claims, overall and by kind;
- no COVERED programmatic pass;
- wrong answers at 100%;
- coverage;
- adversarial.

The orchestrator's outcome and decision are recorded in `council-2026-10-05.md` ("Round 3 outcome").
Nothing was tuned, re-graded or rerun after scoring. Every figure below comes from the files in
`calibration/round3/`.

## What was frozen and run

- **Claims:** sha256 `0235c5bc81daa4e8ae1ce08109ce95a363631605b54ed8b7f87d85db81e374e8`
  (`graders.claims_sha256`), at PR #691 head `e436ed38`. The scoring ran from a separate checkout,
  which refused to start unless `HEAD` was exactly `e436ed38850b3385d2af74b7e01f6e158aab580b`. Every
  grading row carries this claims hash.
- **Judge:** `sonnet`, resolved id `claude-sonnet-5-5` on every judged output, with three ballots per
  judged verdict and a majority. There were no judge errors.
  - Arm P (`plain`) shows the judge the claims and the fields.
  - Arm R (`reference`) also shows the case's reference.
- **Method:**
  - `calibration.py grade` made 12 gradings: two arms, two runs, three sets.
  - `calibration.py metrics`, once per arm, gave `scored/metrics-plain.json` and
    `scored/metrics-reference.json`.
  - Intervals are 95%, given as Wilson low–high and then case-clustered bootstrap low–high.

**The fresh sets.** Each set was written blind to the grader. Each writer worked from
`cases-no-grader.jsonl` (the 35 cases without their graders). The files were hashed into
`blind2/hashes.txt` before any scoring, and the hashes still match.

| Set | Writer | Content | sha256 |
|---|---|---|---|
| `blind2/answers-d1.jsonl` | d1, Sonnet | 70 correct answers, 14 with a caveat | `e4b6b1525b7509ed74dec7936ca6e08e5caf30d95cf7743964ef3871347af210` |
| `blind2/answers-d2.jsonl` | d2, Codex | 70 correct answers, 18 with a caveat | `bedf89e97d408dc95980288dcc049e84f09e68d33c4b518ace59fcd980e9dea4` |
| `blind2/wrong-heldout.jsonl` | Codex | 140 wrong answers, one field corrupted, correct booleans: 35 retraction, 35 soft-hedge, 26 wrong-target, 25 negation, 19 mechanism | `0bc5a08b3c9b37bacdccdc52272d8cb89fd1c285d868c9be6c0323f92b3b9698` |
| `blind2/adversarial.jsonl` | Opus | 140 transforms, 35 each: echo-soup, kitchen-sink, padded-wrong, soft-hedge | `e58819546c7f94b651888fccebf9104b08b3a62e9f267b57b4d5d59a3fea0f1f` |
| `blind2/cases-no-grader.jsonl` | | the writers' input | `09f7f576333fc2a05decc7570c752687cf295b3d537256645e9feb19e0d53194` |

**Derived for scoring** (`scored/derived-hashes.txt`). Both derived files are pure renames; the
contents are otherwise identical:
- `scored/answers-d.jsonl` is d1 followed by d2, with `caveat` renamed `hedged`. sha256 `7f025ad5…`.
- `scored/adversarial.jsonl` renames `style` to `kind`. sha256 `bc663764…`.

The gradings record these hashes as `answers_sha256`. The wrong set was scored as written.

**Adjudication, blind and before scoring.** A blind adjudicator labelled each pair of held-out wrong
answer and the frozen claim it targets, before any judge call. The labels are in
`blind2-labels.jsonl` (sha256 `80cefafd8a68d17dd1e369b819d161730320ce3cccaac1bb87967bd27b03ca73`). There
are 148 labels over the 140 answers:

| Label | Judge claims | Programmatic claims | Total |
|---|---|---|---|
| COVERED | 112 | 16 | 128 |
| AMBIGUOUS | 10 | 0 | 10 |
| UNCOVERED | 10 | 0 | 10 |

## Bars

The bars were pre-registered in round 3 of `council-2026-10-05.md`. Cells give run 1 / run 2.

| Bar | P (plain) | R (reference) | Result |
|---|---|---|---|
| Claim failures on `answers-d` (140): ≤ 5%, upper bound ≤ 8% | 1.9% (0.9–3.9; 0.8–3.2) / 2.4% (1.3–4.6; 1.1–4.1) | 1.1% (0.4–2.8; 0.3–2.2) / 1.1% (0.4–2.8; 0.3–2.2) | pass |
| No decision or gate failure on `answers-d` | 1 / 1 | 1 / 1 | **fail** |
| COVERED judge claims passed: upper bound ≤ 10%, n ≥ 120 (n = 112) | 14.3% (9.0–22.0; 9.2–19.6) / 16.1% (10.4–24.0; 11.1–21.1) | 12.5% (7.6–19.9; 7.8–17.2) / 12.5% (7.6–19.9; 7.8–17.2) | **fail** |
| Soft-hedge: point estimate ≤ 10% | 43.3% / 46.7% | 40.0% / 40.0% | **fail** |
| Wrong-target: point estimate ≤ 10% | 16.7% / 16.7% | 11.1% / 11.1% | **fail** |
| COVERED programmatic claims passed: 0 | 8 / 8 | 8 / 8 | **fail** |
| Wrong answers at 100%: ≤ 5%, upper bound ≤ 10% | 20.7% (14.8–28.2; 15.7–25.7) / 22.1% (16.1–29.7; 17.1–27.1) | 19.3% (13.6–26.6; 14.3–24.3) / 20.7% (14.8–28.2; 15.7–25.7) | **fail** |
| Coverage: ≥ 95% of wrong answers with a COVERED claim | 89.3% (83.1–93.4; 82.9–95.0) | 89.3% | **fail** |
| Adversarial: ≤ `oracle_booleans` (23.8%) + 2 points, and ≤ 25% | kitchen-sink 35.5% / 34.0% | kitchen-sink 34.0% / 33.8% | **fail** |
| Score change between gradings ≤ `min_gain` / 2 (0.025), with no gate split on the correct set | at most 0.0077, no split | at most 0.0048, no split | pass |

The bar on COVERED programmatic passes is not in the outcome table in `council-2026-10-05.md`. It
fails too, and it does not change the decision.

## False negatives (`answers-d`, 140 correct answers)

| Grading | Mean score | At 100% | Claim failures | Judge claims | Programmatic claims | Not hedged (108) | Hedged (32) | d1 | d2 |
|---|---|---|---|---|---|---|---|---|---|
| P run 1 | 97.8% | 133 | 7/368 | 6/224, 2.7% (1.2–5.7; 0.9–4.8) | 1/144 | 6/281, 2.1% | 1/87, 1.1% | 2/184 | 5/184 |
| P run 2 | 97.2% | 131 | 9/368 | 8/224, 3.6% (1.8–6.9; 1.3–6.4) | 1/144 | 8/281, 2.8% | 1/87, 1.1% | 2/184 | 7/184 |
| R run 1 | 98.7% | 136 | 4/368 | 3/224, 1.3% (0.5–3.9; 0.0–2.9) | 1/144 | 4/281, 1.4% | 0/87 | 0/184 | 4/184 |
| R run 2 | 98.6% | 136 | 4/368 | 3/224, 1.3% (0.5–3.9; 0.0–3.0) | 1/144 | 4/281, 1.4% | 0/87 | 0/184 | 4/184 |

Claims that failed a correct answer, counted over the four gradings:

| Case / claim | Kind | P1 | P2 | R1 | R2 |
|---|---|---|---|---|---|
| cite-the-symbol / symbol-form-no-line (a gate) | programmatic | 1 | 1 | 1 | 1 |
| flat-shadow-four-paws / single-line | judge | 1 | 1 | 1 | 1 |
| typed-array-ternary / untyped-branch-fails | judge | 1 | 1 | 1 | 1 |
| check-only-exit-zero / explains-stderr | judge | 1 | 1 | 1 | |
| typed-array-new-literal / names-missing-conversion | judge | 1 | 1 | | 1 |
| canary-pins-the-rule / invariant-rationale | judge | 1 | 2 | | |
| hand-written-vigil-json / silent-blank | judge | 1 | | | |
| borrowed-shader-const-markers / names-splice | judge | | 1 | | |
| rebuild-before-verifying-the-shell / verify-geometry | judge | | 1 | | |

**The gate failure is a defect in a programmatic claim.** It is the same answer in every grading:
`answers-d` line 107, writer d2. The answer cites ``` ``presentation/combat/enemy_view.gd``
(``_update_shadow``) ``` in double backticks. The `symbol-form-no-line` pattern expects one backtick
after `enemy_view.gd`, then the bracket, so it rejects a correct citation.

## False positives (`wrong-heldout`, 140 wrong answers)

COVERED judge claims passed, by kind:

| Kind | n | P run 1 | P run 2 | R run 1 | R run 2 |
|---|---|---|---|---|---|
| soft-hedge | 30 | 13, 43.3% (27.4–60.8; 26.7–60.0) | 14, 46.7% (30.2–63.9; 30.0–64.5) | 12, 40.0% (24.6–57.7; 24.1–56.7) | 12, 40.0% |
| wrong-target | 18 | 3, 16.7% (5.8–39.2; 0.0–33.3) | 3, 16.7% | 2, 11.1% (3.1–32.8; 0.0–27.8) | 2, 11.1% |
| mechanism | 16 | 0 | 1, 6.2% (1.1–28.3; 0.0–20.0) | 0 | 0 |
| negation | 18 | 0 | 0 | 0 | 0 |
| retraction | 30 | 0 | 0 | 0 | 0 |
| **all** | **112** | **16, 14.3%** | **18, 16.1%** | **14, 12.5%** | **14, 12.5%** |

Every COVERED judge claim was judged. None was settled by a gate first.

Wrong answers that scored 100%, by kind:

| Kind | Answers | P run 1 | P run 2 | R run 1 | R run 2 |
|---|---|---|---|---|---|
| soft-hedge | 35 | 16 (45.7%) | 17 (48.6%) | 15 (42.9%) | 15 (42.9%) |
| wrong-target | 26 | 7 (26.9%) | 7 (26.9%) | 6 (23.1%) | 6 (23.1%) |
| mechanism | 19 | 2 (10.5%) | 4 (21.1%) | 1 (5.3%) | 2 (10.5%) |
| negation | 25 | 2 (8.0%) | 2 (8.0%) | 3 (12.0%) | 3 (12.0%) |
| retraction | 35 | 2 (5.7%) | 1 (2.9%) | 2 (5.7%) | 3 (8.6%) |
| **all** | **140** | **29 (20.7%)** | **31 (22.1%)** | **27 (19.3%)** | **29 (20.7%)** |

The mean score of the wrong set was 63.3% / 64.0% (P) and 62.4% / 62.9% (R).

**COVERED programmatic passes.** The same 8 answers pass in every grading, since programmatic
verdicts do not depend on the judge. Each names the right target, but the same field also hedges,
retracts or negates it:

| Line | Case / claim | Kind | The corrupted field |
|---|---|---|---|
| 0 | check-only-exit-zero / names-the-repo-gate | soft-hedge | check_scripts.sh, "though ... --check-only ... would also suffice" |
| 1 | check-only-exit-zero / names-the-repo-gate | retraction | check_scripts.sh, "actually, rely solely on the exit status" |
| 3 | check-only-exit-zero / names-the-repo-gate | negation | "Do not run tools/check_scripts.sh" |
| 44 | half-size-times-scale / keeps-half-size | soft-hedge | the right line, with a comment that "multiplying by born also works" |
| 60 | paired-calls-hit-player / right-heading-call | soft-hedge | `_hero.ward_hit(Vector2.RIGHT)`, with a comment that "LEFT would work equally well" |
| 61 | paired-calls-hit-player / right-heading-call | retraction | `_hero.ward_hit(Vector2.RIGHT)`, with a comment "Actually, use Vector2.LEFT" |
| 72 | cite-the-symbol / symbol-form-no-line | soft-hedge | the right citation, "though `_draw` ... would be an equally suitable symbol" |
| 73 | cite-the-symbol / symbol-form-no-line | retraction | the right citation, "actually, cite `_draw` in that file instead" |

The sibling patterns match a sibling only in its code form, such as `ward_hit(Vector2.LEFT` or
`* born`. They miss a sibling named in prose, and a field that names the target while saying not to
use it. Round 3 deliberately added no hedge-wording pattern.

## Coverage

125 of the 140 wrong answers (89.3%) have at least one COVERED claim. The adjudication labelled 10
pairs AMBIGUOUS and 10 UNCOVERED, all of them on judge claims. 112 COVERED judge claims fall short
of the 120 the false-positive bar needs.

## Adversarial transforms (140; `oracle_booleans` 23.8%)

| Transform | P run 1 | P run 2 | R run 1 | R run 2 |
|---|---|---|---|---|
| kitchen-sink | 35.5% | 34.0% | 34.0% | 33.8% |
| soft-hedge | 27.1% | 27.1% | 27.1% | 27.1% |
| echo-soup | 25.7% | 25.7% | 24.8% | 25.7% |
| padded-wrong | 25.7% | 25.7% | 25.7% | 24.8% |

The bar takes the lower of the two limits; at 23.8% + 2 points = 25.8%, the 25% cap binds.
- Kitchen-sink and soft-hedge exceed both limits in every grading.
- Echo-soup and padded-wrong stay within `oracle_booleans` + 2 points. Each exceeds 25% in three of
  the four gradings, at 25.7%.

## Stability (each set graded twice, three ballots each time)

| Arm / set | Judged verdicts paired | Majority flips | Ballots not unanimous | Gate splits | Score change |
|---|---|---|---|---|---|
| P / d | 224 | 4, 1.8% (0.7–4.5; 0.4–3.4) | 19/448, 4.2% | 0 | 0.0060 |
| P / wrong-heldout | 219 | 6, 2.7% (1.3–5.8; 0.9–4.9) | 21/438, 4.8% | 1 (line 20, canary-pins-the-rule / compares-to-truth) | 0.0077 |
| P / adversarial | 207 | 3, 1.4% (0.5–4.2; 0.0–3.7) | 10/414, 2.4% | 1 (line 21, the same claim) | 0.0036 |
| R / d | 224 | 2, 0.9% (0.2–3.2; 0.0–2.4) | 12/448, 2.7% | 0 | 0.0012 |
| R / wrong-heldout | 219 | 3, 1.4% (0.5–3.9; 0.0–3.0) | 11/438, 2.5% | 0 | 0.0048 |
| R / adversarial | 207 | 4, 1.9% (0.8–4.9; 0.5–4.0) | 14/414, 3.4% | 0 | 0.0006 |

The pre-registered gate-split bar covers the correct set. That set has none in either arm.

## Climb noise (unapproved)

One unapproved baseline: `sonnet` answering × 3 repetitions on the round-2 claims, with `sonnet`
judging in arm P. It was never offered to `approve-grader`; its summary is
`round3/noise-baseline-unapproved.json`.
- The mean was 64.7%.
- The test split's noise floor was **0.060** over 14 cases, against `min_gain` 0.05.
- The train split's was 0.081 over 21 cases.
- A climb therefore cannot detect a test-split gain of `min_gain`.

## Calls

The gradings imply 386 judged outputs per arm and run (136 on `answers-d`, 131 on the wrong set and
119 on the transforms). Over the four arm and run pairs, at three ballots each, that is 4,632 judge
calls. Every judged verdict carries exactly three ballots.

## Files (`calibration/round3/`)

- `blind2/`: the fresh sets as written, the writers' input and `hashes.txt`.
- `blind2-labels.jsonl`: the blind adjudication.
- `scored/`: the files as scored.
  - The two derived sets and `derived-hashes.txt`. It lists the scratch paths the scoring read from.
  - The 12 gradings `g-<arm>-<run>-<set>.jsonl`.
  - `metrics-plain.json` and `metrics-reference.json`.
- `noise-baseline-unapproved.json`: the climb-noise summary.

The sets are spent. They must not be reused to calibrate a later grader.

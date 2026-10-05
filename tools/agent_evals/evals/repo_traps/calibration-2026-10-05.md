# repo_traps: judge calibration, 5 October 2026

**Outcome: neither judge passes. No judge is chosen, `eval.json` is unchanged, and the grader is not
approvable on this evidence.** Both `haiku` and `sonnet` meet the false-negative bar and have no gate
failure on the correct sets. Both fail the false-positive, adversarial and flip-rate bars set in
`council-2026-10-05.md`. As that record requires, nothing was tuned or rerun after scoring.

## What was frozen and run

- Judge questions: sha256 `3d805fadb9d088f687fc2b5cd4ce7279739d6d8aa0dbfdfaec0ed55c98cfe719`
  (`graders.judge_questions_sha256`), at PR #691 head `d5a61d8b`. The grader, claims and thresholds
  are as committed there.
- Sets, single-use, hashed before scoring and now kept in `calibration/` as the record:

| Set | Content | sha256 |
|---|---|---|
| `answers-c.jsonl` | 70 correct answers, a third blind writer (cross-model); primary | `b1eb247e88c145a931dd167a28c7d3b4a491a6cee65e64b4eceb1e3cdeeccaf8` |
| `answers-a.jsonl` | 70 correct answers, blind set A (the regex rounds were tuned on it); secondary | `9451cd5291ad3a412c2befbe4a05c0b567b664984ff12bdb84e80dec38c85d08` |
| `answers-b.jsonl` | 70 correct answers, blind set B (never read by the grader's author); secondary | `1093cb7cabe2d255c1f87b8d63255e66dc35f25a795b831bdff644c07fb6fb25` |
| `wrong-answers.jsonl` | 70 minimal-pair wrong answers (one field corrupted, booleans correct) | `ec789241be0f70f7ae219a6a331c7ec3c7532c357113ef619547e7e1ee370a92` |

- The seven `answers-b` answers quoted to the council (lines 9, 10, 11, 32, 33, 41, 43; the answers the
  regex grader at `c6600d24` zeroed, recomputed from that commit) are reported apart.
- Adversarial: the frozen trivial-answerer set of the diagnostics (496 distinct answers), graded and
  then replayed through `diagnostics.trivial_answerer_scores` itself.
- Method: the real grader (`graders.grade`), the CLI judge backend, three judge calls per output with
  each claim taking the majority, 6 workers. Wilson 95% intervals are given as rate / low / high, in
  percent. "Targeted claims" are the claims on a wrong answer's `corrupted_field`. Per-output verdicts
  and ballots for the correct and wrong sets are in `calibration/verdicts-<judge>.jsonl`.
- Smoke test first (two cases, `haiku`): the CLI reports the resolved model in `modelUsage`, a single
  key, where the backend reads it. No plumbing change was needed.

## Thresholds

| Bar (council record) | haiku | sonnet |
|---|---|---|
| False negatives on c+a: ≤ 5%, upper bound ≤ 8% | 2.2% (1.1–4.3): **pass** | 1.4% (0.6–3.2): **pass** |
| No decision or gate failure on c+a (140 answers) | 0: **pass** | 0: **pass** |
| False positives: targeted-claim pass rate ≤ 10% at the upper bound | 44.0% (33.3–55.3): **fail** | 36.0% (26.1–47.3): **fail** |
| Adversarial: ≤ 25% and ≤ `oracle_booleans` + 2 points | 67.1%, +43.1 points: **fail** | 72.9%, +48.8 points: **fail** |
| Flip rate ≤ 3% | 8.4% (6.5–10.7) over all sets: **fail** | 5.2% (3.7–7.1) over all sets: **fail** |
| No gate flip on the correct sets | 0: **pass** | 0: **pass** |

## haiku (resolved id `claude-haiku-4-5-20251001`)

#### False negatives (correct answers)

| set | answers | judge errors | mean score | at 100% | decision/gate failures | claim failures | claim failure rate (95% Wilson) | judge-claim failures | programmatic failures |
|---|---|---|---|---|---|---|---|---|---|
| c | 70 | 0 | 96.7% | 65 | 0 | 5 of 182 | 2.7 / 1.2 / 6.3 | 5 | 0 |
| a | 70 | 0 | 97.9% | 67 | 0 | 3 of 182 | 1.6 / 0.6 / 4.7 | 3 | 0 |
| b (all 70) | 70 | 0 | 94.4% | 61 | 0 | 9 of 182 | 4.9 / 2.6 / 9.1 | 9 | 0 |
| b (63, without the seven quoted) | 63 | 0 | 93.8% | 54 | 0 | 9 of 165 | 5.5 / 2.9 / 10.0 | 9 | 0 |
| b (the seven quoted) | 7 | 0 | 100.0% | 7 | 0 | 0 of 17 | 0.0 / 0.0 / 18.4 | 0 | 0 |
| c+a pooled | 140 | 0 | 97.3% | 132 | 0 | 8 of 364 | 2.2 / 1.1 / 4.3 | 8 | 0 |

Per-claim failures on c+a (claims that failed at least once; each claim is seen 4 times):

| case / claim | kind | failed |
|---|---|---|
| dom-pile-keep-nodes / interactivity-reason | judge | 2 of 4 |
| funplay-32000 / curl-or-listener | judge | 2 of 4 |
| get-global-rect-is-not-the-trap / measure-first | judge | 1 of 4 |
| renderer-noise-is-not-a-failure / cites-noise | judge | 1 of 4 |
| shared-helper-blast-radius / checks-reach | judge | 1 of 4 |
| stochastic-capture-gate / deterministic-gate | judge | 1 of 4 |

#### False positives (minimal-pair wrong answers; targeted claims are the claims on the corrupted field)

| kind | wrong answers | targeted claims | passed | pass rate (95% Wilson) | wrong answers at 100% |
|---|---|---|---|---|---|
| hedge | 4 | 4 | 2 | 50.0 / 15.0 / 85.0 | 2 |
| mechanism | 18 | 19 | 4 | 21.1 / 8.5 / 43.3 | 3 |
| negation | 20 | 19 | 7 | 36.8 / 19.1 / 59.0 | 8 |
| wrong-target | 28 | 33 | 20 | 60.6 / 43.7 / 75.3 | 15 |
| all | 70 | 75 | 33 | 44.0 / 33.3 / 55.3 | 28 |

(15 targeted verdicts were settled by program before the judge; 0 wrong answers hit a judge error.)

#### Adversarial (the frozen trivial-answerer set, replayed through `trivial_answerer_scores`)

| answerer | score |
|---|---|
| padded_oracle | 67.1% |
| padded_true | 40.0% |
| padded_false | 37.6% |
| hedge_oracle | 26.4% |
| oracle_booleans | 24.0% |
| echo_oracle | 24.0% |
| soup_oracle | 24.0% |
| compact_soup_oracle | 24.0% |
| case_soup_oracle | 24.0% |
| keyword_run_oracle | 24.0% |
| hedge_false | 14.3% |
| constant_true | 12.1% |
| echo_true | 12.1% |
| soup_true | 12.1% |
| compact_soup_true | 12.1% |
| case_soup_true | 12.1% |
| hedge_true | 12.1% |
| keyword_run_true | 12.1% |
| constant_false | 11.9% |
| echo_false | 11.9% |
| soup_false | 11.9% |
| compact_soup_false | 11.9% |
| case_soup_false | 11.9% |
| keyword_run_false | 11.9% |
| injected_false | 1.0% |
| injected_oracle | 1.0% |
| empty | 0.0% |
| injected_true | 0.0% |

maximum 67.1% (padded_oracle); margin over oracle_booleans 43.1 points; judge errors 0

#### Reproducibility (three ballots per judged claim)

| set | judged verdicts | split (not unanimous) | flip rate (95% Wilson) | gate verdicts split |
|---|---|---|---|---|
| c | 110 | 7 | 6.4 / 3.1 / 12.6 | 0 |
| a | 110 | 5 | 4.5 / 2.0 / 10.2 | 0 |
| b | 110 | 17 | 15.5 / 9.9 / 23.4 | 0 |
| wrong | 108 | 11 | 10.2 / 5.8 / 17.3 | 0 |
| trivial | 240 | 17 | 7.1 / 4.5 / 11.0 | 2 |

All sets: 57 of 678 judged verdicts split (8.4 / 6.5 / 10.7).

#### Infrastructure

- judge calls: 1191; errors: 0; timeouts: 0; truncated: 0
- outputs with a judge error: 0 of 776 graded
- model ids seen: {'claude-haiku-4-5-20251001': 1191}
- seconds per call: mean 10.6, max 66.0; wall time 35.4 min at 6 workers


## sonnet (resolved id `claude-sonnet-5-5`)

#### False negatives (correct answers)

| set | answers | judge errors | mean score | at 100% | decision/gate failures | claim failures | claim failure rate (95% Wilson) | judge-claim failures | programmatic failures |
|---|---|---|---|---|---|---|---|---|---|
| c | 70 | 0 | 97.6% | 66 | 0 | 4 of 182 | 2.2 / 0.9 / 5.5 | 4 | 0 |
| a | 70 | 0 | 99.3% | 69 | 0 | 1 of 182 | 0.5 / 0.1 / 3.0 | 1 | 0 |
| b (all 70) | 70 | 0 | 97.5% | 65 | 0 | 5 of 182 | 2.7 / 1.2 / 6.3 | 5 | 0 |
| b (63, without the seven quoted) | 63 | 0 | 97.8% | 59 | 0 | 4 of 165 | 2.4 / 0.9 / 6.1 | 4 | 0 |
| b (the seven quoted) | 7 | 0 | 95.2% | 6 | 0 | 1 of 17 | 5.9 / 1.0 / 27.0 | 1 | 0 |
| c+a pooled | 140 | 0 | 98.5% | 135 | 0 | 5 of 364 | 1.4 / 0.6 / 3.2 | 5 | 0 |

Per-claim failures on c+a (claims that failed at least once; each claim is seen 4 times):

| case / claim | kind | failed |
|---|---|---|
| label-box-from-font-metrics / measures | judge | 3 of 4 |
| check-only-exit-zero / explains-stderr | judge | 1 of 4 |
| shared-helper-blast-radius / checks-reach | judge | 1 of 4 |

#### False positives (minimal-pair wrong answers; targeted claims are the claims on the corrupted field)

| kind | wrong answers | targeted claims | passed | pass rate (95% Wilson) | wrong answers at 100% |
|---|---|---|---|---|---|
| hedge | 4 | 4 | 1 | 25.0 / 4.6 / 69.9 | 1 |
| mechanism | 18 | 19 | 5 | 26.3 / 11.8 / 48.8 | 4 |
| negation | 20 | 19 | 4 | 21.1 / 8.5 / 43.3 | 4 |
| wrong-target | 28 | 33 | 17 | 51.5 / 35.2 / 67.5 | 11 |
| all | 70 | 75 | 27 | 36.0 / 26.1 / 47.3 | 20 |

(15 targeted verdicts were settled by program before the judge; 0 wrong answers hit a judge error.)

#### Adversarial (the frozen trivial-answerer set, replayed through `trivial_answerer_scores`)

| answerer | score |
|---|---|
| padded_oracle | 72.9% |
| padded_true | 45.2% |
| padded_false | 42.4% |
| hedge_oracle | 37.9% |
| oracle_booleans | 24.0% |
| echo_oracle | 24.0% |
| soup_oracle | 24.0% |
| compact_soup_oracle | 24.0% |
| case_soup_oracle | 24.0% |
| keyword_run_oracle | 24.0% |
| hedge_true | 22.1% |
| hedge_false | 21.4% |
| constant_true | 12.1% |
| echo_true | 12.1% |
| soup_true | 12.1% |
| compact_soup_true | 12.1% |
| case_soup_true | 12.1% |
| keyword_run_true | 12.1% |
| constant_false | 11.9% |
| echo_false | 11.9% |
| soup_false | 11.9% |
| compact_soup_false | 11.9% |
| case_soup_false | 11.9% |
| keyword_run_false | 11.9% |
| injected_false | 1.0% |
| injected_oracle | 1.0% |
| empty | 0.0% |
| injected_true | 0.0% |

maximum 72.9% (padded_oracle); margin over oracle_booleans 48.8 points; judge errors 0

#### Reproducibility (three ballots per judged claim)

| set | judged verdicts | split (not unanimous) | flip rate (95% Wilson) | gate verdicts split |
|---|---|---|---|---|
| c | 110 | 2 | 1.8 / 0.5 / 6.4 | 0 |
| a | 110 | 3 | 2.7 / 0.9 / 7.7 | 0 |
| b | 110 | 14 | 12.7 / 7.7 / 20.2 | 0 |
| wrong | 108 | 8 | 7.4 / 3.8 / 13.9 | 1 |
| trivial | 240 | 8 | 3.3 / 1.7 / 6.4 | 0 |

All sets: 35 of 678 judged verdicts split (5.2 / 3.7 / 7.1).

#### Infrastructure

- judge calls: 1191; errors: 0; timeouts: 0; truncated: 0
- outputs with a judge error: 0 of 776 graded
- model ids seen: {'claude-sonnet-5-5': 1191}
- seconds per call: mean 3.7, max 11.9; wall time 12.4 min at 6 workers


## What the evidence says (observations, not changes)

- **False positives have two sources.** On the targeted claims, programmatic checks passed 8 of 15
  for both judges, all `wrong-target` corruptions in code (`_reward_choices()` for
  `_bequest_choices()`, `_discard_pile` for `_draw_pile`). The code claims check shape, not which
  target is named, so no judge can fix those. The judge passed 25 of 60 (haiku) and 19 of 60
  (sonnet). It credited negations (`raw == fields()` for the required `!=`), mechanisms swapped
  within an otherwise correct sentence, and corruptions to a detail the claim's question does not
  name (a different test file, scratch saves for the real saves).
- **The adversarial maximum is the padding probe, and the probe is flawed.** As built in
  `trivial_answers`, `padded` is the full reference followed by the case soup. It therefore contains
  every correct statement, and a judge that reads it correctly credits it. It measures nothing about
  leniency. Without it, the maximum is the hedge (the reference followed by "Or perhaps the opposite
  is true, and none of this applies"). That gives haiku 26.4% (+2.4 points) and sonnet 37.9%
  (+13.9 points), so both still fail. A single generic negation after the reference is not read as
  retracting the reference's statements.
- **Flips concentrate in set B.** The rates are haiku 15.5% and sonnet 12.7% there, against
  1.8–6.4% on sets c and a. On the correct sets no gate verdict split.
- **Infrastructure was clean.** Neither judge had an error, timeout or truncation, and each reported
  one model id throughout.

## Cost

| Judge | Judge calls | Wall time (6 workers) | Seconds per call (mean, max) |
|---|---|---|---|
| smoke (haiku, 2 outputs) | 6 | 1.4 min (sequential) | 14.1, – |
| haiku | 1,191 | 35.4 min | 10.6, 66.0 |
| sonnet | 1,191 | 12.4 min | 3.7, 11.9 |
| total | 2,388 | about 49 min | |

Each run graded 776 outputs: 280 from the four sets and 496 distinct trivial answers. Outputs whose
programmatic gate failed made no call.

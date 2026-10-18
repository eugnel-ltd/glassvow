# Frozen #694 programmatic calibration: FAIL

Candidate `014f58ba3c4a62bbb3c41e19944caae6df47a81d`; 1,040 answers over 80 cases, each graded twice offline. All candidate, answer, label and protocol hashes were verified before grading and remained unchanged.

Both runs produced the same result. Every adversarial transform scored mean **0.075**, exceeding the **0.02** limit (oracle booleans = 0). Each satisfies the separate 0.25 cap. This failed bar prevents acceptance of the candidate.

| Bar | Measured result | Verdict |
|---|---|---|
| Correct decision/gate failures | 0/320 | PASS |
| Correct claim false negatives | 2/552 = 0.362%; Wilson 95% [0.099%, 1.311%]; case-clustered [0%, 1.172%] | PASS |
| Hedged correct claim false negatives | 1/276 = 0.362%; Wilson 95% [0.064%, 2.023%]; case-clustered [0%, 1.172%] | PASS |
| COVERED programmatic claims passing wrong answers | 0/332 | PASS |
| Wrong answers scoring 100% | 0/320; Wilson upper 1.186%; case-clustered [0%, 0%] | PASS |
| Wrong-answer scored coverage | 320/320; Wilson lower 98.814%; case-clustered [100%, 100%] | PASS |
| Adversarial mean ≤ oracle + 0.02 | Every transform: 0.075 > 0.02 | FAIL |
| Adversarial mean ≤ 0.25 | Every transform: 0.075 | PASS |
| Deterministic test/retest | 0/1,040 changed outcomes; 0/1,794 changed scored-claim verdicts; mean score change 0 | PASS |

The two sub-100 correct answers share one non-gate claim: see `metrics.json` under `plain/correct/run1/all/under_100`. They remain frozen; no answer or claim has been revised.

| Transform | Answers | Mean | 95% case-clustered interval |
|---|---:|---:|---|
| echo | 80 | 0.075 | [0.0354, 0.1208] |
| kitchen-sink | 80 | 0.075 | [0.0354, 0.1208] |
| padded-wrong | 80 | 0.075 | [0.0354, 0.1208] |
| soft-hedge | 80 | 0.075 | [0.0354, 0.1208] |
| soup | 80 | 0.075 | [0.0354, 0.1208] |

All four wrong-answer kinds have 80/80 covered answers and 0/80 scoring 100%; per-kind Wilson and case-clustered intervals are in `summary.json`. Labels: 552 pairs, 332 COVERED, 220 UNCOVERED, 0 AMBIGUOUS.

Judge false-positive and ballot-flip bars are not applicable because no scored judge claims exist. No external model, approval or hill-climb ran. Actual isolated Sonnet ×3 and current-hash approvals remain outstanding. These single-use answer sets are now spent.

Reproduction: `run_calibration.py` captures exact CLI commands and hashes in `preflight.json`, `commands.json` and `postflight.json`; `summarise.py` adds pre-registered bars and whole-case bootstrap intervals using 2000 resamples and seed 20261004. Existing grading outputs are never overwritten.

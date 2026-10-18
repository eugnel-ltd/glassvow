# Frozen #694 programmatic calibration: PASS

Candidate `7a164ad943fa13d8d56adc91efffb09efe147317`; 1,040 fresh answers over 80 cases, each graded twice offline. The exact-head independent audit approved this candidate before its fresh writers were commissioned. Every input, label, protocol and candidate source hash was verified before and after grading. The predecessor preservation manifest verified 87 files before and after scoring; the 014f failed campaign remains unchanged and spent.

Both runs satisfy every pre-registered programmatic bar. No correct answer failed a gate or claim; every adversarial transform scored zero, equal to the boolean-only oracle.

| Bar | Measured result in each run | Verdict |
|---|---|---|
| Correct decision/gate failures | 0/320 | PASS |
| Correct claim false negatives ≤5%, Wilson upper ≤8% | 0/552 = 0.000%; Wilson 95% [0.000%, 0.691%]; case-clustered [0.000%, 0.000%] | PASS |
| Hedged correct claim false negatives (reported separately) | 0/276 = 0.000%; Wilson 95% [0.000%, 1.373%]; case-clustered [0.000%, 0.000%] | Reported |
| COVERED programmatic claims passing wrong answers | 0/333 | PASS |
| Wrong answers scoring 100% ≤5%, Wilson upper ≤10% | 0/320 = 0.000%; Wilson 95% [0.000%, 1.186%]; case-clustered [0.000%, 0.000%] | PASS |
| Wrong-answer scored coverage ≥95% | 320/320 = 100.000%; Wilson 95% [98.814%, 100.000%]; case-clustered [100.000%, 100.000%] | PASS |
| Every adversarial mean ≤ oracle +0.02 and ≤0.25 | Every mean 0; oracle 0 | PASS |
| Deterministic test/retest | 0/1,040 changed outcomes; 0/1,794 changed scored-claim verdicts; mean score change 0 | PASS |

| Transform | Answers per run | Mean | 95% case-clustered mean interval |
|---|---:|---:|---|
| echo | 80 | 0.000 | [0.0000, 0.0000] |
| kitchen-sink | 80 | 0.000 | [0.0000, 0.0000] |
| padded-wrong | 80 | 0.000 | [0.0000, 0.0000] |
| soft-hedge | 80 | 0.000 | [0.0000, 0.0000] |
| soup | 80 | 0.000 | [0.0000, 0.0000] |

All four wrong-answer kinds have 80/80 covered answers and 0/80 scoring 100%; per-kind Wilson and case-clustered intervals are in `summary.json`. Labels: 552 pairs, 333 COVERED, 219 UNCOVERED, 0 AMBIGUOUS. No scored or report-only judge backend was constructed; judge false-positive/ballot-flip bars are not applicable.

The writers disclosed limitations in the pinned source context. Writer A inferred `plain_arrays`, `raw_differs_from_trusted` and `settle_frames=2` from the prompts/options. Writer B identified ten context gaps (engine storage, LayoutBook.fields, deferred-frame policy, profile fallback, shader helpers, profile configuration, locale transactions, serialization, capture CLI and the stop record). Full case IDs and provenance are in `writer-limitations.json`. Both stayed within the frozen packet. Their declared roles and answer bytes remain unchanged; the observed grades do not independently establish the missing source facts.

This result does not supply the separate actual isolated Sonnet ×3 baseline, resolved model identity, noise below min_gain 0.05, current-hash inputs/grader approvals, or hill-climb authorisation. No external model call, approval, source change or GitHub write was performed. The fresh sets are now spent.

`run_calibration.py` records the exact CLI commands and hashes in `preflight.json`, `commands.json` and `postflight.json`; `summarise.py` adds the pre-registered bars, per-kind rates and whole-case bootstrap intervals using 2000 resamples and seed 20261004. Each grading is written once and never overwritten.

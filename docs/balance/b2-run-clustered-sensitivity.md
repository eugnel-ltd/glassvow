# B2 whole-run sensitivity

`balance_readout.py rowb` and `table` can report B2's run-clustered sensitivity beside the existing Wilson intervals. This implements the reporting follow-up in [#544](https://github.com/eugnel-ltd/glassvow/issues/544#issuecomment-6099851819) and [#661](https://github.com/eugnel-ltd/glassvow/issues/661). Wilson remains the method of record under the [Ashwarden lock](../design/2026-10-05-ash-flame/README.md), §10. Adoption for both classes at A9 needs its own recorded method ruling.

Use existing merged report directories and the catalogue they were measured on:

```sh
python3 -B tools/balance_readout.py rowb REPORT_DIR --aspect ashwarden --content CONTENT_JSON --b2-sensitivity
python3 -B tools/balance_readout.py rowb REPORT_DIR --aspect duskblade --content CONTENT_JSON --b2-sensitivity
python3 -B tools/balance_readout.py table V0_DIR V5_DIR --v0-seeds 13000-13999 --v5-seeds 13000-14999 --aspect ashwarden --content CONTENT_JSON --b2-sensitivity
```

These commands read reports; they do not launch the simulator. The output adds the run-cluster count, expression and close-call intervals, and a separate B2 sensitivity verdict. Existing B1 and B2 Wilson columns and thresholds are unchanged. `--ref` adds the existing Wilson reference verdicts; sensitivity applies to the current directory. `--tidy` omits row B and therefore refuses `--b2-sensitivity`.

The frozen record specifies 2,000 resamples of whole runs ([Ash readout A1](../design/2026-10-05-ash-flame/readouts/readout-a1.md), *Row B*). The seed, percentile interpolation and undefined-denominator policy below are explicit prospective tooling choices. They do not reconstruct the scratch bootstrap that produced historical figures.

1. Keep each aspect, vow, pool and arm report separate. Require the manifest's complete `aspect`, `vow`, `pool`, `way` and `build` identity to match the requested class, cell and arm; missing or conflicting identity is rejected even when the content hash matches. Read `runs`; each cluster is one report row identified by its unique integer simulation `seed`. Sort those seeds before sampling, so report-row order has no effect. The bootstrap seed is separate from these simulation seeds.
2. Require aligned `fights` and `flame.fights` arrays for every run. Count expression with the grader's coloured-play rule over the class's ways: the committed arm's way, or the adaptive arm's dominant way at the fight's start. Count close calls only among fights whose result is `win`, with ending HP strictly below 20%, using the grader's `max(1, maxHp)` convention. The run's final outcome does not exclude its earlier won fights.
3. For each of 2,000 resamples, sample the original number of whole runs with replacement, using Python's `random.Random` with seed `0` by default. Sum the selected runs' counts, then divide total expressed fights by total fights and total close calls by total won fights. Both metrics use the same selected runs. This is a ratio of pooled counts, not a mean of per-run rates.
4. Report the original pooled point. Sort the resampled ratios and linearly interpolate the 2.5th and 97.5th percentiles at index `(n - 1) * p`. `--b2-seed INTEGER` selects another bootstrap seed; every sensitivity output prints its seed, resample count and method. Use the same seed and Python runtime to reproduce exact resamples.
5. If the original denominator is zero, show an unavailable point. If any resample has a zero denominator, show its count and mark that metric's interval non-estimable. Do not drop undefined samples, redraw them or replace them with zero. Either non-estimable metric forces the separate B2 sensitivity verdict to `UNDECIDED`. Otherwise apply the unchanged B2 thresholds: expression ≥60%, close calls within 1–10%, using the same interval grading rules as Wilson.

Duplicate or non-integer run seeds, misaligned arrays, malformed fight results, invalid HP fields and non-finite or negative play weights are rejected with the report and seed context. Synthetic fixtures test these contracts, unequal run lengths, correlated fight duplication, class grouping and reproducibility; they provide no gameplay, calibration or raw-A3 research evidence.

Run the governed Python entry point, which includes the immutable old-red regression and the statistical fixtures:

```sh
python3 -B tests/test_balance_readout.py
```

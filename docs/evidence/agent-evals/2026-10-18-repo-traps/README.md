# Repo traps: measured programmatic evidence

Issue #694 remains open. These immutable summaries and recovery archives record two
separate offline campaigns, each with 1,040 answers over 80 cases, graded twice.

| Measured head | Result | Decisive observation |
|---|---|---|
| `014f58ba3c4a62bbb3c41e19944caae6df47a81d` | [FAIL](RESULT-014f58ba.md) | Each adversarial mean was 0.075, above oracle +0.02. |
| `7a164ad943fa13d8d56adc91efffb09efe147317` | [PASS](RESULT-7a164ad9.md) | All programmatic bars passed; no correct gate/claim failure, no COVERED false positive, 100% wrong coverage and zero adversarial means. |

The later CI wiring and documentation commits do not relabel these measured heads.
The `tools/agent_evals` tree measured at `7a164ad9` is
`28b408716596b387f953b7d567b383a20d270a3d`; it remains unchanged by those additions.
The agent surface, cases, claims, split, answers, labels and protocol also remain
unchanged. This identity carries the programmatic evidence only. Historical approvals
and metrics have not been amended, and no spent set has been regraded.

The five copied artifacts are listed in [HASHES.json](HASHES.json), with their exact
SHA256 and byte size. That file also records each campaign's measured head and frozen
cases, claims, split, four answer sets, labels, scored-claim specification and protocol
hashes. The three archives total 278,266 bytes and were copied without repacking:

- `694-calibration-014f58ba.tar.gz`: original failed gradings, metrics, commands,
  preflight/postflight and diagnosis. Its preflight retains the old answer hashes;
  this historical archive does not include the old answer bodies.
- `694-calibration-7a164ad9.tar.gz`: passing gradings and metrics, exact commands,
  frozen writer packet, answer sets, adjudication labels, protocol, source hashes,
  independent audit and writer-limitations record.
- `694-adjudication-labels-both-campaigns.tar.gz`: both campaigns' immutable labels
  and scored-claim specifications, plus their recovery manifest.

Writer independence does not establish every task-source fact. Correct writer A
disclosed inferring `plain_arrays`, `raw_differs_from_trusted` and `settle_frames=2`
from the prompts/options. Writer B disclosed ten source-context gaps covering engine
storage, the trusted reader, frame policy, profile fallback/configuration, shader
helpers, locale transactions, serialisation, capture CLI and the stop record. Both
stayed within the frozen packet; their answers and declared roles remain unchanged.
The passing archive's `writer-limitations.json` records the exact case IDs. The
observed grades do not independently validate those missing source facts.

Both campaigns' sets are spent. No external judge call or additional calibration
was used to prepare this evidence record. Outstanding work includes a genuine
isolated Sonnet baseline with three repetitions, resolved model identity and test
noise below `min_gain` 0.05, then the authorised current-hash inputs/grader approval
path. This record supplies no approval, hill-climb authority, full CI result or
claim that #694 or #672 is complete.

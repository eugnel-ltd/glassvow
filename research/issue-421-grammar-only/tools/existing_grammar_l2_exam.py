#!/usr/bin/env python3
"""One-shot preflight, execution and frozen analysis for the L1/L2 exam."""

from __future__ import annotations

import hashlib
import json
import math
import random
import subprocess
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = "c28ae38824f7ba2168b573002ab8b90dadd5bde1"
PROTOCOL_ID = "existing-grammar-l1-l2-v1"
PROTOCOL = ROOT / "research/issue-421-grammar-only/protocols/existing-grammar-l1-l2-v1.json"
PROTOCOL_SHA = PROTOCOL.with_suffix(".sha256")
RUNNER = "res://research/issue-421-grammar-only/tools/existing_grammar_l2_rows.gd"
PREFLIGHT = Path("/tmp/glassvow-421-l2-preflight.jsonl")
PREFLIGHT_LOG = Path("/tmp/glassvow-421-l2-preflight.log")
RAW = Path("/tmp/glassvow-421-l2-raw.jsonl")
COHORT_LOG = Path("/tmp/glassvow-421-l2-cohort.log")
MARKER = Path("/tmp/glassvow-421-l2-start-marker.json")
RESULT = Path("/tmp/glassvow-421-l2-result.json")
STATUS = Path("/tmp/glassvow-421-l2-status.json")
REPORT = Path("/tmp/glassvow-421-l2-report.md")
EXPECTED_DIGEST = "b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf"
ARMS = ("L1", "L2")
VOWS = (0, 5)
POLICIES = ("competent", "RandomBuild")
SEEDS = tuple(range(7000, 7256))
CARDS = ("resonantLance", "quakeblow", "shardstorm", "flawlessForm")
RELICS = ("bellOfEndings", "prismCharm")
ACTIVATIONS = {
    "resonantLance": "resonantLancePlayed",
    "quakeblow": "quakeblowPlayed",
    "shardstorm": "shardstormPlayed",
    "flawlessForm": "flawlessFormPlayed",
    "bellOfEndings": "bellOfEndingsProcs",
    "prismCharm": "prismCharmProcs",
}
CONSUMERS = tuple(key for key in ACTIVATIONS if key != "quakeblow")


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def _json_write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n")


def _load_lines(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _overlap(left: list[int], right: list[int]) -> bool:
    return max(left[0], right[0]) <= min(left[1], right[1])


def _identity() -> tuple[dict, str, list[str]]:
    protocol_sha = _sha(PROTOCOL)
    assert PROTOCOL_SHA.read_text().split()[0] == protocol_sha, "protocol SHA sidecar mismatch"
    protocol = json.loads(PROTOCOL.read_text())
    assert protocol["protocolId"] == PROTOCOL_ID, "protocol identity mismatch"
    assert protocol["identities"]["sourceBase"] == BASE, "source base mismatch"
    assert protocol["arms"]["L1"]["unlocks"] == [
        "aspect2", "card:quakeblow", "card:resonantLance"], "L1 arm drifted"
    assert protocol["arms"]["L2"]["unlocks"] == [
        "aspect2", "card:quakeblow", "card:resonantLance", "card:shardstorm",
        "relic:bellOfEndings", "card:flawlessForm", "relic:prismCharm"], "L2 arm drifted"
    lock = protocol["authority"]["bindingLock"]
    assert _sha(Path(lock["path"])) == lock["sha256"], "binding-lock SHA mismatch"
    assert subprocess.check_output(
        ["git", "-C", lock["worktree"], "rev-parse", "HEAD"], text=True).strip() == lock["commit"], \
        "binding-lock commit mismatch"
    assert subprocess.check_output(
        ["git", "-C", lock["worktree"], "rev-parse", "HEAD^"], text=True).strip() == lock["parent"], \
        "binding-lock parent mismatch"
    prior = protocol["authority"]["immutableL1Packet"]
    assert subprocess.check_output(
        ["git", "-C", prior["worktree"], "rev-parse", "HEAD"], text=True).strip() == prior["head"], \
        "immutable L1 packet head mismatch"
    assert _sha(Path(prior["protocolPath"])) == prior["protocolSha256"], \
        "immutable L1 protocol SHA mismatch"
    assert _git("status", "--porcelain") == "", "execution worktree is not clean"
    head = _git("rev-parse", "HEAD")
    assert _git("rev-parse", "HEAD^") == protocol["identities"]["implementationHead"], \
        "execution head is not the sole protocol commit over the implementation"
    assert int(_git("rev-list", "--count", f"{BASE}..HEAD")) == 2, \
        "execution history is not implementation plus one protocol commit"
    assert subprocess.check_output(["godot", "--version"], text=True).strip() == \
        protocol["identities"]["godotVersion"], "Godot identity mismatch"
    for name, expected in protocol["identities"]["files"].items():
        assert _sha(ROOT / name) == expected, f"file identity mismatch: {name}"
    names = _git("diff", BASE, "--name-only").splitlines()
    allowed = lambda name: name == "tools/balance_sim.gd" or \
        name == "docs/reviews/421/existing-grammar-l2-lock.md" or \
        name.startswith("research/issue-421-grammar-only/")
    assert names and all(allowed(name) for name in names), "harness-scope proof failed"
    bands = protocol["seedBands"]
    current = [bands["cohort"], bands["positivePreflight"]]
    prior_bands = [bands["ledger"][key] for key in bands["ledger"]]
    assert not _overlap(*current), "fresh bands overlap each other"
    assert all(not _overlap(a, b) for a in current for b in prior_bands), \
        "seed-band ledger proof failed"
    return protocol, head, names


def _runner(mode: str, out: Path, log: Path, head: str, protocol_sha: str,
            timeout: int) -> subprocess.CompletedProcess[str]:
    command = ["godot", "--headless", "-s", RUNNER, "--", f"--mode={mode}",
               f"--out={out}", f"--protocol={PROTOCOL}",
               f"--protocolSha={protocol_sha}", f"--expectedHead={head}"]
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
    log.write_text(completed.stdout + completed.stderr)
    return completed


def _write_stop(stage: str, reason: str, extra: dict | None = None) -> int:
    status = {"protocolId": PROTOCOL_ID, "stage": stage, "verdict": "STOP",
              "reason": reason, "cohortRows": 0, "writtenAt": _now()}
    if extra:
        status.update(extra)
    _json_write(STATUS, status)
    REPORT.write_text(f"# Existing-grammar L1/L2 exam — STOP\n\nStage: `{stage}`\n\n{reason}\n")
    print(json.dumps(status, sort_keys=True))
    return 2


def _active(row: dict, metric: str = "consumerDisjunction") -> bool:
    if metric == "consumerDisjunction":
        return any(row[ACTIVATIONS[key]] > 0 for key in CONSUMERS)
    return row[ACTIVATIONS[metric]] > 0


def _assert_participation_implications(rows: list[dict]) -> None:
    for row in rows:
        for card in CARDS:
            assert not (row[card + "Played"] > 0 and
                        (row[card + "Drawn"] <= 0 or row[card + "Offered"] <= 0)), \
                f"{card} Played > Drawn > Offered implication failed"
            assert not (row[card + "Drawn"] > 0 and row[card + "Offered"] <= 0), \
                f"{card} Drawn > Offered implication failed"
        for relic in RELICS:
            assert not (row[relic + "Procs"] > 0 and
                        (row[relic + "Owned"] <= 0 or row[relic + "Offered"] <= 0)), \
                f"{relic} Procs > Owned > Offered implication failed"
            assert not (row[relic + "Owned"] > 0 and row[relic + "Offered"] <= 0), \
                f"{relic} Owned > Offered implication failed"


def preflight() -> int:
    try:
        protocol, head, names = _identity()
        occupied = [p for p in (PREFLIGHT, PREFLIGHT_LOG, RAW, COHORT_LOG, MARKER, RESULT)
                    if p.exists()]
        assert not occupied, f"one-shot output already exists: {occupied}"
        completed = _runner("preflight", PREFLIGHT, PREFLIGHT_LOG, head, _sha(PROTOCOL), 1800)
        assert completed.returncode == 0, f"preflight runner exited {completed.returncode}"
        records = _load_lines(PREFLIGHT)
        manifest = records[0]
        assert manifest["t"] == "preflightManifest" and manifest["expectedRows"] == 0
        assert manifest["protocolSha256"] == _sha(PROTOCOL) and \
            manifest["executionHead"] == head, "preflight manifest identity mismatch"
        assert all(row.get("protocolRows") == 0 for row in records[1:]), \
            "preflight emitted a protocol row"
        baseline = next(row for row in records if row["t"] == "baseline")
        assert baseline["outcomeDigest"] == EXPECTED_DIGEST, "baseline digest sentinel failed"
        pools = next(row for row in records if row["t"] == "pools")["pools"]
        expected = {
            "cards": {"common": set(), "uncommon": set(),
                      "rare": {"shardstorm", "flawlessForm"}},
            "relics": {"common": set(), "uncommon": set(),
                       "rare": {"bellOfEndings", "prismCharm"}, "boss": set()},
        }
        pool_delta: dict[str, dict[str, list[str]]] = {"cards": {}, "relics": {}}
        for kind, tiers in expected.items():
            for tier, additions in tiers.items():
                l1, l2 = Counter(pools[kind]["L1"][tier]), Counter(pools[kind]["L2"][tier])
                assert l2 - l1 == Counter(additions) and not l1 - l2, \
                    f"{kind} pool delta failed at {tier}"
                pool_delta[kind][tier] = sorted(additions)
        assert pools["cards"]["L1"]["uncommon"].count("quakeblow") == 1 and \
            pools["cards"]["L2"]["uncommon"].count("quakeblow") == 1, \
            "quakeblow is not present exactly once in both arms"
        assert pools["cards"]["L1"]["rare"].count("resonantLance") == 1 and \
            pools["cards"]["L2"]["rare"].count("resonantLance") == 1, \
            "resonantLance is not present exactly once in both arms"
        assert len(pools["cards"]["L1"]["rare"]) == 13 and \
            len(pools["cards"]["L2"]["rare"]) == 15, "rare card-pool size drifted"
        assert len(pools["relics"]["L1"]["rare"]) == 5 and \
            len(pools["relics"]["L2"]["rare"]) == 7, "rare relic-pool size drifted"
        probes = [row for row in records if row["t"] == "consumerProbe"]
        assert probes and [row["seed"] for row in probes] == list(
            range(9600, 9600 + len(probes))), "positive preflight seed sweep drifted"
        assert len(probes) <= 50, "positive preflight left its frozen band"
        _assert_participation_implications(probes)
        positives = [row for row in probes if _active(row)]
        assert positives, "L2 consumer activation stayed zero on seeds 9600-9649"
        assert positives[0] is probes[-1], "positive sweep did not stop at first activation"
        assert not any(row["outcome"] == "error" or row["error"] for row in probes), \
            "positive preflight simulator error"
        rng_probes = [row for row in records if row["t"] == "rngProbe"]
        assert rng_probes and [row["seed"] for row in rng_probes] == list(
            range(7000, 7000 + len(rng_probes))), "cohort-coordinate RNG sweep drifted"
        differences = sum(row["l1Rng"] != row["l2Rng"] for row in rng_probes)
        assert differences > 0 and rng_probes[-1]["l1Rng"] != rng_probes[-1]["l2Rng"], \
            "between-subjects terminal-RNG proof failed"
        assert not any(row["l1Outcome"] == "error" or row["l2Outcome"] == "error"
                       for row in rng_probes), "RNG preflight simulator error"
        touched = [row["seed"] for row in probes + rng_probes]
        assert not any(3000 <= seed <= 5399 for seed in touched), \
            "protected or reserve seed touched"
        positive = positives[0]
        evidence = {
            "baselineDigest": baseline["outcomeDigest"], "poolDelta": pool_delta,
            "positiveSeed": positive["seed"],
            "positiveParticipation": {key: positive[key] for key in positive
                                      if any(key.startswith(item) for item in CARDS + RELICS)},
            "rngProbeCoordinates": len(rng_probes), "terminalRngDifferences": differences,
            "protocolRows": 0, "protectedReserveRows": 0, "scopePaths": names,
            "artifactSha256": _sha(PREFLIGHT),
        }
        status = {"protocolId": PROTOCOL_ID, "protocolSha256": _sha(PROTOCOL),
                  "executionHead": head, "stage": "preflight", "verdict": "PREFLIGHT_PASS",
                  "cohortRows": 0, "evidence": evidence, "writtenAt": _now()}
        _json_write(STATUS, status)
        REPORT.write_text("# Existing-grammar L1/L2 exam — preflight PASS\n\n" +
                          json.dumps(evidence, indent=2, sort_keys=True) + "\n")
        print(json.dumps(status, sort_keys=True))
        return 0
    except Exception as exc:
        return _write_stop("preflight", str(exc))


def _mean(rows: list[dict], metric: str) -> float:
    values = [(row["outcome"] == "win") if metric == "win" else _active(row, metric)
              for row in rows]
    return sum(values) / len(values)


def _interaction(index: dict[tuple, dict], vow: int, metric: str,
                 seeds: list[int]) -> float:
    rate = {(arm, policy): _mean([index[arm, vow, policy, seed] for seed in seeds], metric)
            for arm in ARMS for policy in POLICIES}
    return (rate["L2", "competent"] - rate["L2", "RandomBuild"] -
            rate["L1", "competent"] + rate["L1", "RandomBuild"])


def _bounds(values: list[float]) -> list[float]:
    ordered = sorted(values)
    return [ordered[math.floor(.025 * len(ordered))],
            ordered[math.ceil(.975 * len(ordered)) - 1]]


def _wilson(successes: int, total: int) -> list[float]:
    z = 1.959963984540054
    p = successes / total
    centre = (p + z * z / (2 * total)) / (1 + z * z / total)
    half = z * math.sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / \
        (1 + z * z / total)
    return [centre - half, centre + half]


def _participation(rows: list[dict], item: str, suffixes: tuple[str, ...],
                   activation_suffix: str) -> dict:
    out: dict = {"rows": len(rows)}
    for suffix in suffixes:
        key = item + suffix
        label = suffix[0].lower() + suffix[1:]
        successes = sum(row[key] > 0 for row in rows)
        out[label + "Total"] = sum(row[key] for row in rows)
        out[label + "Rows"] = successes
        out[label + "Rate"] = successes / len(rows)
        out[label + "Wilson95"] = _wilson(successes, len(rows))
    active_key = item + activation_suffix
    out["activationDistinctSeeds"] = len({row["seed"] for row in rows if row[active_key] > 0})
    return out


def _consumer_participation(rows: list[dict]) -> dict:
    active = [row for row in rows if _active(row)]
    return {"rows": len(rows), "activeRows": len(active), "activeRate": len(active) / len(rows),
            "wilson95": _wilson(len(active), len(rows)),
            "distinctSeeds": len({row["seed"] for row in active}),
            "byPolicy": {policy: sum(_active(row) for row in rows if row["policy"] == policy)
                         for policy in POLICIES}}


def _reachability(rows: list[dict], metric: str, threshold: int) -> dict:
    values = sorted(row[metric] for row in rows)
    nearest = lambda q: values[max(0, math.ceil(q * len(values)) - 1)]
    mean = sum(values) / len(values)
    nonzero = sum(value > 0 for value in values)
    return {"runs": len(values), "mean": mean, "p25": nearest(.25),
            "median": nearest(.50), "p75": nearest(.75), "max": values[-1],
            "nonzeroRuns": nonzero, "nonzeroFraction": nonzero / len(values),
            "threshold": threshold,
            "impliedCumulativeRunsToThreshold": math.ceil(threshold / mean) if mean > 0 else None}


def _analyse(rows: list[dict], protocol: dict, head: str, names: list[str]) -> dict:
    expected = {(arm, vow, policy, seed) for arm in ARMS for vow in VOWS
                for policy in POLICIES for seed in SEEDS}
    index = {(row["arm"], row["vow"], row["policy"], row["seed"]): row for row in rows}
    integrity: list[str] = []
    if len(rows) != 2048 or len(index) != 2048 or set(index) != expected:
        integrity.append("fixed 2048-row matrix is incomplete or duplicated")
    if [row["rowIndex"] for row in rows] != list(range(1, 2049)):
        integrity.append("row index sequence drifted")
    if any(row["aspect"] != "duskblade" for row in rows):
        integrity.append("non-Dusk row present")
    unexpected = sorted({row["outcome"] for row in rows} - {"win", "loss", "stall"})
    if unexpected:
        integrity.append(f"unexpected outcomes: {unexpected}")
    errors = sum(row["outcome"] == "error" or bool(row["error"]) for row in rows)
    if errors:
        integrity.append(f"{errors} simulator error row(s)")
    l1_only_forbidden = ("shardstorm", "flawlessForm")
    if any(row[item + suffix] for row in rows if row["arm"] == "L1"
           for item in l1_only_forbidden for suffix in ("Offered", "Drawn", "Played", "InDeck")):
        integrity.append("L1 carried L2-only card participation")
    if any(row[item + suffix] for row in rows if row["arm"] == "L1"
           for item in RELICS for suffix in ("Offered", "Owned", "Procs")):
        integrity.append("L1 carried L2-only relic participation")
    try:
        _assert_participation_implications(rows)
    except AssertionError as exc:
        integrity.append(str(exc))
    protected_rows = sum(3000 <= row["seed"] <= 5399 for row in rows)
    if protected_rows:
        integrity.append(f"{protected_rows} protected/reserve row(s)")
    stalls = {(vow, policy, arm): sum(row["outcome"] == "stall" for row in rows
              if row["vow"] == vow and row["policy"] == policy and row["arm"] == arm)
              for vow in VOWS for policy in POLICIES for arm in ARMS}
    additional = sum(max(0, stalls[vow, policy, "L2"] - stalls[vow, policy, "L1"])
                     for vow in VOWS for policy in POLICIES)
    if additional:
        integrity.append(f"{additional} additional L2 stall(s)")
    metrics = ("win", "consumerDisjunction", *ACTIVATIONS)
    point = {metric: {str(vow): _interaction(index, vow, metric, list(SEEDS)) for vow in VOWS}
             for metric in metrics}
    for values in point.values():
        values["pooled"] = sum(values[str(vow)] for vow in VOWS) / 2
    rng = random.Random(protocol["statistics"]["bootstrapSeed"])
    samples = {metric: {"0": [], "5": [], "pooled": []} for metric in metrics}
    for _ in range(protocol["statistics"]["bootstrapResamples"]):
        draw = [SEEDS[rng.randrange(len(SEEDS))] for _ in SEEDS]
        for metric in metrics:
            values = [_interaction(index, vow, metric, draw) for vow in VOWS]
            samples[metric]["0"].append(values[0])
            samples[metric]["5"].append(values[1])
            samples[metric]["pooled"].append(sum(values) / 2)
    bootstrap = {metric: {key: {"interval95": _bounds(values),
                  "positiveSign": sum(value > 0 for value in values) / len(values)}
                  for key, values in groups.items()} for metric, groups in samples.items()}
    l1 = [row for row in rows if row["arm"] == "L1"]
    l2 = [row for row in rows if row["arm"] == "L2"]
    reach = {metric: {str(vow): _reachability(
        [row for row in l1 if row["vow"] == vow], metric, threshold) for vow in VOWS}
        for metric, threshold in (("slain", 100), ("perfects", 3))}
    for metric, threshold in (("slain", 100), ("perfects", 3)):
        reach[metric]["pooled"] = _reachability(l1, metric, threshold)
    participation = {
        "cards": {card: {str(vow): _participation(
            [row for row in l2 if row["vow"] == vow], card,
            ("Offered", "Drawn", "Played", "InDeck"), "Played") for vow in VOWS}
            for card in CARDS},
        "relics": {relic: {str(vow): _participation(
            [row for row in l2 if row["vow"] == vow], relic,
            ("Offered", "Owned", "Procs"), "Procs") for vow in VOWS}
            for relic in RELICS},
        "consumerDisjunction": {str(vow): _consumer_participation(
            [row for row in l2 if row["vow"] == vow]) for vow in VOWS},
    }
    for card in CARDS:
        participation["cards"][card]["pooled"] = _participation(
            l2, card, ("Offered", "Drawn", "Played", "InDeck"), "Played")
    for relic in RELICS:
        participation["relics"][relic]["pooled"] = _participation(
            l2, relic, ("Offered", "Owned", "Procs"), "Procs")
    participation["consumerDisjunction"]["pooled"] = _consumer_participation(l2)
    limits = protocol["thresholds"]
    scientific: list[str] = []
    for vow in VOWS:
        if point["win"][str(vow)] <= 0:
            scientific.append(f"Vow-{vow} win complementarity is not positive")
        if participation["consumerDisjunction"][str(vow)]["activeRate"] < \
                limits["naturalActivationRate"]:
            scientific.append(f"Vow-{vow} L2 consumer activation is below 5%")
    if point["win"]["pooled"] < limits["pooledWinComplementarity"]:
        scientific.append("pooled win complementarity missed +0.02")
    if bootstrap["win"]["pooled"]["positiveSign"] < limits["bootstrapPositiveSign"]:
        scientific.append("pooled bootstrap positive-sign agreement missed 0.90")
    verdict = "STOP" if integrity else ("FAIL_CLOSED" if scientific else "PASS")
    return {"protocolId": PROTOCOL_ID, "protocolSha256": _sha(PROTOCOL),
            "executionHead": head, "verdict": verdict, "rows": len(rows),
            "pointEstimands": point, "bootstrap": bootstrap, "participation": participation,
            "deedReachability": reach, "outcomes": dict(Counter(row["outcome"] for row in rows)),
            "errors": errors, "stalls": {f"V{vow}.{policy}.{arm}": count
                for (vow, policy, arm), count in stalls.items()},
            "additionalStalls": additional, "protectedReserveRows": protected_rows,
            "productMutations": [], "scopePaths": names, "integrityFailures": integrity,
            "scientificFailures": scientific, "rawRowsSha256": _sha(RAW),
            "preflightSha256": _sha(PREFLIGHT), "writtenAt": _now()}


def _finalise(result: dict) -> int:
    _json_write(RESULT, result)
    status = {key: result[key] for key in ("protocolId", "protocolSha256", "executionHead",
              "verdict", "rows", "errors", "additionalStalls", "protectedReserveRows")}
    status.update({"stage": "complete", "result": str(RESULT), "resultSha256": _sha(RESULT),
                   "rawRows": str(RAW), "rawRowsSha256": result["rawRowsSha256"],
                   "scientificFailures": result["scientificFailures"],
                   "integrityFailures": result["integrityFailures"],
                   "scopeDisposition": "L2 only; no L3, L1 rescue, new primitive or P9 claim",
                   "writtenAt": _now()})
    _json_write(STATUS, status)
    win, boot = result["pointEstimands"]["win"], result["bootstrap"]["win"]
    activation = result["participation"]["consumerDisjunction"]
    activation_point = result["pointEstimands"]["consumerDisjunction"]
    reach = result["deedReachability"]
    card_lines = "\n".join(
        f"  - `{card}` played-row rate: Vow 0 `{result['participation']['cards'][card]['0']['playedRate']:.4f}`, "
        f"Vow 5 `{result['participation']['cards'][card]['5']['playedRate']:.4f}`; activation "
        f"complementarity `{result['pointEstimands'][card]['0']:.6f}` / "
        f"`{result['pointEstimands'][card]['5']:.6f}`"
        for card in CARDS)
    relic_lines = "\n".join(
        f"  - `{relic}` proc-row rate: Vow 0 `{result['participation']['relics'][relic]['0']['procsRate']:.4f}`, "
        f"Vow 5 `{result['participation']['relics'][relic]['5']['procsRate']:.4f}`; activation "
        f"complementarity `{result['pointEstimands'][relic]['0']:.6f}` / "
        f"`{result['pointEstimands'][relic]['5']:.6f}`"
        for relic in RELICS)
    reach_lines = "\n".join(
        f"  - `{metric}` {group}: mean `{reach[metric][group]['mean']:.4f}`, "
        f"p25 / median / p75 / max `{reach[metric][group]['p25']}` / "
        f"`{reach[metric][group]['median']}` / `{reach[metric][group]['p75']}` / "
        f"`{reach[metric][group]['max']}`, non-zero fraction "
        f"`{reach[metric][group]['nonzeroFraction']:.4f}`, runs-to-threshold "
        f"`{reach[metric][group]['impliedCumulativeRunsToThreshold']}`"
        for metric in ("slain", "perfects") for group in ("0", "5", "pooled"))
    REPORT.write_text(f"""# Existing-grammar L1/L2 exam — {result['verdict']}

- Rows: {result['rows']} / 2048
- Win complementarity: Vow 0 `{win['0']:.6f}` ({boot['0']['interval95']}), Vow 5 `{win['5']:.6f}` ({boot['5']['interval95']})
- Pooled win complementarity: `{win['pooled']:.6f}`; bootstrap positive-sign agreement `{boot['pooled']['positiveSign']:.4f}`; 95% interval `{boot['pooled']['interval95']}`
- L2 consumer-disjunction rate: Vow 0 `{activation['0']['activeRate']:.4f}` across `{activation['0']['distinctSeeds']}` seeds; Vow 5 `{activation['5']['activeRate']:.4f}` across `{activation['5']['distinctSeeds']}` seeds
- Consumer-disjunction activation complementarity: Vow 0 `{activation_point['0']:.6f}`, Vow 5 `{activation_point['5']:.6f}`, pooled `{activation_point['pooled']:.6f}`
- Per-id participation:
{card_lines}
{relic_lines}
- L1-arm cumulative deed reachability:
{reach_lines}
- Errors / additional stalls / protected-reserve rows: `{result['errors']}` / `{result['additionalStalls']}` / `{result['protectedReserveRows']}`
- Scientific failures: {result['scientificFailures']}
- Integrity failures: {result['integrityFailures']}
- Raw SHA-256: `{result['rawRowsSha256']}`
- Result SHA-256: `{status['resultSha256']}`
- Scope: L2 only. No L3, L1 rescue, new primitive or P9 claim.
""")
    print(json.dumps({"status": status, "pointEstimands": result["pointEstimands"],
                      "bootstrapWin": result["bootstrap"]["win"],
                      "participation": result["participation"],
                      "deedReachability": result["deedReachability"]}, sort_keys=True))
    return 0 if result["verdict"] == "PASS" else (2 if result["verdict"] == "STOP" else 3)


def cohort() -> int:
    try:
        protocol, head, names = _identity()
        status = json.loads(STATUS.read_text())
        assert status["verdict"] == "PREFLIGHT_PASS" and status["cohortRows"] == 0, \
            "cohort lacks a passing zero-row preflight"
        assert status["evidence"]["artifactSha256"] == _sha(PREFLIGHT), \
            "preflight artifact changed"
        occupied = [p for p in (RAW, COHORT_LOG, MARKER, RESULT) if p.exists()]
        assert not occupied, f"one-shot cohort output already exists: {occupied}"
        _json_write(MARKER, {"protocolId": PROTOCOL_ID, "protocolSha256": _sha(PROTOCOL),
                             "executionHead": head, "expectedRows": 2048, "startedAt": _now()})
        completed = _runner("rows", RAW, COHORT_LOG, head, _sha(PROTOCOL), 7200)
        if completed.returncode != 0:
            written = max(0, len(_load_lines(RAW)) - 1) if RAW.exists() else 0
            return _write_stop("cohort", f"cohort runner exited {completed.returncode}",
                               {"cohortRows": written})
        records = _load_lines(RAW)
        manifest = records[0]
        assert manifest["t"] == "manifest" and manifest["expectedRows"] == 2048, \
            "cohort manifest mismatch"
        assert manifest["protocolSha256"] == _sha(PROTOCOL) and \
            manifest["executionHead"] == head, "cohort manifest identity mismatch"
        assert len(records) == 2049 and all(row.get("t") == "row" for row in records[1:]), \
            "cohort stream contains missing or foreign records"
        return _finalise(_analyse(records[1:], protocol, head, names))
    except Exception as exc:
        written = max(0, len(_load_lines(RAW)) - 1) if RAW.exists() else 0
        return _write_stop("cohort", str(exc), {"cohortRows": written})


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("preflight", "cohort"):
        raise SystemExit("usage: existing_grammar_l2_exam.py preflight|cohort")
    raise SystemExit(preflight() if sys.argv[1] == "preflight" else cohort())

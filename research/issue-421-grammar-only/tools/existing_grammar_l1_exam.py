#!/usr/bin/env python3
"""One-shot preflight, execution and frozen analysis for the L0/L1 exam."""

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
PROTOCOL_ID = "existing-grammar-l0-l1-v2"
PROTOCOL = ROOT / "research/issue-421-grammar-only/protocols/existing-grammar-l0-l1-v2.json"
PROTOCOL_SHA = PROTOCOL.with_suffix(".sha256")
RUNNER = "res://research/issue-421-grammar-only/tools/existing_grammar_l1_rows.gd"
PREFLIGHT = Path("/tmp/glassvow-421-l1-preflight.jsonl")
PREFLIGHT_LOG = Path("/tmp/glassvow-421-l1-preflight.log")
RAW = Path("/tmp/glassvow-421-l1-raw.jsonl")
COHORT_LOG = Path("/tmp/glassvow-421-l1-cohort.log")
MARKER = Path("/tmp/glassvow-421-l1-start-marker.json")
RESULT = Path("/tmp/glassvow-421-l1-result.json")
STATUS = Path("/tmp/glassvow-421-l1-status.json")
REPORT = Path("/tmp/glassvow-421-l1-report.md")
EXPECTED_DIGEST = "b02bca98709f70ddc5e1b163bd580f54bece86ece2e6fd2b364784245ec8fecf"


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def _json_write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n")


def _load_lines(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def _identity() -> tuple[dict, str, list[str]]:
    protocol_sha = _sha(PROTOCOL)
    assert PROTOCOL_SHA.read_text().split()[0] == protocol_sha, "protocol SHA sidecar mismatch"
    protocol = json.loads(PROTOCOL.read_text())
    assert protocol["protocolId"] == PROTOCOL_ID, "protocol identity mismatch"
    assert protocol["identities"]["sourceBase"] == BASE, "source base mismatch"
    lock = protocol["authority"]["bindingLock"]
    lock_path = Path(lock["path"])
    assert _sha(lock_path) == lock["sha256"], "binding-lock SHA mismatch"
    assert subprocess.check_output(["git", "-C", lock["worktree"], "rev-parse", "HEAD"],
                                   text=True).strip() == lock["commit"], \
        "binding-lock commit mismatch"
    assert _git("status", "--porcelain") == "", "execution worktree is not clean"
    head = _git("rev-parse", "HEAD")
    assert _git("rev-parse", "HEAD^") == protocol["identities"]["implementationHead"], \
        "execution head is not the sole protocol commit over the implementation"
    assert subprocess.check_output(["godot", "--version"], text=True).strip() == \
        protocol["identities"]["godotVersion"], "Godot identity mismatch"
    for name, expected in protocol["identities"]["files"].items():
        assert _sha(ROOT / name) == expected, f"file identity mismatch: {name}"
    names = _git("diff", BASE, "--name-only").splitlines()
    assert names and all(name == "tools/balance_sim.gd" or
                         name.startswith("research/issue-421-grammar-only/") for name in names), \
        "harness-scope proof failed"
    product = [name for name in names if not name.startswith("research/") and
               name != "tools/balance_sim.gd"]
    assert not product, f"product mutation(s): {product}"
    bands = protocol["seedBands"]
    current = [bands["cohort"], bands["positivePreflight"]]
    prior = [bands[key] for key in bands["priorKeys"]]
    overlap = lambda a, b: max(a[0], b[0]) <= min(a[1], b[1])
    assert not overlap(current[0], current[1]), "fresh bands overlap each other"
    assert all(not overlap(a, b) for a in current for b in prior), "seed-band proof failed"
    return protocol, head, names


def _runner(mode: str, out: Path, log: Path, head: str, protocol_sha: str,
            timeout: int) -> subprocess.CompletedProcess[str]:
    command = ["godot", "--headless", "-s", RUNNER, "--",
               f"--mode={mode}", f"--out={out}", f"--protocol={PROTOCOL}",
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
    REPORT.write_text(f"# Existing-grammar L0/L1 exam — STOP\n\nStage: `{stage}`\n\n{reason}\n")
    print(json.dumps(status, sort_keys=True))
    return 2


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def preflight() -> int:
    try:
        protocol, head, names = _identity()
        occupied = [p for p in (PREFLIGHT, PREFLIGHT_LOG, RAW, COHORT_LOG, MARKER, RESULT)
                    if p.exists()]
        assert not occupied, f"one-shot output already exists: {occupied}"
        completed = _runner("preflight", PREFLIGHT, PREFLIGHT_LOG, head, _sha(PROTOCOL), 600)
        assert completed.returncode == 0, f"preflight runner exited {completed.returncode}"
        records = _load_lines(PREFLIGHT)
        assert records[0]["t"] == "preflightManifest" and records[0]["expectedRows"] == 0
        assert records[0]["protocolSha256"] == _sha(PROTOCOL) and \
            records[0]["executionHead"] == head, "preflight manifest identity mismatch"
        assert all(row.get("protocolRows") == 0 for row in records[1:]), \
            "preflight emitted a protocol row"
        baseline = next(row for row in records if row["t"] == "baseline")
        assert baseline["outcomeDigest"] == EXPECTED_DIGEST, "baseline digest sentinel failed"
        pools = next(row for row in records if row["t"] == "pools")["pools"]
        expected = {"common": set(), "uncommon": {"quakeblow"},
                    "rare": {"resonantLance"}}
        for tier, additions in expected.items():
            l0, l1 = Counter(pools["L0"][tier]), Counter(pools["L1"][tier])
            assert l1 - l0 == Counter(additions) and not l0 - l1, \
                f"pool delta failed at {tier}"
        probes = [row for row in records if row["t"] == "probe"]
        assert probes and [row["seed"] for row in probes] == list(
            range(9500, 9500 + len(probes))), "preflight seed sweep drifted"
        positive = [row for row in probes if row["resonantLancePlayed"] > 0]
        assert positive, "resonantLancePlayed stayed zero on seeds 9500-9549"
        assert len(probes) <= 50 and positive[0] is probes[-1], "positive sweep did not stop once"
        assert positive[0]["resonantLanceDrawn"] > 0 and \
            positive[0]["resonantLanceOffered"] > 0, "Played > 0 chain failed"
        assert sum(row["l0Rng"] != row["l1Rng"] for row in probes) > 0, \
            "between-subjects terminal-RNG proof failed"
        assert not any(row["l0Outcome"] == "error" or row["l1Outcome"] == "error"
                       for row in probes), "preflight simulator error"
        evidence = {"baselineDigest": baseline["outcomeDigest"], "poolDelta": {
            tier: sorted(value) for tier, value in expected.items()},
            "positiveSeed": positive[0]["seed"],
            "positiveParticipation": {key: positive[0][key] for key in positive[0]
                                      if key.startswith("resonantLance")},
            "sharedCoordinates": len(probes),
            "terminalRngDifferences": sum(row["l0Rng"] != row["l1Rng"] for row in probes),
            "protocolRows": 0, "scopePaths": names, "artifactSha256": _sha(PREFLIGHT)}
        status = {"protocolId": PROTOCOL_ID, "protocolSha256": _sha(PROTOCOL),
                  "executionHead": head, "stage": "preflight", "verdict": "PREFLIGHT_PASS",
                  "cohortRows": 0, "evidence": evidence, "writtenAt": _now()}
        _json_write(STATUS, status)
        REPORT.write_text("# Existing-grammar L0/L1 exam — preflight PASS\n\n" +
                          json.dumps(evidence, indent=2, sort_keys=True) + "\n")
        print(json.dumps(status, sort_keys=True))
        return 0
    except Exception as exc:  # preflight failures deterministically STOP before cohort
        return _write_stop("preflight", str(exc))


def _mean(rows: list[dict], metric: str) -> float:
    values = [(row["outcome"] == "win") if metric == "win" else
              (row["resonantLancePlayed"] > 0) for row in rows]
    return sum(values) / len(values)


def _interaction(index: dict[tuple, dict], vow: int, metric: str,
                 seeds: list[int]) -> float:
    rate = {}
    for arm in ("L0", "L1"):
        for policy in ("competent", "RandomBuild"):
            rate[arm, policy] = _mean([index[arm, vow, policy, seed] for seed in seeds], metric)
    return (rate["L1", "competent"] - rate["L1", "RandomBuild"] -
            rate["L0", "competent"] + rate["L0", "RandomBuild"])


def _bounds(values: list[float]) -> list[float]:
    ordered = sorted(values)
    return [ordered[math.floor(0.025 * len(ordered))],
            ordered[math.ceil(0.975 * len(ordered)) - 1]]


def _wilson(successes: int, total: int) -> list[float]:
    z = 1.959963984540054
    p = successes / total
    centre = (p + z * z / (2 * total)) / (1 + z * z / total)
    half = z * math.sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / \
        (1 + z * z / total)
    return [centre - half, centre + half]


def _distribution(rows: list[dict]) -> dict:
    values = sorted(row["shatters"] for row in rows)
    nearest = lambda q: values[max(0, math.ceil(q * len(values)) - 1)]
    reached = sum(value >= 15 for value in values)
    return {"runs": len(values), "min": values[0], "p10": nearest(.10),
            "p25": nearest(.25), "median": nearest(.50), "p75": nearest(.75),
            "p90": nearest(.90), "p95": nearest(.95), "max": values[-1],
            "mean": sum(values) / len(values), "reached15": reached,
            "fractionAtLeast15": reached / len(values), "wilson95": _wilson(reached, len(values))}


def _participation(rows: list[dict], card: str) -> dict:
    out = {"rows": len(rows)}
    for suffix in ("Offered", "Drawn", "Played", "InDeck"):
        key = card + suffix
        out[suffix[0].lower() + suffix[1:] + "Total"] = sum(row[key] for row in rows)
        out[suffix[0].lower() + suffix[1:] + "Rows"] = sum(row[key] > 0 for row in rows)
    out["playedRate"] = out["playedRows"] / len(rows)
    out["playedDistinctSeeds"] = len({row["seed"] for row in rows if row[card + "Played"] > 0})
    return out


def _analyse(rows: list[dict], protocol: dict, head: str, names: list[str]) -> dict:
    expected = {(arm, vow, policy, seed) for arm in ("L0", "L1") for vow in (0, 5)
                for policy in ("competent", "RandomBuild") for seed in range(6000, 6256)}
    index = {(row["arm"], row["vow"], row["policy"], row["seed"]): row for row in rows}
    integrity = []
    if len(rows) != 2048 or len(index) != 2048 or set(index) != expected:
        integrity.append("fixed 2048-row matrix is incomplete or duplicated")
    if any(row["aspect"] != "duskblade" for row in rows):
        integrity.append("non-Dusk row present")
    unexpected = sorted({row["outcome"] for row in rows} - {"win", "loss", "stall"})
    if unexpected:
        integrity.append(f"unexpected outcomes: {unexpected}")
    errors = sum(row["outcome"] == "error" or bool(row["error"]) for row in rows)
    if errors:
        integrity.append(f"{errors} simulator error row(s)")
    if any(row[card + suffix] for row in rows if row["arm"] == "L0"
           for card in ("quakeblow", "resonantLance")
           for suffix in ("Offered", "Drawn", "Played", "InDeck")):
        integrity.append("L0 carried candidate-card participation")
    if any(row["resonantLancePlayed"] > 0 and
           (row["resonantLanceDrawn"] <= 0 or row["resonantLanceOffered"] <= 0)
           for row in rows):
        integrity.append("cohort participation implication failed")
    stalls = {(vow, policy, arm): sum(row["outcome"] == "stall" for row in rows
              if row["vow"] == vow and row["policy"] == policy and row["arm"] == arm)
              for vow in (0, 5) for policy in ("competent", "RandomBuild")
              for arm in ("L0", "L1")}
    additional = sum(max(0, stalls[vow, policy, "L1"] - stalls[vow, policy, "L0"])
                     for vow in (0, 5) for policy in ("competent", "RandomBuild"))
    if additional:
        integrity.append(f"{additional} additional L1 stall(s)")
    seeds = list(range(6000, 6256))
    point = {metric: {str(vow): _interaction(index, vow, metric, seeds) for vow in (0, 5)}
             for metric in ("activation", "win")}
    point["win"]["pooled"] = sum(point["win"][str(vow)] for vow in (0, 5)) / 2
    rng = random.Random(protocol["statistics"]["bootstrapSeed"])
    samples = {metric: {"0": [], "5": [], "pooled": []} for metric in ("activation", "win")}
    for _ in range(protocol["statistics"]["bootstrapResamples"]):
        draw = [seeds[rng.randrange(len(seeds))] for _ in seeds]
        for metric in samples:
            values = [_interaction(index, vow, metric, draw) for vow in (0, 5)]
            samples[metric]["0"].append(values[0]); samples[metric]["5"].append(values[1])
            samples[metric]["pooled"].append(sum(values) / 2)
    bootstrap = {metric: {key: {"interval95": _bounds(values),
                  "positiveSign": sum(value > 0 for value in values) / len(values)}
                  for key, values in groups.items()} for metric, groups in samples.items()}
    l0 = [row for row in rows if row["arm"] == "L0"]
    reach = {str(vow): _distribution([row for row in l0 if row["vow"] == vow])
             for vow in (0, 5)}
    reach["pooled"] = _distribution(l0)
    l1 = [row for row in rows if row["arm"] == "L1"]
    participation = {card: {str(vow): _participation(
        [row for row in l1 if row["vow"] == vow], card) for vow in (0, 5)}
        for card in ("resonantLance", "quakeblow")}
    participation["resonantLance"]["pooled"] = _participation(l1, "resonantLance")
    participation["quakeblow"]["pooled"] = _participation(l1, "quakeblow")
    limits = protocol["thresholds"]
    scientific = []
    for vow in (0, 5):
        if point["win"][str(vow)] <= 0:
            scientific.append(f"Vow-{vow} win complementarity is not positive")
    if point["win"]["pooled"] < limits["pooledWinComplementarity"]:
        scientific.append("pooled win complementarity missed +0.02")
    if bootstrap["win"]["pooled"]["positiveSign"] < limits["bootstrapPositiveSign"]:
        scientific.append("pooled bootstrap positive-sign agreement missed 0.90")
    for vow in (0, 5):
        if participation["resonantLance"][str(vow)]["playedRate"] < \
                limits["naturalActivationRate"]:
            scientific.append(f"Vow-{vow} resonantLance activation is not non-trivial")
        if reach[str(vow)]["fractionAtLeast15"] < limits["paneBreakerReachabilityRate"]:
            scientific.append(f"Vow-{vow} paneBreaker gate is measurably unreachable")
    verdict = "STOP" if integrity else ("FAIL_CLOSED" if scientific else "PASS")
    return {"protocolId": PROTOCOL_ID, "protocolSha256": _sha(PROTOCOL),
            "executionHead": head, "verdict": verdict, "rows": len(rows),
            "pointEstimands": point, "bootstrap": bootstrap,
            "participation": participation, "paneBreakerReachability": reach,
            "outcomes": dict(Counter(row["outcome"] for row in rows)),
            "errors": errors, "stalls": {f"V{vow}.{policy}.{arm}": count
                for (vow, policy, arm), count in stalls.items()},
            "additionalStalls": additional, "protectedReserveRows": 0,
            "productMutations": [], "scopePaths": names,
            "integrityFailures": integrity, "scientificFailures": scientific,
            "rawRowsSha256": _sha(RAW), "preflightSha256": _sha(PREFLIGHT),
            "writtenAt": _now()}


def _finalise(result: dict) -> int:
    _json_write(RESULT, result)
    status = {key: result[key] for key in ("protocolId", "protocolSha256", "executionHead",
              "verdict", "rows", "errors", "additionalStalls", "protectedReserveRows")}
    status.update({"stage": "complete", "result": str(RESULT), "resultSha256": _sha(RESULT),
                   "rawRows": str(RAW), "rawRowsSha256": result["rawRowsSha256"],
                   "scientificFailures": result["scientificFailures"],
                   "integrityFailures": result["integrityFailures"], "writtenAt": _now()})
    _json_write(STATUS, status)
    win, boot = result["pointEstimands"]["win"], result["bootstrap"]["win"]
    reach, part = result["paneBreakerReachability"], result["participation"]
    REPORT.write_text(f"""# Existing-grammar L0/L1 exam — {result['verdict']}

- Rows: {result['rows']} / 2048
- Win complementarity: Vow 0 `{win['0']:.6f}` ({boot['0']['interval95']}), Vow 5 `{win['5']:.6f}` ({boot['5']['interval95']})
- Pooled win complementarity: `{win['pooled']:.6f}`; bootstrap positive-sign agreement `{boot['pooled']['positiveSign']:.4f}`; 95% interval `{boot['pooled']['interval95']}`
- Resonant Lance played-row rates: Vow 0 `{part['resonantLance']['0']['playedRate']:.4f}`, Vow 5 `{part['resonantLance']['5']['playedRate']:.4f}`
- L0 shatters >= 15: Vow 0 `{reach['0']['fractionAtLeast15']:.4f}`, Vow 5 `{reach['5']['fractionAtLeast15']:.4f}`
- Errors / additional stalls / protected-reserve rows: `{result['errors']} / {result['additionalStalls']} / {result['protectedReserveRows']}`
- Scientific failures: {result['scientificFailures']}
- Integrity failures: {result['integrityFailures']}
- Raw SHA-256: `{result['rawRowsSha256']}`
- Result SHA-256: `{status['resultSha256']}`
""")
    print(json.dumps({"status": status, "pointEstimands": result["pointEstimands"],
                      "bootstrapWin": result["bootstrap"]["win"],
                      "participation": result["participation"],
                      "paneBreakerReachability": result["paneBreakerReachability"]},
                     sort_keys=True))
    return 0 if result["verdict"] == "PASS" else 3


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
                             "executionHead": head, "expectedRows": 2048,
                             "startedAt": _now()})
        completed = _runner("rows", RAW, COHORT_LOG, head, _sha(PROTOCOL), 3600)
        if completed.returncode != 0:
            return _write_stop("cohort", f"cohort runner exited {completed.returncode}",
                               {"cohortRows": max(0, len(_load_lines(RAW)) - 1)
                                if RAW.exists() else 0})
        records = _load_lines(RAW)
        assert records[0]["t"] == "manifest" and records[0]["expectedRows"] == 2048, \
            "cohort manifest mismatch"
        assert records[0]["protocolSha256"] == _sha(PROTOCOL) and \
            records[0]["executionHead"] == head, "cohort manifest identity mismatch"
        assert len(records) == 2049 and all(row.get("t") == "row" for row in records[1:]), \
            "cohort stream contains missing or foreign records"
        return _finalise(_analyse(records[1:],
                                  protocol, head, names))
    except Exception as exc:
        return _write_stop("cohort", str(exc), {"cohortRows": max(
            0, len(_load_lines(RAW)) - 1) if RAW.exists() else 0})


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in ("preflight", "cohort"):
        raise SystemExit("usage: existing_grammar_l1_exam.py preflight|cohort")
    raise SystemExit(preflight() if sys.argv[1] == "preflight" else cohort())

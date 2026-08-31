#!/usr/bin/env python3
"""Preflight, execute and decide exactly one frozen STREAM-B-v3 simulator Phase A."""
from __future__ import annotations

import argparse
import collections
import copy
import hashlib
import json
import math
import os
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
PROTOCOL_ID = "p9-w0-v3-phase-a"
PROTOCOL_REL = Path("research/issue-421-grammar-only/protocols/p9-w0-v3-phase-a-preregistration.json")
ROWS_REL = Path("research/issue-421-grammar-only/tools/p9_w0_v2_phase_a_rows.gd")
CURRENT_REL = Path("research/issue-421-grammar-only/inputs/current-main-c28ae388-full-content.json")
OUT_REL = Path("research/issue-421-grammar-only/artifacts/p9-w0-v3-phase-a")
V2_ROWS_REL = Path("research/issue-421-grammar-only/artifacts/p9-w0-v2-phase-a/raw-rows.jsonl")
EXIT = {"GO": 0, "NO-GO": 2, "VETO": 3, "FAIL_CLOSED": 4}
EXPECTED_ROWS = 6400
COMPARATOR_ARM3_ROWS = 1200
TURN_CEILING = "turnCeiling"
PER_CELL_RUNS = 400
PER_CELL_BOUND = 0.02
PER_CELL_MAX = 8
PER_CELL_VETO_AT = 9
WHOLE_RUN_BOUND = 0.005


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_sha(value: object) -> str:
    blob = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode()).hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=REPO, text=True).strip()


def cp_lower(successes: int, total: int, alpha: float = 0.05) -> float:
    """Exact two-sided Clopper-Pearson lower bound via the binomial tail."""
    if successes <= 0 or total <= 0:
        return 0.0
    target = alpha / 2.0
    low, high = 0.0, successes / total
    for _ in range(80):
        p = (low + high) / 2.0
        tail = math.fsum(math.comb(total, i) * p**i * (1.0 - p) ** (total - i)
                         for i in range(successes, total + 1))
        if tail >= target:
            high = p
        else:
            low = p
    return (low + high) / 2.0


def _self_test() -> None:
    assert cp_lower(0, 200) == 0.0
    assert abs(cp_lower(10, 200) - 0.0242341655) < 1e-8
    assert canonical_sha({"b": 2, "a": 1}) == canonical_sha({"a": 1, "b": 2})
    matched = [
        _synthetic_row("omitted", TURN_CEILING, 4000),
        _synthetic_row("null-card", TURN_CEILING, 4000),
    ]
    matched_metrics = _reliability(matched)
    assert matched_metrics["unmatchedCount"] == 0
    unmatched_metrics = _reliability(matched[:1])
    assert unmatched_metrics["unmatchedCount"] == 1
    error_metrics = _reliability([_synthetic_row("omitted", "error", 4000)])
    assert error_metrics["errorCount"] == 1 and error_metrics["turnCeilingCount"] == 0
    over_cell = []
    for seed in range(4000, 4000 + PER_CELL_VETO_AT):
        over_cell.extend((_synthetic_row("omitted", TURN_CEILING, seed),
                          _synthetic_row("null-card", TURN_CEILING, seed)))
    assert _reliability(over_cell)["perCell"]["arm3:duskblade"]["exceeded"]
    over_whole = [_synthetic_row("null-card", TURN_CEILING, seed)
                  for seed in range(33)]
    over_whole.extend(_synthetic_row("omitted", "loss", seed) for seed in range(6367))
    assert _reliability(over_whole)["wholeRun"]["exceeded"]
    assert sum(len(seeds) for seeds in _expected_matrix().values()) == EXPECTED_ROWS
    assert _arm3_comparator_rows() == COMPARATOR_ARM3_ROWS
    print("PASS (10 p9-w0-v3 Phase A runner checks)")


def _synthetic_row(variant: str, outcome: str, seed: int) -> dict:
    return {"variant": variant, "cohort": "comparator" if variant != "omitted" else "control",
            "arm": 3, "aspect": "duskblade", "vow": 0, "seed": seed,
            "outcome": outcome, "error": "induced" if outcome == "error" else ""}


def _other_godot_processes() -> list[str]:
    lines = subprocess.check_output(
        ["ps", "-axo", "pid=,comm=,command="], text=True
    ).splitlines()
    processes: list[str] = []
    for line in lines:
        columns = line.strip().split(maxsplit=2)
        if len(columns) == 3 and Path(columns[1]).name.lower() == "godot":
            processes.append(f"{columns[0]} {columns[2]}")
    return processes


def _preflight(protocol: dict, expected_protocol_sha: str, expected_head: str,
               godot: str) -> tuple[str, str]:
    protocol_path = REPO / PROTOCOL_REL
    if sha256(protocol_path) != expected_protocol_sha:
        raise RuntimeError("protocol SHA-256 does not match the frozen invocation")
    if protocol.get("protocolId") != PROTOCOL_ID:
        raise RuntimeError("protocol identity drift")
    if git("rev-parse", "HEAD") != expected_head:
        raise RuntimeError("execution HEAD does not match the frozen invocation")
    if git("status", "--porcelain"):
        raise RuntimeError("execution worktree is not clean")
    if git("rev-parse", "origin/main") != protocol["identities"]["sourceBase"]:
        raise RuntimeError("origin/main moved from the frozen source base")
    if subprocess.run(["git", "diff", "--quiet", "origin/main", "--", "port_fixtures"],
                      cwd=REPO).returncode != 0:
        raise RuntimeError("port_fixtures differ from the frozen source base")
    for rel, expected in protocol["identities"]["files"].items():
        path = REPO / rel
        if not path.is_file() or sha256(path) != expected:
            raise RuntimeError(f"frozen file identity mismatch: {rel}")
    per_cell = protocol.get("reliability", {}).get("turnCeiling", {}).get("perArmAspectCell", {})
    whole_run = protocol.get("reliability", {}).get("turnCeiling", {}).get("wholeRun", {})
    if per_cell != {"boundInclusive": PER_CELL_BOUND, "runs": PER_CELL_RUNS,
                    "maximumInclusive": PER_CELL_MAX, "vetoAt": PER_CELL_VETO_AT}:
        raise RuntimeError("frozen per-cell turnCeiling bound drift")
    if whole_run != {"boundInclusive": WHOLE_RUN_BOUND, "runs": EXPECTED_ROWS,
                     "maximumInclusive": 32, "vetoAbove": WHOLE_RUN_BOUND}:
        raise RuntimeError("frozen whole-run turnCeiling bound drift")
    if protocol.get("budget", {}).get("maximumSimulatorRows") != EXPECTED_ROWS:
        raise RuntimeError("frozen total row count drift")
    if protocol.get("budget", {}).get("comparatorRows") != 2400:
        raise RuntimeError("frozen comparator row count drift")
    if sum(len(seeds) for seeds in _expected_matrix().values()) != EXPECTED_ROWS:
        raise RuntimeError("internal expected matrix does not contain 6400 rows")
    if _arm3_comparator_rows() != COMPARATOR_ARM3_ROWS:
        raise RuntimeError("arm-3 comparator panel does not contain 1200 rows")
    if _verify_v2_arm1_identity() != 400:
        raise RuntimeError("immutable v2 current-main/null-card arm-1 identity is not 400/400")
    candidate = json.loads((REPO / "content/full-content.json").read_text())
    current = json.loads((REPO / CURRENT_REL).read_text())
    null_card = copy.deepcopy(candidate)
    null_card["cards"].pop("facetBurst", None)
    null_card["cardPools"]["uncommon"] = [
        card for card in null_card["cardPools"]["uncommon"] if card != "facetBurst"
    ]
    if null_card != current or canonical_sha(null_card) != protocol["content"]["nullCardSemanticSha256"]:
        raise RuntimeError("null-card projection is not current-main semantic identity")
    if candidate["cards"].get("facetBurst") != protocol["system"]["facetBurst"]:
        raise RuntimeError("facetBurst shape drift")
    version = subprocess.check_output([godot, "--version"], cwd=REPO, text=True).strip()
    if version != protocol["identities"]["godotVersion"]:
        raise RuntimeError(f"Godot identity mismatch: {version}")
    processes = _other_godot_processes()
    if processes:
        raise RuntimeError("another Godot process is still live: " + " | ".join(processes))
    return version, canonical_sha(candidate)


def _verify_v2_arm1_identity() -> int:
    blobs = [json.loads(line) for line in (REPO / V2_ROWS_REL).read_text().splitlines()
             if line.strip()]
    rows = [row for row in blobs if row.get("t") == "row"]
    if len(rows) != 5200:
        raise RuntimeError("immutable v2 raw-row count drift")
    current = {(int(r["vow"]), int(r["seed"])): r for r in rows
               if r["variant"] == "current-main" and r["cohort"] == "comparator"
               and int(r["arm"]) == 1 and r["aspect"] == "duskblade"}
    null = {(int(r["vow"]), int(r["seed"])): r for r in rows
            if r["variant"] == "null-card" and r["cohort"] == "comparator"
            and int(r["arm"]) == 1 and r["aspect"] == "duskblade"}
    if set(current) != set(null) or len(current) != 400:
        raise RuntimeError("immutable v2 arm-1 CRN coordinate drift")
    return sum(current[key]["outcomeDigest"] == null[key]["outcomeDigest"]
               and current[key]["rng"] == null[key]["rng"] for key in current)


def _expected_matrix() -> dict[tuple, set[int]]:
    expected: dict[tuple, set[int]] = {}
    controls = set(range(4000, 4200))
    holdout = set(range(5000, 5200))
    for arm in (1, 2, 3, 4):
        for aspect in ("duskblade", "ashwarden"):
            for vow in (0, 5):
                expected[("omitted", "control", arm, aspect, vow)] = controls
    for aspect in ("duskblade", "ashwarden"):
        for vow in (0, 5):
            expected[("omitted", "holdout", 1, aspect, vow)] = holdout
    for variant in ("current-main", "explicit-off", "null-card"):
        for arm in (1, 3):
            for vow in (0, 5):
                expected[(variant, "comparator", arm, "duskblade", vow)] = controls
    return expected


def _arm3_comparator_rows() -> int:
    return sum(len(seeds) for key, seeds in _expected_matrix().items()
               if key[1] == "comparator" and key[2] == 3)


def _read_rows(path: Path, protocol: dict, protocol_sha: str) -> tuple[dict, list[dict]]:
    blobs = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    if not blobs or blobs[0].get("t") != "manifest":
        raise RuntimeError("row archive has no manifest")
    manifest, rows = blobs[0], blobs[1:]
    if manifest.get("protocolSha256") != protocol_sha \
            or manifest.get("expectedRows") != EXPECTED_ROWS:
        raise RuntimeError("row manifest identity drift")
    if manifest.get("pilot") != protocol["identities"]["pilot"] \
            or manifest.get("observer") != protocol["identities"]["h11Observer"]:
        raise RuntimeError("row manifest pilot/observer drift")
    if manifest.get("candidateContentSha256") != protocol["content"]["candidateFileSha256"] \
            or manifest.get("currentMainContentSha256") != protocol["content"]["currentMainFileSha256"]:
        raise RuntimeError("row manifest content drift")
    if len(rows) != EXPECTED_ROWS \
            or [r.get("rowIndex") for r in rows] != list(range(1, EXPECTED_ROWS + 1)):
        raise RuntimeError(f"row count/order drift: {len(rows)}")
    actual: dict[tuple, set[int]] = collections.defaultdict(set)
    for row in rows:
        if row.get("outcome") not in ("win", "loss", TURN_CEILING, "error"):
            raise RuntimeError(f"unexpected row outcome: {row.get('outcome')}")
        key = (row["variant"], row["cohort"], int(row["arm"]), row["aspect"], int(row["vow"]))
        seed = int(row["seed"])
        if seed in actual[key]:
            raise RuntimeError(f"duplicate CRN row: {key} seed {seed}")
        actual[key].add(seed)
        expected_weight = 0.0 if row["variant"] == "explicit-off" else 4.5
        if float(row["wardSurplus"]) != expected_weight:
            raise RuntimeError(f"policy comparator drift: {key} seed {seed}")
    if dict(actual) != _expected_matrix():
        raise RuntimeError("row matrix or seed identity drift")
    return manifest, rows


def _group(rows: list[dict], variant: str, cohort: str, arm: int,
           aspect: str, vow: int) -> list[dict]:
    return [r for r in rows if r["variant"] == variant and r["cohort"] == cohort
            and int(r["arm"]) == arm and r["aspect"] == aspect and int(r["vow"]) == vow]


def _summary(rows: list[dict]) -> dict:
    wins = sum(r["outcome"] == "win" for r in rows)
    return {"runs": len(rows), "wins": wins, "winRate": wins / len(rows),
            "turnCeilings": sum(r["outcome"] == TURN_CEILING for r in rows),
            "stalls": sum(r["outcome"] == "stall" for r in rows),
            "errors": sum(r["outcome"] == "error" for r in rows)}


def _activation(rows: list[dict], key: str) -> dict:
    seeds = {int(r["seed"]) for r in rows if int(r[key]) > 0}
    return {"activatedRuns": len(seeds), "runs": len(rows), "rate": len(seeds) / len(rows),
            "clopperPearsonLower95": cp_lower(len(seeds), len(rows)), "seeds": sorted(seeds)}


def _row_coordinate(row: dict) -> dict:
    return {"rowIndex": row.get("rowIndex"), "variant": row["variant"],
            "cohort": row["cohort"], "arm": int(row["arm"]),
            "aspect": row["aspect"], "vow": int(row["vow"]), "seed": int(row["seed"])}


def _reliability(rows: list[dict]) -> dict:
    errors = [r for r in rows if r.get("outcome") == "error" or bool(r.get("error"))]
    ceilings = [r for r in rows if r.get("outcome") == TURN_CEILING]
    null_twins = {(r["aspect"], int(r["vow"]), int(r["seed"])): r for r in rows
                  if r.get("variant") == "null-card" and r.get("cohort") == "comparator"
                  and int(r.get("arm", -1)) == 3}
    unmatched = []
    for row in ceilings:
        twin = null_twins.get((row["aspect"], int(row["vow"]), int(row["seed"])))
        if int(row["arm"]) != 3 or twin is None or twin.get("outcome") != TURN_CEILING:
            unmatched.append(_row_coordinate(row))

    per_cell = {}
    for arm in (1, 2, 3, 4):
        for aspect in ("duskblade", "ashwarden"):
            count = sum(r.get("outcome") == TURN_CEILING for r in rows
                        if r.get("variant") == "omitted" and r.get("cohort") == "control"
                        and int(r.get("arm", -1)) == arm and r.get("aspect") == aspect)
            per_cell[f"arm{arm}:{aspect}"] = {
                "turnCeilings": count, "runs": PER_CELL_RUNS,
                "rate": count / PER_CELL_RUNS, "boundInclusive": PER_CELL_BOUND,
                "maximumInclusive": PER_CELL_MAX, "vetoAt": PER_CELL_VETO_AT,
                "exceeded": count >= PER_CELL_VETO_AT,
            }
    whole_rate = len(ceilings) / len(rows) if rows else 0.0
    return {
        "errorCount": len(errors),
        "errorCoordinates": [_row_coordinate(r) for r in errors],
        "turnCeilingCount": len(ceilings),
        "matchedCount": len(ceilings) - len(unmatched),
        "unmatchedCount": len(unmatched),
        "unmatchedCoordinates": unmatched,
        "nullCardArm3TurnCeilings": sum(
            r.get("outcome") == TURN_CEILING and r.get("variant") == "null-card"
            and r.get("cohort") == "comparator" and int(r.get("arm", -1)) == 3
            for r in rows),
        "perCell": per_cell,
        "wholeRun": {"turnCeilings": len(ceilings), "runs": len(rows), "rate": whole_rate,
                     "boundInclusive": WHOLE_RUN_BOUND,
                     "maximumInclusive": int(EXPECTED_ROWS * WHOLE_RUN_BOUND),
                     "exceeded": whole_rate > WHOLE_RUN_BOUND},
    }


def _analyse(rows: list[dict], protocol: dict) -> tuple[str, list[str], dict]:
    veto: list[str] = []
    misses: list[str] = []
    reliability = _reliability(rows)
    if reliability["errorCount"]:
        veto.append(f"reliability error in {reliability['errorCount']} row(s)")
    if reliability["unmatchedCount"]:
        veto.append(f"unmatched turnCeiling in {reliability['unmatchedCount']} row(s)")
    for cell, metric in reliability["perCell"].items():
        if metric["exceeded"]:
            veto.append(f"{cell} turnCeiling bound exceeded: "
                        f"{metric['turnCeilings']}/{metric['runs']} (veto at 9/400)")
    if reliability["wholeRun"]["exceeded"]:
        whole = reliability["wholeRun"]
        veto.append(f"whole-run turnCeiling bound exceeded: "
                    f"{whole['turnCeilings']}/{whole['runs']} >0.5%")
    ash_rows = [r for r in rows if r["aspect"] == "ashwarden"]
    ash_shatters = sum(int(r["shatters"]) for r in ash_rows)
    ash_bursts = sum(int(r["facetBurstPlayed"]) for r in ash_rows)
    h11_events = sum(int(r["h11PlayerDuskEnemySmolder"]) for r in rows)
    if ash_shatters:
        veto.append(f"H10: {ash_shatters} Ash shatter event(s)")
    if h11_events:
        veto.append(f"H11: {h11_events} player-origin Dusk enemy-Smolder application(s)")
    if ash_bursts:
        veto.append(f"aspect scope: {ash_bursts} Ash facetBurst play(s)")
    for variant in ("current-main", "null-card"):
        activations = sum(int(r["facetBurstPlayed"]) for r in rows if r["variant"] == variant)
        if activations:
            veto.append(f"{variant} manufactured {activations} destination activation(s)")
    paired_identity_faults = 0
    paired_identity_checks = 0
    for vow in (0, 5):
        current = {int(r["seed"]): r for r in _group(rows, "current-main", "comparator", 1,
                                                       "duskblade", vow)}
        null = {int(r["seed"]): r for r in _group(rows, "null-card", "comparator", 1,
                                                    "duskblade", vow)}
        paired_identity_checks += len(current)
        paired_identity_faults += sum(current[s]["outcomeDigest"] != null[s]["outcomeDigest"]
                                      or current[s]["rng"] != null[s]["rng"] for s in current)
    if paired_identity_faults:
        veto.append(f"current-main/null-card identity drift in {paired_identity_faults} CRN pair(s)")

    controls: dict[str, dict] = {}
    for arm in (1, 2, 3, 4):
        for aspect in ("duskblade", "ashwarden"):
            for vow in (0, 5):
                key = f"arm{arm}:{aspect}:v{vow}"
                controls[key] = _summary(_group(rows, "omitted", "control", arm, aspect, vow))
    for aspect in ("duskblade", "ashwarden"):
        for vow in (0, 5):
            planned = controls[f"arm1:{aspect}:v{vow}"]["winRate"]
            random_build = controls[f"arm2:{aspect}:v{vow}"]["winRate"]
            if random_build >= 0.50:
                misses.append(f"arm 2 {aspect} V{vow} is {random_build:.1%}, not <50%")
            if planned <= random_build:
                misses.append(f"Planned is not strictly above RandomBuild for {aspect} V{vow}")

    destinations: dict[str, dict] = {}
    separation: dict[str, float] = {}
    for vow in (0, 5):
        omitted = _group(rows, "omitted", "control", 1, "duskblade", vow)
        off = _group(rows, "explicit-off", "comparator", 1, "duskblade", vow)
        for label, sample in (("omittedFacetBurst", omitted), ("explicitOffFacetBurst", off)):
            metric = _activation(sample, "facetBurstPlayed")
            destinations[f"{label}:v{vow}"] = metric
            if metric["rate"] < 0.05 or metric["clopperPearsonLower95"] <= 0.0:
                misses.append(f"{label} V{vow} misses the 5% positive-lower-bound floor")
        direct = _activation(omitted, "shatters")
        destinations[f"directShatter:v{vow}"] = direct
        if direct["rate"] < 0.05 or direct["clopperPearsonLower95"] <= 0.0:
            misses.append(f"directShatter V{vow} misses the 5% positive-lower-bound floor")
        burst_seeds = set(destinations[f"omittedFacetBurst:v{vow}"]["seeds"])
        shatter_seeds = set(direct["seeds"])
        union = burst_seeds | shatter_seeds
        jaccard = len(burst_seeds & shatter_seeds) / len(union) if union else 1.0
        separation[f"v{vow}"] = jaccard
        if jaccard > 0.50:
            misses.append(f"Dusk V{vow} activation-set Jaccard {jaccard:.3f} >0.50")

    holdout: dict[str, dict] = {}
    for aspect in ("duskblade", "ashwarden"):
        for vow in (0, 5):
            holdout[f"{aspect}:v{vow}"] = _summary(
                _group(rows, "omitted", "holdout", 1, aspect, vow))
    for aspect in ("duskblade", "ashwarden"):
        rate = holdout[f"{aspect}:v5"]["winRate"]
        if rate > 0.90:
            veto.append(f"holdout {aspect} V5 {rate:.1%} exceeds 90%")
    leads: dict[str, float] = {}
    for vow in (0, 5):
        lead = holdout[f"ashwarden:v{vow}"]["winRate"] - holdout[f"duskblade:v{vow}"]["winRate"]
        leads[f"v{vow}"] = lead
        if not 0.0 <= lead <= 0.20:
            veto.append(f"holdout Ash lead V{vow} {lead:+.1%} outside [0,20] pp")

    contrasts: dict[str, dict] = {}
    for vow in (0, 5):
        samples = {}
        for variant, cohort in (("omitted", "control"), ("current-main", "comparator"),
                                ("explicit-off", "comparator"), ("null-card", "comparator")):
            samples[variant] = {int(r["seed"]): int(r["outcome"] == "win")
                                for r in _group(rows, variant, cohort, 1, "duskblade", vow)}
        base = samples["omitted"]
        contrasts[f"v{vow}"] = {f"omittedMinus{label}":
                                  sum(base[s] - sample[s] for s in base) / len(base)
                                  for label, sample in samples.items() if label != "omitted"}
    metrics = {"reliability": reliability,
               "controls": controls, "holdout": holdout, "holdoutAshLead": leads,
               "destinations": destinations, "activationSetJaccard": separation,
               "pairedWinContrasts": contrasts, "identity": {
                   "ashShatters": ash_shatters, "ashFacetBurstPlays": ash_bursts,
                   "h11PlayerDuskEnemySmolder": h11_events,
                   "currentMainNullCardPairsChecked": paired_identity_checks,
                   "currentMainNullCardPairsIdentical": paired_identity_checks - paired_identity_faults,
                   "currentMainNullCardPairFaults": paired_identity_faults,
               }}
    if veto:
        return "VETO", veto, metrics
    if misses:
        return "NO-GO", misses, metrics
    return "GO", ["all frozen Phase A gates passed"], metrics


def _write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n")


def _failure(out_dir: Path | None, protocol_sha: str, expected_head: str,
             message: str, rows: int = 0) -> int:
    result = {"schemaVersion": 1, "protocolId": PROTOCOL_ID,
              "protocolSha256": protocol_sha, "executionHead": expected_head,
              "verdict": "FAIL_CLOSED", "reasons": [message], "rows": rows,
              "landscapeAuthorised": False}
    if out_dir is not None and out_dir.is_dir():
        _write_json(out_dir / "phase-a-result.json", result)
    print("FAIL_CLOSED: " + message, file=sys.stderr)
    return EXIT["FAIL_CLOSED"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--preflight-only", action="store_true")
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--expected-protocol-sha", default="")
    parser.add_argument("--expected-head", default="")
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    if args.self_test:
        _self_test()
        return 0
    if args.preflight_only == args.execute \
            or len(args.expected_protocol_sha) != 64 or len(args.expected_head) != 40:
        return _failure(None, args.expected_protocol_sha, args.expected_head,
                        "choose exactly one of preflight-only/execute and supply the frozen "
                        "protocol SHA and execution HEAD")
    protocol_path = REPO / PROTOCOL_REL
    try:
        protocol = json.loads(protocol_path.read_text())
        version, semantic = _preflight(protocol, args.expected_protocol_sha,
                                       args.expected_head, args.godot)
    except Exception as exc:
        return _failure(None, args.expected_protocol_sha, args.expected_head,
                        f"pre-row preflight: {exc}")

    if args.preflight_only:
        print(f"PASS (p9-w0-v3 static preflight; protocol={args.expected_protocol_sha}; "
              f"head={args.expected_head}; matrix={EXPECTED_ROWS}; arm3Comparators={COMPARATOR_ARM3_ROWS})")
        return 0

    out_dir = REPO / OUT_REL
    try:
        out_dir.parent.mkdir(parents=True, exist_ok=True)
        out_dir.mkdir()
        started = {"protocolId": protocol["protocolId"],
                   "protocolSha256": args.expected_protocol_sha,
                   "executionHead": args.expected_head, "rowsBeforeStart": 0,
                   "startedAtUnix": time.time()}
        marker_fd = os.open(out_dir / "start-marker.json", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
        with os.fdopen(marker_fd, "w") as marker:
            json.dump(started, marker, indent=2, sort_keys=True)
            marker.write("\n")
            marker.flush()
            os.fsync(marker.fileno())
    except Exception as exc:
        return _failure(out_dir if out_dir.exists() else None, args.expected_protocol_sha,
                        args.expected_head, f"one-shot start marker: {exc}")

    rows_path = out_dir / "raw-rows.jsonl"
    log_path = out_dir / "godot.log"
    command = [args.godot, "--headless", "-s", f"res://{ROWS_REL}", "--",
               f"--protocol=res://{PROTOCOL_REL}",
               f"--protocolSha={args.expected_protocol_sha}",
               f"--currentMain=res://{CURRENT_REL}", f"--out={rows_path}"]
    started_at = time.monotonic()
    try:
        with log_path.open("w") as log:
            completed = subprocess.run(command, cwd=REPO, stdout=log,
                                       stderr=subprocess.STDOUT,
                                       timeout=int(protocol["budget"]["wallTimeSeconds"]))
        wall = time.monotonic() - started_at
        if completed.returncode != 0:
            count = max(sum(1 for _ in rows_path.open()) - 1, 0) if rows_path.exists() else 0
            return _failure(out_dir, args.expected_protocol_sha, args.expected_head,
                            f"Godot row process exited {completed.returncode}", count)
        manifest, rows = _read_rows(rows_path, protocol, args.expected_protocol_sha)
        verdict, reasons, metrics = _analyse(rows, protocol)
    except subprocess.TimeoutExpired:
        count = max(sum(1 for _ in rows_path.open()) - 1, 0) if rows_path.exists() else 0
        return _failure(out_dir, args.expected_protocol_sha, args.expected_head,
                        "frozen wall-time ceiling exceeded", count)
    except Exception as exc:
        count = max(sum(1 for _ in rows_path.open()) - 1, 0) if rows_path.exists() else 0
        return _failure(out_dir, args.expected_protocol_sha, args.expected_head,
                        f"post-row integrity/analysis: {exc}", count)

    result = {"schemaVersion": 1, "protocolId": protocol["protocolId"],
              "protocolSha256": args.expected_protocol_sha,
              "executionHead": args.expected_head, "implementationHead": protocol["identities"]["implementationHead"],
              "godot": version, "candidateSemanticSha256": semantic,
              "manifest": manifest, "rows": len(rows), "wallTimeSeconds": wall,
              "verdict": verdict, "outcomeClass": {"GO": "success", "NO-GO": "futility",
                                                     "VETO": "veto"}[verdict],
              "reasons": reasons, "metrics": metrics,
              "landscapeAuthorised": verdict == "GO", "landscapeStarted": False}
    result_path = out_dir / "phase-a-result.json"
    _write_json(result_path, result)
    receipt = {"protocolSha256": args.expected_protocol_sha,
               "resultSha256": sha256(result_path), "rawRowsSha256": sha256(rows_path),
               "rows": len(rows), "verdict": verdict, "completedAtUnix": time.time()}
    _write_json(out_dir / "completion-receipt.json", receipt)
    print(f"{verdict}: {'; '.join(reasons)}")
    print(f"rows={len(rows)} wall={wall:.3f}s result_sha256={receipt['resultSha256']}")
    return EXIT[verdict]


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Preflight and execute the sole STREAM-B-v4 matched attribution re-exam."""
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
PROTOCOL_ID = "p9-w0-v4-phase-a"
PROTOCOL_REL = Path("research/issue-421-grammar-only/protocols/p9-w0-v4-phase-a-preregistration.json")
ROWS_REL = Path("research/issue-421-grammar-only/tools/p9_w0_v2_phase_a_rows.gd")
CURRENT_REL = Path("research/issue-421-grammar-only/inputs/current-main-c28ae388-full-content.json")
OUT_REL = Path("research/issue-421-grammar-only/artifacts/p9-w0-v4-phase-a")
V2_ROWS_REL = Path("research/issue-421-grammar-only/artifacts/p9-w0-v2-phase-a/raw-rows.jsonl")
V3_PACKET = Path("/Users/jamesto/.codex/worktrees/421-stream-b-reliability-v3/glassvow/research/issue-421-grammar-only/artifacts/p9-w0-v3-phase-a")
PREFLIGHT_ROWS = Path("/tmp/glassvow-421-v4-preflight.jsonl")
EXIT = {"PASS": 0, "FAIL_CLOSED": 4, "STOP": 5}
EXPECTED_ROWS = 1600
COMPARATOR_ARM3_ROWS = 1200
TURN_CEILING = "turnCeiling"
PER_CELL_RUNS = 400
PER_CELL_BOUND = 0.02
PER_CELL_MAX = 8
PER_CELL_VETO_AT = 9
WHOLE_RUN_BOUND = 0.005
WHOLE_RUN_ROWS = 6400
PARTICIPATION_FIELDS = ("facetBurstOffered", "facetBurstDrawn",
                        "facetBurstPlayed", "facetBurstInDeck")
EXPECTED_CEILINGS = {("omitted", 0, 4151), ("omitted", 5, 4064),
                     ("omitted", 5, 4079), ("explicit-off", 0, 4151),
                     ("explicit-off", 5, 4064), ("explicit-off", 5, 4079),
                     ("current-main", 0, 4060), ("current-main", 0, 4096),
                     ("null-card", 0, 4060), ("null-card", 0, 4096)}


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
    candidate_free = _reliability([_synthetic_row("omitted", TURN_CEILING, 4000)])
    assert candidate_free["candidateFreeCount"] == 1
    assert candidate_free["candidateTouchedCount"] == 0
    for field in PARTICIPATION_FIELDS:
        touched = _synthetic_row("omitted", TURN_CEILING, 4000)
        touched[field] = 1
        metrics = _reliability([touched])
        assert metrics["candidateFreeCount"] == 0
        assert metrics["candidateTouchedCount"] == 1
    error_metrics = _reliability([_synthetic_row("omitted", "error", 4000)])
    assert error_metrics["errorCount"] == 1 and error_metrics["turnCeilingCount"] == 0
    over_cell = []
    for seed in range(4000, 4000 + PER_CELL_VETO_AT):
        over_cell.append(_synthetic_row("omitted", TURN_CEILING, seed))
    assert _reliability(over_cell)["perCell"]["arm3:duskblade"]["exceeded"]
    over_whole = [_synthetic_row("null-card", TURN_CEILING, seed)
                  for seed in range(33)]
    assert _reliability(over_whole)["wholeRun"]["exceeded"]
    assert sum(len(seeds) for seeds in _expected_matrix().values()) == EXPECTED_ROWS
    assert _arm3_comparator_rows() == COMPARATOR_ARM3_ROWS
    print("PASS (p9-w0-v4 analyser: candidate-free plus four touched cases)")


def _synthetic_row(variant: str, outcome: str, seed: int) -> dict:
    return {"variant": variant, "cohort": "comparator" if variant != "omitted" else "control",
            "arm": 3, "aspect": "duskblade", "vow": 0, "seed": seed,
            "outcome": outcome, "error": "induced" if outcome == "error" else "",
            "rng": seed, "outcomeDigest": "0" * 64, "trajectoryDigest": "1" * 64,
            "facetBurstOffered": 0, "facetBurstDrawn": 0, "facetBurstPlayed": 0,
            "facetBurstInDeck": 0, "ceilingFight": {}, "h11PlayerDuskEnemySmolder": 0}


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
               godot: str, run_probe: bool) -> tuple[str, str, dict]:
    protocol_path = REPO / PROTOCOL_REL
    if sha256(protocol_path) != expected_protocol_sha:
        raise RuntimeError("protocol SHA-256 does not match the frozen invocation")
    if protocol.get("protocolId") != PROTOCOL_ID:
        raise RuntimeError("protocol identity drift")
    if git("rev-parse", "HEAD") != expected_head:
        raise RuntimeError("execution HEAD does not match the frozen invocation")
    if git("status", "--porcelain"):
        raise RuntimeError("execution worktree is not clean")
    parent = protocol["identities"]["executionParent"]
    repair_paths = git("diff", "--name-only", parent, "HEAD").splitlines()
    if any(not path.startswith("research/issue-421-grammar-only/") for path in repair_paths):
        raise RuntimeError("repair diff escaped research/issue-421-grammar-only/")
    inherited = set(protocol["scope"]["inheritedOutsideResearchPaths"])
    outside = {path for path in git("diff", "--name-only",
                                   protocol["identities"]["implementationHead"], "HEAD").splitlines()
               if not path.startswith("research/issue-421-grammar-only/")}
    if outside != inherited:
        raise RuntimeError("out-of-scope diff is not exactly the inherited docs re-anchor")
    if git("rev-parse", "origin/main") != protocol["identities"]["sourceBase"]:
        raise RuntimeError("origin/main moved from the frozen source base")
    if subprocess.run(["git", "diff", "--quiet", "origin/main", "--", "port_fixtures"],
                      cwd=REPO).returncode != 0:
        raise RuntimeError("port_fixtures differ from the frozen source base")
    for rel, expected in protocol["identities"]["files"].items():
        path = REPO / rel
        if not path.is_file() or sha256(path) != expected:
            raise RuntimeError(f"frozen file identity mismatch: {rel}")
    lock = protocol["authority"]["bindingLock"]
    lock_root = Path(lock["worktree"])
    lock_head = subprocess.check_output(
        ["git", "-C", str(lock_root), "rev-parse", "HEAD"], text=True).strip()
    if lock_head != lock["commit"] or sha256(lock_root / lock["path"]) != lock["sha256"]:
        raise RuntimeError("binding attribution-repair lock identity drift")
    for name, expected in protocol["v3Reference"]["packetFiles"].items():
        if sha256(V3_PACKET / name) != expected:
            raise RuntimeError(f"immutable v3 packet identity drift: {name}")
    per_cell = protocol.get("reliability", {}).get("turnCeiling", {}).get("perArmAspectCell", {})
    whole_run = protocol.get("reliability", {}).get("turnCeiling", {}).get("wholeRun", {})
    if per_cell != {"boundInclusive": PER_CELL_BOUND, "runs": PER_CELL_RUNS,
                    "maximumInclusive": PER_CELL_MAX, "vetoAt": PER_CELL_VETO_AT}:
        raise RuntimeError("frozen per-cell turnCeiling bound drift")
    if whole_run != {"boundInclusive": WHOLE_RUN_BOUND, "runs": WHOLE_RUN_ROWS,
                     "maximumInclusive": 32, "vetoAbove": WHOLE_RUN_BOUND}:
        raise RuntimeError("frozen whole-run turnCeiling bound drift")
    if protocol.get("budget", {}).get("maximumSimulatorRows") != EXPECTED_ROWS:
        raise RuntimeError("frozen total row count drift")
    if protocol.get("budget", {}).get("comparatorRows") != COMPARATOR_ARM3_ROWS:
        raise RuntimeError("frozen comparator row count drift")
    if sum(len(seeds) for seeds in _expected_matrix().values()) != EXPECTED_ROWS:
        raise RuntimeError("internal expected matrix does not contain 1600 rows")
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
    probe = _probe_preflight(protocol, expected_protocol_sha, expected_head, godot, run_probe)
    return version, canonical_sha(candidate), probe


def _probe_preflight(protocol: dict, protocol_sha: str, expected_head: str,
                     godot: str, execute: bool) -> dict:
    if execute:
        if PREFLIGHT_ROWS.exists():
            raise RuntimeError(f"preflight artifact already exists: {PREFLIGHT_ROWS}")
        command = [godot, "--headless", "-s", f"res://{ROWS_REL}", "--",
                   "--mode=preflight", f"--protocol=res://{PROTOCOL_REL}",
                   f"--protocolSha={protocol_sha}", f"--expectedHead={expected_head}",
                   f"--currentMain=res://{CURRENT_REL}", f"--out={PREFLIGHT_ROWS}"]
        completed = subprocess.run(command, cwd=REPO, text=True, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT,
                                   timeout=int(protocol["preflight"]["wallTimeSeconds"]))
        if completed.returncode != 0:
            raise RuntimeError(f"probe exited {completed.returncode}: {completed.stdout.strip()}")
    blobs = [json.loads(line) for line in PREFLIGHT_ROWS.read_text().splitlines() if line.strip()]
    manifest, probes = blobs[0], blobs[1:]
    if manifest.get("protocolSha256") != protocol_sha \
            or manifest.get("executionHead") != expected_head \
            or manifest.get("protocolRows") != 0 or not probes or len(probes) > 50:
        raise RuntimeError("preflight probe manifest/cardinality drift")
    positive = []
    for probe in probes:
        old, new, non_default = (probe["v3Writer"], probe["enrichedWriter"],
                                 probe["nonDefaultWriter"])
        if old["outcome"] != new["outcome"] or old["rng"] != new["rng"]:
            raise RuntimeError(f"enriched writer changed outcome/rng at seed {probe['seed']}")
        if old["trajectoryDigest"] != new["trajectoryDigest"]:
            raise RuntimeError(f"same-trajectory digest mismatch at seed {probe['seed']}")
        if non_default["outcomeDigest"] == non_default["trajectoryDigest"]:
            raise RuntimeError(f"policy-erased digest did not differ at seed {probe['seed']}")
        offered, drawn, played = (int(new["facetBurstOffered"]),
                                  int(new["facetBurstDrawn"]), int(new["facetBurstPlayed"]))
        if (played > 0 and drawn <= 0) or (drawn > 0 and offered <= 0):
            raise RuntimeError(f"participation implication failed at seed {probe['seed']}")
        if played > 0:
            positive.append(probe)
    if not positive or not all(positive[0]["eventKeys"].get(key) is True
                               for key in PARTICIPATION_FIELDS[:3]):
        raise RuntimeError("probe never carried a positive three-key facetBurst signal")
    row = positive[0]["enrichedWriter"]
    return {"artifact": str(PREFLIGHT_ROWS), "protocolRows": 0,
            "seedsTried": len(probes), "positiveSeed": positive[0]["seed"],
            "participation": {key: int(row[key]) for key in PARTICIPATION_FIELDS}}


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
    for vow in (0, 5):
        expected[("omitted", "control", 3, "duskblade", vow)] = controls
    for variant in ("current-main", "explicit-off", "null-card"):
        for vow in (0, 5):
            expected[(variant, "comparator", 3, "duskblade", vow)] = controls
    return expected


def _arm3_comparator_rows() -> int:
    return sum(len(seeds) for key, seeds in _expected_matrix().items()
               if key[1] == "comparator" and key[2] == 3)


def _read_rows(path: Path, protocol: dict, protocol_sha: str,
               expected_head: str) -> tuple[dict, list[dict]]:
    blobs = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    if not blobs or blobs[0].get("t") != "manifest":
        raise RuntimeError("row archive has no manifest")
    manifest, rows = blobs[0], blobs[1:]
    if manifest.get("protocolSha256") != protocol_sha \
            or manifest.get("executionHead") != expected_head \
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
        if any(key not in row or int(row[key]) < 0 for key in PARTICIPATION_FIELDS) \
                or len(str(row.get("trajectoryDigest", ""))) != 64:
            raise RuntimeError(f"attribution serialisation drift: {key} seed {seed}")
        ceiling_fight = row.get("ceilingFight")
        if row["outcome"] == TURN_CEILING \
                and (not isinstance(ceiling_fight, dict)
                     or set(ceiling_fight) != {"act", "kind", "enemies", "turns"}):
            raise RuntimeError(f"ceilingFight serialisation drift: {key} seed {seed}")
        if row["outcome"] != TURN_CEILING and ceiling_fight != {}:
            raise RuntimeError(f"non-ceiling row carried ceilingFight: {key} seed {seed}")
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
    classified = []
    for row in ceilings:
        coordinate = _row_coordinate(row)
        fields = {key: int(row.get(key, 0)) for key in PARTICIPATION_FIELDS}
        coordinate.update({"participation": fields, "participationTotal": sum(fields.values()),
                           "ceilingFight": row.get("ceilingFight", {})})
        classified.append(coordinate)
    candidate_touched = [row for row in classified if row["participationTotal"] > 0]
    candidate_free = [row for row in classified if row["participationTotal"] == 0]

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
    whole_rate = len(ceilings) / WHOLE_RUN_ROWS
    return {
        "errorCount": len(errors),
        "errorCoordinates": [_row_coordinate(r) for r in errors],
        "turnCeilingCount": len(ceilings),
        "candidateFreeCount": len(candidate_free),
        "candidateFreeCoordinates": candidate_free,
        "candidateTouchedCount": len(candidate_touched),
        "candidateTouchedCoordinates": candidate_touched,
        "nullCardArm3TurnCeilings": sum(
            r.get("outcome") == TURN_CEILING and r.get("variant") == "null-card"
            and r.get("cohort") == "comparator" and int(r.get("arm", -1)) == 3
            for r in rows),
        "perCell": per_cell,
        "wholeRun": {"turnCeilings": len(ceilings), "runs": WHOLE_RUN_ROWS, "rate": whole_rate,
                     "boundInclusive": WHOLE_RUN_BOUND,
                     "maximumInclusive": int(WHOLE_RUN_ROWS * WHOLE_RUN_BOUND),
                     "exceeded": whole_rate > WHOLE_RUN_BOUND},
    }


def _row_key(row: dict) -> tuple:
    return (row["variant"], row["cohort"], int(row["arm"]), row["aspect"],
            int(row["vow"]), int(row["seed"]))


def _v3_reproduction(rows: list[dict]) -> dict:
    source = [json.loads(line) for line in (V3_PACKET / "raw-rows.jsonl").read_text().splitlines()
              if line.strip()]
    wanted = {(*panel, seed) for panel, seeds in _expected_matrix().items() for seed in seeds}
    old = {_row_key(row): row for row in source if row.get("t") == "row"
           and _row_key(row) in wanted}
    if set(old) != wanted:
        raise RuntimeError("v3 matched-cohort coordinate set drift")
    faults = []
    outcome_matches = rng_matches = 0
    for row in rows:
        prior = old[_row_key(row)]
        outcome_match = row["outcome"] == prior["outcome"]
        rng_match = row["rng"] == prior["rng"]
        outcome_matches += int(outcome_match)
        rng_matches += int(rng_match)
        if not outcome_match or not rng_match:
            fault = _row_coordinate(row)
            fault.update({"v3Outcome": prior["outcome"], "v4Outcome": row["outcome"],
                          "v3Rng": prior["rng"], "v4Rng": row["rng"]})
            faults.append(fault)
    return {"checked": len(rows), "outcomeMatches": outcome_matches,
            "rngMatches": rng_matches, "faultCount": len(faults), "faults": faults}


def _analyse(rows: list[dict], protocol: dict) -> tuple[str, list[str], dict]:
    failures: list[str] = []
    reliability = _reliability(rows)
    reproduction = _v3_reproduction(rows)
    actual_ceilings = {(r["variant"], int(r["vow"]), int(r["seed"])) for r in rows
                       if r["outcome"] == TURN_CEILING}
    ceiling_check = {"expected": 10, "actual": len(actual_ceilings),
                     "matches": actual_ceilings == EXPECTED_CEILINGS,
                     "missing": sorted(EXPECTED_CEILINGS - actual_ceilings),
                     "unexpected": sorted(actual_ceilings - EXPECTED_CEILINGS)}
    if reproduction["faultCount"]:
        failures.append(f"v3 outcome/rng reproduction failure in "
                        f"{reproduction['faultCount']} row(s)")
    if not ceiling_check["matches"]:
        failures.append(f"turnCeiling coordinate reproduction drift: "
                        f"{ceiling_check['actual']}/10 expected")
    if reliability["errorCount"]:
        failures.append(f"reliability error in {reliability['errorCount']} row(s)")
    if reliability["candidateTouchedCount"]:
        failures.append(f"candidate-touched turnCeiling in "
                        f"{reliability['candidateTouchedCount']} row(s)")
    for cell, metric in reliability["perCell"].items():
        if metric["exceeded"]:
            failures.append(f"{cell} turnCeiling bound exceeded: "
                            f"{metric['turnCeilings']}/{metric['runs']} (veto at 9/400)")
    if reliability["wholeRun"]["exceeded"]:
        whole = reliability["wholeRun"]
        failures.append(f"whole-run turnCeiling bound exceeded: "
                        f"{whole['turnCeilings']}/{whole['runs']} >0.5%")
    h11_events = sum(int(r["h11PlayerDuskEnemySmolder"]) for r in rows)
    if h11_events:
        failures.append(f"H11: {h11_events} player-origin Dusk enemy-Smolder application(s)")
    manufactured = {variant: sum(int(r["facetBurstPlayed"]) for r in rows
                                 if r["variant"] == variant)
                    for variant in ("current-main", "null-card")}
    for variant, activations in manufactured.items():
        if activations:
            failures.append(f"{variant} manufactured {activations} destination activation(s)")
    current = {(int(r["vow"]), int(r["seed"])): r for r in rows
               if r["variant"] == "current-main"}
    null = {(int(r["vow"]), int(r["seed"])): r for r in rows
            if r["variant"] == "null-card"}
    identity_faults = sum(current[key]["outcomeDigest"] != null[key]["outcomeDigest"]
                          or current[key]["rng"] != null[key]["rng"] for key in current)
    if identity_faults:
        failures.append(f"current-main/null-card identity drift in {identity_faults} CRN pair(s)")
    omitted = {(int(r["vow"]), int(r["seed"])): r for r in rows if r["variant"] == "omitted"}
    explicit = {(int(r["vow"]), int(r["seed"])): r for r in rows
                if r["variant"] == "explicit-off"}
    same_trajectory = [key for key in omitted
                       if omitted[key]["trajectoryDigest"] == explicit[key]["trajectoryDigest"]]
    same_ceiling = [key for key in same_trajectory if omitted[key]["outcome"] == TURN_CEILING]
    metrics = {"reproductionVsV3": reproduction, "ceilingCoordinates": ceiling_check,
               "reliability": reliability, "identity": {
                   "h11PlayerDuskEnemySmolder": h11_events,
                   "currentMainNullCardPairsChecked": len(current),
                   "currentMainNullCardPairsIdentical": len(current) - identity_faults,
                   "currentMainNullCardPairFaults": identity_faults,
                   "manufacturedFacetBurstPlays": manufactured},
               "trajectoryDiagnostics": {"omittedExplicitOffPairsChecked": len(omitted),
                                           "sameTrajectoryPairs": len(same_trajectory),
                                           "sameTrajectoryCeilingExecutions": len(same_ceiling)}}
    if failures:
        return "FAIL_CLOSED", failures, metrics
    return "PASS", ["all locked attribution re-exam gates passed"], metrics


def _write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n")


def _stop(message: str) -> int:
    print("STOP: " + message, file=sys.stderr)
    return EXIT["STOP"]


def _failure(out_dir: Path | None, protocol_sha: str, expected_head: str,
             message: str, rows: int = 0) -> int:
    result = {"schemaVersion": 1, "protocolId": PROTOCOL_ID,
              "protocolSha256": protocol_sha, "executionHead": expected_head,
              "verdict": "FAIL_CLOSED", "reasons": [message], "rows": rows,
              "landscapeAuthorised": False, "p9Claim": False}
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
        return _stop("choose exactly one of preflight-only/execute and supply the frozen "
                     "protocol SHA and execution HEAD")
    protocol_path = REPO / PROTOCOL_REL
    try:
        protocol = json.loads(protocol_path.read_text())
        version, semantic, probe = _preflight(protocol, args.expected_protocol_sha,
                                              args.expected_head, args.godot,
                                              args.preflight_only)
    except Exception as exc:
        return _stop(f"pre-row preflight: {exc}")

    if args.preflight_only:
        print(f"PASS (p9-w0-v4 zero-row preflight; protocol={args.expected_protocol_sha}; "
              f"head={args.expected_head}; protocolRows=0; positiveSeed={probe['positiveSeed']})")
        return 0

    out_dir = REPO / OUT_REL
    try:
        out_dir.parent.mkdir(parents=True, exist_ok=True)
        out_dir.mkdir()
        started = {"protocolId": protocol["protocolId"],
                   "protocolSha256": args.expected_protocol_sha,
                   "executionHead": args.expected_head, "rowsBeforeStart": 0,
                   "preflight": probe, "startedAtUnix": time.time()}
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
               "--mode=rows", f"--protocol=res://{PROTOCOL_REL}",
               f"--protocolSha={args.expected_protocol_sha}",
               f"--expectedHead={args.expected_head}",
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
        manifest, rows = _read_rows(rows_path, protocol, args.expected_protocol_sha,
                                    args.expected_head)
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
              "manifest": manifest, "preflight": probe,
              "rows": len(rows), "wallTimeSeconds": wall,
              "verdict": verdict,
              "outcomeClass": "candidate-free" if verdict == "PASS" else
                              ("causal-attribution" if
                               metrics["reliability"]["candidateTouchedCount"] else
                               "integrity-failure"),
              "reasons": reasons, "metrics": metrics,
              "landscapeAuthorised": False, "landscapeStarted": False, "p9Claim": False}
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

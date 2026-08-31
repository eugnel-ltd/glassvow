#!/usr/bin/env python3
"""Execute and decide exactly one frozen STREAM-B-v2 simulator Phase A."""
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
PROTOCOL_REL = Path("research/issue-421-grammar-only/protocols/p9-w0-v2-phase-a-preregistration.json")
ROWS_REL = Path("research/issue-421-grammar-only/tools/p9_w0_v2_phase_a_rows.gd")
CURRENT_REL = Path("research/issue-421-grammar-only/inputs/current-main-c28ae388-full-content.json")
OUT_REL = Path("research/issue-421-grammar-only/artifacts/p9-w0-v2-phase-a")
EXIT = {"GO": 0, "NO-GO": 2, "VETO": 3, "FAIL_CLOSED": 4}


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
    print("PASS (3 p9-w0-v2 Phase A runner checks)")


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
    if protocol.get("protocolId") != "p9-w0-v2-phase-a":
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
        for vow in (0, 5):
            expected[(variant, "comparator", 1, "duskblade", vow)] = controls
    return expected


def _read_rows(path: Path, protocol: dict, protocol_sha: str) -> tuple[dict, list[dict]]:
    blobs = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    if not blobs or blobs[0].get("t") != "manifest":
        raise RuntimeError("row archive has no manifest")
    manifest, rows = blobs[0], blobs[1:]
    if manifest.get("protocolSha256") != protocol_sha or manifest.get("expectedRows") != 5200:
        raise RuntimeError("row manifest identity drift")
    if manifest.get("pilot") != protocol["identities"]["pilot"] \
            or manifest.get("observer") != protocol["identities"]["h11Observer"]:
        raise RuntimeError("row manifest pilot/observer drift")
    if manifest.get("candidateContentSha256") != protocol["content"]["candidateFileSha256"] \
            or manifest.get("currentMainContentSha256") != protocol["content"]["currentMainFileSha256"]:
        raise RuntimeError("row manifest content drift")
    if len(rows) != 5200 or [r.get("rowIndex") for r in rows] != list(range(1, 5201)):
        raise RuntimeError(f"row count/order drift: {len(rows)}")
    actual: dict[tuple, set[int]] = collections.defaultdict(set)
    for row in rows:
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
            "stalls": sum(r["outcome"] == "stall" for r in rows),
            "errors": sum(r["outcome"] == "error" for r in rows)}


def _activation(rows: list[dict], key: str) -> dict:
    seeds = {int(r["seed"]) for r in rows if int(r[key]) > 0}
    return {"activatedRuns": len(seeds), "runs": len(rows), "rate": len(seeds) / len(rows),
            "clopperPearsonLower95": cp_lower(len(seeds), len(rows)), "seeds": sorted(seeds)}


def _analyse(rows: list[dict], protocol: dict) -> tuple[str, list[str], dict]:
    veto: list[str] = []
    misses: list[str] = []
    unreliable = [r for r in rows if r["outcome"] in ("stall", "error") or r.get("error")]
    if unreliable:
        veto.append(f"reliability breach in {len(unreliable)} row(s)")
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
    for vow in (0, 5):
        current = {int(r["seed"]): r for r in _group(rows, "current-main", "comparator", 1,
                                                       "duskblade", vow)}
        null = {int(r["seed"]): r for r in _group(rows, "null-card", "comparator", 1,
                                                    "duskblade", vow)}
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
    metrics = {"controls": controls, "holdout": holdout, "holdoutAshLead": leads,
               "destinations": destinations, "activationSetJaccard": separation,
               "pairedWinContrasts": contrasts, "identity": {
                   "ashShatters": ash_shatters, "ashFacetBurstPlays": ash_bursts,
                   "h11PlayerDuskEnemySmolder": h11_events,
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
    result = {"schemaVersion": 1, "protocolId": "p9-w0-v2-phase-a",
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
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--expected-protocol-sha", default="")
    parser.add_argument("--expected-head", default="")
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    if args.self_test:
        _self_test()
        return 0
    if not args.execute or len(args.expected_protocol_sha) != 64 or len(args.expected_head) != 40:
        return _failure(None, args.expected_protocol_sha, args.expected_head,
                        "execution requires the frozen protocol SHA and execution HEAD")
    protocol_path = REPO / PROTOCOL_REL
    try:
        protocol = json.loads(protocol_path.read_text())
        version, semantic = _preflight(protocol, args.expected_protocol_sha,
                                       args.expected_head, args.godot)
    except Exception as exc:
        return _failure(None, args.expected_protocol_sha, args.expected_head,
                        f"pre-row preflight: {exc}")

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
              "reasons": reasons, "metrics": metrics, "landscapeAuthorised": False}
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

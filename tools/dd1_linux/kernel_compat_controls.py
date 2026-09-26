#!/usr/bin/env python3
"""Run every harmless kernel control independently, with recorded build provenance."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import platform
import resource
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import dd1_kernel_qualification as kq
import dd1_reservations as r

RAW_EACH = CASE_RAW = 8 * 1024 * 1024
CONTROLLER = "DD1_KERNEL_COMPAT_CONTROLLER"
CASE_SCHEMA = "DD1-KERNEL-COMPAT-1-CASE"
ART_KEYS = ("supervisor", "inert", "compat2-inert", "fit-inert", "libc.so.6")


def synthetic_account():
    policy = kq.INERT_RESERVATION_POLICY
    return dict(schema="DD1-KERNEL-COMPAT-1-SYNTHETIC-ACCOUNT-1", synthetic=True,
                recovery=dict(id=kq.OPERATION, starts_used=0, cpu_ns_used=0, raw_bytes_used=0,
                              **{k: policy[k] for k in ("starts_cap", "cpu_ns_cap", "raw_bytes_cap",
                                                       "executors", "per_invocation_cpu_seconds")},
                              unit_reservations_v2=[]))


def case_directory(root, case_id):
    return Path(root) / "cases" / case_id


def build_problems(repo):
    import dd1_linux_snapshot as snap
    try:
        manifest = snap.build_manifest(Path(repo))
        build = Path(repo) / "tools/dd1_linux/build"
        for name in ART_KEYS + ("ld-linux-x86-64.so.2",):
            path = build / name
            r.need(path.is_file() and not path.is_symlink(), "missing artefact: " + name)
            raw = path.read_bytes()
            item = manifest["binaries"][name]
            r.need(r.digest(raw) == item["sha256"] and len(raw) == item["bytes"],
                   "build identity mismatch: " + name)
        r.need(snap.elf((build / "supervisor").read_bytes()) == (None, []), "supervisor is not static ELF")
    except (OSError, ValueError, KeyError, TypeError, AttributeError, r.ReservationError, subprocess.SubprocessError) as exc:
        return [str(exc)]
    return []


def _argv(source, mode, births):
    if source == "fit_inert.c":
        return ["/workload", "sequential", str(births), "identity"]
    return ["/workload", mode]


def _case(case_id, source, mode, cap, observation, **extra):
    row = dict(case_id=case_id, source_file=source, mode=mode, cpu_cap=cap,
               argv_tokens=_argv(source, mode, extra.get("births")),
               required_observation=observation)
    row.update(extra)
    return row


ROWS = (
    _case("KC01_STRICT_POSITIVE", "inert.c", "positive", 12,
          "strict success; USER_NOTIF path live; 3 lifetime threads incl main; atomic save/readback; cleanup confirmed"),
    _case("KC02_READONLY_ESCAPE", "inert.c", "escape", 12,
          "writes/rename/alias to immutable source fail; original bytes readable; unit exits success; no escape"),
    _case("KC03_CLONE3_FALLBACK", "inert.c", "clone3", 11,
          "clone3 refused with ENOSYS path; no process created; bounded record; cleanup"),
    _case("KC04_STRICT_THREAD_CEILING", "inert.c", "thread_limit", 12,
          "strict four-lifetime-thread ceiling reached; next birth refused; no fifth thread"),
    _case("KC05_CPU_EXHAUST", "inert.c", "cpu", 20,
          "RLIMIT_CPU actually terminates workload; failure retained; cleanup; no refund/credit"),
    _case("KC06_RAW_OVERWRITE", "inert.c", "overwrites", 12,
          "monotone raw/write accounting; cap refusal before excess effect; failed unit remains charged"),
    _case("KC07_SOCKET_DENY", "inert.c", "socket", 11,
          "unrelated socket syscall EOPNOTSUPP/denied; no socket effect; strict failure"),
    _case("KC08_X32_ABI_KILL", "inert.c", "abi", 11,
          "x32-tagged syscall is fail-closed, expected SIGSYS; no BAD write"),
    _case("KC09_CONTROLLER_KILL", "inert.c", "linger", 12,
          "reservation/operation charge retained; PDEATHSIG/subreaper cleanup leaves controller/supervisor/workload identities gone",
          kill="controller"),
    _case("KC10_SUPERVISOR_KILL", "inert.c", "linger", 12,
          "failed outcome, cleanup confirmed, no surviving workload, charge retained",
          kill="supervisor"),
    _case("KC11_COMPAT_COMBINED", "compat2_inert.c", "combined", 16,
          "compatibility success + strict failure; exactly 1 process-refusal + 1 naming-refusal; CAPABILITY_CLASS_ONLY; save/readback"),
    _case("KC12_CPU_ABOVE_3", "compat2_inert.c", "cpu-above-three", 16,
          "controller 3/3, supervisor 2/2 and installed workload partition correct; workload exceeds former inherited 3s limit without escaping reserved total"),
    _case("KC13_FIT_14_BOUNDARY", "fit_inert.c", "sequential", 16,
          "accepted FIT ceiling reaches 14 lifetime threads incl main; exact mode/immutable-handler checks; atomic save",
          threads=14, births=13),
    _case("KC14_FIT_NEXT_BIRTH_DENY", "fit_inert.c", "sequential", 16,
          "15th lifetime birth is refused; no topology overflow",
          threads=14, births=14),
    _case("KC15_IA32_REACHABILITY", "inert.c", "ia32", 11,
          "if seccomp arch guard is reached: fail-closed SIGSYS; if host faults first with SIGSEGV and zero forbidden effects: record `NOT_REACHABLE_ON_HOST` and make no seccomp-arch claim; exit 0/effect => INCOMPATIBLE",
          special="ia32_reachability"),
    _case("KC16_NESTED_NAMESPACE_DENY", "inert.c", "namespace", 11,
          "workload cannot create another user namespace; EOPNOTSUPP/denied; existing isolated namespace remains intact"),
)


def plan():
    copied = []
    for row in ROWS:
        item = dict(row)
        item["argv_tokens"] = list(row["argv_tokens"])
        copied.append(item)
    return copied


def row_for(case_id):
    for row in ROWS:
        if row["case_id"] == case_id:
            return row
    return None


def _observed_cpu_ns():
    total = 0.0
    for who in (resource.RUSAGE_SELF, resource.RUSAGE_CHILDREN):
        usage = resource.getrusage(who)
        total += usage.ru_utime + usage.ru_stime
    return int(total * 1_000_000_000)


def _signal_pid(pid, sig):
    os.kill(pid, sig)


def _identity_absent(identity):
    """True once /proc identity is gone, reused, or from another boot. Polls ≤ 2s."""
    deadline = time.monotonic() + 2.0
    while True:
        try:
            current = r.process_identity(identity["pid"])
        except OSError:
            return True
        if current["start_ticks"] != identity.get("start_ticks") or current["boot_id"] != identity.get("boot_id"):
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.02)


def _account_row(account, case_id):
    if not isinstance(account, dict):
        return None
    recovery = account.get("recovery")
    rows = recovery.get("unit_reservations_v2") if isinstance(recovery, dict) else None
    if not isinstance(rows, list):
        return None
    for item in rows:
        if isinstance(item, dict) and item.get("unit_id") == case_id:
            return item
    return None


def _want(container, key, expected, bad, inc, label, identical=False):
    if not isinstance(container, dict) or key not in container:
        inc.append(label + " absent")
        return
    value = container[key]
    if (value is not expected) if identical else (value != expected):
        bad.append(label)


def _want_int(container, key, expected, bad, inc, label):
    if not isinstance(container, dict) or key not in container:
        inc.append(label + " absent")
        return
    if type(container[key]) is not int or container[key] != expected:
        bad.append(label)


def _rep(z, key, expected, bad, inc):
    report = z.get("supervisor_report") if isinstance(z, dict) else None
    _want(report, key, expected, bad, inc, key)


def _capture(evidence, name):
    capture = evidence.get("capture")
    if not isinstance(capture, dict) or name not in capture or capture[name] is None:
        return None
    value = capture[name]
    if isinstance(value, str):
        return None
    if isinstance(value, (bytes, bytearray)):
        return bytes(value)
    return None


def _processes(row, evidence, bad, inc):
    if not isinstance(row, dict) or "processes" not in row:
        inc.append("processes absent")
        return
    procs = row["processes"]
    if not isinstance(procs, dict) or set(procs) != {"controller", "supervisor", "workload"}:
        bad.append("processes")
        return
    if "identities_absent" not in evidence:
        inc.append("identity absence absent")
    elif evidence["identities_absent"] is not True:
        bad.append("surviving process")


def _source_same(evidence, bad, inc):
    if "source_same" not in evidence:
        inc.append("source identity absent")
    elif evidence["source_same"] is not True:
        bad.append("source identity drift")


def _success_is(z, expected, bad):
    if isinstance(z, dict) and "success" in z and z["success"] is not expected:
        bad.append("success value")


def _common_b(case_id, evidence, z, row, bad, inc):
    planned = row_for(case_id)
    if "exit" not in evidence:
        inc.append("exit absent")
    elif evidence["exit"] != 0:
        bad.append("controller exit")
    if "success" not in z:
        inc.append("z.success absent")
        success = None
    elif type(z["success"]) is not bool:
        bad.append("z.success")
        success = None
    else:
        success = z["success"]
    _want(z, "cleanup_confirmed", True, bad, inc, "cleanup_confirmed", identical=True)
    _want(z, "native_qualified", False, bad, inc, "native_qualified", identical=True)
    _want(z, "n0_accepted", False, bad, inc, "n0_accepted", identical=True)
    expected_helper = evidence.get("helper_sha256")
    if expected_helper is None:
        inc.append("built helper identity absent")
    else:
        _want(z, "helper_sha256", expected_helper, bad, inc, "helper_sha256")
    _want_int(row, "starts", 1, bad, inc, "starts")
    _want_int(row, "cpu_ns", planned["cpu_cap"] * 1_000_000_000, bad, inc, "cpu_ns")
    if "unit_raw_bytes" not in evidence:
        inc.append("unit raw absent")
    else:
        _want_int(row, "raw_bytes", evidence["unit_raw_bytes"], bad, inc, "raw_bytes")
    if success is True:
        _want(row, "state", "COMPLETE", bad, inc, "state")
    elif success is False:
        _want(row, "state", "FAILED", bad, inc, "state")
    elif "state" not in row:
        inc.append("state absent")
    _processes(row, evidence, bad, inc)
    _source_same(evidence, bad, inc)


def _kc09(evidence, row, bad, inc):
    if "killed" not in evidence:
        inc.append("kill absent")
    elif evidence["killed"] != "controller":
        bad.append("controller not signalled")
    if "exit" not in evidence:
        inc.append("exit absent")
    elif evidence["exit"] != -9:
        bad.append("controller exit")
    _want(row, "state", "RESERVED", bad, inc, "state")
    _processes(row, evidence, bad, inc)
    _want_int(row, "cpu_ns", 12 * 1_000_000_000, bad, inc, "cpu_ns")
    if "unit_raw_bytes" not in evidence:
        inc.append("unit raw absent")
    else:
        _want_int(row, "raw_bytes", evidence["unit_raw_bytes"], bad, inc, "raw_bytes")


def _contains(evidence, name, needle, bad, inc, label):
    data = _capture(evidence, name)
    if data is None:
        inc.append(label + " absent")
    elif needle not in data:
        bad.append(label)


def _exact(evidence, name, expected, bad, inc, label):
    data = _capture(evidence, name)
    if data is None:
        inc.append(label + " absent")
    elif data != expected:
        bad.append(label)


def _number(report, key, bad, inc):
    if not isinstance(report, dict) or key not in report:
        inc.append(key + " absent")
        return None
    value = report[key]
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        bad.append(key)
        return None
    return value


def _ia32(z, bad, inc):
    report = z.get("supervisor_report") if isinstance(z, dict) else None
    if not isinstance(report, dict) or "signal" not in report:
        inc.append("rep.signal absent")
        return "EXPECTED"
    number = report["signal"]
    if number == 31:
        return "EXPECTED"
    if number == 11 and z.get("success") is False:
        return "NOT_REACHABLE_ON_HOST"
    bad.append("ia32 outcome")
    return "INCOMPATIBLE"


def _predicates(case_id, evidence, z, row, bad, inc):
    if case_id == "KC09_CONTROLLER_KILL":
        _kc09(evidence, row, bad, inc)
        return
    _common_b(case_id, evidence, z, row, bad, inc)
    if case_id == "KC01_STRICT_POSITIVE":
        _success_is(z, True, bad)
        _rep(z, "thread_births_including_main", 3, bad, inc)
        _rep(z, "execs", 1, bad, inc)
        _exact(evidence, "save.json", b'{"v":2}\n', bad, inc, "save.json")
        _contains(evidence, "stdout.bin", b"OK SAVE THREADS", bad, inc, "stdout.bin")
    elif case_id == "KC02_READONLY_ESCAPE":
        _success_is(z, True, bad)
        _contains(evidence, "stdout.bin", b"ISOLATED", bad, inc, "stdout.bin")
        if "src_input" not in evidence or evidence["src_input"] is None:
            inc.append("input absent")
        elif evidence["src_input"] != b"IMMUTABLE\n":
            bad.append("input bytes")
        for name in ("src_moved", "src_hardlink", "src_original"):
            if name not in evidence:
                inc.append(name + " absent")
            elif evidence[name] is not False:
                bad.append(name)
    elif case_id == "KC03_CLONE3_FALLBACK":
        report = z.get("supervisor_report") if isinstance(z.get("supervisor_report"), dict) else None
        if report is None or "clone3_denied" not in report:
            inc.append("clone3_denied absent")
        elif type(report["clone3_denied"]) is not int or report["clone3_denied"] < 1:
            bad.append("clone3_denied")
        _rep(z, "thread_births_including_main", 1, bad, inc)
        _contains(evidence, "stdout.bin", b"errno=38", bad, inc, "stdout.bin")
    elif case_id == "KC04_STRICT_THREAD_CEILING":
        _success_is(z, False, bad)
        _rep(z, "last_denied_syscall", 56, bad, inc)
        _rep(z, "execs", 1, bad, inc)
        _rep(z, "thread_births_including_main", 4, bad, inc)
    elif case_id == "KC05_CPU_EXHAUST":
        import dd1_linux_backend as backend
        _success_is(z, False, bad)
        _rep(z, "signal", 9, bad, inc)
        _rep(z, "thread_births_including_main", 3, bad, inc)
        limit = backend.cpu_partition(20)["workload"]
        seconds = _number(z.get("supervisor_report"), "workload_cpu_seconds", bad, inc)
        if seconds is not None and not (limit - 0.1 <= seconds < limit + 1):
            bad.append("workload_cpu_seconds")
    elif case_id == "KC06_RAW_OVERWRITE":
        _success_is(z, False, bad)
        _rep(z, "last_denied_syscall", 18, bad, inc)
        report = z.get("supervisor_report") if isinstance(z.get("supervisor_report"), dict) else None
        if report is None or "reserved_before_writes" not in report or "raw_cap" not in report:
            inc.append("raw_cap absent")
        elif report["reserved_before_writes"] != report["raw_cap"]:
            bad.append("reserved_before_writes")
        if "capture_bytes" not in evidence:
            inc.append("capture bytes absent")
        elif report is not None and "raw_cap" in report and not (
                type(evidence["capture_bytes"]) is int and type(report["raw_cap"]) is int
                and evidence["capture_bytes"] < report["raw_cap"]):
            bad.append("capture bytes")
    elif case_id == "KC07_SOCKET_DENY":
        _success_is(z, False, bad)
        _rep(z, "last_denied_syscall", 41, bad, inc)
        _rep(z, "execs", 1, bad, inc)
        _rep(z, "thread_births_including_main", 1, bad, inc)
    elif case_id == "KC08_X32_ABI_KILL":
        _success_is(z, False, bad)
        _rep(z, "signal", 31, bad, inc)
        data = _capture(evidence, "stdout.bin")
        if data is None:
            inc.append("stdout.bin absent")
        elif b"BAD" in data:
            bad.append("BAD write")
    elif case_id == "KC10_SUPERVISOR_KILL":
        _success_is(z, False, bad)
        if "killed" not in evidence:
            inc.append("kill absent")
        elif evidence["killed"] != "supervisor":
            bad.append("supervisor not signalled")
    elif case_id == "KC11_COMPAT_COMBINED":
        _success_is(z, True, bad)
        _want(z, "compatibility_verdict", True, bad, inc, "compatibility_verdict", identical=True)
        _want(z, "strict_verdict", False, bad, inc, "strict_verdict", identical=True)
        classes = z.get("classification") if isinstance(z.get("classification"), dict) else None
        _want_int(classes, "process_refusals", 1, bad, inc, "process_refusals")
        _want_int(classes, "naming_refusals", 1, bad, inc, "naming_refusals")
        requests = z.get("refused_requests")
        if not isinstance(requests, list):
            inc.append("refused_requests absent")
        elif any(not isinstance(item, dict) or item.get("attribution") != "CAPABILITY_CLASS_ONLY" for item in requests):
            bad.append("attribution")
        _exact(evidence, "save.bin", b"COMPAT2\n", bad, inc, "save.bin")
        if "src_frozen" not in evidence or evidence["src_frozen"] is None:
            inc.append("frozen absent")
        elif evidence["src_frozen"] != b"FROZEN-INERT\n":
            bad.append("frozen bytes")
    elif case_id == "KC12_CPU_ABOVE_3":
        _success_is(z, True, bad)
        classes = z.get("classification") if isinstance(z.get("classification"), dict) else None
        _want_int(classes, "workload_cpu_soft", 6, bad, inc, "workload_cpu_soft")
        _want_int(classes, "workload_cpu_hard", 6, bad, inc, "workload_cpu_hard")
        _want(z, "controller_cpu_limits", [3, 3], bad, inc, "controller_cpu_limits")
        _want_int(classes, "supervisor_cpu_soft", 2, bad, inc, "supervisor_cpu_soft")
        _want_int(classes, "supervisor_cpu_hard", 2, bad, inc, "supervisor_cpu_hard")
        seconds = _number(z.get("supervisor_report"), "workload_cpu_seconds", bad, inc)
        if seconds is not None and not seconds > 4:
            bad.append("workload_cpu_seconds")
        if "src_frozen" not in evidence or evidence["src_frozen"] is None:
            inc.append("frozen absent")
        elif evidence["src_frozen"] != b"FROZEN-INERT\n":
            bad.append("frozen bytes")
    elif case_id == "KC13_FIT_14_BOUNDARY":
        _success_is(z, True, bad)
        _rep(z, "thread_limit", 14, bad, inc)
        _rep(z, "profile_mode", 2, bad, inc)
        _exact(evidence, "save.bin", b"FIT1\n", bad, inc, "save.bin")
        _contains(evidence, "stdout.bin", b"MODE:0555 owner=1 group=1 other=1", bad, inc, "stdout.bin")
    elif case_id == "KC14_FIT_NEXT_BIRTH_DENY":
        _success_is(z, False, bad)
    elif case_id == "KC16_NESTED_NAMESPACE_DENY":
        _success_is(z, False, bad)
        _rep(z, "last_denied_syscall", 272, bad, inc)
        _rep(z, "execs", 1, bad, inc)
        _rep(z, "thread_births_including_main", 1, bad, inc)


def classify(case_id, evidence):
    """Return (classification, reasons) from a plain evidence dict. No kernel and no I/O."""
    bad, inc = [], []
    if not isinstance(evidence, dict) or row_for(case_id) is None:
        return "INCONCLUSIVE", ["evidence absent"]
    if evidence.get("exception") is True:
        inc.append("exception after reservation")
    if evidence.get("timeout") is True:
        inc.append("controller timeout")
    if case_id != "KC09_CONTROLLER_KILL" and evidence.get("stdout_one") is not True:
        inc.append("controller stdout is not one JSON object")
    z = evidence.get("z") if evidence.get("stdout_one") is True else None
    if not isinstance(z, dict):
        z = None
    if isinstance(z, dict) and "pre_release_error" in z:
        inc.append("pre_release_error")
    if evidence.get("account_readable") is not True:
        inc.append("per-case account unreadable")
    row = evidence.get("row") if evidence.get("account_readable") is True else None
    if evidence.get("account_readable") is True and not isinstance(row, dict):
        inc.append("per-case row unreadable")
        row = None
    if case_id in ("KC09_CONTROLLER_KILL", "KC10_SUPERVISOR_KILL") and evidence.get("live") is not True:
        inc.append("kill case never reached LIVE")
    if case_id == "KC09_CONTROLLER_KILL" and isinstance(row, dict):
        _kc09(evidence, row, bad, inc)
    elif isinstance(z, dict) and isinstance(row, dict):
        _predicates(case_id, evidence, z, row, bad, inc)
    kind = "EXPECTED"
    if case_id == "KC15_IA32_REACHABILITY" and isinstance(z, dict) and isinstance(row, dict) and not bad and not inc:
        kind = _ia32(z, bad, inc)
    if bad:
        return "INCOMPATIBLE", bad + inc
    if inc:
        return "INCONCLUSIVE", inc
    return kind, []


def tree_bytes(root, skip=None):
    root = Path(root)
    try:
        if not root.exists() and not root.is_symlink():
            return 0
        if root.is_symlink():
            return root.lstat().st_size
    except OSError:
        return 0
    skip_resolved = None
    if skip is not None:
        try:
            skip_resolved = Path(skip).resolve()
            if root.resolve() == skip_resolved:
                return 0
        except OSError:
            skip_resolved = None
    total = 0
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        current = Path(dirpath)
        kept = []
        for name in dirnames:
            child = current / name
            try:
                if child.is_symlink():
                    total += child.lstat().st_size
                    continue
                if skip_resolved is not None and child.resolve() == skip_resolved:
                    continue
            except OSError:
                continue
            kept.append(name)
        dirnames[:] = kept
        for name in filenames:
            try:
                total += (current / name).lstat().st_size
            except OSError:
                pass
    return total


def one_object(text):
    if not isinstance(text, str) or not text.strip():
        return None
    try:
        value = json.loads(text.strip())
    except ValueError:
        return None
    if not isinstance(value, dict):
        return None
    return value


def _read_bytes(path):
    try:
        if path.is_symlink() or not path.is_file():
            return None
        return path.read_bytes()
    except OSError:
        return None


def _exists(path):
    try:
        return path.exists()
    except OSError:
        return False


def assemble_evidence(row, where, unit, account, outcome):
    parsed = one_object(outcome.get("stdout"))
    readable = isinstance(account, dict)
    case_row = _account_row(account, row["case_id"]) if readable else None
    output = None
    if isinstance(unit, dict):
        output = unit.get("linux", {}).get("output_root") if isinstance(unit.get("linux"), dict) else None
    capture_dir = Path(output) / "capture" if isinstance(output, str) else None
    capture = {}
    for name in ("save.json", "stdout.bin", "save.bin"):
        capture[name] = _read_bytes(capture_dir / name) if capture_dir is not None else None
    src = Path(where) / "source" if where is not None else Path("source")
    if where is not None:
        try:
            meta = r.read(Path(where) / "paths.json")
            if isinstance(meta.get("repo"), str):
                src = Path(meta["repo"])
        except (OSError, r.ReservationError, AttributeError, TypeError):
            pass
    idents = []
    if isinstance(case_row, dict) and isinstance(case_row.get("processes"), dict):
        idents = [item for item in case_row["processes"].values() if isinstance(item, dict)]
    try:
        absent = all(_identity_absent(item) for item in idents) if idents else False
    except Exception:
        absent = False
    before, after = outcome.get("before"), outcome.get("after")
    killed = outcome.get("killed")
    measured = before is not None and after is not None
    return dict(
        exit=outcome.get("exit_code"), stdout_one=parsed is not None, z=parsed,
        account_readable=readable, row=case_row, exception=outcome.get("exc") is not None,
        timeout=outcome.get("timed_out") is True,
        live=(killed in ("controller", "supervisor")) if row.get("kill") else True,
        killed=killed if killed in ("controller", "supervisor") else None,
        identities_absent=absent, source_same=(before == after) if measured else True,
        helper_sha256=unit.get("linux", {}).get("helper", {}).get("sha256") if isinstance(unit, dict) else None,
        unit_raw_bytes=unit.get("raw_bytes") if isinstance(unit, dict) else CASE_RAW,
        capture=capture, capture_bytes=tree_bytes(capture_dir) if capture_dir is not None else 0,
        src_input=_read_bytes(src / "input"), src_moved=_exists(src / "moved"),
        src_hardlink=_exists(src / "hardlink"), src_original=_exists(src / "original"),
        src_frozen=_read_bytes(src / "inputs" / "frozen.txt"))


def collect(args, row):
    outcome = dict(exc=None, timed_out=False, killed=None, exit_code=None, stdout=None, stderr="",
                   before=None, after=None, where=None, unit=None, account_path=None)
    repo = ROOT
    deadline = time.monotonic() + 90
    proc = None
    try:
        outcome["before"] = source_identity(repo, row["source_file"])
        where, unit, account_path = stage(args.root, repo, row, args.head)
        outcome["where"], outcome["unit"], outcome["account_path"] = where, unit, account_path
        proc = spawn(args.head, args.root, args.case)
        if row.get("kill"):
            identities = wait_live(proc, unit["linux"]["output_root"], account_path)
            if identities and proc.poll() is None:
                try:
                    _signal_pid(identities[row["kill"]]["pid"], signal.SIGKILL)
                    outcome["killed"] = row["kill"]
                except OSError:
                    outcome["killed"] = None
        try:
            out, err = proc.communicate(timeout=max(0.01, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            outcome["timed_out"] = True
            proc.kill()
            out, err = proc.communicate()
        outcome["stdout"] = out
        outcome["stderr"] = err or ""
        outcome["exit_code"] = proc.returncode
        outcome["after"] = source_identity(repo, row["source_file"])
    except BaseException as exc:
        outcome["exc"] = exc
        if proc is not None and proc.poll() is None:
            try:
                proc.kill()
                proc.communicate()
            except Exception:
                pass
        if outcome["after"] is None:
            try:
                outcome["after"] = source_identity(repo, row["source_file"])
            except Exception:
                pass
    return outcome


def apply_k1(unit, head, account_path, row):
    unit["operation"] = kq.OPERATION
    unit.pop("scientific_m", None)
    unit["overlay_head"] = head
    unit["kernel_qualification"] = kq.profile()
    unit["cpu_seconds"] = row["cpu_cap"]
    unit["wall_seconds"] = 60
    unit["raw_bytes"] = RAW_EACH
    unit["argv"] = list(row["argv_tokens"])
    unit["account_sha256"] = r.digest(Path(account_path).read_bytes())
    unit["linux"]["output_root"] = str((Path(account_path).parent / "output").resolve())


def sign(where, unit):
    unit.pop("receipt_sha256", None)
    receipt = dict(schema="DD1-INERT-ONLY", demand_sha256=r.digest(r.encode(unit)))
    raw = r.encode(receipt)
    (where / "receipt.json").write_bytes(raw)
    unit["receipt_sha256"] = r.digest(raw)
    (where / "unit.json").write_bytes(r.encode(unit))


def build_inert(where, repo, row, head):
    import dd1_linux_snapshot as snap
    where.mkdir(parents=True, exist_ok=False)
    account_path = where / "ACCOUNT.json"
    account_path.write_bytes(r.encode(synthetic_account()))
    names = snap.HELPER_SOURCES | {"res://tools/dd1_linux/inert.c"}
    staged = where / "source"
    for name in names:
        dest = staged / name[6:]
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((repo / name[6:]).read_bytes())
    for binary in ("supervisor", "inert"):
        dest = staged / "tools/dd1_linux/build" / binary
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes((repo / "tools/dd1_linux/build" / binary).read_bytes())
    files = {name: r.digest((staged / name[6:]).read_bytes()) for name in names}
    helper = staged / "tools/dd1_linux/build/supervisor"
    inert = staged / "tools/dd1_linux/build/inert"
    extra = []
    if row["case_id"] == "KC02_READONLY_ESCAPE":
        (staged / "input").write_bytes(b"IMMUTABLE\n")
        files["res://input"] = r.digest(b"IMMUTABLE\n")
        extra = [str(staged / "input")]
    unit = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=kq.OPERATION, overlay_head=head,
                unit_id=row["case_id"], mode="inert_control", contained_starts=0,
                source_files=files, argv=list(row["argv_tokens"]),
                linux=dict(abi=snap.ABI, entry="/workload", threads=4, workload_raw_bytes=65536,
                           helper=dict(path="tools/dd1_linux/build/supervisor", sha256=r.digest(helper.read_bytes())),
                           runtime={"/workload": dict(path="tools/dd1_linux/build/inert",
                                                      sha256=r.digest(inert.read_bytes()), executable=True)}))
    apply_k1(unit, head, account_path, row)
    if extra:
        unit["argv"] = list(row["argv_tokens"]) + extra
    return unit, account_path, staged


def build_compat(where, repo, row, head):
    import compat2_controls as compat
    where.mkdir(parents=True, exist_ok=False)
    compat.HEAD = head
    unit, staged = compat.make_unit(where, mode=row["mode"], cpu=row["cpu_cap"], repo=None,
                                    existing_account=synthetic_account())
    account_path = where / "synthetic-account.json"
    apply_k1(unit, head, account_path, row)
    unit["compatibility"] = compat.profile(unit)
    unit["compatibility"]["kernel_qualification_sha256"] = r.digest(r.encode(unit["kernel_qualification"]))
    unit["account_sha256"] = r.digest(account_path.read_bytes())
    return unit, account_path, staged


def build_fit(where, repo, row, head):
    import fit_controls as fitctl
    fitctl.HEAD = head
    unit, staged, account_path = fitctl.make(where, mode="sequential", threads=row["threads"],
                                             births=row["births"], repo=None)
    account_path.write_bytes(r.encode(synthetic_account()))
    apply_k1(unit, head, account_path, row)
    fitctl.bind(unit, staged)
    unit["compatibility"]["kernel_qualification_sha256"] = r.digest(r.encode(unit["kernel_qualification"]))
    unit["linux"]["output_root"] = str((where / "output").resolve())
    unit["account_sha256"] = r.digest(account_path.read_bytes())
    return unit, account_path, staged


def stage(root, repo, row, head):
    where = case_directory(root, row["case_id"])
    where.parent.mkdir(parents=True, exist_ok=True)
    if where.exists() or where.is_symlink():
        raise RuntimeError("case directory already exists")
    source = row["source_file"]
    if source == "inert.c":
        unit, account_path, staged = build_inert(where, repo, row, head)
    elif source == "compat2_inert.c":
        unit, account_path, staged = build_compat(where, repo, row, head)
    elif source == "fit_inert.c":
        unit, account_path, staged = build_fit(where, repo, row, head)
    else:
        raise RuntimeError("unknown fixture")
    if unit["overlay_head"] != head:
        raise RuntimeError("head is not bound to the unit")
    sign(where, unit)
    r.atomic_write(where / "paths.json", dict(account=str(account_path), receipt=str(where / "receipt.json"),
                                              output=unit["linux"]["output_root"], repo=str(staged),
                                              argv=unit["argv"]))
    return where, unit, account_path


def source_identity(repo, source_file):
    path = repo / "tools/dd1_linux" / source_file
    raw = path.read_bytes()
    return dict(path="tools/dd1_linux/" + source_file, sha256=r.digest(raw), bytes=len(raw))


def spawn(head, root, case_id):
    env = os.environ.copy()
    env[CONTROLLER] = "1"
    return subprocess.Popen([sys.executable, "-I", "-B", "-S", str(Path(__file__).resolve()),
                             "--out", str(root), "--case", case_id],
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def wait_live(proc, output, account_path):
    end = time.monotonic() + 20
    while time.monotonic() < end:
        if proc.poll() is not None:
            return None
        marker = Path(output) / "capture" / "stdout.bin"
        try:
            rows = r.read(account_path)["recovery"].get("unit_reservations_v2", [])
        except (OSError, r.ReservationError, KeyError):
            rows = []
        if rows and rows[-1].get("processes") and marker.is_file() and b"LIVE\n" in marker.read_bytes():
            return rows[-1]["processes"]
        time.sleep(0.02)
    return None


def controller_main(args):
    where = case_directory(args.root, args.case)
    meta = r.read(where / "paths.json")
    unit = r.read(where / "unit.json")
    if unit.get("overlay_head") != args.head:
        refuse("head is not bound to the unit")
    import dd1_meter_entry as entry
    try:
        result = entry._run_inert_unit(list(meta["argv"]), unit=unit, account_path=Path(meta["account"]),
                                        receipt_path=Path(meta["receipt"]), output=Path(meta["output"]),
                                        head=args.head, repo=Path(meta["repo"]))
        sys.stdout.write(json.dumps(result) + "\n")
        return 0
    except Exception as exc:
        sys.stdout.write(json.dumps({"pre_release_error": type(exc).__name__ + ":" + str(exc)}) + "\n")
        return 2


def run_case(args, row):
    before = _observed_cpu_ns()
    outcome = collect(args, row)
    import dd1_linux_backend as backend
    reaped, adopted = backend.reap_adopted()
    account = None
    if outcome["account_path"] is not None:
        try:
            account = r.read(outcome["account_path"])
        except (OSError, r.ReservationError):
            pass
    evidence = assemble_evidence(row, outcome["where"], outcome["unit"], account, outcome)
    if not reaped:
        evidence["identities_absent"] = False
    classification, reasons = classify(row["case_id"], evidence)
    if outcome["exc"] is not None:
        reasons.append(type(outcome["exc"]).__name__ + ": " + str(outcome["exc"]))
    return dict(case=row["case_id"].split("_")[0], case_id=row["case_id"],
                classification=classification, reasons=reasons,
                cpu_ns=max(0, _observed_cpu_ns() - before),
                kernel_release=platform.release(), kernel_version=platform.version(),
                adopted=adopted, controller_stdout=outcome["stdout"], controller_stderr=outcome["stderr"])


def adopt_orphans():
    import ctypes
    r.need(platform.system() == "Linux", "Linux control host required")
    r.need(ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0, "driver subreaper unavailable")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--case")
    group.add_argument("--all", action="store_true")
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)
    rows = plan() if args.all else [row for row in plan()
        if args.case in (row["case_id"], row["case_id"].split("_")[0])]
    if not rows:
        parser.error("unknown case")
    args.root = args.out.resolve()
    args.head = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                               check=True, capture_output=True, text=True).stdout.strip()
    if os.environ.get(CONTROLLER) == "1":
        if args.all:
            parser.error("controller requires one case")
        args.case = rows[0]["case_id"]
        return controller_main(args)
    # A new destination prevents overwriting earlier evidence or following planted links.
    if args.out.is_symlink() or args.out.absolute() != args.root:
        parser.error("output must be unaliased")
    if args.root.is_relative_to(ROOT) and not args.root.is_relative_to(ROOT / "tools/dd1_linux/build"):
        parser.error("repository output must be under gitignored tools/dd1_linux/build")
    args.root.mkdir(parents=True, exist_ok=False)
    problems = build_problems(ROOT)
    if not problems:
        try:
            adopt_orphans()
        except (OSError, AttributeError, r.ReservationError) as exc:
            problems = [str(exc)]
    records = []
    for row in rows:
        args.case = row["case_id"]
        record = dict(case=row["case_id"].split("_")[0], case_id=row["case_id"],
                      classification="INCONCLUSIVE", reasons=list(problems), cpu_ns=0,
                      kernel_release=platform.release(), kernel_version=platform.version())
        if not problems:
            try:
                record = run_case(args, row)
            except Exception as exc:
                record["reasons"] = [type(exc).__name__ + ": " + str(exc)]
        r.atomic_write(args.root / (record["case"] + ".json"), record)
        records.append(record)
    summary = dict(head=args.head, cases=records, cpu_ns=sum(row["cpu_ns"] for row in records),
                   kernel_release=platform.release(), kernel_version=platform.version())
    r.atomic_write(args.root / "SUMMARY.json", summary)
    print(json.dumps({row["case"]: row["classification"] for row in records}, sort_keys=True))
    return 0 if all(row["classification"] == "EXPECTED" or
                    (row["case"] == "KC15" and row["classification"] == "NOT_REACHABLE_ON_HOST")
                    for row in records) else 1


if __name__ == "__main__":
    raise SystemExit(main())

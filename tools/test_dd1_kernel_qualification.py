"""Pure DD1-KERNEL-COMPAT-1 K1 checks. No kernel, subprocess, engine, or fixture build."""
from __future__ import annotations
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import inspect
import io
import json
import os
import platform
import shutil
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "dd1_linux"))
import dd1_compatibility as compat
import dd1_kernel_qualification as kq
import dd1_linux_backend as backend
import dd1_linux_snapshot as snap
import dd1_meter_entry as entry
import dd1_reservations as r
import dd1_runtime_fit as fitmod
import kernel_compat_controls as controls

REAL_HELPER = snap.PINNED_HELPER_SHA256
REAL_INERT = entry.INERT_BINARIES
REAL_FIT = fitmod.INERT_BINARY
REAL_LIBC = compat.LIBC

HEAD = "a" * 40
INSIDE = datetime(2026, 9, 26, 18, 0, tzinfo=timezone.utc)
AT_DEADLINE = datetime(2026, 9, 27, 11, 2, tzinfo=timezone.utc)
LEGACY_NOW = datetime(2026, 9, 18, tzinfo=timezone.utc)
SOURCE = b"inert source"
CASE_RAW = 8_388_608
BASE_HEAD = "c17ae971a447c28e597b78d0ecb5eb29f36e644a"
REMOTE_MAIN = "07b5aa9dec8436132a524511d5438c510e322070"
HELPER_PIN = "41a4529af3bb2fb3f065d164dee8ac9cd2af7d761311c5ee63538347a44e45a4"


class FrozenClock(datetime):
    instant = INSIDE

    @classmethod
    def now(cls, tz=None):
        return cls.instant


class Proc:
    def __init__(self, out, code=0):
        self.out, self.code, self.returncode = out, code, None

    def poll(self):
        return self.returncode

    def communicate(self, timeout=None):
        self.returncode = self.code
        return self.out, ""

    def kill(self):
        self.returncode = -9


class Ctx:
    def __init__(self, files, kind="empirical", receipts=None):
        self.files, self.kind = files, kind
        self.receipts = receipts or {}

    def resolve(self, locator):
        return self.files.get(locator)


def host_facts(**over):
    host = {key: (list(value) if isinstance(value, list) else value)
            for key, value in kq.QUALIFIED_IDENTITY.items()}
    host.update(over)
    return host


def profile(head=HEAD, **over):
    body = dict(schema=kq.SCHEMA, operation=kq.OPERATION, selection=kq.SELECTION, source_head=head,
                status="REQUALIFYING", mode="inert_control", host_identity=host_facts(),
                primitives=sorted(kq.PRIMITIVES))
    body.update(over)
    return body


def unit(**over):
    qual = over.pop("qualification", {})
    body = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=kq.OPERATION, overlay_head=HEAD,
                mode="inert_control", operation_start_utc=kq.INERT_RESERVATION_POLICY["start_utc"],
                operation_deadline_utc=kq.INERT_RESERVATION_POLICY["deadline_utc"],
                kernel_qualification=profile(**qual))
    body.update(over)
    return body


def k_account(**recovery):
    policy = kq.INERT_RESERVATION_POLICY
    body = dict(id="DD1-KERNEL-COMPAT-1", selection=policy["selection"], starts_used=0,
                starts_cap=policy["starts_cap"], cpu_ns_used=0, cpu_ns_cap=policy["cpu_ns_cap"],
                raw_bytes_used=0, raw_bytes_cap=policy["raw_bytes_cap"], executors=1,
                per_invocation_cpu_seconds=30, first_engine_launch_utc=policy["start_utc"],
                deadline_utc=policy["deadline_utc"], unit_reservations_v2=[],
                events=[{"note": "SYNTHETIC K1 inert reservation account; no historical credit"}])
    body.update(recovery)
    return dict(schema="DD1-KERNEL-COMPAT-1-SYNTHETIC-ACCOUNT-1", synthetic=True, recovery=body)


def legacy_account():
    return dict(schema="DD1-N0-RECOVERY-1-ACCOUNT-1", synthetic=True,
        historical=dict(attempt="1/1 consumed", starts_used=1277, starts_cap=8192,
            starts_remaining_arithmetic=6915, spendable=False, cpu_seconds="UNKNOWN",
            elapsed_seconds="UNKNOWN", raw_bytes="UNKNOWN"),
        recovery=dict(id=r.OPERATION, starts_used=2040, starts_cap=r.STARTS_CAP,
            cpu_ns_used=398617197992, cpu_ns_cap=r.CPU_CAP, raw_bytes_used=893139,
            raw_bytes_cap=r.RAW_CAP, executors=1, per_invocation_cpu_seconds=300,
            first_engine_launch_utc=r.FIRST, deadline_utc=r.DEADLINE,
            events=[{"note": "SYNTHETIC copy of immutable historical observations"}]))


def disposition(u, authority="owner:ash"):
    body = dict(schema=kq.DISPOSITION_SCHEMA, operation=kq.OPERATION, owner_selection=kq.SELECTION,
                profile_sha256=kq.profile_sha256(u), source_head=u["overlay_head"],
                kernel_identity=u["kernel_qualification"]["host_identity"],
                independent_review="APPROVE", planner_acceptance="ACCEPTED",
                launch_admitted=True, authority=authority)
    raw = r.encode(body)
    expected = dict(roles={"kernel_qualification_disposition": {"locator": "role", "sha256": r.digest(raw)}},
                    receipt_authorities={"kernel_qualification_disposition":
                                         {"authority": authority, "sha256": r.digest(raw)}})
    ctx = Ctx({"role": raw}, receipts={"kernel_qualification_disposition": raw})
    return raw, expected, ctx


class KernelQualificationTests(unittest.TestCase):
    def test_legacy_no_profile_6_18_44_passes(self):
        kq.require({}, host_facts(kernel_release="6.18.44"))

    def test_legacy_no_profile_6_12_94_fails(self):
        with self.assertRaisesRegex(r.ReservationError, "unsupported host/ABI; no fallback"):
            kq.require({}, host_facts())

    def test_requalifying_inert_6_12_94_passes(self):
        kq.require(unit(), host_facts())

    def test_requalifying_rejected_for_engineering_native(self):
        u = unit(mode="engineering", qualification={"mode": "engineering"})
        with self.assertRaisesRegex(r.ReservationError, "REQUALIFYING is inert-control only"):
            kq.require(u, host_facts())
        with self.assertRaisesRegex(r.ReservationError, "not native authority"):
            kq.native_bindings(u, {"roles": {}}, Ctx({}))

    def test_host_release_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["kernel_release"] = "6.18.44"
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_host_version_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["kernel_version"] = "#1 different"
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_host_machine_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["machine"] = "aarch64"
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_host_pointer_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["pointer_bytes"] = 4
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_host_libc_change_rejects(self):
        u = unit()
        u["kernel_qualification"]["host_identity"]["libc"] = ["glibc", "2.39"]
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_wrong_selection_rejects(self):
        u = unit()
        u["kernel_qualification"]["selection"] = 1
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_wrong_operation_rejects(self):
        u = unit()
        u["kernel_qualification"]["operation"] = "DD1-N0-RECOVERY-1"
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_wrong_source_head_rejects(self):
        u = unit()
        u["kernel_qualification"]["source_head"] = "b" * 40
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_missing_primitive_rejects(self):
        u = unit()
        u["kernel_qualification"]["primitives"] = sorted(kq.PRIMITIVES - {"cgroup_v2"})
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_extra_primitive_rejects(self):
        u = unit()
        u["kernel_qualification"]["primitives"] = sorted(kq.PRIMITIVES) + ["ptrace"]
        with self.assertRaises(r.ReservationError):
            kq.require(u, host_facts())

    def test_extra_field_rejects(self):
        u = unit()
        u["kernel_qualification"]["boot_id"] = "not-a-profile-field"
        with self.assertRaisesRegex(r.ReservationError, "no extra fields"):
            kq.require(u, host_facts())

    def test_missing_disposition_rejects_native(self):
        u = unit(mode="engineering", qualification={"status": "QUALIFIED", "mode": "engineering"})
        with self.assertRaisesRegex(r.ReservationError, "missing kernel qualification disposition"):
            kq.native_bindings(u, {"roles": {}}, Ctx({}))

    def test_synthetic_disposition_rejects_native(self):
        u = unit(mode="engineering", qualification={"status": "QUALIFIED", "mode": "engineering"})
        _raw, expected, ctx = disposition(u, authority="synthetic:k1")
        with self.assertRaisesRegex(r.ReservationError, "unauthenticated kernel qualification issuer"):
            kq.native_bindings(u, expected, ctx)
        _raw, expected, ctx = disposition(u)
        ctx.kind = "synthetic"
        with self.assertRaisesRegex(r.ReservationError, "synthetic native authority"):
            kq.native_bindings(u, expected, ctx)
        _raw, expected, ctx = disposition(u)
        ctx.receipts["kernel_qualification_disposition"] = b"mismatch"
        with self.assertRaisesRegex(r.ReservationError, "unauthenticated kernel qualification issuer"):
            kq.native_bindings(u, expected, ctx)

    def test_staged_controller_source_substitution_differs(self):
        loaded = Path(kq.__file__).read_bytes()
        staged = loaded.replace(b"DD1-KERNEL-QUALIFICATION-1", b"DD1-KERNEL-QUALIFICATION-0", 1)
        self.assertNotEqual(loaded, staged)
        self.assertNotEqual(r.digest(loaded), r.digest(staged))
        prepare = Path(snap.__file__).read_text()
        self.assertIn("loaded controller source differs", prepare)
        self.assertIn("res://tools/dd1_kernel_qualification.py", snap.HELPER_SOURCES)
        self.assertEqual(snap.PINNED_HELPER_SHA256,
                         "41a4529af3bb2fb3f065d164dee8ac9cd2af7d761311c5ee63538347a44e45a4")

    def test_k2_plan_is_exactly_16_cases(self):
        rows = controls.plan()
        self.assertEqual(len(rows), 16)
        caps = [row["cpu_cap"] for row in rows]
        self.assertTrue(all(cap <= 30 for cap in caps))
        self.assertEqual(sum(caps), 204)
        self.assertLessEqual(sum(caps), 240)
        self.assertEqual(sum(caps) + controls.BUILD_RESERVE, 264)
        self.assertLessEqual(sum(caps) + controls.BUILD_RESERVE, controls.AGGREGATE)
        ids = [row["case_id"] for row in rows]
        self.assertEqual(len(set(ids)), 16)
        self.assertEqual(rows[8]["kill"], "controller")
        self.assertEqual(rows[9]["kill"], "supervisor")
        self.assertEqual(rows[12]["threads"], 14)
        self.assertEqual(rows[12]["births"], 13)
        self.assertEqual(rows[13]["births"], 14)
        self.assertEqual(rows[14]["special"], "ia32_reachability")
        for row in rows:
            self.assertEqual(row["argv_tokens"][0], "/workload")
            self.assertNotIn("godot", " ".join(row["argv_tokens"]).lower())
            self.assertTrue(row["required_observation"])
            self.assertNotIn("threads", rows[0])




class LedgerTests(unittest.TestCase):
    POSITIVE = frozenset((
        "KC01_STRICT_POSITIVE", "KC02_READONLY_ESCAPE", "KC03_CLONE3_FALLBACK",
        "KC11_COMPAT_COMBINED", "KC12_CPU_ABOVE_3", "KC13_FIT_14_BOUNDARY",
        "KC15_IA32_REACHABILITY"))

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        self.origin = controls.ROOT
        self._clock = controls.datetime
        self._boot = controls._live_boot_id_sha256
        self._absent = controls._identity_absent
        self._cpu = controls._observed_cpu_ns
        self._stage = controls.stage
        self._spawn = controls.spawn
        self._wait = controls.wait_live
        self._signal = controls._signal_pid
        self._write = r.atomic_write
        self.boot_hash = "c" * 64
        FrozenClock.instant = INSIDE
        controls.datetime = FrozenClock
        controls._live_boot_id_sha256 = lambda: self.boot_hash
        controls._identity_absent = lambda identity: True
        self.clone = self.root / "clone"
        for name in snap.HELPER_SOURCES:
            dest = self.clone / name[6:]
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(self.origin / name[6:], dest)
        for name in ("inert.c", "compat2_inert.c", "fit_inert.c"):
            shutil.copyfile(self.origin / "tools/dd1_linux" / name, self.clone / "tools/dd1_linux" / name)
        build = self.clone / "tools/dd1_linux/build"
        build.mkdir(parents=True)
        self.blobs = {
            "supervisor": b"supervisor-bytes", "inert": b"inert-bytes",
            "compat2-inert": b"compat2-bytes", "fit-inert": b"fit-bytes", "libc.so.6": b"libc-bytes"}
        for name, raw in self.blobs.items():
            (build / name).write_bytes(raw)
        controls.ROOT = self.clone
        self.patch_pins()
        self.write_k0()
        (self.root / "LOCK").write_bytes(b"")

    def tearDown(self):
        controls.ROOT = self.origin
        controls.datetime = self._clock
        controls._live_boot_id_sha256 = self._boot
        controls._identity_absent = self._absent
        controls._observed_cpu_ns = self._cpu
        controls.stage = self._stage
        controls.spawn = self._spawn
        controls.wait_live = self._wait
        controls._signal_pid = self._signal
        r.atomic_write = self._write
        snap.PINNED_HELPER_SHA256 = REAL_HELPER
        entry.INERT_BINARIES = REAL_INERT
        fitmod.INERT_BINARY = REAL_FIT
        compat.LIBC = REAL_LIBC
        FrozenClock.instant = INSIDE
        self.tmp.cleanup()


    def source_map(self, clone=None):
        clone = self.clone if clone is None else clone
        return {name: r.digest((clone / name[6:]).read_bytes()) for name in snap.HELPER_SOURCES}

    def k0_body(self, durable=None, clone=None, head=HEAD):
        durable = self.root if durable is None else durable
        clone = self.clone if clone is None else clone
        primitives = {name: True for name in (
            "seccomp_user_notif", "user_namespace", "mount_namespace", "network_namespace",
            "readonly_bind_remount", "subreaper", "pdeathsig", "cgroup_v2")}
        primitives.update(rlimit_cpu_soft=1, rlimit_cpu_hard=1)
        return dict(
            schema="DD1-KERNEL-COMPAT-1-K0", operation=kq.OPERATION, selection_comment=5845725453,
            selection_timestamp_utc="2026-09-26T11:02:00Z", deadline_utc="2026-09-27T11:02:00Z",
            custodian="Tushar", executor="grokbot-vm", durable_root=str(durable),
            lock=dict(path=str(Path(durable) / "LOCK"), acquired=True, locker_pid=1,
                      locker_start_ticks=2, acquired_at_utc="2026-09-26T11:02:00Z",
                      same_unix_user_advisory_only=True),
            clone=dict(path=str(clone), head=head, tree="b" * 40, clean=True,
                       shared_clone_modified=False, remote_main=REMOTE_MAIN),
            host=dict(hostname="test-host", os_id="debian", os_version="13",
                      kernel_release=kq.QUALIFIED_IDENTITY["kernel_release"],
                      kernel_version=kq.QUALIFIED_IDENTITY["kernel_version"],
                      machine="x86_64", pointer_bytes=8, libc=["glibc", "2.41"],
                      python=platform.python_version(), boot_id_sha256=self.boot_hash, cgroup_v2=True),
            resources=dict(vcpus=1, memory_total_bytes=1, memory_available_bytes=1, swap_total_bytes=0,
                           disk_free_bytes=1, load_1m=0.1),
            primitives=primitives,
            github=dict(ls_remote_main=REMOTE_MAIN, authenticated_gh_api_available=True),
            persistence=dict(home_root_expected_persistent=True, usr_may_reset_on_computer_update=True,
                             flock_path="flock", python_path="python3", cc_path="cc",
                             openssh_reinstall_after_update_risk=True),
            helper=dict(baseline_sha256=HELPER_PIN, compiled_in_k0=False),
            helper_sources_sha256=self.source_map(clone),
            counters=dict(workload_releases=0, compile_commands=0, engine_runs=0, source_mutations=0))


    def invoke(self, args):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            try:
                code = controls.main(args)
            except SystemExit as exc:
                return exc.code, out.getvalue(), err.getvalue()
        return code, out.getvalue(), err.getvalue()



    def evidence(self, case_id):
        planned = controls.row_for(case_id)
        success = case_id in self.POSITIVE or case_id == "KC09_CONTROLLER_KILL"
        report, capture = {}, {"save.json": None, "stdout.bin": None, "save.bin": None}
        src_input = frozen = None
        if case_id == "KC01_STRICT_POSITIVE":
            report.update(thread_births_including_main=3, execs=1)
            capture["save.json"] = b'{"v":2}\n'
            capture["stdout.bin"] = b"OK SAVE THREADS\n"
        elif case_id == "KC02_READONLY_ESCAPE":
            capture["stdout.bin"] = b"ISOLATED\n"
            src_input = b"IMMUTABLE\n"
        elif case_id == "KC03_CLONE3_FALLBACK":
            report.update(clone3_denied=1, thread_births_including_main=1)
            capture["stdout.bin"] = b"errno=38\n"
        elif case_id == "KC04_STRICT_THREAD_CEILING":
            report.update(last_denied_syscall=56, execs=1, thread_births_including_main=4)
        elif case_id == "KC05_CPU_EXHAUST":
            report.update(signal=9, thread_births_including_main=3, workload_cpu_seconds=10)
        elif case_id == "KC06_RAW_OVERWRITE":
            report.update(last_denied_syscall=18, reserved_before_writes=1_000_000_000, raw_cap=1_000_000_000)
        elif case_id == "KC07_SOCKET_DENY":
            report.update(last_denied_syscall=41, execs=1, thread_births_including_main=1)
        elif case_id == "KC08_X32_ABI_KILL":
            report.update(signal=31)
            capture["stdout.bin"] = b"clean\n"
        elif case_id == "KC11_COMPAT_COMBINED":
            capture["save.bin"] = b"COMPAT2\n"
            frozen = b"FROZEN-INERT\n"
        elif case_id == "KC12_CPU_ABOVE_3":
            report.update(workload_cpu_seconds=5)
            frozen = b"FROZEN-INERT\n"
        elif case_id == "KC13_FIT_14_BOUNDARY":
            report.update(thread_limit=14, profile_mode=2)
            capture["save.bin"] = b"FIT1\n"
            capture["stdout.bin"] = b"MODE:0555 owner=1 group=1 other=1\n"
        elif case_id == "KC15_IA32_REACHABILITY":
            report.update(signal=31)
        elif case_id == "KC16_NESTED_NAMESPACE_DENY":
            report.update(last_denied_syscall=272, execs=1, thread_births_including_main=1)
        z = dict(success=success, cleanup_confirmed=True, native_qualified=False, n0_accepted=False,
                 helper_sha256=snap.PINNED_HELPER_SHA256, supervisor_report=report)
        if case_id == "KC11_COMPAT_COMBINED":
            z.update(compatibility_verdict=True, strict_verdict=False,
                     classification=dict(process_refusals=1, naming_refusals=1),
                     refused_requests=[dict(attribution="CAPABILITY_CLASS_ONLY")])
        elif case_id == "KC12_CPU_ABOVE_3":
            z.update(classification=dict(workload_cpu_soft=6, workload_cpu_hard=6,
                                         supervisor_cpu_soft=2, supervisor_cpu_hard=2),
                     controller_cpu_limits=[3, 3])
        state = "RESERVED" if case_id == "KC09_CONTROLLER_KILL" else ("COMPLETE" if success else "FAILED")
        row = dict(unit_id=case_id, starts=1, cpu_ns=planned["cpu_cap"] * 1_000_000_000, raw_bytes=CASE_RAW,
                   state=state, processes={
                       "controller": {"pid": 11, "start_ticks": 1, "boot_id": "b"},
                       "supervisor": {"pid": 12, "start_ticks": 2, "boot_id": "b"},
                       "workload": {"pid": 13, "start_ticks": 3, "boot_id": "b"}})
        return dict(exit=-9 if case_id == "KC09_CONTROLLER_KILL" else 0, stdout_one=True, z=z,
                    account_readable=True, row=row, exception=False, timeout=False, live=True,
                    killed=("controller" if case_id == "KC09_CONTROLLER_KILL"
                            else "supervisor" if case_id == "KC10_SUPERVISOR_KILL" else None),
                    identities_absent=True, source_same=True, unit_raw_bytes=CASE_RAW, capture=capture,
                    capture_bytes=10, src_input=src_input, src_moved=False, src_hardlink=False,
                    src_original=False, src_frozen=frozen)

    def lay_down(self, root, row, evidence):
        where = Path(root) / "dd1-kernel-compat-1" / row["case_id"]
        where.mkdir(parents=True)
        source = where / "source"
        source.mkdir()
        capture = where / "output" / "capture"
        capture.mkdir(parents=True)
        for name, data in evidence["capture"].items():
            if data is not None:
                (capture / name).write_bytes(data)
        if evidence["src_input"] is not None:
            (source / "input").write_bytes(evidence["src_input"])
        if evidence["src_frozen"] is not None:
            (source / "inputs").mkdir()
            (source / "inputs" / "frozen.txt").write_bytes(evidence["src_frozen"])
        account = where / "ACCOUNT.json"
        r.atomic_write(account, dict(recovery=dict(unit_reservations_v2=[evidence["row"]])))
        r.atomic_write(where / "paths.json", dict(repo=str(source)))
        unit = dict(raw_bytes=evidence["unit_raw_bytes"], linux=dict(output_root=str(where / "output")))
        return where, unit, account












    def test_classify_expected_vs_stop(self):
        ids = [row["case_id"] for row in controls.plan()]
        for case_id in ids:
            with self.subTest(case_id=case_id, kind="expected"):
                kind, reasons = controls.classify(case_id, self.evidence(case_id))
                self.assertEqual(kind, "EXPECTED", reasons)
            with self.subTest(case_id=case_id, kind="contradiction"):
                bad = self.evidence(case_id)
                if case_id == "KC09_CONTROLLER_KILL":
                    bad["exit"] = 0
                else:
                    bad["exit"] = 1
                self.assertEqual(controls.classify(case_id, bad)[0], "INCOMPATIBLE")
            with self.subTest(case_id=case_id, kind="missing"):
                missing = self.evidence(case_id)
                if case_id == "KC09_CONTROLLER_KILL":
                    missing["row"] = dict(missing["row"])
                    missing["row"].pop("state")
                else:
                    missing["z"] = dict(missing["z"])
                    missing["z"].pop("cleanup_confirmed")
                self.assertEqual(controls.classify(case_id, missing)[0], "INCONCLUSIVE")
            if case_id == "KC15_IA32_REACHABILITY":
                continue
            other = self.evidence(case_id)
            other["z"] = dict(other["z"])
            report = dict(other["z"].get("supervisor_report") or {})
            report["signal"] = 11
            other["z"]["supervisor_report"] = report
            other["z"]["success"] = False
            if isinstance(other["row"], dict) and case_id != "KC09_CONTROLLER_KILL":
                other["row"] = dict(other["row"])
                other["row"]["state"] = "FAILED"
            self.assertNotEqual(controls.classify(case_id, other)[0], "NOT_REACHABLE_ON_HOST")
        segv = self.evidence("KC15_IA32_REACHABILITY")
        segv["z"] = dict(segv["z"])
        segv["z"]["success"] = False
        segv["z"]["supervisor_report"] = dict(segv["z"]["supervisor_report"], signal=11)
        segv["row"] = dict(segv["row"], state="FAILED")
        self.assertEqual(controls.classify("KC15_IA32_REACHABILITY", segv)[0], "NOT_REACHABLE_ON_HOST")
        exited = self.evidence("KC15_IA32_REACHABILITY")
        exited["exit"] = 32
        self.assertEqual(controls.classify("KC15_IA32_REACHABILITY", exited)[0], "INCOMPATIBLE")
        self.assertEqual(controls.classify("KC15_IA32_REACHABILITY", self.evidence("KC15_IA32_REACHABILITY"))[0], "EXPECTED")


    def test_kc02_staging_binds_escape_input(self):
        fake = self.root / "escape-clone"
        names = snap.HELPER_SOURCES | {"res://tools/dd1_linux/inert.c"}
        for name in names:
            dest = fake / name[6:]
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(b"src:" + name.encode())
        build = fake / "tools/dd1_linux/build"
        build.mkdir(parents=True)
        (build / "supervisor").write_bytes(b"SUP")
        (build / "inert").write_bytes(b"INERT")

        def snapshot(tree):
            found = {}
            for dirpath, _dirs, files in os.walk(tree):
                for name in files:
                    path = Path(dirpath) / name
                    found[str(path.relative_to(tree))] = path.read_bytes()
            return found

        before = snapshot(fake)
        where, unit, _account = controls.stage(str(self.root), fake, controls.row_for("KC02_READONLY_ESCAPE"), HEAD)
        self.assertEqual(unit["argv"][0], "/workload")
        self.assertEqual(unit["argv"][1], "escape")
        self.assertEqual(len(unit["argv"]), 3)
        self.assertEqual(Path(unit["argv"][2]), where / "source" / "input")
        self.assertEqual(unit["source_files"]["res://input"], r.digest(b"IMMUTABLE\n"))
        self.assertEqual((where / "source" / "input").read_bytes(), b"IMMUTABLE\n")
        meta = r.read(where / "paths.json")
        self.assertEqual(Path(meta["repo"]), where / "source")
        self.assertEqual(snapshot(fake), before)
        self.assertIn("repo=None", inspect.getsource(controls.build_compat))
        self.assertIn("repo=None", inspect.getsource(controls.build_fit))


    def test_malformed_disposition_rejects_as_reservation_error(self):
        qualified = unit(mode="engineering", qualification={"status": "QUALIFIED", "mode": "engineering"})
        for raw in (b"not json", b"[]", b"{}", b"\xff"):
            expected = dict(roles={"kernel_qualification_disposition": {"locator": "role", "sha256": r.digest(raw)}},
                            receipt_authorities={})
            with self.assertRaises(r.ReservationError):
                kq.native_bindings(qualified, expected, Ctx({"role": raw}))
        bare = unit(mode="engineering", qualification={"status": "QUALIFIED", "mode": "engineering"})
        bare["kernel_qualification"] = ["not-a-dict"]
        with self.assertRaises(r.ReservationError):
            kq.native_bindings(bare, {"roles": {}}, Ctx({}))


if __name__ == "__main__":
    unittest.main(verbosity=2)

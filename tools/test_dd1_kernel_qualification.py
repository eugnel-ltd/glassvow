"""Pure DD1 qualification, provenance and runner tests; no Linux process execution."""
from copy import deepcopy
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
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

HEAD = "a" * 40
CASE_RAW = 8_388_608


def host_facts(**over):
    host = dict(system="Linux", machine="x86_64", kernel_release="6.12.94+",
                kernel_version="test kernel", pointer_bytes=8, libc=["glibc", "2.41"])
    host.update(over)
    return host


def profile(**over):
    body = dict(schema=kq.SCHEMA, status="REQUALIFYING", mode="inert_control",
                host_identity=host_facts(), primitives=sorted(kq.PRIMITIVES))
    body.update(over)
    return body


def unit(**over):
    qual = over.pop("qualification", {})
    body = dict(schema="DD1-COMPLETE-UNIT-DEMAND-2", operation=kq.OPERATION, overlay_head=HEAD,
                mode="inert_control", kernel_qualification=profile(**qual))
    body.update(over)
    return body


class Ctx:
    def __init__(self, files, kind="empirical", receipts=None):
        self.files, self.kind = files, kind
        self.receipts = receipts or {}

    def resolve(self, locator):
        return self.files.get(locator)


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


    def test_k2_plan_is_exactly_16_cases(self):
        rows = controls.plan()
        self.assertEqual(len(rows), 16)
        caps = [row["cpu_cap"] for row in rows]
        self.assertTrue(all(cap <= 30 for cap in caps))
        self.assertLessEqual(sum(caps), 240)
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

    def test_host_profile_has_no_calendar_or_comment_gate(self):
        for release in ("6.12.94+", "6.18.44", "7.1.0"):
            kq.require({}, host_facts(kernel_release=release))
        for changes in ({"system": "Darwin"}, {"machine": "arm64"}, {"pointer_bytes": 4}):
            facts = host_facts(**changes)
            with self.assertRaises(r.ReservationError):
                kq.require(unit(qualification={"host_identity": facts}), facts)
        with patch.object(kq, "host_facts", return_value=host_facts(kernel_release="next")):
            self.assertEqual(kq.profile()["host_identity"]["kernel_release"], "next")
        self.assertEqual(set(kq.profile()), kq.KEYS)
        self.assertNotIn("deadline_utc", kq.inert_reservation_policy(unit()))
        self.assertNotIn("start_utc", kq.inert_reservation_policy(unit()))


class ClassificationTests(unittest.TestCase):
    POSITIVE = frozenset(("KC01_STRICT_POSITIVE", "KC02_READONLY_ESCAPE", "KC03_CLONE3_FALLBACK",
                          "KC11_COMPAT_COMBINED", "KC12_CPU_ABOVE_3", "KC13_FIT_14_BOUNDARY",
                          "KC15_IA32_REACHABILITY"))

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
                 helper_sha256="b" * 64, supervisor_report=report)
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
                    identities_absent=True, source_same=True, unit_raw_bytes=CASE_RAW, helper_sha256="b" * 64, capture=capture,
                    capture_bytes=10, src_input=src_input, src_moved=False, src_hardlink=False,
                    src_original=False, src_frozen=frozen)

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

    def test_controller_kill_needs_no_final_stdout(self):
        evidence = self.evidence("KC09_CONTROLLER_KILL")
        evidence.update(stdout_one=False, z=None)
        self.assertEqual(controls.classify("KC09_CONTROLLER_KILL", evidence), ("EXPECTED", []))

    def test_helper_identity_is_the_built_identity(self):
        evidence = self.evidence("KC01_STRICT_POSITIVE")
        evidence["helper_sha256"] = "c" * 64
        self.assertEqual(controls.classify("KC01_STRICT_POSITIVE", evidence)[0], "INCOMPATIBLE")
        evidence.pop("helper_sha256")
        self.assertEqual(controls.classify("KC01_STRICT_POSITIVE", evidence)[0], "INCONCLUSIVE")


if __name__ == "__main__":
    unittest.main(verbosity=2)

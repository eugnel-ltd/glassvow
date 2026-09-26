"""De-gating integration seams, with no Linux syscalls or process launches."""
from contextlib import ExitStack
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / 'dd1_linux'))
import dd1_reservations as r
import dd1_kernel_qualification as kq
import dd1_linux_backend as backend
import dd1_linux_snapshot as snap
import dd1_meter_entry as entry
import inert_cases
import compat2_controls
import fit_controls
import kernel_compat_controls as controls

HEAD = 'a' * 40
TODAY = datetime(2026, 9, 26, tzinfo=timezone.utc)
INSIDE = datetime(2026, 9, 18, tzinfo=timezone.utc)


class IsolatedImportTests(unittest.TestCase):
    def test_cli_imports_sibling_builders_with_isolation(self):
        import subprocess
        script = Path(controls.__file__).resolve()
        code = "import runpy; runpy.run_path(%r, run_name='import_only'); import compat2_controls, fit_controls" % str(script)
        result = subprocess.run([sys.executable, '-I', '-B', '-S', '-c', code],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)


class ReservationTests(unittest.TestCase):
    def test_only_backend_test_account_has_no_expiry_but_keeps_caps(self):
        account = inert_cases.account()
        before = r.totals(account, INSIDE)
        with self.assertRaisesRegex(r.ReservationError, 'outside recovery window'):
            r.totals(account, TODAY)
        account['schema'] = r.INERT_TEST_ACCOUNT_SCHEMA
        self.assertEqual(r.totals(account, TODAY), before)
        for field in ('starts_cap', 'cpu_ns_cap', 'raw_bytes_cap', 'executors'):
            changed = deepcopy(account)
            changed['recovery'][field] += 1
            with self.assertRaises(r.ReservationError):
                r.totals(changed, TODAY)
        changed = deepcopy(account)
        changed['synthetic'] = False
        with self.assertRaises(r.ReservationError):
            r.totals(changed, TODAY)
        account['historical']['spendable'] = True
        with self.assertRaises(r.ReservationError):
            r.totals(account, TODAY)

    def test_native_account_still_expires_and_has_immutable_identity(self):
        account = inert_cases.account()
        account['synthetic'] = False
        r.totals(account, INSIDE)
        with self.assertRaisesRegex(r.ReservationError, 'outside recovery window'):
            r.totals(account, TODAY)
        for key in ('id', 'deadline_utc', 'first_engine_launch_utc'):
            changed = deepcopy(account)
            changed['recovery'][key] = 'changed'
            with self.assertRaises(r.ReservationError):
                r.totals(changed, INSIDE)

    def test_kernel_per_case_policy_has_no_calendar_and_keeps_bounds(self):
        account = controls.synthetic_account()
        policy = kq.INERT_RESERVATION_POLICY
        for now in (TODAY, datetime(2035, 1, 1, tzinfo=timezone.utc)):
            self.assertEqual(r.totals(account, now, policy), dict(starts=0, cpu_ns=0, raw_bytes=0))
            r.available(account, 1, 30 * 10**9, 1024, now, policy)
        for args in ((2, 1, 1), (1, 31 * 10**9, 1), (1, 1, policy['raw_bytes_cap'] + 1)):
            with self.assertRaises(r.ReservationError):
                r.available(account, *args, TODAY, policy)
        account['synthetic'] = False
        with self.assertRaises(r.ReservationError):
            r.totals(account, TODAY, policy)

    def test_policy_cannot_be_used_for_native_modes(self):
        for mode in ('focused_fixture', 'fixed_ordinary', 'engineering'):
            with self.assertRaises(r.ReservationError):
                kq.inert_reservation_policy(dict(mode=mode, operation=kq.OPERATION,
                                                kernel_qualification=kq.profile()))

    def test_native_unit_still_checks_operation_and_bindings(self):
        for mode in ('focused_fixture', 'fixed_ordinary', 'engineering'):
            unit = dict(schema='DD1-COMPLETE-UNIT-DEMAND-2', mode=mode,
                        operation=kq.OPERATION, scientific_m=r.M)
            with self.assertRaisesRegex(r.ReservationError, 'wrong unit operation/M'):
                r.validate_unit(unit, ['/workload'], head=HEAD, receipt_sha='r', account_sha='a',
                                source_reader=lambda _: b'')

    def test_inert_grant_is_relative_and_native_grant_is_historical(self):
        for mode, kernel in (('inert_control', True), ('inert_control', False), ('focused_fixture', False)):
            with self.subTest(mode=mode, kernel=kernel), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve()
                account = controls.synthetic_account() if kernel else inert_cases.account()
                if mode != 'inert_control':
                    account['synthetic'] = False
                ap = root / 'account.json'
                r.atomic_write(ap, account)
                source = b'fixture source'
                unit = dict(schema='DD1-COMPLETE-UNIT-DEMAND-2', mode=mode, unit_id='one',
                            operation=kq.OPERATION if kernel else r.OPERATION, scientific_m=r.M,
                            kernel_qualification=kq.profile(), overlay_head=HEAD,
                            receipt_sha256='2' * 64, account_sha256=r.digest(ap.read_bytes()),
                            argv=['/workload'], contained_starts=0, cpu_seconds=12,
                            wall_seconds=60, raw_bytes=8 * 1024 * 1024,
                            source_files={'res://fixture.c': r.digest(source)})
                grants = []
                def runner(grant, output):
                    grants.append(grant)
                    return dict(success=True)
                started = datetime.now(timezone.utc).timestamp()
                result = r.reserve_and_run(ap, unit, command=unit['argv'], head=HEAD,
                    receipt_sha='2' * 64, source_reader=lambda _: source, authority_check=lambda _: None,
                    output=root / 'output', runner=runner, now=INSIDE,
                    policy=kq.INERT_RESERVATION_POLICY if kernel else None)
                self.assertTrue(result['success'])
                if mode == 'inert_control':
                    self.assertGreaterEqual(grants[0]['deadline_unix'], started + 60)
                    self.assertLess(grants[0]['deadline_unix'], started + 62)
                else:
                    self.assertEqual(grants[0]['deadline_unix'], datetime.fromisoformat(r.DEADLINE.replace('Z', '+00:00')).timestamp())


class ControllerTests(unittest.TestCase):
    def limits(self, mode, at, deadline=None):
        with ExitStack() as stack:
            stack.enter_context(patch.object(backend, '_once', False))
            stack.enter_context(patch.object(Path, 'iterdir', return_value=iter([Path('task')])))
            stack.enter_context(patch.object(backend.resource, 'getrusage', return_value=SimpleNamespace(ru_utime=0, ru_stime=0)))
            stack.enter_context(patch.object(backend.resource, 'getrlimit', return_value=(backend.resource.RLIM_INFINITY, backend.resource.RLIM_INFINITY)))
            stack.enter_context(patch.object(backend.resource, 'setrlimit'))
            stack.enter_context(patch.object(backend.ctypes, 'CDLL', return_value=SimpleNamespace(prctl=lambda *_: 0)))
            stack.enter_context(patch.object(backend.signal, 'signal'))
            stack.enter_context(patch.object(backend.signal, 'pthread_sigmask'))
            stack.enter_context(patch.object(backend.signal, 'setitimer'))
            stack.enter_context(patch.object(backend.time, 'time', return_value=at.timestamp()))
            return backend.controller_limits(dict(mode=mode, cpu_seconds=12, wall_seconds=60), deadline)

    def test_inert_controller_today_has_wall_budget(self):
        self.assertEqual(self.limits('inert_control', TODAY)[1], 58)

    def test_native_controller_expiry_and_override_remain_denied(self):
        for mode in ('focused_fixture', 'fixed_ordinary', 'engineering'):
            self.assertEqual(self.limits(mode, INSIDE)[1], 58)
            with self.assertRaisesRegex(r.ReservationError, 'wall envelope'):
                self.limits(mode, TODAY)
            with self.assertRaisesRegex(r.ReservationError, 'cannot be overridden'):
                self.limits(mode, INSIDE, '2030-01-01T00:00:00Z')


class StagingTests(unittest.TestCase):
    def test_every_case_stages_current_helper_fixture_and_libc(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            repo = root / 'repo'
            here = repo / 'tools/dd1_linux'
            build = here / 'build'
            build.mkdir(parents=True)
            names = snap.HELPER_SOURCES | {'res://tools/dd1_linux/inert.c',
                'res://tools/dd1_linux/compat2_inert.c', 'res://tools/dd1_linux/fit_inert.c', 'res://project.godot'}
            for name in names:
                p = repo / name[6:]
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(name.encode())
            for name in ('supervisor', 'inert', 'compat2-inert', 'fit-inert', 'libc.so.6', 'ld-linux-x86-64.so.2'):
                (build / name).write_bytes(('new:' + name).encode())
            with patch.object(compat2_controls, 'ROOT', repo), patch.object(fit_controls, 'ROOT', repo), \
                 patch.object(fit_controls, 'HERE', here), patch.object(fit_controls.fit, 'host_facts', return_value={}):
                for row in controls.plan():
                    where, unit, account = controls.stage(root / 'evidence', repo, row, HEAD)
                    self.assertEqual(unit['linux']['helper']['sha256'], r.digest(b'new:supervisor'))
                    r.validate_unit(unit, unit['argv'], head=HEAD, receipt_sha=unit['receipt_sha256'],
                        account_sha=r.digest(account.read_bytes()),
                        source_reader=lambda name: (Path(r.read(where / 'paths.json')['repo']) / name[6:]).read_bytes(),
                        policy=kq.INERT_RESERVATION_POLICY)
                    if row['source_file'] != 'inert.c':
                        self.assertEqual(unit['compatibility']['libc_sha256'], r.digest(b'new:libc.so.6'))
                        self.assertEqual(unit['compatibility']['executable_sha256'], unit['linux']['runtime']['/workload']['sha256'])


if __name__ == '__main__':
    unittest.main(verbosity=2)

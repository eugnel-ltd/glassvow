"""AMENDMENT 4 falsifiers using byte fixtures and fake processes only."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / 'dd1_linux'))
import build_inert
import compat2_controls
import dd1_compatibility as compat
import dd1_kernel_qualification as kq
import dd1_linux_snapshot as snap
import dd1_meter_entry as entry
import dd1_reservations as r
import dd1_runtime_fit as fit
import kernel_compat_controls as controls


def static_elf():
    raw = bytearray(120)
    raw[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<H', raw, 18, 62)
    struct.pack_into('<Q', raw, 32, 64)
    struct.pack_into('<HH', raw, 54, 56, 1)
    return bytes(raw)


class ProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name).resolve()
        self.build = self.repo / 'tools/dd1_linux/build'
        self.build.mkdir(parents=True)
        self.sources = {}
        for name in snap.BUILD_SOURCES:
            path = self.repo / name[6:]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(('source:' + name).encode())
            self.sources[name] = path.read_bytes()
        self.manifest = dict(sources={n: r.digest(v) for n, v in self.sources.items()}, binaries={})
        for name in controls.ART_KEYS + ('ld-linux-x86-64.so.2', 'inert-dynamic'):
            raw = static_elf() if name == 'supervisor' else ('binary:' + name).encode()
            (self.build / name).write_bytes(raw)
            self.manifest['binaries'][name] = dict(sha256=r.digest(raw), bytes=len(raw))
        self.save()
        def git(argv, **kwargs):
            self.assertEqual(argv[:2], ['git', '-C'])
            self.assertTrue(argv[-1].startswith('HEAD:tools/'))
            return SimpleNamespace(stdout=self.sources['res://' + argv[-1][5:]])
        self.addCleanup(patch.stopall)
        patch.object(snap.subprocess, 'run', side_effect=git).start()
        patch.object(snap, '__file__', str(self.repo / 'tools/dd1_linux_snapshot.py')).start()

    def save(self):
        (self.build / 'BUILD.json').write_bytes(r.encode(self.manifest))

    def test_build_accepts_new_hashes_and_static_helper(self):
        self.assertEqual(controls.build_problems(self.repo), [])
        raw = (self.build / 'supervisor').read_bytes()
        snap.validate_helper(raw, r.digest(raw))
        self.assertNotIn(r.digest(raw), entry.INERT_BINARIES)

    def test_build_rejects_missing_each_artefact(self):
        for name in controls.ART_KEYS + ('ld-linux-x86-64.so.2',):
            with self.subTest(name=name):
                path = self.build / name
                raw = path.read_bytes()
                path.unlink()
                self.assertTrue(controls.build_problems(self.repo))
                path.write_bytes(raw)

    def test_source_hashes_must_match_git_and_disk(self):
        name = next(iter(self.sources))
        (self.repo / name[6:]).write_bytes(b'dirty source')
        self.assertTrue(controls.build_problems(self.repo))
        self.manifest['sources'][name] = r.digest(b'dirty source')
        self.save()
        self.assertTrue(controls.build_problems(self.repo))
        (self.repo / name[6:]).write_bytes(self.sources[name])
        self.manifest['sources'].pop(name)
        self.save()
        self.assertTrue(controls.build_problems(self.repo))

    def test_helper_rejects_forged_digest_size_and_nonstatic_elf(self):
        raw = (self.build / 'supervisor').read_bytes()
        with self.assertRaises(r.ReservationError):
            snap.validate_helper(raw, '0' * 64)
        with self.assertRaises(r.ReservationError):
            snap.validate_helper(raw + b'x', r.digest(raw + b'x'))
        with patch.object(snap, 'elf', return_value=('/lib64/ld-linux-x86-64.so.2', [])):
            with self.assertRaises(r.ReservationError):
                snap.validate_helper(raw, r.digest(raw))
            self.assertTrue(controls.build_problems(self.repo))

    def test_fixture_hashes_are_manifest_bound(self):
        self.assertEqual(snap.fixture_hashes({'fit-inert'}), {self.manifest['binaries']['fit-inert']['sha256']})
        self.assertEqual(len(snap.fixture_hashes()), 4)
        (self.build / 'fit-inert').write_bytes(b'substituted')
        with self.assertRaises(r.ReservationError):
            snap.fixture_hashes({'fit-inert'})

    def test_missing_manifest_keeps_historical_fallback(self):
        (self.build / 'BUILD.json').unlink()
        self.assertEqual(snap.fixture_hashes(), frozenset())
        self.assertTrue(entry.INERT_BINARIES)
        self.assertTrue(fit.INERT_BINARY)
        with self.assertRaises(FileNotFoundError):
            snap.validate_helper(static_elf(), r.digest(static_elf()))

    def test_malformed_manifest_fails_closed(self):
        (self.build / 'BUILD.json').write_text('{')
        self.assertTrue(controls.build_problems(self.repo))
        with self.assertRaises(ValueError):
            snap.fixture_hashes()

    def test_runtime_fit_accepts_built_fixture_and_rejects_other(self):
        digest = self.manifest['binaries']['fit-inert']['sha256']
        unit = dict(mode='inert_control', runtime_fit=dict(executable_sha256=digest), execution_modes={})
        with patch.object(fit, 'host_facts', return_value={}), \
             patch.object(fit, 'limit', return_value=14), patch.object(fit, 'selected', return_value=True), \
             patch.object(fit, 'projection', return_value=dict(path='res://handler')), \
             patch.object(fit, 'mode_map', return_value={}), patch.object(fit, 'describe', side_effect=lambda u, *_: u['runtime_fit']):
            fit.validate(unit, {}, {})
            unit['runtime_fit']['executable_sha256'] = fit.INERT_BINARY
            fit.validate(unit, {}, {})
            unit['runtime_fit']['executable_sha256'] = '0' * 64
            with self.assertRaises(r.ReservationError):
                fit.validate(unit, {}, {})


    def test_meter_accepts_only_built_or_historical_fixture_hash(self):
        raw = (self.build / 'inert').read_bytes()
        prepared = SimpleNamespace(pinned=dict(files={'/workload': (raw, True)}, source={}, setup_raw=0))
        receipt = self.repo / 'receipt.json'
        receipt.write_bytes(b'{}')
        account = self.repo / 'account.json'
        account.write_bytes(r.encode(dict(synthetic=True)))
        output = self.repo / 'output'
        unit = dict(linux=dict(output_root=str(output), workload_raw_bytes=1),
                    contained_starts=0, cpu_seconds=12, raw_bytes=8 * 1024 * 1024,
                    account_sha256=r.digest(account.read_bytes()))
        with patch.object(entry.reservations, 'available'), \
             patch.object(entry.preparation, 'load_sealed'), \
             patch.object(entry, 'require_native_backend', return_value=prepared), \
             patch.object(entry.reservations, 'reserve_and_run', return_value={'success': True}), \
             patch.object(entry.signal, 'setitimer'):
            result = entry._complete(['/workload'], unit, account, receipt, output, 'a' * 40,
                                     self.repo, lambda _: None, None, inert=True)
            self.assertTrue(result['success'])
            prepared.pinned['files']['/workload'] = (b'unknown executable', True)
            with self.assertRaisesRegex(r.ReservationError, 'harmless fixture'):
                entry._complete(['/workload'], unit, account, receipt, output, 'a' * 40,
                                self.repo, lambda _: None, None, inert=True)


class BuildTests(unittest.TestCase):
    def test_build_records_all_outputs_and_toolchain_without_compiling(self):
        for has_dpkg in (False, True):
            with self.subTest(dpkg=has_dpkg), tempfile.TemporaryDirectory() as tmp:
                here = Path(tmp) / 'tools/dd1_linux'
                here.mkdir(parents=True)
                commands = []
                def run(argv, **kwargs):
                    commands.append(argv)
                    if '-o' in argv:
                        Path(argv[-1]).write_bytes(('compiled:' + Path(argv[-1]).name).encode())
                        return SimpleNamespace(returncode=0, stdout='', stderr='')
                    return SimpleNamespace(returncode=0, stdout='cc test version\n' if argv[0] == 'cc' else 'libc6 test\n')
                def copy(source, dest):
                    Path(dest).write_bytes(('runtime:' + Path(dest).name).encode())
                with patch.object(build_inert, 'HERE', here), \
                     patch.object(build_inert.subprocess, 'run', side_effect=run), \
                     patch.object(build_inert.shutil, 'which', return_value='/usr/bin/dpkg-query' if has_dpkg else None), \
                     patch.object(build_inert.shutil, 'copyfile', side_effect=copy), \
                     patch.object(snap, 'build_sources', return_value={'source': 'digest'}), \
                     patch.object(snap, 'verify_build_sources'), \
                     patch.object(snap, 'elf', return_value=('/lib64/ld-linux-x86-64.so.2', ['libc.so.6'])):
                    manifest = build_inert.build()
                self.assertEqual(len([c for c in commands if '-o' in c]), 5)
                self.assertEqual(set(manifest['binaries']), set(controls.ART_KEYS) | {'inert-dynamic', 'ld-linux-x86-64.so.2'})
                self.assertEqual(manifest['toolchain'], dict(cc='cc test version', packages='libc6 test\n' if has_dpkg else None))
                for name, item in manifest['binaries'].items():
                    raw = (here / 'build' / name).read_bytes()
                    self.assertEqual(item, dict(bytes=len(raw), sha256=r.digest(raw)))
                self.assertEqual(r.read(here / 'build/BUILD.json'), json.loads(r.encode(manifest)))


class ProfileTests(unittest.TestCase):
    def test_libc_compares_exact_declared_runtime_entry(self):
        raw = b'host libc security update'
        runtime = {'/workload': dict(sha256=r.digest(b'fixture')),
                   '/lib/x86_64-linux-gnu/libc.so.6': dict(sha256=r.digest(raw))}
        unit = dict(mode='inert_control', stage='identity', contained_starts=0, overlay_head='a' * 40,
                    source_files={}, argv=['/workload'], task=dict(kind='exact-files', stage='identity', files={}),
                    linux=dict(environment=compat.ENVIRONMENT, runtime=runtime, threads=4,
                               helper=dict(sha256=r.digest(b'helper'))))
        unit['compatibility'] = compat2_controls.profile(unit)
        unit['compatibility']['libc_sha256'] = r.digest(raw)
        pinned = dict(helper=b'helper', files={'/workload': (b'fixture', True),
                                             '/lib/x86_64-linux-gnu/libc.so.6': (raw, False)})
        with patch.object(compat, 'validate_task'):
            self.assertEqual(compat.validate_profile(unit, pinned), unit['compatibility'])
            runtime['/lib/x86_64-linux-gnu/libc.so.6']['sha256'] = '0' * 64
            with self.assertRaisesRegex(r.ReservationError, 'profile libc identity'):
                compat.validate_profile(unit, pinned)
            runtime.pop('/lib/x86_64-linux-gnu/libc.so.6')
            runtime['/other/libc.so.6'] = dict(sha256=r.digest(raw))
            with self.assertRaises(r.ReservationError):
                compat.validate_profile(unit, pinned)


class RunnerTests(unittest.TestCase):
    def test_all_continues_after_failures_and_exception(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp).resolve() / 'out'
            called = []
            def run(args, row):
                case = row['case_id'].split('_')[0]
                called.append(case)
                if case == 'KC02':
                    raise RuntimeError('capture defect')
                kind = 'INCOMPATIBLE' if case == 'KC01' else 'EXPECTED'
                return dict(case=case, classification=kind, reasons=['different'] if case == 'KC01' else [],
                            cpu_ns=123, kernel_release='test')
            with patch.object(controls, 'adopt_orphans'), \
                 patch.object(controls, 'build_problems', return_value=[]), \
                 patch.object(controls, 'run_case', side_effect=run), \
                 patch.object(controls.subprocess, 'run', return_value=SimpleNamespace(stdout='a' * 40)), \
                 redirect_stdout(io.StringIO()):
                self.assertEqual(controls.main(['--all', '--out', str(out)]), 1)
            self.assertEqual(called, ['KC%02d' % n for n in range(1, 17)])
            self.assertEqual(len(list(out.glob('KC*.json'))), 16)
            summary = r.read(out / 'SUMMARY.json')
            self.assertEqual(len(summary['cases']), 16)
            self.assertEqual(r.read(out / 'KC02.json')['classification'], 'INCONCLUSIVE')
            self.assertEqual(r.read(out / 'KC16.json')['classification'], 'EXPECTED')
            self.assertEqual(summary['cpu_ns'], 15 * 123)

    def test_build_problem_records_all_cases_without_spawning(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp).resolve() / 'out'
            with patch.object(controls, 'build_problems', return_value=['source mismatch']), \
                 patch.object(controls, 'run_case') as run, \
                 patch.object(controls.subprocess, 'run', return_value=SimpleNamespace(stdout='a' * 40)), \
                 redirect_stdout(io.StringIO()):
                self.assertEqual(controls.main(['--all', '--out', str(out)]), 1)
                run.assert_not_called()
            self.assertEqual(len(list(out.glob('KC*.json'))), 16)

    def test_cpu_partitions_are_reachable(self):
        import dd1_linux_backend as backend
        for row in controls.plan():
            self.assertGreaterEqual(backend.cpu_partition(row['cpu_cap'])['workload'], 1)

    def test_case_timeout_kills_controller(self):
        proc = unittest.mock.Mock()
        proc.communicate.side_effect = [subprocess.TimeoutExpired('fake', 90), ('', '')]
        proc.returncode = -9
        args = SimpleNamespace(root=Path('/unused'), head='a' * 40, case='KC01_STRICT_POSITIVE')
        with patch.object(controls, 'source_identity', return_value={}), \
             patch.object(controls, 'stage', return_value=(Path('/unused'), {}, Path('/unused/account'))), \
             patch.object(controls, 'spawn', return_value=proc):
            outcome = controls.collect(args, controls.row_for(args.case))
        self.assertTrue(outcome['timed_out'])
        proc.kill.assert_called_once()
        timeout = proc.communicate.call_args_list[0].kwargs['timeout']
        self.assertGreater(timeout, 0)
        self.assertLessEqual(timeout, 90)


if __name__ == '__main__':
    unittest.main(verbosity=2)

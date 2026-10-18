#!/usr/bin/env python3
"""Mock compiler/engine processes to prove only shared-builder sequencing."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/godot/native_boot_upload'))
SPEC=importlib.util.spec_from_file_location('mip_shared_builder',ROOT/'tools/godot/native_boot_upload/build.py')
builder=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)


class BuilderTests(unittest.TestCase):
    def exercise(self,root,prerequisites,fail=False,mutate=False):
        archive=root/'source.tar.gz';archive.write_bytes(b'unit-test archive; not an engine input')
        production=root/'production.patch';production.write_text('production')
        observer=root/'observer.py';observer.write_text('# mocked observer')
        dependency=root/'prerequisite.patch';dependency.write_text('dependency')
        args=argparse.Namespace(work=root/'builds',output=root/'evidence',patch=production,observer=observer,
            source_archive=archive,source_archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
            splash=None,test_suite='',prerequisite_patches=[dependency] if prerequisites else [])
        calls=[]

        def extract(_archive,directory):
            tree=directory/'upstream';tree.mkdir(parents=True)
            (tree/'version.py').write_text('major = 4\nminor = 7\npatch = 2\nstatus = "stable"\n')
            (tree/'input').write_text('same original source')
            return tree

        def run(command,cwd,log,timeout):
            log.parent.mkdir(parents=True,exist_ok=True);log.write_text('mocked native process; not executed\n')
            variant=cwd.parent.name
            if command[0]=='patch':
                kind=Path(command[-1]).stem;calls.append((variant,kind))
                if fail and kind=='prerequisite':
                    raise RuntimeError('seeded prerequisite application failure')
                (cwd/'input').write_text((cwd/'input').read_text()+Path(command[-1]).read_text())
            elif '-m' in command:
                calls.append((variant,'compiler'))
                (cwd/'bin').mkdir();binary=cwd/'bin/godot.linuxbsd.template_debug.x86_64'
                binary.write_bytes(b'unit-test executable placeholder');binary.chmod(0o755)
                if mutate and variant=='baseline':
                    dependency.write_text('changed dependency')
            else:
                calls.append((variant,'observer'))

        def version(command,**_kwargs):
            if command[-1]=='--version' and 'godot.' in command[0]:
                return '4.7.2.stable.custom_build.test\n'
            return 'mock compiler/tool version\n'

        with mock.patch.object(builder,'extract',extract),mock.patch.object(builder,'run',run),mock.patch.object(builder.subprocess,'check_output',version):
            if fail or mutate:
                with self.assertRaises((RuntimeError,AssertionError)):
                    builder.build(args)
            else:
                builder.build(args)
        return json.loads((args.output/'build-manifest.json').read_text()),calls

    def test_default_preserves_existing_boot_sequence(self):
        with tempfile.TemporaryDirectory() as temp:
            report,calls=self.exercise(Path(temp),False)
        self.assertEqual(calls,[('baseline','observer'),('baseline','compiler'),('candidate','production'),('candidate','observer'),('candidate','compiler')])
        self.assertEqual(report['prerequisite_patches'],[])
        self.assertEqual(report['native_tests']['status'],'NOT RUN')

    def test_prerequisite_is_identical_and_before_candidate_patch(self):
        with tempfile.TemporaryDirectory() as temp:
            report,calls=self.exercise(Path(temp),True)
        self.assertEqual(calls,[('baseline','prerequisite'),('baseline','observer'),('baseline','compiler'),('candidate','prerequisite'),('candidate','production'),('candidate','observer'),('candidate','compiler')])
        before=report['builds']['baseline']['applied_patches'];after=report['builds']['candidate']['applied_patches']
        self.assertEqual(before,after[:1])
        self.assertEqual(before[0]['role'],'prerequisite')
        self.assertEqual(after[1]['role'],'production')
        self.assertEqual(report['prerequisite_patches'][0]['sha256'],before[0]['sha256'])

    def test_failed_prerequisite_never_reaches_compiler(self):
        with tempfile.TemporaryDirectory() as temp:
            report,calls=self.exercise(Path(temp),True,fail=True)
        self.assertEqual(report['status'],'failed_or_inconclusive')
        self.assertEqual(calls,[('baseline','prerequisite')])

    def test_changed_prerequisite_cannot_change_candidate_identity(self):
        with tempfile.TemporaryDirectory() as temp:
            report,calls=self.exercise(Path(temp),True,mutate=True)
        self.assertEqual(report['status'],'failed_or_inconclusive')
        self.assertNotIn(('candidate','compiler'),calls)


if __name__=='__main__':
    unittest.main()

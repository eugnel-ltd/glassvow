#!/usr/bin/env python3
"""Exam scheduling, merge and 2026-08-14 island-selection contracts."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("balance_exam", Path(__file__).resolve().parents[1] / "tools/balance_exam.py")
exam = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(exam)


class ExamTests(unittest.TestCase):
    def test_shards_cover_original_policy_sequence(self):
        for size in (1, 50, 73, 200, 2000):
            policies = []
            jobs = exam.sweep_jobs(Path("layer1"), size)
            for _, args in jobs:
                flags = dict(arg[2:].split("=", 1) for arg in args[1:])
                first, count = int(flags["policyFirst"]), int(flags["policyCount"])
                policies.extend(range(first, first + count))
                self.assertEqual((flags["rootSeed"], flags["seeds"], flags["seed0"], flags["stage"]),
                                 ("215", "40", "3000", "exam"))
            self.assertEqual(policies, list(range(2000)))

    def test_merge_preserves_bytes_and_order(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shards = [root / str(i) for i in range(3)]
            for i, path in enumerate(shards):
                path.write_bytes(b'{"manifest":{"policyFirst":' + str(i).encode() + b'}}\n' +
                                 b'{"policyIndex":' + str(i).encode() + b', "value":1.0}\n')
            out = root / "merged"
            exam.merge_shards(shards, out)
            self.assertEqual(out.read_bytes(), shards[0].read_bytes() + b''.join(
                path.read_bytes().split(b'\n', 1)[1] for path in shards[1:]))
            shards[1].write_text('{}\n')
            with self.assertRaisesRegex(ValueError, "manifest"):
                exam.merge_shards(shards, out)

    def test_controls_count_error_field_and_keep_historical_order(self):
        rows = [dict(arm=arm, aspect=aspect, vow=vow, outcome="win", error="")
                for arm in reversed(range(1, 5)) for aspect in ("ashwarden", "duskblade") for vow in (5, 0)]
        rows.append(dict(arm=1, aspect="duskblade", vow=0, outcome="loss", error="fault"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "controls"
            path.write_text(json.dumps(dict(runs=rows)))
            result = exam.aggregate_controls(path)
        self.assertEqual(result[0], dict(arm=1, aspect="duskblade", vow=0, wins=1, runs=2,
                                         winRate=.5, stalls=0, errors=1))
        self.assertEqual([(r["arm"], r["aspect"], r["vow"]) for r in result],
                         [(arm, aspect, vow) for arm in range(1, 5)
                          for aspect in ("duskblade", "ashwarden") for vow in (0, 5)])

    def test_selection_ties_threshold_precedence_and_schedule(self):
        cells = [f'{lean}:{tier}' for lean in ('shatter', 'smolder', 'attrition')
                 for tier in ('thin', 'mid', 'fat')]
        grid = {cell: dict(policies=20, winRate=.8) for cell in cells}
        grid[cells[0]]['policies'] = 19  # Even a high rate cannot qualify this cell.
        grid[cells[0]]['winRate'] = 1
        analysis = dict(deckCuts=dict(thinMax=10, midMax=20),
                        medians={'duskblade': dict(shattersPerFight=1, smolderKillsPerFight=1)},
                        grids={'duskblade:v0': grid, 'duskblade:5': grid})
        rows = []
        for vow in (0, 5):
            for i, cell in enumerate(cells):
                lean, tier = cell.split(':')
                for policy in (9, 3):
                    rows.append(dict(aspect='duskblade', vow=vow, policyIndex=policy,
                                     deck={'thin': 10, 'mid': 20, 'fat': 21}[tier], outcome='win',
                                     fights=[dict(shatters=2 if lean == 'shatter' else 1,
                                                  smolderKills=2 if lean != 'attrition' else 1,
                                                  turns=100 if vow == 5 else 10)]))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'merged'
            path.write_text('{}\n' + ''.join(json.dumps(r) + '\n' for r in rows))
            selected, order = exam.select_islands(path, analysis)
            for items in selected.values():
                self.assertEqual(items, [dict(cell=cell, policyIndex=3) for cell in cells[1:7]])
            self.assertEqual(order, list(range(6, 12)) + list(range(6)))
            grid[cells[1]]['policies'] = 0
            grid[cells[2]]['policies'] = 0
            grid[cells[3]]['policies'] = 0
            with self.assertRaisesRegex(ValueError, 'need six cells'):
                exam.select_islands(path, analysis)

    def test_child_commands_niced_and_flags_after_separator(self):
        job = exam.cem_job(Path('island.ndjson'), Path('seeds.json'), 7)
        with patch.object(exam, 'run_command') as run:
            exam.run_jobs([job], Path('/tmp'), 1, 'godot', 19)
        command = run.call_args.args[0]
        self.assertEqual(command[:8], ['nice', '-n', '19', 'godot', '--headless', '-s',
                                      'res://tools/balance_cem.gd', '--'])
        self.assertEqual(command[8:], ['--island=7', '--stage=exam', '--seedsJson=seeds.json',
                         '--samplerRoot=215', '--rootSeed=216', '--trainSeed0=4200',
                         '--holdoutSeed0=5000', '--holdoutCount=200', '--out=island.ndjson'])

    def test_dry_run_never_launches_or_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory) / 'exam'
            with patch.object(exam, 'run_command') as run, patch('builtins.print'):
                self.assertEqual(exam.main(['--out-dir', str(out), '--dry-run']), 0)
            run.assert_not_called()
            self.assertFalse(out.exists())

    def test_zero_exit_script_error_stops_measurement(self):
        with tempfile.TemporaryDirectory() as directory:
            def fail_with_zero(*args, **kwargs):
                kwargs['stdout'].write('SCRIPT ERROR: failed dependency\n')
                return type('Result', (), {'returncode': 0})()
            with patch.object(exam.subprocess, 'run', side_effect=fail_with_zero):
                with self.assertRaisesRegex(RuntimeError, 'exit 0'):
                    exam.run_command(['godot'], Path(directory) / 'log')

    def test_failed_process_stops_measurement(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(exam.subprocess, 'run') as run:
                run.return_value.returncode = 1
                with self.assertRaisesRegex(RuntimeError, 'exit 1'):
                    exam.run_command(['false'], Path(directory) / 'log', (0, 2, 3))


if __name__ == '__main__':
    unittest.main()

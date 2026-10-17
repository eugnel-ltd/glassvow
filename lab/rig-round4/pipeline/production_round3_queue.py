# Resume prepared motion trials one character at a time after the weight trials.
import json
import os
from pathlib import Path
import subprocess
import time

lane = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
pipeline = lane / 'pipeline'
# The existing sequential runner owns these two source files first.
deadline = time.monotonic() + 1800
while not all((lane / 'mobs' / name / 'rig-round3-trunk/reimport-deformation.json').exists() for name in ('ashAcolyte', 'gloomslime')):
    assert time.monotonic() < deadline, 'Weight trials did not complete; resume explicitly'
    time.sleep(15)
queue = [('drownedOne', 'fall'), ('rootheart', 'fall'), ('sporeling', 'fall'), ('thornling', 'fall')]
queue = queue[:1]  # Review the first death trial before expanding the motion family.
results = []
for name, variant in queue:
    output = lane / 'mobs' / name / f'rig-round3-{variant}'
    assert not output.exists(), f'Inspect an existing trial: {output}'
    result = subprocess.run(['python3', str(pipeline / 'production_motion_run.py'), 'mobs', name, 'rig-contact-batch', variant], capture_output=True, text=True)
    log = pipeline / f'production-round3-{name}.log'
    assert not log.exists()
    log.write_text(result.stdout + result.stderr)
    if result.returncode:
        print('TRIAL FAILED', name, 'inspect', str(log), flush=True)
        results.append({'name': name, 'result': 'failed', 'log': str(log)})
        break
    report = json.loads((output / 'reimport-deformation.json').read_text())
    severe = sum(row['max_stretched_edges'] for row in report)
    results.append({'name': name, 'variant': str(output), 'severe_edges': severe, 'result': 'awaiting visual review'})
    print('TRIAL CHECKED', name, 'severe', severe, flush=True)
    (pipeline / 'production-round3-motion-results.json').write_text(json.dumps(results, indent=2) + '\n')

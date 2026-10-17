# Run one isolated motion trial through the existing contact and reimport checks.
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

lane = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
root, name, source_variant, variant = sys.argv[1:]
folder = lane / root / name
spec_path = folder / f'round3-{variant}.json'
settings = json.loads(spec_path.read_text())
steps = [
    [str(folder / source_variant / f'{name}.blend'), '--python', str(lane / 'pipeline/production_motion_trial.py'), '--', str(spec_path)],
    ['--python', str(lane / 'pipeline/ground_batch.py'), '--', settings['source_output'], str(spec_path)],
    ['--python', str(lane / 'pipeline/check_candidate_batch.py'), '--', f'{root}/{name}/{Path(settings["out_dir"]).name}'],
]
for index, step in enumerate(steps):
    deadline = time.monotonic() + 1200
    while os.getloadavg()[0] >= 30:
        assert time.monotonic() < deadline, 'Resource wait exceeded 20 minutes'
        time.sleep(15)
    assert shutil.disk_usage(lane).free / 2**30 >= 100
    result = subprocess.run(['/Applications/Blender.app/Contents/MacOS/Blender', '-b', '--python-exit-code', '1', *step], capture_output=True, text=True)
    text = result.stdout + result.stderr
    (folder / f'round3-{variant}-step{index}.log').write_text(text)
    assert result.returncode == 0, text[-2500:]
report = json.loads((Path(settings['out_dir']) / 'reimport-deformation.json').read_text())
print(name, [(row['clip'], row['max_stretched_edges']) for row in report], flush=True)

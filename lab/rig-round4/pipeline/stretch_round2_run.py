# Run one isolated weight trial. Wait for the engine resource floor.
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

lane = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
blender = '/Applications/Blender.app/Contents/MacOS/Blender'
root, name, variant = sys.argv[1:]
folder = lane / root / name
settings_path = folder / f'round2-{variant}.json'
settings = json.loads(settings_path.read_text())
source = Path(settings['source_output'])
steps = []
if not source.exists():
    steps.append([str(folder / settings.get('source_variant', 'rig-contact-batch') / f'{name}.blend'), '--python', str(lane / 'pipeline' / settings.get('script', 'stretch_round2_weights.py')), '--', str(settings_path)])
if not (Path(settings['out_dir']) / f'{name}.glb').exists():
    steps.append(['--python', str(lane / 'pipeline/ground_batch.py'), '--', str(source), str(settings_path)])
steps.append(['--python', str(lane / 'pipeline/check_candidate_batch.py'), '--', f'{root}/{name}/{Path(settings["out_dir"]).name}'])
for index, step in enumerate(steps):
    deadline = time.monotonic() + 1200
    while os.getloadavg()[0] >= 30:
        assert time.monotonic() < deadline, 'Load did not settle within 20 minutes'
        time.sleep(15)
    assert shutil.disk_usage(lane).free / 2**30 >= 100, 'Disk resource floor'
    result = subprocess.run([blender, '-b', '--python-exit-code', '1', *step], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (folder / f'round2-{variant}-step{index}.log').write_text(result.stdout)
    assert result.returncode == 0, result.stdout[-2500:]
report = json.loads((Path(settings['out_dir']) / 'reimport-deformation.json').read_text())
print(name, variant, [(row['clip'], row['max_stretched_edges']) for row in report], flush=True)

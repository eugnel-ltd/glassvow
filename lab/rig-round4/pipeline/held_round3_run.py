# Guarded sequential runner: each Blender launch requires load < 30 and >= 100 GiB free.
import os, shutil, subprocess, sys
from pathlib import Path
lab = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
blender = '/Applications/Blender.app/Contents/MacOS/Blender'
for step in sys.argv[1:]:
    name, mode = step.split(':')
    load, free = os.getloadavg()[0], shutil.disk_usage(lab).free / 2**30
    print('RESOURCE GUARD', step, round(load, 2), round(free, 3), flush=True)
    if load >= 30 or free < 100:
        sys.exit('Resource floor reached before ' + step)
    if mode == 'batch':
        args = ['--python', str(lab / 'pipeline/check_candidate_batch.py'), '--', f'mobs/{name}Self/rig-round3-held-articulated']
    else:
        args = ['--python', str(lab / 'pipeline/held_round3.py'), '--', str(lab / f'pipeline/held_{name}_round3.json'), mode]
    run = subprocess.run([blender, '-b', '--factory-startup', '--threads', '2', '--python-exit-code', '1', *args],
                         capture_output=True, text=True)
    keep = [line for line in (run.stdout + run.stderr).splitlines()
            if line.startswith(('BUILD', 'ARTICULATION', 'DEFORMATION', 'STRUCTURE', 'INSPECTION', 'CHECK', 'RIG', 'Traceback', 'AssertionError', 'Error', '  File'))
            or 'Error' in line]
    print('\n'.join(keep)[-6000:], flush=True)
    print(step, 'exit', run.returncode, flush=True)
    if run.returncode:
        sys.exit(run.returncode)

# Run the next character only after the current trial completes.
import os
from pathlib import Path
import subprocess
import time

lane = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
for name in ('obsidianGolem', 'gloomslime', 'ashAcolyte', 'abyssalKnight'):
    deadline = time.monotonic() + 1200
    while os.getloadavg()[0] >= 30:
        assert time.monotonic() < deadline, 'Resource wait exceeded 20 minutes'
        time.sleep(15)
    result = subprocess.run(['/Applications/Blender.app/Contents/MacOS/Blender', '-b', '--python-exit-code', '1', '--python', str(lane / 'pipeline/stretch_round2_diagnose.py'), '--', name], capture_output=True, text=True)
    (lane / 'mobs' / name / 'round2-diagnosis.log').write_text(result.stdout + result.stderr)
    assert result.returncode == 0, result.stderr
    print('DIAGNOSIS', name, 'complete', flush=True)

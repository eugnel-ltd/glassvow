# Engine: merge one JSON patch into the repair progress record (dict keys merge one level deep).
#   python3 progress_update.py <patch.json>
import json
from pathlib import Path
import sys

record = Path("/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab/pipeline/production-repair-progress-20261016.json")
data = json.loads(record.read_text())
for key, value in json.loads(Path(sys.argv[1]).read_text()).items():
    if isinstance(value, dict) and isinstance(data.get(key), dict):
        data[key].update(value)
    elif isinstance(value, list) and isinstance(data.get(key), list):
        data[key].extend(value)
    else:
        data[key] = value
record.write_text(json.dumps(data, indent=2) + "\n")
print("PROGRESS UPDATED", sorted(json.loads(Path(sys.argv[1]).read_text())))

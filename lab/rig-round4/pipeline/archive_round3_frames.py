# Archive this lab's superseded evidence. Verify both ends before local removal.
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import sys
import time

lab = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
pipeline = lab / 'pipeline'
rows = json.loads((pipeline / 'current-research-inventory-round2.json').read_text())
active_previews = {Path(row['preview']).resolve() for row in rows}
files = []
# Round 3: keep frames for the selection, round-2 actives, open trials and anything recent.
changes = json.loads((pipeline / 'production-round3-working-selection.json').read_text())['changes']
keep_tails = {f"{n}-{v.removeprefix('rig-round3-')}" for n, v in changes.items()}
keep_words = ('gravewarden', 'hem', 'shade', 'sovereign', 'unlitSelf', 'unobsidianSelf')
recent = time.time() - 1800
for preview in [*pipeline.glob('godot-preview*'), *pipeline.glob('godot-view*')]:
    if not preview.is_dir() or preview.resolve() in active_previews:
        continue
    if any(preview.name.endswith(t) for t in keep_tails) or any(w in preview.name for w in keep_words):
        continue
    for frame in preview.rglob('frame-*.png'):
        if frame.parent.resolve() not in active_previews and frame.stat().st_mtime < recent:
            files.append(frame)
if '--dry-run' in sys.argv:
    print('DRY RUN', len(files), round(sum(f.stat().st_size for f in files) / 2**30, 2), 'GiB')
    raise SystemExit
files = sorted(set(files))
assert files and all(f.is_file() and not f.is_symlink() and f.resolve().is_relative_to(lab) for f in files)
records = [{'path': str(f.relative_to(lab)), 'bytes': f.stat().st_size,
            'sha256': hashlib.sha256(f.read_bytes()).hexdigest()} for f in files]
stamp = time.strftime('%Y%m%d-%H%M%S')
remote_dir = 'Archives/glassvow-asset-lab'
remote_name = f'{remote_dir}/round3-frames-{stamp}.tar'
manifest_path = pipeline / f'archive-{stamp}.json'
manifest = {'source': str(lab), 'archive': remote_name, 'files': records, 'bytes': sum(r['bytes'] for r in records)}
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
subprocess.run(['ssh', 'ds1819-clawdbot', f'mkdir -p {remote_dir}; test ! -e {remote_name}'], check=True)
# tar streams directly to the NAS. No temporary archive consumes engine disk.
upload = subprocess.Popen(['ssh', 'ds1819-clawdbot', f'cat > {remote_name}'], stdin=subprocess.PIPE)
class Stream:
    def __init__(self):
        self.digest = hashlib.sha256()
    def write(self, data):
        self.digest.update(data)
        upload.stdin.write(data)
        return len(data)
    def flush(self):
        upload.stdin.flush()
stream = Stream()
with tarfile.open(fileobj=stream, mode='w|') as archive:
    archive.add(manifest_path, arcname='MANIFEST.json', recursive=False)
    for path in files:
        archive.add(path, arcname=str(path.relative_to(lab)), recursive=False)
upload.stdin.close()
assert upload.wait() == 0
local_hash = stream.digest.hexdigest()
remote_hash = subprocess.check_output(['ssh', 'ds1819-clawdbot', f'sha256sum {remote_name}'], text=True).split()[0]
assert remote_hash == local_hash
# Read every archived payload on the NAS and match its manifest hash.
verify_code = """import tarfile,json,hashlib,sys
with tarfile.open(sys.argv[1]) as t:
 m=json.load(t.extractfile('MANIFEST.json'))
 for r in m['files']:
  f=t.extractfile(r['path']); h=hashlib.sha256(); count=0
  while True:
   b=f.read(1048576)
   if not b: break
   h.update(b);count+=len(b)
  assert count==r['bytes'] and h.hexdigest()==r['sha256'],r['path']
 print('REMOTE CONTENTS PASS',len(m['files']))
"""
import shlex
subprocess.run(['ssh', 'ds1819-clawdbot', 'python3 -c ' + shlex.quote(verify_code) + ' ' + shlex.quote(remote_name)], check=True)
subprocess.run(['ssh', 'ds1819-clawdbot', f"printf '%s  %s\\n' '{local_hash}' 'round3-frames-{stamp}.tar' > {remote_name}.sha256"], check=True)
removed = 0
for record in records:
    path = lab / record['path']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], path
    path.unlink()
    removed += record['bytes']
manifest.update(archive_sha256=local_hash, remote_contents='passed', removed_local_bytes=removed,
                free_gib_after=shutil.disk_usage(lab).free / 2**30)
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({k: v for k, v in manifest.items() if k != 'files'}, indent=2), flush=True)

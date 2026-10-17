# Build a separate round-two inventory. Keep the previous inventory and models intact.
import hashlib
import json
from pathlib import Path
import subprocess

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
source = pipeline / 'current-research-inventory-cape-floor.json'
output = pipeline / 'current-research-inventory-round2.json'
assert not output.exists()
rows = json.loads(source.read_text())
changes = {'leviathan': 'patch', 'ashwarden': 'trunk', 'obsidianGolem': 'patch',
           'gloomslime': 'patch', 'ashAcolyte': 'patch', 'abyssalKnight': 'patch', 'waylayer': 'small'}
summary = []
for row in rows:
    original = Path(row['glb'])
    assert hashlib.sha256(original.read_bytes()).hexdigest() == row['sha256']
    name = row['candidate'].split('/')[1]
    if name not in changes:
        continue
    folder = original.parent.parent / f'rig-round2-{changes[name]}'
    model = folder / f'{name}.glb'
    before = sum(item['max_stretched_edges'] for item in row['deformation'])
    deformation = json.loads((folder / 'reimport-deformation.json').read_text())
    after = sum(item['max_stretched_edges'] for item in deformation)
    assert after < before, name
    assert {item['clip'] for item in deformation} == {'idle', 'walk', 'attack', 'cast', 'hurt', 'death'}
    assert all(item['min_z'] >= -.005 and item['max_min_z'] <= .015 for item in deformation if item['clip'] in row['ground_clips'])
    structure = json.loads((folder / 'structure.json').read_text())
    assert structure['unweighted'] == 0 and structure['max_influences'] <= 4
    subprocess.run(['python3', str(pipeline / 'stretch_round2_compare.py'), str(original), str(model)], check=True)
    preview = pipeline / f'godot-preview-round2-{name}' / name
    frames = json.loads((preview / 'frames.json').read_text())
    assert len(frames) == 6 and sum(item['frames'] for item in frames) == 223
    assert len(list(preview.glob('frame-*.png'))) == 223
    assert (preview / 'temporal-sheet-exact.png').exists()
    evidence = {}
    for kind, marker in [('godot', 'GD RESULT 1/1 passed'), ('preview', 'PREVIEW RESULT failures 0')]:
        log = pipeline / f'round2-{name}-{kind}.log'
        text = log.read_text()
        assert marker in text and 'ERROR:' not in text and 'SCRIPT ERROR' not in text
        assert log.stat().st_mtime_ns >= model.stat().st_mtime_ns
        evidence[kind] = {'path': str(log), 'sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
    candidate = str(folder.relative_to(lane))
    notes = [note for note in row['known_limitations'] if not note.startswith('Severe stretch edges remain:')]
    if after:
        detail = ', '.join(f"{item['clip']} {item['max_stretched_edges']}" for item in deformation if item['max_stretched_edges'])
        notes.insert(0, f'Severe stretch edges remain: {detail}')
    row.update(candidate=candidate, glb=str(model), sha256=hashlib.sha256(model.read_bytes()).hexdigest(),
               bytes=model.stat().st_size, structure=structure, deformation=deformation,
               preview=str(preview), evidence=evidence, known_limitations=notes)
    if name == 'ashwarden':
        support_path = folder / 'support-contact.json'
        support = json.loads(support_path.read_text())
        assert support['candidate'] == candidate and support['world_translation_control'] == 'passed'
        samples = [item for item in support['samples'] if item['clip'] == 'death']
        assert len(samples) == 33 and all(-.005 <= item['minimum_z_m']['feet'] <= .015 for item in samples)
        row['support_contact_evidence'] = {'path': str(support_path), 'sha256': hashlib.sha256(support_path.read_bytes()).hexdigest()}
    summary.append({'name': name, 'before': before, 'after': after, 'sha256': row['sha256']})
assert len(rows) == 38 and len(summary) == 7
output.write_text(json.dumps(rows, indent=2) + '\n')
report = {'changes': summary, 'summed_severe_edges': sum(item['max_stretched_edges'] for row in rows for item in row['deformation']),
          'zero_severe_stretch': sum(all(item['max_stretched_edges'] == 0 for item in row['deformation']) for row in rows)}
(pipeline / 'stretch-round2-results.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))

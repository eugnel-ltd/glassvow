"""Round-four independent source generation; adapted from round three."""
import ast
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
PREVIOUS = ROOT.parent / 'mythic-art'
STYLE = next(ast.literal_eval(n.value) for n in ast.parse((PREVIOUS / 'generate.py').read_text()).body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'STYLE' for t in n.targets))


def guard():
    while True:
        free = shutil.disk_usage(ROOT).free / 1024**3
        if free < 50:
            raise RuntimeError(f'STOP: free disk {free:.2f} GiB is below 50 GiB')
        load = os.getloadavg()[0]
        if load <= 50:
            return load, free
        print(f'WAIT: load {load:.2f} exceeds 50; free {free:.2f} GiB', flush=True)
        time.sleep(30)


def generate(spec):
    output = ROOT / 'sources' / spec['name'] / 'generated.png'
    if output.exists():
        print(f'EXISTS in this round: {spec["name"]}', flush=True)
        return
    ledger = ROOT / 'generation-count.jsonl'
    records = [json.loads(s) for s in ledger.read_text().splitlines()] if ledger.exists() else []
    stage_calls = sum(r.get('stage') == '4b' for r in records)
    if stage_calls >= 40:
        raise RuntimeError('STOP: stage 4b 40-call budget reached')
    load, free = guard()
    name = spec['name']
    directory = ROOT / 'sources' / name
    directory.mkdir(parents=True, exist_ok=False)
    prompt = f'''{STYLE}
Use case: stylized-concept
Asset type: Glassvow independent layered mythic card artwork, round four
Primary request: {spec['request']}
Gameplay read: {spec['cue']}. Strong silhouette at 148x91 cover crop and 64 px wide.
Story moment: serious, restrained, iconic and strange, never a stock fantasy cathedral.
Style/medium: {spec['material']}. Heavy outer lead lines, 3-5 large masses, matte painterly stained glass. All surfaces are glass, including landscape and clothes.
Composition/framing: {spec['composition']}. Landscape 1536x1024, near 3:2. Never ultrawide.
LAYER OVERRIDE, takes precedence over generic scene text: {spec['surface']}
Lighting/mood: {spec['light']}. This palette and lighting override the generic amber rim: {spec['palette']}.
Constraints: NO text, letters, numerals, glyphs, runes, writing, labels, signatures or watermarks. No faces or eyes. Exactly two arms and two legs on any figure. No card chrome, cost, title, ornamental border or decorative badge. No motion blur. No extra objects beyond the requested layer.
Load and visually use these three images as STYLE references only, never composition or palette references: {PREVIOUS}/style-master.png ; /Users/jamesto/Coding/glassvow/assets/art/cards/eclipseSlash.jpg ; /Users/jamesto/Coding/glassvow/assets/art/cards/lunge.jpg .
{spec.get('reference', '')}
Generate exactly ONE image with the built-in image generation tool. Save the real generated image at this absolute path: {output}. Do not draw a substitute with Python/SVG. Do not change repository files. Only write inside {ROOT}. Return output path and source size.'''
    (ROOT / f'{name}-prompt.txt').write_text(prompt)
    record = {'call': len(records)+1, 'stage': '4b', 'stage_call': stage_calls+1, 'name': name, 'started': time.strftime('%Y-%m-%dT%H:%M:%S%z'), 'load': round(load, 2), 'free_gib': round(free, 2), 'status': 'running'}
    records.append(record)
    ledger.write_text(''.join(json.dumps(r)+'\n' for r in records))
    print(f'START {record["call"]}: {name}', flush=True)
    started = time.monotonic()
    with (ROOT / f'{name}-generation.log').open('w') as log:
        result = subprocess.run(['bash', os.path.expanduser('~/.claude/scripts/subagents/run-imagegen.sh'), prompt], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=900)
    record.update(seconds=round(time.monotonic()-started), exit=result.returncode, exists=output.exists(), status='complete' if result.returncode == 0 and output.exists() else 'failed')
    ledger.write_text(''.join(json.dumps(r)+'\n' for r in records))
    print(f'END {name}: {record["status"]}; {record["seconds"]} s', flush=True)
    if record['status'] != 'complete':
        raise RuntimeError('STOP: generation failed; inspect the named log')


if __name__ == '__main__':
    batch = Path(sys.argv[1]).stem
    try:
        for spec in json.loads((ROOT / sys.argv[1]).read_text()):
            generate(spec)
    except Exception as error:
        (ROOT / f'{batch}-status.txt').write_text(str(error))
        raise
    (ROOT / f'{batch}-status.txt').write_text('complete\n')

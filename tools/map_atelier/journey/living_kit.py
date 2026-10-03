"""Act I journey kit, R2 additions (the living land, 3 Oct 2026).

Run with Blender background Python from the repository root:

    blender -b -P tools/map_atelier/journey/living_kit.py

Reuses build_kit.py's materials, helpers and save(), so the new pieces share
the R1 kit's palette, stone finish and export settings. Writes only its own
GLBs (and their .blend masters) and merges their rows into manifest.json; the
R1 kit's files are left untouched.
"""
from pathlib import Path
import json
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_kit as kit

# The lantern's glass centre, which the flame card and the light pool use
# (Blender Z; Godot Y). Keep in step with Kit.LAMP_ANCHORS["lantern-post"].
LANTERN_GLASS_Z = 1.38


def lantern_post():
    kit.reset()
    kit.block('Post plinth', (0, 0, .07), (.40, .40, .14), kit.STONE[0], .03)
    kit.block('Post shaft', (0, 0, .55), (.26, .26, .84), kit.STONE[1], .03)
    kit.block('Post cap', (0, 0, .99), (.40, .40, .08), kit.EDGE, .02)
    kit.lantern(0, 0, LANTERN_GLASS_Z - .31, chain=False)
    kit.save('lantern-post', 'Roadside stone post carrying an amber lantern; R2 light, lane pick', 1200)


def merge_manifest():
    path = kit.OUT / 'manifest.json'
    manifest = json.loads(path.read_text())
    built = {row['id']: row for row in kit.MANIFEST}
    rows = [built.pop(row['id'], row) for row in manifest['assets']]
    rows.extend(built.values())
    manifest['assets'] = rows
    path.write_text(json.dumps(manifest, indent=2) + '\n')


lantern_post()
merge_manifest()
print('JOURNEY_LIVING_KIT_OK', len(kit.MANIFEST), flush=True)

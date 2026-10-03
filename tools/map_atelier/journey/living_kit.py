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


CLOTH = kit.material('Banner cloth', (.42, .045, .055), .9)
TRIM = kit.material('Banner trim', (.62, .43, .13), .6)


def cloth_panel(name, x0, x1, top, bottom, mat, columns, rows, notch=0.0, y=0.0):
    """A hanging panel in Blender's XZ plane (Godot's XY), subdivided so the
    banner shader's wave has rows to move; `notch` lifts the hem's middle into
    a swallowtail."""
    verts = []
    for r in range(rows + 1):
        t = r / rows
        for c in range(columns + 1):
            u = c / columns
            x = x0 + (x1 - x0) * u
            z = top + (bottom - top) * t
            if r == rows and notch:
                z += notch * (1 - abs(u * 2 - 1))
            verts.append((x, y, z))
    faces = []
    for r in range(rows):
        for c in range(columns):
            a = r * (columns + 1) + c
            faces.append((a, a + 1, a + columns + 2, a + columns + 1))
    return kit.mesh(name, verts, faces, [mat])


def bridge_banner():
    kit.reset()
    kit.rod('Banner bar', (-.42, 0, 0), (.42, 0, 0), .022, kit.METAL, 6)
    for x in (-.42, .42):
        kit.block('Banner finial', (x, 0, 0), (.06, .06, .06), kit.METAL, .01)
    cloth_panel('Banner cloth', -.34, .34, -.05, -1.55, CLOTH, 4, 12, notch=.24)
    cloth_panel('Banner band', -.34, .34, -.07, -.19, TRIM, 4, 1, y=-.004)
    cloth_panel('Banner stripe', -.045, .045, -.19, -1.28, TRIM, 1, 10, y=-.004)
    kit.save('bridge-banner', 'Red cloth banner with a gold band, hung from a bridge parapet; R2 motion, lane pick', 600, grounded=False)


def merge_manifest():
    path = kit.OUT / 'manifest.json'
    manifest = json.loads(path.read_text())
    built = {row['id']: row for row in kit.MANIFEST}
    rows = [built.pop(row['id'], row) for row in manifest['assets']]
    rows.extend(built.values())
    manifest['assets'] = rows
    path.write_text(json.dumps(manifest, indent=2) + '\n')


lantern_post()
bridge_banner()
merge_manifest()
print('JOURNEY_LIVING_KIT_OK', len(kit.MANIFEST), flush=True)

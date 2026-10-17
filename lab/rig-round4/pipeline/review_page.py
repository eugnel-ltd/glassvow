# Build review.html in the lane folder: one card per character (2D source, Codex ref, Tripo views, clip montage).
#   python3 -I review_page.py
import html, json, os

LANE = "/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab"
ENEMIES = "/Users/jamesto/Coding/glassvow/assets/art/enemies"
NOTES = {
    "duskblade": "Hood holds a gold crystal (it came from the Codex ref): canon says a faceless void. Keep or remove?",
    "ashwarden": "The lantern hangs low, near the knee.",
    "gravewarden": "Stone pieces are cut apart and move rigidly; a hole shows at the shoulder when an arm lifts (the mesh is a hollow shell).",
    "gloomslime": "Heat weighting fails on this mesh, so its arm moves are kept small; the attack wind-up still pulls the front a little. Candidate for a re-generate.",
    "waylayer": "The axe can leave the frame in these renders (camera framing only).",
    "ashAcolyte": "The ember bowl reads dark in some angles.",
}
CHARS = [("chars", "duskblade", "Hero"), ("chars", "ashwarden", "Hero")] + [
    ("mobs", m, "Act I") for m in ("sporeling", "duskfang", "gloomslime", "waylayer", "thornling",
                                    "ashAcolyte", "gravewarden", "alphaFang", "rootheart")]


def img(path, label):
    if not os.path.exists(path):
        return f'<figure class="miss"><figcaption>{label}: missing</figcaption></figure>'
    rel = os.path.relpath(path, LANE)
    return f'<figure><a href="{html.escape(rel)}"><img src="{html.escape(rel)}" loading="lazy"></a><figcaption>{label}</figcaption></figure>'


cards = []
for root, name, group in CHARS:
    d = f"{LANE}/{root}/{name}"
    spec = json.load(open(f"{d}/rig.json")) if os.path.exists(f"{d}/rig.json") else {}
    glb = f"{d}/rig/{name}.glb"
    size = f"{os.path.getsize(glb) / 1e6:.1f} MB GLB" if os.path.exists(glb) else "no GLB"
    plan = spec.get("plan", "humanoid") + (", rigid stone" if spec.get("weights") == "rigid" else "")
    figs = []
    if root == "mobs":
        figs.append(img(f"{ENEMIES}/{name}.png", "game art today (2D)"))
    figs += [img(f"{d}/ref/body-a.png", "Codex modelling ref"), img(f"{d}/rig/views.png", "Tripo mesh, 4 views"),
             img(f"{d}/rig/montage.png", "clips: idle, walk, attack, cast, hurt, death")]
    note = NOTES.get(name, "")
    cards.append(f'''<section><h2>{html.escape(name)} <small>{group} · {plan} · {size}</small></h2>
<div class="row">{"".join(figs)}</div>{f'<p class="note">{html.escape(note)}</p>' if note else ""}
<p class="pick">Pick: <label><input type="radio" name="{name}"> keep</label> <label><input type="radio" name="{name}"> redo</label> <label><input type="radio" name="{name}"> drop</label></p></section>''')

page = f'''<!doctype html><html lang="en"><meta charset="utf-8"><title>Glassvow 3D characters: review</title>
<style>body{{font:15px system-ui;margin:24px;background:#1b1b1f;color:#e8e6e3}}h1{{font-weight:600}}
section{{border-top:1px solid #444;padding:12px 0}}h2 small{{color:#9a9a9a;font-weight:400;font-size:13px}}
.row{{display:flex;gap:10px;overflow-x:auto}}figure{{margin:0;flex:0 0 auto}}figure img{{height:260px;background:#777;border-radius:4px}}
figcaption{{font-size:12px;color:#aaa}}.note{{color:#f0c674}}.miss{{color:#c66}}.pick{{color:#ccc}}</style>
<h1>Glassvow 3D characters: candidates (lane folder only, nothing in assets/)</h1>
<p>Tripo Studio meshes from Codex references; rigged and animated in Blender; every GLB loads in Godot 4.7.2 with 6 clips.
Click a picture for full size. The radio buttons are for your notes only; they are not saved.</p>
{"".join(cards)}</html>'''
open(f"{LANE}/review.html", "w").write(page)
print("review.html", len(cards), "cards")

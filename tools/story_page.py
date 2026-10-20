"""The storytelling home page: tools/story_page.html filled from tools/story_copy.json.

tools/teaser_page.py owns the media pipeline and the rules; this module owns
what the page shows. The template is the published design (the website story
canvas of 20 October 2026) with its styles moved into site/assets/story*.css,
because the site's Content-Security-Policy allows no inline style or script.

Template language, deliberately tiny:
  {{a.b}}                   an escaped value from the context
  {{html.x}}                a context value inserted as markup (built here)
  {{pic.name}}              the URL of a picture's smallest WebP
  {{media.file_ext}}        the URL of a copied file (file.ext)
  <sc-for list="{{x}}" as="y">…</sc-for>   repeat for each item (not nested)
  <img data-pic="name" [data-sizes="…"]>   becomes <picture> with AVIF and WebP
  data-poster="name"        becomes poster="…" on a <video>
"""

from __future__ import annotations

import html
import json
import re
from functools import cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "tools/story_page.html"
COPY_FILE = ROOT / "tools/story_copy.json"
WEB = "docs/design/2026-10-20-website-story/"
ART = "assets/art/"

# Picture specs: (name, source, widths, options). Options: trim, box (crop
# before trimming), aspect. Every source is a file in this repository.
SHARD_BOXES = ((40, 360, 320, 888), (284, 12, 580, 528), (728, 44, 1044, 512),
               (968, 428, 1216, 960), (692, 784, 968, 1236), (296, 780, 600, 1236))
WAY_BOXES = {"frost": (60, 24, 404, 760), "hearth": (768, 24, 1132, 720), "eclipse": (1332, 72, 1940, 696)}
PLATES = ("prologue-bg", "duskblade-scene", "act1", "act2", "act3", "act1-fg", "act2-fg", "act3-fg",
          "hero-fg", "sovereign-scene", "door", "merchant", "vigil-bg", "vigil-hall", "vigil-fg",
          "lantern-bg", "lantern-fg", "lamp-bg", "lamp-fg")
NODES = ("monster", "event", "elite", "rest", "shop", "treasure", "unlit", "boss")
CARD_ART = ("cleave", "emberdance", "totality", "hex")
PICTURE_SPECS = (
    ("hearth", ART + "scenes/opening-hearth.png", (960, 1536), {}),
    ("lantern", WEB + "art/lantern.webp", (240, 480), {"trim": True}),
    *((name, f"{WEB}art/{name}.webp", (960, 1536), {}) for name in PLATES),
    ("vigil-walker", WEB + "art/vigil-walker.webp", (220, 440), {}),
    ("lantern-keeper", WEB + "art/lantern-keeper.webp", (480, 960), {}),
    ("lamp-figure", WEB + "art/lamp-figure.webp", (460, 920), {}),
    ("gambler", WEB + "art/gambler.webp", (640, 1280), {}),
    ("wounded-knight", WEB + "art/wounded-knight.webp", (640, 1280), {}),
    ("flesh-trader", WEB + "art/flesh-trader.webp", (640, 1016), {}),
    ("kindle", WEB + "art/kindle.webp", (960,), {}),
    ("shatter", WEB + "art/shatter.webp", (960,), {}),
    *((f"shard-{i}", WEB + "art/prologue-shards.webp", (240,), {"box": box, "trim": True})
      for i, box in enumerate(SHARD_BOXES)),
    *((f"way-{key}", WEB + "art/way-emblems.webp", (160,), {"box": box, "trim": True})
      for key, box in WAY_BOXES.items()),
    ("map-act1", "docs/design/2026-10-02-map-living-land/r3/r3-6-light/frames/act1-desktop-full.jpg",
     (720, 1440), {"box": (1462, 0, 2924, 844)}),
    ("turn-poster", WEB + "footage/turn-poster.jpg", (944,), {}),
    ("shatter-poster", WEB + "footage/shatter-poster.jpg", (600,), {}),
    *((f"node-{name}", f"{ART}ui/node-{name}.png", (96,), {}) for name in NODES),
    ("ui-lantern", ART + "ui/lantern.png", (200,), {}),
    *((f"art-{name}", f"{ART}cards/{name}.jpg", (640,), {}) for name in CARD_ART),
    ("back-vault", ART + "backs/vault.png", (304,), {}),
    *((f"myth-{i}", f"{WEB}mythic/bankedFire-B-L{i}.{'jpg' if i == 0 else 'png'}", (1152,), {})
      for i in range(6)),
)
# Copied byte for byte: the in-game clips.
FILE_SPECS = (
    ("turn.mp4", WEB + "footage/turn.mp4"),
    ("shatter.mp4", WEB + "footage/shatter.mp4"),
)
# The three rigged foes (lab rig round 4), each with its skin moved beside it.
MODEL_SPECS = tuple((name, f"{WEB}models/{name}.glb") for name in ("gravewarden", "siren", "watcherEye"))
STRANGERS = ("gambler", "wounded-knight", "flesh-trader")
STRANGER_PAR = ("par-a", "par-b", "par-a")
WAY_KEYS = ("frost", "hearth", "eclipse")
MARKS = ("45", "60", "75")


@cache
def copy() -> dict:
    return json.loads(COPY_FILE.read_text(encoding="utf-8"))


def esc(text: str) -> str:
    return html.escape(str(text), quote=True)


def lookup(ctx: dict, path: str):
    node = ctx
    for key in path.split("."):
        if isinstance(node, dict) and key in node:
            node = node[key]
        elif isinstance(node, list) and key.isdigit():
            node = node[int(key)]
        else:
            raise KeyError(f"story template: no value for {{{{{path}}}}}")
    return node


def fill(text: str, ctx: dict) -> str:
    def hole(match: re.Match) -> str:
        path = match.group(1).strip()
        if path.startswith("html."):
            return str(lookup(ctx, path))
        return esc(lookup(ctx, path))
    return re.sub(r"\{\{([^}]+)\}\}", hole, text)


def expand(template: str, ctx: dict) -> str:
    def loop(match: re.Match) -> str:
        items, name = lookup(ctx, match.group(1)), match.group(2)
        return "".join(fill(match.group(3), {**ctx, name: item}) for item in items)
    looped = re.sub(r'<sc-for list="\{\{([^}]+)\}\}" as="(\w+)">(.*?)</sc-for>', loop, template, flags=re.S)
    return fill(looped, ctx)


def picture_tag(tag: str, sources: dict) -> str:
    """One <img data-pic> as <picture>: AVIF then WebP, sized from the manifest."""
    name = re.search(r' data-pic="([^"]+)"', tag).group(1)
    sizes_m = re.search(r' data-sizes="([^"]+)"', tag)
    sizes = sizes_m.group(1) if sizes_m else "100vw"
    pic = sources[name]
    attrs = re.sub(r' (data-pic|data-sizes|loading|decoding|src)="[^"]*"', "", tag[4:-1])
    if ' alt=""' in attrs and "aria-hidden=" not in attrs:
        attrs += ' aria-hidden="true"'  # an empty alt marks the picture as decorative
    eager = "fetchpriority=" in attrs
    load = "" if eager else ' loading="lazy"'
    widths = pic["widths"]
    def srcset(ext: str) -> str:
        return ", ".join(f'{pic["url"]}-{w}.{ext} {w}w' for w in widths)
    return (f'<picture><source type="image/avif" srcset="{srcset("avif")}" sizes="{esc(sizes)}">'
            f'<img{attrs} src="{pic["url"]}-{widths[0]}.webp" srcset="{srcset("webp")}" '
            f'sizes="{esc(sizes)}" width="{pic["width"]}" height="{pic["height"]}"{load} decoding="async"></picture>')


def context(lang: str, *, pictures: dict, media_url: str, twin: str, twin_name: str, home: str,
            twin_home: str, name: str, guides: list[tuple[str, str]], contact: str, sound: str,
            platforms: tuple[str, ...]) -> dict:
    data = copy()
    t = data[lang]
    li = 0 if lang == "en" else 1
    pic = {key: f'{value["url"]}-{value["widths"][0]}.webp' for key, value in pictures.items()}
    media = {spec[0].replace(".", "_"): f"/{media_url}/{spec[0]}" for spec in FILE_SPECS}
    media.update({f"{name}_glb": f"/{media_url}/{name}.glb" for name, _ in MODEL_SPECS})
    shards = [{"pic": f"shard-{i}", "c": s[1], "a": s[2], "r": s[3], "t": s[4]} for i, s in enumerate(data["shards"])]
    tiers = [{"n": r[0], "p": r[1], "read": r[2], "cost": r[3], "i": i} for i, r in enumerate(t["s"]["flame"]["tiers"])]

    def card(c: dict) -> dict:
        face = {"name": c["name"][li], "text": c.get("text", ["", ""])[li], "type": c.get("type", ""),
                "cost": c.get("cost"), "tier": c["tier"], "warm": c.get("warm", 0),
                "typeLabel": t["cards"]["types"].get(c.get("type", ""), ""), "lang": lang,
                "knobs": c.get("knobs")}
        if c.get("layers"):
            face["layers"] = [[layer[1], layer[2]] for layer in c["layers"]]
            src = " ".join(f'{pictures[f"myth-{i}"]["url"]}-1152.webp' for i in range(len(c["layers"])))
        elif c.get("back"):
            src = pic["back-vault"]
        else:
            src = pictures[f'art-{c["id"]}']["url"] + "-640.webp"
        label = c["name"][li] + (" — " + re.sub(r"[@#]", "", c["text"][li]) if c.get("text") else "")
        return {"id": c["id"], "label": label, "face": json.dumps(face, ensure_ascii=False), "src": src,
                "rarity": t["cards"].get(c["r"], ""), "finish": t["cards"].get(c.get("fk", ""), "")}

    return {
        "t": t, "lang": lang, "name": name, "home": home, "twin": twin, "twinName": twin_name,
        "twinHref": twin_home, "pic": pic, "media": media,
        "html": {"sound": sound, "contact": contact},
        "guides": [{"path": path, "name": label} for path, label in guides],
        "platforms": [{"n": n, "s": t["v"]["platforms"][i]["s"], "d": data["platformD"][i]}
                      for i, n in enumerate(platforms)],
        "shards": shards,
        "strangers": [{"i": i + 1, "n": s[0], "q": s[1], "alt": s[2], "pic": STRANGERS[i], "par": STRANGER_PAR[i]}
                      for i, s in enumerate(t["strangers"])],
        "nodes": [{"name": label, "pic": f"node-{NODES[i]}"} for i, label in enumerate(t["nodes"])],
        "turnSteps": [{"n": s[0], "p": s[1]} for s in t["s"]["turn"]["steps"]],
        "tiers": tiers,
        "deckChips": [{"k": "dk_" + k} for k in data["deck"]],
        "marks": [{"l": label, "at": MARKS[i]} for i, label in enumerate(t["s"]["flame"]["marks"])],
        "rack": [{"c": "b" if i < 9 else "x"} for i in range(13)],
        "ways": [{"key": WAY_KEYS[i], "name": w[0], "flame": w[1], "pic": f"way-{WAY_KEYS[i]}"}
                 for i, w in enumerate(t["ways"])],
        "glassCards": [card(c) for c in data["glass"]],
        "mythCards": [card(c) for c in data["myth"]],
    }


def render(ctx: dict, pictures: dict) -> list[str]:
    page = expand(TEMPLATE.read_text(encoding="utf-8"), ctx)
    page = re.sub(r"<img\b[^>]*\bdata-pic=\"[^\"]+\"[^>]*>", lambda m: picture_tag(m.group(0), pictures), page)
    page = re.sub(r' data-poster="([^"]+)"',
                  lambda m: f' poster="{pictures[m.group(1)]["url"]}-{pictures[m.group(1)]["widths"][-1]}.webp"', page)
    page = re.sub(r"<!--.*?-->\n?", "", page, flags=re.S)
    return page.rstrip("\n").split("\n")

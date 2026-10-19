"""Glassvow's teaser home page in English and 繁體中文: / and /zh-hant/.

tools/build_site.py renders and audits these pages. Game names and lines come
from locale/*.json; the site's own lines sit in COPY. The art and sound the
pages show are web copies of the game's files: `build_site.py --media` encodes
them into site/assets/teaser/ (needs Pillow with AVIF and ffmpeg) and writes
media.json, which pins each output to its source digest and recipe, so
`--check` fails when a source, a recipe or an output drifts.
"""

from __future__ import annotations

import hashlib
import html
import json
import math
import re
import shutil
import subprocess
from dataclasses import dataclass
from functools import cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MEDIA_DIR = "assets/teaser"
MANIFEST = f"{MEDIA_DIR}/media.json"
SCRIPT = "/assets/teaser.js"
STYLESHEET = "/assets/teaser.css"
HOME = {"en": "/", "zh-Hant": "/zh-hant/"}
NAME = {"en": "Glassvow", "zh-Hant": "琉璃誓言"}
PRIVACY = {"en": "/privacy/", "zh-Hant": "/privacy/zh-hant/"}
# Owner decision, 19 October 2026: all four are coming soon. Unreleased, so plain
# names only, never store badges, links, dates or prices. One store per platform.
PLATFORMS = ("App Store", "Google Play", "Amazon Appstore", "Steam")
GAME_PLATFORMS = ("iOS (App Store)", "Android (Google Play)", "Amazon Appstore", "Steam (PC)")
OPERATING_SYSTEMS = "iOS, Android"


def platform_list(lang: str) -> str:
    """The four platforms as one phrase, worded the same on every page and in the entity."""
    if lang == "en":
        return f"{', '.join(GAME_PLATFORMS[:-1])} and {GAME_PLATFORMS[-1]}"
    wide = [name.replace(" (", "（").replace(")", "）") for name in GAME_PLATFORMS]
    return f"{'、'.join(wide[:-1])} 及 {wide[-1]}"


ART = "assets/art/"
SCENES = ("opening-hearth", "night-stall")
CARDS = ("cleave", "eclipseSlash", "aegis", "emberdance", "totality", "dimTheGlass", "annihilate")
BACKS = ("vault", "rose", "eclipse")
ASPECTS = ("ashwarden", "duskblade")
FOES = ("duskfang", "chaosHound", "deepmaw", "shade", "gravewarden", "starCultist")
# Rose-window panes: (light, deep) glass colours of the game's card backs.
ROSE_GLASS = (("#ff8a8a", "#7a1530"), ("#ffe08a", "#b8641a"), ("#8fc1ff", "#1d3a8f"),
              ("#c9a6ff", "#4b2a8a"), ("#ffb36b", "#9a3412"), ("#8ff0e2", "#0f5f66"))


class MediaError(ValueError):
    """Teaser media that is missing, stale or cannot be encoded."""


@dataclass(frozen=True)
class Picture:
    name: str
    source: str
    widths: tuple[int, ...]
    aspect: float | None = None  # centre crop to width / height
    trim: bool = False  # crop to the alpha bounding box first

    def outputs(self) -> dict[str, str]:
        return {f"{self.name}-{width}.{ext}": f"{ext} w={width} aspect={self.aspect} trim={self.trim}"
                for width in self.widths for ext in ("avif", "webp")}


@dataclass(frozen=True)
class Sound:
    name: str
    source: str
    seconds: float | None = None  # cut here, after a six-second fade
    rates: tuple[str, str] = ("48k", "64k")  # Opus, MP3

    def outputs(self) -> dict[str, str]:
        return {f"{self.name}.{ext}": f"{ext} {rate} seconds={self.seconds}"
                for ext, rate in zip(("ogg", "mp3"), self.rates)}


PICTURES = (
    Picture("vigil-road", ART + "title-background/background.png", (960, 1536)),
    Picture("vigil-road-tall", ART + "title-background/background.png", (432, 576), aspect=9 / 16),
    Picture("wordmark-en", ART + "title/title.png", (640, 1280), trim=True),
    Picture("wordmark-zh-Hant", ART + "title/title-zh.png", (640, 1280), trim=True),
    Picture("lantern", ART + "title/lantern-hero.png", (240, 480), trim=True),
    *(Picture(f"scene-{name}", f"{ART}scenes/{name}.png", (640, 1280)) for name in SCENES),
    *(Picture(f"card-{name}", f"{ART}cards/{name}.jpg", (480,), aspect=1.2) for name in CARDS),
    *(Picture(f"back-{name}", f"{ART}backs/{name}.png", (304,)) for name in BACKS),
    *(Picture(f"aspect-{name}", f"{ART}heroes/{name}.png", (300, 600), trim=True) for name in ASPECTS),
    *(Picture(f"foe-{name}", f"{ART}enemies/{name}.png", (200, 400), trim=True) for name in FOES),
)
SOUNDS = (
    # The title theme falls quiet near 2:05; the cut and fade land there.
    Sound("theme", "assets/audio/music/title.mp3", 126.0, ("64k", "96k")),
    Sound("flip", "assets/audio/sfx/card.mp3"),
    Sound("rise", "assets/audio/sfx/paneRise.mp3"),
    Sound("crack", "assets/audio/sfx/glassCrack.mp3"),
    Sound("shatter", "assets/audio/sfx/shatter.mp3"),
)

COPY = {
    "en": {
        "title": "Glassvow · 琉璃誓言 — a stained-glass roguelite deckbuilder",
        "description": "Glassvow (琉璃誓言): a stained-glass roguelite deckbuilder, coming soon to "
                       f"{platform_list('en')}.",
        "kicker": "A pilgrimage in stained glass",
        "lede": "A single-player roguelite deckbuilder. Build a deck of glass, kindle the lantern, "
                "and shatter what blocks the way.",
        "soon_on": "Available soon on",
        "coming": "Coming soon",
        "sound": ("Sound off", "Sound on"),
        "fire": "A fire was cut into six pieces and scattered along the road.",
        "fire_after": "Gather what was broken. Light the rose.",
        "road": "The road",
        "road_lines": ("Walk east from the Vigil with a lantern.", None),
        "deck_kicker": "A roguelite deckbuilder",
        "deck": "Build a deck of glass. Kindle the lantern.",
        "foes": "Shatter what blocks the way.",
        "soon": "Available soon",
        "facts": "Single-player · No accounts · No ads",
        "more": "About Glassvow",
        "support": "Support",
        "privacy": "Privacy",
    },
    "zh-Hant": {
        "title": "琉璃誓言 Glassvow — 彩窗上的朝聖之路",
        "description": "《琉璃誓言》（Glassvow）是一款單人 Roguelike 牌組構築遊戲，亦是一場彩窗上的朝聖。"
                       f"即將登陸 {platform_list('zh-Hant')}。",
        "kicker": "彩窗上的朝聖之路",
        "lede": "單人 Roguelike 牌組構築遊戲。組一副琉璃牌，點燃提燈，打碎擋路之物。",
        "soon_on": "即將登陸",
        "coming": "即將推出",
        "sound": ("聲音：關", "聲音：開"),
        "fire": "一團火被裁成六片，散落於路。",
        "fire_after": "尋回碎去的東西。點亮彩窗。",
        "road": "長路",
        "road_lines": ("提燈離開守夜之爐向東走。", None),
        "deck_kicker": "Roguelike 牌組構築",
        "deck": "組一副琉璃牌，點燃提燈。",
        "foes": "打碎擋路之物。",
        "soon": "即將推出",
        "facts": "單人遊戲 · 沒有帳戶 · 沒有廣告",
        "more": "關於琉璃誓言",
        "support": "支援",
        "privacy": "私隱政策",
    },
}
# Road kickers, and the lines COPY leaves as None, come from the game's own strings.
ROAD_KEYS = ("ui.vigil.title", "ui.shop.title")
ROAD_LINE_KEYS = (None, "ui.shop.cardRemoval.confirmBody")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_outputs() -> dict[str, tuple[str, str]]:
    return {name: (item.source, recipe) for item in (*PICTURES, *SOUNDS)
            for name, recipe in item.outputs().items()}


# --- Locale and manifest ---------------------------------------------------

@cache
def locale(lang: str) -> dict[str, str]:
    def flat(node: object, prefix: str = ""):
        if isinstance(node, dict):
            for key, value in node.items():
                yield from flat(value, f"{prefix}.{key}" if prefix else key)
        else:
            yield prefix, str(node)
    return dict(flat(json.loads((ROOT / f"locale/{lang}.json").read_text(encoding="utf-8"))))


def say(lang: str, key: str) -> str:
    try:
        return locale(lang)[key]
    except KeyError:
        raise MediaError(f"locale/{lang}.json has no {key}") from None


def load_manifest(site: Path) -> dict[str, dict]:
    try:
        return json.loads((site / MANIFEST).read_text(encoding="utf-8"))["outputs"]
    except (OSError, ValueError, KeyError) as error:
        raise MediaError(f"{MANIFEST} unreadable ({error}); run tools/build_site.py --media") from None


def media_problems(site: Path) -> list[str]:
    try:
        outputs = load_manifest(site)
    except MediaError as error:
        return [f"MEDIA {error}"]
    expected, problems = expected_outputs(), []
    for name in sorted(expected.keys() | outputs.keys()):
        entry, path = outputs.get(name, {}), site / MEDIA_DIR / name
        if name not in expected:
            problems.append(f"MEDIA_UNUSED {name} is in {MANIFEST} but no longer specified")
        elif not entry:
            problems.append(f"MEDIA_MISSING {name} is specified but not encoded")
        elif (entry.get("source"), entry.get("recipe")) != expected[name]:
            problems.append(f"MEDIA_RECIPE {name} was encoded from another source or recipe")
        elif entry.get("source_sha256") != digest(ROOT / expected[name][0]):
            problems.append(f"MEDIA_SOURCE {expected[name][0]} changed since {name} was encoded")
        elif not path.is_file() or digest(path) != entry.get("sha256"):
            problems.append(f"MEDIA_OUTPUT site/{MEDIA_DIR}/{name} does not match {MANIFEST}")
    listed = set(outputs) | {Path(MANIFEST).name}
    problems += [f"MEDIA_UNLISTED site/{MEDIA_DIR}/{path.name} is not in {MANIFEST}"
                 for path in sorted((site / MEDIA_DIR).glob("*")) if path.name not in listed]
    return problems


def encode_media(site: Path) -> None:
    """Re-encode every web copy and rewrite media.json (Pillow + ffmpeg)."""
    from PIL import Image, features
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None or not features.check("avif"):
        raise MediaError("--media needs ffmpeg on PATH and Pillow built with AVIF")
    folder = site / MEDIA_DIR
    shutil.rmtree(folder, ignore_errors=True)
    folder.mkdir(parents=True)
    outputs: dict[str, dict] = {}
    for picture in PICTURES:
        image = Image.open(ROOT / picture.source)
        image = image.convert("RGBA" if image.has_transparency_data else "RGB")
        if picture.trim:
            image = image.crop(image.getchannel("A").getbbox())
        if picture.aspect:
            width = min(image.width, round(image.height * picture.aspect))
            height = round(width / picture.aspect)
            left, top = (image.width - width) // 2, (image.height - height) // 2
            image = image.crop((left, top, left + width, top + height))
        for name in picture.outputs():
            width = int(name.rsplit("-", 1)[1].split(".")[0])
            if width > image.width:
                raise MediaError(f"{name} would enlarge {picture.source}")
            sized = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
            if name.endswith(".avif"):
                sized.save(folder / name, "AVIF", quality=56, speed=4)
            else:
                sized.save(folder / name, "WEBP", quality=78, method=6)
            outputs[name] = {"width": sized.width, "height": sized.height}
    for sound in SOUNDS:
        cut = []
        if sound.seconds:
            fade = f"afade=t=in:d=0.4,afade=t=out:st={sound.seconds - 6}:d=6"
            cut = ["-t", str(sound.seconds), "-af", fade]
        for name, rate in zip(sound.outputs(), sound.rates):
            codec = ["-c:a", "libopus", "-vbr", "on"] if name.endswith(".ogg") else ["-c:a", "libmp3lame"]
            subprocess.run([ffmpeg, "-v", "error", "-y", "-i", str(ROOT / sound.source), *cut, *codec,
                            "-b:a", rate, "-map_metadata", "-1", str(folder / name)], check=True)
            outputs[name] = {}
    for name, (source, recipe) in expected_outputs().items():
        outputs[name].update(source=source, recipe=recipe, source_sha256=digest(ROOT / source),
                             sha256=digest(folder / name), bytes=(folder / name).stat().st_size)
    (site / MANIFEST).write_text(json.dumps({"outputs": outputs}, indent=1, sort_keys=True) + "\n",
                                 encoding="utf-8")


# --- Markup ----------------------------------------------------------------

def esc(text: str) -> str:
    return html.escape(text, quote=True)


def picture(site: Path, name: str, alt: str, sizes: str, cls: str, *, eager: bool = False,
            tall: str | None = None) -> str:
    """<picture> with AVIF then WebP; `tall` art-directs portrait screens."""
    outputs = load_manifest(site)
    item = next(p for p in PICTURES if p.name == name)

    def srcset(pic: Picture, ext: str) -> str:
        return ", ".join(f"/{MEDIA_DIR}/{pic.name}-{w}.{ext} {w}w" for w in pic.widths)

    sources = []
    if tall:
        portrait = next(p for p in PICTURES if p.name == tall)
        sources += [f'<source media="(max-aspect-ratio: 4/5)" type="image/{ext}" '
                    f'srcset="{srcset(portrait, ext)}" sizes="100vw">' for ext in ("avif", "webp")]
    sources += [f'<source type="image/avif" srcset="{srcset(item, "avif")}" sizes="{sizes}">']
    largest = outputs[f"{name}-{item.widths[-1]}.webp"]
    loading = 'fetchpriority="high"' if eager else 'loading="lazy"'
    hidden = ' aria-hidden="true"' if not alt else ""
    return (f'<picture class="{cls}">{"".join(sources)}<img src="/{MEDIA_DIR}/{name}-{item.widths[0]}.webp" '
            f'srcset="{srcset(item, "webp")}" sizes="{sizes}" alt="{esc(alt)}"{hidden} '
            f'width="{largest["width"]}" height="{largest["height"]}" {loading} decoding="async"></picture>')


def platforms(lang: str, cls: str) -> list[str]:
    coming = esc(COPY[lang]["coming"])
    return [f'<ul class="{cls}">',
            *(f'  <li class="platform"><span class="platform-name display">{esc(name)}</span>'
              f'<span class="platform-soon">{coming}</span></li>' for name in PLATFORMS),
            "</ul>"]


def rose_window() -> list[str]:
    petal = "M0-20C24-30 34-62 0-88C-34-62-24-30 0-20Z"
    veins = "M0-21Q-12-52 0-87M0-21Q12-52 0-87M-21-46Q0-40 21-46M-17-70Q0-64 17-70"
    stops = [f'<radialGradient id="rose-{k}" cx="50%" cy="70%" r="75%"><stop offset="0" '
             f'stop-color="{light}"/><stop offset="1" stop-color="{deep}"/></radialGradient>'
             for k, (light, deep) in enumerate(ROSE_GLASS)]
    turns = [f'transform="rotate({60 * k})"' for k in range(6)]
    gems = [f'<circle cx="{74 * math.sin(math.radians(30 + 60 * k)):.2f}" '
            f'cy="{-74 * math.cos(math.radians(30 + 60 * k)):.2f}" r="9"/>' for k in range(6)]
    return [
        '<svg class="rose" viewBox="-100 -100 200 200" aria-hidden="true" focusable="false">',
        f'  <defs>{"".join(stops)}</defs>',
        '  <circle class="rose-ground" r="96"/>',
        '  <g class="rose-dark">' + "".join(f'<path d="{petal}" {t}/>' for t in turns) + "</g>",
        '  <g class="rose-lit">' + "".join(
            f'<path d="{petal}" fill="url(#rose-{k})" {t}/>' for k, t in enumerate(turns)) + "</g>",
        f'  <g class="rose-gems">{"".join(gems)}</g>',
        '  <g class="rose-lead">' + "".join(
            f'<path d="{petal}{veins}" {t}/>' for t in turns) + "".join(gems)
        + '<circle r="20"/><circle r="92"/><circle r="97"/></g>',
        '  <circle class="rose-heart" r="15"/>',
        "</svg>",
    ]


def body(lang: str, *, site: Path, twin: str, twin_name: str, guides: list[tuple[str, str]],
         contact: str) -> list[str]:
    """Header and <main> of one teaser page; build_site.py adds the footer."""
    c = COPY[lang]
    off, on = c["sound"]
    sounds = " ".join(f'data-{s.name}="{" ".join(f"/{MEDIA_DIR}/{n}" for n in s.outputs())}"'
                      for s in SOUNDS)
    road = []
    for scene, key, line, line_key in zip(SCENES, ROAD_KEYS, c["road_lines"], ROAD_LINE_KEYS):
        road += ['    <li class="road-pane"><figure>',
                 "      " + picture(site, f"scene-{scene}", "", "(min-width: 64rem) 46vw, 82vw", "road-art"),
                 f'      <figcaption><span class="road-kicker display">{esc(say(lang, key))}</span>'
                 f'{esc(line or say(lang, line_key))}</figcaption>',
                 "    </figure></li>"]
    cards = [f'    <li class="card"><div class="card-turn"><div class="card-back">'
             f'{picture(site, f"back-{BACKS[i % 3]}", "", "12rem", "card-pic")}</div>'
             f'<div class="card-face">{picture(site, f"card-{card}", "", "12rem", "card-pic")}'
             f'<span class="card-name display">{esc(say(lang, f"content.cards.{card}.name"))}</span>'
             f"</div></div></li>" for i, card in enumerate(CARDS)]
    aspects = []
    for aspect in ASPECTS:
        name = say(lang, f"content.aspects.{aspect}.name")
        aspects += [f'    <article class="aspect aspect-{aspect}">',
                    "      " + picture(site, f"aspect-{aspect}", name, "(min-width: 48rem) 22rem, 70vw",
                                       "aspect-art"),
                    f'      <h3 class="aspect-name display">{esc(name)}</h3>',
                    f'      <p>{esc(say(lang, f"content.aspects.{aspect}.blurb"))}</p>',
                    "    </article>"]
    foes = ["    <li>" + picture(site, f"foe-{foe}", say(lang, f"content.enemies.{foe}.name"),
                                 "(min-width: 48rem) 12rem, 30vw", "foe") + "</li>" for foe in FOES]
    return [
        '<header class="bar">',
        f'  <a class="bar-mark display" href="{HOME[lang]}">'
        f'<img src="/assets/icon.png" alt="" aria-hidden="true" width="64" height="64">'
        f'<span>{NAME[lang]}</span></a>',
        f'  <button class="sound" type="button" aria-pressed="false" hidden {sounds} '
        f'data-off="{esc(off)}" data-on="{esc(on)}"><span class="sound-wave" aria-hidden="true">'
        f'<i></i><i></i><i></i></span><span class="sound-label">{esc(off)}</span></button>',
        f'  <a class="switch" href="{HOME[twin]}" hreflang="{twin}" lang="{twin}">{twin_name}</a>',
        "</header>",
        '<main class="teaser-main">',
        '<section class="hero" data-scene="hero">',
        '  <div class="hero-sky" aria-hidden="true">',
        "    " + picture(site, "vigil-road", "", "100vw", "hero-road", eager=True, tall="vigil-road-tall"),
        '    <canvas class="hero-light"></canvas>',
        '    <div class="shafts"><i></i><i></i><i></i></div>',
        "  </div>",
        "  " + picture(site, "lantern", "", "(min-width: 48rem) 13rem, 7.5rem", "lantern", eager=True),
        '  <div class="hero-copy">',
        '    <h1 class="wordmark">' + picture(site, f"wordmark-{lang}", NAME[lang],
                                             "(min-width: 48rem) 40rem, 88vw", "wordmark-art", eager=True)
        + "</h1>",
        f'    <p class="kicker display">{esc(c["kicker"])}</p>',
        f'    <p class="lede">{esc(c["lede"])}</p>',
        f'    <p class="soon-on">{esc(c["soon_on"])}</p>',
        *("    " + line for line in platforms(lang, "platforms")),
        "  </div>",
        f'  <a class="cue" href="{HOME[lang]}#fire"><span>{esc(say(lang, "ui.embark.title"))}</span></a>',
        "</section>",
        '<section class="fire" id="fire" data-scene="fire">',
        '  <div class="fire-stage">',
        '    <div class="fire-glow" aria-hidden="true"></div>',
        *("    " + line for line in rose_window()),
        f'    <h2 class="fire-line">{esc(c["fire"])}</h2>',
        f'    <p class="fire-after">{esc(c["fire_after"])}</p>',
        "  </div>",
        "</section>",
        '<section class="road" data-scene="road" aria-labelledby="road-title">',
        '  <div class="road-stage">',
        f'    <h2 class="road-title" id="road-title">{esc(c["road"])}</h2>',
        '    <ol class="road-track">', *road, "    </ol>",
        "  </div>",
        "</section>",
        '<section class="deck" data-scene="deck" aria-labelledby="deck-title">',
        '  <div class="deck-stage">',
        f'    <p class="kicker display">{esc(c["deck_kicker"])}</p>',
        f'    <h2 id="deck-title">{esc(c["deck"])}</h2>',
        '    <ul class="fan">', *cards, "    </ul>",
        "  </div>",
        "</section>",
        '<section class="aspects" aria-labelledby="aspects-title">',
        f'  <h2 id="aspects-title">{esc(say(lang, "ui.embark.aspectLabel"))}</h2>',
        '  <div class="aspect-row">', *aspects, "  </div>",
        "</section>",
        '<section class="foes" data-scene="foes" aria-labelledby="foes-title">',
        '  <ul class="foe-row">', *foes, "  </ul>",
        f'  <h2 id="foes-title">{esc(c["foes"])}</h2>',
        "</section>",
        '<section class="vow" id="soon" data-scene="vow" aria-labelledby="vow-title">',
        '  <div class="vow-stage">',
        '    <div class="vow-copy">',
        f'      <h2 id="vow-title">{esc(c["soon"])}</h2>',
        *("      " + line for line in platforms(lang, "platforms platforms-large")),
        f'      <p class="facts">{esc(c["facts"])}</p>',
        "    </div>",
        '    <canvas class="vow-glass" aria-hidden="true"></canvas>',
        "  </div>",
        "</section>",
        f'<nav class="more" aria-label="{esc(c["more"])}">',
        *(f'  <a href="{path}">{esc(name)}</a>' for path, name in guides),
        "</nav>",
        f'<p class="support">{esc(c["support"])} · <span class="address">{contact}</span></p>',
        "</main>",
    ]


HEAD = (f'<link rel="stylesheet" href="{STYLESHEET}">',
        f'<script type="module" src="{SCRIPT}"></script>')


# --- Rules -----------------------------------------------------------------

YEAR = re.compile(r"\b(?:19|20)\d\d\b")
PRICE = re.compile(r"[$£€¥]\s?\d|\bHK\$|\bfree\b|免費", re.IGNORECASE)
RATING = re.compile(r"★|☆|\brating\b|評分|\d(?:\.\d)?\s?/\s?5\b", re.IGNORECASE)


def page_errors(page: str, lang: str) -> list[str]:
    """Unreleased-store, audio and switch rules a teaser page must keep."""
    errors = []
    lists = re.findall(r'<ul class="platforms[^"]*">(.*?)</ul>', page, flags=re.S)
    if not lists:
        errors.append("no platform row")
    for row in lists:
        names = re.findall(r'class="platform-name display">([^<]*)<', row)
        if tuple(html.unescape(name) for name in names) != PLATFORMS:
            errors.append(f"platform row must name exactly {', '.join(PLATFORMS)}")
        if row.count(f'class="platform-soon">{esc(COPY[lang]["coming"])}<') != len(PLATFORMS):
            errors.append("every platform must say it is coming soon")
        if re.search(r"<a\b|<img\b|badge", row, flags=re.I):
            errors.append("platform row must not link out or show store badges")
    if re.search(r"\sautoplay\b", page):
        errors.append("audio must never autoplay")
    if 'class="sound" type="button" aria-pressed="false"' not in page:
        errors.append("sound must start off")
    twin = "zh-Hant" if lang == "en" else "en"
    if f'class="switch" href="{HOME[twin]}" hreflang="{twin}"' not in page:
        errors.append(f"language switch must lead to {HOME[twin]}")
    visible = re.sub(r"<script.*?</script>|<[^>]+>", " ", page.split("<body", 1)[-1], flags=re.S)
    for label, pattern in (("a year or release date", YEAR), ("a price", PRICE),
                           ("a rating", RATING)):
        if pattern.search(html.unescape(visible)):
            errors.append(f"teaser must not show {label}")
    return errors

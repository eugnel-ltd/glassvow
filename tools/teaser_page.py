"""Glassvow's home page in English and 繁體中文: / and /zh-hant/.

tools/build_site.py renders and audits these pages. What the page shows lives in
tools/story_page.py (template, copy and media list); this module owns the media
pipeline, the head and the rules. The art, clips, models and sound the pages
use are web copies of files in this repository: `build_site.py --media` encodes
them into site/assets/teaser/ (needs Pillow with AVIF and ffmpeg) and writes
media.json, which pins each output to its source digest and recipe, so
`--check` fails when a source, a recipe or an output drifts.
"""

from __future__ import annotations

import hashlib
import html
import json
import re
import shutil
import struct
import subprocess

import story_page as story
from dataclasses import dataclass
from functools import cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MEDIA_DIR = "assets/teaser"
MANIFEST = f"{MEDIA_DIR}/media.json"
SCRIPT = "/assets/story.js"
STYLESHEETS = ("/assets/story.css", "/assets/story-systems.css")
HOME = {"en": "/", "zh-Hant": "/zh-hant/"}
NAME = {"en": "Glassvow", "zh-Hant": "琉璃誓言"}
PRIVACY = {"en": "/privacy/", "zh-Hant": "/privacy/zh-hant/"}
# Owner decision, 19 October 2026: all four are coming soon. Unreleased, so never
# store badges, links, dates or prices. One store per platform. Owner, 20 October
# 2026 (website comments): each plain name may carry its platform's mark.
PLATFORMS = ("App Store", "Google Play", "Amazon Appstore", "Steam")
GAME_PLATFORMS = ("iOS (App Store)", "Android (Google Play)", "Amazon Appstore", "Steam (PC)")
OPERATING_SYSTEMS = "iOS, Android"


def platform_list(lang: str) -> str:
    """The four platforms as one phrase, worded the same on every page and in the entity."""
    if lang == "en":
        return f"{', '.join(GAME_PLATFORMS[:-1])} and {GAME_PLATFORMS[-1]}"
    wide = [name.replace(" (", "（").replace(")", "）") for name in GAME_PLATFORMS]
    return f"{'、'.join(wide[:-1])} 及 {wide[-1]}"


class MediaError(ValueError):
    """Teaser media that is missing, stale or cannot be encoded."""


@dataclass(frozen=True)
class Picture:
    name: str
    source: str
    widths: tuple[int, ...]
    aspect: float | None = None  # centre crop to width / height
    trim: bool = False  # crop to the alpha bounding box first
    box: tuple[int, int, int, int] | None = None  # crop to this box before anything else

    def outputs(self) -> dict[str, str]:
        crop = f" box={self.box}" if self.box else ""
        return {f"{self.name}-{width}.{ext}": f"{ext} w={width} aspect={self.aspect} trim={self.trim}{crop}"
                for width in self.widths for ext in ("avif", "webp")}


@dataclass(frozen=True)
class File:
    name: str
    source: str

    def outputs(self) -> dict[str, str]:
        return {self.name: "copy"}


@dataclass(frozen=True)
class Model:
    """A GLB whose one embedded image moves out beside it, so three.js loads it
    as an ordinary same-origin image (the CSP admits no blob: URL)."""
    name: str
    source: str

    def outputs(self) -> dict[str, str]:
        return {f"{self.name}.glb": "glb skin=external", f"{self.name}-skin.jpg": "glb skin"}


def split_glb(data: bytes, skin_uri: str) -> tuple[bytes, bytes]:
    """The GLB with its single image pointed at skin_uri, and that image's bytes."""
    magic, version, _ = struct.unpack_from("<III", data, 0)
    json_len, json_type = struct.unpack_from("<II", data, 12)
    if magic != 0x46546C67 or version != 2 or json_type != 0x4E4F534A:
        raise MediaError("not a glTF 2.0 binary")
    doc = json.loads(data[20:20 + json_len])
    rest = data[20 + json_len:]
    bin_len, _ = struct.unpack_from("<II", rest, 0)
    blob = rest[8:8 + bin_len]
    images = doc.get("images", [])
    if len(images) != 1 or images[0].get("mimeType") != "image/jpeg" or "bufferView" not in images[0]:
        raise MediaError("expected exactly one embedded JPEG")
    view = doc["bufferViews"][images[0]["bufferView"]]
    start = view.get("byteOffset", 0)
    skin = blob[start:start + view["byteLength"]]
    images[0] = {"uri": skin_uri}
    text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    text += b" " * (-len(text) % 4)
    body = struct.pack("<II", len(text), json_type) + text + rest
    return struct.pack("<III", magic, version, 12 + len(body)) + body, skin


# Vendored scripts, pinned: three.js r128 (npm three@0.128.0, MIT) for the foes.
VENDOR = {
    "assets/vendor/three.min.js": "9274bbcec8d96168626c732b5d31c775aa8cfb7eaa0599bec0c175908a2c1ce2",
    "assets/vendor/GLTFLoader.js": "5c15967ba830918a9caea6338712c994c354bccd4edc4569bde411c3ec06a3e6",
    "assets/vendor/three-LICENSE.txt": "7dddf7c5b8fd10ee654db8857d75d104b5557889aa5a91fc4ca545ea7c07062f",
}


def vendor_problems(site: Path) -> list[str]:
    return [f"VENDOR site/{path} does not match its pinned digest" for path, sha in VENDOR.items()
            if not (site / path).is_file() or digest(site / path) != sha]


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
    Picture("wordmark-en", "assets/art/title/title.png", (640, 1280), trim=True),
    Picture("wordmark-zh-Hant", "assets/art/title/title-zh.png", (640, 1280), trim=True),
    *(Picture(name, source, widths, opts.get("aspect"), opts.get("trim", False), opts.get("box"))
      for name, source, widths, opts in story.PICTURE_SPECS),
)
FILES = (*(File(name, source) for name, source in story.FILE_SPECS),
         *(Model(name, source) for name, source in story.MODEL_SPECS))
SOUNDS = (
    # The title theme falls quiet near 2:05; the cut and fade land there.
    Sound("theme", "assets/audio/music/title.mp3", 126.0, ("64k", "96k")),
    Sound("shatter", "assets/audio/sfx/shatter.mp3"),
)

COPY = {
    "en": {
        "title": "Glassvow · 琉璃誓言 — a stained-glass roguelite deckbuilder",
        "description": "Glassvow (琉璃誓言): a stained-glass roguelite deckbuilder, coming soon to "
                       f"{platform_list('en')}.",
        "coming": "Coming soon",
        "sound": ("Sound off", "Sound on"),
        "privacy": "Privacy",
    },
    "zh-Hant": {
        "title": "琉璃誓言 Glassvow — 彩窗上的朝聖之路",
        "description": "《琉璃誓言》（Glassvow）是一款單人 Roguelike 牌組構築遊戲，亦是一場彩窗上的朝聖。"
                       f"即將登陸 {platform_list('zh-Hant')}。",
        "coming": "即將推出",
        "sound": ("聲音：關", "聲音：開"),
        "privacy": "私隱政策",
    },
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_outputs() -> dict[str, tuple[str, str]]:
    return {name: (item.source, recipe) for item in (*PICTURES, *SOUNDS, *FILES)
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
        if picture.box:
            image = image.crop(picture.box)
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
    for file in FILES:
        if isinstance(file, Model):
            glb, skin = split_glb((ROOT / file.source).read_bytes(), f"{file.name}-skin.jpg")
            (folder / f"{file.name}.glb").write_bytes(glb)
            (folder / f"{file.name}-skin.jpg").write_bytes(skin)
            outputs[f"{file.name}.glb"], outputs[f"{file.name}-skin.jpg"] = {}, {}
        else:
            shutil.copyfile(ROOT / file.source, folder / file.name)
            outputs[file.name] = {}
    for name, (source, recipe) in expected_outputs().items():
        outputs[name].update(source=source, recipe=recipe, source_sha256=digest(ROOT / source),
                             sha256=digest(folder / name), bytes=(folder / name).stat().st_size)
    (site / MANIFEST).write_text(json.dumps({"outputs": outputs}, indent=1, sort_keys=True) + "\n",
                                 encoding="utf-8")


# --- Markup ----------------------------------------------------------------

def esc(text: str) -> str:
    return html.escape(text, quote=True)


def pictures(site: Path) -> dict[str, dict]:
    """Each picture's URL stem, widths and largest WebP size, from media.json."""
    outputs = load_manifest(site)
    found = {}
    for pic in PICTURES:
        largest = outputs.get(f"{pic.name}-{pic.widths[-1]}.webp")
        if largest is None:
            raise MediaError(f"{pic.name} is not encoded; run tools/build_site.py --media")
        found[pic.name] = {"url": f"/{MEDIA_DIR}/{pic.name}", "widths": pic.widths,
                           "width": largest["width"], "height": largest["height"]}
    return found


def body(lang: str, *, site: Path, twin: str, twin_name: str, guides: list[tuple[str, str]],
         contact: str) -> list[str]:
    """Header and <main> of one home page; build_site.py adds the footer."""
    off, on = COPY[lang]["sound"]
    sounds = " ".join(f'data-{s.name}="{" ".join(f"/{MEDIA_DIR}/{n}" for n in s.outputs())}"'
                      for s in SOUNDS)
    sound = (f'<button class="sound" type="button" aria-pressed="false" hidden {sounds} '
             f'data-off="{esc(off)}" data-on="{esc(on)}"><span class="sound-wave" aria-hidden="true">'
             f'<i></i><i></i><i></i></span><span class="sound-label">{esc(off)}</span></button>')
    found = pictures(site)
    ctx = story.context(lang, pictures=found, media_url=MEDIA_DIR, twin=twin, twin_name=twin_name,
                        home=HOME[lang], twin_home=HOME[twin], name=NAME[lang], guides=guides,
                        contact=contact, sound=sound, platforms=PLATFORMS)
    return story.render(ctx, found)


HEAD = (*(f'<link rel="stylesheet" href="{sheet}">' for sheet in STYLESHEETS),
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

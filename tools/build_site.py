#!/usr/bin/env python3
"""Build the public site in site/ from Markdown.

docs/privacy/privacy-policy.en.md and privacy-policy.zh-Hant.md become
/privacy/ and /privacy/zh-hant/; docs/legal/company-information.en.md and
.zh-Hant.md become /company/ and /company/zh-hant/; docs/site/*.md become
/faq/, /play/ and /genre/ (each with a zh-Hant twin). The home page is the
teaser in tools/teaser_page.py, at / and /zh-hant/. A deliberately small
reader accepts `#` and `##` headings, paragraphs, `-` lists, links, **strong**
and *emphasis*. Anything else, an unfilled [placeholder] or the draft HTML
comment stops the build. Every page is then audited: balanced tags, a language,
a title and a description, internal links that exist, no inline code and
nothing loaded from another origin, because site/_headers serves a self-only
Content-Security-Policy; the teaser's one module script is a file on this
site. The per-page footer is © EUGNEL LTD plus a link to the Company
information page (the teaser's adds only its privacy link); statutory details
live only on that page.
Indexable pages also carry length-bounded titles and descriptions, a canonical
URL, hreflang en/zh-Hant/x-default, Open Graph/Twitter tags, and JSON-LD
(VideoGame + MobileApplication + Organization). FAQ pages add FAQPage whose
Q/A match the visible headings. The builder writes sitemap.xml, robots.txt
and llms.txt.

    python3 tools/build_site.py                 write site/
    python3 tools/build_site.py --check         exit 1 when site/ is stale
    python3 tools/build_site.py --self-test     prove that each check can fail
    python3 tools/build_site.py --display-font  re-subset the zh-Hant heading face
    python3 tools/build_site.py --media         re-encode the teaser's art and sound

Only --display-font and --media need more than the standard library: the first
reuses the pinned Noto sources and pyftsubset of tools/subset_noto_serif_tc.py,
the second needs Pillow (with AVIF) and ffmpeg.
Deploy with: npx wrangler pages deploy site --project-name glassvow-site
"""

from __future__ import annotations

import argparse
import hashlib
import html
import importlib.util
import json
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from collections import Counter
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Callable

import teaser_page as teaser

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"
ORIGIN = "https://glassvow.eugnel.com"
CONTACT = "glassvow@eugnel.com"
PRIVACY_CONTACT = "hello@eugnel.com"
# Trading disclosures live on one Company information page; every other page
# keeps a persistent footer link. Ampersand is escaped when written to HTML.
COMPANY_NUMBER = "17505169"
ICO_NUMBER = "ZC277339"
REGISTERED_OFFICE = "122 New Road, Ascot, SL5 8QH"
OLD_CONTROLLER = "James TO"
RETIRED_REGULATOR = "Information Commissioner"
RETIRED_REGULATOR_ZH = "資訊專員"
COMPANY_HREF = {"en": "/company/", "zh-Hant": "/company/zh-hant/"}
COMPANY_LABEL = {"en": "Company information", "zh-Hant": "公司資料"}
ORGANIZATION_NAME = "EUGNEL LTD"
GAME_NAME = "Glassvow"
GAME_ALTERNATE_NAME = "琉璃誓言"
GAME_DESCRIPTION = f"Glassvow (琉璃誓言) is a single-player card game coming soon to {teaser.platform_list('en')}."
GAME_DESCRIPTION_ZH = f"《琉璃誓言》（Glassvow）是一款單人卡牌遊戲，即將登陸 {teaser.platform_list('zh-Hant')}。"
# The privacy policy describes the iOS build as it exists today; every other page
# names all four platforms (teaser.GAME_PLATFORMS) and never the iOS-only wording.
IOS_ONLY = ("iPhone and iPad", "iPhone 及 iPad")
TITLE_BOUNDS = (8, 70)
DESCRIPTION_BOUNDS = (50, 160)
OG_IMAGE = "assets/og.png"
OG_IMAGE_SIZE = (512, 512)
OG_LOCALE = {"en": "en_GB", "zh-Hant": "zh_Hant"}
JSONLD_FORBIDDEN = (COMPANY_NUMBER, REGISTERED_OFFICE, ICO_NUMBER)
NOTICE_FORBIDDEN = JSONLD_FORBIDDEN
AI_BOTS = ("GPTBot", "OAI-SearchBot", "Google-Extended", "PerplexityBot", "ClaudeBot")
ENTITY_PATH = ROOT / "docs/marketing/entity.md"
ENTITY_FIELD = re.compile(r"^([a-z_]+): (.+)$")
ENTITY_REQUIRED = (
    "developer", "url", "privacy_email", "support_email",
    "game_en", "game_zh", "subtitle_en", "subtitle_zh", "short_en", "short_zh",
)
LISTING_JSON = {
    "en-US": ROOT / "docs/product/listing/ios/en-US.json",
    "zh-Hant": ROOT / "docs/product/listing/ios/zh-Hant.json",
}
FOOTER_FORBIDDEN = NOTICE_FORBIDDEN + (PRIVACY_CONTACT,)
SLIM_SOURCES = (
    "docs/privacy/privacy-policy.en.md",
    "docs/privacy/privacy-policy.zh-Hant.md",
    "docs/legal/terms-and-refunds.en.md",
    "docs/legal/terms-and-refunds.zh-Hant.md",
)
PRIVACY_EN_REQUIRED = (
    "EUGNEL LTD",
    "https://ico.org.uk/make-a-complaint/",
    PRIVACY_CONTACT,
    "within 30 days",
    "without undue delay",
    "complain to us first",
    "Information Commission (ICO)",
)
PRIVACY_ZH_REQUIRED = (
    "EUGNEL LTD",
    "資訊委員會（ICO）",
    "https://ico.org.uk/make-a-complaint/",
    PRIVACY_CONTACT,
    "30 日",
    "不得無故拖延",
    "先向我們投訴",
)
COMPANY_EN_REQUIRED = (
    "EUGNEL LTD",
    "registered in England &amp; Wales",
    f"company no. {COMPANY_NUMBER}",
    REGISTERED_OFFICE,
    PRIVACY_CONTACT,
    f"registered with the Information Commission (ICO), registration number {ICO_NUMBER}",
)
COMPANY_ZH_REQUIRED = (
    "EUGNEL LTD",
    "英格蘭及威爾斯",
    f"公司編號 {COMPANY_NUMBER}",
    REGISTERED_OFFICE,
    PRIVACY_CONTACT,
    "資訊委員會（ICO）",
    ICO_NUMBER,
)
LEGAL_FOOTER = re.compile(r'<footer class="legal">.*?</footer>', re.S)
# Each language names itself, as the game's language selector does.
LANGUAGE_NAMES = {"en": "English", "zh-Hant": "繁體中文"}


@dataclass(frozen=True)
class Policy:
    lang: str
    source: str
    path: str
    name: str
    brand: str
    description: str
    kind: str = "article"


POLICIES = (
    Policy("en", "docs/privacy/privacy-policy.en.md", "/privacy/", "Privacy policy", "Glassvow",
           "What Glassvow, a card game for iPhone and iPad, handles: no accounts, ads or "
           "analytics; saves stay on your device; crash reports go only to Sentry."),
    Policy("zh-Hant", "docs/privacy/privacy-policy.zh-Hant.md", "/privacy/zh-hant/", "私隱政策",
           "琉璃誓言",
           "《琉璃誓言》會處理哪些資料：沒有帳戶、廣告或分析工具；存檔只保存在你的裝置上；"
           "技術性的當機及錯誤報告只會傳送給一家服務供應商 Sentry。"),
)
COMPANY_PAGES = (
    Policy("en", "docs/legal/company-information.en.md", "/company/", "Company information",
           "Glassvow",
           "EUGNEL LTD: registered in England & Wales, company number, registered office, "
           "contact and ICO registration."),
    Policy("zh-Hant", "docs/legal/company-information.zh-Hant.md", "/company/zh-hant/", "公司資料",
           "琉璃誓言",
           "EUGNEL LTD 公司資料：英格蘭及威爾斯註冊、公司編號、註冊辦事處、聯絡電郵及 ICO 登記。"),
)
FAQ_PAGES = (
    Policy("en", "docs/site/faq.en.md", "/faq/", "FAQ", "Glassvow",
           "Answers about Glassvow (琉璃誓言): what it is, who makes it, which platforms it is "
           "coming to, saves, ads, and how to reach EUGNEL LTD.", "faq"),
    Policy("zh-Hant", "docs/site/faq.zh-Hant.md", "/faq/zh-hant/", "常見問題", "琉璃誓言",
           "《琉璃誓言》（Glassvow）常見問題：這是甚麼遊戲、誰製作、即將登陸哪些平台、存檔、廣告，"
           "以及如何聯絡 EUGNEL LTD。", "faq"),
)
PLAY_PAGES = (
    Policy("en", "docs/site/play.en.md", "/play/", "How to play", "Glassvow",
           "How to play Glassvow: walk east from the Vigil with a lantern, build a deck of "
           "glass, kindle the lantern, and shatter what blocks the way."),
    Policy("zh-Hant", "docs/site/play.zh-Hant.md", "/play/zh-hant/", "玩法", "琉璃誓言",
           "《琉璃誓言》怎麼玩：提燈離開守夜之爐向東走，組一副琉璃牌，點燃提燈，打碎擋路之物。"
           f"單人卡牌遊戲，即將登陸 {teaser.platform_list('zh-Hant')}。"),
)
GENRE_PAGES = (
    Policy("en", "docs/site/genre.en.md", "/genre/", "A roguelite deckbuilder", "Glassvow",
           f"Glassvow, a stained-glass roguelite deckbuilder, coming soon to {teaser.platform_list('en')}."),
    Policy("zh-Hant", "docs/site/genre.zh-Hant.md", "/genre/zh-hant/", "Roguelike 牌組構築",
           "琉璃誓言",
           "《琉璃誓言》是一款單人 Roguelike 牌組構築遊戲，亦是一場彩窗上的朝聖，"
           f"即將登陸 {teaser.platform_list('zh-Hant')}。"),
)
PAGE_GROUPS = (POLICIES, COMPANY_PAGES, FAQ_PAGES, PLAY_PAGES, GENRE_PAGES)

# Copied byte for byte, so the game's own files stay the single source.
COPIES = {
    "assets/fonts/Cinzel-700.woff2": "assets/fonts/Cinzel-700.woff2",
    "assets/fonts/OFL-Cinzel.txt": "assets/fonts/OFL-Cinzel.txt",
    "assets/fonts/Cinzel-800.woff2": "assets/fonts/Cinzel-800.woff2",
    "assets/fonts/Alegreya-400.woff2": "assets/fonts/Alegreya-400.woff2",
    "assets/fonts/Alegreya-700.woff2": "assets/fonts/Alegreya-700.woff2",
    "assets/fonts/OFL-Alegreya.txt": "assets/fonts/OFL-Alegreya.txt",
    "assets/fonts/OFL-NotoSerifTC.txt": "assets/fonts/OFL.txt",
}
STYLESHEET = "assets/site.css"
DISPLAY_FONT = "assets/fonts/NotoSerifTC-SemiBold-display.woff2"
DISPLAY_MANIFEST = "assets/fonts/NotoSerifTC-SemiBold-display.json"


def char_class(*ranges: tuple[int, int]) -> str:
    return "[" + "".join(f"{chr(low)}-{chr(high)}" for low, high in ranges) + "]"


# Chinese characters and full-width forms: the unicode-range of the heading
# face in site.css, so the glyphs it must carry are exactly these in headings.
CJK = re.compile(char_class((0x2E80, 0x9FFF), (0xF900, 0xFAFF), (0xFE30, 0xFE4F), (0xFF00, 0xFFEF)))
CJK_RUN = re.compile(CJK.pattern + "+")
# GitHub closes `**…：**` before a Chinese character only when a space follows;
# on the page that space would double the gap full-width punctuation carries.
WIDE_PUNCTUATION_SPACE = re.compile(
    "(" + char_class((0x3000, 0x303F), (0xFF00, 0xFFEF)) + "(?:</(?:strong|em)>)?) ")


class BuildError(ValueError):
    """A source or page that must not be published as it stands."""


# --- Markdown subset -------------------------------------------------------

UNSUPPORTED = (
    (re.compile(r"<!--"), "HTML comment (delete the draft notice before publishing)"),
    (re.compile(r"^\s*(```|~~~)"), "code fence"),
    (re.compile(r"^\s*>"), "blockquote"),
    (re.compile(r"^\s*\|"), "table"),
    (re.compile(r"^\s*\d+[.)]\s"), "ordered list"),
    (re.compile(r"^\s*[*+]\s"), "list marker other than '-'"),
    (re.compile(r"^\s*([-*_=])(?:\s*\1){2,}\s*$"), "rule or underlined heading"),
    (re.compile(r"^#{3,}\s"), "heading below level 2"),
    (re.compile(r"^\s+\S"), "indented line"),
    (re.compile(r"`"), "inline code"),
    (re.compile(r"!\["), "image"),
    (re.compile(r"<[A-Za-z/!]"), "raw HTML"),
    (re.compile(r"\[[^\]]*\](?!\()"), "unfilled [placeholder] or reference link"),
)
HEADING = re.compile(r"(#{1,2}) (\S.*)")
LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
STRONG = re.compile(r"\*\*(?=\S)(.+?)(?<=\S)\*\*")
EMPHASIS = re.compile(r"\*(?=\S)(.+?)(?<=\S)\*")
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")


def email(address: str) -> str:
    # Cloudflare's Email Obfuscation would swap the address for a script the
    # CSP blocks; these markers tell it to leave the text alone.
    return f"<!--email_off-->{address}<!--/email_off-->"


def text_html(text: str, lang: str) -> str:
    out = STRONG.sub(r"<strong>\1</strong>", html.escape(text, quote=False))
    out = EMPHASIS.sub(r"<em>\1</em>", out)
    if "*" in out:
        raise BuildError(f"unbalanced emphasis: {text[:60]}")
    out = EMAIL.sub(lambda match: email(match.group(0)), out)
    if lang == "en":  # Chinese inside English copy is read with its own voice.
        return CJK_RUN.sub(r'<span lang="zh-Hant">\g<0></span>', out)
    return WIDE_PUNCTUATION_SPACE.sub(r"\1", out)


def inline_html(text: str, lang: str) -> str:
    parts, cursor = [], 0
    for match in LINK.finditer(text):
        label, href = match.groups()
        if not href.startswith(("https://", "mailto:", "/")):
            raise BuildError(f"link target must be https, mailto or site-relative: {href}")
        parts += [text_html(text[cursor:match.start()], lang),
                  f'<a href="{html.escape(href)}">{text_html(label, lang)}</a>']
        cursor = match.end()
    return "".join(parts) + text_html(text[cursor:], lang)


def blocks_of(source: str) -> list[list[str]]:
    blocks: list[list[str]] = [[]]
    for number, line in enumerate(source.splitlines(), 1):
        for pattern, reason in UNSUPPORTED:
            if pattern.search(line):
                raise BuildError(f"line {number}: {reason}: {line.strip()[:60]}")
        if line.strip():
            blocks[-1].append(line.strip())
        elif blocks[-1]:
            blocks.append([])
    return [block for block in blocks if block]


def render_markdown(source: str, lang: str) -> list[str]:
    """Return the supported Markdown subset as indented <article> lines."""
    lines, in_section = ["<article>"], False
    for block in blocks_of(source):
        pad = "    " if in_section else "  "
        heading = HEADING.fullmatch(block[0])
        if heading and len(block) > 1:
            raise BuildError(f"a heading must stand alone: {block[0][:60]}")
        if heading and len(heading.group(1)) == 1:
            if len(lines) > 1:
                raise BuildError("the page must open with its only '#' title")
            lines.append(f"  <h1>{inline_html(heading.group(2), lang)}</h1>")
        elif len(lines) == 1:
            raise BuildError(f"the page must open with its '#' title: {block[0][:60]}")
        elif heading:
            lines += ["  </section>"] * in_section
            lines += ["  <section>", f"    <h2>{inline_html(heading.group(2), lang)}</h2>"]
            in_section = True
        elif all(line.startswith("- ") for line in block):
            lines += [f"{pad}<ul>", *(f"{pad}  <li>{inline_html(line[2:], lang)}</li>"
                                      for line in block), f"{pad}</ul>"]
        elif any(line.startswith("- ") for line in block):
            raise BuildError(f"a list must not share a block with a paragraph: {block[0][:60]}")
        else:
            lines.append(f"{pad}<p>{inline_html(' '.join(block), lang)}</p>")
    if len(lines) == 1:
        raise BuildError("no '#' title")
    return lines + ["  </section>"] * in_section + ["</article>"]


# --- Pages -----------------------------------------------------------------

def page_url(path: str) -> str:
    return f"{ORIGIN}{path}"


def load_entity() -> dict[str, str]:
    text = ENTITY_PATH.read_text(encoding="utf-8")
    values = {}
    for line in text.splitlines():
        match = ENTITY_FIELD.fullmatch(line)
        if match:
            values[match.group(1)] = match.group(2)
    missing = [name for name in ENTITY_REQUIRED if name not in values]
    if missing:
        raise BuildError(f"{ENTITY_PATH.relative_to(ROOT)} missing {', '.join(missing)}")
    return values


def entity_errors() -> list[str]:
    """Keep site, JSON-LD, llms.txt and listing names on one public entity."""
    try:
        values = load_entity()
    except (OSError, BuildError) as error:
        return [str(error)]
    text = ENTITY_PATH.read_text(encoding="utf-8")
    errors = [f"entity.md still carries {item!r}" for item in NOTICE_FORBIDDEN if item in text]
    expected = {
        "developer": ORGANIZATION_NAME,
        "url": ORIGIN,
        "privacy_email": PRIVACY_CONTACT,
        "support_email": CONTACT,
        "game_en": GAME_NAME,
        "game_zh": GAME_ALTERNATE_NAME,
        "short_en": GAME_DESCRIPTION,
        "short_zh": GAME_DESCRIPTION_ZH,
    }
    errors.extend(f"entity {key} != {want!r}" for key, want in expected.items()
                  if values.get(key) != want)
    errors.extend(f"platform {platform!r} does not name store {store!r}"
                  for store, platform in zip(teaser.PLATFORMS, teaser.GAME_PLATFORMS, strict=True)
                  if store not in platform)
    names = {"en-US": "game_en", "zh-Hant": "game_zh"}
    subs = {"en-US": "subtitle_en", "zh-Hant": "subtitle_zh"}
    for locale, path in LISTING_JSON.items():
        listing = json.loads(path.read_text(encoding="utf-8"))
        if listing.get("name") != values[names[locale]]:
            errors.append(f"listing {locale} name != entity {names[locale]}")
        if listing.get("subtitle") != values[subs[locale]]:
            errors.append(f"listing {locale} subtitle != entity {subs[locale]}")
    return errors


def plain_inline(text: str) -> str:
    text = LINK.sub(r"\1", text)
    text = STRONG.sub(r"\1", text)
    return EMPHASIS.sub(r"\1", text)


def faq_pairs(source: str) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    pending: str | None = None
    for block in blocks_of(source):
        heading = HEADING.fullmatch(block[0]) if len(block) == 1 else None
        if heading and len(heading.group(1)) == 2:
            pending = heading.group(2)
            continue
        if pending is None:
            continue
        if heading or all(line.startswith("- ") for line in block):
            raise BuildError(f"FAQ answer must open with a paragraph: {pending}")
        pairs.append((pending, plain_inline(" ".join(block))))
        pending = None
    if pending:
        raise BuildError(f"FAQ question has no answer: {pending}")
    if len(pairs) < 3:
        raise BuildError("FAQ needs at least three questions")
    return pairs


def visible_text(fragment: str) -> str:
    fragment = re.sub(r"<!--.*?-->", "", fragment, flags=re.S)
    fragment = re.sub(r"<[^>]+>", "", fragment)
    return html.unescape(fragment).strip()


def visible_faq_pairs(page: str) -> list[tuple[str, str]]:
    return [(visible_text(question), visible_text(answer))
            for question, answer in re.findall(r"<h2>(.*?)</h2>\s*<p>(.*?)</p>", page, flags=re.S)]


def node_types(node: dict) -> set[str]:
    value = node.get("@type")
    if isinstance(value, list):
        return {item for item in value if isinstance(item, str)}
    return {value} if isinstance(value, str) else set()


def structured_data(*, lang: str, title: str, description: str, canonical: str,
                    faq: tuple[tuple[str, str], ...] = ()) -> dict:
    """VideoGame + MobileApplication + Organization. No postal address or company number."""
    page = page_url(canonical)
    org_id = f"{ORIGIN}/#organization"
    game_id = f"{ORIGIN}/#videogame"
    image = page_url(f"/{OG_IMAGE}")
    graph: list[dict] = [
        {"@type": "Organization", "@id": org_id, "name": ORGANIZATION_NAME,
         "url": page_url("/"), "email": PRIVACY_CONTACT},
        {"@type": ["VideoGame", "MobileApplication"], "@id": game_id, "name": GAME_NAME,
         "alternateName": GAME_ALTERNATE_NAME, "url": page_url("/"),
         "description": GAME_DESCRIPTION, "inLanguage": ["en", "zh-Hant"],
         "operatingSystem": teaser.OPERATING_SYSTEMS, "gamePlatform": list(teaser.GAME_PLATFORMS),
         "applicationCategory": "GameApplication",
         "author": {"@id": org_id}, "publisher": {"@id": org_id}, "image": image},
        {"@type": "WebPage", "@id": f"{page}#webpage", "url": page, "name": title,
         "description": description, "inLanguage": lang,
         "isPartOf": {"@id": game_id}, "publisher": {"@id": org_id}, "image": image},
    ]
    if faq:
        graph.append({
            "@type": "FAQPage", "@id": f"{page}#faq", "url": page, "inLanguage": lang,
            "mainEntity": [{"@type": "Question", "name": question,
                            "acceptedAnswer": {"@type": "Answer", "text": answer}}
                           for question, answer in faq],
        })
    return {"@context": "https://schema.org", "@graph": graph}


def json_ld_tag(data: dict) -> str:
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("<", r"\u003c")
    return f'<script type="application/ld+json">{payload}</script>'


FONT_PRELOADS = ("/assets/fonts/Cinzel-700.woff2", f"/{DISPLAY_FONT}")


def shell(*, lang: str, title: str, description: str, body: list[str],
          canonical: str | None = None, alternates: tuple[tuple[str, str], ...] = (),
          body_class: str | None = None, robots: str | None = None,
          faq: tuple[tuple[str, str], ...] = (), preloads: tuple[str, ...] = FONT_PRELOADS,
          head_extra: tuple[str, ...] = ()) -> str:
    head = [
        "<!DOCTYPE html>",
        f'<html lang="{lang}">',
        "<head>",
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        '<meta name="color-scheme" content="dark light">',
        '<meta name="theme-color" content="#0b0e1a" media="(prefers-color-scheme: dark)">',
        '<meta name="theme-color" content="#f5f0e5" media="(prefers-color-scheme: light)">',
        f"<title>{html.escape(title)}</title>",
        f'<meta name="description" content="{html.escape(description)}">',
    ]
    if robots:
        head.append(f'<meta name="robots" content="{html.escape(robots)}">')
    if canonical:
        absolute = page_url(canonical)
        image = page_url(f"/{OG_IMAGE}")
        locale = OG_LOCALE[lang]
        alternate_locale = "zh_Hant" if lang == "en" else "en_GB"
        head += [
            f'<link rel="canonical" href="{absolute}">',
            *[f'<link rel="alternate" hreflang="{code}" href="{page_url(path)}">'
              for code, path in alternates],
            '<meta property="og:type" content="website">',
            f'<meta property="og:site_name" content="{html.escape(GAME_NAME)}">',
            f'<meta property="og:locale" content="{locale}">',
            f'<meta property="og:locale:alternate" content="{alternate_locale}">',
            f'<meta property="og:title" content="{html.escape(title)}">',
            f'<meta property="og:description" content="{html.escape(description)}">',
            f'<meta property="og:url" content="{absolute}">',
            f'<meta property="og:image" content="{image}">',
            '<meta property="og:image:type" content="image/png">',
            f'<meta property="og:image:width" content="{OG_IMAGE_SIZE[0]}">',
            f'<meta property="og:image:height" content="{OG_IMAGE_SIZE[1]}">',
            f'<meta property="og:image:alt" content="{html.escape(GAME_NAME)}">',
            '<meta name="twitter:card" content="summary">',
            f'<meta name="twitter:title" content="{html.escape(title)}">',
            f'<meta name="twitter:description" content="{html.escape(description)}">',
            f'<meta name="twitter:image" content="{image}">',
            f'<meta name="twitter:image:alt" content="{html.escape(GAME_NAME)}">',
            json_ld_tag(structured_data(lang=lang, title=title, description=description,
                                       canonical=canonical, faq=faq)),
        ]
    elif alternates:
        head += [f'<link rel="alternate" hreflang="{code}" href="{page_url(path)}">'
                 for code, path in alternates]
    head += [
        *(f'<link rel="preload" href="{font}" as="font" type="font/woff2" crossorigin>'
          for font in preloads),
        '<link rel="icon" href="/assets/icon.png" type="image/png">',
        f'<link rel="stylesheet" href="/{STYLESHEET}">',
        *head_extra,
        "</head>",
        f'<body class="{body_class}">' if body_class else "<body>",
    ]
    return "\n".join(head + body + ["</body>", "</html>", ""])


def company_footer(lang: str = "en") -> list[str]:
    href = COMPANY_HREF[lang]
    label = html.escape(COMPANY_LABEL[lang])
    return ['<footer class="legal">', f'  <p>© EUGNEL LTD · <a href="{href}">{label}</a></p>',
            "</footer>"]


def teaser_footer(lang: str) -> list[str]:
    privacy = html.escape(teaser.COPY[lang]["privacy"])
    return ['<footer class="legal">',
            f'  <p><a href="{COMPANY_HREF[lang]}">© EUGNEL LTD</a> · '
            f'<a href="{teaser.PRIVACY[lang]}">{privacy}</a></p>',
            "</footer>"]


def teaser_footer_errors(page: str, lang: str) -> list[str]:
    """The company rule: only © EUGNEL LTD to /company/ and the privacy link; support stays."""
    footers = LEGAL_FOOTER.findall(page)
    footer = footers[0] if len(footers) == 1 else ""
    links = re.findall(r'<a href="([^"]*)">([^<]*)</a>', footer)
    privacy = teaser.COPY[lang]["privacy"]
    errors = []
    if (links != [(COMPANY_HREF[lang], "© EUGNEL LTD"), (teaser.PRIVACY[lang], html.escape(privacy))]
            or visible_text(footer) != f"© EUGNEL LTD · {privacy}"):
        errors.append("teaser footer must be only © EUGNEL LTD linking to the Company page, "
                      "and the privacy link")
    if CONTACT not in page:
        errors.append(f"teaser must show the support address {CONTACT}")
    return errors


def platform_errors(relative: str, page: str, lang: str) -> list[str]:
    """Guides and teasers name all four platforms; only the privacy policy stays iOS-only."""
    text = html.unescape(page)
    errors = [f"still says only {phrase!r}" for phrase in IOS_ONLY
              if phrase in text and not relative.startswith("privacy/")]
    named = {item.path for group in (FAQ_PAGES, PLAY_PAGES, GENRE_PAGES) for item in group}
    path = "/" + relative.removesuffix("index.html")
    if path in named | set(teaser.HOME.values()) and teaser.platform_list(lang) not in text:
        errors.append(f"must name the four platforms as {teaser.platform_list(lang)!r}")
    return errors


def article_page(page: Policy, twin: Policy, article: list[str],
                 group: tuple[Policy, ...],
                 faq: tuple[tuple[str, str], ...] = ()) -> str:
    bar = [f'  <a class="brand display" href="{teaser.HOME[page.lang]}">{page.brand}</a>',
           f'  <a class="switch" href="{twin.path}" hreflang="{twin.lang}" '
           f'lang="{twin.lang}">{LANGUAGE_NAMES[twin.lang]}</a>']
    body = (['<header class="masthead">', *bar, "</header>", "<main>"]
            + [f"  {line}" for line in article]
            + ["</main>", '<footer class="colophon">', *bar, "</footer>"]
            + company_footer(page.lang))
    alternates = tuple((item.lang, item.path) for item in group)
    return shell(lang=page.lang, title=f"{page.name} · {page.brand}",
                 description=page.description, body=body, canonical=page.path,
                 alternates=alternates + (("x-default", group[0].path),), faq=faq)


def policy_panes() -> list[str]:
    panes = [f'    <a class="pane" href="{item.path}" hreflang="{item.lang}" lang="{item.lang}">'
             f'<span class="pane-kicker">{LANGUAGE_NAMES[item.lang]}</span> '
             f'<span class="pane-title display">{item.name}</span></a>' for item in POLICIES]
    return ['  <nav class="panes" aria-label="Privacy policy">', *panes, "  </nav>"]


def guide_panes() -> list[str]:
    panes = []
    for group in (FAQ_PAGES, PLAY_PAGES, GENRE_PAGES):
        english, chinese = group
        panes.append(
            f'    <a class="pane" href="{english.path}">'
            f'<span class="pane-kicker" lang="{chinese.lang}">{chinese.name}</span> '
            f'<span class="pane-title display">{english.name}</span></a>')
    return ['  <nav class="panes" aria-label="About Glassvow">', *panes, "  </nav>"]


def teaser_home(lang: str) -> str:
    twin = "zh-Hant" if lang == "en" else "en"
    index = 0 if lang == "en" else 1
    guides = [(group[index].path, group[index].name) for group in (PLAY_PAGES, FAQ_PAGES, GENRE_PAGES)]
    body = teaser.body(lang, site=SITE, twin=twin, twin_name=LANGUAGE_NAMES[twin], guides=guides,
                       contact=email(CONTACT)) + teaser_footer(lang)
    copy = teaser.COPY[lang]
    return shell(lang=lang, title=copy["title"], description=copy["description"], body=body,
                 canonical=teaser.HOME[lang],
                 alternates=(("en", teaser.HOME["en"]), ("zh-Hant", teaser.HOME["zh-Hant"]),
                             ("x-default", teaser.HOME["en"])),
                 body_class="teaser", preloads=FONT_PRELOADS[: 1 if lang == "en" else 2],
                 head_extra=teaser.HEAD)


def not_found_page() -> str:
    body = [
        '<main class="threshold">',
        '  <a class="brand display" href="/">Glassvow</a>',
        '  <h1 class="lost">Page not found <span lang="zh-Hant">找不到此頁面</span></h1>',
        *guide_panes(),
        *policy_panes(),
        "</main>",
        *company_footer("en"),
    ]
    return shell(lang="en", title="Page not found · Glassvow", body=body,
                 description="There is no page at this address on the Glassvow site.",
                 robots="noindex", body_class="home")


def page_file(path: str) -> str:
    return path.strip("/") + "/index.html" if path.strip("/") else "index.html"


# --- Audit -----------------------------------------------------------------

VOID_TAGS = frozenset({"br", "hr", "img", "input", "link", "meta", "source", "wbr"})
FORBIDDEN_TAGS = frozenset({"script", "style", "iframe", "object", "embed", "form", "base",
                            "noscript"})


class PageAudit(HTMLParser):
    """Structure, CSP and language audit of one page; collects display-face text."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.errors: list[str] = []
        self.open: list[tuple[str, bool]] = []
        self.display: list[str] = []
        self.links: set[str] = set()
        self.seen: Counter[str] = Counter()
        self.lang = self.title = self.description = ""
        self.canonical = self.robots = ""
        self.hreflang: dict[str, str] = {}
        self.json_ld: list[str] = []
        self.og: dict[str, str] = {}
        self.twitter: dict[str, str] = {}
        self.images: list[tuple[str, str, str, str]] = []
        self._json_ld_parts: list[str] | None = None
        self.doctype = False

    def handle_decl(self, decl: str) -> None:
        self.doctype = decl.lower() == "doctype html"

    def _site_path(self, url: str) -> str:
        if url.startswith(ORIGIN) and not url.startswith(ORIGIN + "//"):
            path = url[len(ORIGIN):] or "/"
            return path if path.startswith("/") else "/" + path
        return url

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = {name: value or "" for name, value in attrs}
        self.seen[tag] += 1
        json_ld = (tag == "script" and values.get("type") == "application/ld+json"
                   and "src" not in values)
        # A script file on this site is allowed (CSP script-src 'self'); its body must be empty.
        script_file = tag == "script" and values.get("type") == "module" and "src" in values
        if tag in FORBIDDEN_TAGS and not (json_ld or script_file):
            self.errors.append(f"<{tag}> is not allowed on a script-free, self-only page")
        self.errors += [f"inline {name}= on <{tag}>" for name in values
                        if name == "style" or name.startswith("on")]
        loads = [values["src"]] if "src" in values else []
        if tag == "link" and not set(values.get("rel", "").split()) <= {"canonical", "alternate"}:
            loads.append(values.get("href", ""))
        loads += [part.split()[0] for name in ("srcset", "imagesrcset")
                  for part in values.get(name, "").split(",") if part.strip()]
        loads += [url for name, value in values.items() if name.startswith("data-")
                  for url in value.split() if url.startswith("/")]
        for url in loads:
            if not url.startswith("/") or url.startswith("//"):
                self.errors.append(f"<{tag}> loads {url!r} from outside the site")
            self.links.add(url)
        href = values.get("href", "")
        if tag == "a" and (not href.startswith(("/", "https://", "mailto:")) or href.startswith("//")):
            self.errors.append(f"<a> links to {href!r}")
        elif tag == "a" and href.startswith("/"):
            self.links.add(href)
        if tag == "html":
            self.lang = values.get("lang", "")
        if tag == "link":
            rels = set(values.get("rel", "").split())
            if "canonical" in rels:
                self.canonical = href
            if "alternate" in rels and values.get("hreflang"):
                self.hreflang[values["hreflang"]] = href
        if tag == "meta":
            name, prop, content = values.get("name", ""), values.get("property", ""), values.get("content", "")
            if name == "description":
                self.description = content
            if name == "robots":
                self.robots = content
            if prop.startswith("og:"):
                self.og[prop] = content
            if name.startswith("twitter:"):
                self.twitter[name] = content
            if prop == "og:image" or name == "twitter:image":
                path = self._site_path(content)
                if path.startswith("/"):
                    self.links.add(path)
        if tag == "img":
            alt = values.get("alt") if "alt" in values else None
            if alt == "" and values.get("aria-hidden") == "true":
                alt = "decorative"
            self.images.append((values.get("src", ""), alt or "", values.get("width", ""),
                                values.get("height", "")))
        if json_ld:
            self._json_ld_parts = []
        if tag not in VOID_TAGS:
            display = (tag in ("h1", "h2") or "display" in values.get("class", "").split()
                       or bool(self.open and self.open[-1][1]))
            self.open.append((tag, display))

    def handle_endtag(self, tag: str) -> None:
        if tag == "script" and self._json_ld_parts is not None:
            self.json_ld.append("".join(self._json_ld_parts))
            self._json_ld_parts = None
        if not self.open or self.open[-1][0] != tag:
            expected = f"<{self.open[-1][0]}>" if self.open else "no open element"
            self.errors.append(f"</{tag}> does not close {expected}")
        else:
            self.open.pop()

    def handle_data(self, data: str) -> None:
        if self._json_ld_parts is not None:
            self._json_ld_parts.append(data)
        elif self.open and self.open[-1][0] == "script" and data.strip():
            self.errors.append("inline script")
        if self.open and self.open[-1][0] == "title":
            self.title += data
        if self.open and self.open[-1][1]:
            self.display.append(data)


def disclosure_errors(relative: str, page: str) -> list[str]:
    """Short footer, company page, and 2026 controller/regulator wording."""
    errors = []
    footers = LEGAL_FOOTER.findall(page)
    if page.count('class="legal"') != 1 or len(footers) != 1:
        errors.append("needs exactly one company footer")
        footer = ""
    else:
        footer = footers[0]
        if "© EUGNEL LTD" not in footer:
            errors.append("company footer must show © EUGNEL LTD")
        expected = COMPANY_HREF["zh-Hant"] if "zh-hant" in relative else COMPANY_HREF["en"]
        if f'href="{expected}"' not in footer:
            errors.append("company footer is missing the Company information link")
        if any(item in footer for item in FOOTER_FORBIDDEN):
            errors.append("company footer still carries number, address, email or ICO registration")
    if OLD_CONTROLLER in page:
        errors.append("still names James TO")
    if RETIRED_REGULATOR in page:
        errors.append("uses retired Information Commissioner wording")
    if RETIRED_REGULATOR_ZH in page:
        errors.append("uses retired 資訊專員 wording")
    if relative.startswith("privacy/"):
        required = PRIVACY_ZH_REQUIRED if "zh-hant" in relative else PRIVACY_EN_REQUIRED
        errors.extend(f"missing {item!r}" for item in required if item not in page)
        errors.extend(f"privacy page still carries {item!r}"
                      for item in NOTICE_FORBIDDEN if item in page)
        lowered = page.lower()
        if "application reference" in lowered or "c2062045" in lowered:
            errors.append("ICO registration still uses pending/application wording")
    if relative.startswith("company/"):
        required = COMPANY_ZH_REQUIRED if "zh-hant" in relative else COMPANY_EN_REQUIRED
        errors.extend(f"missing {item!r}" for item in required if item not in page)
        lowered = page.lower()
        if "application reference" in lowered or "c2062045" in lowered:
            errors.append("ICO registration still uses pending/application wording")
    return errors


def slim_source_errors() -> list[str]:
    """Privacy and terms name the controller and email; details live on /company/."""
    errors = []
    for relative in SLIM_SOURCES:
        text = (ROOT / relative).read_text(encoding="utf-8")
        errors.extend(f"{relative} still carries {item!r}"
                      for item in NOTICE_FORBIDDEN if item in text)
    return errors


def audit_page(page: str) -> PageAudit:
    audit = PageAudit()
    audit.feed(page)
    audit.close()
    if audit.open:
        audit.errors.append("unclosed " + ", ".join(f"<{tag}>" for tag, _ in audit.open))
    for problem, failed in (
            ("missing <!DOCTYPE html>", not audit.doctype),
            ("<html> declares no lang", not audit.lang),
            ("needs one non-empty <title>", audit.seen["title"] != 1 or not audit.title.strip()),
            ("needs a meta description", not audit.description.strip()),
            ("needs exactly one <h1>", audit.seen["h1"] != 1)):
        if failed:
            audit.errors.append(problem)
    return audit


def json_ld_errors(data: object, *, require_faq: bool = False,
                   visible_faq: list[tuple[str, str]] | None = None) -> list[str]:
    dumped = json.dumps(data, ensure_ascii=False)
    errors = [f"JSON-LD must not include {needle!r}" for needle in JSONLD_FORBIDDEN
              if needle in dumped]
    nodes = data.get("@graph", [data]) if isinstance(data, dict) else []
    types: set[str] = set()
    for node in nodes:
        if isinstance(node, dict):
            types |= node_types(node)
    for needed in ("VideoGame", "MobileApplication", "Organization"):
        if needed not in types:
            errors.append(f"JSON-LD missing {needed}")
    if require_faq and "FAQPage" not in types:
        errors.append("JSON-LD missing FAQPage")
    for node in nodes:
        if not isinstance(node, dict):
            continue
        if "Organization" in node_types(node):
            if node.get("name") != ORGANIZATION_NAME:
                errors.append("Organization name must be EUGNEL LTD")
            if not str(node.get("url", "")).startswith(ORIGIN):
                errors.append("Organization url missing")
            if node.get("email") != PRIVACY_CONTACT:
                errors.append("Organization email must be hello@eugnel.com")
            extras = {"address", "taxID", "leiCode", "identifier", "legalName"}
            if extras & node.keys():
                errors.append("Organization must not include address or company identifiers")
        if "VideoGame" in node_types(node) and (
                node.get("gamePlatform") != list(teaser.GAME_PLATFORMS)
                or node.get("operatingSystem") != teaser.OPERATING_SYSTEMS
                or node.get("description") != GAME_DESCRIPTION):
            errors.append("VideoGame must name the four platforms and the entity description")
        if "FAQPage" in node_types(node) and visible_faq is not None:
            entities = node.get("mainEntity") if isinstance(node.get("mainEntity"), list) else []
            encoded = []
            for item in entities:
                if not isinstance(item, dict):
                    continue
                answer = item.get("acceptedAnswer")
                text = answer.get("text", "") if isinstance(answer, dict) else ""
                encoded.append((item.get("name", ""), text))
            if encoded != visible_faq:
                errors.append("FAQPage Q/A must match visible questions and first answers")
    return errors


def seo_errors(relative: str, audit: PageAudit, page: str = "") -> list[str]:
    """Title/description bounds, canonical, hreflang, JSON-LD. 404 is noindex only."""
    errors = []
    low, high = TITLE_BOUNDS
    if not low <= len(audit.title.strip()) <= high:
        errors.append(f"title length {len(audit.title.strip())} not in {low}-{high}")
    low, high = DESCRIPTION_BOUNDS
    if not low <= len(audit.description.strip()) <= high:
        errors.append(f"description length {len(audit.description.strip())} not in {low}-{high}")
    for src, alt, width, height in audit.images:
        if not alt.strip():
            errors.append(f"img {src!r} missing alt")
        if not width or not height:
            errors.append(f"img {src!r} missing width or height")
    if relative == "404.html":
        if "noindex" not in {part.strip() for part in audit.robots.split(",")}:
            errors.append("404 needs noindex")
        if audit.canonical:
            errors.append("404 must not have a canonical")
        return errors
    expected = page_url("/" if relative == "index.html"
                        else "/" + relative[: -len("index.html")] if relative.endswith("/index.html")
                        else "/" + relative)
    if audit.canonical != expected:
        errors.append(f"canonical {audit.canonical!r} != {expected!r}")
    if set(audit.hreflang) != {"en", "zh-Hant", "x-default"}:
        errors.append("hreflang must declare en, zh-Hant and x-default")
    errors.extend(f"hreflang {code} is not on {ORIGIN}"
                  for code, href in audit.hreflang.items() if not href.startswith(ORIGIN))
    if len(audit.json_ld) != 1:
        errors.append("needs exactly one JSON-LD block")
    else:
        try:
            data = json.loads(audit.json_ld[0])
        except json.JSONDecodeError:
            errors.append("JSON-LD does not parse")
        else:
            require_faq = relative.startswith("faq/")
            errors.extend(json_ld_errors(
                data, require_faq=require_faq,
                visible_faq=visible_faq_pairs(page) if require_faq else None))
    for key in ("og:title", "og:description", "og:url", "og:type", "og:image"):
        if key not in audit.og:
            errors.append(f"missing {key}")
    if audit.og.get("og:url") != audit.canonical:
        errors.append("og:url must match canonical")
    return errors


def robots_txt() -> bytes:
    lines = ["User-agent: *", "Allow: /", ""]
    for bot in AI_BOTS:
        lines += [f"User-agent: {bot}", "Allow: /", ""]
    lines += [f"Sitemap: {ORIGIN}/sitemap.xml", ""]
    return "\n".join(lines).encode()


def robots_has_sitemap(text: str) -> bool:
    return f"Sitemap: {ORIGIN}/sitemap.xml" in text


def robots_allows_bots(text: str) -> bool:
    return all(f"User-agent: {bot}" in text and "Allow: /" in text for bot in AI_BOTS)


def llms_txt() -> bytes:
    values = load_entity()
    links = [
        ("Home", "/"),
        ("Home (zh-Hant)", "/zh-hant/"),
        ("FAQ", "/faq/"),
        ("FAQ (zh-Hant)", "/faq/zh-hant/"),
        ("How to play", "/play/"),
        ("How to play (zh-Hant)", "/play/zh-hant/"),
        ("A roguelite deckbuilder", "/genre/"),
        ("Roguelike 牌組構築", "/genre/zh-hant/"),
        ("Privacy policy", "/privacy/"),
        ("Privacy policy (zh-Hant)", "/privacy/zh-hant/"),
        ("Company information", "/company/"),
        ("Company information (zh-Hant)", "/company/zh-hant/"),
    ]
    lines = [
        f"# {values['game_en']}",
        "",
        values["short_en"],
        values["short_zh"],
        "",
        f"Developer: {values['developer']}",
        f"Site: {values['url']}/",
        f"Support: {values['support_email']}",
        f"Privacy: {values['privacy_email']}",
        "",
        "## Pages",
        *(f"- {label}: {page_url(path)}" for label, path in links),
        "",
    ]
    return "\n".join(lines).encode()


def llms_errors(text: str) -> list[str]:
    required = (
        GAME_NAME, GAME_ALTERNATE_NAME, ORGANIZATION_NAME, GAME_DESCRIPTION, GAME_DESCRIPTION_ZH,
        page_url("/"), page_url("/zh-hant/"), page_url("/faq/"), page_url("/play/"), page_url("/genre/"),
        page_url("/privacy/"), page_url("/company/"),
        page_url("/faq/zh-hant/"), page_url("/play/zh-hant/"),
        page_url("/genre/zh-hant/"), page_url("/privacy/zh-hant/"),
        page_url("/company/zh-hant/"), CONTACT, PRIVACY_CONTACT,
    )
    errors = [f"llms.txt missing {item!r}" for item in required if item not in text]
    errors.extend(f"llms.txt still carries {item!r}" for item in NOTICE_FORBIDDEN if item in text)
    return errors


def sitemap_xml(indexable: list[tuple[str, dict[str, str]]]) -> bytes:
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"',
        '        xmlns:xhtml="http://www.w3.org/1999/xhtml">',
    ]
    for loc, alts in sorted(indexable):
        lines += ["  <url>", f"    <loc>{html.escape(loc)}</loc>"]
        lines += [f'    <xhtml:link rel="alternate" hreflang="{html.escape(code)}" '
                  f'href="{html.escape(href)}"/>' for code, href in sorted(alts.items())]
        lines.append("  </url>")
    lines += ["</urlset>", ""]
    return "\n".join(lines).encode()


def sitemap_locs(payload: bytes) -> set[str]:
    root = ET.fromstring(payload)
    ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    return {el.text or "" for el in root.findall("sm:url/sm:loc", ns)}


# --- Build and check -------------------------------------------------------

def render_pages(group: tuple[Policy, ...]) -> dict[str, str]:
    pages: dict[str, str] = {}
    for index, page in enumerate(group):
        try:
            source = (ROOT / page.source).read_text(encoding="utf-8")
            if OLD_CONTROLLER in source:
                raise BuildError(f"still names {OLD_CONTROLLER}")
            if RETIRED_REGULATOR in source or RETIRED_REGULATOR_ZH in source:
                raise BuildError("uses retired Information Commissioner wording")
            article = render_markdown(source, page.lang)
            faq = tuple(faq_pairs(source)) if page.kind == "faq" else ()
        except BuildError as error:
            raise BuildError(f"{page.source}: {error}") from None
        pages[page_file(page.path)] = article_page(
            page, group[1 - index], article, group, faq=faq)
    return pages


def build() -> tuple[dict[str, bytes], set[str], str]:
    """Return site/ outputs, the site paths they reference and the display corpus."""
    slim = slim_source_errors()
    if slim:
        raise BuildError("; ".join(slim))
    drifted = entity_errors()
    if drifted:
        raise BuildError("; ".join(drifted))
    pages: dict[str, str] = {}
    for group in PAGE_GROUPS:
        pages.update(render_pages(group))
    try:
        teasers = {lang: page_file(path) for lang, path in teaser.HOME.items()}
        pages.update({relative: teaser_home(lang) for lang, relative in teasers.items()})
    except teaser.MediaError as error:
        raise BuildError(str(error)) from None
    pages["404.html"] = not_found_page()
    links: set[str] = set()
    corpus: set[str] = set()
    indexable: list[tuple[str, dict[str, str]]] = []
    for relative, page in pages.items():
        audit = audit_page(page)
        audit.errors.extend(disclosure_errors(relative, page))
        audit.errors.extend(seo_errors(relative, audit, page))
        audit.errors.extend(platform_errors(relative, page, audit.lang))
        for lang in (lang for lang, path in teasers.items() if path == relative):
            audit.errors += teaser_footer_errors(page, lang) + teaser.page_errors(page, lang)
        if audit.errors:
            raise BuildError(f"site/{relative}: " + "; ".join(audit.errors))
        links |= audit.links
        corpus |= set(CJK.findall("".join(audit.display)))
        if relative != "404.html":
            indexable.append((audit.canonical, dict(audit.hreflang)))
    outputs = {relative: page.encode("utf-8") for relative, page in pages.items()}
    outputs.update({target: (ROOT / source).read_bytes() for target, source in COPIES.items()})
    outputs["robots.txt"] = robots_txt()
    outputs["sitemap.xml"] = sitemap_xml(indexable)
    outputs["llms.txt"] = llms_txt()
    llms = llms_errors(outputs["llms.txt"].decode())
    if llms:
        raise BuildError("; ".join(llms))
    return outputs, links, "".join(sorted(corpus))


def stale_paths(site: Path, outputs: dict[str, bytes]) -> list[str]:
    return [f"{'STALE' if (site / relative).is_file() else 'MISSING'} site/{relative}"
            for relative, content in sorted(outputs.items())
            if not (site / relative).is_file() or (site / relative).read_bytes() != content]


CSS_URL = re.compile(r"""url\(\s*["']?([^"')]+)""")
CSS_EXTERNAL = re.compile(r"@import|url\(\s*[\"']?\s*(?:[a-z][a-z0-9+.-]*:|//)", re.IGNORECASE)


SCRIPT_UNSAFE = re.compile(r"[a-z][a-z0-9+.-]*://|\beval\s*\(|\bFunction\s*\(|document\.write",
                           re.IGNORECASE)
CSP_REQUIRED = ("default-src 'none'", "script-src 'self'", "media-src 'self'", "base-uri 'none'")
CSP_UNSAFE = re.compile(r"unsafe-|https?:|\*|data:|blob:|\bnonce-|\bsha\d+-")


def script_problems(relative: str, source: str) -> list[str]:
    """The teaser script may reach only this site and never evaluates strings."""
    return [f"UNSAFE site/{relative}: {match.group(0)}" for match in SCRIPT_UNSAFE.finditer(source)]


def csp_problems(headers: str) -> list[str]:
    policies = re.findall(r"Content-Security-Policy: (.*)", headers)
    if len(policies) != 1:
        return ["CSP site/_headers needs exactly one Content-Security-Policy"]
    problems = [f"CSP lacks {item}" for item in CSP_REQUIRED if item not in policies[0]]
    return problems + [f"CSP admits {match.group(0)!r}" for match in CSP_UNSAFE.finditer(policies[0])]


def reference_problems(site: Path, links: set[str]) -> list[str]:
    problems, targets = [], {url.split("#")[0].split("?")[0] for url in links}
    for sheet in (STYLESHEET, *(sheet.lstrip("/") for sheet in teaser.STYLESHEETS)):
        if not (site / sheet).is_file():
            continue  # reported as DANGLING below
        css = (site / sheet).read_text(encoding="utf-8")
        problems += [f"EXTERNAL site/{sheet}: {match.group(0)}" for match in CSS_EXTERNAL.finditer(css)]
        targets |= {"/" + str(Path(sheet).parent / url) for url in CSS_URL.findall(css)
                    if not CSS_EXTERNAL.match(f"url({url})")}
    # The home page's own modules; vendored scripts are pinned by digest instead.
    for path in sorted((site / "assets").glob("story*.js")):
        script = str(path.relative_to(site))
        problems += script_problems(script, path.read_text(encoding="utf-8"))
    problems += teaser.vendor_problems(site)
    if (site / "_headers").is_file():
        problems += csp_problems((site / "_headers").read_text(encoding="utf-8"))
    for url in sorted(targets):
        path = site / (page_file(url) if url.endswith("/") else url.lstrip("/"))
        if not path.is_file():
            problems.append(f"DANGLING {url} (no site/{path.relative_to(site)})")
    return problems


def display_font_problems(site: Path, corpus: str) -> list[str]:
    try:
        manifest = json.loads((site / DISPLAY_MANIFEST).read_text(encoding="utf-8"))
        digest = hashlib.sha256((site / DISPLAY_FONT).read_bytes()).hexdigest()
    except (OSError, ValueError) as error:
        return [f"DISPLAY_FONT unreadable: {error}"]
    problems = []
    if digest != manifest.get("woff2_sha256"):
        problems.append(f"DISPLAY_FONT site/{DISPLAY_FONT} does not match its manifest")
    missing = "".join(char for char in corpus if char not in manifest.get("text", ""))
    if missing:
        problems.append(f"DISPLAY_GLYPHS the zh-Hant heading face lacks: {missing}")
    return problems


def write_outputs(site: Path, outputs: dict[str, bytes]) -> None:
    for relative, content in outputs.items():
        path = site / relative
        if not path.is_file() or path.read_bytes() != content:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)


def write_display_font(corpus: str) -> None:
    spec = importlib.util.spec_from_file_location("subset_noto_serif_tc",
                                                  ROOT / "tools/subset_noto_serif_tc.py")
    fonts = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fonts)
    pyftsubset = shutil.which("pyftsubset")
    if pyftsubset is None:
        raise BuildError("pyftsubset is not on PATH; bootstrap FontTools as "
                         "tools/subset_noto_serif_tc.py describes")
    source_dir = fonts.DEFAULT_SOURCE_DIR
    try:
        source_dir.mkdir(parents=True, exist_ok=True)
    except OSError:
        source_dir = Path("/tmp/glassvow-noto-serif-tc-sources")
    source = fonts.ensure_cjk_sources(source_dir)["SemiBold"]
    fonts.subset(pyftsubset, source, corpus, SITE / DISPLAY_FONT)
    manifest = {
        "source": f"{source.name} from {fonts.CJK_ARCHIVE_URL}",
        "source_sha256": fonts.CJK_SOURCES["SemiBold"][1],
        "text": corpus,
        "woff2_sha256": hashlib.sha256((SITE / DISPLAY_FONT).read_bytes()).hexdigest(),
    }
    (SITE / DISPLAY_MANIFEST).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


# --- Self-test -------------------------------------------------------------

REJECTED_MARKDOWN = (
    ("unfilled placeholder", "# T\n\nWrite to [contact email].\n"),
    ("draft comment", "<!-- DRAFT -->\n\n# T\n"),
    ("table", "# T\n\n| a | b |\n"),
    ("code fence", "# T\n\n```\nx\n```\n"),
    ("raw HTML", "# T\n\n<b>x</b>\n"),
    ("unbalanced emphasis", "# T\n\n*open\n"),
    ("level-3 heading", "# T\n\n### Deeper\n"),
    ("unsafe link", "# T\n\n[x](javascript:void)\n"),
    ("text before the title", "Intro.\n\n# T\n"),
)
SAMPLES = (
    ("en", "# Title\n\n*Updated*\n\nGlassvow (琉璃誓言) & **you**: see [policy]"
           "(https://example.com/a?b=1&c=2), mail a@b.co.\n\n## 1. Part\n\n- one\n- two\n",
     ["<article>", "  <h1>Title</h1>", "  <p><em>Updated</em></p>",
      '  <p>Glassvow (<span lang="zh-Hant">琉璃誓言</span>) &amp; <strong>you</strong>: see '
      '<a href="https://example.com/a?b=1&amp;c=2">policy</a>, mail '
      "<!--email_off-->a@b.co<!--/email_off-->.</p>",
      "  <section>", "    <h2>1. Part</h2>", "    <ul>", "      <li>one</li>",
      "      <li>two</li>", "    </ul>", "  </section>", "</article>"]),
    ("zh-Hant", "# 標題\n\n**簡而言之：** 遊戲。 Sentry 會\n",
     ["<article>", "  <h1>標題</h1>", "  <p><strong>簡而言之：</strong>遊戲。Sentry 會</p>",
      "</article>"]),
)


def self_test() -> int:
    failures: list[str] = []
    seeded: list[str] = []

    def expect(label: str, rejected: Callable[[], bool]) -> None:
        try:
            caught = rejected()
        except BuildError:
            caught = True
        seeded.append(label)
        print(f"self-test {label}: {'rejected' if caught else 'ACCEPTED'}")
        if not caught:
            failures.append(label)

    for label, source in REJECTED_MARKDOWN:
        expect(label, lambda source=source: not render_markdown(source, "en"))
    failures += [f"{lang} sample render" for lang, source, expected in SAMPLES
                 if render_markdown(source, lang) != expected]
    good = shell(lang="en", title="T", description="D", body=["<main><h1>T</h1></main>"])
    failures += ["clean page audit"] if audit_page(good).errors else []
    for label, page in (
            ("unclosed tag", good.replace("</main>", "")),
            ("inline style", good.replace("<main>", '<main style="color:red">')),
            ("script", good.replace("<main>", "<main><script></script>")),
            ("inline module script", good.replace("<main>", '<main><script type="module">go()</script>')),
            ("third-party script", good.replace(
                "<main>", '<main><script type="module" src="https://cdn.example/a.js"></script>')),
            ("off-site srcset", good.replace(
                "<main>", '<main><img src="/a.webp" srcset="https://cdn.example/a.webp 2x" alt="A">')),
            ("third-party stylesheet", good.replace(f'href="/{STYLESHEET}"', 'href="https://cdn.example/a.css"')),
            ("missing lang", good.replace(' lang="en"', ""))):
        expect(label, lambda page=page: bool(audit_page(page).errors))
    expect("script reaches off-site", lambda: bool(script_problems("a.js", 'fetch("https://t.example")')))
    expect("script evaluates strings", lambda: bool(script_problems("a.js", "eval(code)")))
    policy = "Content-Security-Policy: " + "; ".join(CSP_REQUIRED)
    failures += ["clean CSP"] if csp_problems(policy) else []
    expect("CSP unsafe-inline", lambda: bool(csp_problems(policy + "; style-src 'unsafe-inline'")))
    expect("CSP without script-src", lambda: bool(csp_problems(policy.replace("script-src 'self'", ""))))

    indexed = shell(
        lang="en", title="Glassvow policy page",
        description="Glassvow privacy notes for iPhone and iPad players and support.",
        body=["<main><h1>T</h1></main>"], canonical="/privacy/",
        alternates=(("en", "/privacy/"), ("zh-Hant", "/privacy/zh-hant/"),
                    ("x-default", "/privacy/")))
    failures += ["indexable seo"] if seo_errors("privacy/index.html", audit_page(indexed)) else []
    expect("title too long", lambda: any("title length" in item for item in seo_errors(
        "privacy/index.html", audit_page(indexed.replace(
            "<title>Glassvow policy page</title>", f"<title>{'G' * 80}</title>")))))
    expect("missing canonical", lambda: any("canonical" in item for item in seo_errors(
        "privacy/index.html", audit_page(indexed.replace(
            f'<link rel="canonical" href="{ORIGIN}/privacy/">', "")))))
    expect("hreflang pair", lambda: any("hreflang" in item for item in seo_errors(
        "privacy/index.html", audit_page(indexed.replace(
            'hreflang="zh-Hant"', 'hreflang="fr"')))))
    expect("json-ld parse", lambda: any("JSON-LD does not parse" in item for item in seo_errors(
        "privacy/index.html", audit_page(indexed.replace(
            '<script type="application/ld+json">',
            '<script type="application/ld+json">{', 1)))))
    expect("json-ld company number", lambda: any(COMPANY_NUMBER in item for item in json_ld_errors(
        {"@graph": [{"@type": "Organization", "name": ORGANIZATION_NAME,
                     "url": f"{ORIGIN}/", "email": PRIVACY_CONTACT, "taxID": COMPANY_NUMBER},
                    {"@type": ["VideoGame", "MobileApplication"]}]})))
    expect("json-ld missing email", lambda: any("email" in item for item in json_ld_errors(
        {"@graph": [{"@type": "Organization", "name": ORGANIZATION_NAME, "url": f"{ORIGIN}/"},
                    {"@type": ["VideoGame", "MobileApplication"]}]})))
    expect("faq qa mismatch", lambda: any("FAQPage Q/A" in item for item in json_ld_errors(
        {"@graph": [
            {"@type": ["VideoGame", "MobileApplication"]},
            {"@type": "Organization", "name": ORGANIZATION_NAME,
             "url": f"{ORIGIN}/", "email": PRIVACY_CONTACT},
            {"@type": "FAQPage", "mainEntity": [
                {"@type": "Question", "name": "Q",
                 "acceptedAnswer": {"@type": "Answer", "text": "A"}}]}]},
        require_faq=True, visible_faq=[("Q", "B")])))
    expect("robots missing sitemap", lambda: not robots_has_sitemap("User-agent: *\nAllow: /\n"))
    expect("robots missing AI bot", lambda: not robots_allows_bots(
        f"User-agent: *\nAllow: /\nSitemap: {ORIGIN}/sitemap.xml\n"))
    expect("sitemap omission", lambda: page_url("/") not in sitemap_locs(sitemap_xml([])))
    expect("llms missing faq", lambda: any("/faq/" in item for item in llms_errors("# Glassvow\n")))

    outputs, links, corpus = build()
    with tempfile.TemporaryDirectory(prefix="glassvow-site-") as temporary:
        site = Path(temporary)
        write_outputs(site, outputs)
        (site / STYLESHEET).write_text("@import url(https://fonts.example/css);\n", encoding="utf-8")
        (site / "index.html").write_bytes(b"stale")
        (site / "404.html").unlink()
        (site / DISPLAY_FONT).write_bytes(b"font")
        (site / DISPLAY_MANIFEST).write_text(json.dumps(
            {"text": corpus[:-1], "woff2_sha256": hashlib.sha256(b"other").hexdigest()}), encoding="utf-8")
        media = teaser.load_manifest(SITE)
        drifted = next(iter(media))
        media[drifted] = {**media[drifted], "source_sha256": "0" * 64}
        (site / teaser.MANIFEST).parent.mkdir(parents=True, exist_ok=True)
        (site / teaser.MANIFEST).write_text(json.dumps({"outputs": media}), encoding="utf-8")
        (site / teaser.MEDIA_DIR / "stray.webp").write_bytes(b"stray")
        stale = stale_paths(site, outputs)
        references = reference_problems(site, links)
        font = display_font_problems(site, corpus)
        media_found = teaser.media_problems(site)
    expect("stale page", lambda: "STALE site/index.html" in stale)
    expect("missing page", lambda: "MISSING site/404.html" in stale)
    expect("third-party CSS import", lambda: any(item.startswith("EXTERNAL") for item in references))
    expect("dangling link", lambda: any(item.startswith("DANGLING /assets/icon.png") for item in references))
    expect("display font drift", lambda: any(item.startswith("DISPLAY_FONT") for item in font))
    expect("missing display glyph", lambda: any(corpus[-1] in item for item in font))
    expect("media source drift", lambda: any(item.startswith("MEDIA_SOURCE") and drifted in item
                                             for item in media_found))
    expect("unlisted media", lambda: any(item.startswith("MEDIA_UNLISTED") for item in media_found))

    def glb(doc: dict, blob: bytes, bin_type: int = 0x004E4942) -> bytes:
        text = json.dumps(doc).encode("utf-8")
        text += b" " * (-len(text) % 4)
        body = struct.pack("<II", len(text), 0x4E4F534A) + text + struct.pack("<II", len(blob), bin_type) + blob
        return struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body

    model = {"buffers": [{"byteLength": 20}], "images": [{"bufferView": 1, "mimeType": "image/jpeg"}],
             "bufferViews": [{"buffer": 0, "byteLength": 8}, {"buffer": 0, "byteOffset": 8, "byteLength": 6},
                             {"buffer": 0, "byteOffset": 16, "byteLength": 4}],
             "accessors": [{"bufferView": 0}, {"bufferView": 2, "sparse": {"indices": {"bufferView": 2},
                                                                         "values": {"bufferView": 0}}}]}
    packed, skin = teaser.split_glb(glb(model, b"geometry" + b"SKIN!!\0\0" + b"tail"), "x-skin.jpg")
    packed_doc = json.loads(packed[20:20 + struct.unpack_from("<I", packed, 12)[0]])
    if (skin != b"SKIN!!" or not packed.endswith(b"geometrytail") or b"SKIN" in packed
            or packed_doc["images"] != [{"uri": "x-skin.jpg"}] or packed_doc["buffers"] != [{"byteLength": 12}]
            or [view.get("byteOffset", 0) for view in packed_doc["bufferViews"]] != [0, 8]
            or packed_doc["accessors"][1] != {"bufferView": 1, "sparse": {"indices": {"bufferView": 1},
                                                                          "values": {"bufferView": 0}}}):
        failures.append("GLB repack keeps the embedded skin or misplaces a buffer view")

    def glb_rejected(data: bytes) -> bool:
        try:
            teaser.split_glb(data, "x-skin.jpg")
        except teaser.MediaError:
            return True
        return False

    expect("GLB without a BIN chunk", lambda: glb_rejected(glb(model, bytes(20), bin_type=0x4E4F534A)))
    expect("GLB accessor reading the skin", lambda: glb_rejected(glb(
        {**model, "accessors": [{"bufferView": 1}]}, bytes(20))))
    short_footer = ('<footer class="legal"><p>© EUGNEL LTD · '
                    '<a href="/company/">Company information</a></p></footer>')
    expect("missing company footer",
           lambda: "needs exactly one company footer" in disclosure_errors("index.html", "<html></html>"))
    expect("full company footer",
           lambda: "company footer still carries number, address, email or ICO registration"
           in disclosure_errors(
               "index.html",
               '<footer class="legal"><p>© EUGNEL LTD · Company no. 17505169 · '
               f'{REGISTERED_OFFICE} {ICO_NUMBER} {PRIVACY_CONTACT} · '
               '<a href="/company/">Company information</a></p></footer>'))
    expect("footer missing company page",
           lambda: "company footer is missing the Company information link" in disclosure_errors(
               "index.html", '<footer class="legal"><p>© EUGNEL LTD</p></footer>'))
    expect("privacy still has company number",
           lambda: any("17505169" in item for item in disclosure_errors(
               "privacy/index.html",
               ("EUGNEL LTD hello@eugnel.com https://ico.org.uk/make-a-complaint/ "
                "within 30 days without undue delay complain to us first "
                "Information Commission (ICO) company no. 17505169" + short_footer))))
    expect("company page missing ICO",
           lambda: any(ICO_NUMBER in item for item in disclosure_errors(
               "company/index.html",
               ("EUGNEL LTD registered in England &amp; Wales company no. 17505169 "
                f"{REGISTERED_OFFICE} {PRIVACY_CONTACT}" + short_footer))))
    expect("old controller name",
           lambda: "still names James TO" in disclosure_errors(
               "privacy/index.html", f"{short_footer} James TO"))
    expect("retired regulator wording",
           lambda: any("Information Commissioner" in item for item in disclosure_errors(
               "privacy/index.html", f"{short_footer} Information Commissioner's Office")))
    html_pages = {rel: text.decode("utf-8") for rel, text in outputs.items() if rel.endswith(".html")}
    teasers = {"en": html_pages["index.html"], "zh-Hant": html_pages["zh-hant/index.html"]}
    if any(teaser_footer_errors(page, lang) + teaser.page_errors(page, lang) for lang, page in teasers.items()):
        failures.append("built teaser pages fail their own rules")
    four, game = teaser.platform_list("en"), structured_data(lang="en", title="T", description="D", canonical="/")
    game["@graph"][1]["gamePlatform"] = list(teaser.GAME_PLATFORMS[:-1])
    expect("json-ld platform drift", lambda: any("four platforms" in item for item in json_ld_errors(game)))
    expect("guide platform drift", lambda: bool(platform_errors(
        "faq/index.html", html_pages["faq/index.html"].replace(four, "iOS (App Store)"), "en")))
    expect("iOS-only wording", lambda: bool(platform_errors(
        "genre/index.html", html_pages["genre/index.html"] + "for iPhone and iPad", "en")))
    expect("llms missing platforms", lambda: bool(llms_errors(
        outputs["llms.txt"].decode().replace(teaser.platform_list("zh-Hant"), "iOS"))))
    en, privacy = teasers["en"], f'<a href="{teaser.PRIVACY["en"]}">'
    coming = f'<span class="platform-soon">{teaser.COPY["en"]["coming"]}</span>'
    for label, check, page in (
            ("teaser footer extra link", teaser_footer_errors, en.replace(
                privacy, f'<a href="/terms/">Terms</a> · {privacy}')),
            ("teaser footer unlinked ©", teaser_footer_errors, en.replace(
                '<a href="/company/">© EUGNEL LTD</a>', "© EUGNEL LTD")),
            ("teaser footer wrong company page", teaser_footer_errors, en.replace(
                '<a href="/company/">', f'<a href="{COMPANY_HREF["zh-Hant"]}">')),
            ("teaser footer missing privacy", teaser_footer_errors, en.replace(
                f' · {privacy}{teaser.COPY["en"]["privacy"]}</a>', "")),
            ("teaser missing support", teaser_footer_errors, en.replace(CONTACT, "help@example.com")),
            ("fake store link", teaser.page_errors, en.replace(coming, f'<a href="/">{coming}</a>', 1)),
            ("missing Steam", teaser.page_errors, en.replace(">Steam<", ">Itch<", 1)),
            ("autoplay", teaser.page_errors, en.replace("<main", '<audio autoplay src="/a.ogg"></audio><main')),
            ("sound on by default", teaser.page_errors, en.replace(
                'type="button" aria-pressed="false"', 'type="button" aria-pressed="true"')),
            ("release date", teaser.page_errors, en.replace("</h1>", "</h1><p>Spring 2027</p>")),
            ("price", teaser.page_errors, en.replace("</h1>", "</h1><p>$4.99</p>")),
            ("rating", teaser.page_errors, en.replace("</h1>", "</h1><p>★★★★★</p>")),
            ("missing language switch", teaser.page_errors, en.replace('class="switch"', 'class="toggle"'))):
        expect(label, lambda check=check, page=page: bool(check(page, "en")))
    if "company/index.html" not in outputs or "company/zh-hant/index.html" not in outputs:
        failures.append("company pages were not built")
    if any(disclosure_errors(rel, page) for rel, page in html_pages.items()):
        failures.append("built pages fail the company/privacy disclosure contract")
    if any(seo_errors(rel, audit_page(page), page) for rel, page in html_pages.items()):
        failures.append("built pages fail the SEO contract")
    if not robots_has_sitemap(outputs["robots.txt"].decode()):
        failures.append("robots missing sitemap")
    if not robots_allows_bots(outputs["robots.txt"].decode()):
        failures.append("robots missing AI bots")
    if llms_errors(outputs["llms.txt"].decode()):
        failures.append("llms.txt is incomplete")
    if entity_errors():
        failures.append("public entity drifted")
    if "faq/index.html" not in outputs or "play/index.html" not in outputs:
        failures.append("AIO pages were not built")
    expected_locs = {audit_page(page).canonical for rel, page in html_pages.items()
                     if rel != "404.html"}
    if sitemap_locs(outputs["sitemap.xml"]) != expected_locs:
        failures.append("sitemap does not list every indexable page")
    if any(path.endswith("404.html") or path.rstrip("/").endswith("404")
           for path in sitemap_locs(outputs["sitemap.xml"])):
        failures.append("sitemap lists 404")
    if slim_source_errors():
        failures.append("privacy or terms still carry company number, address or ICO registration")
    if failures:
        print(f"site self-test FAILED: {', '.join(failures)}", file=sys.stderr)
        return 1
    print(f"site self-test OK ({len(seeded)} seeded defects rejected; samples rendered exactly)")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="exit 1 when site/ is stale")
    mode.add_argument("--self-test", action="store_true", help="prove that each check can fail")
    mode.add_argument("--display-font", action="store_true",
                      help="re-subset the zh-Hant heading face (needs pyftsubset)")
    mode.add_argument("--media", action="store_true",
                      help="re-encode the teaser's art and sound (needs Pillow with AVIF, ffmpeg)")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    try:
        if args.media:
            teaser.encode_media(SITE)
        outputs, links, corpus = build()
        if args.display_font:
            write_display_font(corpus)
        if not args.check:
            write_outputs(SITE, outputs)
        problems = (stale_paths(SITE, outputs) + reference_problems(SITE, links)
                    + display_font_problems(SITE, corpus) + teaser.media_problems(SITE))
    except (BuildError, OSError, teaser.MediaError, subprocess.CalledProcessError) as error:
        print(f"site build FAILED: {error}", file=sys.stderr)
        return 1
    if problems:
        print(f"site {'check' if args.check else 'build'} FAILED; run python3 tools/build_site.py "
              "(with --display-font for DISPLAY_* issues, --media for MEDIA_* issues)\n"
              + "\n".join(problems), file=sys.stderr)
        return 1
    print(f"site {'is current' if args.check else 'written'}: {len(outputs)} files; "
          f"the zh-Hant heading face covers all {len(corpus)} display characters")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

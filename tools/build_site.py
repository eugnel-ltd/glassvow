#!/usr/bin/env python3
"""Build the public site in site/ from Markdown.

docs/privacy/privacy-policy.en.md and privacy-policy.zh-Hant.md become
/privacy/ and /privacy/zh-hant/; docs/legal/company-information.en.md and
.zh-Hant.md become /company/ and /company/zh-hant/. A deliberately small
reader accepts `#` and `##` headings, paragraphs, `-` lists, links, **strong**
and *emphasis*. Anything else, an unfilled [placeholder] or the draft HTML
comment stops the build. Every page is then audited: balanced tags, a language,
a title and a description, internal links that exist, no inline code and
nothing loaded from another origin, because site/_headers serves a self-only
Content-Security-Policy. The per-page footer is © EUGNEL LTD plus a link to
the Company information page; statutory details live only on that page.

    python3 tools/build_site.py                 write site/
    python3 tools/build_site.py --check         exit 1 when site/ is stale
    python3 tools/build_site.py --self-test     prove that each check can fail
    python3 tools/build_site.py --display-font  re-subset the zh-Hant heading face

Only --display-font needs more than the standard library: it reuses the pinned
Noto sources and pyftsubset of tools/subset_noto_serif_tc.py.
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
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Callable

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
NOTICE_FORBIDDEN = (COMPANY_NUMBER, REGISTERED_OFFICE, ICO_NUMBER)
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


POLICIES = (
    Policy("en", "docs/privacy/privacy-policy.en.md", "/privacy/", "Privacy policy", "Glassvow",
           "What Glassvow, a card game for iPhone and iPad, handles: no accounts, "
           "advertising or analytics tools; saved games stay on your device; technical "
           "crash and error reports go to one service provider, Sentry."),
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
           "EUGNEL LTD 公司資料：英格蘭及威爾斯註冊、公司編號、註冊辦事處、聯絡及 ICO 登記。"),
)

# Copied byte for byte, so the game's own files stay the single source.
COPIES = {
    "assets/fonts/Cinzel-700.woff2": "assets/fonts/Cinzel-700.woff2",
    "assets/fonts/OFL-Cinzel.txt": "assets/fonts/OFL-Cinzel.txt",
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

def shell(*, lang: str, title: str, description: str, body: list[str],
          canonical: str | None = None, alternates: tuple[tuple[str, str], ...] = (),
          body_class: str | None = None) -> str:
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
    if canonical:
        head.append(f'<link rel="canonical" href="{ORIGIN}{canonical}">')
    head += [f'<link rel="alternate" hreflang="{code}" href="{ORIGIN}{path}">'
             for code, path in alternates]
    head += [
        '<link rel="icon" href="/assets/icon.png" type="image/png">',
        f'<link rel="stylesheet" href="/{STYLESHEET}">',
        "</head>",
        f'<body class="{body_class}">' if body_class else "<body>",
    ]
    return "\n".join(head + body + ["</body>", "</html>", ""])


def company_footer(lang: str = "en") -> list[str]:
    href = COMPANY_HREF[lang]
    label = html.escape(COMPANY_LABEL[lang])
    return ['<footer class="legal">', f'  <p>© EUGNEL LTD · <a href="{href}">{label}</a></p>',
            "</footer>"]


def article_page(page: Policy, twin: Policy, article: list[str],
                 group: tuple[Policy, ...]) -> str:
    bar = [f'  <a class="brand display" href="/">{page.brand}</a>',
           f'  <a class="switch" href="{twin.path}" hreflang="{twin.lang}" '
           f'lang="{twin.lang}">{LANGUAGE_NAMES[twin.lang]}</a>']
    body = (['<header class="masthead">', *bar, "</header>", "<main>"]
            + [f"  {line}" for line in article]
            + ["</main>", '<footer class="colophon">', *bar, "</footer>"]
            + company_footer(page.lang))
    alternates = tuple((item.lang, item.path) for item in group)
    return shell(lang=page.lang, title=f"{page.name} · {page.brand}",
                 description=page.description, body=body, canonical=page.path,
                 alternates=alternates + (("x-default", group[0].path),))


def policy_panes() -> list[str]:
    panes = [f'    <a class="pane" href="{item.path}" hreflang="{item.lang}" lang="{item.lang}">'
             f'<span class="pane-kicker">{LANGUAGE_NAMES[item.lang]}</span> '
             f'<span class="pane-title display">{item.name}</span></a>' for item in POLICIES]
    return ['  <nav class="panes" aria-label="Privacy policy">', *panes, "  </nav>"]


def home_page() -> str:
    body = [
        '<main class="threshold">',
        '  <h1 class="title"><span class="title-en">Glassvow</span> '
        '<span class="title-zh" lang="zh-Hant">琉璃誓言</span></h1>',
        '  <p class="lede">A single-player card game for iPhone and iPad.</p>',
        '  <p class="lede" lang="zh-Hant">一款供 iPhone 及 iPad 使用的單人卡牌遊戲。</p>',
        *policy_panes(),
        '  <p class="support">Support · <span lang="zh-Hant">支援</span></p>',
        f'  <p class="address">{email(CONTACT)}</p>',
        "</main>",
        *company_footer("en"),
    ]
    return shell(lang="en", title="Glassvow · 琉璃誓言", body=body, canonical="/",
                 description="Glassvow (琉璃誓言), a single-player card game for iPhone and "
                             "iPad: its privacy policy in English and 繁體中文, and support.",
                 body_class="home")


def not_found_page() -> str:
    body = [
        '<main class="threshold">',
        '  <a class="brand display" href="/">Glassvow</a>',
        '  <h1 class="lost">Page not found <span lang="zh-Hant">找不到此頁面</span></h1>',
        *policy_panes(),
        "</main>",
        *company_footer("en"),
    ]
    return shell(lang="en", title="Page not found · Glassvow", body=body,
                 description="There is no page at this address on the Glassvow site.",
                 body_class="home")


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
        self.doctype = False

    def handle_decl(self, decl: str) -> None:
        self.doctype = decl.lower() == "doctype html"

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = {name: value or "" for name, value in attrs}
        self.seen[tag] += 1
        if tag in FORBIDDEN_TAGS:
            self.errors.append(f"<{tag}> is not allowed on a script-free, self-only page")
        self.errors += [f"inline {name}= on <{tag}>" for name in values
                        if name == "style" or name.startswith("on")]
        loads = [values["src"]] if "src" in values else []
        if tag == "link" and not set(values.get("rel", "").split()) <= {"canonical", "alternate"}:
            loads.append(values.get("href", ""))
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
        if tag == "meta" and values.get("name") == "description":
            self.description = values.get("content", "")
        if tag not in VOID_TAGS:
            display = (tag in ("h1", "h2") or "display" in values.get("class", "").split()
                       or bool(self.open and self.open[-1][1]))
            self.open.append((tag, display))

    def handle_endtag(self, tag: str) -> None:
        if not self.open or self.open[-1][0] != tag:
            expected = f"<{self.open[-1][0]}>" if self.open else "no open element"
            self.errors.append(f"</{tag}> does not close {expected}")
        else:
            self.open.pop()

    def handle_data(self, data: str) -> None:
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
        except BuildError as error:
            raise BuildError(f"{page.source}: {error}") from None
        pages[page_file(page.path)] = article_page(page, group[1 - index], article, group)
    return pages


def build() -> tuple[dict[str, bytes], set[str], str]:
    """Return site/ outputs, the site paths they reference and the display corpus."""
    slim = slim_source_errors()
    if slim:
        raise BuildError("; ".join(slim))
    pages: dict[str, str] = {}
    pages.update(render_pages(POLICIES))
    pages.update(render_pages(COMPANY_PAGES))
    pages["index.html"] = home_page()
    pages["404.html"] = not_found_page()
    links: set[str] = set()
    corpus: set[str] = set()
    for relative, page in pages.items():
        audit = audit_page(page)
        audit.errors.extend(disclosure_errors(relative, page))
        if audit.errors:
            raise BuildError(f"site/{relative}: " + "; ".join(audit.errors))
        links |= audit.links
        corpus |= set(CJK.findall("".join(audit.display)))
    outputs = {relative: page.encode("utf-8") for relative, page in pages.items()}
    outputs.update({target: (ROOT / source).read_bytes() for target, source in COPIES.items()})
    return outputs, links, "".join(sorted(corpus))


def stale_paths(site: Path, outputs: dict[str, bytes]) -> list[str]:
    return [f"{'STALE' if (site / relative).is_file() else 'MISSING'} site/{relative}"
            for relative, content in sorted(outputs.items())
            if not (site / relative).is_file() or (site / relative).read_bytes() != content]


CSS_URL = re.compile(r"""url\(\s*["']?([^"')]+)""")
CSS_EXTERNAL = re.compile(r"@import|url\(\s*[\"']?\s*(?:[a-z][a-z0-9+.-]*:|//)", re.IGNORECASE)


def reference_problems(site: Path, links: set[str]) -> list[str]:
    css = (site / STYLESHEET).read_text(encoding="utf-8")
    problems = [f"EXTERNAL site/{STYLESHEET}: {match.group(0)}" for match in CSS_EXTERNAL.finditer(css)]
    targets = {url.split("#")[0] for url in links}
    targets |= {"/" + str(Path(STYLESHEET).parent / url) for url in CSS_URL.findall(css)
                if not CSS_EXTERNAL.match(f"url({url})")}
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
    source = fonts.ensure_cjk_sources(fonts.DEFAULT_SOURCE_DIR)["SemiBold"]
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
            ("third-party stylesheet", good.replace(f'href="/{STYLESHEET}"', 'href="https://cdn.example/a.css"')),
            ("missing lang", good.replace(' lang="en"', ""))):
        expect(label, lambda page=page: bool(audit_page(page).errors))

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
        stale = stale_paths(site, outputs)
        references = reference_problems(site, links)
        font = display_font_problems(site, corpus)
    expect("stale page", lambda: "STALE site/index.html" in stale)
    expect("missing page", lambda: "MISSING site/404.html" in stale)
    expect("third-party CSS import", lambda: any(item.startswith("EXTERNAL") for item in references))
    expect("dangling link", lambda: any(item.startswith("DANGLING /assets/icon.png") for item in references))
    expect("display font drift", lambda: any(item.startswith("DISPLAY_FONT") for item in font))
    expect("missing display glyph", lambda: any(corpus[-1] in item for item in font))
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
    if "company/index.html" not in outputs or "company/zh-hant/index.html" not in outputs:
        failures.append("company pages were not built")
    if any(disclosure_errors(rel, page) for rel, page in html_pages.items()):
        failures.append("built pages fail the company/privacy disclosure contract")
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
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    try:
        outputs, links, corpus = build()
        if args.display_font:
            write_display_font(corpus)
        if not args.check:
            write_outputs(SITE, outputs)
        problems = (stale_paths(SITE, outputs) + reference_problems(SITE, links)
                    + display_font_problems(SITE, corpus))
    except (BuildError, OSError) as error:
        print(f"site build FAILED: {error}", file=sys.stderr)
        return 1
    if problems:
        print(f"site {'check' if args.check else 'build'} FAILED; run python3 tools/build_site.py "
              "(with --display-font for DISPLAY_* issues)\n" + "\n".join(problems), file=sys.stderr)
        return 1
    print(f"site {'is current' if args.check else 'written'}: {len(outputs)} files; "
          f"the zh-Hant heading face covers all {len(corpus)} display characters")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# Glassvow public entity

Single source for the canonical public name, short description and developer
string. `tools/build_site.py` (JSON-LD, `llms.txt`, home lede) and the iOS
listing **name** / **subtitle** in `docs/product/listing/ios/*.json` must match
these fields. The signed #243 listing promotional text and long description are
not duplicated here.

Do not put a postal address, company number or ICO number in this file.

developer: EUGNEL LTD
url: https://glassvow.eugnel.com
privacy_email: hello@eugnel.com
support_email: glassvow@eugnel.com
game_en: Glassvow
game_zh: 琉璃誓言
subtitle_en: A pilgrimage in stained glass
subtitle_zh: 彩窗上的朝聖之路
short_en: Glassvow (琉璃誓言) is a single-player card game coming soon to iOS (App Store), Android (Google Play), Amazon Appstore and Steam (PC).
short_zh: 《琉璃誓言》（Glassvow）是一款單人卡牌遊戲，即將登陸 iOS（App Store）、Android（Google Play）、Amazon Appstore 及 Steam（PC）。

Platforms (owner decision, 19 October 2026): all four are "coming soon". Public
copy names no release date, price or store link until a store page is live.
`tools/teaser_page.py` (`GAME_PLATFORMS`) holds the wording; `--self-test` and
`--check` keep the entity, JSON-LD `gamePlatform`, `llms.txt`, the FAQ, how to
play, genre and teaser pages on it. The privacy policy and draft terms describe
the iOS build as it exists today and change with each platform's own release.

## External mention targets (checklist, not actions)

Free surfaces only. Do not pay for placement. Do not spam. Tick when a
citation is actually observed, not when someone was asked to post.

- [ ] Wikidata item that names Glassvow / 琉璃誓言 and EUGNEL LTD
- [ ] English Wikipedia or a reliable secondary source that cites the site
- [ ] 繁體中文 secondary source that cites the site
- [ ] Store product pages (after release) cited by AI overviews
- [ ] Editorial listings (TouchArcade, Pocket Gamer, or equivalent) if they write about the game
- [ ] Organic forum or Reddit mention with a link to glassvow.eugnel.com

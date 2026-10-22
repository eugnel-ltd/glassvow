# Glassvow listing preparation

Prepared for [#754](https://github.com/eugnel-ltd/glassvow/issues/754), continuing [#427](https://github.com/eugnel-ltd/glassvow/issues/427). The JSON files are local upload candidates, not an App Store Connect readback. No field, price or asset was uploaded by this preparation.

## Text and sources

`ios/en-US.json` and `ios/zh-Hant.json` contain the name, subtitle, promotional text, description, keywords and draft first-release note. Name, promotional text and descriptions preserve the [signed #243 resolution](https://github.com/eugnel-ltd/glassvow/issues/243#issuecomment-5335822126) exactly. Subtitles come from row 454 of `docs/story/05-foreshadow-ledger.md`, as verified in [#427's subtitle source record](https://github.com/eugnel-ltd/glassvow/issues/427#issuecomment-5648971317). No second-class or future-release claim was added. The premium/full-campaign claims still require the final product evidence owned by #108.

The signed English keyword source is `roguelike,roguelite,deckbuilder,cards,strategy,stained-glass,pilgrimage,turn-based,story,indie`. The upload candidate removes only `stained-glass` and `pilgrimage`: the subtitle already indexes those words, and the company `listing_check.py` rejects that duplication.

**Draft ASO (#802, 19 October 2026), for owner review before any App Store Connect write. It does not supersede #243.** Unused keyword budget only: English adds `single-player` (83/100); Chinese adds `單人` (41/100). No competitor names, no stuffing, no change to name, subtitle, promotional text or description. `彩窗` and `朝聖` remain in the Chinese keyword string as signed; they still duplicate the subtitle and still need authorised ASC validation. The five two-character Chinese terms (`卡牌`, `策略`, `彩窗`, `朝聖`, `劇情`) still need that validation; local length checks do not prove acceptance or a language exception.

The draft `whatsNew` strings derive from `releases/1.0.0.md`. They do not announce a live release. The final release lane reads that note and these field files; no upload automation is introduced here.

## Remaining fields and dependencies

| Item | Evidence or exact missing proof |
|---|---|
| App identity | Shipping App Store Connect app: Apple ID `6825547714`, name `Glassvow`, SKU `glassvow`, bundle `uk.eugnel.glassvow`, primary language English (U.K.). The James TO record `6803851427` (bundle `io.fol2.glassvow`, SKU `GLASSVOW-IOS-2026`) still exists and is unused. Listing field readback remains pending |
| Price | #243 signed US$6.99 base price, Apple regional prices, no introductory discount; current store schedule/readback pending |
| Storefronts, pre-order, release control | #425 remains open; its recommendation is not a recorded choice |
| Support URL | The prepared root `https://glassvow.eugnel.com/` shows `glassvow@eugnel.com`; live HTTP, routing and mailbox delivery proof remain pending |
| Privacy URLs | English `https://glassvow.eugnel.com/privacy/`; Chinese `https://glassvow.eugnel.com/privacy/zh-hant/`; #415 owns live checks and ASC readback |
| App Privacy | `docs/privacy/README.md` contains the current proposed answers; #415/#420 own unresolved decisions, actual payload and ASC evidence |
| Category, copyright, age/content-rights and encryption declarations | Need current authorised form/build readback; no answers or seller identity invented |
| Review contact and instructions | Private contact remains outside git; final #541 build must supply the reproducible review route |
| Icon | #545 landed via #590; acceptance/attachment to the actual store slot still needs readback |
| Screenshots | #546 owns the final 24-frame matrix; no image, caption or layout changed here |
| Final product | #108 signature and #541 build identity remain required; #428 owns submission and #429 public verification |

Google Play remains the later platform wave. These iOS fields do not claim an Android listing or Play Data safety completion. The web channel is a policy/contact site with no checkout; its existing pages are not a game-store listing.

## Local check

Run the company skill's `scripts/listing_check.py` on each JSON file with `--store apple`. It checks field lengths, duplicate indexed keywords, claims and known field types. It does not validate the current ASC form, assets, legal decisions or the final binary. The English description and Chinese description have 400 and 133 characters; the English and Chinese subtitles have 29 and 8; the draft keywords have 83 and 41. All fit the recorded field maxima. Actual check results belong in the delivery receipt. These keyword additions stay draft until the owner accepts them against #243.

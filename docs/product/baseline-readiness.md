# Nonvisual baseline readiness

Prepared on 18 October 2026 for [#753 legal](https://github.com/eugnel-ltd/glassvow/issues/753), [#754 listing](https://github.com/eugnel-ltd/glassvow/issues/754) and [#755 payments](https://github.com/eugnel-ltd/glassvow/issues/755). All three remain `missing` in `product.yaml`: local preparation is not publication, store acceptance or legal review.

## What this preparation delivers

The manifest records the existing paid-app SKU and App Store app ID from #426, and the north star now reflects #243's signed US$6.99 launch price. The bilingual JSON in `docs/product/listing/ios/` contains the actual listing fields, with provenance and the one duplicate-keyword correction in its README. `releases/1.0.0.md` supplies the draft first-release note. `docs/legal/` contains bilingual product-specific terms/refund drafts and the shared renderer's exact missing inputs and incompatible default claims. No artwork, screenshot, caption, layout, runtime, price choice or launch-control choice changes.

## Paid download: evidence and remaining checks

Glassvow's launch model is a paid App Store download, with no account, web checkout, IAP or separate entitlement backend. The generic company payments checklist mentions server-verified receipts and an entitlement API; it does not by itself authorise building those features into this product. The approved no-account/local-save scope remains in force. If the company gate requires an entitlement architecture beyond the store's paid-download licence, resolve that contract in the company baseline rather than inventing a waiver or silently adding a server.

[#426's 21 August 2026 provisioning readback](https://github.com/eugnel-ltd/glassvow/issues/426#issuecomment-5368536882) records app ID `6803851427`, bundle ID `io.fol2.glassvow`, SKU `GLASSVOW-IOS-2026`, primary locale `en-US` and version `1.0.0` in `PREPARE_FOR_SUBMISSION`. [Its account verification](https://github.com/eugnel-ltd/glassvow/issues/426#issuecomment-5368972109) records the Paid Applications agreement in effect, banking cleared, required tax forms complete and EU DSA active/verified. #426 is closed. Those are dated completed observations, not missing setup steps and not a current release receipt.

For #755 before publication, the exact remaining proof is a current authorised readback of those prerequisites, the actual paid-app price schedule/regional prices and configured sale availability under #425's eventual storefront policy, plus agreement on how the company payments baseline applies to this paid-download model. After release, #429 separately verifies public purchase/download of the signed #108/#541 candidate; that later smoke check cannot be a prerequisite for a gate that must pass before first publication. This environment exposes GitHub but no App Store Connect action or `asc` executable, so none of those remote reads or purchases is claimed. No payment details or credentials belong in git. #425 is open with no recorded storefront/pre-order/release-control answer; its recommendation is not adopted here.

Apple's app ID is stored as the iOS store identifier for the known paid app. It is not a StoreKit IAP product ID. The launch price is a signed decision, not a fabricated current price readback. Google Play's merchant setup remains a later-platform dependency; this work does not assert its state.

## Closure map

| Issue | Available output | Exact remaining dependency |
|---|---|---|
| #753 | Two-language privacy pages naming EUGNEL LTD as controller, 2026 UK data-law complaints wording, short site-wide footer linking to a Company information page, plus terms/refund drafts in `docs/legal/` | Deploy the updated pages, solicitor review, #415/#420 observed disclosures and current ASC answers; `baseline.legal` stays missing until that proof exists |
| #754 | Complete local bilingual iOS text JSON and first-release note; known signed price and historical app identity | Current ASC field validation/readback, Chinese keyword entry check, #425 choices, accepted #545/#546 asset slots and final #108/#541 identity |
| #755 | Existing paid-download SKU/app ID registered in the manifest; #426's completed account proof linked | Current account/price/configured-availability reads, agreed interpretation of any generic entitlement requirement and authorised storefront policy; #429 purchase/download smoke is a separate post-release check |

`python3 .ai-sdlc/manifest_check.py product.yaml` proves the manifest shape. `--publishing ios` must continue to refuse while these required items are open. No `done`, waiver, exclusion, live version or live date is added for these items. Publication and signing remain outside this preparation.

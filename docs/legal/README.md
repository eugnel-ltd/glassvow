# Legal baseline preparation

Prepared for [#753](https://github.com/eugnel-ltd/glassvow/issues/753). `baseline.legal` remains `missing`. The documents here are review inputs, excluded from `site/`; no terms page was published. The privacy notice now names EUGNEL LTD as controller (owner decision, 19 October 2026). Live deployment of those pages, solicitor review, and the #415/#420 observations are still required before the item can be `done`.

## Concrete documents

- `terms-and-refunds.en.md` and `terms-and-refunds.zh-Hant.md` provide matching draft terms and refund text for the actual paid-download product. They omit accounts, in-app purchases, web checkout, account deletion and a separate receipt/entitlement service.
- The English and Chinese privacy policies live in `docs/privacy/` and are generated into `site/`. `docs/privacy/README.md` records the proposed store privacy answers, SDK sources, unresolved D2–D4 decisions and the live/device checks owned by #415/#420.
- Consent/settings review must start from the shipped copy in `locale/en.json` and `locale/zh-Hant.json`, `ui.settings.diagnostics`, `diagnosticsNotice` and `diagnosticsNote`. The switch is on by default, can be turned off, and takes effect on the next launch (`application/sentry_loop.gd`). This is the existing D1 option B, not an opt-in or a new finding that consent is legally sufficient. There is no account-deletion or web-cookie consent flow to describe.

The draft terms adapt the company legal template's digital-content/statutory-rights and store-refund sections. They are not a solicitor's opinion or a new store declaration.

## Shared renderer preflight

Authority: eugnel-platform `packages/legal/README.md`, `src/pages.js`, `src/render.js` and its five templates, inspected at commit `20ea52439d1dc285fea3ebcc0671acef6ff2af56`. The renderer requires complete fields and the README requires solicitor review before a product's first public release. The company source is eugnel-hq `company/company.yaml`, read for this work on 18 October 2026 and updated from the 19 October 2026 owner comments on #753; keep company facts there rather than forking them into this repository.

| Input or template | Exact gap for Glassvow |
|---|---|
| Company privacy address | `privacy_email` is `hello@eugnel.com` in eugnel-hq `company/company.yaml`, owner-confirmed on 18 October 2026. The Glassvow privacy notice uses that address as the controller contact. Product support remains `glassvow@eugnel.com` |
| ICO registration | Registration number `ZC277339`, confirmed by ICO email on 19 October 2026. The notice reads "registered with the Information Commission (ICO), registration number ZC277339", with no pending or application wording. `C2062045` was an application reference and is not used |
| Company and seller/controller | Owner decision, 19 October 2026 (issue #753): Glassvow is an EUGNEL LTD product and EUGNEL LTD is the data controller now. Company no. 17505169, registered in England & Wales, registered office 122 New Road, Ascot, SL5 8QH. The App Store app/IP transfer from James's individual Apple developer account comes later, is separate, and does not block the notice; until it happens the App Store still shows the individual seller, which is expected. Do not reword the notice to match that seller |
| Manifest legal data | No `legal` block yet. Lawful basis, installation-ID linkage, purpose mapping, actual retention and Sentry account/transfer terms are not settled by source inspection; preserve #415's D2–D4 questions until evidence resolves them |
| Default templates | Terms and privacy unconditionally describe accounts; consent describes account deletion and anonymous usage statistics; store answers promise in-app account deletion. Those claims do not describe this product |
| Web channel | `channels.web` is a policy/contact site, not checkout. The renderer uses the key to add a web merchant-of-record sale, invoice and order email; those claims must not be published for Glassvow |
| Store payments | The privacy template says the product receives a purchase receipt. The current game has no receipt-upload/entitlement service. A paid download is not an IAP integration |
| Refunds | The template claims the product asks for cancellation consent at checkout and that refunds revoke access. There is no game-owned checkout or remote entitlement revocation to prove those claims |
| First public release | Solicitor review of the customer documents is still required. Publishing the updated privacy pages and confirming the live URLs are still required. A successful render alone would not complete them |

Do not fill unknowns with placeholder facts to make the renderer pass. Correct the platform's product-shape assumptions through its own reviewed change before using its output unchanged. The draft documents here make the available product-specific preparation reviewable while preserving that dependency.

## Proof still needed

| Existing lane | Required observation |
|---|---|
| #415 privacy | Deploy the updated pages to `glassvow.eugnel.com`; actual policy HTTP/redirect/404 checks, Cloudflare no-injection settings, support and privacy mailbox delivery, Sentry region/retention/IP setting, final policy and ASC URL/privacy-answer readback; resolve D2–D4 with the final disclosures |
| #420 telemetry | Three actual iOS probe events (script error, native crash, hang), matching symbols/build, payload exclusions and exported SDK privacy manifest; inspect before turning configured behaviour into observed claims |
| #427 listing | Current seller, applicable privacy form, rights/rating declarations and final fields/assets; the App Store seller remains the individual account until the later transfer |
| Solicitor | Review both-language customer documents and the diagnostics lawful basis/consent posture |

No account, device, mailbox or solicitor action is marked complete by this preparation. `baseline.legal` stays `missing` until that proof exists. This repository does not write a waiver in the owner's name.

# Legal baseline preparation

Prepared for [#753](https://github.com/eugnel-ltd/glassvow/issues/753). `baseline.legal` remains `missing`. The documents here are review inputs, excluded from `site/`; no new legal page was published. Existing privacy pages and their approved in-app targets remain unchanged.

## Concrete documents

- `terms-and-refunds.en.md` and `terms-and-refunds.zh-Hant.md` provide matching draft terms and refund text for the actual paid-download product. They omit accounts, in-app purchases, web checkout, account deletion and a separate receipt/entitlement service.
- The English and Chinese privacy policies already exist in `docs/privacy/`. `docs/privacy/README.md` records the proposed store privacy answers, SDK sources, unresolved decisions and the live/device checks owned by #415/#420.
- Consent/settings review must start from the shipped copy in `locale/en.json` and `locale/zh-Hant.json`, `ui.settings.diagnostics`, `diagnosticsNotice` and `diagnosticsNote`. The switch is on by default, can be turned off, and takes effect on the next launch (`application/sentry_loop.gd`). This is the existing D1 option B, not an opt-in or a new finding that consent is legally sufficient. There is no account-deletion or web-cookie consent flow to describe.

The draft terms adapt the company legal template's digital-content/statutory-rights and store-refund sections. They are not a solicitor's opinion, a new store declaration or a decision about the identity of the seller/controller.

## Shared renderer preflight

Authority: eugnel-platform `packages/legal/README.md`, `src/pages.js`, `src/render.js` and its five templates, inspected at commit `20ea52439d1dc285fea3ebcc0671acef6ff2af56`. The renderer requires complete fields and the README requires solicitor review before a product's first public release. The company source is eugnel-hq `company/company.yaml`, read for this work on 18 October 2026; keep company facts there rather than forking them into this repository.

| Input or template | Exact gap for Glassvow |
|---|---|
| Company privacy address | `privacy_email` is null. Do not infer it from `glassvow@eugnel.com` or create a mailbox by writing an address |
| ICO registration | `ico_registration` is null; the company record says pending. `C2062045` is an application reference, not a registration number. The expected date of 19 October is not proof of registration |
| Company and seller/controller | Company facts identify EUGNEL LTD, number 17505169, registered office 122 New Road, Ascot, Berkshire, SL5 8QH, England and Wales. Existing privacy text names James TO. Confirm the applicable contracting entity/controller against actual account and legal records before publishing revised identity text |
| Manifest legal data | No `legal` block yet. Lawful basis, installation-ID linkage, purpose mapping, actual retention and Sentry account/transfer terms are not settled by source inspection; preserve #415's D2–D4 questions until evidence resolves them |
| Default templates | Terms and privacy unconditionally describe accounts; consent describes account deletion and anonymous usage statistics; store answers promise in-app account deletion. Those claims do not describe this product |
| Web channel | `channels.web` is a policy/contact site, not checkout. The renderer uses the key to add a web merchant-of-record sale, invoice and order email; those claims must not be published for Glassvow |
| Store payments | The privacy template says the product receives a purchase receipt. The current game has no receipt-upload/entitlement service. A paid download is not an IAP integration |
| Refunds | The template claims the product asks for cancellation consent at checkout and that refunds revoke access. There is no game-owned checkout or remote entitlement revocation to prove those claims |
| First public release | Solicitor review and confirmed final entity, contact, effective date and store scope are still required. A successful render alone would not complete them |

Do not fill unknowns with placeholder facts to make the renderer pass. Correct the platform's product-shape assumptions through its own reviewed change before using its output unchanged. The draft documents here make the available product-specific preparation reviewable while preserving that dependency.

## Proof still needed

| Existing lane | Required observation |
|---|---|
| #415 privacy | Actual policy HTTP/redirect/404 checks, Cloudflare no-injection settings, support mailbox delivery, Sentry region/retention/IP setting, final policy and ASC URL/privacy-answer readback; resolve D2–D4 with the final disclosures |
| #420 telemetry | Three actual iOS probe events (script error, native crash, hang), matching symbols/build, payload exclusions and exported SDK privacy manifest; inspect before turning configured behaviour into observed claims |
| #427 listing | Current seller, applicable privacy form, rights/rating declarations and final fields/assets; the legal identity must match confirmed records |
| Company facts / solicitor | Supply the company privacy address, actual ICO outcome and final contracting/controller identity; review both-language customer documents and the diagnostics lawful basis/consent posture |

No account, device, mailbox or solicitor action is marked complete by this preparation. The expected ICO date must never change status automatically.

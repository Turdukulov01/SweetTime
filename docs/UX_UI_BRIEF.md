# SweetTime UX/UI Requirements Pack

## Design Direction

SweetTime should feel youthful, sweet, modern, and light: pastel/kawaii cues with clear ordering hierarchy and no decorative overload. Light theme is primary; dark theme remains supported. The current implementation and screenshots are prototypes until they pass this pack and the reconciled design system.

## Access And Authentication Rules

- Guests can select a branch, browse/search the menu, configure products, view active promotions, and build a local cart.
- Checkout and all personal surfaces require authentication. After successful auth, the user returns to the interrupted checkout with cart and valid selections preserved.
- Phone OTP is the primary P0 path. The Kyrgyz field owns the fixed `+996` prefix, accepts exactly nine subscriber digits, formats them as `XXX XXX XXX`, and sends the normalized `+996XXXXXXXXX` value to auth.
- Email one-time code remains the alternative. Prototype calls must use and name `MockPhoneOtpProvider` or `MockEmailOtpProvider`; they must never imply that a real message was sent.
- Google Sign-In is an owner-approved additional path. It may become active only through the official provider with registered Android/iOS OAuth clients and a backend ID-token exchange that issues a SweetTime session. Until those prerequisites exist, the UI must show a localized setup-required state and must not turn Google/Apple taps into SMS or a local authenticated session. Other social providers remain future scope.
- Personal order, balance, QR, referral, and account data must never render briefly while the app is resolving a guest or expired session.

## Canonical Navigation

The authenticated and guest shell uses five stable tabs:

1. **Home**
2. **Catalog**
3. **QR**
4. **Cart**
5. **Profile**

QR is the central tab. For a guest it shows an auth gate; for a customer it opens **My QR / Scan**. Every authenticated customer has one permanent unique six-digit code, displayed with spacing for readability but stored without spaces. Its QR payload uses the versioned SweetTime referral/loyalty format approved during backend design.

## Core Customer Flows

### Guest To Order

Launch -> optional first-run introduction -> select branch -> browse/search -> configure product -> cart -> checkout auth gate -> phone/email one-time code or configured Google Sign-In -> return to checkout -> choose pickup/scheduled/QR-table -> for QR-table scan or enter the branch table reference -> choose demo/cash/QR-demo payment -> place order -> confirmation/status.

### Loyalty And Referral

Authenticate -> QR -> show permanent loyalty QR or scan friend's QR/manual code -> validate one-time inviter binding -> invited customer receives 50 points -> inviter receives 100 after the invited customer's first `completed` order. Loyalty earns 5% of paid amount, allows up to 30% redemption, uses `1 point = 1 KGS`, and expires after 12 months.

### Repeat Order

Profile or order status -> order history -> reorder -> resolve removed/unavailable products or modifiers -> cart -> checkout.

### Account Deletion

Profile -> Settings -> Delete account -> explain consequences -> explicit confirmation/re-auth if required -> submitting -> success and sign-out, or recoverable failure without losing the account.

## Order And Payment States

Preparation lifecycle is `awaiting_payment` when confirmation is required, then `new -> preparing -> ready -> completed`. `cancelled` is a separate terminal outcome. Payment state is separate, for example `not_required | pending | paid | failed | refund_pending | refunded`; UI must not use payment wording as an order-preparation status.

The customer may self-cancel an `awaiting_payment` or `new` order only. Once preparation starts, the UI offers branch contact instead of a cancel action. Cancelling a paid demo order creates one idempotent `refund_pending -> refunded` flow; cash needs no refund. Reserved/redeemed points and pending rewards are reversed exactly once. Branch staff may cancel later only through an authorized operational flow with a recorded reason.

## P0 Mobile Surface Specification

| Surface | Purpose And Entry | Primary Actions | Auth Gate | Verifiable Acceptance |
|---|---|---|---|---|
| Launch / bootstrap | Resolve theme, demo/API mode, session, company config, and last branch when the app opens | Retry, continue with safe offline/demo data when allowed | No | No personal data flashes before session resolution; failure has retry; offline/demo mode is labelled; launch cannot dead-end |
| First-run introduction | Explain ordering, loyalty, and branch choice on first run | Next, skip, start | No | Skip is always visible; completion persists locally; content fits 320 width and does not block returning users |
| Home | Orient the user to the selected branch, current news, promotions, and primary ordering CTA | Change branch, open a news story/promotion/product, open catalog | No | Selected branch is visible; the horizontal "Узнайте, что у нас нового" story rail contains only active news and hides when empty; categories remain in Catalog rather than duplicating Home; unavailable content is not advertised; one primary order CTA is obvious |
| Branch picker and detail | Choose operating context and inspect address, hours, phone, open state, pickup estimate, and map links | Select branch, call, open 2GIS/Google Maps, retry | No | Changing branch revalidates cart availability; closed branch is clear; external links are explicit; empty/error/offline states preserve the last valid choice |
| Catalog / search | Browse categories and products for the selected branch and manage favorite drinks where the choice is made | Search, select one or more independent categories, toggle the independent Favorites filter, toggle a product heart, open product, add configured/default item when valid | No | Search, multiple category IDs and Favorites compose; All clears categories; the Favorites chip uses a filled heart without a checkmark overlay; removing a heart while Favorites is active updates the grid immediately; favorite/no-result states explain the next action; branch-unavailable items are marked and cannot be silently ordered; prices use whole KGS |
| Product detail / customizer | Explain a product and collect required size, sugar, ice, and topping choices | Select modifiers, change quantity, add to cart | No | Required choices are validated; price updates immediately; allergen/info text is reachable; unavailable product disables add with branch-specific reason; action remains reachable with keyboard/text scaling |
| Promotions | Show only active pilot offers and their eligibility | Open offer, follow eligible CTA | No | Start/end dates, branch/product exclusions, and promo requirements are understandable; empty list has no decorative placeholder block; expired offer cannot be applied |
| Cart | Review local items, modifiers, quantities, promo, and estimated loyalty before checkout | Edit/remove, change quantity, apply promo, proceed to checkout | No; points balance requires auth | Guest cart survives auth return and app restart according to local policy; totals recalculate; invalid promo has inline reason; unavailable items must be resolved; empty cart has catalog CTA |
| Authentication: channel and code | Create or resume an account through phone OTP, email one-time code, or configured Google Sign-In | Enter the fixed-format Kyrgyz phone, choose email, request/verify/resend a code, or choose a Google account | Required only at protected boundary | The heading says sign in or register; phone is fixed to `+996` plus exactly nine digits; named mock provider and demo code are explicit; invalid/expired code, cooldown, provider error, cancellation and offline states preserve input; Google is active only with registered client IDs and a backend token exchange, otherwise a localized setup-required state is shown |
| Checkout | Confirm branch, order type, time/table, payment method, points, promo, comments, and final total | Select options, place order | Yes | Auth return preserves valid cart/options; availability and promo are revalidated; scheduled time must be future/within hours; QR-table requires valid table reference; points never exceed 30%; total cannot change silently |
| QR-table identification | Identify the selected branch table for a cafe order; entered from Checkout, not from the loyalty/referral QR tab | Scan branch-issued table QR, enter table number/code manually, retry or change order type | Yes | Scanner copy cannot be confused with referral binding; manual fallback is always available; malformed, inactive, or wrong-branch references show specific errors; no order is placed until the table is valid |
| Demo payment / result | Demonstrate payment-dependent flow without claiming a real provider | Confirm named demo, retry failed demo, return to checkout | Yes | Real provider logos/claims are absent; duplicate taps cannot create duplicate paid orders; pending/failure/success are distinct; cash skips fake online confirmation |
| Order confirmation and status | Confirm accepted order and show preparation progress | Refresh, self-cancel only in `awaiting_payment`/`new`, contact branch after preparation, reorder after completion | Yes | Order number, branch, type, total, payment state, and approved lifecycle are separate and readable; cancellation/refund outcome is explicit and idempotent; offline shows last update time; unsupported backward transition is never offered |
| Order history / reorder | Review prior orders and rebuild an available cart | Filter/open order, reorder | Yes | Empty state has catalog CTA; reordered items preserve valid modifiers; removed/unavailable items require explicit resolution; cancelled and completed orders are distinguishable |
| QR — My QR | Present permanent loyalty/referral identity to a barista or friend | Adjust brightness if supported, copy six-digit code | Yes | Code is stable across sessions, copyable, human-readable, and matches the QR payload; balance is not exposed to guests; screenshot contains no unrelated sensitive data |
| QR — Scan / manual code | Bind an inviter for a new customer, with camera fallback | Grant permission, toggle the device torch when supported, scan, enter six-digit code, retry | Yes | Handles denied/permanently denied/unavailable camera; torch control has on/off/unavailable feedback and remains disabled when unsupported; camera/QR detection stops on My QR, another bottom tab, or app background and resumes only on active Scan; manual input is always reachable; self, malformed, already-bound, and ineligible codes return specific non-destructive results |
| Loyalty wallet / ledger | Keep Profile compact while explaining the authenticated customer's balance, rules and referral | Open the single Profile Points entry, copy the referral code, then later open the full ledger | Yes | The current prototype route shows one balance, `1 point = 1 KGS`, 5%, 30%, 12-month rules and invite-a-friend copy; it does not invent per-customer expiring entries. Before P0 completion, balance must equal a server ledger and earned/spent/referral/expired adjustments and empty state must be available |
| Referral status | Explain invitation rules and show result of binding/rewards | Open My QR, scan, copy code, view invited/rewarded state | Yes | Copy says invited +50 and inviter +100 only after first `completed` order; one-inviter and self-referral rules are explicit; no multi-level earnings are implied |
| Profile — guest | Explain protected benefits without leaking personal data and expose public preferences | Select RU/KG/EN, sign in, continue browsing through tabs | No | No fake balance/order/name is shown; language selection persists; sign-in returns to Profile unless another protected flow initiated auth |
| Profile — customer | Summarize identity and account destinations without repeating a product list | Select RU/KG/EN, edit profile, open the single Points entry, history/recurring order, support or FAQ, sign out | Yes | Header uses the customer's own name/photo or an honest add-name fallback; Favorite drinks appears in Catalog, not Profile; Points rules/referral live behind one row; language selection persists independently of auth; sign-out clears local personal data while preserving allowed guest cart/preferences |
| Profile edit | Capture customer identity without pretending that a local file is a server avatar | Edit required first/last name, optional birth date, choose gallery, take photo, remove photo, save | Yes | Validation is inline; camera/gallery cancellation is harmless; permission/picker failure is localized; current mock labels the avatar session-only; production must upload a validated file and store a server object identity rather than the device-local path |
| Help and account | Group support, FAQ and account actions into one predictable Profile section | Open support, expand FAQ answers, sign out, start deletion | Support/FAQ may be public; personal actions require auth | Missing support configuration is labelled unavailable and no fake phone/email/chat action is enabled; FAQ is localized; sign-out is distinct from irreversible deletion; future hosted legal links remain labelled until configured |
| Account deletion | Let the customer understand and complete deletion safely | Cancel, confirm, re-auth if required, retry | Yes | Consequences and irreversible data are explained; double-submit is blocked; progress survives navigation safely; success signs out and clears personal cache; failure leaves account usable and shows support path |

## P0 Admin Flows

The canonical admin is the custom Next.js app in `admin/`; `admin-legacy/` is archive-only.

- **Login and scope:** owner/manager/barista enters the SweetTime pilot and sees only allowed company/branch resources.
- **Order queue:** filter by branch/status, inspect order/payment separately, and offer only valid one-click lifecycle actions.
- **Menu:** manage categories, products, sizes, modifiers, prices, active state, and branch availability.
- **Branches:** manage contact/hours/open state and availability overrides.
- **Staff:** owner manages roles and branch assignment; a user cannot escalate their own role.
- **Promotions/promo codes:** manage eligibility, dates, branch/product restrictions, and active state.
- **News:** owner and manager create, edit, preview, schedule, publish, reorder, archive, and delete localized Home stories; barista has no read/write admin surface for news. The API independently enforces role and `company_id` scope, and the public mobile feed returns only active, published, non-expired items.
- **Customers/loyalty/referrals:** view only operationally necessary data and ledgers; never expose password hashes or secrets.
- **Pilot settings:** owner maintains approved SweetTime branding and rules; the two-company showcase remains demo-only.

Admin acceptance requires server-side role/company/branch enforcement; hiding a menu item is not authorization.

## Language And Localized Content

- The application language selector offers **RU**, **KG**, and **EN**. The locale codes are `ru`, `ky`, and `en`; `KG` is the customer-facing label for Kyrgyz.
- The selected language persists locally, is available to guests, and is reachable from Home and Profile. Authentication changes must not reset it.
- In Profile the selector is a compact language icon immediately beside the theme action; it opens
  the three labelled options and must not consume a full central card. The guest Profile exposes
  the same two public preference actions in its app bar.
- Static application copy and dynamic company content are separate concerns. Static UI belongs in the Flutter localization resources; news, products, promotions, and branch content arrive as localized domain data.
- Dynamic content falls back from the selected language to Russian when an approved translation is absent. The admin must show translation completeness before publication without inventing machine-translated production copy.
- The current Flutter prototype implements this split for every existing screen and all demo
  categories, products, modifiers, branches, promotions and news. Category/modifier selections use
  stable IDs or enums, so changing language must preserve filters, customizations and cart items.
- The backend contract must return stable IDs together with `{ru, ky, en}` display fields. Legacy
  strings are accepted only as a demo-compatibility fallback; a production client must not infer an
  ID from a Russian label, list position or translated slug.

## State Matrix

| State | Required Behavior | Acceptance |
|---|---|---|
| Loading | Use skeletons for content and progress for blocking submissions; keep stable layout | No infinite spinner; a timeout/retry path exists; controls cannot submit twice |
| Empty | Explain why content is empty and provide the next useful action | Empty catalog/search/cart/orders/ledger/promotions are distinct; promotional sections may hide when absence is expected |
| Validation | Place actionable messages next to the affected field/choice | Input and cart are preserved; first invalid control becomes reachable; message is not color-only |
| Recoverable error | Keep last valid content, explain failure plainly, and offer retry | Retry is scoped and idempotent; user input is retained; raw stack/server errors are never shown |
| Offline | Show cached/local data with freshness and disable unsafe remote completion | Browsing/cart remain usable where possible; checkout never claims success without confirmation; reconnect/retry is visible |
| Guest | Render public data only and route protected actions to auth | No personal-data flash; guest cart is retained; auth returns to the initiating protected flow |
| Authenticating / expired session | Distinguish requesting, code entry, cooldown, expired code, and expired session | Session expiry preserves non-sensitive work and starts auth; repeated code requests respect cooldown; logout is deterministic |
| Deletion | Distinguish confirmation, submitting, success, failure, and previously requested state | No accidental deletion; double-submit blocked; success clears personal cache; failure is recoverable |
| Camera permission | Explain not requested, denied, permanently denied, unavailable, and active scanner states | Manual six-digit input always works; settings deep link appears only when useful; no blank camera surface |
| Branch/product unavailable | Explain whether branch is closed or item/modifier is unavailable | Add/checkout is blocked only for affected selections; branch change or removal is offered; price/total revalidates |
| Payment uncertainty | Keep `pending`, `failed`, `paid`, and `refunded` separate from order preparation | Retry/status check is idempotent; duplicate order creation is prevented; support path includes order reference |

## Android/iOS Responsive And Accessibility Acceptance

- Test every P0 surface at **320, 360, 390, and 430 logical-pixel widths**; no unintended horizontal scrolling or clipped primary action.
- Respect top/bottom safe areas, camera cutouts, Android gesture/three-button navigation, and iOS home indicator. Fixed checkout/cart actions sit above system insets and the five-tab bar.
- Interactive targets are at least **44x44 logical pixels**; prefer 48 on Android where layout permits. Adjacent icon actions remain separable.
- At platform text scale 1.0 and 1.3, content does not truncate essential meaning. At 1.5, text may wrap/scroll but every label, total, validation message, and primary action remains accessible.
- With the keyboard open at each input width, the focused field and its error are visible, the page can scroll, and the primary action is not permanently covered.
- Android system back and iOS back/swipe follow navigation history; leaving an in-progress payment/deletion action requires safe confirmation where needed.
- Bottom-tab labels remain stable in Russian, inactive glyphs use their filled tinted form, the
  selected pill/icon keeps its approved contrasting treatment, cart badge handles `0`, `1–9`,
  and `9+`, and the central QR action is reachable.
- Loading/error/empty transitions do not move the primary action unpredictably. Intentional horizontal carousels expose their scroll affordance.
- Light theme is the acceptance baseline; dark theme must retain readable contrast and state meaning but must not delay light-theme P0 approval.
- Performance acceptance uses profile/release mode on a target phone, not debug mode: warmed Home
  scrolling and tab feedback target the 16.7 ms frame budget at 60 Hz, first image decode avoids
  full-resolution textures when a smaller rendered size is sufficient, and leaving Scan removes
  the system camera indicator and sustained camera/ML workload.

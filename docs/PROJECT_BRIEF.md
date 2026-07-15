# SweetTime Project Brief

## Product And Current Milestone

SweetTime is a branded ordering and loyalty app for one bubble tea chain with several branches. The current target is a sellable **single-chain pilot for SweetTime**, starting with a polished Android/iOS UX/UI prototype and then connecting approved flows to the backend and admin.

The data model keeps `company_id` so the core can be adapted later. The two-company SweetTime/CoffeeGo demo proves configurable branding and data separation only; it is **not production SaaS**, tenant self-service, billing, or a promise to operate multiple clients at launch.

## Business Goal

The pilot must be understandable in one owner demo and useful for a live cafe trial:

- a guest can explore the real menu and build a cart without friction;
- an authenticated customer can place and track pickup, scheduled-pickup, or QR-table orders;
- loyalty, referrals, promotions, promo codes, and branch availability are visible and explainable;
- staff can process orders quickly and the owner can maintain pilot content;
- real payment, delivery, store, and legal dependencies remain clearly isolated.

## P0 Roles

- **Guest:** chooses a branch, browses the menu, configures products, and maintains a local cart.
- **Customer:** authenticates, checks out, tracks/repeats orders, uses loyalty and referrals, and manages/deletes the account.
- **Owner:** manages the SweetTime pilot, settings, roles, branches, menu, modifiers, availability, promotions, promo codes, customers, loyalty, and referrals.
- **Branch Manager:** manages branch operations, availability, schedule, orders, and staff within assigned scope.
- **Barista/Cashier:** sees the assigned branch queue and advances allowed order statuses.

The current pilot authentication path is Google Sign-In with a backend ID-token exchange. A customer must add a Kyrgyz contact number normalized to `+996` plus exactly nine subscriber digits before checkout; until a real SMS provider is connected, that number is explicitly unverified and is never accepted as a login factor. Phone OTP stays disabled outside local provider tests, and the old public demo-code fallback must not create a session. Production Google Sign-In still requires final app identifiers/signing, registered Google OAuth clients and configured backend audiences; other social providers and production messaging remain future integrations.

## Canonical Product Decisions

- Mobile navigation has five tabs: **Home / Catalog / QR / Cart / Profile**.
- Each authenticated customer has one permanent unique six-digit code and QR payload. It serves as the loyalty card and referral invitation.
- Guests may browse and build a cart. Authentication is required before checkout and before personal orders, balance, QR, referral, or account data are shown.
- Order lifecycle is `awaiting_payment` when payment confirmation is required, then `new -> preparing -> ready -> completed`; `cancelled` is a separate terminal outcome. Payment status is stored and displayed separately from preparation status.
- Loyalty defaults: `1 point = 1 KGS`, earn `5%` of the paid amount, spend up to `30%` of an order, expiry after 12 months.
- Referral defaults: the invited new customer receives 50 points when a valid invitation is bound; the inviter receives 100 points after that customer's first `completed` order. One inviter may be bound once; self-referral is rejected.
- P0 order types: pickup now, scheduled pickup, and QR-table order. Delivery is not P0.
- P0 payment choices: named demo payment, cash, and QR demo. Real providers are not represented as production-ready.
- Recurring "daily drink" is a P1 demo/MVP-light feature, not required to accept the P0 pilot.
- The canonical admin is the custom Next.js application in `admin/`. `admin-legacy/` is an archive and must not receive new MVP work.

## Owner Inputs Required

The business owner must approve or provide:

- legal brand name, customer-facing app name, logo variants, icon, and brand color references;
- menu categories, products, descriptions, sizes, modifiers, allergens, prices, availability, and product photos with usage rights;
- branch names, addresses, phones, hours, pickup timing, table/QR rules, and 2GIS/Google Maps links;
- promotion and promo-code rules, dates, exclusions, and customer-facing copy;
- loyalty/referral deviations from the defaults, if any;
- supported languages and approved Russian/Kyrgyz copy;
- owner/manager/staff list and branch assignments for the pilot;
- payment and receipt preferences for later provider discovery;
- privacy-policy controller details, support contacts, terms, deletion contact/URL, domain, and store-account ownership;
- final approval of P0 flows, screen copy, demo data, and acceptance devices.

Until these inputs arrive, placeholders must be labelled as demo content and must not be presented as approved brand assets.

## MVP Success Criteria

- The mobile P0 prototype passes the acceptance criteria in `UX_UI_BRIEF.md` without a backend.
- The approved backend can create real pilot users, products, orders, points, referrals, promos, and admin edits without exposing secrets.
- Owner, manager, and barista access is role- and branch-scoped.
- Branch-specific unavailability and promotion eligibility are enforced consistently in UI and API.
- The owner can operate the pilot from `admin/` without developer help for routine content and order work.
- Demo-only providers, the two-company showcase, and future integrations are clearly distinguished from production capability.

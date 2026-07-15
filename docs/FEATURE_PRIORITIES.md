# SweetTime Feature Priorities

## Scope Rule

P0 is a **single-chain SweetTime pilot**. `company_id` remains in the architecture for future reuse, while the SweetTime/CoffeeGo showcase remains demo-only. A feature is not complete merely because a mock screen or extension point exists; it must pass the acceptance criteria for its phase.

## P0: Required For Sellable Pilot

### Customer Mobile

- Branded five-tab shell: Home, Catalog, QR, Cart, Profile.
- Persistent RU/KG/EN application-language selection available to guests and authenticated customers; complete static-copy localization is required before pilot acceptance.
- Guest branch selection, menu browsing, product configuration, and local cart.
- Authentication gate before checkout or personal data; Google Sign-In uses a backend-verified ID-token/session exchange, followed by a required strict `+996` + nine-digit contact number before checkout. The number remains unverified and cannot be used for login until a real SMS provider is connected; no public demo OTP may create a customer session.
- Catalog, independent multi-select categories, search, a composable filled-heart Favorites filter/product hearts, product details, sizes, sugar, ice, toppings, allergens, and branch-specific availability.
- Branch information: address, hours, phone, open state, and 2GIS/Google Maps links.
- Cart, promo-code validation, loyalty estimate, and checkout.
- Pickup now, scheduled pickup, and QR-table order.
- Named demo payment, cash, and QR demo payment, with payment state separate from order state.
- Order confirmation/status, history, and reorder.
- Loyalty wallet and point ledger: `1 point = 1 KGS`, earn `5%`, spend up to `30%`, expire after 12 months.
- Permanent six-digit loyalty/referral QR, manual code fallback, one-time inviter binding, invited bonus 50, inviter bonus 100 after the first `completed` order.
- Scanner torch control with explicit on/off/unavailable states on supported devices.
- Active localized news stories on Home under "Узнайте, что у нас нового"; product categories remain in Catalog and are not duplicated on Home.
- Active promotions and promo codes; empty or ineligible promotion blocks stay hidden.
- Guest/auth/profile surfaces; customer editing for first/last name, optional birth date and avatar;
  one compact Points destination; grouped support/FAQ/sign-out; and in-app account deletion flow.
- Loading, empty, validation, error, offline, expired-session, camera-permission, and deletion states.

### Backend And Admin

- FastAPI OpenAPI contract for only approved P0 flows.
- Typed SQLAlchemy 2 models and migrations with future-ready `company_id`.
- Auth/session/customer-profile/avatar/favorites/account-deletion APIs and role/branch permissions.
- Catalog, branch, availability, order, payment-demo, loyalty, referral, promo, and promotion APIs with business-rule tests.
- Canonical custom Next.js admin in `admin/`; `admin-legacy/` remains archive-only.
- Owner/manager/barista login and access boundaries.
- Fast order queue and allowed lifecycle actions: `new -> preparing -> ready -> completed`, plus `cancelled`; `awaiting_payment` is used only when payment confirmation is required.
- Menu/category/modifier, branch/availability, staff/role, promotion/promo-code, customer, loyalty, and referral operations required for the pilot.
- Owner/manager-only news management: localized content, media/accent, CTA, scheduling, ordering, publish/archive state, and server-enforced company scope. Barista access is forbidden.
- Owner-managed real support-contact configuration; absent contacts must remain visibly unavailable
  rather than being replaced with demo phone/email values.
- Tenant and branch isolation tests even though production P0 serves only SweetTime.

## P1: Strong Demo Additions

- Demo/MVP-light recurring "daily drink" with clearly labelled mock prepayment.
- Push token registration, preference UI, and named mock push task.
- Richer dashboard counters and pilot analytics.
- Richer favorite collections/recommendations beyond the P0 Catalog filter.
- Optional first-run educational onboarding beyond the minimal P0 introduction.

## Production After Pilot Approval

- Production SMS/email OTP providers and delivery monitoring.
- Real MBank QR, Элсом, О!Деньги, bank-card, and fiscal-receipt providers.
- Hosted privacy policy, terms, support URL, and deletion-request URL.
- Monitoring, backups, incident handling, and production data migration.
- Play Console and Apple Developer setup, signing, Internal Testing, and TestFlight.

## Future / Paid Extensions

- Social providers other than the owner-approved Google Sign-In path.
- Delivery, saved delivery addresses, courier tracking, and Yandex Delivery.
- Customer review submission/moderation; P0 may show approved static testimonials only.
- POS/cash-register integration.
- Excel/PDF reports, audit logs, advanced analytics, and segmentation.
- Telegram staff bot.
- Full white-label/SaaS tenant management, company switcher, onboarding, billing, subscriptions, and custom domains.

## Explicit Non-Goals For P0

- Delivery logistics or delivery-address management.
- Production social login, real payment, fiscal, messaging, map, or POS integrations without approved providers and credentials.
- Review submission or public user-generated content.
- Full SaaS tenant self-service or production multi-company operation.
- Treating the two-company demo, mock providers, generated assets, or demo credentials as production behavior.
- Polishing later backend/admin scope at the expense of completing and approving the mobile P0 experience.

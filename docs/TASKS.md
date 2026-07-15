# SweetTime Status Backlog

Updated: 2026-07-15. Work is sequential unless the owner explicitly approves a skip.

## Status Rules

- `[x]` means the task's documented acceptance is complete.
- `[ ] [next]` is the first task to execute.
- `[ ] [partial—verify]` means scaffold/demo work exists but is not accepted until code and checks confirm it.
- `[ ] [partial—verified]` means the existing slice was inspected, but known gaps still block phase acceptance.
- `[ ] [blocked—owner input]` requires a business decision or asset.
- Demo screenshots, routes, mocks, or extension points alone do not prove production completion.

## Current Execution Queue — S5.3/S5.4 to S7

This is the short operational list shared by Claude Code and Codex. Detailed phase acceptance
below remains authoritative; this section records the current execution order.

- [ ] **S5.3 backend — customer persistence.** **[partial—verified locally]** Production API now
  has customer favorites, order history, recurring orders and server avatar storage, with Alembic
  revisions and manual auth/tenant checks. Product sizes/toppings and OrderItem V2 now use stable
  IDs; new order prices/display snapshots are server-owned, while legacy V1 orders remain readable.
  Before release: add isolated PostgreSQL endpoint tests, commit the shared dirty worktree and
  deploy/migrate the server.
- [x] **S5.3 Flutter — personal data and device draft.** **[verified locally]** Server avatar
  and favorites are connected. Cart is stored locally by stable IDs, restored after the current
  catalog loads, repriced from current catalog data and covered by restart/stale-data tests. Server
  order history is loaded after session restore/login: V1 stays display-only and V2 exact reorder
  resolves only current stable IDs against an authoritative server catalog, reprices every line and
  fails atomically on any conflict. Recurring orders now load/save/cancel through the customer API,
  keep stable product/branch IDs, trust server `paidUntil`, and retain honest demo-payment wording.
  Home, Catalog, product detail and exact reorder share a single top add-to-cart notice; rapid actions
  replace the active notice instead of building a queue, and the controller rejects unavailable or
  stale selections before reporting success. Flutter checks pass locally; server rollout remains S7.
  Photo is intentionally server-side now, not a device-only picker file.
- [ ] **S5.4 — Google identity + required contact phone.** **[partial—verified locally]** Backend now
  verifies Google ID tokens with `google-auth`, checks the configured `aud`/`azp`, keys identities by
  stable tenant/provider/`sub`, and issues SweetTime tokens without persisting the Google credential.
  Google-only customers start with `phone=null`; strict Kyrgyz contact entry is required before
  checkout but remains unverified and is not a login factor until a real SMS provider exists. Flutter
  uses `google_sign_in` v7, removes the offline `1111` session fallback, preserves the cart/typed return
  to checkout, blocks duplicate/racing auth actions and signs the provider out best-effort on failures
  or logout. Backend 42 tests, Flutter 50 tests, analyze, debug APK build, PostgreSQL migration and
  Compose config pass locally. The real Web, Android debug and Android release OAuth clients now exist;
  Flutter/backend use the Web client as the token audience and authorize both Android presenters. The
  final Android/iOS identifier is `kg.sweettime.app`; release signing is fail-closed and no longer falls
  back to the debug key. Before acceptance: create the ignored local `android/key.properties`, build and
  verify a release signed by the existing upload key, deploy migration `f5a9c2e41d07`, then run a
  physical-device HTTPS Google sign-in/contact/checkout test. An iOS OAuth client and URL scheme remain
  future iOS-release work. SMS verification remains a later provider task.
- [ ] **S6 — Ubuntu deployment artifacts.** **[partial—verified locally]** `backend/api/Dockerfile`
  and `deploy/production/` contain PostgreSQL, Redis, backend, nginx, media volume and an environment
  example. PostgreSQL/backend/nginx now have ordered healthchecks; `/ready` probes the real database.
  Production config rejects placeholder secrets, wildcard/non-HTTPS CORS, mock OTP and demo seed;
  migrations run as a one-shot service, the API starts without known demo accounts, `.env` is ignored,
  and nginx binds to host loopback by default for a future TLS reverse proxy. Versioned PostgreSQL +
  media snapshots now use a short write-maintenance window, checksums and a non-destructive disposable
  restore drill; off-host copy is append-only and requires an explicit target. Still required: real
  production secrets, execution of the locally verified one-shot real owner/catalog bootstrap on the
  target, a real independent off-host destination with retention/encryption policy, avatar privacy
  decision, fully pinned Docker runtime dependencies/image digests, admin deployment decision, and
  validation on the target Ubuntu host. The TLS/domain/loopback-port topology is now approved and active.
- [ ] **S7 — deploy to physical server.** **[in progress]** Target is
  `ranex@81.88.192.41`; `/srv/sweetime/media`, `/srv/sweetime/backups` and
  `/srv/projects/sweetime` are prepared. Host Nginx and the valid Let's Encrypt certificate now route
  `lnp-corporation.duckdns.org` to loopback `127.0.0.1:8080`; HTTP returns the expected HTTPS redirect
  and HTTPS currently returns the expected `502` because the SweetTime stack has not started. The repo's
  Compose mapping intentionally exposes container Nginx as `127.0.0.1:8080:80`, then proxies API traffic
  to backend port 8000; it must not be replaced with a direct `8080:8000` mapping. Host Nginx now limits
  uploads to 11 MiB and denies `/media/temp/`; its syntax/reload and free loopback port were verified by
  the owner. The final media alias uses `^~`, disables autoindex, omits the incompatible `try_files $uri`
  and sends immutable/nosniff headers. UUID-versioned media URLs make the 30-day immutable cache safe.
  Git snapshot `352f161` was uploaded as a secret-free archive, its SHA-256 was verified on the host and
  it was extracted into `/srv/projects/sweetime`. Target preflight passed: Ubuntu, Docker/Compose,
  Nginx/TLS, writable storage, 21 TiB free space and the free loopback port are suitable. UFW is inactive
  while existing services expose ports 3000 and 9090; any firewall hardening needs a separate audited
  change so Nton, Cockpit and SSH are not broken. Production `.env` is mode 600, contains no placeholders
  and passes `docker compose config --quiet`; UID/GID match `ranex` at 1000:1000. The backend image built
  successfully as `sweettime-backend:local`. PostgreSQL started healthy, Alembic migrations completed and
  the fail-closed one-shot bootstrap created the real SweetTime tenant/catalog and first owner with exit
  0. The main stack then started successfully: backend is healthy, loopback and public HTTPS `/ready`
  return 200, company config returns the real SweetTime tenant and `/media/temp/` returns 403. Redis/nginx
  subsequently became healthy. Global staff login returned 200 for the real owner with role `owner`,
  company `sweettime` and both token types present without exposing their values. After the owner confirms
  the generated password is stored safely, the plaintext bootstrap secret was removed. Initial verified
  snapshot `20260715T125752Z` was created with a valid PostgreSQL custom dump at Alembic `f5a9c2e41d07`,
  a valid empty-media archive and checksums; all services returned healthy and public `/ready` returned
  200. The disposable restore drill, an independent off-host copy and mobile Google HTTPS QA remain undone.

## Audit Snapshot — 2026-07-12

- Flutter: `flutter analyze` and `flutter build apk --debug` pass; `flutter test` fails because the only widget test mounts `SweetTimeApp` without `ProviderScope`.
- Flutter implementation: feature folders and `go_router` are present, but the canonical P0 surface map still has partial and missing flows/states. API repositories are not implemented and `lib/core/api_client.dart` is currently unused.
- Admin: `pnpm typecheck` and `pnpm build` pass; `/login`, `/`, `/orders`, `/menu`, `/branches`, `/staff`, and `/settings` respond 200 in the restored dev server. Persistence, server authorization, and automated tests remain incomplete.
- Backend: SQLAlchemy 2 typed declarations are verified, but Alembic revisions are absent. `pytest` could not run because no prepared Python environment/dependencies exist.
- Security: `backend/app` has critical RBAC, tenant/branch isolation, refresh-token, server-side pricing, status-idempotency, loyalty, and referral defects; it is not pilot/production ready. `backend/app_demo` is local demo-only.
- Infrastructure: Compose targets incompatible backend/admin contracts, expects a missing `admin/Dockerfile`, uses stale Vite variables/ports, and is not a working full-stack path.
- Repository: no `.git` exists in the project or parent folders, so there is no reliable history, diff, rollback, or root CI baseline.

## Fresh Verification — 2026-07-13

- Direct owner-requested demo-admin slice is implemented: staff invite has a separate required
  name, ASCII email validation and inline name editing; branches have client/API creation; menu
  has category chips; dashboard cards open detailed demo analytics for payments, recurring
  plans, popular products and customer activity.
- Admin `pnpm typecheck` and production build pass. `/login`, `/`, `/staff`, `/branches`,
  `/menu`, `/orders`, and `/settings` return 200 after a clean dev-server restart.
- Demo API health is green; live OpenAPI exposes GET/POST branches. The SweetTime demo history
  currently contains 52 orders with `paymentMethod` values (`cash`, `mock`, `qr`).
- This slice remains demo-only: staff and recurring orders are local mocks, customer analytics
  groups by `customerName`, and `paymentMethod` is not a production payment status. Visual owner
  review of the new interactions is still required.
- Direct owner-requested Flutter UX slice is implemented for review: the QR scanner exposes a
  real torch toggle with unsupported/error states; the duplicate Home category rail is replaced
  by an active-news story rail and full-screen viewer; RU/KG/EN can be selected from Home/Profile
  and persists locally. The owner confirmed the torch on a physical Android device and accepted
  the Home news block. A follow-up performance pass now stops the native scanner outside the
  active Scan tab, resizes image decoding to the rendered card, narrows Home state subscriptions,
  caches ThemeData, removes expensive theme interpolation, and shortens tab feedback animation.
  The owner confirmed the first correction, then later reported renewed Home/Catalog jank while a
  debug/JIT APK with Vulkan validation was installed on the Redmi Note 9 Pro. The follow-up pass
  removed scroll-sensitive `SliverLayoutBuilder` wrappers from both grids, narrowed Catalog/Profile/
  News state subscriptions, prebuilds a bounded number of rows, removes synchronous avatar file I/O
  from `build`, and bounds detail-image decode. A fresh profile APK is now installed for owner QA.
  The current
  Flutter UI and demo company content are fully localized for RU/KG/EN with stable category/
  modifier IDs and legacy/localized API mapping. The latest Profile slice moves favorite drinks
  into a composable Catalog filter; adds first name, last name, optional birth date and session-only
  camera/gallery avatar editing; and reduces Profile to one Points entry plus recurring order,
  history, addresses, support, FAQ, sign-out and deletion. `flutter analyze`, all 21 tests and the
  profile APK pass. Physical camera/gallery QA on Android/iOS, responsive/text-scale QA, persistence
  API work and final visual approval remain open.
- The owner-requested auth/order boundary is implemented for review. Guests can browse and build a
  cart, but Cart, direct `/checkout`, local `checkout()` and API `submitOrder()` all reject guest
  order creation. Auth preserves the cart and returns to Checkout through a closed typed destination.
  Kyrgyz phone input owns `+996`, accepts exactly nine subscriber digits, formats `XXX XXX XXX`, and
  normalizes to `+996XXXXXXXXX`. The misleading Apple action is removed and Google no longer starts
  demo SMS or creates a local session. A 2026-07-15 follow-up implements the backend Google ID-token
  exchange, provider identity migration, required unverified contact step and checkout gate; live
  Google Sign-In now remains blocked only on final identifiers/signing, real OAuth clients, deployment
  configuration and physical HTTPS QA. All 50 Flutter tests, analyze and a fresh debug APK build pass.

## Phase 0 — Product And Design

- [x] **Task 0 — Repository audit and correction plan.** Documentation, Flutter, backend, admin, legacy prototypes, infrastructure, tests, and visual references were inspected; results are summarized above.
- [x] **Task 1 — Product And UX Requirements Pack.** Core scope, roles, flows, mobile surfaces, state matrix, responsive criteria, exclusions, owner inputs, and phased acceptance reconciled in the five core docs.
- [ ] **Task 2 — Reconcile the canonical Design System.** **[next]** Documentation only:
  - make the approved design direction unambiguous and mark older screenshots/recommendations as legacy;
  - align `docs/design/DESIGN_SYSTEM.md`, `DESIGN_COMPARISON.md`, `REFERRAL_LOGIC.md`, `ADMIN_PANEL.md`, and `DEMO_API.md` with single-chain P0 and demo-only multi-company behavior;
  - specify five-tab navigation, permanent six-digit QR, auth gates/providers, approved order/payment states, promotion/availability components, and all state variants;
  - complete 320/360/390/430, safe-area, keyboard, text-scale, and 44px target guidance;
  - link the canonical design docs from required agent-reading lists; do not change application code.
- [ ] Produce or update visual references for P0 surfaces and states not represented by a current approved screenshot: launch/introduction, branch detail, promotions, email-code auth, order status, order history/reorder, loyalty ledger, settings, and deletion states.
- [ ] **[blocked—owner input]** Collect and approve brand/business inputs listed in `PROJECT_BRIEF.md`; label all interim content as demo.
- [ ] Run owner review and formally accept Phase 0.

## Repository Hygiene — Before The Next Code Task

- [x] Repository boundary and Git baseline are initialized (`8a74eed`); generated build output and local databases are ignored. Current S5.x work remains intentionally uncommitted pending owner review.
- [ ] Mark `sweetime/` and `admin-legacy/` as reference/archive surfaces and remove them from active build/deploy claims.
- [ ] Reconcile root `README.md`, `.env.example`, agent guidance, ports, environment-variable names, and the chosen canonical runtime before advertising a full-stack launch command.

## Phase 1 — Flutter UI Prototype

- [ ] **[partial—verified 2026-07-13] Owner UX slice — QR torch, Home news, and RU/KG/EN.**
  Flutter UI, local demo news, routing, language persistence, focused widget tests, compact Profile
  controls, filled bottom-navigation icons and the first performance correction are present.
  Android torch behavior and the first scrolling/tab/theme/language correction were owner-confirmed.
  A later debug-build report triggered the second measured code pass described above; final smoothness
  now requires owner confirmation on the installed profile APK. All current static screens and demo
  products/categories/modifiers/branches/promotions
  are localized for RU/KG/EN. Before acceptance: physically verify camera stop/resume outside Scan,
  validate iOS camera behavior, verify 320/360/390/430 layouts and text scaling, and obtain owner
  visual approval. Categories remain available in Catalog.
- [ ] **[partial—verified 2026-07-13] Owner Profile UX slice.** Favorite drinks are no longer
  duplicated in Profile: Catalog has an independent filled-heart Favorites filter without an
  overlaid checkmark, supports simultaneous multi-category selection, composes with search, and
  updates immediately when a heart is toggled. Authenticated Profile has a compact
  identity card, one protected Points route, recurring order/history/addresses, and one Help and
  account section for support, FAQ and sign-out. Profile edit covers required first/last name,
  optional birth date, gallery/camera/remove-avatar actions and protected deep links. The avatar is
  explicitly session-only and support contacts are explicitly unconfigured in this mock-first phase.
  Before acceptance: owner visual review, physical Android/iOS gallery/camera/permission QA,
  responsive/text-scale QA, and approved persistence/upload contracts.
- [ ] **Task 3 — Flutter Architecture Plan.** Inspect current code and create `docs/FLUTTER_ARCHITECTURE.md` covering feature folders, routing, explicit state boundaries, domain/DTO separation, repository interfaces, named mock/API providers, design-system placement, and tests.
- [ ] **[partial—verified]** Existing feature split, five-tab shell, QR flow, shared demo data, theme,
  demo/API bootstrap and legacy/localized mapping are present. Repository/provider separation and
  an explicit user-visible offline/demo mode are still missing; silent fallback is not a production
  integration.
- [x] Existing scaffold has a small `lib/main.dart`, feature folders, and `go_router`; Task 3 must still document and validate the final boundaries/deep-link behavior.
- [ ] Define mock-first repository interfaces and separate mock/API implementations; demo/offline fallback must be explicit, not silent production behavior.
- [ ] **Task 4 — Complete all P0 Flutter surfaces** from `UX_UI_BRIEF.md`, including guest/auth return-to-checkout, branch availability, promo, order lifecycle, loyalty ledger, referral, settings, and deletion.
- [x] **[verified local prototype 2026-07-13]** Guest Cart -> Auth -> Checkout preserves cart state;
  direct Checkout and both local/API order methods reject guests. Auth cancellation clears the
  pending return destination. Phone input is limited to fixed `+996` plus exactly nine digits and
  normalized independently of display spacing. This is a client prototype gate; the public demo
  API is not server-side authorization and must not be used as production order security.
- [ ] Fix audited flow blockers: guest checkout/demo points, incomplete account deletion reset, premature referral reward, quick-add/reorder availability bypass, unknown-product crash, lost checkout comment, and closed-branch handling.
- [x] **[local prototype]** Login no longer assigns every customer the demo name or balance; sign-out
  clears private session data, and demo deletion clears profile, points, referral binding, orders,
  favorites, cart and recurring-order state. Server-side session restoration/deletion is still Phase 2.
- [x] Remove misleading provider behavior: Apple is absent and Google never invokes demo SMS or
  authenticates locally; until OAuth is configured it shows a localized unavailable state.
- [ ] Add the P0 email one-time-code path and implement real promo validation behavior in the prototype.
- [ ] **[blocked—owner/cloud/backend input]** Activate real Google Sign-In only after approving the
  final Android application ID and iOS bundle ID, configuring debug/release/Play SHA OAuth clients
  and the web/server client audience, and implementing a backend token exchange/session. Do not
  accept client-supplied email/name as proof of identity or use Google success as a local-only login.
- [ ] Implement every loading/empty/validation/error/offline/session/camera/deletion/payment state in the state matrix.
- [ ] Verify responsive Android/iOS layouts at 320/360/390/430 widths, safe areas, keyboard, text scale, and minimum tap targets.
- [ ] Evaluate frame smoothness only in profile/release mode, never from a debug/JIT APK. Capture
  first-scroll and warmed steady-scroll traces before renderer or visual-quality compromises.
- [x] Add widget/domain coverage for guest cart -> auth -> checkout return, bounded Kyrgyz phone
  input and guest order rejection.
- [ ] Add remaining widget/smoke tests for navigation, modifier pricing, unavailable branch/product,
  QR permission/manual fallback, order status, and account deletion states.
- [x] Add iOS camera and photo-library usage descriptions for QR and profile-photo flows.
- [ ] Complete accessibility semantics/contrast QA and a migration plan away from the deprecated
  `mobile_scanner` 6 Gradle integration.
- [x] **[verified 2026-07-13]** Complete typed RU/KG/EN Flutter localization resources now cover
  Auth, Home/news, Catalog, Product, Cart, Checkout, QR, Profile/history and recurring-order UI.
  Current demo menu/branch/promotion content is localized domain data; fallback and persistence are
  tested. Unknown future backend content still requires the explicit localized API contract below.
- [x] **[verified 2026-07-13]** `flutter analyze`, all 24 tests and the fresh profile APK pass; the old
  `ProviderScope` failure and global-router test leakage are fixed. Keep these checks green after
  every change. The auth-slice APK is installed on Redmi Note 9 Pro `f3bff2a5` for physical acceptance.
- [ ] **[blocked—owner input]** Add final app icon and approved product/brand assets only after Task 9 inputs are supplied; keep organized placeholders until then.

## Phase 2 — Backend MVP

- [ ] **Task 5 — Backend Foundation Cleanup.** Choose and document one canonical FastAPI production application; keep any SQLite/demo application explicitly local/demo-only.
- [ ] **[partial—verified]** SQLAlchemy 2 `Mapped`/`mapped_column` and typed relationships are present. Direct/indirect tenant ownership and every query path still require a tenant-scope audit and correction.
- [ ] Add and test Alembic revisions from an empty PostgreSQL database; make seed data idempotent and demo/pilot datasets distinct.
- [ ] Add refresh-token persistence/revocation, logout/session expiry, secure settings, and account-deletion behavior.
- [ ] Add the approved Google identity exchange to the canonical backend: verify Google ID-token
  signature, issuer, audience, expiry and verified email; key identity by provider + `sub`; apply
  safe account-linking/tenant rules; then issue, rotate and revoke SweetTime sessions. Never derive
  staff/admin roles from a Google email.
- [ ] Define named OTP, payment, receipt, and notification provider interfaces; use mock providers until credentials and commercial terms are approved.
- [ ] Tighten resource-, role-, company-, and branch-level permissions; never serialize password hashes or secrets.
- [ ] Replace generic admin CRUD/mass assignment with endpoint-specific schemas and permissions; prevent staff role escalation and sensitive resource reads.
- [ ] Reject refresh tokens on access-token endpoints; persist, rotate, revoke, and test refresh sessions and logout.
- [ ] Recalculate totals/modifiers/availability server-side, enforce allowed order transitions and idempotent completion/refund, and exclude expired loyalty entries.
- [ ] Add PostgreSQL integration tests for startup, auth, catalog, availability, order creation, and isolation.
- [ ] **Task 6 — Backend P0 API Completion.** Implement or reconcile auth, branches, categories, products/modifiers, availability, orders, demo payments, loyalty, referral, promo/promotion, reorder, and deletion APIs.
- [ ] Add an authenticated customer-profile contract for `first_name`, `last_name`, optional
  `birth_date`, avatar object key/URL and favorites. Define validated image upload/replacement/
  deletion, authorization, storage limits, privacy retention and account-deletion cleanup; never
  persist a device-local picker path as the avatar identity.
- [ ] Make localized catalog IDs explicit: categories and every modifier option return stable `id`
  plus `name: {ru, ky, en}`; products, branches and promotions return localized fields without
  deriving identity from a Russian label, list position or slug. Add rename/reorder and translation-
  completeness contract tests before replacing demo content.
- [ ] Add the approved news feed contract with `company_id`, localized title/body/badge/CTA,
  serializable visual/media fields, publish/start/end state, and sort order. Public reads return
  only active company news; create/update/publish/archive/delete require owner or manager and deny
  barista server-side, with tenant/role tests.
- [ ] Normalize order lifecycle to `awaiting_payment -> new -> preparing -> ready -> completed`, with separate `cancelled` and payment status; migrate demo aliases rather than exposing two contracts.
- [ ] Test loyalty `1 point = 1 KGS`, earn 5%, spend max 30%, 12-month expiry; referral one-time binding, +50/+100 trigger, idempotency, and anti-fraud limits; promo and availability edge cases.
- [ ] Verify OpenAPI matches the approved mobile/admin contracts and no demo document promises an unchanged production contract without evidence.

## Phase 3 — Custom Next.js Admin MVP

- [x] Canonical admin decision: develop `admin/`; keep `admin-legacy/` archive-only.
- [ ] **Task 7 — Admin MVP.** **[partial—verified 2026-07-13]** Login, expanded clickable
  demo analytics, order queue, menu/modifiers/availability and category filters, branch editing/
  creation, staff invite/name editing, and settings screens exist and build. Sessions/RBAC remain
  client-only; staff/recurring are mocks and several writes remain optimistic or demo-only.
- [ ] Connect admin to the canonical API and implement real owner/manager/barista sessions and permission-aware navigation.
- [ ] Let the owner configure real support contacts/availability in pilot settings; mobile must not
  invent phone, email or chat availability when this configuration is absent.
- [ ] Reconcile order actions with the canonical lifecycle and payment state; allow only valid transitions and make mutations idempotent.
- [ ] Complete product/category/modifier editing and branch-specific availability controls.
- [ ] Complete branch, staff/role, promotion/promo-code, customer, loyalty, referral, and owner-only pilot settings operations.
- [ ] Add owner/manager-only News management in `admin/`: list, create/edit, translation
  completeness, media/accent/CTA, preview, scheduling, ordering, publish/archive/delete. Navigation
  hiding and client `RoleGate` are UX only; the canonical API must enforce permissions.
- [ ] Enforce company/branch scope server-side and add isolation/permission tests; the two-company view remains a demo scenario, not production SaaS.
- [ ] Align scripts, environment variables, ports, Docker configuration, and README with the custom Next.js stack.
- [ ] Keep admin typecheck and production build green; add unit/E2E/accessibility tests and verify authenticated role/branch flows before acceptance.

## Phase 4 — Integration, Brand, Pilot, And Release

- [ ] **Task 8 — Mobile API Integration.** Connect repository implementations for auth, config, catalog/branches, orders/history/status, loyalty/referral, promotions, and deletion while retaining an explicit mock/demo mode.
- [ ] Store tokens securely, handle expiry/revocation, prevent duplicate checkout/payment submissions, and make network errors conform to the state matrix.
- [ ] Add end-to-end contract tests for Flutter -> API -> admin order processing and status refresh.
- [ ] **Task 9 — Brand And Content Replacement.** **[blocked—owner input]** Replace app name/logo/colors/menu/photos/modifiers/branches/maps/promotion copy and seed data only with approved owner assets.
- [ ] Validate content rights, Russian/Kyrgyz copy, allergens, prices, hours, roles, and branch availability with the owner.
- [ ] Configure deployment, TLS, environment separation, backups, monitoring, recovery notes, and a staff pilot runbook.
- [ ] Configure Android pilot application id/signing and produce an APK/AAB after Phase 1–3 acceptance.
- [ ] Run an owner/staff pilot on target Android devices and record accepted flows, defects, and future-integration pricing.
- [ ] **Task 10 — Release Checklist.** Document Android/iOS identifiers, signing, permissions, store accounts, screenshots, metadata, privacy disclosures, support ownership, and deployment responsibilities.
- [ ] Prepare hosted privacy policy, terms, support URL, and deletion-request URL with owner/legal approval.
- [ ] Replace mock OTP/payment/receipt providers only after credentials, costs, terms, and test environments are approved.
- [ ] Verify production monitoring/backups and remove demo credentials, placeholder claims, and generated brand assets from production configuration.
- [ ] Prepare Google Play Internal Testing first; prepare iOS/TestFlight only after Apple account, bundle id, legal assets, support URL, and deletion links are ready.

## Guardrails / Not P0

- [x] Delivery, delivery addresses, review submission, social providers other than the approved
  Google path, real payments, full SaaS tenant management, subscription billing, advanced
  analytics/exports, POS, and staff bots are explicitly outside P0.
- [x] Recurring "daily drink" is classified as P1 demo/MVP-light and cannot block P0 acceptance.
- [x] Mock providers and the SweetTime/CoffeeGo two-company showcase are labelled demo-only and must not be sold as production integrations or SaaS readiness.

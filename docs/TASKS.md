# SweetTime Status Backlog

Updated: 2026-07-16. Work is sequential unless the owner explicitly approves a skip.

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

- [ ] **S5.3 backend — customer persistence.** **[partial—verified on production]** Production API now
  has customer favorites, order history, recurring orders and server avatar storage, with Alembic
  revisions and manual auth/tenant checks. Product sizes/toppings and OrderItem V2 now use stable
  IDs; new order prices/display snapshots are server-owned, while legacy V1 orders remain readable.
  The revision is committed, deployed and migrated through `b91e7c4a2d10`; physical Android QA
  confirmed profile/avatar/favorites/history/recurring persistence and full account deletion.
  Remaining acceptance gap: isolated PostgreSQL endpoint tests for these customer flows.
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
- [x] **S5.4 — Google identity + required contact phone.** **[verified Android production pilot]** Backend now
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
  back to the debug key. A production release APK was successfully
  built with the upload keystore, verified as package `kg.sweettime.app` and release SHA-1
  `51:DC:A2:E5:1D:37:6E:BB:B1:B7:E8:A8:A8:77:8A:2D:D4:92:16:54`, installed and launched on the Redmi
  Note 9 Pro. Physical QA confirmed Google profile/contact/avatar/history/recurring persistence, then
  exposed two release defects: account deletion was local-only and QR camera crashed inside ML Kit after
  R8. The fixes now add transactional server deletion (profile/identity/media removed; financial ledgers
  anonymized), invalidate old tokens, recreate the same Google subject as a fresh phone-less customer,
  and keep nested ML Kit classes in release builds. Backend 43 tests, Flutter 52 tests, analyze, a
  disposable PostgreSQL migration to `b91e7c4a2d10`, and signed release APK build pass locally. The revision
  is deployed and physical QA confirmed delete→same Google login→required contact creates a clean account
  without previous profile/avatar/favorites/history/recurring data. The rebuilt APK also
  passed Redmi release smoke for QR preview initialization, torch, tab leave/re-entry, and launching the
  external profile camera without an ML Kit crash. An iOS OAuth client and URL scheme remain future iOS-release work. SMS
  verification remains a later task.
- [ ] **Reliable mobile order submission + automatic admin queue.** **[implemented locally
  2026-07-16; production rollout and physical end-to-end acceptance pending]** Flutter no longer
  creates a local successful order before the API responds: checkout is server-first, refreshes an
  expired access token once, preserves the cart and points selection on every failed/ambiguous
  request, and clears them only after PostgreSQL confirms the order. Every new APK request has a
  stable high-entropy `clientRequestId`; backend request fingerprinting, per-company row locking and
  unique database constraints make retries and concurrent numbering safe. New orders start in
  `new`, not the false `preparing` state. Admin now opens an authenticated header-based SSE stream:
  committed create/status mutations wake a tenant-scoped GET reconciliation almost immediately,
  while non-overlapping 15-second polling, reconnect/focus and a replay-window reconciliation remain
  recovery paths. JWT is never placed in the event URL, an SSE connection does not retain a database
  session, and PostgreSQL remains authoritative. Migration `a842d9c13f70`, backend 61/61, Flutter
  60/60, admin 8/8, a real PostgreSQL+HTTP SSE smoke, static analysis, nginx syntax and isolated
  production images pass locally. Remaining:
  deploy backend/admin with the migration, install the new APK and prove one real
  Flutter→API→PostgreSQL→admin order plus a safe retry on the production pilot.
- [ ] **S6 — Ubuntu deployment artifacts.** **[partial—verified in production; next: admin content acceptance]** `backend/api/Dockerfile`
  and `deploy/production/` contain PostgreSQL, Redis, backend, nginx, media volume and an environment
  example. PostgreSQL/backend/nginx now have ordered healthchecks; `/ready` probes the real database.
  Production config rejects placeholder secrets, wildcard/non-HTTPS CORS, mock OTP and demo seed;
  migrations run as a one-shot service, the API starts without known demo accounts, `.env` is ignored,
  and nginx binds to host loopback by default for a future TLS reverse proxy. Versioned PostgreSQL +
  media snapshots now use a short write-maintenance window, checksums and a non-destructive disposable
  restore drill; off-host copy is append-only and requires an explicit target. Still required: real
  production secrets, execution of the locally verified one-shot real owner/catalog bootstrap on the
  target, a real independent off-host destination with retention/encryption policy, avatar privacy
  decision and fully pinned Docker runtime dependencies/image digests. Backend validation, TLS/domain,
  loopback routing, backup and restore drill are complete on the target. The Next.js admin now has a
  non-root standalone Dockerfile, fail-closed HTTPS build arg, internal-only Compose service, combined
  backend/admin healthcheck and nginx routing for `/login` plus `/admin` redirect. Typecheck, Docker build,
  disposable PostgreSQL→backend→admin→nginx smoke and security-header checks pass locally. The admin image
  is now deployed internally on the physical server: public `/login` and `/ready` return 200, `/admin`
  redirects to the HTTPS `/login`, temporary media remains 403, and all five production services are healthy.
  Authenticated owner login is physically verified; reversible admin→API→mobile content acceptance remains
  before this slice is approved.
- [x] **S7 — deploy backend to physical server.** **[verified production]** Target is
  `ranex@81.88.192.41`; `/srv/sweetime/media`, `/srv/sweetime/backups` and
  `/srv/projects/sweetime` are prepared. Host Nginx and the valid Let's Encrypt certificate now route
  `lnp-corporation.duckdns.org` to loopback `127.0.0.1:8080`; HTTP redirects to HTTPS and the live
  SweetTime backend is available through the production TLS route. The repo's
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
  200. A disposable PostgreSQL restore drill then passed at the same Alembic head/media count, removed its
  temporary container and left production healthy. Revision `761b7b6` is deployed at Alembic
  `b91e7c4a2d10`; public `/ready` returns 200 and physical Android Google/contact/account-deletion QA passed.
  Archive extraction under a strict shell umask exposed unreadable image sources; commit `b9f1e46` now
  hardens backend image permissions and uses an absolute Alembic config path. An independent off-host copy
  remains a later resilience task.

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
- [ ] **Task 7 — Admin MVP.** **[partial—deployed 2026-07-15; owner login verified]** Real JWT login/refresh, permission-aware
  navigation, API-backed order queue, menu/modifiers/availability, branches, news, promotions and settings
  exist and build. The production container and TLS routing are deployed and pass unauthenticated smoke.
  Fake login credentials and recurring analytics were removed from the production surface; staff navigation
  is hidden and the direct route is read-only until server-side staff CRUD exists. Owner login works against
  production; a reversible content mutation/readback test through the live API/mobile is still required.
- [x] Connect admin to the canonical API and implement real owner/manager/barista sessions and permission-aware navigation.
- [ ] Let the owner configure real support contacts/availability in pilot settings; mobile must not
  invent phone, email or chat availability when this configuration is absent.
- [ ] Reconcile order actions with the canonical lifecycle and payment state; allow only valid transitions and make mutations idempotent.
- [ ] Complete product/category/modifier editing and branch-specific availability controls.
- [ ] Complete branch, staff/role, promotion/promo-code, customer, loyalty, referral, and owner-only pilot settings operations.
- [ ] Add owner/manager-only News management in `admin/`: list, create/edit, translation
  completeness, media/accent/CTA, preview, scheduling, ordering, publish/archive/delete. Navigation
  hiding and client `RoleGate` are UX only; the canonical API must enforce permissions.
- [ ] **[deployed 2026-07-15; admin media and phone acceptance pending] Stories,
  collections and news feed expansion.** The approved
  contract in `docs/design/NEWS_CONTENT_SPEC.md`: at most 30 active flat Home stories; editable
  RU/KG/EN story collections with names and round image covers editable after creation and support
  for at least 40 stories each (capacity, not a publication minimum);
  a permanent newest-first news feed; text/image/MP4 content; pinning, scheduling and non-destructive
  expiry; protected owner/manager media CRUD; server-side public filtering; and reversible
  admin→API→Flutter acceptance. Collections live on the dedicated News page, not on Home. Local
  PostgreSQL+HTTP acceptance passed with 41/41 unique collection stories, an edited collection name,
  and the Home response capped at 30. Production runs migration `e73c8f2a1b04`; public Home,
  collections, feed and admin login return 200, and both nginx layers accept 52 MiB multipart payloads.
  Real production image/video and Android UX remain to be checked.
- [ ] **[implemented and installed 2026-07-16; owner visual acceptance pending]
  Full-screen story and feed-media UX.** Flutter stories now use a black full-screen
  contain stage for portrait/landscape image and MP4 content, segmented 2GIS-style timed progress,
  automatic advance, left/right tap zones, and press-and-hold pause/resume. Image/text stories use
  a six-second smooth timeline; video progress is continuously animated and synchronized to the exact
  media duration. Media-only stories with blank admin fields show no invented title. Story video starts with
  system-controlled sound and pauses both playback and sound while held. The obsolete CTA and bottom
  arrows are removed. Feed-post detail now opens at 98% screen height with a 78% black media stage;
  video autoplays muted, media tap toggles sound, and the central control toggles play/pause. Collection
  results are sorted newest-first client-side as well as server-side. `flutter analyze` is clean and
  all 58 Flutter tests pass, including 45-story capacity, timed progress, hold/resume, right-tap and
  Android Back. The production release APK is installed on Redmi Note 9 Pro `f3bff2a5`; physical image,
  MP4 sound/volume and visual fit still require owner confirmation because the phone was locked during
  automated screenshot QA.
- [ ] Enforce company/branch scope server-side and add isolation/permission tests; the two-company view remains a demo scenario, not production SaaS.
- [ ] Align scripts, environment variables, ports, Docker configuration, and README with the custom Next.js stack.
- [ ] Keep admin typecheck and production build green; add unit/E2E/accessibility tests and verify authenticated role/branch flows before acceptance.
- [ ] **[fixed locally 2026-07-16; production rollout pending] Admin bootstrap HTTP 500 hardening.**
  A published media-only V2 story with blank title/body/badge made the legacy `/news` response fail
  Pydantic validation and return HTTP 500. The legacy output now accepts media-only content and always
  emits stable `{ru, ky, en}` strings. The global admin bootstrap no longer depends on that legacy route:
  its optional Settings phone-preview reads V2 stories and degrades to an empty preview without blocking
  orders/menu/branches. Idempotent GET/HEAD requests retry network/408/500/502/503/504 failures twice with
  short backoff; persistent 5xx errors no longer expose a raw `HTTP 500` message. Backend 54/54 tests,
  admin typecheck, 6/6 admin tests and isolated production Docker builds pass. Deploy backend/admin and
  verify `/api/companies/sweettime/news` returns 200 before marking complete.

## Phase 4 — Integration, Brand, Pilot, And Release

- [ ] **Task 8 — Mobile API Integration.** Connect repository implementations for auth, config, catalog/branches, orders/history/status, loyalty/referral, promotions, and deletion while retaining an explicit mock/demo mode.
- [ ] **[implemented locally 2026-07-15; physical content acceptance pending]** Admin-driven config,
  catalog, branch, news and promotion data refreshes at bootstrap, after app resume (30-second throttle),
  and by pull-to-refresh on Home/Catalog. Concurrent refreshes are coalesced; an empty server news/promotion
  list is authoritative and no longer resurrects DemoData. Flutter analyze and all 53 tests pass; the release
  APK is installed on the target Redmi for the reversible admin→mobile check.
- [ ] Store tokens securely and complete expiry/revocation. **[partial—verified locally
  2026-07-16]** Duplicate order submission and ambiguous network failure are now handled by
  server-first checkout plus `clientRequestId` idempotency; payment submission remains a separate
  future provider integration.
- [x] **[fixed and installed 2026-07-16]** Preserve authoritative empty product modifier lists and
  support products without sizes end-to-end. Flutter previously replaced an explicit server `sizes: []`
  with DemoData sizes, then sent a forbidden `sizeId`; production correctly rejected the order with 400.
  No-size products now use nullable `sizeId` in cart persistence/history/order DTOs, stale local drafts are
  normalized, and business-validation failures no longer claim that the internet is unavailable.
- [x] **[fixed and installed 2026-07-16]** Android Back follows in-app history on nested routes.
  Checkout has an explicit Back action and always falls back to the preserved Cart when opened without
  Navigator history; product/auth entry points push onto the source stack. Back from Catalog/QR/Cart/Profile
  root tabs returns to Home first, while Back from Home may exit normally. Order submission blocks accidental
  navigation until its result is known.
- [ ] **[deployed and installed 2026-07-16; owner phone acceptance pending]
  Complete order history and preparation details.** Profile now exposes one compact history entry that opens
  a dedicated scrollable route; each order opens a near-full-height detail sheet with immutable product,
  description, image, size, sugar, ice, topping, pricing, branch/address, ready-time, payment, phone and comment
  snapshots. Multi-select, select-all and trash actions hide history only on that device; PostgreSQL remains the
  source of truth and admin/kitchen records are never deleted by this UX. Admin order cards now open a responsive
  detail drawer with the same preparation data. New orders store localized snapshots and optional product image
  URLs, while legacy orders degrade without invented values. Checkout sends stable `asap`/`HH:mm`/table values
  plus the barista comment. Backend 62/62, Flutter 69/69, admin 11/11 and typecheck pass; the full Alembic chain
  succeeds from an empty PostgreSQL database through `f27a4d9c8b11`. Production now exposes the new
  product image contract; the signed release APK is installed on Redmi Note 9 Pro with existing app data preserved.
- [ ] Add end-to-end contract tests for Flutter -> API -> admin order processing and status refresh.
- [ ] **[deployed and installed 2026-07-21; owner acceptance pending]
  Repair mobile order-history hydration and refresh the admin phone preview.** A committed order is inserted
  into mobile history directly from the authoritative `POST /orders` response, then reconciled with
  `/auth/customer/me/orders`; the history page also refreshes immediately on open and keeps polling/pull refresh.
  Device-only hidden IDs are now scoped by `customer_id` instead of leaking between accounts on the same phone.
  Admin Settings no longer stretches the dark phone shell below the preview and now mirrors the current five-tab
  app structure, branch selector, hero, promotions, stories, product images, logo/background draft and accent.
  Flutter analyze is clean, full Flutter tests 88/88, admin typecheck and content tests 14/14 pass. The signed
  production APK is installed and the admin container is deployed; physical history/preview acceptance remains.
  **Follow-up 2026-07-21:** production order snapshots legitimately allow untranslated `ky`/`en` values to be
  null, but Flutter treated either missing translation as corruption and rejected the entire history response.
  The parser now keeps the required RU snapshot and uses it as the display fallback for pending translations;
  a regression test covers product, size and topping snapshots. A replacement APK still needs to be built and
  installed before owner acceptance.
- [ ] **[implemented locally 2026-07-16; production rollout and phone acceptance pending]
  Catalog editing, rolling sessions, order refresh, promo codes and partial loyalty spend.** Admin menu
  exposes an explicit edit action, editable product data, real image upload/delete with photo preview,
  stable localized category creation/selection, and final per-size prices (the API continues to store
  a delta). Flutter order history supports pull-to-refresh without discarding the last good list on an
  error. Customer refresh sessions are server-persisted, rotated and extended to 30 days after activity;
  concurrent mobile refresh is coalesced, logout/account deletion revoke/remove sessions. Orders snapshot
  a normalized active promo code; unknown/inactive codes are rejected by the server and shown as an inline
  cart error, while admin and customer order details display the accepted code. Loyalty spend is disabled
  at zero and accepts a manually chosen amount up to the server-owned balance/30% cap. Migration chain:
  `c64f0b2d8a31` -> `b17c9e4a2f60` -> `e18d7a4c9f22`; the last migration also corrects unmistakable legacy
  full-size prices accidentally stored as deltas (for example 4000 + 3000). Backend 71/71, Flutter 75/75,
  admin typecheck and 11/11 tests pass; clean PostgreSQL migration and production Docker admin build pass.
  Catalog/admin list prices use the lowest configured final size price, and paid toppings are never
  preselected, so opening a product cannot silently raise its displayed price.
- [ ] **[implemented locally 2026-07-16; production rollout and phone acceptance pending]
  Product editor UX, reusable toppings, automatic history refresh and strict promo gate.** Product photos
  are selected through the system file picker in both create/edit modes and uploaded only after one explicit
  Save; the raw URL/path field and save-first-media step are removed. Base price is optional when final size
  prices exist and is derived from their minimum; a product without sizes still requires an explicit price.
  A tenant-owned localized topping catalog can be created once and selected into any product, while manual
  custom toppings remain available and product/order snapshots stay immutable. Settings use a local phone
  preview draft and do not update the admin shell, API or phone before the single Save succeeds. Mobile order
  history polls every 10 seconds only while visible and still supports pull-to-refresh. A non-empty promo code
  is revalidated against fresh server content before checkout and blocks navigation when invalid, inactive or
  unverifiable. Migration head `a62f1c9d4e30`; backend 72/72, Flutter 77/77, admin 14/14/typecheck, production
  Docker admin build and empty-PostgreSQL migration pass.
- [ ] **[implemented locally 2026-07-16; phone acceptance pending] Edit a configured cart line.**
  Every mobile cart card exposes an explicit localized Edit action that opens the full product constructor
  with that row's size, sugar, ice and toppings. Save replaces exactly that index, preserves quantity and
  local persistence, and never appends or merges a neighbouring row of the same product. Invalid/stale indices
  return safely to Cart. This is Flutter-only and does not require another backend migration.
- [ ] **[implemented locally 2026-07-20; production rollout and phone acceptance pending]
  White-label visual branding and content media.** Company settings persist an uploaded logo and branded
  background, while Flutter restores cached branding before the first frame and applies it to Home and News.
  Story rings use the company accent, viewed stories become neutral per tenant, video thumbnails no longer show
  a floating white play button and fall back to the business logo. Promotions support image-only and image with
  overlaid localized text. Product/size/topping display data retain RU/KY/EN, and Profile replaces fake Home/Office
  addresses with a localized list of real API branches. Migration head `b84c1a7e2d90`; backend 74/74, Flutter
  analyze plus 82/82 tests, admin typecheck plus 14/14 content tests and release APK build pass.
- [ ] **[implemented locally 2026-07-20; phone acceptance pending] Adaptive video-news viewer.** Video detail
  begins below the system status bar, fills the available width without side gutters and derives its height from
  the initialized video's native aspect ratio, capped by the safe screen height. The title overlays the lower
  video gradient; tapping it expands the localized description and date. Existing play/pause, sound toggle,
  close and Android Back behavior remains. Flutter analyze and 84/84 tests pass; release APK is built, but the
  target Redmi disconnected from ADB before installation.
- [ ] **White-label platform hardening.** Keep one tenant-aware backend and one configurable admin
  runtime for all companies; map approved custom domains to `company_id` and require Host, URL scope
  and JWT `cid` to agree. Do not create one copied backend/admin and one port pair per company.
  Add server-owned `businessType`, `enabledModules`, navigation/layout preset and design-token
  configuration. Build branded Flutter flavors (package/bundle id, icon, splash, OAuth/Firebase
  presenter and tenant bootstrap) from one shared codebase, with vertical modules/templates for
  bubble tea, coffee shop and restaurant rather than source forks. Before multiple backend replicas,
  fan out ephemeral SSE wake-ups through Redis Pub/Sub or PostgreSQL NOTIFY; durable payment/receipt
  jobs still require a transactional outbox plus a durable queue/stream.
- [ ] **Payment provider and reliable event delivery design.** Before connecting a bank/PSP, add
  separate `Order`, `PaymentAttempt`, `PaymentEvent` and transactional `OutboxEvent` records;
  persist provider IDs and idempotency keys, verify signed webhooks, tolerate duplicates and
  out-of-order events, and let a worker retry notifications/receipts. PostgreSQL remains the source
  of truth. A broker may dispatch outbox work, but Redis Pub/Sub alone must never be treated as a
  durable order or payment queue. Select Kyrgyz QR/acquiring and international card providers only
  after merchant eligibility, API/sandbox access, fiscal receipt responsibilities, settlement,
  refunds, chargebacks, commissions and contracts are confirmed.
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

# SweetTime Implementation Phases

## Working Rule

Phase completion is based on reviewed acceptance criteria, not on the presence of scaffold or demo code. Existing Flutter, backend, demo API, and admin work should be audited and reused where it matches the approved phase; it does not authorize skipping earlier gates.

The P0 release target is one SweetTime chain. `company_id` and the SweetTime/CoffeeGo demo preserve a future white-label path but do not make production SaaS part of the pilot.

## Phase 0: Product And Design Lock

### Outputs

- final roles, scope, business defaults, exclusions, and owner-input checklist;
- complete P0 screen map and user/admin flows;
- screen-by-screen purpose, entry points, actions, auth gates, states, and acceptance criteria;
- reconciled mobile design system and current visual/clickable prototype;
- Android/iOS responsive and accessibility rules;
- approved P0/P1/future split and canonical terminology.

### Gate

- Product/UX Requirements Pack is complete in the core docs.
- Task 2 reconciles `docs/design/DESIGN_SYSTEM.md` and visual references with the approved five-tab QR, auth, referral, order-state, responsive, and state rules.
- Remaining owner inputs are explicitly marked as blockers or approved placeholders.
- The owner reviews the Phase 0 pack before Phase 1 is accepted or backend/admin scope expands further.

## Phase 1: Flutter UI Prototype

### Outputs

- feature-based Flutter application with a small bootstrap and explicit routing/state boundaries;
- polished P0 screens using local/mock repositories and named mock providers;
- five-tab Home/Catalog/QR/Cart/Profile navigation;
- guest browsing/cart and preserved return-to-checkout authentication;
- complete loading, empty, validation, error, offline, permission, session, and deletion states;
- widget/smoke tests and responsive evidence at 320, 360, 390, and 430 logical-pixel widths on Android and iOS conventions.

### Acceptance

- every P0 customer flow is demoable without backend access;
- no unfinished backend is required to validate navigation or visuals;
- common text scale, keyboard, safe-area, and back-navigation scenarios keep all primary actions reachable;
- `flutter analyze` and relevant Flutter tests pass in the prepared environment;
- the owner approves the mobile prototype before production API expansion.

## Phase 2: Backend MVP

### Outputs

- one canonical FastAPI application and environment-driven configuration;
- PostgreSQL schema and Alembic migrations using typed SQLAlchemy 2 ORM and future-ready `company_id`;
- idempotent pilot seed data and clearly separate demo mode;
- auth/session, catalog, branch/availability, order, payment-demo, loyalty, referral, promo/promotion, and account-deletion APIs;
- named provider interfaces for OTP, payment, receipt, and notifications; only mock providers until real approval;
- OpenAPI documentation, role/branch enforcement, and business/integration tests.

### Acceptance

- a clean PostgreSQL database can be created by migrations;
- mobile repositories can switch between mock and API implementations;
- order and payment states are separate and use the approved lifecycle;
- loyalty/referral/promo/availability rules are idempotent and covered by tests;
- secrets and password hashes are never serialized, and cross-company/branch access tests fail safely.

## Phase 3: Admin MVP

### Outputs

- the custom Next.js application in `admin/` connected to the approved API;
- owner/manager/barista authentication and permission-aware navigation;
- order queue with safe one-click status actions;
- menu/category/modifier, branch/availability, staff/role, promotion/promo-code, customer, loyalty, and referral operations;
- SweetTime pilot settings and branding preview where supported.

`admin-legacy/` is archive-only and is not a second implementation target.

### Acceptance

- staff can run the assigned branch queue without owner-only access;
- the owner can maintain pilot menu, branches, availability, promotions, and staff without developer help;
- company and branch isolation are enforced server-side, not only hidden in UI;
- typecheck, tests, and production build pass in the prepared Node environment.

## Phase 4: Integration, Pilot, And Release

### Outputs

- Flutter/API/admin integration with mock mode retained for sales demos;
- real approved SweetTime brand/menu/branch data;
- physical-server deployment, environment config, TLS, backups, monitoring, and recovery notes;
- Android pilot APK/AAB with configured application id and signing;
- pilot runbook, staff training, support path, and known-issue list;
- privacy policy, terms, support URL, and deletion web link before public distribution;
- production identifiers, permissions, icons, screenshots, signing, and store metadata when moving beyond the pilot;
- Google Play Internal Testing first; iOS/TestFlight only after the Apple account, bundle id, legal assets, support URL, and deletion links are ready.

### Acceptance

- owner and staff complete a pilot order end to end on target devices;
- demo providers are visibly distinguished from production dependencies;
- business owner approves content, roles, operational rules, and pilot readiness;
- legal, store, provider, and client-owned account prerequisites are complete;
- production submission contains no demo credentials, generated placeholder claims, or mock provider ambiguity;
- production OTP/payment/receipt integrations are added only after provider approval;
- Android is prepared first; iOS follows when Apple prerequisites are available;
- production monitoring, backup verification, and incident ownership are assigned before public launch.

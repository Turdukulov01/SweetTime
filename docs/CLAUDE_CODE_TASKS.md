# Claude Code Tasks For SweetTime

Use these tasks sequentially. Do not start a later task until the previous one is reviewed or explicitly skipped by the project owner.

Before every task, Claude Code must read:

- `CLAUDE.md`
- `AGENTS.md`
- `docs/PROJECT_BRIEF.md`
- `docs/UX_UI_BRIEF.md`
- `docs/FEATURE_PRIORITIES.md`
- `docs/IMPLEMENTATION_PHASES.md`
- `docs/TASKS.md`
- `docs/collab/README.md`
- `docs/collab/CODEX_NOTES.md`

## Global Rules For Claude Code

- Work design-first. Do not expand backend/admin before UX/UI is clarified.
- Treat the current Flutter app as a draft prototype, not approved final UI.
- Use modern framework patterns.
- Backend ORM must use SQLAlchemy 2 typed style: `DeclarativeBase`, `Mapped`, `mapped_column`.
- Do not add real payment, delivery, SMS, WhatsApp, Telegram, or POS integrations without credentials, pricing, and explicit approval.
- Do not expose secrets, password hashes, or sensitive user data in admin APIs.
- Keep each task small enough to review.
- After each task, summarize changed files, checks run, and remaining risks.

---

## Task 0: Repository Audit And Correction Plan

**Goal:** Understand current repo state and list what must be corrected before feature work continues.

**Prompt For Claude Code:**

Review the SweetTime repository. Read all project docs listed at the top of `docs/CLAUDE_CODE_TASKS.md`. Inspect Flutter, backend, admin, docs, and Docker files. Do not edit code yet. Produce a short audit with:

- current implemented parts;
- design/process gaps;
- technical debt;
- outdated patterns;
- broken or risky code paths;
- recommended next 5 tasks in exact order.

**Acceptance Criteria:**

- No files changed.
- Audit mentions design-first workflow.
- Audit explicitly checks SQLAlchemy model style.
- Audit identifies whether Flutter UI is draft or ready.

---

## Task 1: Product And UX Requirements Pack

**Goal:** Prepare a clear product/UX spec before more code.

**Prompt For Claude Code:**

Create or update product documentation for SweetTime based on existing docs and current app draft. Do not implement UI or backend changes. Produce:

- final MVP user roles;
- customer user flows;
- admin user flows;
- complete mobile screen map;
- screen-by-screen requirements;
- loading/empty/error/auth/guest states;
- MVP vs future scope.

Use concise Markdown. Update existing docs instead of creating duplicates where possible.

**Recommended Files:**

- `docs/PROJECT_BRIEF.md`
- `docs/UX_UI_BRIEF.md`
- `docs/FEATURE_PRIORITIES.md`
- `docs/IMPLEMENTATION_PHASES.md`
- `docs/TASKS.md`

**Acceptance Criteria:**

- Every P0 mobile screen has a purpose and acceptance criteria.
- Delivery and real payments are clearly marked future.
- "Daily drink" recurring order is marked as demo/MVP-light.
- No application code changed.

---

## Task 2: Mobile Design System Spec

**Goal:** Define the UI system before polishing Flutter screens.

**Prompt For Claude Code:**

Create a mobile design system specification for SweetTime. Do not implement widgets yet. Define:

- brand placeholders until real logo/colors/menu/photos are provided;
- color tokens for light and dark mode;
- typography scale;
- spacing and radius scale;
- buttons, inputs, chips, cards, product cards, bottom nav, modal sheets;
- checkout summary component;
- loyalty/referral components;
- admin visual direction;
- Android/iOS safe-area, keyboard, and navigation requirements.

**Recommended File:**

- `docs/DESIGN_SYSTEM.md`

**Acceptance Criteria:**

- Design system matches youth/kawaii/pastel style without overload.
- Includes mobile responsiveness notes.
- Includes what to hide when promotions/seasonal products are empty.
- No application code changed.

---

## Task 3: Flutter Architecture Refactor Plan

**Goal:** Plan Flutter structure before moving draft code.

**Prompt For Claude Code:**

Inspect current Flutter code. Propose a refactor plan to move from draft single-file UI to feature-based architecture. Do not perform the refactor yet. Define:

- folder structure under `lib/`;
- routing approach with `go_router`;
- state management boundaries with Riverpod;
- domain models vs DTOs;
- mock repositories vs API repositories;
- design system widget locations;
- test strategy.

**Recommended File:**

- `docs/FLUTTER_ARCHITECTURE.md`

**Acceptance Criteria:**

- Plan avoids one giant `main.dart`.
- Plan supports mock-first UI development.
- Plan makes API integration replaceable.
- No code changed except documentation.

---

## Task 4: Flutter UI Prototype Refactor

**Goal:** Refactor the current Flutter draft into clean architecture while keeping behavior working.

**Prompt For Claude Code:**

Refactor the Flutter draft into the architecture approved in `docs/FLUTTER_ARCHITECTURE.md`. Keep the app mock/local-data based. Do not integrate backend yet. Implement:

- feature folders;
- app router;
- shared design system widgets;
- mock repositories;
- home, catalog, product detail, cart, checkout, orders, loyalty, profile flows;
- widget tests for main navigation and checkout smoke flow.

**Acceptance Criteria:**

- `lib/main.dart` is small and only bootstraps the app.
- No customer flow from the draft is lost.
- UI remains responsive on mobile widths.
- `flutter analyze` and `flutter test` pass in a local Flutter environment.

---

## Task 5: Backend Foundation Cleanup

**Goal:** Make backend foundation modern and maintainable before adding deep features.

**Prompt For Claude Code:**

Review and improve the FastAPI backend foundation. Keep scope limited to architecture quality. Ensure:

- SQLAlchemy 2 typed ORM with `Mapped` and `mapped_column`;
- clean module structure for routers, services, models, schemas, dependencies;
- Alembic initial migration exists;
- seed data is idempotent;
- settings are environment-driven;
- password hashes are never serialized;
- tests cover startup, auth, catalog, and basic order creation.

**Acceptance Criteria:**

- Backend imports cleanly.
- `pytest` passes in a prepared Python environment.
- Alembic can create schema from empty DB.
- No old `Column(...)` model declarations remain.

---

## Task 6: Backend MVP API Completion

**Goal:** Implement only APIs needed by approved mobile/admin MVP flows.

**Prompt For Claude Code:**

Complete MVP API behavior for SweetTime based on approved docs. Implement or verify:

- auth register/login/refresh/logout/me/account deletion;
- branches, categories, products, modifiers, availability;
- order creation, status changes, repeat order;
- mock/cash/QR demo payments;
- loyalty wallet and ledger;
- referral apply and rewards after first completed order;
- promo code apply;
- recurring order demo;
- role-protected admin APIs.

**Acceptance Criteria:**

- API shape matches `README.md` and docs.
- Staff can change order statuses.
- Customer cannot change staff-only statuses.
- Points: earn 5%, spend max 30%, 1 point = 1 KGS.
- Referral anti-fraud basics work.
- Tests cover business rules.

---

## Task 7: Custom Next.js Admin MVP UX And CRUD

**Goal:** Make the canonical custom Next.js admin in `admin/` usable for a cafe owner and staff.

**Prompt For Claude Code:**

Improve the custom Next.js admin MVP in `admin/`. Keep `admin-legacy/` archive-only. Prioritize
operational usefulness over decoration. Implement:

- dashboard counters;
- order queue with fast status update actions;
- product/category/modifier CRUD;
- branch CRUD and availability controls;
- user/role list;
- promo/promotion CRUD;
- loyalty/referral visibility;
- owner vs staff permission boundaries.

**Acceptance Criteria:**

- Owner can edit menu and branches.
- Staff can process orders quickly.
- Staff cannot access owner-only settings.
- Admin build passes in a normal Node environment.

---

## Task 8: Mobile API Integration

**Goal:** Connect Flutter UI to backend without breaking mock/demo mode.

**Prompt For Claude Code:**

Add API integration to Flutter using repository interfaces. Keep mock repositories available for design/demo mode. Implement:

- API client with base URL config;
- auth token storage;
- catalog/branches/products API repository;
- order creation and order history;
- loyalty/referral API calls;
- graceful loading, empty, and error states;
- fallback mock mode for offline demo.

**Acceptance Criteria:**

- App can run in mock mode without backend.
- App can run against local FastAPI backend.
- Tokens are stored securely.
- Network errors do not crash UI.

---

## Task 9: Brand And Design Replacement

**Goal:** Replace placeholders with real cafe identity after assets are provided.

**Prompt For Claude Code:**

After brand assets are provided, update SweetTime design and content:

- app name;
- logo;
- colors;
- real menu categories;
- real products and modifiers;
- product photos;
- branch addresses, phones, hours, 2GIS/Google Maps links;
- splash/app icon placeholders.

**Acceptance Criteria:**

- No placeholder product/menu content remains in demo data.
- UI still follows approved design system.
- Assets are organized and referenced from Flutter correctly.
- Admin seed data matches real cafe content.

---

## Task 10: Release Readiness Checklist

**Goal:** Prepare project for pilot and store submission without premature spending.

**Prompt For Claude Code:**

Create release readiness docs and config tasks. Do not submit to stores. Prepare:

- Android application id plan;
- signing checklist;
- iOS bundle id checklist;
- required permissions;
- privacy policy outline;
- terms/support URL checklist;
- account deletion web-link requirement;
- app screenshots checklist;
- TestFlight/Internal Testing decision notes;
- server deployment checklist.

**Recommended File:**

- `docs/RELEASE_CHECKLIST.md`

**Acceptance Criteria:**

- Clearly separates pilot APK/AAB from App Store/Play Market production.
- Lists what client must provide/pay for.
- Includes account deletion requirements.
- Does not require real payment integrations for MVP demo.

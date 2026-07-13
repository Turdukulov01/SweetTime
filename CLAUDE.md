# SweetTime Claude Guidance

## Project Direction

SweetTime is a sellable MVP for one concrete bubble tea chain, with a reusable core that can later be adapted for other cafes. Do not treat it as a generic demo app. Product, UX, and commercial presentation matter as much as code.

## Required Work Order

1. **Design and product specification first.**
   - Define user flows, screen inventory, visual direction, states, and acceptance criteria before expanding implementation.
   - Use the existing Flutter UI only as an interactive draft, not as final approved design.

2. **Mobile UI implementation second.**
   - Build Flutter screens from the approved design system.
   - Keep UI clean, pastel/youth/kawaii, but not overloaded.

3. **Backend third.**
   - Implement only APIs required by approved mobile/admin flows.
   - Keep `company_id` in models for future white-label adaptation.

4. **Admin fourth.**
   - Web admin is the preferred admin surface.
   - Staff queue must stay simple; owner/manager screens can be richer.

5. **Release preparation last.**
   - Android build first, iOS/TestFlight after accounts and legal assets exist.

## Technical Preferences

- Python: FastAPI, Pydantic v2, SQLAlchemy 2 typed ORM with `Mapped` and `mapped_column`.
- Backend should be API-first and documented through OpenAPI.
- Flutter: feature-based structure, Riverpod or another explicit state layer, theme/design tokens.
- Admin: React Admin is acceptable for MVP speed; custom Next.js can be a later upgrade.
- Do not add real payment/delivery integrations until provider access, costs, and merchant terms are confirmed.

## Product Defaults

- Loyalty: `1 point = 1 KGS`, earn `5%`, spend up to `30%`, points expire after 12 months.
- Referral: invited user receives 50 points; inviter receives 100 points after invited user's first completed order.
- MVP payments: mock, cash, QR demo.
- Future payments: MBank QR, Элсом, О!Деньги, bank cards, fiscal receipt.
- MVP orders: pickup, scheduled pickup, QR cafe order, demo recurring "daily drink".
- Future: delivery, POS integration, advanced analytics, exports, full SaaS tenant management.

## Before Making Changes

- Read `AGENTS.md`, `docs/PROJECT_BRIEF.md`, `docs/UX_UI_BRIEF.md`, `docs/FEATURE_PRIORITIES.md`, and `docs/IMPLEMENTATION_PHASES.md`.
- AI collaboration (Claude Code + Codex): rules in `docs/collab/README.md`. Claude writes only `docs/collab/CLAUDE_NOTES.md` and reads `CODEX_NOTES.md`; Codex — the reverse. Read the colleague's file at session start and update your own file after meaningful work with changed files, checks, risks, contradictions, and requests.
- Treat `docs/TASKS.md` as the canonical backlog and acceptance status; agent notes do not approve tasks or override phase order.
- If a request conflicts with the design-first process, clarify whether the user wants planning/spec work or direct implementation.
- Keep changes scoped to the current phase.

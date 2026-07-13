# SweetTime Agent Instructions

## AI Collaboration (Claude Code + Codex)

Two AI assistants work on this repo. Shared context lives in `docs/collab/` (rules: `docs/collab/README.md`):
- **Codex**: at session start read `docs/collab/CLAUDE_NOTES.md` (current state, active zones, requests); write your own analysis/status ONLY to `docs/collab/CODEX_NOTES.md`. Never edit the colleague's file. Do not modify `lib/`, `admin/`, `backend/app_demo/`, `docs/design/*` without an explicit user task — these are active zones of Claude's agents (see CLAUDE_NOTES).
- **Claude Code**: at session start read `docs/collab/CODEX_NOTES.md`; write only to `docs/collab/CLAUDE_NOTES.md` and never edit the colleague's file.
- Both assistants must update their own notes after meaningful work with changed files, checks, remaining risks, contradictions, and requests to the colleague.
- `docs/TASKS.md` is the canonical backlog and acceptance status. Collaboration notes do not approve a task or override the phase order.

## Ground Rules

- This project must be built in phases. Do not jump straight to full backend/admin/mobile implementation unless the user explicitly asks for that phase.
- The first real milestone is a polished UX/UI prototype and design system for Android/iOS.
- Use existing code as a scaffold. It is not final design.
- Prefer modern, typed APIs and current framework patterns.

## Phase Discipline

### Phase 0: Product And Design
- Clarify brand, menu, references, flows, and screen list.
- Produce screen-by-screen UX spec.
- Produce design system tokens: colors, typography, spacing, components, states.
- Define mobile acceptance criteria before backend expansion.

### Phase 1: Flutter UI Prototype
- Build polished screens using local/mock data.
- Cover responsive Android/iOS layouts.
- Include loading, empty, error, guest, auth, and account deletion states.
- Do not rely on unfinished backend for visual flow validation.

### Phase 2: Backend API
- Implement FastAPI only for approved flows.
- Use SQLAlchemy 2 typed ORM: `Mapped`, `mapped_column`, typed relationships.
- Maintain future white-label readiness with `company_id`.

### Phase 3: Admin Panel
- Build web admin for owner/manager/staff roles.
- Prioritize products, categories, modifiers, branches, orders, users, loyalty, promos.

### Phase 4: Release
- Prepare Android APK/AAB first.
- Prepare iOS only after Apple Developer account, bundle id, privacy policy, support URL, and deletion links are ready.

## Code Standards

- Keep domain rules explicit and documented.
- Avoid fake "production" integrations. Use named mock providers until real credentials exist.
- Do not expose password hashes or secrets through admin endpoints.
- Add tests for business rules before deep feature expansion.
- Update docs whenever product scope or phase priorities change.

## Current Important Files

- `docs/PROJECT_BRIEF.md` — product and business context.
- `docs/UX_UI_BRIEF.md` — design-first direction.
- `docs/FEATURE_PRIORITIES.md` — MVP vs future feature split.
- `docs/IMPLEMENTATION_PHASES.md` — build order.
- `docs/TASKS.md` — actionable task backlog.
- `docs/collab/README.md` — collaboration protocol for Claude Code and Codex.
- `docs/collab/CLAUDE_NOTES.md` / `CODEX_NOTES.md` — current cross-agent context.

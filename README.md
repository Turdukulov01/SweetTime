# SweetTime MVP

SweetTime is a sellable MVP for a bubble tea chain: Flutter mobile app, FastAPI backend, PostgreSQL, Redis/Celery and React Admin. The first client is one concrete cafe chain, but the architecture keeps a future white-label/SaaS path open.

## Development Order

This project must be developed design-first:

1. Product brief, UX flows, screen map and design system.
2. Flutter UI prototype with mock/local data.
3. Backend API for approved flows.
4. Web admin for owner, manager and staff roles.
5. Android/iOS release preparation.

The current Flutter UI is a working draft for discussion, not the final approved design.

## Key Docs

- [CLAUDE.md](CLAUDE.md) — instructions for Claude-style agents.
- [AGENTS.md](AGENTS.md) — instructions for all coding agents.
- [Project brief](docs/PROJECT_BRIEF.md) — business and product context.
- [UX/UI brief](docs/UX_UI_BRIEF.md) — design-first requirements.
- [Feature priorities](docs/FEATURE_PRIORITIES.md) — MVP vs future split.
- [Implementation phases](docs/IMPLEMENTATION_PHASES.md) — correct build order.
- [Task backlog](docs/TASKS.md) — actionable next work.

## What Exists Now

- Flutter draft shell with catalog, product modifiers, cart, checkout, branches, orders, loyalty, referrals, profile, dark theme and account deletion flow.
- FastAPI backend foundation with auth, JWT, catalog, branches, orders, payments, loyalty, referrals, promo codes, recurring orders and admin CRUD.
- SQLAlchemy 2 typed ORM models using `Mapped` and `mapped_column`, with `company_id` for future white-label adaptation.
- React Admin foundation for orders, products, categories, branches, users, promo codes, promotions and support resources.
- Docker Compose for `api`, `postgres`, `redis`, `celery_worker`, `celery_beat`, `admin` and `nginx`.

## Default Accounts

- Owner: `owner@sweettime.kg` / `sweettime123`
- Staff: `staff@sweettime.kg` / `sweettime123`

## Backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open API docs at `http://localhost:8000/docs`.

## Admin

```bash
cd admin
npm install
npm run dev
```

Admin expects the API at `VITE_API_URL` or `http://localhost:8000`.

## Full Stack

```bash
docker compose up --build
```

- API: `http://localhost:8000`
- Swagger: `http://localhost:8000/docs`
- Admin: `http://localhost:5173`
- Nginx gateway: `http://localhost:8080`

## Flutter

Run from the repository root after installing Flutter:

```bash
flutter pub get
flutter run
```

## MVP Boundaries

Real MBank QR, Elsom, O!Dengi, card payments, Yandex Delivery, POS integration, Excel/PDF reports, audit logs and full SaaS tenant management are prepared as extension points, but are not implemented as production integrations in this MVP.

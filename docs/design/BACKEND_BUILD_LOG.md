# SweetTime — пошаговый лог сборки боевого backend

Назначение: **резюмируемый журнал** этапа Phase 2 (боевой backend + деплой). Если сессия
упёрлась в лимит — по этому файлу любой (Claude/Codex/новый агент) продолжает с точного места.
План целиком: `docs/design/PRODUCTION_PLAN.md`. Каждый шаг = git-коммит (откат возможен).

## Договорённости с пользователем (2026-07-13)

- Цель сейчас: **рабочая система на своём сервере** (Ubuntu Server, Docker есть). API + админка,
  связанные с приложением. Глубокую серверную безопасность прикручиваем ПО ХОДУ; но **авторизацию
  добавить нужно сейчас**. SMS-провайдер — ПОТОМ (нужен договор/деньги), OTP пока mock.
- Деплой: доступа по SSH нет — я даю команды, пользователь выполняет. Домена нет — пока по IP.
- Разработка/тест — локально: **Postgres в Docker** (контейнер `sweettime-pg`, 5432,
  sweettime/sweettime/sweettime). Docker Desktop + WSL установлены.

## Каноническое решение

Боевой пакет `backend/api/` — эволюция контракта `backend/app_demo` (его уже понимают приложение
и админка: `/api/companies/{cid}/...`, camelCase, локализованные поля `{ru,ky,en}`). Механизмы
безопасности (JWT, хэш паролей) переносим из `backend/app/security.py`. `backend/app_demo` остаётся
для локального демо; `backend/app` — донор кода, как боевой НЕ используем (single-tenant + React-Admin).

## Среда (готово)

- [x] Docker engine 29.6.1 работает.
- [x] Postgres 16 контейнер `sweettime-pg` на :5432 (POSTGRES_DB/USER/PASSWORD=sweettime).
  Перезапуск: `docker start sweettime-pg` (или `docker run ...` заново — см. историю).
  DATABASE_URL для локалки: `postgresql+psycopg://sweettime:sweettime@localhost:5432/sweettime`.

---

## S1 — каноническая основа (В РАБОТЕ)

Цель: пакет `backend/api/` на Postgres, Alembic-миграции с нуля, полные модели (вкл. таблицы
пользователей под будущий JWT), идемпотентный сид (2 компании + demo-стафф/клиент), рабочие
GET/POST/PATCH эндпоинты контракта (пока БЕЗ проверки токена — auth в S2).

Подшаги:
- [ ] S1.1 Скелет пакета `backend/api/` (config pydantic-settings: DATABASE_URL/JWT_SECRET; database.py engine/Session; main.py FastAPI + CORS + /health).
- [ ] S1.2 Модели SQLAlchemy 2 typed: Company, AdminUser(email/hashed_password/role/company_id/branch_id), Customer(phone/name/points/referral_code/invited_by_code/company_id), Branch, Product(+isNew/isBestSeller/color/sizes/toppings JSON/availableBranchIds/localized name+desc), Order(items JSON/type/status/paymentMethod/total/pointsUsed/pointsEarned/createdAt/customer), News, Promotion. Локализованные поля — JSON {ru,ky,en}.
- [ ] S1.3 Alembic: init, первая ревизия = вся схема; `alembic upgrade head` на пустой Postgres проходит.
- [ ] S1.4 Сид (идемпотентный): sweettime+coffeego (данные как в app_demo/seed.py — товары/филиалы/новости/акции), demo-стафф (owner@/manager@/barista@sweettime.kg + owner@coffeego.kg, пароль demo, хэш) + demo-клиент (+996…). Только при пустой БД.
- [ ] S1.5 Эндпоинты контракта на Postgres: GET config/products/branches/orders/news/promotions; POST/PATCH products/branches/orders/news/promotions; PATCH order status. Формы — по DEMO_API.md (camelCase). Без auth (S2).
- [ ] S1.6 Проверки: `alembic upgrade head` с нуля; `uvicorn api.main:app` стартует на :8000; curl GET по обеим компаниям; изоляция (нет чужих данных). Коммит `feat(api): production backend foundation on Postgres`.

Статус S1: старт. Исполнитель: агент backend-api под супервизией Claude.

## S2 — авторизация (следующий)
JWT: стафф (email+пароль) и клиент (OTP-mock по телефону), access/refresh, зависимость
get_current_* + require_staff/role, company_id из токена. Клиентские мутации требуют токен.

## S3+ — см. PRODUCTION_PLAN.md (серверные цены/лояльность, контент, клиенты на API, деплой S6–S7).

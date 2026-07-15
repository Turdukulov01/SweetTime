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

**Статус S1: ✅ ПРИНЯТ 2026-07-13** (все подшаги S1.1–S1.6 выполнены). Исполнитель: агент
backend-api (упёрся в лимит на Alembic); Alembic-миграции, фикс дефекта и приёмку доделал Claude.

Дефект агента, найденный и исправленный при приёмке: в `seed_if_empty()` `flush()` стоял ПОСЛЕ
филиалов → `ForeignKeyViolation` (у моделей нет ORM-relationship, поэтому порядок вставки FK надо
задавать явными `flush()` по уровням: компании → филиалы → остальное). Исправлено.

Доказательства (S1.6):
- `py -m alembic -c api/alembic.ini upgrade head` с нуля → 9 таблиц: companies, admin_users,
  customers, branches, products, orders, news, promotions, alembic_version. Ревизия `c23573f41ea6`.
- `/health` → `{"status":"ok"}`; приложение = 24 роута.
- Данные: sweettime 8 товаров / 3 филиала / 4 новости / 3 акции / 50 заказов; coffeego 7/2/2/2/25.
- Изоляция: пересечение id новостей sweettime∩coffeego = 0; PATCH sweettime-товара через coffeego → 404.
- Запись: PATCH `isBestSeller` false→true работает.
- Стафф с bcrypt-хэшами (`$2b$12$`): owner/manager/barista@sweettime.kg, owner@coffeego.kg (пароль
  `demo`); клиент +996 555 123 456 (1240 баллов, код SWEET-AIGERIM) — готовы под JWT в S2.

### Как поднять локально (для следующей сессии / другого агента)
```powershell
# 1) Docker Desktop запущен, затем Postgres:
docker start sweettime-pg     # контейнера нет? см. раздел «Среда» выше
# 2) миграции + API (из папки backend/):
cd C:\Users\user\flutter_project\sweettime\sweettime\backend
py -m alembic -c api/alembic.ini upgrade head
py -m uvicorn api.main:app --port 8010
```
Порты: **8010 — боевой API (`backend/api`)**, 8000 — старый demo (`backend/app_demo`), 3020 — админка.

## S5 — клиенты на боевой API (В РАБОТЕ)

- [x] **S5.0 глобальный вход** `POST /api/auth/staff/login` {email,password} → токен + user
  (companyId внутри). Нужен потому, что форма входа админки компанию не знает; email уникален
  глобально. Токен всё равно несёт `cid` → скоуп сохраняется. Проверено: owner@coffeego.kg →
  companyId=coffeego; неверный пароль → 401. Коммит `3705828`.
- [x] **S5.2a профиль клиента НА СЕРВЕРЕ** (жалоба пользователя: приложение не хранило сессию и
  личные данные, хотя тему/язык хранило). Customer + `first_name/last_name/birth_date`, миграция
  `ecd3c7b14a5c` (с `server_default=''`, иначе NOT NULL не добавить к существующим строкам).
  Эндпоинты: `GET /api/companies/{cid}/auth/customer/me` (восстановление сессии по токену),
  `PATCH .../customer/me` (сохранить своё имя/фамилию/др). Staff-токен на профиль клиента → 401.
  Проверено: PATCH → новый вход по OTP → профиль на месте (в БД `Айгерим|Осмонова|1998-03-14`).
  Коммит `363fe9a`.
- [x] **S5.1 админка на JWT** — ПРИНЯТА. Реальный вход через `/api/auth/staff/login`, токен+user в
  localStorage (сессия переживает F5), Bearer во всех запросах, single-flight refresh на 401,
  logout+редирект при протухшем refresh. Мок-фолбэка больше НЕТ (удалён `admin/lib/data.ts`;
  демо-остатки — в честном `admin/lib/demo-data.ts`); API не ответил → экран ошибки, не тихая
  подмена. 403 → тост «Недостаточно прав» + откат оптимистичного изменения. `/staff` и карточка
  «Постоянные заказы» помечены как демо (серверных ручек нет). Дефект, найденный агентом:
  `branchId: null` от API молча ронял сессию → разлогин; исправлено в `parseAdminUser`.
  Проверено агентом в реальном Chrome (CDP) + curl; мной: typecheck OK.
- [x] **S5.2b Flutter** — ПРИНЯТ. `flutter_secure_storage` возвращён; `lib/core/auth_store.dart`
  (интерфейс + Keystore/Keychain, для тестов — in-memory фейк). `bootstrap()` восстанавливает
  сессию через `auth/customer/me` (+refresh на 401); **офлайн НЕ разлогинивает**. Вход по OTP через
  API, профиль читается/сохраняется на сервере, Bearer на `POST /orders`. Дефолт `API_BASE` →
  `http://127.0.0.1:8010`. Хорошее решение агента: `ApiResult{ok|rejected|unavailable}` — отказ
  сервера и офлайн различаются. Проверки: analyze 0, **тесты 27/27** (3 новых), build web+APK.
  Код Codex не переписан (локализация, guest-gate, +996, отсутствие фейкового Google сохранены).

**Итог S5: жалоба пользователя закрыта** — приложение хранит сессию (токен на устройстве) и личные
данные (на сервере: переживают переустановку/смену телефона). Коммит `7cae65e`.

### Проверка на физическом телефоне (Redmi, USB)
`adb reverse tcp:8010 tcp:8010` — телефон ходит на API ПК через USB (firewall/LAN не нужны):
```powershell
$adb = "C:\Users\user\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb -s f3bff2a5 reverse tcp:8010 tcp:8010
& $adb -s f3bff2a5 shell "curl -s http://127.0.0.1:8010/health"   # -> {"status":"ok"}
```
Проверено: с устройства `/health` отвечает; profile-APK установлен (`kg.sweettime.demo`).
Проброс слетает при переподключении USB/перезапуске adb — повторить команду.

### Грабли (записаны, чтобы не наступать снова)
- **Кириллица в inline-JSON через Git Bash curl** → 400 «error parsing the body». Это артефакт
  shell, НЕ API. Слать тело файлом (`--data-binary @f.json`) или PowerShell с UTF-8-байтами.
- **Порт 8010 может держать старый процесс** — после правок API обязательно убивать PID и
  перезапускать, иначе проверки бьют в устаревший код (агент S2 на этом чуть не ошибся).
- **NOT NULL колонка к непустой таблице** → нужен `server_default`, затем снять его `alter_column`.

## S2 — авторизация (JWT) и роли (НА ПРИЁМКУ)

Цель: JWT для стаффа (email+пароль) и клиента (OTP-mock по телефону), access/refresh,
зависимости get_current_* + require_role, company_id ИЗ ТОКЕНА. SMS-провайдера нет — OTP mock.

Подшаги:
- [x] S2.1 `security.py`: bcrypt-пароли + JWT (pyjwt, HS256). Payload: `sub`, `typ` (staff|customer),
  `cid`, `role` (у стаффа), `kind` (access|refresh), `iat`/`exp`. Секретов/паролей в payload нет.
  Сроки — из настроек (`access_token_minutes`=30, `refresh_token_days`=30).
- [x] S2.2 Эндпоинты стаффа: POST `auth/staff/login`, POST `auth/refresh`, GET `auth/me`.
- [x] S2.3 Эндпоинты клиента: POST `auth/otp/request` (mock), POST `auth/otp/verify` (код `1111`,
  создаёт клиента при первом входе).
- [x] S2.4 Зависимости (`api/deps.py`): get_current_staff / get_current_customer / require_role.
  Сюда же переехал мультитенантный скоуп из `main.py` (get_company + get_company_*).
- [x] S2.5 Защита эндпоинтов (см. таблицу прав ниже).
- [x] S2.6 Alembic: **миграция не нужна** — модели не менялись (`alembic check` → "No new upgrade
  operations detected"). Токены stateless, таблиц под них не заводили.
- [x] S2.7 Проверки curl (ниже).

### Модель прав (кто что может)

| Ручка | Доступ |
|---|---|
| `/health`, GET `config`/`products`/`branches`/`news`/`promotions` | **публично** (гость смотрит меню без входа) |
| POST/PATCH/DELETE `products`/`branches`/`news`/`promotions`, PATCH `config` | staff: **owner, manager** |
| PATCH `orders/{id}/status` | staff: **owner, manager, barista** |
| GET `orders` (очередь админки) | **любой staff** компании |
| POST `orders` | **токен клиента** (customerName/customerId — из токена, не из тела) |

**Ключевая защита**: `company_id` берётся из claim `cid` токена и сверяется с `{companyId}` пути —
не совпало → **403**, даже если токен валиден. Плюс сверка company_id по БД (роль/компанию могли
изменить после выпуска токена). Refresh-токен не принимается как access (claim `kind`).

### Доказательства (S2.7, порт 8010)

| # | Проверка | Результат |
|---|---|---|
| 1 | login `owner@sweettime.kg`/`demo` | 200, пара токенов + `{"id":"u-sw-owner","role":"owner","companyId":"sweettime"}` |
| 2 | login с неверным паролем | **401** `Invalid email or password` |
| 3 | GET `auth/me` с токеном owner | 200, профиль без пароля/хэша |
| 4 | PATCH товара БЕЗ токена | **401** `Not authenticated` |
| 5 | PATCH товара с токеном owner | 200, поле изменилось |
| 6 | **токен sweettime → PATCH в `/api/companies/coffeego/...`** | **403** `Token was issued for another company` |
| 7 | POST `auth/refresh` с refreshToken | 200, новая пара |
| 7b | refresh-токен подсунут как access в `auth/me` | **401** `Expected a access token` |
| 8 | barista → PATCH товара | **403** `Role 'barista' is not allowed here (allowed: manager, owner)` |
| 9 | barista → PATCH статуса заказа (new→ready) | **200** |
| 10 | GET `orders` без токена | **401** |
| 11 | POST `auth/otp/request` | 200 `{"sent":true,"demoCode":"1111","mode":"mock"}` |
| 12 | POST `auth/otp/verify` код `1111` | 200, токены + `{"id":"c-sw-aigerim","points":1240,"referralCode":"SWEET-AIGERIM"}` |
| 12b | verify с кодом `9999` | **400** `Invalid code` |
| 12c | verify нового телефона | 200, клиент создан (`name":"Гость"`, свежий referralCode) |
| 13 | POST заказа без токена | **401** |
| 14 | POST заказа с токеном клиента | **201**, `customerName` подставлен из профиля токена |
| 14c | подделка `customerName":"HACKER"` в теле | поле проигнорировано → `customerName":"Айгерим"` |
| 14d | токен клиента sweettime → POST заказа в coffeego | **403** |
| 14e | токен клиента → PATCH товара (админская ручка) | **401** `Staff token required` |
| 15 | GET `config`/`products`/`branches`/`news`/`promotions` без токена | **200** (публичны) |

Тестовые данные после проверок вычищены (БД в состоянии сида: sweettime 50 заказов, 1 клиент).

### Как тестировать (следующая сессия)
```bash
B=http://127.0.0.1:8010/api/companies
# 1) токен стаффа
TOKEN=$(curl -s -X POST $B/sweettime/auth/staff/login -H 'Content-Type: application/json' \
  -d '{"email":"owner@sweettime.kg","password":"demo"}' | py -c "import sys,json;print(json.load(sys.stdin)['accessToken'])")
curl -s $B/sweettime/auth/me -H "Authorization: Bearer $TOKEN"
# 2) токен клиента (OTP mock: код всегда 1111)
curl -s -X POST $B/sweettime/auth/otp/request -H 'Content-Type: application/json' -d '{"phone":"+996 555 123 456"}'
curl -s -X POST $B/sweettime/auth/otp/verify  -H 'Content-Type: application/json' -d '{"phone":"+996 555 123 456","code":"1111"}'
# 3) изоляция компаний: тем же TOKEN в чужую компанию → 403
curl -s -X PATCH $B/coffeego/products/cg1 -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"isNew":true}'
```
Тело POST с кириллицей в Git Bash лучше слать файлом (`--data-binary @order.json`): инлайн-JSON
ломается на перекодировке и даёт 400 «error parsing the body» — это артефакт shell, не API.

### Осознанно НЕ сделано в S2 (следующие шаги)
- **Revocation/logout**: токены stateless, чёрного списка нет — выданный access живёт до `exp` (30 мин).
- **Реальный SMS**: провайдера нет (нужен договор) — `/otp/request` ничего не шлёт и открыто отдаёт код.
  Rate-limit на запрос OTP тоже не делали (нужен вместе с провайдером).
- **Клиенты на JWT** (Flutter/админка) — это S5; сейчас приложение шлёт POST /orders без токена и
  получит 401, админка — тоже (её мутации теперь под токеном). Пока не обновлены — ожидаемо.
- `JWT_SECRET` в проде обязателен через env (дефолт `change-me-in-production` — только локально).
- Серверные цены/лояльность/рефералка (+100 инвайтеру, invited_by) — S3, здесь не трогали.

## S3+ — см. PRODUCTION_PLAN.md (серверные цены/лояльность, контент, клиенты на API, деплой S6–S7).

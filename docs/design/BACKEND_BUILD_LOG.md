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

## S5.3 — персистентность пользовательских данных (6 правок пользователя 2026-07-15)

Пользователь на физическом телефоне нашёл: приложение НЕ хранит (1) фото профиля, (2) постоянные
заказы, (3) историю заказов, (4) корзину, (5) избранное (статичные 3 товара из DemoData
возвращаются после перезахода), (6) UX: снекбар «товар добавлен» перекрывает кнопку «Оформить».

Корень: прототип Codex держал всё в `AppState` в памяти; на сервер пока переведены только сессия
и профиль (S5.2). Решения (принцип: данные аккаунта — на сервере, черновики — локально):

| # | Что | Где хранить | Почему |
|---|---|---|---|
| 1 | Фото профиля | **локально навсегда** (копия в app documents + путь в prefs) | серверу нужен файловый storage/volume — отдельная задача (CX-013). НЕ переживёт переустановку — честно сказать пользователю |
| 2 | Постоянные заказы | **сервер** (таблица `recurring_orders`) | предоплаченная подписка — терять нельзя |
| 3 | История заказов | **сервер** (`GET /auth/customer/me/orders`) | заказы уже в БД, приложение просто не читает свои |
| 4 | Корзина | **локально** (shared_preferences) | черновик, не данные аккаунта |
| 5 | Избранное | **сервер** (`Customer.favorite_product_ids` JSON) | личные данные аккаунта; сейчас берутся из `DemoData.favoriteIds` |
| 6 | Снекбар | UX: сверху экрана | перекрывает «Оформить», приходится ждать |

Контракт S5.3 (задаю здесь, чтобы backend и Flutter не разошлись):
- `GET /api/companies/{cid}/auth/customer/me/orders` (Bearer клиента) → его заказы, новые сверху;
  форма элемента — как в существующем OrderOut.
- `GET|PUT /api/companies/{cid}/auth/customer/me/favorites` (Bearer) → `{productIds:[...]}`;
  PUT заменяет список целиком (идемпотентно, без гонок инкрементов).
- `GET|PUT|DELETE /api/companies/{cid}/auth/customer/me/recurring` (Bearer) →
  `{productIds:[...], time:"HH:MM", branchId, plan:"single|week|month", paidUntil: ISO|null, active}`;
  PUT создаёт/заменяет (у клиента одна подписка — как в UI), DELETE отменяет.

Статус: **backend S5.3 — СДЕЛАН** (ручки готовы, ждут Flutter); Flutter — следом (+ п.4 корзина
локально, п.6 UX). Фото профиля (п.1) в backend не входило — нужен файловый storage (CX-013).

### S5.3 backend: что сделано (2026-07-15)

Ревизия Alembic `7c003983b74d` (favorites + recurring_orders), ручки под `/auth/customer/me/...`.
Файлы: `api/models.py`, `api/schemas.py`, `api/auth.py`, `api/serializers.py` (новый), `api/seed.py`,
`api/main.py`, `api/migrations/versions/7c003983b74d_*.py`.

| Ручка | Поведение |
|---|---|
| `GET /auth/customer/me/favorites` | `{"productIds":[...]}` |
| `PUT /auth/customer/me/favorites` | заменяет список целиком; ответ = что реально сохранено |
| `GET /auth/customer/me/orders` | свои заказы, новые сверху, форма — OrderOut |
| `GET /auth/customer/me/recurring` | активная подписка или **200 `null`** |
| `PUT /auth/customer/me/recurring` | создаёт/заменяет, `paidUntil` считает сервер |
| `DELETE /auth/customer/me/recurring` | **204**, идемпотентно |

**Принятые решения (были оставлены на исполнителя):**

1. **Чужие/несуществующие id в favorites → отфильтровываются, НЕ 400.** Избранное — мягкий список
   предпочтений; снятый с продажи товар не должен навсегда ломать сохранение (клиент чинится сам).
   Ответ содержит реально сохранённый список, поэтому расхождение клиенту видно сразу. Дубли
   схлопываются, порядок клиента сохраняется.
2. **В подписке (recurring) обратная политика: неизвестный/чужой товар → 400.** Подписка
   предоплачена — молча выкинуть напиток, за который заплатили, нельзя. Чужой филиал → 404.
3. **GET recurring без подписки → 200 `null`, не 404.** «Подписки нет» — штатное состояние нового
   клиента, а не ошибка; приложение (S5.2b) различает ok/rejected/unavailable, и 404 попал бы в
   «сервер отказал».
4. **DELETE recurring → `active=false`, строку НЕ удаляем** (виден след: что и до какой даты
   оплачено). Идемпотентен: повторный DELETE и отмена несуществующей → 204. Отменённая подписка
   наружу не отдаётся (GET → null).
5. **Одна подписка на клиента** — гарантия на уровне БД (`uq_recurring_order_customer` по
   customer_id), а не только в коде; PUT обновляет строку на месте, повторное оформление
   переиспользует её.
6. `paidUntil` считает СЕРВЕР (single=1, week=7, month=30 дней); клиентское поле `paidUntil` в теле
   PUT отвергается (`extra="forbid"` → 422) — срок оплаты не то, что присылают с устройства.
7. Сериализатор заказа вынесен в `api/serializers.py`: очередь админки и история клиента обязаны
   отдавать один и тот же OrderOut, а прямой импорт `main` → `auth` дал бы цикл.

**Доказательства (curl, порт 8010, после перезапуска процесса):**

| # | Проверка | Результат |
|---|---|---|
| 1 | `alembic upgrade head` на **текущей БД с данными** | OK (`ecd3c7b14a5c -> 7c003983b74d`) |
| 2 | `alembic upgrade head` на **пустой БД** (`sweettime_fresh`) | OK, 10 таблиц; `alembic check` → «No new upgrade operations» |
| 3 | вход клиента OTP `1111` / `+996555123456` | 200, токен |
| 4 | GET favorites | `["p1","p4","p7"]` (демо-избранное) |
| 5 | PUT `["p1","p2"]` → GET | `["p1","p2"]`; PUT `[]` → GET → `[]` |
| 6 | PUT `["p1","cg-p1","p9","p1"]` (чужой/несущ./дубль) | `["p1"]` — cg-p1 реально существует в coffeego и отброшен |
| 7 | GET me/orders vs БД | id 1-в-1 с `WHERE customer_id='c-sw-aigerim'`; **3 у клиента против 54 в очереди компании**, новые сверху |
| 8 | GET recurring (нет подписки) | **200 `null`** |
| 9 | PUT `{p1,"11:00",b1,"week"}` | `paidUntil` = now+**7.000** дней, `active:true`; GET → он же |
| 10 | DELETE → GET → DELETE | 204 → `null` → 204 (идемпотентно) |
| 11 | PUT `{["p1","p4","p1"],"09:30",b1,"month"}` | дубль схлопнут → `["p1","p4"]`, paidUntil=+30д, строк в таблице по-прежнему **1** |
| 12 | PUT recurring с `cg-p1` / `cg-b1` / `25:99` / `plan:"year"` / `[]` / своим `paidUntil` | **400 / 404 / 422 / 422 / 422 / 422** |
| 13 | favorites+orders+recurring без токена | **401** (все) |
| 14 | они же со **staff-токеном** | **401** `Customer token required` |
| 15 | токен клиента sweettime → те же ручки в **coffeego** (GET/PUT/DELETE) | **403** (все) |

Тестовые данные вычищены: БД снова 52 заказа sweettime, `recurring_orders` пуста, избранное
демо-клиента = `["p1","p4","p7"]`.

**Демо-избранное на существующей БД**: сид проставляет `["p1","p4","p7"]` только новому клиенту, а
текущая БД засеяна раньше (сид идемпотентный, повторно не идёт) → в миграцию добавлен адресный
backfill (`WHERE id='c-sw-aigerim' AND favorite_product_ids::text IN ('[]','null')`); на чужой БД
затронет 0 строк.

**Осознанно НЕ сделано (backend S5.3):**
- Фото профиля (п.1) — нужен файловый storage/volume (CX-013), в задачу не входило.
- Корзина (п.4) и снекбар (п.6) — сторона Flutter.
- **История заказов демо-клиента почти пуста**: 50 сидовых заказов sweettime имеют `customer_id=NULL`
  (сид их не привязывает). Экран истории оживёт только на заказах, созданных через POST /orders с
  токеном. Привязку сидовых заказов к demo-клиенту не делал — в брифе её не было; если демо должно
  выглядеть живым, это отдельная правка сида.
- Оплата подписки — мок: `paidUntil` проставляется фактом PUT, платёжного провайдера за интерфейсом
  здесь нет (как и договорено — реальных интеграций не заводим).
- Списание/начисление баллов и фактическое исполнение подписки (кто и как варит напиток в 11:00)
  — не в скоупе S5.3; это S3/операционка.
- Админских ручек по `recurring_orders` нет — карточка «Постоянные заказы» в админке остаётся
  помеченной как демо (см. S5.1).

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

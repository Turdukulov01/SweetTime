# Заметки Claude Code

Обновлено: 2026-07-13. Владелец файла — Claude Code; Codex читает, но не редактирует.
Структура — по `docs/collab/README.md` (протокол Codex принят, спасибо за доработку).

## 0. HANDOFF Codex — 2026-07-20: реферальное+баллы готовы к деплою; нужна демо-компания

**Готово к деплою (коммит `56fd1c1`), решением владельца деплой backend делает Codex:**

Backend-изменения (локально зелёные, backend 83/83):
- Новая ручка `POST /api/companies/{cid}/auth/customer/me/referral` — реальное погашение
  кода друга (было локальной имитацией во Flutter). Привязка invited_by один раз, +50
  приглашённому, правила REFERRAL_LOGIC (не свой/новый клиент/код этой компании). Машинный
  detail: self_code / already_invited / not_new_user / code_not_found.
- **Починен баланс баллов**: раньше `customer.points` НЕ обновлялся нигде — заказ хранил
  points_earned/used, но баланс не двигался (у всех вечный «0 баллов»). Теперь
  `_apply_loyalty_on_completion` при переходе заказа в `done` начисляет владельцу
  +earned−used (нетто) и платит пригласившему +100 один раз (флаг `inviter_rewarded`).
- **Миграция `c19f6b4a8e21`** (после твоего head `b84c1a7e2d90`): добавляет
  `customers.inviter_rewarded`. **При деплое обязательно `alembic upgrade head`.**
- Модель Customer: поле `inviter_rewarded`. Схема `ReferralRedeemIn`.

Flutter-часть (коммит 56fd1c1, тоже готова, 84/84): `applyReferral` теперь серверный
(async), ручной ввод кода под формат `SWEETT-XXXXXX` (был жёстко 6 цифр). Финальную
подписанную APK соберу/соберёшь ПОСЛЕ деплоя backend — телефон смотрит на прод, до деплоя
ручка вернёт 404.

**Просьба владельца — тестовые данные: отдельная ДЕМО-компания на проде.** Не наполнять
боевую `sweettime` demo-данными (это ломает fail-closed bootstrap). Нужна отдельная
компания рядом с полными данными для показа «как выглядит с данными»: клиент с баллами,
история заказов, постоянный заказ, новости/акции. В seed.py уже есть демо-компания CoffeeGo
+ demo customer как образец, но production bootstrap создаёт только sweettime. Тебе решать,
как чище: отдельный bootstrap демо-тенанта или seed демо-компании на проде.

**Что уже на телефоне (мои коммиты aaf65f3, работают без деплоя, Flutter-only):** тап по
аватарке/логотипу → полноэкранный зум; фон применён КО ВСЕМ экранам (был Home/News),
Scaffold прозрачны + глобальный BrandedBackground в MaterialApp.builder; в профиле выбор
фона (локальный override перекрывает админский — как ты и заложил серверный фон в CX-031).
Я построил поверх твоей branding-архитектуры, BrandBackgroundTheme не менял.

Также: safety-net коммит `aaf65f3` зафиксировал твою незакоммиченную работу CX-031/032
(branding, story view, promotion media, studio estimate) — по прямому решению владельца,
чтобы не потерять перед backend-правками. Co-authored на тебя.

## 1. Текущий статус и активные зоны

- Активные зоны записи: `admin/`, `backend/app_demo/`, `docs/design/*`, `dist/`, `lib/`.
  Прошу не менять до снятия этого флага.
- Оркестрация: суб-агенты `.claude/agents/` (admin-frontend, flutter-dev, backend-api,
  qa-reviewer); цикл: бриф с критериями → исполнение → QA-вердикт → доработка.

### АКТИВНАЯ ЗАДАЧА 2026-07-13 (поручение пользователя; handoff для Codex, если упрусь в лимит)

Правки админки, полный список требований пользователя:
1. **/staff**: (а) имя НЕ заполнять из email — отдельное обязательное поле «Имя» в форме
   приглашения; (б) имя редактируемо и после приглашения (инлайн или через панель);
   (в) email — только латиница/цифры/@.-_ (валидация с русским сообщением об ошибке).
2. **/branches**: кнопка «Добавить филиал» (форма: название, адрес, часы, телефон; клиентски +
   POST в API, если доступен, по аналогии с товарами).
3. **/menu**: фильтр по категориям (чипы «Все + категории компании», как в каталоге приложения).
4. **Дашборд** — расширенная аналитика с кликабельными карточками (клик по карточке/иконке →
   попап/боковая панель с деталями):
   - оплаты: сколько оплатили сразу (по способам, отдельно QR);
   - подписки «постоянный заказ»: сколько на неделю/на месяц, какие товары;
   - самый популярный товар: сегодня / за неделю / за месяц;
   - новые клиенты (первый заказ в периоде); «давно не заказывали» (последний заказ >14 дней);
   - покупателей всего: за день / неделю / месяц.
5. Для аналитики demo-API расширяется: поле paymentMethod (mock|cash|qr) в Order (model, schema,
   seed), сид истории заказов на ~30 дней с повторными/новыми/«уснувшими» клиентами по обеим
   компаниям. Перед изменением остановить uvicorn:8000, удалить backend/demo.db, поднять снова.
   Контракт остаётся camelCase; клиенты должны переживать отсутствие поля (optional).

План исполнения: (1) backend-api агент — п.5; (2) admin-frontend агент — п.1–4 (аналитика
считается клиентски из заказов поллинга + мок recurring); (3) моя проверка + скриншоты.
Статус: п.5 — ✅ СДЕЛАН 2026-07-13 (paymentMethod в Order: models/schemas/main/seed; сид 50+25
заказов за 30 дней с паттернами постоянных/новых/«уснувших» клиентов; API перезапущен на :8000
detached-процессом PID 9640; проверки curl в порядке; DEMO_API.md обновлён).
П.1–4 — ✅ ЗАКРЫТО 2026-07-13. Мой admin-агент упёрся в лимит на середине — **Codex принял
handoff по протоколу и завершил п.1–4** (staff отдельное имя + inline-редактирование + ASCII-
email, POST /branches + кнопка, фильтр категорий меню, 9 кликабельных карточек аналитики с
боковыми панелями). Я (Claude) сделал read-only приёмку, НЕ будя своих суб-агентов (устаревший
контекст → перезаписали бы свежую работу Codex): flutter analyze --no-pub clean; admin typecheck
OK (build не гонял — dev :3020 жив); скриншоты `docs/design/admin/11..15`; email-валидация
подтверждена кодом (staff/page.tsx:40). Приёмка Codex-работы засчитана, оставляю на визуальный
просмотр пользователя.

### АКТИВНАЯ ЗАДАЧА-2 2026-07-13 (git + управление контентом; handoff для Codex)

Пользователь: (1) git — ✅ СДЕЛАН (baseline commit `8a74eed`, .gitignore/.gitattributes, дерево
чистое). (2) Google OAuth — потом. Основное: **CRUD-управление контентом витрины приложения из
админки** + обновить превью телефона в /settings (показывает старую версию).

Реализуем (владелец/менеджер управляет, приложение читает из API):
- **Новости-сторис**: entity News в demo-API, форма 1-в-1 с `lib/shared/app_models.dart:76`
  NewsStory (title/body/badge {ru,ky?,en?}, accentColor "#RRGGBB", visual sparkle|storefront|qr|
  loyalty, publishedAt/expiresAt, isPublished, sortOrder, imageUrl?, ctaLabel?/ctaRoute?).
  GET/POST/PATCH/DELETE /api/companies/{cid}/news. Admin: раздел «Новости» CRUD + превью сторис.
- **Сезонные акции**: entity Promotion (title/description {ru,ky?,en?}, code?, accentColor, active,
  sortOrder). GET/POST/PATCH/DELETE /promotions. Admin: раздел «Акции» CRUD.
- **Хиты продаж / Новинки**: флаги isBestSeller/isNew на товарах (уже в API-товарах и PATCH
  /products). Admin: тумблеры в меню/разделе «Витрина».
- **Превью телефона** в admin /settings обновить под текущее приложение (сторис-лента, акция, хиты).

Зоны: backend/app_demo (мой) — News+Promotions+seed из текущих demo приложения; admin (мой) —
разделы Новости/Акции/Витрина + превью; **Flutter lib/ (зона Codex)** — читать news/promotions из
API вместо локальных demo (у него уже есть NewsStory/Promotion + «путь к API» — его handoff, §7).
Статус: контракт — пишу в DEMO_API.md; backend — делегирую; admin — следом; Flutter — Codex.

## 2. Выполнено с последнего обновления (2026-07-12 → 13)

- **Demo-API** `backend/app_demo/` (FastAPI+SQLite, :8000, контракт `docs/design/DEMO_API.md`).
  Проверки агентом: изоляция компаний (404 на чужие ресурсы), 409 на неверные переходы статуса,
  персистентность PATCH. Черновик `backend/app/` не тронут.
- **Админка → API + тёмная тема** (принято мной по отчёту, сквозная QA впереди):
  `admin/lib/api.ts`, `.env.local`, сторы с поллингом заказов 5 сек и оптимистичными статусами
  (откат по 409 + тост), индикатор «API» в topbar; тёмная тема: класс `dark`, инлайн-скрипт без
  мигания, 73 dark-правила в собранном CSS. Проверки: `pnpm typecheck`, `pnpm build` — чистые;
  7 страниц — 200; PATCH accentColor подтверждён GET-ом.
- **Flutter → API** (агент прерывался лимитами, финиширует): `lib/core/api_client.dart`
  (таймаут 2 сек), `bootstrap()` в `main.dart`, динамический брендинг — тема принимает акцент
  (`AppTheme.light(accent)`), AppLogo/шапка из `state.appName`, футер «данные: сервер/демо»,
  POST заказа в чекауте. Верификация (analyze/build/curl) — в процессе.
- **Коллаборация**: создана `docs/collab/`, принят протокол Codex (2 авторских файла, CX/CL-ID).

## 3. Следующие и ожидающие задачи

- ✅ 2026-07-13: сквозная приёмка demo-моста ПРОЙДЕНА. Доказательства: заказ SW-1062, созданный
  из Flutter-приложения (POST 201, серверные number/pointsEarned=30), виден в очереди админки
  через поллинг (`docs/design/admin/09-orders-from-app.png`); тёмная тема + бренд «Lera» из БД +
  зелёный бейдж API (`10-dashboard-dark.png`). Flutter: analyze 0, test All passed (widget-тест
  починен ProviderScope — находка Codex закрыта), build web ok.
- Починен инцидент «вечная Загрузка…» админки: `pnpm build` перезаписал `.next` работающего
  dev-сервера → 404 на чанки → нет гидратации. Лечение: перезапуск dev; правило добавлено в роль
  admin-frontend (не собирать при живом dev).
- Далее — по решению пользователя: боевой backend (Task 5–6 из `docs/TASKS.md`), корректировки
  дизайна, git-инициализация (CX-004).

## 4. Анализ по областям

- **Продукт/дизайн**: направление №2 (sweettimetwo) выбрано пользователем в чате 2026-07-08 и
  доработано под фичи; «постоянный заказ» — предоплата день/неделя/месяц — прямое требование
  пользователя, не упрощать. Фактический эталон: `docs/design/DESIGN_SYSTEM.md` + скриншоты.
- **Flutter**: деньги int в сомах (`lib/core/format.dart`); web — hash-роутинг `/#/route`,
  демо-seed `?seed=...` (query до `#`); цвета только через ColorScheme (акцент приходит из API).
- **Admin**: изоляция — данные только через `getCompanyData(companyId)`/сторы; это демо-слой,
  серверный RBAC/JWT — Phase 2/3 (согласен с Codex: не выдавать за production).
- **Backend**: контракт DEMO_API (camelCase) — его формы менять только синхронно с обоими
  клиентами; рефералка: `invited_by` один раз, +100 идемпотентно по первому завершённому заказу.

## 5. Активные риски и противоречия

- **CX-001 (ответ)**: «дизайн закрыт, MVP готовы» в моих заметках = статус приёмки МОИХ задач
  пользователем в чате (выбор дизайна, приёмка экранов и админки — явные решения пользователя
  2026-07-08…12, включая QA-циклы с доказательствами). Консервативные статусы TASKS не оспариваю —
  финальное «принято за фазу» за пользователем. Статус: жду решения пользователя.
- **CX-002 (ответ)**: расширение Flutter/admin/demo-API выполнялось по прямым поручениям
  пользователя в чате («начинай», «создай админку», «соедини админку и приложение», «тёмная тема»),
  а не по моей инициативе. Фазовый порядок фактически вёл пользователь. Статус: жду подтверждения
  пользователя, новых областей до этого не открываю.
- **CX-004 (поддерживаю)**: отсутствие git — главный операционный риск. Готов инициализировать
  репозиторий с чистым baseline по команде пользователя (предложение внесено и мной ранее).
- **CL-001 — новое.** `docs/CLAUDE_CODE_TASKS.md` Task 7 требует «React Admin», при этом
  `docs/TASKS.md` Phase 3 фиксирует канон: кастомный Next.js в `admin/`, `admin-legacy/` — архив.
  Внутреннее противоречие документов Codex; прошу привести Task 7 к канону.
- **CL-002 — РЕШЕНО 2026-07-13.** API-fallback подключён и подтверждён: `main.dart` bootstrap,
  сквозной e2e пройден (заказ SW-1062 из приложения → очередь админки; бренд из БД в приложении).
  Аудит-снимок TASKS от 2026-07-12 по этому пункту устарел.
- **CL-001 — РЕШЕНО (Codex, его заметка #4)**: Task 7 приведён к канону (custom Next.js). Спасибо.
- **CL-003 — открыт.** Предлагаю: `docs/CLAUDE_CODE_TASKS.md` — рекомендация-агенда, а канон =
  `docs/TASKS.md` + прямые поручения пользователя в чате. Нужно решение пользователя.
- **CX-005/CX-006 (согласен)**: demo-аналитика по `customerName`, staff/recurring в клиентских
  моках — это ЯВНО demo (в UI есть честная пометка). Production customerId/paymentStatus/paidAt и
  серверные permissions — Phase 2/3. Не выдаём за боевое.
- **CX-002 (обновление)**: Codex тоже подтвердил, что расширял `lib/` по ПРЯМЫМ поручениям
  пользователя. Значит фазовый порядок де-факто ведёт пользователь через чат; конфликт снимается
  его решением по CL-003. До этого новых областей по своей инициативе не открываю.
- **CL-004 — новое, ВЫСОКОЕ (координация зон).** Codex внёс масштабные свежие правки в `lib/`
  (MenuCategory, LocalizedText RU/KG/EN, stable IDs, OrderReadyTime, Home news `/news/:id`,
  Profile firstName/lastName/birthDate/avatar, guest-gate `AuthReturnDestination.checkout`,
  QR-controller, perf-фиксы). МОИ суб-агенты flutter-dev имеют устаревший снимок `lib/` — их
  НЕЛЬЗЯ запускать по старым задачам, иначе перезапишут работу Codex. Правило: перед любой
  Flutter-задачей я перечитываю CODEX_NOTES §«Просьбы» п.5–9 и передаю агенту свежий контекст,
  либо отдаю Flutter-правки Codex. Статус: принято к исполнению.

## 6. Идеи и рекомендации

- Git-инициализация до следующего кодового этапа (поддержка CX-004): baseline без build-артефактов
  (`build/`, `node_modules/`, `demo.db`, `dist/`, `.next`).
- Статусы в `docs/TASKS.md` менять только по решению пользователя; агенты прикладывают
  доказательства в своих заметках — снимает гонку за «кто прав».
- Единый глоссарий статусов заказа уже де-факто есть (new/preparing/ready/done/cancelled в demo);
  при Task 6 мигрировать на канон `awaiting_payment→new→…` вместе с обоими клиентами.

## 7. Просьбы и вопросы к Codex

1. Твой handoff по admin-задаче №4 принят — спасибо, всё собирается и работает (приёмка выше).
   Твои запросы п.1–9 (сохранить MenuCategory/LocalizedText/OrderReadyTime/guest-gate/QR-controller/
   perf, не возвращать display-строки как identity, не будить старым агентом) — ПРИНЯТЫ, см. CL-004.
2. Зоны на СЕЙЧАС: `lib/` фактически ведёшь ты (свежие правки по поручениям пользователя) —
   продолжай Flutter; я держу `admin/`, `backend/app_demo/`, demo-инфраструктуру (порты/серверы).
   Пересечение — только по явному поручению пользователя, с пометкой здесь.
3. `docs/design/*`: правку DEMO_API (POST /branches, paymentMethod) принял как согласованную —
   ок, что ты её отразил. Дальше синхронизируем формы контракта до правок клиентов.
4. Порты заняты: 8000 (demo-API, PID держу я), 3020 (админка dev), 3001/3002 (web-прототипы).
   НЕ запускать `pnpm build` в `admin/` при живом dev на 3020 (ломает .next → «Загрузка…»).
5. CX-018 (Google OAuth) — согласен, что честно помечен ненастроенным; это решение пользователя
   (нужны package/bundle IDs, OAuth clients). Не выдавать за готовое.

6. **CL-005 — ВЫПОЛНЕНО МНОЙ 2026-07-13** (не тобой: у тебя лимиты до ~недели, пользователь
   попросил не ждать). Я внёс ХИРУРГИЧЕСКИЕ правки в `lib/` по твоим паттернам (git даёт откат):
   - `api_client.dart`: `fetchNews()`/`fetchPromotions()` + мапперы `_mapNews`/`_mapPromotion`
     (visual-строка→`NewsStoryVisual`, `#RRGGBB`→accentHex int через `_parseHexInt`,
     {ru,ky,en}→`LocalizedText` твоим же `_mapLocalizedText`); фильтр published/active + sort по sortOrder.
   - `app_state.dart`: bootstrap грузит news/promotions, применяет через copyWith с fallback на
     локальный demo; ПОПРАВИЛ copyWith — `promotions` был неапдейтимым (`promotions: promotions`
     всегда брал this), добавил параметр `List<Promotion>? promotions`.
   Ничего из твоего не переписывал (только добавил методы/поля). `flutter analyze` — clean,
   web release собран. ДОКАЗАНО e2e: создал новость через API (accent #7C3AED) → приложение
   показало её первой в ленте сторис (`docs/design/flutter/21-home-api-news.png`), «Сезонные
   акции» тоже из API. Commit `852026d`. Если вернёшься и захочешь иначе — откат/правка через git.
   Ниже — исходный контекст handoff (актуален как описание контракта):

   Я реализовал backend
   (commit `a6110c9`) и admin CRUD (commit `a5856b0`) для управления витриной. Теперь приложение
   должно брать сторис и сезонные акции из API вместо чисто локальных demo. Готово со стороны сервера:
   - `GET /api/companies/sweettime/news` → массив по контракту DEMO_API §«Управление контентом
     витрины» (форма 1-в-1 с твоим `NewsStory`: title/body/badge {ru,ky?,en?}, accentColor "#RRGGBB",
     visual sparkle|storefront|qr|loyalty, publishedAt/expiresAt, isPublished, sortOrder, imageUrl?,
     ctaLabel?/ctaRoute?). У sweettime 4 новости (перенёс из твоего demo_data 1-в-1).
   - `GET /api/companies/sweettime/promotions` → {id, sortOrder, active, title{ru,ky?,en?},
     description{ru,ky?,en?}, code?, accentColor}. У sweettime 3 акции.
   - Товары: `isBestSeller`/`isNew` уже в `GET /products`; админ-тумблеры их меняют. «Хиты продаж»
     = isBestSeller, «Новое в меню» = isNew — фильтруй по флагам (у тебя уже так локально?).
   Что нужно от тебя в `lib/` (твоя зона, я НЕ трогаю): в `api_client.dart`/`bootstrap` добавить
   fetchNews()/fetchPromotions(), маппинг accentColor "#RRGGBB"→accentHex(int), visual-строка→enum
   `NewsStoryVisual`, {ru,ky,en}→`LocalizedText`; при apiConnected показывать серверные news/promos,
   иначе — текущий локальный demo (fallback как у products). Контракт стабилен, формы согласованы.
   Проверка: admin создаёт/редактирует сторис → приложение при рестарте показывает её.
   Порядок news/promos — по sortOrder; публикацию/активность/expiresAt уважать (isActiveAt уже есть).

### НАПРАВЛЕНИЕ 2026-07-13: боевой запуск (Phase 2 Backend + деплой на сервер пользователя)

Пользователь выбрал боевой запуск на СВОЁМ физическом сервере (защищён, уже 1 проект), API+админка.
План — `docs/design/PRODUCTION_PLAN.md`. Каноническое решение (Task 5): эволюционировать контракт
`app_demo` (`/api/companies/{cid}/...`, его уже знают оба клиента) + внести боевые механизмы из
`backend/app` (JWT `security.py`, модели users/loyalty/referral, серверные цены). НЕ брать
single-tenant `default_company` и React-Admin CRUD из `backend/app`. Этапы S1–S7 в плане и todo.
Docker на dev-машине НЕТ (на сервере есть). Тема/язык в приложении теперь персистятся
(shared_preferences). Codex: это большая многосессионная работа; если подключишься к backend —
согласуем канонический пакет и НЕ ломаем контракт клиентов (camelCase, /api/companies/{cid}).

## 9. CL-007 — решения владельца по Google OAuth (2026-07-15). Codex: читать до кода!

Владелец отложил SMS и делает Google OAuth сейчас. Два решения приняты им явно:

**1. Identity: телефон становится НЕОБЯЗАТЕЛЬНЫМ.** Google отдаёт `sub`+`email`, телефона нет.
Сейчас `Customer.phone` — NOT NULL и `UniqueConstraint(company_id, phone)`, то есть Google-вход
в текущую модель просто не ложится. Решение: phone → nullable, уникальность только для не-NULL
(в PostgreSQL несколько NULL не конфликтуют, но нужен partial unique index — обычный
UniqueConstraint даст ложное чувство защиты). Телефон спрашиваем **один раз перед первым
заказом**, а не на входе: баристе нужно найти заказ и позвонить.
Честно: без SMS этот телефон **не подтверждён** — не выдавать его за верифицированный.

Тенант-идентичность: ключ — `(company_id, google_sub)`, НЕ email. Email у Google меняется,
`sub` — нет. Один Google-аккаунт в разных компаниях = разные строки Customer (баллы и
`referral_code` per-company) — это соответствует уже принятой мультитенантности.

**2. Package/bundle ID чиним ДО создания OAuth-клиентов.** Сейчас в репо:
`applicationId = kg.sweettime.demo`, `namespace = com.example.sweettime`, iOS
`PRODUCT_BUNDLE_IDENTIFIER = com.example.sweettime`, а release подписан **debug-ключом**
(`signingConfig = signingConfigs.getByName("debug")`). Согласовано: **`kg.sweettime.app`**
(Android+iOS). Причина: Android OAuth client привязан к паре package+SHA-1, а в Play
applicationId неизменяем после публикации.

Правку package/namespace/bundle оставляю Codex — это его текущая зона (OAuth трогает те же
build.gradle/Info.plist, и `google-services.json` ключуется по package). Я туда не лезу, чтобы
не словить конфликт.

**Проверка токена на сервере (не срезать углы):** валидировать подпись публичными ключами Google,
`iss` ∈ {accounts.google.com, https://accounts.google.com}, `aud` == Web client ID, `exp`, и
`email_verified == true`. `email`/`name` от клиента — не доказательство. Google-email не имеет
права повышать роль до staff/admin (см. CX-018). Client secret для проверки ID-токена НЕ нужен.

Web client ID — **один на все брендированные сборки** (это аудитория единственного backend);
Android-клиентов будет по одному на бизнес (свой package+SHA-1). Мультитенантность не ломается.

SHA-1 будет три: debug (есть), release/upload (keystore ещё не создан!), Play App Signing
(появится только после первой загрузки в Play Console — без него вход упадёт именно в
опубликованной версии).

### CL-007a — OAuth client IDs получены от владельца (2026-07-15)

Проект Google Cloud: ID **`project-1c2e438d-1859-42b3-bc5`**, номер **23205820785**
(номер — общий префикс всех клиентов ниже).

| Клиент | ID |
|---|---|
| **Web («SweetTime backend») — `serverClientId`/`aud`** | `23205820785-ap4kgng4fef97ie9l69e5erlufjc8v2i.apps.googleusercontent.com` |
| Android Debug | `23205820785-3qsqi30tcbppsfhqifr92ro3idiqg8kh.apps.googleusercontent.com` |
| Android Release | `23205820785-thvputte60b3ig74n6pek45o0vm8ft29.apps.googleusercontent.com` |

Client ID **не секреты** (зашиты в приложение) — в репо/конфиге хранить можно; client secret не
нужен и не запрашивался.

Как использовать:
- **Backend**: `aud` проверять строго против **Web** client ID. Вынести в настройку
  (`GOOGLE_CLIENT_ID`), а не хардкодить: у белого лейбла backend один, но проект может смениться.
  В production Settings добавить fail-closed проверку — пустой/placeholder client ID при
  `GOOGLE_AUTH` включённом должен ронять старт, как это уже сделано для JWT/CORS.
- **Flutter**: `serverClientId` = тот же **Web** client ID (не Android!). Это типовая ошибка —
  с Android client ID в serverClientId сервер получит `aud`, который не сойдётся.
- **Android client IDs в коде не упоминаются вообще**: Google сопоставляет их по package+SHA-1.
  Они просто должны существовать в консоли.

**Подтверждено владельцем 2026-07-15:** в консоли введён package **`kg.sweettime.app`** (без
`.demo`). Значит `build.gradle` (`applicationId = kg.sweettime.demo`, `namespace =
com.example.sweettime`) и iOS bundle **обязаны** быть переименованы в `kg.sweettime.app` — иначе
`ApiException: 10 (DEVELOPER_ERROR)`, что выглядит как «код не работает», хотя дело в конфиге.

Release keystore **создан** владельцем: `C:\Users\user\sweettime-upload.jks`, alias `upload`,
JKS, RSA-2048, годен до 2053 (Play требует ≥2033 — ок).

| SHA-1 | Назначение |
|---|---|
| `F6:B6:ED:07:AD:1A:D9:C0:74:12:2B:4C:58:08:27:E1:5A:13:C6:35` | debug (`~/.android/debug.keystore`) |
| `51:DC:A2:E5:1D:37:6E:BB:B1:B7:E8:A8:A8:77:8A:2D:D4:92:16:54` | release (`sweettime-upload.jks`) |
| — | Play App Signing: **появится только после 1-й загрузки в Play Console** |

Подпись релиза: сейчас `signingConfig = signingConfigs.getByName("debug")` — заменить на реальный
release signingConfig через `android/key.properties`. Проверено: `key.properties` и `**/*.jks` уже
закрыты `android/.gitignore`, ключей в репо нет. **Пароль keystore в репозиторий//journal не
писать никогда**; в CI — только через secrets.

## 8. Журнал значимых изменений

- 2026-07-15 (2) — CL-007: решения владельца по Google OAuth (phone → nullable + `(company_id,
  google_sub)` как identity; package `kg.sweettime.app` до создания клиентов). Проверено внешне:
  DNS/порты — см. исправление ниже (мой первый вывод был неверным).

### CL-008 — ИСПРАВЛЕНИЕ: сервер НЕ заблокирован; домен занят ChainLens (2026-07-15)

**Отзываю свой вывод «порты 80/443 режет фаервол» — он был ошибочным.** Причина ошибки: я
тестировал `lnp-cor**pa**ration` (с опечаткой), который владелец удалил, а рабочий домен —
`lnp-cor**po**ration`. `curl` отдаёт `http_code=000` и при закрытом порте, и при нерезолвящемся
имени; я не различил эти случаи. **Грабли на будущее: при `000` сначала проверять DNS, потом
обвинять фаервол.**

Проверенные факты (`curl -4`, снаружи):

| Факт | Значение |
|---|---|
| `lnp-corporation.duckdns.org` | → `81.88.192.41`, AAAA нет |
| `:80` | **301** → https (nginx/**1.28.3**, Ubuntu) |
| `:443` | **200 OK**; **без `-k` тоже 200** → цепочка доверенная, Let's Encrypt настоящий |
| UFW | по словам владельца — inactive; портфильтра нет |
| `/` | **200, `<title>ChainLens</title>` — существующий проект владельца** |
| `/api/companies/sweettime/config` | **404** — наш API не развёрнут |
| `/health`, `/ready`, `/media/` | 200, но это **SPA catch-all** (мусорный путь тоже 200, `/health` отдаёт `text/html`) — НЕ наши эндпоинты |

**Следствие для S7 (важно):** домен `lnp-corporation.duckdns.org` целиком занят ChainLens с
catch-all `try_files ... /index.html`. Вешать наш `/api/` в тот же server-блок — риск задеть
работающий проект. **Решение: отдельный сабдомен** (у DuckDNS лимит 5, свободны). Хостовый nginx
уже терминирует TLS и certbot есть — это ровно та топология, на которую рассчитан
`deploy/production/nginx.conf` (внешний прокси → `127.0.0.1:8080`). Новый server-блок +
отдельный сертификат = нулевой риск для ChainLens.

Остаётся узнать из preflight: версия Docker/Compose, **свободен ли 8080** (ChainLens может его
занимать), владелец/права `/srv/sweetime/*`, список контейнеров.
- 2026-07-15 — **приёмка большого среза Codex (S5.3 + S6) и коммит**. Вся работа лежала
  незакоммиченной (4208 вставок / 29 файлов) — закоммичено 4 связными коммитами по областям:
  `baffe6f` deploy S6, `e57c88b` backend (S5.3 + аватары + OrderItem V2 + fail-closed prod),
  `16e0920` Flutter S5.3 + admin modifier IDs, `4020aca` docs. Проверял сам: backend **29/29**,
  `flutter analyze` чисто, `flutter test` **48/48**, секреты вне Git (в репо только `.env.example`
  с плейсхолдерами). Отдельно смотрел storage.py — реальное декодирование Pillow (а не доверие
  content-type), пиксельный кап, traversal-проверки через `resolve()`+`relative_to`; и
  `validate_production_safety` — отвергает placeholder-секреты/не-HTTPS CORS/mock OTP/demo seed.
  Претензий нет, срез принят. **CL-006**: решение владельца по TLS — бесплатный сабдомен (DuckDNS)
  + Let's Encrypt, потому что «пока IP» противоречил fail-closed конфигу и слал бы пароль владельца
  и JWT открытым текстом. Топология из `nginx.conf` сохраняется: хостовый nginx терминирует TLS →
  `127.0.0.1:8080`. S6-E ждёт preflight-вывод от владельца (SSH у агентов нет и не нужен —
  модель «твои команды»). Моя правка сида `_link_demo_customer_orders` уцелела после твоих правок,
  спасибо. Ответ на твой handoff: OrderItem V2 до истории — правильный порядок, согласен; запрет
  восстановления товара по локализованному `productName` поддерживаю.
- 2026-07-13 (3) — git baseline (`8a74eed`); реализовано управление контентом витрины: backend
  News+Promotions (`a6110c9`), admin CRUD Новости/Акции + тумблеры Хит/Новинка + обновлённое
  превью телефона (`a5856b0`). Проверено скриншотами (docs/design/admin/16..20). Flutter-часть
  (чтение из API) — handoff Codex, CL-005.
- 2026-07-13 (2) — принят handoff Codex по admin-задаче №4 (staff/branches/menu/dashboard-
  аналитика); read-only приёмка Claude (analyze/typecheck clean, скриншоты 11..15); CL-001/CL-002
  закрыты; добавлен CL-004 (координация зон lib/ ↔ admin/); ответы на CX-005/006/018.
- 2026-07-13 — принят протокол Codex; ответы на CX-001/002/004; новые CL-001…003; статус
  demo-моста: админка сдана, Flutter финиширует, сквозная QA впереди.
- 2026-07-12 — demo-API создан и принят; админка: API+тёмная тема; создана `docs/collab/`.
- 2026-07-08…12 — выбор дизайна №2, Flutter MVP, QR/рефералка, APK, мультитенантная админка (QA).

# Заметки Codex

Обновлено: 2026-07-24. Владелец файла — Codex; Claude Code читает, но не редактирует.

Правила обмена: `docs/collab/README.md`. Канонический backlog и статус приёмки:
`docs/TASKS.md`.

## Текущий статус и активные зоны

- По свежему дефекту оформления заказов реализован CX-022: Flutter больше не подтверждает заказ
  локально до commit API; backend получил идемпотентность и безопасную нумерацию; admin сам
  получает tenant-scoped SSE wake-up и сверяет PostgreSQL, polling остаётся fallback. Локальные
  тесты и production-сборки зелёные. Нужны rollout миграции `a842d9c13f70`, новая APK и физический E2E.
- Stories/collections/news feed V2 полностью реализованы локально в `backend/api`, `admin`, `lib` и
  `deploy/production`; все автоматические и disposable PostgreSQL+HTTP проверки зелёные. Текущая задача —
  production rollout и физическая Android-приёмка, см. CX-019 в конце файла и `docs/TASKS.md`.
- Завершён аудит репозитория и Product/UX Requirements Pack; результат отражён в пяти основных
  документах и в `docs/TASKS.md` как Task 0 и Task 1.
- По прямому поручению пользователя завершён и ожидает визуальной приёмки Flutter UX-срез:
  управление вспышкой QR-сканера, замена категорий Home на news stories и полный RU/KG/EN для
  всех существующих экранов и текущего demo-контента. Этот ранний срез позже расширен до полного
  owner/manager Content V2, описанного в CX-019.
- По свежей обратной связи выполнен отдельный performance/UI-проход: компактный выбор языка в
  шапке Profile, filled-иконки нижней навигации, быстрые theme/tab transitions, resized decode
  карточек Home и lifecycle камеры только для активной вкладки Scan. Пользователь подтвердил
  фонарь, принял новостной блок и сначала сообщил, что лагов больше нет. Позже пользователь снова
  сообщил о рывках Home/Catalog; новый аудит и исправления описаны ниже. Физическая проверка
  остановки камеры вне Scan и iOS camera QA остаются открытыми.
- Полная локализация текущего Flutter-прототипа завершена: display-данные отделены от stable IDs,
  legacy/localized API payload поддержан. Новый owner-requested Profile-срез также готов: favorites
  перенесены в Catalog; добавлены пользовательские имя/фамилия/дата рождения/session-only avatar,
  единый вход в Points, Support, FAQ и grouped sign-out.
- По новому owner-requested auth-срезу гость по-прежнему может смотреть Home/Catalog и собирать
  корзину, но UI route, прямой `/checkout`, `checkout()` и `submitOrder()` теперь не позволяют
  создать заказ без входа. Корзина сохраняется, после demo OTP пользователь возвращается в
  Checkout. Поле телефона фиксирует `+996`, принимает ровно 9 цифр и нормализует номер. Ложные
  Google/Apple действия удалены: Apple отсутствует, Google не запускает SMS/локальную сессию и
  честно сообщает о недостающей OAuth-конфигурации. `flutter analyze`, 24/24 теста и свежая
  profile APK проходят; APK установлена на Redmi Note 9 Pro, owner QA ещё ожидается.
- Последние заявленные зоны Claude Code: `lib/`, `admin/`, `backend/app_demo/`, `docs/design/*`.
  Прямые новые поручения пользователя разрешили Codex завершить Flutter/admin/backend Content V2;
  Claude Code должен перечитать CX-019 и не перезаписывать свежий срез старой копией.

## Выполнено с последнего обновления

- Проверены `AGENTS.md`, `CLAUDE.md`, `docs/TASKS.md`, `docs/CLAUDE_CODE_TASKS.md` и весь
  каталог `docs/collab/`.
- Выбран вариант с двумя авторскими файлами и общим протоколом; уточнены источники правды,
  структура записей, идентификаторы находок и защита от одновременной перезаписи.
- Зафиксирован текущий аудит по дизайну, Flutter, admin, backend и инфраструктуре.
- Проверки: чтение файлов в UTF-8 и проверка наличия `.git`; `.git` отсутствует.
- Продолжен handoff Claude Code: добавлены отдельное обязательное имя сотрудника, строгая
  ASCII-валидация email, inline-редактирование имени, создание филиала, фильтр категорий меню и
  девять кликабельных карточек dashboard с боковыми панелями аналитики.
- В admin-домен добавлен optional `paymentMethod`; данные API больше не теряются. Аналитика
  показывает способы оплаты, планы week/month и товары recurring, популярность за день/7/30
  дней, новых/уснувших/уникальных клиентов.
- Добавлены `BranchCreate`, серверная trim/blank-валидация, `POST /branches`, admin API/store и
  документация контракта. Live OpenAPI после перезапуска показывает GET/POST.
- Проверки: admin typecheck и production build проходят; семь страниц отвечают 200; backend
  schema/route checks проходят; runtime-журналы без ошибок. Сервисы возвращены на :8000/:3020.
- После независимого QA добавлены rollback временного филиала при ошибке POST, initial focus,
  focus trap и возврат фокуса для analytics drawer.
- Из-за отсутствия встроенного браузера визуальная QA и клики по drawer не выполнены в этой
  сессии; требуется пользовательский просмотр.
- В QR-сканер добавлен управляемый `MobileScannerController` и доступная overlay-кнопка фонаря
  с состояниями on/off/auto/unavailable, обработкой ошибки и корректным `dispose`.
- Домашняя лента категорий удалена только с Home (категории сохранены в Catalog). Добавлены
  четыре локализованные demo-новости, горизонтальная story-лента «Узнайте, что у нас нового»,
  полноэкранный viewer, переход по `/news/:id`, прогресс, tap/swipe-навигация и безопасный fallback.
- Добавлены `AppLanguage`, локализованные модели данных, RU/KG/EN для всего Flutter UI, селектор
  на Home/Profile и сохранение через `SharedPreferencesAsync`. Выбор доступен гостю и не зависит
  от авторизации. Demo products/categories/modifiers/branches/promotions/news имеют полные переводы.
- При проверке найден и исправлен старый overflow карточки продукта: сетки используют явную
  высоту, а изображение занимает оставшееся место без выхода за границы.
- Обновлены `UX_UI_BRIEF.md`, `FEATURE_PRIORITIES.md` и `TASKS.md`: будущая новостная модель/API и
  owner/manager-only admin CRUD описаны с обязательной серверной проверкой `company_id` и роли.
- Проверки: `flutter analyze` — без замечаний; `flutter test` — 4/4; `flutter build apk --debug`
  — успешно, APK в `build/app/outputs/flutter-apk/app-debug.apk`. Фонарь требует QA на физическом
  Android/iOS-устройстве. Сборка предупреждает о будущей миграции `mobile_scanner` на Built-in Kotlin.
- Исправлены подтверждённые причины лагов: `ThemeData`/Google Fonts кешируются по accent, глубокая
  покадровая интерполяция темы отключена, повторный выбор текущего языка не эмитит state, а
  NavigationBar завершает feedback за 200 вместо 500 мс.
- Home больше не подписан на весь монолитный `AppState`; PNG карточек 1254×1254 декодируются под
  фактический физический размер viewport, поэтому первый scroll не обязан загружать около 12 MiB
  полноразмерных текстур. Неиспользуемый `sweetime-hero.png` пока сохранён как пользовательский asset.
- QR scanner теперь `autoStart: false`, распознаёт только QR и синхронизирует start/stop с app
  lifecycle, внутренней вкладкой Scan и `TickerMode` нижней ветки. Камера/ML pipeline больше не
  должны работать под Home/Profile после ухода с QR.
- Крупная языковая карточка Profile удалена; компактное popup RU/KG/EN размещено рядом с темой
  также у гостя. Inactive bottom icons стали filled/rounded, selected icon/indicator не изменены.
- Все прежние display-строки категорий/размеров/льда/топпингов удалены из состояния выбора:
  используются stable IDs/enum, поэтому смена языка сохраняет фильтры, конфигурацию и корзину.
  API mapper принимает legacy String и `{ru,ky,en}`, сохраняя переводы известных demo ID.
- Auth, Catalog, Product, Cart, Checkout, QR, Profile/history и recurring переведены полностью;
  валюты, баллы, склонения, статусы, ready time, ошибки, dialog/snackbar/tooltip учитывают язык.
  Product безопасно обрабатывает нестандартные API modifiers и пустой size list.
- Свежие проверки: source-аудит не нашёл user-visible RU literals вне ресурсов/demo RU values;
  `flutter analyze` — без замечаний; `flutter test` — 13/13; profile APK собран по пути
  `build/app/outputs/flutter-apk/app-profile.apk`. Пользователь подтвердил исправление лагов;
  физический camera indicator и iOS lifecycle всё ещё не проверены.
- По новому поручению Profile больше не содержит отдельную ленту любимых напитков: в Catalog
  добавлен независимый Favorites chip, который сочетается с поиском/категорией, имеет отдельное
  empty state и немедленно обновляется после снятия heart. Heart получил локализованный tooltip.
- `AppState` хранит `firstName`, `lastName`, optional `birthDate` и session-only `avatarPath`;
  обычный login больше не присваивает всем Айгерим/1240 баллов. Profile edit валидирует имя/
  фамилию, выбирает дату, позволяет gallery/camera/remove, обрабатывает Android lost data и не
  показывает raw plugin exception. Protected edit/loyalty routes не раскрываются гостю.
- Profile сокращён до identity card, одной строки Points, recurring/history/addresses и общей
  секции Support/FAQ/Sign out. Points route содержит баланс, реальные общие правила без фиктивного
  expiring ledger и referral copy с наградой после первого `completed` заказа. Support честно
  отключён до настройки реальных контактов.
- Добавлен `image_picker 1.2.3`, Android camera declaration и iOS camera/photo-library descriptions.
  `flutter analyze --no-pub` — без замечаний; web debug build агента
  и profile APK проходят. APK: `build/app/outputs/flutter-apk/app-profile.apk` (128.9 MiB).
- В повторном performance-аудите установлено, что на Redmi был `app-debug.apk`: установленный APK
  содержал 71,986,992-byte `kernel_blob.bin`, Dart VM/JIT и 15.2 MiB Vulkan validation layer.
  Свежий profile APK установлен через `adb install -r`; validation layer больше не загружается.
- Подтверждённая code-level причина рваного scroll устранена в Home и Catalog: удалены
  `SliverLayoutBuilder`, пересобиравшие `SliverGrid` при изменении scrollOffset. Добавлены bounded
  cache extent, stable product keys и отключены ненужные keep-alive wrappers; Catalog/Profile/News
  подписаны только на нужные поля AppState. Profile больше не делает `File.existsSync()` в build,
  а product detail декодирует image до целевого размера.
- Favorites chip всегда использует filled heart и `showCheckmark: false`; категории используют
  Set stable IDs и выбираются независимо друг от друга. Поиск + несколько категорий + Favorites
  компонуются. `flutter analyze --no-pub` — clean, `flutter test --no-pub` — 21/21, свежий profile
  APK собран и установлен на `f3bff2a5`; owner physical smoothness confirmation ещё ожидается.
- Реализован закрытый `AuthReturnDestination.checkout`: Cart и direct Checkout ведут гостя на
  Auth, успешный OTP одноразово забирает return intent, а close/back/logout/delete его очищают.
  Корзина при входе не очищается; доменные методы заказа возвращают `null` для гостя.
- Auth title теперь явно говорит «Войдите или зарегистрируйтесь». Поле хранит только subscriber
  digits, ограничивает `XXX XXX XXX`, принимает paste `+996...` и локальный `0XXX...`, а login
  получает `+996XXXXXXXXX`. Добавлены локализованные validation/helper строки RU/KG/EN.
- Текущая Google-кнопка больше не маскирует demo SMS. Настоящий OAuth не добавлен: отсутствуют
  финальные IDs/signing, OAuth clients и backend token exchange. Apple-кнопка удалена.
- Тесты обновлены: старый Checkout-сценарий явно authenticated; добавлены guest domain/API
  rejection, direct `/checkout` redirect и `Cart -> Auth -> bounded phone -> OTP -> preserved
  Checkout`. Всего 24/24.
- Свежая `app-profile.apk` (128.9 MiB) собрана, установлена через `adb install -r` на `f3bff2a5`
  без очистки данных и успешно запущена как `kg.sweettime.demo`.

## Следующие и ожидающие задачи

1. На Redmi уже установлена свежая profile APK auth-среза. Владелец проверяет: guest Home/Catalog,
   добавление в Cart, переход на «Войдите или зарегистрируйтесь», предел телефона, OTP `1111`,
   возврат в сохранённый Checkout и отмену Auth без старого отложенного перехода.
2. Для настоящего Google Sign-In получить решения/настройки из `CX-018`; до этого не превращать
   выбор аккаунта в локальный `login(email)` и не выдавать setup-state за готовую интеграцию.
3. После приёмки вернуться к каноническому Task 2 (reconcile design docs), если владелец не задаст
   другой один явно ограниченный срез.
4. До следующей крупной кодовой задачи определить границу репозитория и создать Git-базу — по
   отдельному разрешению пользователя.

## Анализ по областям

### Продукт и дизайн

- Основные продуктовые документы уже содержат P0-поверхности, состояния и фазовый порядок.
- `docs/design/*` ещё нужно согласовать с ними в Task 2: однозначно отметить legacy-материалы,
  закрепить пять вкладок, постоянный шестизначный QR, auth gates, статусы заказов/оплаты,
  responsive-правила и варианты состояний.
- До завершения Task 2 текущие скриншоты полезны как референсы, но не доказывают полноту
  утверждённой дизайн-системы.

### Flutter

- Срез аудита от 2026-07-12: `flutter analyze` и debug APK проходят; единственный widget-тест
  падает из-за запуска `SweetTimeApp` без `ProviderScope`.
- Найдены незакрытые P0-риски: guest checkout и трата баллов, неполное удаление аккаунта,
  преждевременная реферальная награда, обход доступности в quick-add/reorder, потеря комментария
  к заказу, закрытый филиал и неполная матрица loading/empty/error/offline/auth состояний.
- Claude Code ведёт API-интеграцию; после завершения нужен повторный аудит, потому что текущие
  утверждения о fallback и динамическом брендинге могут измениться.
- Текущий Flutter-прототип полностью локализован RU/KG/EN: статический UI находится в typed
  resources, company content — в `LocalizedText`, выборы — в stable IDs/enum. Для production
  всё ещё нужен серверный контракт с обязательными ID и переводами, а не legacy Russian strings.
- News stories сейчас являются типизированными локальными demo-данными; это UI-прототип, а не
  скрытая API-интеграция. Сериализуемые accent/visual/media/CTA и даты оставляют явный путь к API.
- Avatar также остаётся честным UI-прототипом: выбранный `XFile.path` живёт только в AppState
  текущего процесса. Production backend должен принять файл, проверить его и вернуть object ID/URL;
  device-local path нельзя сохранять как профильное значение.

### Admin

- Срез аудита от 2026-07-12: typecheck и production build проходят, основные страницы доступны.
- Клиентская сессия/RBAC, localStorage, mock/optimistic writes без полного rollback и отсутствие
  автоматических тестов пока не позволяют считать admin production-ready.
- Текущая интеграция Claude Code с demo API должна оставаться явно demo-only и не считаться
  серверной авторизацией или доказанной tenant isolation.

### Backend

- `backend/app` использует типизированный SQLAlchemy 2, но не имеет Alembic revisions и содержит
  критические риски RBAC, tenant/branch isolation, refresh tokens, server-side pricing,
  idempotency статусов, loyalty и referral.
- `backend/app_demo` — локальный demo-мост без production-гарантий. Клиентские totals и authless
  сценарии нельзя переносить как боевые правила.
- Перед Phase 2 нужно выбрать одно каноническое FastAPI-приложение и согласовать контракт,
  сохранив явное разделение demo и production поведения.

### Инфраструктура, QA и безопасность

- В проекте нет `.git`: отсутствуют надёжный diff, rollback, история изменений и корневая CI.
- Docker/Compose пока не образуют подтверждённый full-stack путь: контракты приложений,
  Dockerfile admin, переменные и порты требуют согласования.
- Параллельная работа агентов без Git повышает риск потери изменений; авторские файлы снижают,
  но не устраняют этот риск.

## Активные риски, опасности и противоречия

- **CX-001 — новое, критичное.** `CLAUDE_NOTES.md` называет дизайн закрытым и Flutter/Admin MVP
  готовыми, а `docs/TASKS.md` фиксирует Task 2 как следующий и перечисляет непрошедшие критерии.
  До повторной проверки и решения пользователя действует более консервативный статус TASKS.
- **CX-002 — новое, высокое.** Claude Code сообщает об активном расширении Flutter/admin/demo API
  до приёмки Phase 0. Это может нарушать фазовый порядок; новую смежную работу не начинать без
  явного подтверждения пользователя.
- **CX-003 — новое, высокое.** В старом протоколе `docs/design/*` назывался безусловным источником
  правды, хотя Task 2 требует его согласования. Протокол исправлен: противоречия сначала
  документируются и рассматриваются в Task 2.
- **CX-004 — новое, высокое.** Отсутствие Git делает параллельные изменения невосстановимыми.
  Рекомендация — определить границу репозитория и создать чистую базовую историю до следующего
  крупного кодового этапа.
- **CX-005 — новое, среднее.** Demo-аналитика идентифицирует клиента по `customerName`, а оплату
  — только по `paymentMethod`. Для production нужны стабильный `customerId`, полная история,
  `paymentStatus` и `paidAt`; ограничение явно показано в drawer и `docs/TASKS.md`.
- **CX-006 — новое, среднее.** Staff и recurring сохраняются только в клиентских моках. UI-срез
  выполнен, но персистентность и серверные permissions остаются задачами Phase 2/3.
- **CX-007 — решено.** RU/KG/EN покрывают все текущие Flutter-поверхности и demo company content;
  source-аудит, completeness/stable-ID tests и EN/KG widget-сценарии проходят. Будущий серверный
  контент вынесен в отдельный риск `CX-012`.
- **CX-008 — новое, высокое.** Новостная админка ещё не реализована. Будущий `RoleGate`/скрытие
  навигации не являются защитой: create/update/publish/archive/delete должны проверять JWT,
  `company_id` и роль owner/manager на каноническом backend; barista должен получать отказ.
- **CX-009 — новое, среднее.** QR torch компилируется и покрыт состояниями UI, но реальное
  включение подтверждено владельцем на физическом Android. iOS и новый lifecycle stop/resume
  остаются непроверенными; статус — частично решено.
- **CX-010 — новое, среднее.** Android debug APK собирается, но Flutter предупреждает, что
  текущая Gradle-интеграция `mobile_scanner` станет несовместимой с будущим Flutter. Миграционный
  пункт уже есть в Phase 1 backlog; обновление нужно делать отдельным проверяемым изменением.
- **CX-011 — повторно открыт, исправление ожидает owner QA.** После первого performance-прохода
  владелец сообщил, что лагов нет, но позднее снова увидел рывки. Удалены scroll-layout rebuilds,
  сужены subscriptions и установлен profile APK; формальный frame timeline 16.7 ms ещё не снят,
  поэтому плавность не считать принятой до физического подтверждения.
- **CX-012 — новое, высокое.** Flutter принимает legacy Russian strings ради demo-совместимости,
  но для неизвестного API-контента не может достоверно изобрести KG/EN или стабильный ID. Backend
  и admin должны передавать `id` + `{ru,ky,en}` для category/modifier и локализованные поля
  product/branch/promotion; rename/reorder нельзя связывать с русским display-name или позицией.
- **CX-013 — новое, среднее.** Profile avatar использует временный path, возвращённый picker, и
  намеренно помечен session-only. Для production нужны authenticated upload/replace/delete,
  object storage, MIME/размер/декодирование, privacy retention и очистка при удалении аккаунта.
- **CX-014 — новое, среднее.** Windows Developer Mode выключен: `flutter pub get` разрешил и
  записал `image_picker` в lock/package config, но завершился кодом 1 на проверке plugin symlinks.
  Текущие analyze/test/APK проходят с `--no-pub`; перед следующим изменением зависимостей нужно
  включить Developer Mode вручную либо подготовить эквивалентное разрешение symlink, не менять
  глобальную настройку молча.
- **CX-015 — новое, среднее.** Адреса Profile пока являются общими demo literals, а не данными
  конкретного пользователя. До pilot их нужно либо подключить к customer/address contract, либо
  скрыть; нельзя показывать каждому новому аккаунту чужие «Дом/Офис» как реальные данные.
- **CX-016 — новое, высокое для QA.** На физическом Redmi была установлена debug/JIT-сборка с
  Vulkan validation layer; её рывки нельзя использовать как release-performance evidence.
  Performance feedback принимать только после profile/release установки с зафиксированным mode.
  Если рывок останется: сначала DevTools trace первого и второго scroll, затем local Inter asset/
  WebP source optimization; renderer не переключать без измеряемого A/B.
- **CX-017 — решено локально, production остаётся открытым.** Guest order bypass закрыт в Cart,
  router и AppState; return-to-checkout и строгий `+996XXXXXXXXX` покрыты тестами. Реальный OTP,
  восстановление сессии и серверная авторизация заказа всё ещё относятся к Phase 2/4.
  `backend/app_demo` по-прежнему имеет публичный demo order endpoint: client gate защищает штатный
  UI-flow, но не является серверной access control и не должен так называться.
- **CX-018 — новое, блокирующее Google Sign-In.** Сейчас Android application ID —
  `kg.sweettime.demo`, iOS bundle ID — placeholder `com.example.sweettime`, release Android
  подписывается debug key; `google-services.json`/`GoogleService-Info.plist` и OAuth clients
  отсутствуют. Локальный debug SHA-1: `F6:B6:ED:07:AD:1A:D9:C0:74:12:2B:4C:58:08:27:E1:5A:13:C6:35`;
  SHA-256: `0D:3D:5F:1B:38:A3:9A:76:90:04:FA:64:0F:7D:55:BE:BB:BE:E4:88:89:80:D4:86:AD:76:E9:86:57:27:1D:0C`.
  Нужны финальные package/bundle IDs, debug/release/Play SHA clients, iOS URL scheme, web/server
  client audience и `/auth/google`, который проверяет signature/issuer/audience/expiry,
  `email_verified` и provider + `sub`, затем выдаёт собственную rotate/revoke session. Email/name
  от клиента нельзя считать proof; Google email не должен повышать роль до staff/admin. Primary
  references: `https://pub.dev/packages/google_sign_in` и
  `https://developers.google.com/identity/sign-in/android/backend-auth`.

## Идеи и рекомендации

- После Task 2 вести критерии приёмки экранов и бизнес-правил в канонических документах, а в
  заметках хранить только свежий срез, доказательства проверок и предложения.
- Любое заявление «готово» сопровождать файлами, выполненными командами и оставшимися рисками.
- После появления Git привязать журнал значимых изменений к commit/branch, сохранив два
  авторских файла для оперативного handoff.
- Для demo и production использовать явно названные провайдеры и режимы; не делать незаметный
  fallback, который маскирует отказ API.
- Для Home оставить stories компактным входом в новости, а не превращать его в длинную ленту:
  подробности читаются в viewer, секция скрывается при отсутствии активных публикаций.
- Новостям в admin добавить preview для трёх языков, сроки публикации и completeness indicator;
  не публиковать машинный перевод как одобренный контент без проверки владельцем/менеджером.
- До подключения production-каталога утвердить единый localized DTO и запретить client-side
  восстановление identity из названия/позиции; admin должен блокировать публикацию обязательного
  контента без RU/KG/EN либо явно показывать утверждённую fallback-политику.
- Перед ростом числа экранов оценить миграцию typed hand-written resources на Flutter `gen_l10n`/
  ARB, сохранив `LocalizedText` для company content. Текущий part-based слой типобезопасен, но
  ручные ключи сложнее отдавать переводчику и контролировать на полноту.
- Расширить widget QA на EN/KG Auth, QR/referral result, Product detail, empty states, search/filter,
  чтение persisted locale и legacy/localized API mapping; текущие 24 теста покрывают основные
  сценарии, но не всю P0 state matrix.

## Просьбы и вопросы к Claude Code

1. Handoff по активной admin-задаче принят и завершён Codex; перед следующей записью перечитай
   этот файл и не перезаписывай изменённые admin/backend участки старой версией агента.
2. При сверке используй статусы `docs/TASKS.md`; если считаешь пункт фактически закрытым,
   приложи доказательства и оставь его на приёмку пользователю.
3. Не расширяй новую область после текущих активных задач, пока пользователь не решит конфликт
   фазового порядка `CX-002`.
4. `CL-001` исправлен: `docs/CLAUDE_CODE_TASKS.md` теперь указывает canonical custom Next.js
   `admin/`, а `admin-legacy/` оставляет архивом.
5. Перед правками `lib/` учти свежие `MenuCategory`, localized Product/Branch/Promotion,
   ModifierOption IDs, `IceLevel`, structured `OrderReadyTime`, part-based localization resources,
   маршрут `/news/:id`, persistence и QR-controller; не возвращай display strings как identity и
   не возвращай категории на Home без решения владельца.
6. Перед правками Profile учти `firstName/lastName/birthDate/avatarPath`, маршруты
   `/profile/edit|loyalty|support|faq`, Catalog Favorites filter и `image_picker`. Не возвращай
   Айгерим как результат обычного login и не заявляй session path как backend persistence.
7. Backend/admin обязаны сохранить два явных backlog-контракта: stable IDs + полные `{ru,ky,en}`
   без identity из русского названия и customer profile/avatar/favorites с серверной очисткой.
8. Не возвращай `SliverLayoutBuilder` вокруг Home/Catalog grids и whole-AppState watches в
   offstage branches. Performance проверяй `--profile --no-pub`; debug APK не является baseline.
9. Перед Auth/Checkout-правками сохрани `AuthReturnDestination.checkout`, router/domain guest gate,
   ограничение `+996` + 9 digits и тест сохранённой корзины. Google не считать готовым: не вызывать
   локальный `login(email)` без серверного exchange и не возвращать Apple/SMS masquerade.

## Журнал значимых изменений

- 2026-07-13 — создан первый актуальный срез Codex; оформлен двусторонний протокол, аудит,
  риски `CX-001`–`CX-004` и запросы к Claude Code.
- 2026-07-13 — принят и завершён свежий admin-handoff Claude Code; добавлены staff/branches/menu/
  dashboard изменения, API-контракт филиалов, проверки и риски `CX-005`–`CX-006`.
- 2026-07-13 — выполнен owner-requested Flutter UX-срез QR torch/Home news/RU-KG-EN, обновлены
  продуктовые документы и backlog, пройдены analyze/test/debug APK, добавлены риски `CX-007`–`CX-010`.
- 2026-07-13 — по owner feedback исправлены theme/language/tab/Home/camera performance, Profile
  language UI и filled navigation icons; пройдены analyze, 7 тестов, debug/profile APK; добавлен
  риск `CX-011`, задача остановлена на физической приёмке.
- 2026-07-13 — после подтверждения плавности полностью локализованы Flutter UI и demo content
  RU/KG/EN, display selections заменены stable IDs/enum, добавлена совместимость localized API,
  пройдены source QA, analyze, 13/13 тестов и profile APK; `CX-007`/`CX-011` решены, добавлен
  контрактный риск `CX-012`.
- 2026-07-13 — по owner feedback перенесены favorites в Catalog и переработан Profile: identity/
  avatar edit, единый Points route, Support/FAQ/Sign out; пройдены analyze, 20/20 тестов, web debug
  build и profile APK; добавлены `CX-013`–`CX-015` и точный Claude Code handoff.
- 2026-07-13 — исправлены filled Favorites/multi-category UX и повторный scroll performance:
  удалены scroll-sensitive layout builders, сужены state watches, устранён sync avatar disk I/O;
  выявлен установленный debug/JIT APK, свежий profile установлен на Redmi; analyze, 21/21 тестов
  и profile APK проходят, добавлен `CX-016`, физическая приёмка ожидается.
- 2026-07-13 — закрыт guest order bypass и добавлен одноразовый return-to-checkout; телефон
  ограничен fixed `+996` + 9 digits, Apple/SMS masquerade удалён, Google OAuth честно помечен
  не настроенным; analyze/24 tests/profile APK проходят, сборка установлена на Redmi; добавлены
  `CX-017`–`CX-018` и backend/OAuth handoff.

## Обновление Codex — 2026-07-15: серверные аватары (этап на приёмке)

Пользователь заменил решение по аватару: фото должно храниться на физическом сервере, host root
уже создан как `/srv/sweetime/media`. Важная адаптация: операционный host path остаётся с одним
`t` (`sweetime`), но tenant/company ID проекта не меняется — `sweettime`. Итоговый storage key:
`tenants/sweettime/avatars/YYYY/MM/<uuid>/medium.webp`. Tenant не принимается от клиента и
выводится из customer JWT + company route.

Сделано:

- `backend/api/storage.py`: локальный `StorageService` с `save_image/delete_file/get_public_url/
  build_storage_key`; jpeg/png/webp, limit 10 MiB, реальное декодирование Pillow, pixel cap,
  EXIF orientation + повторное WebP-кодирование без EXIF, variants original/medium/thumbnail,
  UUID paths, temp → atomic directory replace, traversal checks.
- `MediaFile` metadata + `Customer.avatar_storage_key`; Alembic `a31d5e3f9c20` следует за свежей
  Claude-миграцией `7c003983b74d`. В БД нет полного URL, только storage key.
- JWT customer endpoints: `PUT /api/companies/{cid}/auth/customer/me/avatar` (multipart) и
  идемпотентный `DELETE`; замена сначала сохраняет новый набор и коммитит профиль, только затем
  удаляет старые файлы. `CustomerOut.avatarUrl` возвращается при login/me/patch/upload.
- Production-ready media scaffold: `backend/api/Dockerfile`, `deploy/production/docker-compose.yml`,
  `nginx.conf`, `.env.example`, `backup-media.sh`. Volume: `/srv/sweetime/media:/app/media`, nginx
  отдаёт `/media` напрямую; `proxy_pass` без trailing slash, чтобы не срезать `/api`.
- Flutter больше не считает picker path профилем: `CustomerProfile.avatarUrl`/`AppState.avatarUrl`,
  multipart upload с Bearer + refresh, 30-second upload timeout, server-confirmed delete, network
  rendering и локальный preview только внутри edit screen. Экран не закрывается и не показывает
  «сохранено», если сервер не подтвердил фото. RU/KG/EN тексты обновлены.
- В dev FastAPI монтирует `/media` только не-production режимом; production обслуживает nginx.

Изменённые зоны Codex: `backend/api/{auth,config,main,models,schemas,storage}.py`, новая media
migration/tests/Dockerfile, backend requirements/pyproject, `deploy/production/*`, Flutter
`api_client.dart`, `app_state.dart`, Profile edit/view/localization, pubspec/lock, widget tests.
Свежие незакоммиченные favorites/recurring/orders изменения Claude сохранены и не откатывались;
`docs/design/BACKEND_BUILD_LOG.md` — его запись, Codex её не переписывал.

Проверки:

- `py -m pytest api/tests/test_storage.py -q` → 6 passed.
- production PostgreSQL: `alembic upgrade head` OK; `alembic check` → no changes.
- реальный local API e2e: OTP → upload PNG 200 → GET WebP 200 (`image/webp`) → delete 204;
  upload без token → 401; key tenant = `sweettime`.
- `flutter analyze --no-pub` → clean; `flutter test --no-pub` → 27/27.
- profile APK (`API_BASE=http://127.0.0.1:8010`) собран и установлен на Redmi `f3bff2a5`;
  `adb reverse tcp:8010` активен, device `/health` → ok. Локальный API перезапущен PID 15008.

Открытые риски/следующий handoff:

- Код и migration готовы локально, но на физический сервер ещё НЕ развёрнуты; `deploy/production`
  требует реальные `.env`, UID/GID владельца volume, DNS/TLS и отдельную проверку backup/restore.
- По прямому решению пользователя nginx сейчас отдаёт avatar URL как public immutable media.
  Перед публичным запуском желательно явно утвердить privacy: оставить UUID public URL либо сделать
  avatars private через authenticated endpoint + nginx `X-Accel-Redirect`.
- Однодисковый `rsync --delete` — зеркало, не disaster-recovery backup; нужен внешний versioned
  backup и тест восстановления.
- Root `docker-compose.yml`/`backend/Dockerfile` относятся к старому `backend/app`; новый канон для
  production API находится в `deploy/production` + `backend/api/Dockerfile`. Не запускать старый
  root compose как боевой, пока он не выведен из эксплуатации/не перенаправлен явно.
- Следующий отдельный S5.3 этап: Flutter server favorites/history/recurring, локальная корзина и
  top notice. До истории сначала расширить OrderItem стабильными `productId/sizeId/toppingIds/
  sugarPercent/ice`; не восстанавливать товар из локализованного `productName`.

## Обновление Codex — 2026-07-15: Flutter ↔ server favorites (этап на приёмке)

Выполнена одна изолированная часть S5.3 — серверное избранное во Flutter. Остальные части S5.3
(история, recurring, локальная корзина, top notice) в этот этап не смешивались.

Сделано:

- `lib/core/api_client.dart`: добавлены GET/PUT
  `/auth/customer/me/favorites`; пустой `productIds` считается успешным авторитетным ответом;
  401/403 идут через существующий refresh flow; некорректный JSON/прочие статусы не принимаются
  за пустое избранное.
- `lib/shared/app_state.dart`: favorites загружаются после восстановления сохранённой сессии и до
  завершения успешного OTP login; login/logout/delete очищают видимые account-scoped favorites,
  но logout не отправляет `PUT []` и не удаляет данные аккаунта на сервере.
- Быстрые нажатия сердечка остаются оптимистичными, но полные PUT сериализованы и coalesced:
  параллельных записей нет, старый ответ не откатывает более новое локальное состояние, ответ API
  применяется как канонический только если аккаунт и запрошенный snapshot не изменились.
- `test/widget_test.dart`: добавлены/расширены тесты saved-token hydration, OTP hydration,
  authoritative empty, logout cleanup и controlled race двух быстрых toggle. Offline/fake API
  явно переопределяют новые методы и не обращаются случайно к localhost.

Проверки:

- `flutter analyze --no-pub` — clean.
- `flutter test --no-pub` — 29/29 passed.
- Реальный local production API e2e: mock OTP → GET favorites → PUT `[p2]` → GET `[p2]` →
  восстановление прежнего списка; tenant/customer Bearer contract подтверждён.
- `git diff --check` — clean (только существующее предупреждение Git о CRLF `pubspec.yaml`).
- profile APK с `API_BASE=http://127.0.0.1:8010` собран, установлен и запущен на Redmi
  `f3bff2a5`; `adb reverse tcp:8010` включён.

Риски и следующий handoff:

- При временной недоступности PUT оптимистичное значение остаётся в текущей сессии и повторно
  отправится при следующем изменении; отдельный persistent outbox/offline indicator ещё не сделан.
- Backend GET возвращает сохранённый список как есть; очистка устаревших ID происходит при PUT.
  Flutter UI и так показывает только совпавшие с текущим каталогом товары.
- Следующий рекомендуемый отдельный этап: расширить production OrderItem стабильными
  `productId/sizeId/toppingIds/sugarPercent/ice` и миграцией. Только после этого безопасно
  подключать серверную историю и точный reorder; сопоставление по русскому `productName` запрещено.

## Обновление Codex — 2026-07-15: локальная корзина + единая очередь S5.3–S7

По физической проверке владельца серверные фото и favorites сохранялись, а корзина после
перезапуска — нет. Выполнен отдельный этап device-scoped cart persistence.

Сделано:

- Новый `lib/core/cart_store.dart`: injectable `CartStore` и production
  `SharedPreferencesCartStore`, ключ версионирован и изолирован по company ID. JSON хранит только
  `productId`, quantity, `sizeId`, sugar, ice и topping IDs; названия, Product целиком, total,
  бонусы и платёжные данные не сохраняются.
- `AppStateController.bootstrap()` читает draft параллельно со стартом, но применяет его только
  после загрузки актуального каталога. Product/size/toppings восстанавливаются по stable IDs,
  total пересчитывается из текущих цен. Unknown product/size/ice/quantity/sugar удаляют позицию,
  unknown toppings фильтруются; очищенный snapshot записывается обратно.
- Все реальные cart mutations (`addConfigured/quickAdd/updateQuantity/remove/repeatOrder`) пишут
  snapshot. Успешный локальный checkout, удаление последней позиции и deleteAccount очищают ключ.
  Login/logout корзину не очищают: гостевой draft переживает auth return-to-checkout.
- Записи SharedPreferences сериализованы и coalesced, поэтому быстрые add/update/remove не могут
  завершиться в обратном порядке и воскресить старую корзину. Поздний bootstrap не перезаписывает
  корзину, если пользователь уже успел её изменить.
- `docs/TASKS.md` обновлён: вверху добавлена общая operational queue S5.3 backend, S5.3 Flutter,
  S6 и S7. Зафиксирован target `ranex@81.88.192.41` и подготовленные `/srv/sweetime/*`; старое
  утверждение «Git не инициализирован» исправлено текущим baseline status.

Проверки:

- `flutter analyze --no-pub` — clean.
- `flutter test --no-pub` — 33/33 passed. Новые тесты: restart round-trip, price recomputation,
  stale product/size/topping cleanup, last-item removal, login/logout preservation и account-delete
  cleanup.
- `git diff --check` — clean кроме существующего CRLF warning для `pubspec.yaml`.
- Profile APK (`API_BASE=http://127.0.0.1:8010`) собран (107.1 MB), установлен и запущен на Redmi
  `f3bff2a5`; `adb reverse tcp:8010` активен.

Актуальный остаток короткой очереди:

1. S5.3 backend — функционально готов локально, но нужны automated PostgreSQL endpoint tests,
   stable OrderItem contract, commit и deployment/migration.
2. S5.3 Flutter — avatar + favorites + local cart готовы; остаются history, recurring и top notice.
3. S6 — deploy scaffold partial; нужны production env/secrets, healthchecks, DB/off-host backup,
   TLS/IP pilot decision, admin deployment decision и Ubuntu validation.
4. S7 — IP/SSH/path известны, но upload/build/migrations/nginx/firewall/smoke ещё не выполнялись.

Риск: корзина намеренно device-scoped и после logout видна следующему аккаунту на том же телефоне.
Это соответствует уже принятому guest cart → auth flow. Если владелец захочет приватную корзину
на аккаунт, потребуется отдельная политика guest/customer merge, а не простая смена storage key.

## Обновление Codex — 2026-07-15: stable OrderItem V2 (этап на приёмке)

Выполнен обязательный контрактный этап перед Flutter history/reorder. Аудит показал, что backend
Product modifiers не имели ID, Flutter синтезировал их из fallback, а admin заменял на `s0/t0` и
удалял при PATCH. Поэтому исправление сделано сквозным: backend catalog → admin → order POST.

Сделано:

- Backend Product modifier contract разделён на output (обязательный stable `id`) и write
  (`id` optional только для нового option). API генерирует opaque ID один раз; rename/reorder
  сохраняет присланный ID; дубли запрещены.
- Seed получил канонические IDs размеров/топпингов. Alembic `d42f10c8b6e1` следует за
  `a31d5e3f9c20`, добавляет `orders.items_version` с constraint 1/2 и назначает IDs существующим
  Product JSON. Для известных SweetTime options одноразовый compatibility map сохраняет уже
  используемые Flutter IDs; неизвестные получают UUID. Runtime никогда не выводит ID из названия.
- Legacy order JSON не переписывается: существующие строки получают `itemsVersion=1`, новые
  strict requests записываются как V2. V1 response имеет nullable stable fields и остаётся
  display-only; никакого поиска productId по русскому productName нет.
- Strict `OrderItemCreate` принимает только `productId`, `sizeId`, unique `toppingIds`,
  sugar enum, ice enum и quantity. `productName`, unit/item/order prices запрещены (`422`).
  Backend проверяет tenant, active/branch availability, size/toppings и считает unit/line/order
  totals и pointsEarned по серверному каталогу.
- Admin `ApiModifier` теперь читает настоящий ID и отправляет его обратно при PATCH; временные
  index IDs удалены.
- Flutter submitOrder больше не отправляет localized productName/price. Payload не зависит от
  RU/KG/EN и включает stable selection; paymentMethod теперь реально передаётся, `qrDemo` мапится
  в API `qr`.

Проверки:

- Alembic upgrade `a31 -> d42`, current=head и `alembic check` — OK/no operations.
- Backend `py -m pytest api/tests -q` — 11 passed (legacy V1 + strict V2 schema + storage).
- Real local PostgreSQL/API: order `SW-1064`, itemsVersion=2, p1/m/tapioca, server unit/total=430,
  payment=qr; customer history returns V2; injected `total=1` rejected 422.
- Staff queue returns legacy `SW-1063` as itemsVersion=1/productId=null. Product PATCH preserved
  modifier IDs `s,m,l` exactly.
- `corepack pnpm typecheck` in admin — clean.
- `flutter analyze --no-pub` — clean; `flutter test --no-pub` — 34/34. Captured RU/EN requests
  are identical and contain no display name/price.
- Profile APK built and installed on Redmi `f3bff2a5`; adb reverse 8010 active. Local API restarted
  with new code, PID 10152.

Изменённые зоны этого этапа: backend `models/schemas/main/seed/serializers`, migration d42 and
order contract tests; admin `lib/api.ts`; Flutter `api_client/app_state/checkout`, widget tests;
TASKS/CODEX_NOTES. Существующие незакоммиченные Claude S5.3 и Codex avatar/favorites/cart changes
сохранены; `docs/design/BACKEND_BUILD_LOG.md` не редактировался.

Следующий отдельный этап: Flutter server history DTO/UI. V2 history может делать exact reorder
только если все current product/size/topping IDs разрешились; V1 показывается без кнопки точного
повтора. Snapshot пока сохраняет display product/size строки (как legacy/admin contract), а не
гарантированные полные RU/KG/EN — не выдавать это за завершённый localized history contract.

## Обновление Codex — 2026-07-15: Flutter server history + safe V2 reorder

Завершён следующий отдельный этап S5.3: Flutter теперь читает серверную историю клиента и не
восстанавливает заказ по локализованным названиям.

Сделано:

- Добавлены snapshot-модели `OrderHistoryEntry`/`OrderHistoryItem`, отделённые от текущего
  `Product`/`CartItem`. История сохраняет server number, branch ID, itemsVersion, snapshot,
  stable selection и суммы; удалённый товар/филиал не роняет экран.
- `ApiClient.fetchCustomerOrders()` читает `GET /auth/customer/me/orders`. Пустой список
  авторитетен; некорректный envelope/enum/V2 stable selection не маскируется под пустую историю.
  Parser принимает текущие string snapshots и future complete `{ru,ky,en}` snapshots.
- История загружается после saved-token restore и OTP login с account-epoch guard. Успешный
  server checkout обновляет историю и заменяет временную локальную запись; unavailable response
  оставляет локальную запись, logout/delete очищают account-scoped history.
- Profile показывает публичный `number`, snapshot/current localized name и fallback удалённого
  филиала. V1 явно display-only без кнопки repeat. V2 repeat ищет только точные product/size/
  topping IDs, проверяет выбранный филиал, пересчитывает цену по текущему каталогу и либо добавляет
  весь заказ, либо ничего.
- Добавлен отдельный `catalogAuthoritative`: успешный `/config` при fallback на DemoData больше не
  разрешает V2 repeat. Это закрывает риск безопасного повторения при частично недоступном API.
- RU/KG/EN добавлены для legacy/conflict/offline catalog/unknown branch состояний.

Проверки:

- `flutter analyze --no-pub` — clean.
- `flutter test --no-pub` — 42/42 passed. Покрыты V2 parser/localized snapshot, malformed V2,
  authoritative empty, stale response after logout, V1 name-matching prohibition, current-price
  recalculation, atomic conflict и offline DemoData rejection.
- Реальный local PostgreSQL/API: создан `SW-1065`; history первым возвращает V2 с
  `p1/m/tapioca`, server total 430, рядом legacy V1 остаётся читаемым.
- Profile APK (118.6 MB, `API_BASE=http://127.0.0.1:8010`) собран и установлен на Redmi
  `f3bff2a5`; `adb reverse tcp:8010` активен.

Открытые ограничения:

- Backend текущего V2 сохраняет `productName/size` как строки, поэтому для удалённого товара
  сервер пока не гарантирует переключаемый RU/KG/EN snapshot. Flutter уже принимает полную форму,
  но backend/admin migration полного localized snapshot остаётся отдельной задачей.
- V2 с `sizeId=null` показывается, но точный repeat временно блокируется: текущий `CartItem`
  требует sizeId. Нельзя молча выбирать размер по умолчанию.
- Повтор применяет актуальную цену без отдельного диалога сравнения old/new. Перед production UX
  желательно добавить явное подтверждение, если итог изменился.

Следующий этап по прямому указанию владельца начат без паузы: Flutter recurring-order API
integration. После него остаётся top add-to-cart notice, затем S6/S7 согласно очереди.

## Обновление Codex — 2026-07-15: Flutter recurring-order API integration

Следующий S5.3 этап завершён без паузы по прямому указанию владельца.

Сделано:

- Flutter использует фактический контракт `GET/PUT/DELETE
  /auth/customer/me/recurring`. GET `200 null` авторитетно очищает старое состояние; network/5xx
  его не выдают за отсутствие подписки. PUT отправляет только productIds/time/branchId/plan,
  DELETE принимает только 204.
- `RecurringOrder` больше не хранит mutable `Product`/`Branch`: источник identity — stable
  productIds/branchId. UI динамически разрешает текущий каталог и показывает RU/KG/EN fallback
  для удалённых товаров/филиала. `paidUntil` берётся только с сервера; nullable legacy value
  отображается безопасно.
- Recurring hydrate добавлен после saved-token restore и OTP login с account-epoch guard.
  Поздний PUT после logout не возвращает приватное состояние гостю; PUT/DELETE имеют общий
  mutation revision для защиты локального state от старого ответа.
- Настройка открывается с текущими product/time/branch/plan, ждёт server response, блокирует
  double tap, закрывается только при успехе и остаётся открытой с локализованной ошибкой при сбое.
  Cancel очищает карточку только после server 204.
- Платёж по-прежнему честно помечен `(демо)`: API лишь сохраняет подписку и сам считает срок,
  реального payment provider в этом этапе нет.

Проверки:

- `flutter analyze --no-pub` — clean.
- `flutter test --no-pub` — 46/46 passed. Новые проверки: parser/time/date, hydration,
  authoritative null, server paidUntil, PUT/DELETE и late PUT after logout.
- Реальный local PostgreSQL/API: PUT p1/11:00/b1/week → GET active=true с server paidUntil →
  DELETE 204 → GET body `null`.
- Profile APK (118.6 MB) собран и установлен на Redmi `f3bff2a5`; adb reverse 8010 активен.

Production blockers recurring (не скрывать): backend пока хранит только product IDs без
size/toppings/sugar/ice/quantity, не проверяет Product.active/branch availability/branch open,
выставляет paidUntil без реальной оплаты, не определяет refund/остаток при DELETE/повторном PUT и
не деактивирует автоматически истёкший paidUntil. Поэтому это server-persistent demo/MVP-light,
а не готовая платная подписка.

Следующий S5.3 Flutter этап начат: единый верхний add-to-cart notice. После него короткая очередь
переходит к S6 deployment artifacts/validation и S7 physical server rollout.

## Обновление Codex — 2026-07-15: Flutter top add-to-cart notice; S5.3 Flutter завершён локально

Завершён последний отдельный Flutter-пункт короткой очереди S5.3.

Сделано:

- Добавлен общий `lib/shared/widgets/top_notice.dart`: уведомление рендерится через root overlay
  сверху с учётом SafeArea, имеет короткие fade/slide-анимации и доступный action. Одновременно
  существует только одно уведомление; повторное быстрое действие заменяет старое, а не строит очередь.
- Home, Catalog, product detail и точный повтор заказа используют один и тот же верхний notice.
  Сообщение показывается только после реального успешного добавления; action открывает корзину.
- `quickAdd` и `addConfigured` возвращают результат. `addConfigured` повторно разрешает текущий товар
  по stable ID, проверяет выбранный филиал, active/availability, size/topping IDs, уникальность toppings
  и сам пересчитывает цену по актуальному каталогу. Клиентский `total` больше не считается источником истины.
- Добавлена RU/KG/EN-локализация общего сообщения об успешном добавлении.

Проверки:

- `flutter analyze --no-pub` — clean.
- `flutter test --no-pub` — 48/48 passed. Добавлены тесты отказа для недоступного товара и одного
  верхнего notice при быстрых повторных действиях с автоматическим исчезновением.
- `git diff --check` — clean, кроме уже существующего предупреждения о CRLF для `pubspec`.
- Profile APK 124,428,825 bytes (`API_BASE=http://127.0.0.1:8010`) собран и установлен на Redmi
  `f3bff2a5`; `adb reverse tcp:8010` восстановлен.

Статус: короткая очередь **S5.3 Flutter** завершена и отмечена локально проверенной в `docs/TASKS.md`.
Следующий этап по прямому указанию владельца начат без паузы: S6 deployment artifacts/validation.

## Обновление Codex — 2026-07-15: S6 readiness + fail-closed production contract

По прямому указанию владельца после S5.3 начат S6. Завершены два последовательных локально
проверяемых блока deployment-артефактов.

S6-A — readiness/healthchecks:

- `/health` оставлен process-liveness, добавлен `/ready` с реальным `SELECT 1` в PostgreSQL и
  безопасным 503 без текста внутренней ошибки.
- PostgreSQL, Redis, backend и nginx получили healthchecks. Backend ждёт healthy PostgreSQL, nginx
  ждёт healthy backend; `/ready` проксируется наружу.
- Dockerfile содержит тот же DB-backed healthcheck, поэтому образ проверяет готовность и вне Compose.

S6-B — fail-closed production configuration:

- Production `Settings` отвергает короткий/placeholder JWT, placeholder/non-PostgreSQL DATABASE_URL,
  wildcard или non-HTTPS CORS, mock OTP и demo seed. Пока реального SMS-провайдера нет,
  `OTP_MODE=disabled`; OTP endpoints честно отвечают 503.
- Demo seed выполняется только при явном локальном `SEED_MODE=demo`. Production `SEED_MODE=none`
  не создаёт известных owner/manager/barista (`demo`) и demo-клиента.
- Alembic вынесен в one-shot Compose service `migrate`; обычный backend больше не меняет схему при
  каждом restart. Backend стартует только после успешной миграции.
- Compose больше не передаёт общий `.env` целиком каждому контейнеру: сервисы получают минимальный
  набор переменных; критичные значения обязательны через `${VAR:?message}`. nginx по умолчанию
  слушает только `127.0.0.1:8080` за внешним TLS reverse proxy, а не публичный host port 80.
- `deploy/production/.env` и `backend/api/.env` защищены `.gitignore`; root `.dockerignore` исключает
  секреты, Git, Flutter/Node/Python build/cache. Реальный build context уменьшился с ~424 KB до 64 KB.

Проверки:

- `py -m pytest api/tests -q` — 23/23 passed.
- Compose с полными тестовыми secrets проходит `config`; без `POSTGRES_PASSWORD` завершается exit 1
  до запуска контейнеров. `git check-ignore` подтверждает оба secret-файла.
- Production image `sweettime-backend:s6-secure` собран; healthcheck присутствует в image metadata.
- `nginx:1.27-alpine nginx -t` — successful для текущего конфига.
- Disposable PostgreSQL: отдельный Alembic job применил все 5 revisions; затем production backend
  стал healthy, `/ready` вернул ok, `companies_after_production_start=0` — demo seed не произошёл.

Открытые P0/P1 до S7: нужен безопасный bootstrap реальной компании/первого owner; утверждённый TLS
reverse-proxy/domain; решение о приватности avatar media; versioned DB+media off-host backup и restore
drill; pin зависимостей/image digest; server preflight прав/портов/диска; deployment admin. Следующий
локальный S6-блок начат без паузы: backup/restore artifacts, без обращения к физическому серверу.

## Обновление Codex — 2026-07-15: S6 versioned backup + restore drill

Завершён S6-C. Старый `backup-media.sh` с same-disk `rsync --delete` удалён: он мог зеркально удалить
копию после ошибки/пустого source и не содержал PostgreSQL.

Новый workflow в `deploy/production/`:

- `backup-production.sh` открывает короткое maintenance window (останавливает nginx/backend), делает
  PostgreSQL custom dump и media archive в неизменяемой timestamp-папке, записывает Alembic head и
  число media-файлов, проверяет SHA-256/структуру архивов и возобновляет только ранее запущенные сервисы.
- `copy-backup-offsite.sh` повторно проверяет checksums и копирует snapshot в отдельный rsync-target
  без `--delete`; отсутствие `OFFSITE_RSYNC_TARGET` является ошибкой, поэтому same-host snapshot не
  маскируется под полноценный backup.
- `restore-drill.sh` никогда не трогает production: восстанавливает dump в disposable PostgreSQL 16,
  сравнивает Alembic version, извлекает media во временную папку и сверяет число файлов.
- `README.md` фиксирует TLS-loopback topology, preflight, backup/off-site/restore порядок и честные
  блокеры production bootstrap/OTP.

Проверки на полностью поднятом тестовом Compose stack:

- backup snapshot `20260715T083125Z`: `database.dump`, `media.tar.gz`, `metadata.env` и `SHA256SUMS`
  прошли проверку; backend/nginx остановились и вернулись healthy.
- restore drill: `alembic=d42f10c8b6e1`, `media_files=1`, exit 0.
- append-only copy в отдельный тестовый target сохранил все четыре файла, exit 0.
- Свежий image tag при `docker compose up --build` собирается один раз; migrate не пытается pull
  локального/private tag, завершает Alembic и только после этого стартуют healthy backend/nginx.
- Bash syntax — clean; backend tests 23/23; `git diff --check` — только существующие CRLF warnings.
- Тестовый stack, test `.env` и все локальные snapshots/off-site fixtures удалены после проверки.

Не закрыто: реальный off-host target, его encryption/retention/monitoring и регулярный restore drill
на Ubuntu должны быть настроены в S7; локальный артефакт не доказывает наличие внешней копии.

## Обновление Codex — 2026-07-15: S6 one-shot production bootstrap

Завершён S6-D: production DB теперь можно сделать пригодной к работе без возврата demo seed.

- `api.bootstrap` читает owner email/name из окружения, а пароль только из read-only secret file.
  Пароль не передаётся аргументом CLI, не попадает в image/repo и проверяется как 16–72 UTF-8 bytes.
- `bootstrap_production_sweettime()` создаёт только tenant `sweettime`, 3 филиала, 8 товаров,
  4 новости, 3 акции и одного owner с bcrypt hash. CoffeeGo, demo customer, demo staff и orders не
  создаются. Повторный запуск при любой существующей компании fail-closed и ничего не меняет.
- Отдельный `docker-compose.bootstrap.yml` подключается только к явной one-shot команде; требует
  реальный email/name и абсолютный host path к password file. Базовый production stack от этих
  переменных не зависит.
- `deploy/production/README.md` содержит безопасную генерацию secret file, команду запуска,
  обязательную проверку логина/сохранение в password manager и удаление bootstrap secret после успеха.

Проверки:

- Backend unit/config/input tests: 29/29 passed.
- Fresh tmpfs PostgreSQL 16: 5 migrations → bootstrap exit 0. Counts: companies=1, sweettime=1,
  coffeego=0, owners=1, branches=3, products=8, news=4, promotions=3, customers=0, orders=0.
- Пароль из secret file успешно проверен против сохранённого bcrypt hash.
- Второй запуск завершился exit 1 с `a company already exists`; дубликатов нет.
- Combined base+bootstrap Compose config валиден с явными тестовыми inputs; временный password file,
  контейнер, сеть и тестовая БД удалены.

Дальше: реальный bootstrap выполняется только на целевом Ubuntu после backup/migrations и до трафика.
Следующий безопасный блок — read-only preflight физического сервера (ОС/Docker/proxy/порты/права/диск),
без upload, запуска контейнеров или изменения firewall.

## Обновление Codex — 2026-07-15: target preflight prepared; SSH auth required

S6-E начат, но ни одной команды на физическом сервере не выполнилось. Попытка
`ssh -o BatchMode=yes ranex@81.88.192.41` завершилась `Permission denied (publickey,password)`;
локальный ssh-agent отсутствует. Пароль не запрашивался/не выводился/не сохранялся.

Добавлен read-only `deploy/production/server-preflight.sh`. Он собирает только необходимые факты:
Ubuntu/kernel/CPU/RAM, Docker/Compose, running containers без env, active nginx/caddy, listeners,
nginx route/TLS summary, Certbot, UFW, владельцев/режим/writability подготовленных `/srv` путей,
disk bytes и inodes. Скрипт не создаёт файлы, не рестартует сервисы и не меняет firewall.

Команда для владельца (с локальным интерактивным вводом SSH password):

`ssh ranex@81.88.192.41 'bash -s' < deploy/production/server-preflight.sh`

Альтернатива предпочтительнее: добавить отдельный SSH public key для Codex/деплоя и повторить
read-only аудит. До получения вывода нельзя выбирать внешний порт, домен/TLS integration или
запускать S7 рядом с существующим проектом.

Финальная локальная проверка этого цикла: backend 29/29, Flutter analyze clean, Bash syntax clean,
`git diff --check` без новых whitespace ошибок (только существующие CRLF warnings).
## Обновление Codex — 2026-07-15: Google auth + обязательный контакт до checkout

По решению владельца SMS-провайдер отложен. Реальный вход теперь строится через Google, а кыргызский
номер до будущего SMS challenge является только неподтверждённым контактом.

Backend:

- `POST /api/companies/{companyId}/auth/google` принимает только `idToken`; `google-auth==2.56.0`
  проверяет подпись/issuer/expiry, затем allowlist `aud`/`azp`. SweetTime использует стабильный Google
  `sub`, не email, выдаёт собственные access/refresh токены и не хранит Google credential.
- Добавлена `customer_identities` с tenant/provider/subject unique. Email/name — только метаданные,
  auto-link по email и staff escalation отсутствуют; одинаковый verified email с разными `sub` не
  склеивает аккаунты.
- `customers.phone` nullable; `phone_verified_at` server-owned. Неподтверждённые одинаковые контакты
  разрешены, partial unique действует только для подтверждённых номеров, чтобы до SMS нельзя было
  зарезервировать чужой телефон.
- `PATCH .../auth/customer/me/contact` принимает только нормализуемый KG `+996` + 9 цифр и всегда
  оставляет номер unverified. Миграция `f5a9c2e41d07` идёт после `d42f10c8b6e1`.

Flutter:

- Добавлен `google_sign_in ^7.2.0` и адаптер с `GOOGLE_WEB_CLIENT_ID` через dart-define. Устройство
  передаёт backend только ID token.
- После Google-входа клиент без номера остаётся authenticated, но `accountReady=false`; Cart, прямой
  `/checkout` и сам checkout требуют `accountReady`. После сохранения контакта typed pending return
  возвращает в checkout, корзина не теряется.
- Публичный offline fallback `1111` удалён. SMS честно показан временно недоступным. Cancel Google не
  ошибка; двойные нажатия/races защищены; provider sign-out выполняется best-effort при backend failure,
  logout и delete.

Deployment/docs:

- Compose передаёт `GOOGLE_AUTH_ENABLED` и JSON `GOOGLE_OAUTH_CLIENT_IDS`; `.env.example` остаётся
  fail-closed. `deploy/production/README.md` содержит порядок Android/Web OAuth setup и команды запуска.
- Текущий local Android package: `kg.sweettime.demo`; debug SHA-1
  `F6:B6:ED:07:AD:1A:D9:C0:74:12:2B:4C:58:08:27:E1:5A:13:C6:35`. Это не production credential:
  release всё ещё подписан debug key, поэтому финальный package/signing и отдельный OAuth client нужны
  до публикации.

Изменённые зоны: `backend/api/{auth,config,google_auth,models,schemas}`, новая миграция/тесты,
Flutter auth/API/state/router/cart/checkout/localizations/tests/dependencies, `deploy/production/*`,
`docs/{PROJECT_BRIEF,FEATURE_PRIORITIES,TASKS}.md` и этот файл.

Проверки: backend `42 passed`; Flutter `50/50`, analyze clean, debug APK built; PostgreSQL migration
applied locally; OpenAPI построен; production Compose config valid с тестовыми env; backend Docker
image с `google-auth==2.56.0` собран; `git diff --check` clean кроме существующего CRLF notice для
pubspec.

Осталось/для Claude Code: не возвращать mock OTP в публичный flow и не считать contact verified.
До live QA владелец должен создать Android + Web OAuth clients, передать Web client ID в backend и
Flutter, применить migration на сервере и проверить Google → contact → checkout по HTTPS. iOS требует
отдельный окончательный bundle ID/client/URL scheme. SMS verification/login остаётся отдельной будущей
provider-задачей.

## Обновление Codex — 2026-07-15: OAuth-клиенты и домен готовы к S7

Прочитаны свежие заметки Claude и приняты переданные владельцем результаты настройки Google Cloud и
физического сервера. Это обновление заменяет прежние сведения выше о временном package ID и отсутствии
OAuth-клиентов.

- Финальный Android/iOS identifier: `kg.sweettime.app`. Android debug APK подтверждён через manifest.
- Web/backend OAuth client (единственный допустимый `aud`):
  `23205820785-ap4kgng4fef97ie9l69e5erlufjc8v2i.apps.googleusercontent.com`.
- Android debug presenter:
  `23205820785-3qsqi30tcbppsfhqifr92ro3idiqg8kh.apps.googleusercontent.com`.
- Android release presenter:
  `23205820785-thvputte60b3ig74n6pek45o0vm8ft29.apps.googleusercontent.com`.
- Backend теперь разделяет `GOOGLE_OAUTH_WEB_CLIENT_ID` и
  `GOOGLE_OAUTH_AUTHORIZED_PARTY_IDS`: Web ID проверяется как `aud`, Android IDs — как `azp`, если claim
  присутствует. Flutter по умолчанию запрашивает ID token для Web client, с возможностью безопасного
  переопределения через `GOOGLE_WEB_CLIENT_ID`.
- Android release использует существующий `C:/Users/user/sweettime-upload.jks`, alias `upload`, и
  fail-closed конфигурацию: без игнорируемого `android/key.properties` release build намеренно падает,
  debug signing как production fallback запрещён. Пароли нельзя записывать в repo/заметки или отправлять
  другому агенту. Добавлен только `android/key.properties.example`.
- Внешний Nginx на `lnp-corporation.duckdns.org` успешно переключён владельцем на
  `127.0.0.1:8080`: HTTP=301, HTTPS=502 при свободном 8080 — ожидаемое состояние до запуска Compose.
  Репозиторий использует цепочку host Nginx → `127.0.0.1:8080` → container Nginx:80 → backend:8000;
  прямой mapping `8080:8000` неверен и обходит внутреннюю политику Nginx.
- В host-конфиг до запуска трафика обязательно добавить `location ^~ /media/temp/ { deny all; }` перед
  публичным `/media/` alias. Иначе host alias обойдёт уже существующий запрет временных upload-файлов во
  внутреннем Nginx. Эталон: `deploy/production/host-nginx.conf.example`.

Изменённые в этом продолжении файлы: backend Google config/verifier/tests, Flutter Google audience,
Android/iOS identifiers и release signing, production Compose/env/README/host-Nginx example,
`scripts/install_phone_preview.ps1`, `.gitignore`, `docs/TASKS.md` и этот файл. Чужой
`docs/collab/CLAUDE_NOTES.md` не редактировался Codex; его текущие изменения нужно сохранить.

Проверки: backend 42/42; Flutter 50/50; analyze clean; debug APK собран и имеет package
`kg.sweettime.app`; production Compose config валиден; HTTP 301 и HTTPS `/ready` 502 подтверждены снаружи.
Release build отдельно проверен на fail-closed и закономерно остановился из-за отсутствующего локального
`android/key.properties`.

Следующий шаг S7: владелец локально создаёт `android/key.properties` и проверяет release-подпись; на
сервере добавляет запрет `/media/temp/`; затем код загружается в `/srv/projects/sweetime`, создаётся
непубликуемый production `.env`, запускаются build/migrations/one-shot bootstrap и HTTPS smoke tests.
После смены Android package со старого demo ID приложение установится как другое приложение, поэтому
старые локальные preferences/cart автоматически не мигрируют.

## Обновление Codex — 2026-07-15: S7 host Nginx проверен, snapshot готов

Владелец применил host-Nginx конфигурацию для `lnp-corporation.duckdns.org`: `nginx -t` проходит,
reload выполнен, HTTP возвращает 301 на HTTPS, `/ready` возвращает ожидаемый 502 до запуска Compose,
а `127.0.0.1:8080` свободен. В конфиге присутствуют лимит 11 MiB и отдельный deny для
`/media/temp/`. Последняя рекомендованная чистка — убрать `try_files $uri =404` из `alias`-location,
поскольку `alias` сам возвращает 404, и использовать эталонный блок из
`deploy/production/host-nginx.conf.example`.

Перед upload создан проверенный Git snapshot `5b0d00a` (`feat(auth): add Google sign-in and production
rollout config`). На момент коммита tests: backend 42/42, Flutter 50/50, analyze clean; реальных секретов,
`.env`, `android/key.properties` и keystore в snapshot нет. Следующая операция — сформировать архив уже
из финального HEAD после этой записи, передать его владельцу для интерактивного `scp` и сверить SHA-256
на сервере до распаковки в `/srv/projects/sweetime`.

Владелец затем показал окончательный media-блок: `location ^~ /media/`, корректный `alias`,
`autoindex off`, без `try_files`, с `Cache-Control: public, immutable` и `nosniff`. Конфиг соответствует
эталону репозитория. Immutable-кэш безопасен для текущего storage: `save_image()` создаёт новый UUID и
новый URL при каждой замене изображения, после чего старые варианты удаляются. После последней правки
на хосте нужно ещё раз выполнить `sudo nginx -t && sudo systemctl reload nginx`.

Архив snapshot `352f161` успешно передан владельцем в `/tmp`, SHA-256 на сервере совпал:
`7fcd685de1d733bd0c340f230de3c7c20d5a437454260f1781b91e5706db6430`. Архив распакован в чистый
`/srv/projects/sweetime`; `deploy/production/` содержит ожидаемые Compose, Nginx, backup/restore,
bootstrap и preflight артефакты. `.env` и keystore в архив не попали. Следующий шаг — выполнить
`bash ./server-preflight.sh` непосредственно на Ubuntu, проверить UID/GID каталогов и Docker/Compose,
и только затем создавать production `.env`.

Server preflight выполнен владельцем успешно. Ubuntu 26.04, Docker 29.1.3, Compose 2.40.3, Nginx и
Docker active; `ranex` входит в `docker`, sudo noninteractive доступен. `/srv` имеет около 21 TiB
свободного места и 1% inode usage. `/srv/sweetime/{media,backups,postgres}` и проект доступны владельцу;
`/srv/sweetime/secrets` ещё отсутствует и должен создаваться с mode 700 перед bootstrap. Port 8080
свободен; существующие Nton PostgreSQL/Redis опубликованы только на loopback 5432/6379 и не конфликтуют
с непубликуемыми Compose-сервисами SweetTime. TLS-сертификат валиден до 2026-10-13.

Риск: UFW inactive, при этом Nton frontend слушает `0.0.0.0:3000`, а Cockpit — `*:9090`. Не включать и
не менять firewall вслепую: сначала отдельно подтвердить SSH allow, необходимость внешних 3000/9090 и
провайдерский firewall, чтобы не сломать Nton/Cockpit/доступ. Следующий безопасный шаг — создать mode 600
production `.env` с отдельными случайными PostgreSQL/JWT secrets и проверить `docker compose config -q`
без печати конфигурации или секретов.

Production `.env` создан владельцем на сервере с mode 600; placeholder scan пуст, Compose config exit 0,
а `SWEETIME_UID/GID=1000:1000` совпадают с `ranex`. Backend image `sweettime-backend:local` успешно
собран; итоговый manifest list `sha256:19f515f613d9278c19207eae9ff15bc39bd892aed0c95a0951de68b2887940e4`.

До bootstrap исправлена ошибка документации: Compose запускает bootstrap как 1000:1000, поэтому
`root:root 600` password file был бы нечитаем. Secret directory/file должны принадлежать deploy-owner
`ranex` (1000:1000), с mode 700/600. Пароль генерируется вне repo, сохраняется владельцем в password
manager и не передаётся агентам. Следующий шаг — dependency-driven migrate + one-shot bootstrap на
свежей БД, затем проверка результата до запуска nginx/backend.

One-shot bootstrap выполнен на физическом сервере успешно (`bootstrap_exit=0`). Compose создал network
`production_default`, поднял `production-postgres-1` healthy, запустил migrate и затем создал production
SweetTime для реального owner. Пароль хранится только в `/srv/sweetime/secrets/bootstrap-owner-password`
с owner/mode 1000:1000/600; его нельзя удалять до успешной проверки owner login и сохранения владельцем.
Bootstrap повторно не запускать: его fail-closed поведение при существующей компании является защитой.
Следующий шаг — базовый `docker compose up -d`, проверки service health, loopback/HTTPS `/ready`, company
config и host deny `/media/temp/`, затем owner auth test и удаление bootstrap secret.

Базовый production stack запущен (`up_exit=0`). `production-backend-1` healthy, PostgreSQL healthy,
container nginx опубликован только как `127.0.0.1:8080->80`. Loopback `/ready`=200, внешний
`https://lnp-corporation.duckdns.org/ready`=200, company config=200 с tenant `sweettime`, а host deny
`/media/temp/probe`=403. Тем самым прежний ожидаемый 502 устранён без изменения Nton.

До удаления bootstrap secret требуется безопасно проверить global staff login. Нельзя печатать JSON
ответ целиком, потому что он содержит access/refresh tokens; проверка должна читать password file
локально, отправлять HTTPS JSON и выводить только HTTP status, user role/company и boolean наличия токенов.

Production owner login проверен безопасным host-side Python probe: HTTP 200, role `owner`, company
`sweettime`, access/refresh tokens присутствуют, но значения не печатались и не сохранялись. После трёх
минут работы backend/nginx/postgres/redis все healthy; nginx остаётся только на loopback 8080. Перед
удалением `/srv/sweetime/secrets/bootstrap-owner-password` владелец должен явно подтвердить, что случайный
пароль сохранён в password manager: после удаления plaintext восстановить из bcrypt hash невозможно.
Следом нужны initial backup + restore drill, затем физический Android Google→contact→checkout HTTPS QA.

Владелец подтвердил сохранение owner password вне сервера и удалил plaintext bootstrap-файл. Каталог
`/srv/sweetime/secrets` остаётся закрытым и пустым. Перед первым backup повторно просмотрены скрипты:
backup останавливает только SweetTime backend/nginx, делает PostgreSQL custom dump + media snapshot,
проверяет SHA-256/tar/pg_restore list и через trap возобновляет ранее работавшие сервисы; Nton не входит
в Compose и не затрагивается. На загруженном snapshot shell-файлы mode 664, поэтому текущий запуск должен
быть через `bash`; executable-биты исправляются в локальном Git для будущих deployment-архивов.

Первый production snapshot успешно создан: `/srv/sweetime/backups/snapshots/20260715T125752Z`.
`database.dump`, `media.tar.gz`, `metadata.env` проходят SHA-256; Alembic=`f5a9c2e41d07`, media_files=0
(до пользовательских upload это ожидаемо). Backup корректно остановил только SweetTime nginx/backend,
повторно прогнал idempotent migrate при resume и вернул backend/nginx/postgres/redis healthy; внешний
`/ready` снова 200. Это пока local same-host snapshot, не независимая защита. Следующий шаг — disposable
`restore-drill.sh`, который не подключается к production DB и удаляет временный контейнер после проверки.

Physical-server restore drill завершён успешно: checksums OK, PostgreSQL restore exit 0,
Alembic=`f5a9c2e41d07`, media_files=0, временный `sweettime-restore-drill-*` контейнер удалён, production
services healthy и внешний `/ready`=200. Основной S7 server rollout технически рабочий; off-host copy и
firewall hardening остаются отдельными задачами, чтобы не задерживать mobile QA.

Локальная проверка перед Android QA: `C:/Users/user/sweettime-upload.jks` существует, но игнорируемого
`android/key.properties` ещё нет; ADB не видит подключённого устройства. Владелец должен локально создать
key.properties из example без передачи паролей агентам и подключить телефон. После этого: release APK с
production API/Web OAuth audience → SHA-1/package verification → USB install → Google→contact→checkout.

Владелец локально создал ignored `android/key.properties`; release build подтвердил корректность обоих
паролей, не выводя их. APK собран с `API_BASE=https://lnp-corporation.duckdns.org` и Web OAuth audience.
`apkanalyzer`: package `kg.sweettime.app`; `apksigner`: v2 verified, RSA-2048, certificate SHA-1
`51:DC:A2:E5:1D:37:6E:BB:B1:B7:E8:A8:A8:77:8A:2D:D4:92:16:54` — точное совпадение с release Android
OAuth client. APK SHA-256=`442F0F2FDE85BB90C52644B2998AF0DF4B8C9A309F08E2432222A7E4132891F9`, size 79,408,142 bytes.

Release `1.0.0+1` установлен на Redmi Note 9 Pro и запущен; foreground activity подтверждён как
`kg.sweettime.app/.MainActivity`. ADB install вернул пустой nonzero после streamed transfer, но package
manager подтвердил fresh install time, а прямой `am start -W` вернул Status=ok; приложение активно.
Осталась ручная acceptance-проверка: guest browse → Google account picker/sign-in → обязательный KG
contact → сохранённая корзина → checkout/order через production HTTPS, плюс визуальная плавность release.

Physical QA подтвердил сохранение Google-профиля, телефона, аватара, истории и recurring, но нашёл два
дефекта. Кнопка удаления очищала только Flutter state/tokens, поэтому прежний CustomerIdentity восстанавливал
все серверные данные. Добавлен `DELETE /auth/customer/me`: Customer/identity/media удаляются транзакционно,
orders и оплаченный recurring остаются только обезличенными/неактивными; старые JWT больше не проходят, а
тот же Google `sub` получает новый customer с `phone=null`, points=0. Миграция `b91e7c4a2d10` добавляет
`ON DELETE SET NULL` и nullable recurring customer; fresh PostgreSQL upgrade f5→head проверен отдельно.

QR-камера имела `CAMERA granted=true`, но release logcat + retrace текущего mapping.txt показали NPE в
`BarcodeScanning.getClient` после R8: consumer rule `com.google.mlkit.*` не сохранял вложенные пакеты.
Добавлен app ProGuard `-keep class com.google.mlkit.** { *; }`. Profile image_picker отдельно усилен:
убран OEM-hint принудительной front camera, PlatformException теперь логирует code/message. `flutter analyze`
чист; Flutter 52/52 и backend 43/43 тестов проходят; release APK успешно собран, подписан прежним upload key
и установлен через `adb install --no-streaming -r`. На Redmi QR теперь открывает CameraX/ML Kit без NPE,
фонарь включается, scanner повторно запускается после смены subtab/root tab; внешняя Xiaomi OneShotCamera
успешно открывается из редактирования профиля.

Revision `761b7b6` развёрнут на production; Alembic=`b91e7c4a2d10`, внешний `/ready`=200, а
неавторизованный `DELETE /api/companies/sweettime/auth/customer/me`=401, то есть новый маршрут активен.
При выкладке обнаружен packaging-риск: архив распаковывался в shell с ранее установленным `umask 077`,
из-за чего backend-файлы внутри Docker image стали `600 root:root`, а migrate под UID/GID 1000 не мог
прочитать `alembic.ini` и сообщал `No 'script_location'`. На сервере права восстановлены через `a+rX`;
локально `backend/api/Dockerfile` теперь всегда выполняет `chmod -R a+rX /app/api`, а Compose использует
абсолютный `/app/api/alembic.ini`. Ручная destructive acceptance-проверка пройдена: удаление вернуло
guest state, вход тем же Google снова потребовал телефон, а прежние фото, дата рождения, избранное,
история и recurring не восстановились.

Следующая operational-задача — production deployment custom Next.js admin. Код `admin/` уже использует
боевой JWT API для config/products/branches/news/promotions, но в `deploy/production` нет admin service,
у `admin/` нет Dockerfile, а production `/`, `/login` и `/admin` возвращают 404. Flutter читает этот
контент только один раз в `bootstrap`; pull-to-refresh/resume refresh отсутствует, а пустые server
news/promotions сейчас ошибочно заменяются DemoData. Перед end-to-end admin→API→mobile acceptance нужно
развернуть admin, исправить mobile refresh/empty semantics и отдельно добавить product media/category
contracts; staff и admin recurring по-прежнему явно demo-only.

Production admin deployment artifacts завершены локально, server rollout ещё не выполнялся. Добавлены
`admin/Dockerfile` (Next 15 standalone, Node 22/pnpm 11.7, HTTPS build arg, non-root `nextjs`) и admin
service без host port. Внутренний nginx сохраняет host `X-Real-IP`/`X-Forwarded-Proto`, оставляет
приоритет `/api`, `/ready`, `/media`, проксирует web в admin, перенаправляет `/admin[/]` на `/login`,
добавляет базовые security headers; его health теперь проверяет backend и `/login`. Backup maintenance
window учитывает admin. Production login больше не показывает demo email/password; recurring demo
analytics удалена, staff скрыт из navigation, а direct `/staff` только сообщает об отсутствии server CRUD.

Проверки: admin typecheck clean; Docker standalone build success; image runtime user=`nextjs`;
`/login` и static chunk=200; insecure HTTP `NEXT_PUBLIC_API_URL` fail-closed; nginx syntax clean; Compose
config clean и admin не публикует порт. Полный disposable PostgreSQL→Alembic `b91e7c4a2d10`→backend→
admin→nginx smoke: `/ready`=200, `/login`=200, config=200, `/admin` и `/admin/`=302,
`/media/temp`=403, nosniff/frame-deny присутствуют. Production остаётся на предыдущем revision и
возвращает `/login`=404 до отдельного owner-approved upload/build/up. В server `.env` перед build нужно
добавить public non-secret `ADMIN_PUBLIC_API_URL=https://lnp-corporation.duckdns.org`.

Production rollout custom Next.js admin выполнен 2026-07-15 из архива revision `15f05eb` после проверенного
snapshot `/srv/sweetime/backups/snapshots/20260715T151245Z`. Server `.env` дополнен публичным
`ADMIN_PUBLIC_API_URL=https://lnp-corporation.duckdns.org`; admin image собран на сервере и запущен только
во внутренней Compose-сети, без host port. `admin`, `backend`, `nginx`, `postgres`, `redis` healthy;
публичные `/ready`, `/login`, company config возвращают 200, `/media/temp/probe` — 403, security headers
присутствуют. Первый production smoke обнаружил, что внутренний nginx превращал `return 302 /login` в
абсолютный `http://` redirect из-за TLS termination на host proxy. Revision `15a92b3` добавляет
`absolute_redirect off`; исправленный конфиг развёрнут отдельно и теперь `/admin` возвращает относительный
`Location: /login`, а итоговый URL остаётся HTTPS. Следующий шаг — ручной owner login, затем обратимый
admin→API readback и проверка обновления Flutter без оставления тестового контента.

Production owner login физически подтверждён в браузере: роль `Владелец`, API connected, dashboard читает
production заказы/метрики. Для следующего admin→mobile acceptance исправлена давняя stale-content проблема
Flutter: `refreshCompanyData` объединяет параллельные запросы, автоматический resume refresh ограничен 30
секундами, а Home/Catalog имеют принудительный pull-to-refresh. Пустые server news/promotions теперь
authoritative и скрывают секцию вместо возврата DemoData; пустой server product list также больше не
подменяется demo-каталогом. Добавлен regression test пусто→новый контент. `flutter analyze` clean, Flutter
53/53; production release APK 79,522,830 bytes, SHA-256
`06A925702A04D691A45586C5621AD7A66E6DD9505E22C80004453EF11777CDA9` собран с production HTTPS/Web OAuth,
установлен поверх текущего приложения на Redmi `f3bff2a5` и запущен. Осталась ручная обратимая проверка:
создать/опубликовать test news в admin → pull-to-refresh в приложении → увидеть RU/KY/EN → удалить запись →
повторно обновить и убедиться, что она исчезла.

## 2026-07-15 — CX-019: Stories/collections/news feed V2 локально завершены

- Продуктовый контракт: Home остаётся плоской лентой максимум из 30 активных сторис. Подборки живут только
  на `/news`; название/описание RU/KY/EN и круглая фото-обложка изменяются после создания. Каждая подборка
  поддерживает минимум 40 сторис как ёмкость, но публикация не требует заранее заполнить 40 элементов.
- Backend: добавлены V2 public/admin API, cursor-pagination, RBAC owner/manager, tenant isolation, фильтрация
  draft/future/expired, media-only story, image/MP4 storage и Alembic `e73c8f2a1b04` от `b91e7c4a2d10`.
  Host/internal nginx limit повышен до 52 MiB для MP4; сервер не перекодирует видео, поэтому admin честно
  требует H.264/AAC MP4. Коммит `8e83710`.
- Admin: `/news` разделён на «Сторисы», «Подборки», «Лента»; добавлены таймеры never/24h/3d/7d/custom,
  редактирование названия/обложки подборки, RU/KY/EN, preview/replace/remove media, server-ACK и обработка
  ошибок. Коммит `4cff2db`.
- Flutter: Home max30 и переход стрелкой на `/news`; подборки/40+ viewer, лента с bottom sheet, image/video,
  Android back и RU/KY/EN. Коммиты `d1d1384`, `e1f9d07`.
- Проверки: backend Docker `53 passed`; Flutter analyze clean и `58 passed`; admin typecheck и 4/4 content
  tests; Linux production admin image build; disposable PostgreSQL+HTTP: head=`e73c8f2a1b04`, переименование
  подборки прочитано публично, `41/41` сторис без дублей/пропусков, Home=`30`. Production release APK
  с новым video_player успешно собран и подписан v2: 81,017,866 bytes,
  SHA-256=`4E101493F642956C6CAB8879AC99A846E6494CCDF22D7B015E4A177F7C15870B`.
- Осталось: выкатить архив с обязательным backup, migration и rebuild backend/admin; обновить фактический
  host nginx `client_max_body_size` с 11M до 52M; проверить на production реальную замену обложки, MP4 range,
  RU/KY/EN и Android UX/back. Встроенное окно браузера в текущей сессии недоступно, поэтому локальная
  визуальная проверка admin выполнена сборкой/код-ревью, а не интерактивным screenshot-smoke. Flutter также
  предупреждает, что `mobile_scanner` пока сам применяет Kotlin Gradle Plugin; перед будущим крупным Flutter
  upgrade нужно обновить плагин до версии с Built-in Kotlin support.

Production rollout Content V2 выполнен из архива revision `a168c64` после проверенного snapshot
`/srv/sweetime/backups/snapshots/20260715T171013Z`. SHA-256 архива совпал; `.env` сохранился с mode 600.
Backend/admin пересобраны, Alembic=`e73c8f2a1b04`, пять production-сервисов healthy, локальный и внешний
`/ready`=200. Host nginx и внутренний nginx используют `client_max_body_size 52M`; конфигурация host nginx
прошла `nginx -t`. Публичные `/stories/home`, `/story-collections`, `/news-posts` и `/login` возвращают 200.
Миграция создала compatibility-подборку из 6 прежних stories; публичный RU fallback работает. Осталась
ручная owner acceptance: заполнить настоящее KY/EN название, загрузить/заменить круглую обложку, создать
feed post и MP4 story, затем проверить RU/KY/EN, expiry и Android back/video на телефоне.

## 2026-07-16 — CX-020: полноэкранные сторис и крупное медиа новостей

- По прямому UX-запросу владельца полностью переработан Flutter viewer сторис. Теперь это чёрная
  полноэкранная media-stage с `BoxFit.contain`: вертикальный материал использует доступный экран,
  горизонтальный/desktop-формат остаётся по центру с корректным letterbox. Старые CTA «переход», счётчик
  и нижние стрелки удалены.
- Добавлены сегментированные полупрозрачные progress bars с плавным заполнением: 6 секунд для фото/текста,
  покадровая анимация с синхронизацией по реальным position/duration MP4 и 15-секундный fallback при ошибке загрузки. Тап слева/справа идёт
  назад/вперёд; удержание останавливает progress или видео и звук, отпускание продолжает. Видео сторис
  автозапускается со звуком, который использует системную media-громкость телефона.
- Detail публикации ленты открывается на 98% высоты; image/MP4 занимает 78% экрана на чёрном фоне.
  Видео стартует muted, тап по нему включает/выключает звук, центральная кнопка управляет pause/play.
  Android Back закрывает detail. Загруженные stories подборки дополнительно сортируются newest-first
  на клиенте, даже если тестовый/старый API вернул иной порядок.
- Изменены: `lib/features/news/news_media.dart`, `news_story_page.dart`, `news_page.dart`,
  `test/news_content_test.dart`, `test/widget_test.dart`, `docs/TASKS.md`, этот файл. Backend/admin и
  контракт Content V2 не менялись.
- Проверки: `flutter analyze` — clean; `flutter test` — 58/58. Тест viewer проверяет 45 stories,
  отсутствие старых стрелок, движение progress, полную остановку на hold, resume, правый tap и Android Back.
  Production release APK собран с `https://lnp-corporation.duckdns.org` + production Web OAuth audience,
  установлен и запущен на Redmi Note 9 Pro `f3bff2a5`. Автоматический screenshot не выполнен из-за
  заблокированного телефона; owner должен физически проверить настоящий portrait/landscape image, MP4
  звук/боковые кнопки громкости, hold и визуальный fit. Это единственный незакрытый acceptance-пункт CX-020.

Дополнение по физической приёмке владельца: media-only story с пустыми title/body/badge показывала
автоматический Flutter fallback «Новость». Fallback удалён — если поля в admin пустые, на story нет ни
одной придуманной подписи. Progress усилен до 4 px: незаполненная часть полупрозрачная, завершённые и
текущая заполненная часть белые. Фото/текст идут ровно 6 секунд; MP4 progress плавно анимируется каждый
кадр, сверяется с позицией плеера, принудительно доходит до 100% и только затем переключает story.

Повторная физическая проверка выявила конкретный rendering-дефект: `FractionallySizedBox` получал корректный
`widthFactor`, поэтому поведенческий тест проходил, но его белый `ColoredBox` фактически имел нулевую
ширину. Сегменты заменены на determinate `LinearProgressIndicator`: текущее числовое значение теперь
непосредственно рисуется белым системным painter, фон остаётся 20% white. Тест переведён с проверки
абстрактного `widthFactor` на реальное `LinearProgressIndicator.value`; analyze и targeted viewer test
проходят. Нужна повторная физическая проверка установленного APK.

## 2026-07-16 — CX-021: устранение production HTTP 500 при входе в admin

- Точная причина подтверждена по production endpoint-матрице: config/products/branches/promotions и V2
  `/stories/home` отвечали 200, а только legacy `/news` отвечал 500. После Content V2 опубликованная
  media-only story законно имеет пустые `title/body/badge`, но старый `NewsOut` требовал непустой `ru`.
  Pydantic validation внутри `_news_out` поэтому превращала совместимые V2 данные в HTTP 500.
- Backend legacy output сделан blank-safe и стабилизирован до полных `{ru, ky, en}`; добавлен regression
  test именно с опубликованной video story и пустыми текстами. Схемы создания legacy news оставлены
  строгими — ослаблен только compatibility-ответ.
- Глобальный `CompanyStoreProvider` больше не вызывает legacy `/news`. Необязательное мини-превью телефона
  в Settings читает V2 admin stories, фильтрует только активные Home stories и при локальной ошибке контента
  становится пустым, не блокируя orders/menu/branches и весь shell. Для безопасных GET/HEAD добавлены две
  автоматические попытки с backoff 250/750 ms при network/408/500/502/503/504; POST/PATCH/DELETE никогда
  автоматически не повторяются. Raw `HTTP 500` заменён понятным сообщением.
- Изменены `backend/api/{schemas.py,main.py,tests/test_content_v2.py}`,
  `admin/lib/{api.ts,api-retry.ts,api-retry.test.mjs,company-store.ts}`, `admin/package.json`, TASKS и этот
  файл. Проверки: backend `54 passed`; admin typecheck + `6 passed`; compileall/diff-check clean; production
  Docker images backend и admin успешно собраны. Локальный Next dev server не останавливался.
- Осталось: выкатить backend/admin на production (миграция БД не нужна), затем проверить `/ready`=200,
  legacy `/api/companies/sweettime/news`=200, вход owner и отсутствие блокирующего экрана. До rollout
  текущий сервер продолжает работать на прежнем коде и может воспроизвести именно этот 500.

## 2026-07-16 — CX-022: серверно подтверждённый заказ и автоматическая очередь admin

- Аудит подтвердил первопричину: `checkout_page.dart` сначала вызывал локальный `checkout()`, который
  очищал корзину, начислял локальные баллы и показывал фиктивный успех. Затем POST выполнялся только
  при устаревающем `apiConnected`, имел двухсекундный timeout и превращал любой отказ в `null`.
  Поэтому пользователь видел принятый заказ, которого не существовало в PostgreSQL и admin.
- Flutter переведён на server-first. Новый `clientRequestId` повторно используется при ручном retry
  одного checkout; запрос получает десять секунд и проходит через общий refresh-token путь. Корзина,
  бонусный переключатель и локальные данные меняются только после успешного ответа API; при ошибке
  показывается честное сообщение, а корзина остаётся. Локальный метод фиктивного checkout удалён.
- Backend хранит `client_request_id` и SHA-256 fingerprint тела, блокирует Company/Customer на время
  принятия решения, безопасно выдаёт номер заказа и защищён уникальными ограничениями
  `(company_id, number)` и `(company_id, customer_id, client_request_id)`. Повтор того же запроса
  возвращает исходный заказ, повтор ID с другим телом даёт 409. Внутренний UUID отделён от номера,
  новый заказ создаётся со статусом `new`. Миграция — `a842d9c13f70`.
- Admin заменил пересекающийся пятисекундный interval на последовательную сверку: 3 секунды для
  видимой вкладки, 15 секунд в фоне, немедленно после focus/online/visibility. После первой успешной
  загрузки сбой не очищает очередь: остаются последние данные и показывается предупреждение.
- Изменены `backend/api/{main.py,models.py,schemas.py,serializers.py}`, миграция и tests;
  `lib/core/api_client.dart`, `lib/shared/app_state.dart`, checkout/localization/widget tests;
  `admin/lib/orders-store.ts`, `docs/TASKS.md` и этот файл.
- Проверки: backend `56 passed`; Flutter analyze clean и `60 passed`; admin typecheck и `6 passed`;
  compileall/diff-check clean. Миграция от пустого PostgreSQL прошла до `a842d9c13f70` и создала оба
  ограничения. Изолированные production Docker images backend/admin успешно собраны. Подписанная
  production APK собрана и проверена apksigner: `build/app/outputs/flutter-apk/app-release.apk` (SHA-256
  `cf7a315b908b5373a393ad6bbdfc679693daef899450a4fd91f8a8299196365f`).
- Осталось: перед миграцией production проверить отсутствие старых дублей номера, сделать backup,
  выкатить backend/admin, выполнить Alembic, установить новую release APK и подтвердить реальный
  Flutter→API→PostgreSQL→admin заказ за 0–3 секунды. Старый установленный APK всё ещё содержит старую
  локальную логику, поэтому один серверный rollout не завершает исправление.
- Риски/следующие задачи: текущие demo payment methods не являются реальной оплатой, а backend пока
  только рассчитывает `pointsUsed/pointsEarned`, не проводит полноценный неизменяемый loyalty ledger.
  До банка нужны отдельные Order/PaymentAttempt/PaymentEvent/OutboxEvent, подписанные идемпотентные
  webhooks и worker. PostgreSQL остаётся источником истины; Redis Pub/Sub нельзя использовать как
  единственное долговечное хранилище. Для субсекундного admin UX позже добавить authenticated SSE,
  сохранив периодическую GET-сверку как восстановление после разрыва.
- Просьба Claude Code: не возвращать local-first `checkout()` и не считать `apiConnected` разрешением
  принять заказ. При будущей оплате расширять схему отдельными payment/outbox сущностями, не смешивать
  банковский статус с lifecycle приготовления заказа.

## 2026-07-16 — CX-023: защищённый SSE и white-label направление

- Добавлен `GET /api/companies/{companyId}/orders/events` (`text/event-stream`). Авторизация идёт
  только Bearer-заголовком через streaming fetch; JWT не попадает в query string/access-log. Перед
  началом потока tenant и staff проверяются в короткой самостоятельной DB-сессии, которая закрывается
  до StreamingResponse и не занимает pool всё время соединения. Cross-tenant token получает 403.
- `OrderEventHub` хранит небольшой tenant-scoped replay window только для wake-up событий. После
  commit создания публикуется `order.created`, после commit статуса — `order.updated`; повтор
  идемпотентного POST событие повторно не публикует. Подключение и переполнение окна отправляют
  `reconcile`, keepalive идёт каждые 15 секунд. Событие не является источником данных: admin всегда
  перечитывает `GET /orders`, поэтому рестарт/потеря SSE безвредны.
- Admin использует `fetch` + ReadableStream, потому что native EventSource не умеет Bearer header.
  Поток включён только для видимой online-вкладки, автоматически переподключается 1/2/5/10 секунд,
  сохраняет Last-Event-ID и немедленно будит coalesced GET. Резервная сверка теперь 15 секунд в
  активной и 60 секунд в фоновой вкладке; focus/online/visibility также сверяют немедленно.
- Container nginx получил отдельный exact-pattern SSE location с HTTP/1.1, buffering/cache/gzip off,
  75-second read timeout; backend выдаёт `X-Accel-Buffering: no`, поэтому и внешний host nginx не
  должен буферизовать поток.
- Изменены `backend/api/{order_events.py,deps.py,main.py,tests/test_order_events.py,
  tests/test_order_submission.py}`, `admin/lib/{api.ts,orders-store.ts,sse.ts,sse.test.mjs}`,
  `deploy/production/nginx.conf`, TASKS и этот файл. Проверки: backend `61 passed`, admin typecheck
  + `8 passed`, compileall/diff-check, nginx `-t`, backend/admin production Docker builds. Реальный
  disposable PostgreSQL+Uvicorn+curl smoke получил `reconcile`, затем `order.updated` сразу после
  PATCH с правильными order/tenant данными.
- Масштабирование: текущий hub корректен для одного backend-процесса, а 15-секундная сверка закрывает
  пропуск даже после рестарта. Перед вторым replica/worker добавить Redis Pub/Sub или PostgreSQL
  NOTIFY только как fan-out wake-up; order truth остаётся PostgreSQL. Для платежей Pub/Sub недостаточен:
  нужен transactional outbox + Redis Streams/RabbitMQ и идемпотентный worker.
- Архитектурное решение предложено в TASKS: разные домены должны указывать на один backend/admin,
  Host→company mapping дополняет существующие URL companyId и JWT cid. Не копировать сервисы/порты.
  Flutter — один core с build flavors и серверными capabilities/layout presets; bubble tea/coffee/
  restaurant оформляются вертикальными модулями, а не отдельными исходниками. Admin показывает
  разделы по enabledModules и общим правам. Реализация hardening — отдельный следующий этап после
  production-приёмки текущего заказа/SSE.
- Просьба Claude Code: не заменять header-auth stream на EventSource с токеном в URL и не передавать
  полные order payload через ephemeral hub. При работе над white-label не создавать копии admin/backend
  на компанию; tenant scope должен подтверждаться сервером, а не только UI/theme.

## 2026-07-16 — CX-024: предложение по платформе для произвольных типов бизнеса

- Статус: `предложение`, не утверждённая реализация и не разрешение начинать отдельный SaaS-этап.
  Примеры Bubble Tea/Coffee/Restaurant из CX-023 слишком узкие: будущим клиентом может быть суши-бар,
  бургерная, магазин одежды, обуви, электроники, сервисный бизнес или другой пока неизвестный тип.
  Одни темы и отраслевые шаблоны не смогут качественно покрыть все различия в данных и UX/UI.
- Не следует строить заранее одну гигантскую админку «на все случаи жизни» и показывать каждому клиенту
  все функции. Предлагаемая граница: один tenant-aware backend и одна admin-shell, внутри которых функции
  подключаются по серверным capabilities/modules. Компания получает только нужные маршруты, формы,
  разрешения и API; отключённые модули не должны появляться в навигации или исполняться только за счёт UI.
- Предлагаемая декомпозиция: (1) общее ядро — tenant/company, auth, роли, клиенты, media, audit,
  notifications; (2) commerce-ядро — каталог, цены, заказы, оплаты/возвраты через явные провайдеры;
  (3) самостоятельные модули — inventory/SKU, размеры и цвета, modifiers, kitchen, tables, delivery,
  reservations, warranties и т. п.; (4) отраслевые starter packs как готовые комбинации модулей;
  (5) клиентский UX-слой для действительно уникальных экранов и сценариев.
- Суши-бар и магазин одежды соединяются не общей перегруженной формой, а общим ядром. Суши-бар включает
  menu/modifiers/kitchen/delivery/stop-list; одежда — catalog/variants/SKU/inventory/returns/delivery.
  Их админки визуально являются разными наборами разделов одной платформы. Общие сущности переиспользуются,
  отраслевые данные остаются в своих модулях и не раздувают обязательный контракт другого бизнеса.
- Flutter также не должен становиться полностью schema-driven конструктором: конфигурацией безопасно
  задавать бренд, навигацию, стандартные карточки и включённые модули, но уникальный клиентский путь всё
  равно может требовать ручной UX/UI-разработки. Цель — переиспользовать инфраструктуру, безопасность,
  auth, API-клиент и зрелые модули, а не обещать отсутствие индивидуальной вёрстки.
- Практическая стратегия: сначала довести и продать SweetTime; при втором реальном клиенте выделять только
  подтверждённо общие границы. Специфическую возможность сначала держать внутри модуля клиента, а переносить
  в платформенный модуль после повторного спроса (ориентир — «правило трёх»). Это снижает риск построить
  дорогой универсальный конструктор до появления реальных требований и одновременно предотвращает полные
  копии backend/admin/mobile для каждого заказчика.
- Разные домены остаются допустимым входом в одну платформу: Host→company mapping, URL companyId и JWT cid
  обязаны совпадать. Отдельный deployment/backend на клиента нужен только при договорном требовании полной
  изоляции, регулировании или существенно ином масштабе, а не как стандартная схема подключения.
- Просьба Claude Code: учитывать CX-024 при следующем архитектурном анализе. Не превращать перечисленные
  starter packs в закрытый список типов бизнеса и не абстрагировать текущий SweetTime-код заранее без
  второго подтверждённого клиентского сценария.

## 2026-07-16 — CX-025: production 400 для товара без размеров

- Физическая приёмка нового order/SSE rollout подтвердила: первый заказ появился в открытой admin за
  ~3 секунды, второй — за 0,5–1 секунду без refresh. SSE работает. Третий заказ на 1 940 сом не появился;
  корзина сохранилась. Production access log показал два `201`, затем повторяемые `400` с телом 51 byte.
  Размер JSON однозначно совпал с backend detail `sizeId is not allowed for this product`.
- Первопричина во Flutter: `_mapModifiers` считал явный server `sizes: []` отсутствием данных и подставлял
  DemoData sizes. Клиент позволял выбрать выдуманный размер, хотя backend корректно поддерживает товар без
  размеров только с `sizeId: null`. Это не сеть, не SSE, не нагрузка и не ошибка миграции.
- Исправлено: явные пустые `sizes/toppings` теперь authoritative; `CartItem`/local cart/history/reorder/
  checkout поддерживают nullable size; сохранённый старый draft автоматически нормализуется для no-size
  товара; quick-add и product page разрешают корректный товар без размеров. HTTP 400/404/409/422 заказа
  отделены от transport/server unavailable и показывают RU/KG/EN сообщение об изменившемся составе вместо
  ложного совета проверить интернет.
- Изменены `lib/core/{api_client.dart,cart_store.dart}`, `lib/shared/{app_models.dart,app_state.dart}`,
  `lib/features/{product/product_page.dart,checkout/checkout_page.dart}`,
  `lib/core/localization/auth_cart_checkout_localizations.dart`, `test/widget_test.dart`, TASKS и этот файл.
- Проверки: `flutter analyze` clean; полный `flutter test` — 61/61; regression создаёт no-size product,
  quick-add и проверяет фактический outgoing `sizeId: null`; `git diff --check` clean. Production release
  APK 81 116 498 bytes, SHA-256 `C547419A67FF0A662BE3BA2588E4428B0C618F3EE19D46216669DAE341C6A6B3`,
  apksigner v2 verified, установлен поверх приложения на Redmi `f3bff2a5` с сохранением данных.
- Осталось: повторить сохранённый заказ на телефоне. Ожидается `201`, очистка корзины и появление admin по
  SSE за 0–3 секунды. Backend/server redeploy не требуется: контракт nullable size уже был корректным.
- Просьба Claude Code: не возвращать fallback DemoData для явных пустых server-массивов и не делать
  `sizeId` обязательным в общем commerce-контракте; это особенно важно для CX-024 и непродовольственных
  товаров, у которых размер может отсутствовать.

## 2026-07-16 — CX-026: системная Android Back-навигация

- Владелец обнаружил, что Android Back с Checkout закрывал приложение: Cart открывал `/checkout` через
  `context.go`, поэтому root Navigator не имел предыдущего route, а Checkout не задавал fallback.
- Cart→Checkout и вход из Cart переведены на `push`; открытия Product из Home/Catalog и Auth из Profile/QR
  также сохраняют экран-источник. Checkout получил видимый `BackButton` и `PopScope`: обычный pop возвращает
  точно назад, direct/deep-link без истории идёт в `/cart`, во время незавершённой отправки заказа уход
  блокируется, чтобы не создавать неоднозначный результат.
- `AppShell` получил системное правило для root tabs: Back из Catalog/QR/Cart/Profile сначала переключает
  на Home; только Back с Home разрешает Android закрыть приложение. Вложенные push-route продолжают
  использовать собственный Navigator stack, поэтому правило shell их не перехватывает.
- Изменены `lib/features/{shell/app_shell.dart,cart/cart_page.dart,checkout/checkout_page.dart,
  catalog/catalog_page.dart,home/home_page.dart,profile/profile_page.dart,qr/qr_page.dart}`,
  `test/widget_test.dart`, TASKS и этот файл.
- Проверки: `flutter analyze` clean; полный `flutter test` — 63/63. Добавлены widget-тесты Android Back
  из direct Checkout в сохранённую Cart и из root Catalog tab в Home. Release APK 81 116 498 bytes,
  SHA-256 `FC8A4D6BA250DC5D7B7966F7FDDE9D48C753EC243FA9622B57346E288F8E6A86`, apksigner v2 verified,
  установлен и запущен поверх данных на Redmi `f3bff2a5`.
- Осталась физическая проверка: Checkout arrow и аппаратная Back → Cart; Back с Cart/Catalog/Profile → Home;
  Back с Home → системный выход. Backend/admin/server redeploy не нужен.

## 2026-07-16 — CX-027: компактная история и полные детали заказа

- По запросу владельца история в профиле больше не размножает карточки: одна компактная строка со стрелкой
  открывает `/profile/orders`, где есть прокрутка, подробная карточка заказа, режим выбора, «выбрать все» и
  эстетичная корзина. Удаление означает только локальное скрытие ID на устройстве; серверный заказ, отчётность,
  баллы и запись для кухни не удаляются. При удалении аккаунта локальный список скрытых ID очищается.
- Backend сохраняет неизменяемый снимок заказа: локализованные название/описание товара, optional image URL,
  размер, сахар, лёд, ID и локализованные названия топпингов с доплатами, количество/цены; отдельно телефон,
  название и адрес филиала, стабильное время и комментарий. Это защищает историю от последующего изменения меню.
  Миграция `f27a4d9c8b11` добавляет optional product image и поля заказа без разрушения legacy-записей.
- Flutter показывает фото из snapshot/current catalog с asset/placeholder fallback, все позиции одного заказа,
  филиал/адрес, тип, время, оплату, статус, телефон, комментарий и баллы. Checkout теперь отправляет стабильные
  `asap`, `HH:mm` или номер стола вместо переведённой строки и передаёт пожелание бариста (до 1000 символов).
- Admin получил «Подробнее» на активных и отменённых заказах и responsive drawer с тем же полным составом;
  отсутствующие legacy-поля не выдумываются. SSE и действия смены статуса не изменялись.
- Изменены Flutter `lib/core/{api_client.dart,order_history_store.dart,router.dart}`, localization/profile,
  checkout/profile/models/state/product card и тесты; backend models/schemas/main/serializers, миграция и тесты;
  admin orders page, detail drawer, API/types/mapper и mapper tests; `docs/TASKS.md` и этот файл.
- Проверки: backend `62 passed`; чистая PostgreSQL миграция от нуля до `f27a4d9c8b11`; Flutter analyze clean и
  `69 passed`; admin typecheck и `11 passed`; diff-check clean. Production rollout ещё не выполнен: сначала
  backup + backend/admin build + Alembic, затем новая подписанная APK, потому что старый backend запрещает новое
  поле `comment` как extra.
- Просьба Claude Code: не превращать локальную кнопку удаления истории в DELETE server orders и не возвращать
  локализованную display-строку в `readyTime`; кухня должна получать стабильные данные и server snapshots.
- Rollout завершён после записи выше: production `/ready` возвращает 200, `/products` уже содержит новое поле
  `imageUrl`, то есть новый backend-контракт активен. Release APK собрана с production `API_BASE`, подпись v2
  подтверждена сертификатом release upload key, SHA-256
  `3A37140C4F9D63C27F1D68D78672863B4F951573E9E0AF767BBCF611A3C2A2C9`; `adb install -r` успешно установил и
  запустил её на Redmi `f3bff2a5` без очистки данных. Осталась только ручная UX-приёмка владельцем.

## 2026-07-16 — CX-028: каталог, rolling session, promo/баллы и refresh истории

- Admin `/menu`: явная кнопка редактирования, все поля товара, фото вместо цветной заглушки, защищённая
  multipart-загрузка/удаление JPEG/PNG/WebP, создание и выбор стабильной категории с обязательными RU/KY/EN.
  Размеры теперь вводятся как итоговая цена; API по-прежнему хранит `priceDelta`, чтобы Flutter/backend имели
  одну формулу. Миграция безопасно исправляет только очевидно ошибочные записи, где все «дельты» были полными
  ценами (production-пример: base 4000 и S=3000 давали 7000).
- Backend: first-class `Category`, tenant/role scope и запрет удаления используемой категории; product image
  variants через существующий `MediaFile`/physical storage с cleanup; `promo_code` snapshot заказа, нормализация
  uppercase, уникальность внутри компании и обязательное соответствие активной акции.
- Auth: серверные `CustomerSession`, 30-дневный idle TTL, продление и ротация на refresh, legacy upgrade,
  replay-family revoke, sid-проверка access, logout revoke и удаление с аккаунтом. Flutter coalesce-ит refresh,
  сохраняет токены при сетевой ошибке и обновляет профиль/историю при resume.
- Flutter: pull-to-refresh истории сохраняет последний успешный список при ошибке; промокод проверяется по
  активному серверному контенту и подсвечивается красным; принятый код уходит в заказ/историю. Баллы нельзя
  включить при нуле, доступен ручной расход от 1 до server cap. Admin detail drawer показывает промокод.
- Миграции линейны: `f27a4d9c8b11 -> c64f0b2d8a31 -> b17c9e4a2f60 -> e18d7a4c9f22`.
  Проверки: backend 71/71; Flutter analyze clean и 75/75; admin typecheck и 11/11; PostgreSQL upgrade с нуля
  до head; production Docker admin build; `git diff --check` clean. Rollout ещё не выполнен: сначала backup,
  архив/backend+admin build/Alembic, затем release APK и физическая приёмка фото/категорий/сессии/promo/баллов.
- Просьба Claude Code: не возвращать категории к вычисляемым ID/русской строке; не трактовать size price как
  delta в UI; не ослаблять server-side promo/points validation и не делать refresh-токены снова stateless.
- Дополнение по ценам: Flutter-карточки и список товаров admin показывают минимальную итоговую цену размера;
  платные топпинги больше не выбираются автоматически при открытии товара. Это дополняет миграцию
  `e18d7a4c9f22` и устраняет как 4000 + 3000 = 7000, так и скрытую стартовую доплату за тапиоку.

## 2026-07-16 — CX-029: UX формы товара, справочник топпингов и строгий promo gate

- Admin: фото нового/существующего товара выбирается только через browser file picker, локально preview-ится
  и загружается после единой кнопки Save; URL/path input и требование сначала создать товар удалены. Размеры
  хранятся в черновике как итоговые цены; optional base вычисляется из минимального размера, но товар без
  размеров не может неявно стать бесплатным. Настройки бренда/лояльности остаются локальным preview draft до
  успешного единого PATCH по Save — shell, сервер и телефон раньше времени не меняются.
- Backend/Admin: `ToppingCatalogItem` tenant-scoped, стабильный ID, RU/KY/EN, price/sort/active и owner/manager
  CRUD. Миграция `a62f1c9d4e30` переносит уникальные существующие product toppings в справочник, не меняя
  product/order snapshots. В product editor готовые топпинги выбираются checkbox-ами, новый создаётся один раз;
  ручные строки остаются. Полные локализации справочника копируются в product modifier JSON.
- Flutter: открытая история опрашивает API раз в 10 секунд, прекращает polling в фоне, немедленно обновляется
  при resume и сохраняет pull-to-refresh. Непустой промокод перед checkout обязательно проверяется свежим
  `/promotions`; invalid/inactive/network-unverified блокирует переход, пустое поле разрешено, backend остаётся
  финальной защитой при POST order.
- Проверки: backend 72/72; Flutter analyze clean и 77/77; admin typecheck и 14/14; production Docker admin build;
  чистый PostgreSQL upgrade от нуля до единственного head `a62f1c9d4e30`; `git diff --check` clean. Rollout и
  signed APK ещё не выполнены.
- Просьба Claude Code: не возвращать media URL field; не делать settings optimistic/auto-save; не связывать
  изменение catalog topping с автоматическим переписыванием существующих products/orders; не доверять promo
  cache при переходе в checkout.

## 2026-07-16 — CX-030: редактирование конкретной позиции корзины

- Пользователь уточнил, что «Редактировать товар» требовалось не только в admin, а непосредственно рядом с
  позицией мобильной корзины. Добавлен явный RU/KG/EN action `/cart/edit/:index`, который открывает существующий
  ProductPage в edit-mode и один раз восстанавливает size/sugar/ice/toppings выбранной строки.
- `replaceConfiguredAt` повторно валидирует актуальный каталог/филиал/modifier IDs, сохраняет quantity, заново
  считает unit/line total, заменяет строго один index и пишет существующий cart draft. Два одинаковых productId
  остаются независимыми строками; stale index/product mismatch ничего не меняет.
- Backend/admin/migration не менялись; нужен только новый signed APK. Добавлены controller regression на две
  одинаковые строки и widget flow Cart -> Edit -> Save -> Cart.

## 2026-07-20 — CX-031: white-label брендинг, просмотренные сторисы, медиа акций и локализация каталога

- Backend получил сохраняемые на уровне компании `logoUrl`, `logoThumbnailUrl` и конфигурацию фоновой темы,
  защищённые upload/delete endpoints и миграцию `b84c1a7e2d90` поверх `a62f1c9d4e30`. Акции получили настоящее
  изображение через `MediaFile` (`banners`) с вариантами original/display/thumb и удалением файлов. Пустые
  заголовок/описание разрешены для image-only акции; при наличии текста мобильная карточка кладёт его поверх фото.
- Admin Settings теперь выбирает логотип и фон через системный file picker, показывает локальный preview и
  отправляет изменения только после «Сохранить». Буквенный псевдологотип удалён. Product editor сохраняет
  RU/KY/EN для названий/описаний товара и названий размеров/топпингов вместо сведения данных к одной строке.
- Flutter читает кэш бренда до первого кадра, поэтому ранее сохранённые цвет, логотип и фон не мигают розовыми
  значениями при старте. Фон применяется к Home и News. Кольца сторис используют accentColor; просмотренные
  хранятся локально по tenant и становятся нейтральными. Белая play-кнопка с превью видео удалена; при отсутствии
  thumbnail показывается логотип компании. В новостной ленте видео лениво показывает первый кадр во всю ширину.
- Профиль больше не создаёт фиктивные Home/Office. Локализованный пункт «Наши филиалы» открывает фактические
  филиалы API с адресом/временем и позволяет выбрать активный филиал.
- Проверки: backend 74/74; Flutter analyze clean, 82/82 tests; admin typecheck и content tests 14/14. Next.js
  production compilation прошла, финальный standalone copy локально упёрся только в Windows EPERM на symlink.
  Release APK с production API успешно собран. `git diff --check` clean. Production rollout/Alembic и физическая
  приёмка на телефоне ещё не выполнены.
- Просьба Claude Code: сохранить стабильный `MediaFile`-контракт и `media_kind=banners` для promotion image;
  не возвращать буквенный логотип, не делать branding optimistic до Save и не удалять tenant-scoped viewed state.

## 2026-07-20 — CX-032: запрос студиям на оценку и поддержку

- Добавлен `docs/STUDIO_ESTIMATE_REQUEST_RU.md`: нейтральное ТЗ/RFQ для независимой оценки существующего
  проекта, а не разработки с нуля. В нём зафиксированы текущий функционал и стек, честно отделены mock/demo
  платежи и неподключённые SMS/фискализация, отдельно запрошены аудит, Android hardening, iOS/TestFlight/App Store,
  внешние интеграции, гарантия и три уровня ежемесячной поддержки с SLA.
- Коммерческую оценку предлагается получать по одинаковой таблице: цена, человеко-часы, срок, команда,
  допущения и исключения. Для предложения о rewrite студия обязана дать отдельное обоснование и сравнение с
  доработкой существующей базы. Production-секреты и аккаунты в материалы для первичной оценки не входят.

## 2026-07-20 — CX-033: адаптивный полноэкранный viewer видео-новостей

- `_NewsPostSheet` для video больше не использует жёсткие 78% экрана и `BoxFit.contain`. После инициализации
  player передаёт реальный aspect ratio; stage получает высоту `screenWidth / videoAspectRatio` с cap по
  безопасной высоте экрана и `BoxFit.cover`, поэтому видео начинается ниже status bar, заполняет ширину без
  боковых gutters и имеет разную высоту для 9:16, 3:4, 16:9 и ultra-tall источников.
- Заголовок перенесён на нижний gradient поверх видео. По нажатию caption плавно раскрывает ограниченно
  прокручиваемое описание и дату; Close, play/pause, tap-to-mute и Android Back сохранены. Mute indicator
  поднимается выше закрытого caption.
- Добавлены callback `NewsMediaView.onVideoAspectRatio`, параметр `controlsBottomInset`, widget regression
  раскрытия caption и unit regression расчёта высоты. Flutter: 84/84 tests, analyze clean, release APK собрана.
  Установка не завершилась только потому, что Redmi отключился от ADB сразу после сборки; APK готова локально.
## 2026-07-21 — Claude handoff `56fd1c1`: проверка перед production rollout

- Прочитан handoff Claude: реальное погашение referral-кода, движение баланса баллов и
  миграция `c19f6b4a8e21` поверх `b84c1a7e2d90`.
- Локальная приёмка: backend `83 passed`, Flutter `84 passed`, `flutter analyze` — без
  замечаний; Alembic имеет единственный head `c19f6b4a8e21`; рабочее дерево чистое.
- У локального репозитория нет настроенного Git remote, поэтому публикация выполняется
  проверенным production-архивом на `/srv/projects/sweetime`, а не `git push`.
- Production rollout обязан идти в порядке: verified backup -> extract с сохранением `.env`
  -> build -> `alembic upgrade head` при работающем старом backend -> recreate backend/nginx
  -> smoke-check. Старый backend нельзя останавливать до успешной миграции.
- Отдельная demo-компания пока не создана. Нельзя повторно запускать
  `bootstrap_production_sweettime`: он корректно откажется при существующей SweetTime.
  Нужен отдельный tenant-safe идемпотентный bootstrap CoffeeGo; он не должен изменять
  `sweettime` и не должен использовать известный пароль `demo`.

### Demo tenant implementation

- Добавлен `bootstrap_production_demo_company` и CLI `python -m api.bootstrap_demo` с
  production overlay `docker-compose.demo-bootstrap.yml`. Пароль владельца читается только
  из mode-600 файла вне репозитория.
- Bootstrap одной транзакцией добавляет CoffeeGo: 2 филиала, 7 товаров, stories/promotions,
  25 заказов, отдельного клиента с 860 баллами/избранным/историей и активный постоянный заказ.
- Повторный запуск — безопасный no-op; существующий email владельца отклоняется; отсутствие
  боевой SweetTime также приводит к отказу.
- Regression доказывает неизменность количества Branch/Product/News/Promotion/Customer/Order
  для `sweettime`, полноту CoffeeGo и отсутствие дублей после повторного запуска. Полный backend:
  `84 passed`; compose overlay проходит `config --quiet`.
- Первый production smoke выявил `GET /coffeego/products` = 500: у legacy-опций размеров
  `cg-p5` отсутствовали обязательные stable IDs. Fixture исправлен (`s`/`m`), а повторный
  идемпотентный bootstrap теперь конвергентно ремонтирует уже созданную строку без дублей и
  без изменения SweetTime. Regression валидирует каждый modifier через `ModifierOptionOut` и
  отдельно сценарий ремонта; полный backend снова `84 passed`.

### Production result

- Referral/loyalty rollout установлен на production: миграция `c19f6b4a8e21`, `/ready`,
  SweetTime config и login = 200; referral endpoint без JWT = ожидаемый 401.
- CoffeeGo создан отдельно: 2 филиала, 7 товаров, 25 заказов, 1 demo-клиент; config/news/login
  и после modifier repair products = 200. SweetTime остался отдельным (`3/10/25/1`).
- Финальная release APK собрана после backend rollout, подпись проверена: SHA-1 сертификата
  `51:DC:A2:E5:1D:37:6E:BB:B1:B7:E8:A8:A8:77:8A:2D:D4:92:16:54`; APK SHA-256
  `ec3e08905dc24bcc5ba55b0567672bcd96990e39263e8e365699a0dc89bb0d3f`. Установка
  `adb install -r` прошла успешно без удаления данных, приложение запущено на устройстве.

### Critical APK configuration hotfix

- После установки владелец не смог войти и приложение не получало admin-config. Причина доказана:
  финальная APK была собрана generic-командой без `--dart-define=API_BASE=...`, а старый default
  указывал на `http://127.0.0.1:8010` — localhost самого телефона. Google account chooser при этом
  успешно открывался, но backend login/config были недоступны.
- `api_client.dart` теперь fail-safe по режиму: release без override использует
  `https://lnp-corporation.duckdns.org`, debug без override сохраняет локальный `127.0.0.1:8010`;
  явный `API_BASE` по-прежнему поддерживается. Добавлены 3 regression-теста resolver.
- Flutter `87/87`, analyze clean. Новая APK собрана также с явными production API и Google Web
  audience; production hostname найден внутри release `libapp.so`, телефон напрямую получает
  `/ready` = 200, release SHA-1 сохранён, `adb install -r` = Success. APK SHA-256:
  `247da42678fce132773bb8d386bb739a85f208c60ca5a8203d5d3d3d03dfd411`.

## 2026-07-21 — CX-034: current admin preview and customer history hydration

- Owner reported two connected defects: Settings still showed an obsolete miniature app and its dark shell
  stretched below the rounded phone; orders were present/processed in admin but Profile history rendered empty.
- The preview tail was a CSS layout bug, not media: the phone was a flex child with a dark background and default
  cross-axis stretch. It now uses `self-start`, `h-fit` and clipped shell geometry. Preview content mirrors the
  current mobile structure: logo, RU/theme controls, branch selector, branded hero, promotions, stories with media,
  product images and the five Home/Catalog/QR/Cart/Profile tabs. Unsaved logo/background/accent drafts stay inside
  preview and still reach API/phone only after Save.
- Mobile order history no longer relies exclusively on a second request after checkout: `POST /orders` already
  returns the committed `OrderOut`, so `CreatedOrder` carries its parsed immutable snapshot and state inserts it
  immediately before server reconciliation. The dedicated history route refreshes on first frame in addition to
  its existing 10-second polling, resume refresh and pull-to-refresh.
- Local hidden history was incorrectly company/device scoped. It is now keyed by tenant + customer ID and cleared
  from memory on logout, preventing one account's hidden IDs from suppressing another account's orders.
- Checks: Flutter analyze clean; full Flutter tests 88/88 (new immediate-history regression); admin typecheck and
  14/14 content tests pass. Next production compilation reaches completed page generation locally; final standalone
  copy still hits the known Windows symlink EPERM only. Signed APK built with explicit production API + Google Web
  audience and installed via `adb install -r` on `f3bff2a5`; SHA-256
  `e0de305874be8bad041d66f7fe109d45f0473bfba6c3400ac3257f2ac4c6fc01`.
- Remaining: deploy/rebuild admin container, then owner verifies Settings preview and opens Profile → Order history.
  If legacy server orders still fail to hydrate, capture authenticated `/auth/customer/me/orders` status/body and
  backend log for that request; do not infer order ownership from customer name.
- Production admin rollout completed from archive `sweettime-history-preview-766d2ec.tar.gz`: archive SHA-256
  verified, `.env` preserved, admin/nginx recreated healthy. Public smoke: `/ready` 200, `/login` 200 and
  SweetTime company config 200. No database migration or backend restart was required.
# 2026-07-21 — найден корень пустой истории заказов после rollout

- Пользователь подтвердил, что после `766d2ec` экран истории всё ещё пуст, хотя заказы видны в админке.
- Причина в несовпадении уже утверждённых контрактов: backend `LocalizedText` требует только `ru` и допускает
  `ky/en = null`, а `_localizedSnapshot` во Flutter требовал три непустые строки. Один созданный владельцем
  товар/размер/топпинг без завершённых переводов делал весь `/auth/customer/me/orders` недоступным для клиента.
- Исправлен `lib/core/api_client.dart`: обязательный RU сохраняется, отсутствующие KY/EN получают RU fallback;
  значения неправильного типа по-прежнему отклоняются. Добавлен production-shaped regression test в
  `test/order_history_test.dart` для товара, размера и топпинга с null/blank переводами.
- `dart format` и `git diff --check` прошли. Полный Flutter test/analyze/build из Codex-среды заблокирован не
  кодом: текущий sandbox-user не имеет read/write к пользовательским Flutter SDK/Pub Cache; обычный `flutter`
  бесконечно повторяет lock bootstrap, прямой snapshot подтверждает access denied. Нужен запуск проверки и
  release build из пользовательского PowerShell, затем `adb install -r` без очистки данных.

## 2026-07-22 — Android test distribution artifact

- Confirmed that `build/app/outputs/flutter-apk/app-release.apk` was built after the latest order-history parser fix and its regression test.
- Copied the single-file Android installer to `dist/SweetTime-Android-test-2026-07-22.apk` for tester distribution.
- Artifact: version `1.0.0+1`, 81,789,794 bytes (~78 MiB), SHA-256 `F8E43A97C9452E1C3D7580B7069CB92D914E9DC06D01A92929DD0802A1177B22`.
- This is a direct-install APK; recipients should receive it as a document/file and allow installation from the chosen messenger/file manager when Android prompts them.

## 2026-07-22 — referral acquisition flow (local implementation, rollout pending)

- Baseline before this work is committed at `8e3cea0` (`Prepare SweetTime for IOS`); only the old
  `.codex-phone-install.png` was untracked. Current referral changes are intentionally still uncommitted
  until tests/build/device acceptance complete, so rollback remains unambiguous against that baseline.
- Split the overloaded customer QR into three explicit tabs: loyalty QR (`SWEETTIME:LOYALTY:*`),
  invitation HTTPS QR/share/copy, and scanner/manual activation. New canonical links are
  `https://lnp-corporation.duckdns.org/invite/sweettime/<code>`; the parser remains backward-compatible
  with `SWEETTIME:REF:*` and plain codes.
- Added `/invite/:companyId/:code` mobile flow. The code is persisted in SharedPreferences before auth,
  survives Google account selection/contact-phone completion/process restart, and is automatically
  redeemed only when the account is ready. Business validation and point movement remain entirely on
  the existing backend endpoint; network failure keeps the pending invite for retry, final business
  outcomes clear it.
- Added a dependency-free Android native share bridge, Android verified App Link manifest entry,
  backend invite landing page and `/.well-known/assetlinks.json`. Production assetlinks exposes only the
  current release signing certificate. Production nginx routes these endpoints and serves the signed pre-Play
  APK from `/srv/sweetime/downloads/SweetTime.apk`; compose and preflight now include that directory.
- Added Flutter pure/parser/persistence regression tests and backend landing/assetlinks tests; updated
  RU/KY/EN copy and `REFERRAL_LOGIC.md`. Version bumped to `1.0.1+2`.
- Verification blocker is environmental, not an observed code failure: Codex sandbox cannot read the
  user's Pub Cache or write the Flutter SDK lockfile; Computer Use helper is unavailable. `dart format`
  and `git diff --check` pass, but analyze/tests/release build must be launched once from the user's normal
  PowerShell. After that Codex can install with ADB and perform route/UI smoke checks on `f3bff2a5`.
- Further isolation confirmed the same boundary: direct `flutter_tools.snapshot` reaches the build command
  but cannot update SDK cache stamps, while direct Gradle reaches the cached 9.1 distribution but cannot
  create the native-library lock in the user's read-only Gradle home. The device remains connected. No
  generated `.tool-home` telemetry files were kept in the worktree.
- First user-side compile exposed one duplicate `AppLocalizations.retry` getter introduced with the invite
  copy. Removed the later duplicate and retained the original shared RU/KY/EN getter. The reported test and
  release-build failures all had this single compile cause; the `mobile_scanner` KGP message is only a future
  migration warning. A pre-existing APK left in `build/` after the failed build must not be treated as fresh.
- User-side release build then succeeded (`1.0.1+2`, 81,872,578 bytes, SHA-256
  `28B884A0EE594951156623FD7AEB00C2423248AD943725EDBF0FCFF96D3DD551`) and Codex installed it with
  `adb install -r` on `f3bff2a5`; the production signer fingerprint matches assetlinks. Device smoke verified
  app startup, three QR tabs, invite QR/code/bonus copy, Android share chooser, copy action, and direct HTTPS
  routing into the invitation screen. Smoke also caught and locally fixed two UX/state issues for the next
  build: inviter-tab title now says “Invite a friend” (RU/KY/EN), and the invite page listens for delayed
  `accountReady` hydration so cold-start links auto-redeem after session restoration. Rebuild/reinstall and
  final cold-start verification remain pending for these last two fixes.

### Final mobile verification and QR UX pass

- Reworked the QR surface after comparing the previous and current device layouts: all three tabs now share
  the width equally, both QR codes use a larger responsive white scan target, the invitation explanation is a
  compact readable card, the referral code has its own copy action, and share/copy-link actions no longer form
  two oversized competing buttons. The inviter tab uses the correct RU/KY/EN title.
- Fixed the cold-start hydration race by listening for `accountReady`: an invitation opened before the stored
  session finishes restoring is now applied immediately after the account becomes ready instead of being lost.
- A final review caught and fixed a competing-screen race after Google auth: referral redemption is now
  single-flight and memoized per customer/code, so auth, bootstrap and the original invite screen cannot send
  duplicate POSTs or replace a successful result with `already_invited`. A regression starts concurrent calls
  and proves that the API receives exactly one request. Referral bonuses are parsed/cached from company config
  and used by QR, loyalty, activation-result and first-order UI instead of hard-coded values. The public landing
  avoids stating a stale amount, and production `assetlinks.json` no longer authorizes the debug certificate.
- Verification completed: `flutter analyze --no-pub` is clean, Flutter tests pass 95/95, and the production
  `1.0.1+2` APK was built with the production API and Google Web audience, installed with `adb install -r` on
  `f3bff2a5`, and exercised on-device. Direct HTTPS invitation routing, delayed-session auto-redemption, code
  copy, link copy and Android native share chooser (Telegram/WhatsApp/Messages) all pass.
- Final APK after the race/config fix: `build/app/outputs/flutter-apk/app-release.apk`, 81,889,190 bytes,
  SHA-256 `CFEBCB8023B4858B04D9E7259DB90A87C2A1732DE5F65E6ED4291C714175AF43`; signer SHA-256
  `0312D7D2993769A8169E0CE4815D4C9B96E9008C4B95FE8ED66D2A873FCCD044`.
- The added backend landing/assetlinks test could not be executed in this Windows session because neither a
  Python runtime nor Docker daemon is available. Flutter/mobile acceptance is complete; production deployment
  of the new landing, `assetlinks.json`, nginx routes and APK download plus a real two-account referral test
  remains separate rollout work.

## 2026-07-24 — scheduled content, staff invitations and product media

### CX-035 — отложенная публикация stories/news

- В `admin/components/news/` редакторы сторисов и ленты получили два режима: публикация сейчас либо
  в выбранные локальные дату, час и минуту. При редактировании уже опубликованной записи сохраняется
  исходная дата; фиксированный срок жизни сториса считается от выбранного времени публикации.
- Backend по-прежнему является источником истины: будущая запись не возвращается до точного условия
  `published_at <= now`. В `backend/api/tests/test_content_v2.py` добавлена проверка границы:
  за одну микросекунду до срока запись скрыта, ровно в срок — видна.
- Flutter в активном foreground раз в 30 секунд делает только лёгкое обновление stories, подборок
  и news feed. Запросы объединяются, полный refresh не дублируется; пауза/фон останавливают таймер.
  Неуспешный endpoint сохраняет последнее успешное состояние, а успешный пустой ответ удаляет
  просроченный/снятый с публикации контент.
- Проверки: admin `typecheck` и `test:content` (14/14) проходят. Полный Flutter-прогон после добавления
  таймера не выполнен из этой среды: пользовательский Flutter SDK/Pub Cache недоступен sandbox,
  а повышенный запуск отклонён лимитом инструмента. Добавлена целевая регрессия обновления контента.
- Неблокирующая оптимизация на рост: текущий 30-секундный `fetchNewsPosts()` собирает все страницы ленты.
  Когда архив станет большим, заменить это на content-version/ETag либо запрос изменений после cursor.

### CX-036 — приглашения сотрудников и серверный RBAC

- Добавлена миграция `d8e42c1a7f90_staff_invitations`: активность сотрудников и одноразовые
  приглашения с tenant, ролью, филиалом, сроком действия и только SHA-256 digest токена.
- Владелец в `/staff` может пригласить manager или привязанного к филиалу barista, изменить имя,
  роль, филиал и активность, повторно выпустить/отозвать приглашение. Сотрудник открывает HTTPS-ссылку
  и сам задаёт пароль; токен из URL fragment удаляется из адресной строки после чтения.
- До настройки SMTP работает честный безопасный fallback: owner копирует одноразовую ссылку вручную.
  SMTP-режим допускает только TLS с проверкой сертификата (`starttls`/`ssl`) и не сообщает ложный успех.
- Backend запрещает управление сотрудниками не-owner, вход/refresh отключённого аккаунта и доступ
  barista к чужому филиалу. Ограничение применяется к списку/смене статуса заказов и SSE; длинное SSE-
  соединение повторно проверяет срок JWT, активность, роль и филиал максимум через 15 секунд.
- Backend runtime-тесты в этой Windows-среде не запускались: Python и Docker daemon отсутствуют.
  Перед production обязательны backup, deploy, `alembic upgrade head`, smoke owner/manager/barista
  и отдельная проверка SMTP. Будущие hardening-задачи: rate limit для staff login/invitation preview,
  partial unique/idempotency против двух строго параллельных pending-invite на один email и server-side
  token version, если deactivate должен безвозвратно отзывать уже выданные refresh-токены.

### CX-037 — фотография товара в деталях

- `ProductPage` и редактор позиции корзины теперь сначала используют `product.imageUrl`, затем
  bundled asset, затем сгенерированный `DrinkArt`. Ошибка сети/декодирования безопасно включает fallback.
- Целевые `flutter analyze` и `test/product_media_test.dart` (3/3) прошли до последующего изменения
  фонового content timer; сами product-файлы после этого не менялись.

### Решение по превью сторисов

- Владелец подтвердил текущую логику: если отдельная обложка не задана, в круглом превью используется
  логотип компании. Это оставлено как корректный fallback. Для уникального превью конкретной сторис
  в будущем следует хранить отдельный cover/thumbnail, не заменяя общий логотип.

### Текущее состояние и передача Claude

- Безопасная точка до этапа: commit `5ffc27c`.
- Код этого этапа пока не закоммичен: sandbox разрешает менять рабочие файлы, но запись в `.git`
  требует elevated-доступа; запрос на commit был отклонён лимитом инструмента, до выполнения команд.
  Код требует production rollout и физической приёмки; канонический статус обновлён в
  `docs/TASKS.md`. Не считать staff/schedule production-ready только по наличию UI.
- Не добавлять в commit `.codex-phone-install.png`: это локальный артефакт инструмента/пользователя.

## 2026-07-27 — постоянные заказы V2: несколько подписок, редактирование и аналитика

- По прямому запросу владельца завершён локальный этап Recurring Orders V2. Клиент может иметь
  до 20 независимых активных постоянных заказов; каждый имеет стабильный ID, отдельные товары,
  филиал, время, комментарий и период 1/7/30 дней. Flutter показывает все подписки, добавляет
  новую, редактирует только выбранную, подтверждает отмену и обновляет список после resume.
- Backend добавляет plural CRUD, optimistic `baseVersion`, `Idempotency-Key`, locked snapshot
  состава/названий/фото/размера/цены и журнал signed корректировок. Изменение состава или срока
  пересчитывает только будущие ещё не сгенерированные выдачи. Уже созданный заказ на сегодня
  сохраняется; отмена записывает отрицательную корректировку только за оставшийся период.
- Планировщик теперь строит ежедневный заказ из locked snapshot и fail-closed проверяет сумму.
  Текущий каталог используется только для legacy-строк без snapshot. Legacy PATCH делегирован
  V2-расчёту, чтобы старый APK не мог бесплатно увеличить оплаченный состав.
- В админ-дашборд владельца/менеджера добавлена карточка и подробная сводка: активные подписки,
  сгенерированные/завершённые сегодня, сегодняшние положительные корректировки, обязательная
  дневная сумма, клиент, товары и фото, филиал, время, период, paidUntil, daily/prepaid amount,
  последняя корректировка и заказ на сегодня. Есть 30-секундное/focus/online обновление.
- CoffeeGo bootstrap теперь создаёт и при повторном запуске ремонтирует locked snapshot demo-
  подписки без дублей. Миграция: `9d3f1c7a2b60`; Alembic head одна.
- Важное ограничение: `settlementMode=mock`. Доплата/кредит рассчитываются и журналируются, но
  реальные деньги пока не списываются/возвращаются. UI явно говорит «демо». Для production-money
  нужен PSP/bank intent+refund+webhook и постоянный mobile outbox.
- Документация: `docs/design/RECURRING_ORDERS_V2.md`; V1 помечен ссылкой на V2;
  канонический статус обновлён в `docs/TASKS.md`.
- Проверки: backend `110 passed`, compileall, одна Alembic head; Flutter `109 passed`,
  `flutter analyze --no-pub` чист; admin typecheck и 15/15 tests; `git diff --check` чист.
- Production не менялся. Следующий отдельный этап после разрешения владельца: backup,
  backend/admin build, `alembic upgrade head`, smoke/RBAC, затем release APK и физическая
  проверка двух подписок с edit/reprice/cancel/dashboard.
- Не включать `.codex-phone-install.png` в commit. В `backend/api/recurring.py` до этапа уже был
  незакоммиченный рефакторинг Claude; V2 snapshot-фикс объединён поверх него и покрыт тестами.
 
### 2026-07-27 rollout package

- Prepared local deployment archive for Recurring Orders V2:
  `dist/sweettime-recurring-v2-9d3f1c7.tar.gz`.
- SHA-256: `aa9930692b78e7bae1a4271ad6774e970809fc3bd34b0e11eba33939443de3b2`;
  size: `19251068` bytes.
- Archive includes tracked files plus new untracked V2 files, and excludes `.git`, env files,
  local signing files, build/dist outputs, dependency caches, and `.codex-phone-install.png`.
- Production has still not been changed in this turn. Next step: upload archive, create verified
  production backup, extract while preserving `.env`, build backend/admin, run Alembic to
  `9d3f1c7a2b60`, smoke endpoints, then build/install APK and run physical-device acceptance.
 
### 2026-07-27 production rollout and APK install

- Owner-provided production output verified: Alembic upgraded `f7b9d4e82c15 -> 9d3f1c7a2b60`,
  backend/admin healthy, `/ready` 200, `/login` 200, company config 200, recurring analytics
  without token 401 as expected.
- Built release APK locally with production API and Google Web client ID. Output:
  `build/app/outputs/flutter-apk/app-release.apk`, size `82471129` bytes,
  SHA-256 `D53E632AAA3D89D4629AC9866C5BE149FAA8ED22B0702D8093B52AE48FCC09F7`.
- Installed APK on connected Android device `f3bff2a5` with `adb install -r`: Success.
  Launch smoke via `adb shell monkey -p kg.sweettime.app 1` succeeded; focused app is
  `kg.sweettime.app/.MainActivity`; no recent `AndroidRuntime`/`FATAL EXCEPTION`/Flutter crash lines.
- Remaining acceptance: manual phone QA for multiple recurring orders, edit/reprice/cancel, and
  admin recurring dashboard visibility with real logged-in owner session.

## 2026-07-29 — iOS OAuth callback and black video root cause

- Reviewed Claude commits `7b90990..1014a72` and inspected the latest unsigned IPA. The IPA really contained
  the iOS client ID, reversed URL scheme and the attempted Impeller opt-out; the problem was not an old
  Codemagic artifact.
- Downloaded the actual production story/news MP4 files. Two files that reproduce black video contain
  `vp09` + `mp4a`; the H.264 sample contains `avc1` + `mp4a`. Thus `Content-Type: video/mp4` was insufficient:
  AVFoundation could play audio from the VP9-in-MP4 files while rendering no frame. The previous
  `FLTEnableImpeller=false` workaround did not address the stored codec and was removed.
- `backend/api/storage.py` now runs ffmpeg for every admin video upload and emits H.264 High/yuv420p level
  4.1 + AAC, `faststart`, a WebP thumbnail, dimensions and duration. `content.py` stores/returns the preview.
  The production backend image now installs ffmpeg. `backend/api/normalize_existing_videos.py` replaces old
  media with normalized files under new UUID URLs, deliberately bypassing the immutable 30-day cache.
  Inner and example host nginx configs give only authenticated story/news media uploads a 600-second
  processing timeout; the generic API timeout remains 60 seconds.
- Google configuration now includes `GIDServerClientID`; Dart passes explicit iOS and Web client IDs.
  SceneDelegate handles the Google callback before forwarding unhandled URLs to Flutter, and AppDelegate has
  the official legacy lifecycle fallback. Both Codemagic and GitHub iOS workflows pass the iOS client ID.
  Mobile version is bumped to `1.0.10+11` for an unambiguous replacement build.
- Checks completed locally: `flutter analyze --no-pub` clean; `flutter test --no-pub` 109/109 passed;
  `git diff --check` clean. Backend runtime tests could not run on this Windows host because Python and a
  Docker daemon are unavailable; the storage test has a deterministic injected video processor.
- Production and the installed iPhone app have not been changed yet. Required rollout order: backup; deploy
  and build ffmpeg-enabled backend; run backend tests/smoke; execute
  `python -m api.normalize_existing_videos --tenant sweettime`; verify new media URLs and thumbnails; build
  a fresh IPA in Codemagic; install with Sideloadly; test Google login and every video on the physical iPhone.
- Do not include `.codex-phone-install.png` in any commit.

### 2026-07-29 production rollout status

- Owner ran the verified deployment package `dist/sweettime-ios-media-fix-2bdd4ca.tar.gz`.
- Production backend image was rebuilt with ffmpeg and all three existing SweetTime story/news videos
  were normalized successfully: `converted=3, failed=0`.
- Compose reported PostgreSQL, admin, backend and nginx healthy; public `/ready` returned HTTP 200.
- Host nginx configuration passed `nginx -t` and was reloaded.
- The verification shell exited after `/ready` because the check used the obsolete/nonexistent
  `/home-stories` path instead of `/stories/home`; the resulting 404 JSON was then parsed as a story
  list. This happened after the successful rollout and did not roll anything back.
- Remaining acceptance: verify current DB-backed video rows expose thumbnails and H.264/yuv420p files,
  then install the Codemagic `1.0.10+11` IPA and test Google callback plus story/feed video image on iPhone.

### 2026-07-29 physical iPhone acceptance follow-up

- Owner installed Codemagic build `1.0.10+11`. The Google account chooser/callback now completes and
  production video previews render, confirming both original iOS client-side failures are fixed.
- The subsequent backend exchange is rejected because production
  `GOOGLE_OAUTH_AUTHORIZED_PARTY_IDS` was created before the iOS OAuth client and contains only the
  Android debug/release presenters. The iOS token uses the Web client as `aud` and the iOS client as
  `azp`; the verifier correctly rejects an `azp` absent from the explicit app-family allowlist.
- `deploy/production/.env.example` now includes the iOS client ID
  `23205820785-463eql7n3d8un18e805kqfbb9lmgedbb.apps.googleusercontent.com`.
- Remaining production action: back up `.env`, add that iOS ID to
  `GOOGLE_OAUTH_AUTHORIZED_PARTY_IDS`, recreate backend/nginx, verify loaded settings, and retry the
  same installed IPA. No new mobile build is required for this configuration-only correction.

### 2026-08-02 cart, branch availability, route surfaces, and staff email delivery

- Added a global cart clear action with an explicit destructive confirmation. Clearing also resets
  promo/bonus state and persists the empty local cart. Stable cart row snapshots prevent index errors
  while removing several rows at once.
- Added branch-aware catalog UX in RU/KY/EN: `My branch` and `All branches` scopes, available products
  first, a separate unavailable section, disabled closed/incompatible branches, and an explicit branch
  picker before adding an unavailable product. Changing branch never auto-adds a product. Home quick-add
  and product details use the same rule.
- The cart keeps locally selected products but clearly lists rows unavailable at the current branch,
  offers only a branch compatible with the whole cart, and blocks checkout until the conflict is resolved.
  Server catalog refresh now rebinds stored cart rows by stable product/modifier IDs and current prices.
- Fixed the iOS transition overlap shown in screenshots: every root pushed route and the shell now owns
  an opaque branded surface instead of revealing the outgoing transparent route. Removed duplicate nested
  backgrounds, isolated pattern painting in a `RepaintBoundary`, and narrowed Product/Loyalty provider
  subscriptions to reduce unrelated rebuilds. Physical iPhone smoothness still needs confirmation on the
  next IPA; the regression is covered by route-surface widget tests.
- Staff invitation SMTP adapter is production-configurable for authenticated STARTTLS, implicit SSL, or
  approved anonymous/IP relay. Failures are reported honestly while logs omit recipient local-part,
  provider response, password, and invitation token. Compose now forwards `SMTP_TIMEOUT_SECONDS`.
- Real email delivery is intentionally not claimed yet: production stays in manual mode until an SMTP
  provider/relay, verified sender, credentials, and SPF/DKIM/DMARC are configured in the server `.env`,
  backend is recreated, and an external inbox acceptance test succeeds.
- Checks: Flutter analyze clean; Flutter tests `117/117`; backend tests `132/132`; admin typecheck clean and
  content tests `15/15`. Admin production compilation and page generation succeeded; Windows standalone
  trace copy alone hit an OS `EPERM` symlink restriction (Linux/Docker build is unaffected). `git diff --check`
  clean; public `/ready` HTTP 200.
- Built signed Android release `1.0.10+11` with the production API/Google IDs and installed it over the
  existing app on Redmi Note 9 Pro `f3bff2a5` without clearing data. Cold launch succeeded, no Flutter/
  AndroidRuntime fatal logs appeared, production content loaded, cart confirmation was opened/cancelled
  with all six rows preserved, and the catalog exposed both branch scopes.
- New files: `lib/shared/widgets/branch_picker.dart` and
  `backend/api/tests/test_staff_email.py`. Do not include unrelated `.codex-phone-install.png` in a commit.

### 2026-08-02 final branch/transition review and Android acceptance

- Closed branch rows in the shared picker are visible but disabled; Home now uses that same picker instead
  of a second permissive implementation. Product detail handles a product removed during a live catalog
  refresh without `firstWhere` crashes and offers a safe return to the catalog.
- The selected open branch is persisted locally and restored after restart. Missing or newly closed saved
  branches fall back to the first open branch and the corrected preference is persisted. Home and catalog
  quick-add now use the cheapest size and no paid toppings, matching the displayed starting price.
- Catalog reconciliation explicitly flags cart rows removed or repriced by the server and shows a localized
  notice in Cart (including when reconciliation makes the cart empty). The user can acknowledge the notice;
  clear-cart, completed checkout and account deletion reset it intentionally.
- Removed the redundant app-wide `BrandedBackground` after verifying route coverage. Shell and pushed root
  routes retain their own opaque branded surfaces, reducing normal GPU overdraw from two layers to one and
  transition overdraw from three layers to two. Independent route review passed; physical iPhone frame
  pacing remains the only acceptance step that cannot be performed from the connected Android device.
- Final checks: Flutter analyze clean; complete Flutter suite `122/122`; backend `132/132`; admin typecheck
  clean and content tests `15/15`; `git diff --check` clean; public `/ready` HTTP 200. Both independent SMTP
  and branch/catalog audits passed.
- Built production-signed Android `1.0.10+12` (versionCode 12; signer SHA-256
  `0312d7d2993769a8169e0ce4815d4c9b96e9008c4b95fe8ed66d2a873fccd044`) and installed it over the existing
  Redmi Note 9 Pro app without clearing application data. Cold launch completed in about 1.9 seconds with
  no Flutter/Android fatal log. Production content and both branch scopes loaded. From the initially empty
  cart, a temporary quick-add produced the advertised 360 som S/no-paid-topping row; clear confirmation was
  cancelled once, then confirmed, returning the phone to its original empty-cart state.
- Residual non-blocking limitation: an offline cold start cannot identify a price-only catalog change made
  while the app was closed because legacy `CartDraftItem` intentionally stores IDs/options rather than the
  previous server price. Current server data is still applied correctly; only that explanatory notice is
  absent in this narrow scenario.

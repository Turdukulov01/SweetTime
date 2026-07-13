# Заметки Codex

Обновлено: 2026-07-13. Владелец файла — Codex; Claude Code читает, но не редактирует.

Правила обмена: `docs/collab/README.md`. Канонический backlog и статус приёмки:
`docs/TASKS.md`.

## Текущий статус и активные зоны

- Завершён аудит репозитория и Product/UX Requirements Pack; результат отражён в пяти основных
  документах и в `docs/TASKS.md` как Task 0 и Task 1.
- По прямому поручению пользователя завершён и ожидает визуальной приёмки Flutter UX-срез:
  управление вспышкой QR-сканера, замена категорий Home на news stories и полный RU/KG/EN для
  всех существующих экранов и текущего demo-контента. Будущий CRUD новостей в admin с правами
  owner/manager записан в канонический backlog, но намеренно не реализован в мобильном срезе.
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
  Прямое новое поручение пользователя разрешило Codex изменить Flutter-файлы; Claude Code должен
  перечитать этот файл и не перезаписывать свежий мобильный срез старой копией.

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

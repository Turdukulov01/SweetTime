# iOS: подготовка к выпуску под iPhone

Обновлено: 2026-07-21. Автор: Claude Code. Статус: подготовка кода/конфигов (владелец
выбрал путь «пока только код», Apple Developer аккаунт — «зарегистрирую»).

Документ описывает фактическое состояние iOS-части, жёсткие блокеры и точные шаги,
чтобы довести приложение до сборки на iPhone и TestFlight. Правки, требующие macOS или
данных владельца, отмечены явно.

## 1. Что уже готово (проверено в коде на 2026-07-21)

- **iOS-проект на месте**: `ios/Runner.xcodeproj`, `Base.lproj/{Main,LaunchScreen}.storyboard`,
  `SceneDelegate.swift`, современный `AppDelegate.swift` (Flutter implicit engine).
- **Bundle ID = `kg.sweettime.app`** во всех конфигурациях `project.pbxproj` — совпадает с
  Android и с OAuth-консолью (раньше был placeholder `com.example.sweettime`).
- **Deployment target = iOS 13.0** (`IPHONEOS_DEPLOYMENT_TARGET`), `ENABLE_BITCODE = NO`,
  Swift 5.0. 13.0 совместим со всеми плагинами: `google_sign_in 7`, `mobile_scanner 6`,
  `video_player`, `image_picker`, `flutter_secure_storage` (Keychain).
- **Info.plist**: заданы `NSCameraUsageDescription` (QR + аватар) и
  `NSPhotoLibraryUsageDescription` (выбор аватара). Ориентации: portrait + landscape.
- **Адаптив/safe area**: `SafeArea` используется во всех рискованных для iPhone местах —
  нижние панели действий (`checkout_page.dart:271`, `product_page.dart:250`,
  `cart_page.dart:213`), шапка Home (`home_page.dart:48`). Вырез/Dynamic Island/home
  indicator на уровне вёрстки учтены. Flutter рендерит одинаково на iOS и Android.
- **Доказательная база**: `flutter analyze --no-pub` — чисто; `flutter test --no-pub` —
  89/89 passed (2026-07-21).

Вывод: **сам код и Xcode-конфиг менять под iOS не требуется**. Осталось то, что физически
нельзя сделать на Windows, и то, что зависит от данных владельца.

## 2. Жёсткие блокеры (вне Windows)

| Блокер | Почему | Кто снимает |
|---|---|---|
| Среда сборки **macOS + Xcode** | `flutter build ipa`, CocoaPods (`pod install`), симулятор, подпись, TestFlight — только на Mac | владелец (Mac / облачный CI / аренда) |
| **Apple Developer аккаунт** ($99/год) | подпись, provisioning, TestFlight, App Store | владелец (в процессе оформления) |
| **iOS OAuth-клиент** для Google Sign-In | в консоли есть только Web + Android Debug/Release; без iOS-клиента вход через Google на iPhone падает с `DEVELOPER_ERROR` | владелец создаёт в Google Cloud |

`Podfile` в репозитории **нет** намеренно — Flutter генерирует его при первой сборке
`flutter build ios` на Mac. Хардкодить его на Windows не нужно.

## 3. Google Sign-In на iOS — точные шаги

Проект Google Cloud: `project-1c2e438d-1859-42b3-bc5`, номер `23205820785`.
Web client (`serverClientId`/`aud`) уже используется во Flutter и backend — его НЕ менять.

### 3.1. Владелец создаёт iOS OAuth client (Google Cloud Console)

APIs & Services → Credentials → Create credentials → OAuth client ID → **iOS**:
- Bundle ID: `kg.sweettime.app`
- App Store ID / Team ID можно оставить пустыми до публикации.

Google выдаст **iOS client ID** вида
`23205820785-XXXXXXXX.apps.googleusercontent.com`. Он НЕ секрет.

### 3.2. Правки `ios/Runner/Info.plist` (делаются, когда client ID получен)

Добавить перед закрывающим `</dict>`:

```xml
<!-- iOS OAuth client ID (не секрет). Плагин google_sign_in читает его отсюда,
     если clientId не передан в GoogleSignIn.instance.initialize(). -->
<key>GIDClientID</key>
<string>23205820785-XXXXXXXX.apps.googleusercontent.com</string>

<!-- Callback OAuth: reversed iOS client ID как URL scheme.
     Берётся из iOS client ID: com.googleusercontent.apps.23205820785-XXXXXXXX -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.23205820785-XXXXXXXX</string>
    </array>
  </dict>
</array>
```

Reversed client ID = сегменты iOS client ID до `.apps.googleusercontent.com`,
переставленные: `com.googleusercontent.apps.<та часть, что была перед доменом>`.

### 3.3. Код Flutter

`lib/core/google_identity.dart` сейчас задаёт только `serverClientId` (Web). На iOS плагин
`google_sign_in 7` берёт iOS `clientId` из `GIDClientID` в Info.plist автоматически —
**менять Dart-код не обязательно**, если п. 3.2 выполнен. Web client ID остаётся аудиторией
backend (`aud`), Android/iOS клиенты Google сопоставляет по package/bundle + SHA-1/Bundle ID.

### 3.4. Проверка (на Mac/устройстве)

Вход через Google на iPhone → приложение получает `idToken` → backend `/auth/google`
проверяет подпись, `iss`, `aud == Web client ID`, `exp`, `email_verified`. Клиентские
email/name доказательством не являются (см. CX-018/CL-007).

## 4. Сборка iOS (на Mac или через облачный CI)

Когда появится Mac-среда и Apple аккаунт:

```bash
# на macOS с установленным Xcode + CocoaPods
flutter pub get
cd ios && pod install && cd ..        # сгенерирует Podfile/Podfile.lock
flutter build ipa --release \
  --dart-define=API_BASE=https://<prod-домен> \
  --dart-define=GOOGLE_WEB_CLIENT_ID=23205820785-ap4kgng4fef97ie9l69e5erlufjc8v2i.apps.googleusercontent.com
```

Подпись/провижининг:
- В Xcode → Runner → Signing & Capabilities выбрать Team (Apple Developer), включить
  Automatically manage signing или задать provisioning profile вручную.
- `CODE_SIGN_STYLE` в проекте сейчас `Automatic` — для CI обычно переводят на `Manual` +
  App Store Connect API key.

Без своего Mac рабочий вариант — **облачный CI** (Codemagic / Bitrise / GitHub Actions
macOS runner): собирает `.ipa` и грузит в TestFlight; Apple Developer аккаунт всё равно
обязателен для подписи.

## 5. Осталось для релиза iOS (кроме сборки)

- **Брендированный launch screen**: сейчас `LaunchScreen.storyboard` показывает дефолтный
  Flutter `LaunchImage` (белый фон, центрированная картинка). Для релиза заменить на
  фирменный сплэш SweetTime (иконка/логотип на брендовом фоне).
- **Иконка приложения**: набор `AppIcon.appiconset` присутствует — проверить, что это
  финальные брендовые иконки, а не placeholder (это же требование Task 9 из `docs/TASKS.md`).
- **Legal для App Store**: privacy policy URL, terms, support URL, ссылка на удаление
  аккаунта — те же, что нужны для Google Play (Task 10). App Store Review их требует.
- **App Privacy («Nutrition label»)** в App Store Connect: задекларировать сбор данных
  (email через Google, телефон, фото аватара, история заказов).
- **Скриншоты** под размеры iPhone (6.7" и 6.5"/5.5" по требованиям Apple).

## 6. Рекомендации по коду (опционально, требуют проверки на устройстве)

Эти правки полезны для iPhone, но затрагивают и Android и не проверяемы без устройства —
делать только по согласованию и с последующим QA на реальном iPhone:

- **Стиль статус-бара под тему**: приложение использует прозрачные Scaffold + брендовый фон;
  иконки статус-бара (часы/батарея) на iPhone должны контрастировать. Сейчас overlay style
  задаётся только в `news_story_page.dart`. Можно задать глобально через
  `AnnotatedRegion<SystemUiOverlayStyle>` в `MaterialApp.builder` или
  `appBarTheme.systemOverlayStyle`, синхронизировав со светлой/тёмной темой.
- **Ограничение масштаба текста**: iPhone поддерживает крупный Dynamic Type; для защиты
  вёрстки можно клампить `MediaQuery.textScaler` в builder. Проверить на 320/375/390/430
  и не сломать существующие widget-тесты.

## 7. Чек-лист физического QA на iPhone (когда будет устройство/симулятор)

- [ ] Вырез/Dynamic Island: шапки и контент не перекрыты (Home, Catalog, News, Profile).
- [ ] Home indicator снизу: нижние панели (Cart, Checkout, Product) не налезают.
- [ ] Свайп-назад (edge swipe) работает на push-экранах (товар, checkout, подэкраны профиля).
- [ ] Клавиатура: поля (телефон в Auth, комментарий в Checkout) не перекрываются, скролл ок.
- [ ] Камера/QR (`mobile_scanner`): запрос доступа с нашим текстом, старт/стоп по вкладке Scan,
      фонарь.
- [ ] Выбор аватара (`image_picker`): камера и галерея, запрос доступа с нашим текстом.
- [ ] Google Sign-In: выбор аккаунта → возврат в приложение → backend-сессия.
- [ ] Тёмная/светлая тема: контраст статус-бара и фона.
- [ ] Масштаб текста (Settings → Accessibility → Larger Text): основные действия достижимы.
- [ ] Ширины 320 (SE), 390, 430 (Pro Max): нет горизонтального переполнения.

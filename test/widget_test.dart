import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweettime/core/api_client.dart';
import 'package:sweettime/core/auth_store.dart';
import 'package:sweettime/core/format.dart';
import 'package:sweettime/core/localization/app_localizations.dart';
import 'package:sweettime/core/router.dart';
import 'package:sweettime/core/theme/app_theme.dart';
import 'package:sweettime/main.dart';
import 'package:sweettime/shared/app_models.dart';
import 'package:sweettime/shared/app_state.dart';
import 'package:sweettime/shared/demo_data.dart';

void main() {
  test('dynamic localized content falls back to Russian', () {
    const text = LocalizedText(ru: 'Новости', ky: ' ', en: null);

    expect(text.resolve(AppLanguage.ru), 'Новости');
    expect(text.resolve(AppLanguage.ky), 'Новости');
    expect(text.resolve(AppLanguage.en), 'Новости');
  });

  test('demo company content has complete RU, KG and EN translations', () {
    final values = <LocalizedText>[
      for (final branch in DemoData.branches) ...[branch.name, branch.address],
      for (final category in DemoData.categories) category.name,
      for (final product in DemoData.products) ...[
        product.name,
        product.description,
        for (final size in product.sizes) size.name,
        for (final topping in product.toppings) topping.name,
      ],
      for (final promotion in DemoData.promotions) ...[
        promotion.title,
        promotion.description,
      ],
      for (final story in DemoData.newsStories) ...[
        story.title,
        story.body,
        story.badge,
      ],
    ];

    for (final value in values) {
      expect(value.ru.trim(), isNotEmpty);
      expect(
        value.ky?.trim(),
        isNotEmpty,
        reason: 'Missing KG for ${value.ru}',
      );
      expect(
        value.en?.trim(),
        isNotEmpty,
        reason: 'Missing EN for ${value.ru}',
      );
      expect(
        RegExp(r'[А-Яа-яЁё]').hasMatch(value.resolve(AppLanguage.en)),
        isFalse,
        reason: 'English falls back to Russian for ${value.ru}',
      );
    }
  });

  test('cart selections use stable ids and survive a language change', () {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
    );
    controller.quickAdd(DemoData.products.first);

    final before = controller.state.cart.single;
    controller.setLanguage(AppLanguage.en);
    final after = controller.state.cart.single;
    const strings = AppLocalizations(AppLanguage.en);

    expect(after.sizeId, before.sizeId);
    expect(after.sugarPercent, before.sugarPercent);
    expect(after.ice, before.ice);
    expect(after.toppingIds, before.toppingIds);
    expect(
      strings.cartModifiers(after),
      'M • sugar 50% • regular ice • Tapioca pearls',
    );
  });

  test('money and points follow the selected language', () {
    expect(_regularSpaces(formatSom(1240, AppLanguage.ru)), '1 240 сом');
    expect(_regularSpaces(formatSom(1240, AppLanguage.ky)), '1 240 сом');
    expect(formatSom(1240, AppLanguage.en), 'KGS 1,240');
    expect(formatPoints(1, AppLanguage.ru), '1 балл');
    expect(formatPoints(2, AppLanguage.ru), '2 балла');
    expect(formatPoints(11, AppLanguage.ru), '11 баллов');
    expect(formatPoints(21, AppLanguage.ru), '21 балл');
    expect(formatPoints(1, AppLanguage.ky), '1 упай');
    expect(formatPoints(1, AppLanguage.en), '1 point');
  });

  test('profile identity is user supplied and cleared on logout', () {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
    );
    final birthDate = DateTime(1998, 4, 12);

    controller.login('+996 700 123 456');
    expect(controller.state.userName, isEmpty);

    controller.updateProfile(
      firstName: '  Алина ',
      lastName: ' Садыкова  ',
      birthDate: birthDate,
      avatarPath: 'local-avatar.jpg',
    );

    expect(controller.state.firstName, 'Алина');
    expect(controller.state.lastName, 'Садыкова');
    expect(controller.state.userName, 'Алина Садыкова');
    expect(controller.state.birthDate, birthDate);
    expect(controller.state.avatarPath, 'local-avatar.jpg');

    controller.logout();
    expect(controller.state.isGuest, isTrue);
    expect(controller.state.userName, isEmpty);
    expect(controller.state.birthDate, isNull);
    expect(controller.state.avatarPath, isNull);
    expect(controller.state.userContact, isEmpty);
  });

  test('demo account deletion clears personal and commerce state', () {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
    )..seedDemo(auth: true, cart: true, history: true, recurring: true);

    expect(controller.state.points, greaterThan(0));
    expect(controller.state.favoriteIds, isNotEmpty);
    expect(controller.state.cart, isNotEmpty);
    expect(controller.state.orders, isNotEmpty);
    expect(controller.state.recurring, isNotNull);

    controller.deleteAccount();

    expect(controller.state.isGuest, isTrue);
    expect(controller.state.userName, isEmpty);
    expect(controller.state.userContact, isEmpty);
    expect(controller.state.points, 0);
    expect(controller.state.favoriteIds, isEmpty);
    expect(controller.state.cart, isEmpty);
    expect(controller.state.orders, isEmpty);
    expect(controller.state.pointEvents, isEmpty);
    expect(controller.state.recurring, isNull);
  });

  test(
    'guest checkout and API submission are rejected without cart loss',
    () async {
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
      )..seedDemo(cart: true);

      final created = await controller.submitOrder(
        type: OrderType.pickup,
        readyTime: 'as soon as possible',
        items: controller.state.cart,
        branch: controller.state.selectedBranch,
        total: controller.state.total,
        pointsUsed: 0,
      );

      final order = controller.checkout(
        type: OrderType.pickup,
        readyTime: const OrderReadyTime(kind: OrderReadyTimeKind.asap),
        paymentMethod: PaymentMethod.mock,
      );

      expect(created, isNull);
      expect(order, isNull);
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.cart, isNotEmpty);
      expect(controller.state.orders, isEmpty);
    },
  );

  test('saved token restores the server session and profile on start', () async {
    final authStore = _MemoryAuthStore(
      accessToken: 'good',
      refreshToken: 'fresh',
    );
    final api = _FakeAuthApiClient(
      profile: CustomerProfile(
        id: 'c-sw-aigerim',
        phone: '+996 555 123 456',
        firstName: 'Айгерим',
        lastName: 'Осмонова',
        birthDate: DateTime(1998, 3, 14),
        points: 1240,
        referralCode: 'SWEET-AIGERIM',
        invitedByCode: null,
      ),
    );
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: authStore,
      api: api,
    );

    expect(controller.state.isGuest, isTrue);
    await controller.bootstrap();

    // Личные данные приходят с сервера, а не из локального стейта.
    expect(api.customerMeCalls, ['good']);
    expect(controller.state.isGuest, isFalse);
    expect(controller.state.firstName, 'Айгерим');
    expect(controller.state.lastName, 'Осмонова');
    expect(controller.state.birthDate, DateTime(1998, 3, 14));
    expect(controller.state.points, 1240);
    expect(controller.state.userContact, '+996 555 123 456');
  });

  test('rejected token is cleared and the user stays a guest', () async {
    final authStore = _MemoryAuthStore(accessToken: 'stale');
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: authStore,
      api: _FakeAuthApiClient(
        profile: const CustomerProfile(
          id: 'c-sw-aigerim',
          phone: '+996 555 123 456',
          firstName: '',
          lastName: '',
          birthDate: null,
          points: 0,
          referralCode: null,
          invitedByCode: null,
        ),
      ),
    );

    await controller.bootstrap();

    expect(controller.state.isGuest, isTrue);
    expect(authStore.accessToken, isNull);
    expect(authStore.refreshToken, isNull);
  });

  test('OTP sign-in stores tokens and logout clears them', () async {
    final authStore = _MemoryAuthStore();
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: authStore,
      api: _FakeAuthApiClient(
        profile: const CustomerProfile(
          id: 'c-sw-aigerim',
          phone: '+996 555 123 456',
          firstName: 'Айгерим',
          lastName: '',
          birthDate: null,
          points: 1240,
          referralCode: 'SWEET-AIGERIM',
          invitedByCode: null,
        ),
      ),
    );

    expect(await controller.loginWithOtp('+996555123456', '9999'), isFalse);
    expect(controller.state.isGuest, isTrue);
    expect(authStore.accessToken, isNull);

    expect(await controller.loginWithOtp('+996555123456', '1111'), isTrue);
    expect(controller.state.isGuest, isFalse);
    expect(controller.state.points, 1240);
    expect(authStore.accessToken, 'good');
    expect(authStore.refreshToken, 'fresh');

    controller.logout();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.isGuest, isTrue);
    expect(authStore.accessToken, isNull);
    expect(authStore.refreshToken, isNull);
    expect(authStore.clearCount, 1);
  });

  testWidgets('AppTheme memoizes light and dark themes for the same accent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 900));

    final firstLight = AppTheme.light(AppColors.candy500);
    final secondLight = AppTheme.light(AppColors.candy500);
    final firstDark = AppTheme.dark(AppColors.candy500);
    final secondDark = AppTheme.dark(AppColors.candy500);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(identical(firstLight, secondLight), isTrue);
    expect(identical(firstDark, secondDark), isTrue);
    expect(identical(firstLight, firstDark), isFalse);
    expect(materialApp.themeAnimationDuration, Duration.zero);
  });

  testWidgets('SweetTime app renders home shell', (WidgetTester tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Главная'), findsOneWidget);
    expect(find.text('Каталог'), findsOneWidget);
    expect(find.text('Корзина'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
    expect(find.text('Категории'), findsNothing);
    await _scrollToText(tester, 'Узнайте, что у нас нового');
    expect(find.text('Узнайте, что у нас нового'), findsOneWidget);
  });

  testWidgets('bottom navigation uses filled inactive icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 900));

    final destinations = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .toList();
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );

    expect(destinations, hasLength(5));
    expect(navigationBar.animationDuration, const Duration(milliseconds: 200));
    expect(
      destinations.map((destination) => _navigationIcon(destination.icon)),
      [
        Icons.home_rounded,
        Icons.local_cafe_rounded,
        Icons.qr_code_2,
        Icons.shopping_bag_rounded,
        Icons.person_rounded,
      ],
    );
    expect(
      destinations.map(
        (destination) => _navigationIcon(destination.selectedIcon!),
      ),
      [
        Icons.home_rounded,
        Icons.local_cafe_rounded,
        Icons.qr_code_2,
        Icons.shopping_bag_rounded,
        Icons.person_rounded,
      ],
    );
  });

  testWidgets('guest profile uses compact language and theme actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Профиль');

    expect(find.byType(SegmentedButton<AppLanguage>), findsNothing);
    expect(find.text('Язык приложения'), findsNothing);
    expect(find.byType(PopupMenuButton<AppLanguage>), findsOneWidget);
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });

  testWidgets('language selector switches RU, KG and EN', (
    WidgetTester tester,
  ) async {
    final preferences = _MemoryLanguagePreferenceStore();
    await tester.pumpWidget(_testApp(preferences));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Профиль');
    await tester.tap(find.byType(PopupMenuButton<AppLanguage>));
    await tester.pumpAndSettle();
    await _selectLanguage(tester, 'Кыргызча');
    expect(find.text('Башкы бет'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<AppLanguage>));
    await tester.pumpAndSettle();
    await _selectLanguage(tester, 'English');
    expect(find.text('Home'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(preferences.code, 'en');
  });

  testWidgets('news story opens from home', (WidgetTester tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Главная');
    await _scrollToText(tester, 'Новый вкус недели');
    await tester.tap(find.text('Новый вкус недели'));
    await tester.pumpAndSettle();
    expect(find.text('Новый вкус недели'), findsOneWidget);
    expect(
      find.text(
        'Попробуйте клубничный улун с воздушной сырной пенкой — только до воскресенья.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('English catalog, cart and checkout have localized content', (
    WidgetTester tester,
  ) async {
    final controller =
        AppStateController(
            languagePreferences: _MemoryLanguagePreferenceStore(),
          )
          ..setLanguage(AppLanguage.en)
          ..seedDemo(auth: true, cart: true);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Catalog');
    expect(find.text('Milk tea'), findsOneWidget);
    expect(find.text('Pink Moon milk tea'), findsOneWidget);
    expect(find.text('Add to cart'), findsWidgets);

    await _openNavigationTab(tester, 'Cart');
    expect(find.text('Summary'), findsOneWidget);
    expect(find.textContaining('sugar 50%'), findsOneWidget);
    expect(find.textContaining('Tapioca pearls'), findsOneWidget);

    await tester.tap(find.textContaining('Checkout').last);
    await tester.pumpAndSettle();
    expect(find.text('Fulfillment method'), findsOneWidget);
    await _scrollToText(tester, 'Demo payment');
    expect(find.text('Demo payment'), findsOneWidget);
    await _scrollToText(tester, 'Comment');
    expect(find.text('Comment'), findsOneWidget);
    expect(find.textContaining('Пожелания бариста'), findsNothing);
  });

  testWidgets(
    'guest signs in with a bounded Kyrgyz phone and returns to checkout',
    (WidgetTester tester) async {
      // Сервер недоступен: проверяем автономный демо-вход (APK без API).
      final controller =
          AppStateController(
              languagePreferences: _MemoryLanguagePreferenceStore(),
              authStore: _MemoryAuthStore(),
              api: _OfflineApiClient(),
            )
            ..setLanguage(AppLanguage.en)
            ..seedDemo(cart: true);
      await tester.pumpWidget(_testAppWithController(controller));
      await tester.pump(const Duration(milliseconds: 900));

      await _openNavigationTab(tester, 'Cart');
      await tester.tap(find.textContaining('Checkout').last);
      await tester.pumpAndSettle();

      expect(find.text('Sign in or register'), findsOneWidget);
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(
        find.text(
          'Google sign-in is not available yet. OAuth must be configured for the app and backend.',
        ),
        findsOneWidget,
      );
      expect(controller.state.isGuest, isTrue);
      expect(find.text('SMS code'), findsNothing);

      final phoneField = find.byType(TextField).first;
      await tester.enterText(phoneField, '+996 708 381 382 999');
      expect(
        tester.widget<TextField>(phoneField).controller!.text,
        '708 381 382',
      );
      await tester.enterText(phoneField, '0708 381 382');
      expect(
        tester.widget<TextField>(phoneField).controller!.text,
        '708 381 382',
      );

      await tester.tap(find.text('Get code'));
      await tester.pumpAndSettle();
      expect(find.text('SMS code'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        DemoData.demoOtpCode,
      );
      await tester.tap(find.text('Confirm and sign in'));
      await tester.pumpAndSettle();

      expect(controller.state.isGuest, isFalse);
      expect(controller.state.userContact, '+996708381382');
      expect(controller.state.cart, isNotEmpty);
      expect(find.text('Fulfillment method'), findsOneWidget);
    },
  );

  testWidgets('guest direct checkout route is redirected to auth', (
    WidgetTester tester,
  ) async {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
    )..seedDemo(cart: true);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    appRouter.go('/checkout');
    await tester.pumpAndSettle();

    expect(find.text('Войдите или зарегистрируйтесь'), findsOneWidget);
    expect(controller.state.pendingAuthReturn, AuthReturnDestination.checkout);
    expect(controller.state.cart, isNotEmpty);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Корзина'), findsWidgets);
    expect(controller.state.pendingAuthReturn, isNull);
    expect(controller.state.cart, isNotEmpty);
  });

  testWidgets('Kyrgyz cart localizes product and modifier content', (
    WidgetTester tester,
  ) async {
    final controller =
        AppStateController(
            languagePreferences: _MemoryLanguagePreferenceStore(),
          )
          ..setLanguage(AppLanguage.ky)
          ..seedDemo(cart: true);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Себет');
    expect(find.text('Себет'), findsWidgets);
    expect(find.text('Кызгылт ай сүттүү чайы'), findsOneWidget);
    expect(find.textContaining('кант 50%'), findsOneWidget);
    expect(find.textContaining('Тапиока шариктери'), findsOneWidget);
  });

  testWidgets('English authenticated profile localizes all major sections', (
    WidgetTester tester,
  ) async {
    final controller =
        AppStateController(
            languagePreferences: _MemoryLanguagePreferenceStore(),
          )
          ..setLanguage(AppLanguage.en)
          ..seedDemo(auth: true, history: true, recurring: true);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Profile');
    expect(find.text(DemoData.demoUserFirstName), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);

    await tester.tap(find.text('Points'));
    await tester.pumpAndSettle();
    expect(find.text('Bonus balance'), findsOneWidget);
    expect(find.text('How points work'), findsOneWidget);
    expect(find.text('Invite a friend'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _scrollToText(tester, 'Recurring order');
    expect(find.text('Recurring order'), findsOneWidget);
    await _scrollToText(tester, 'Order history');
    expect(find.text('Order history'), findsOneWidget);
    await _scrollToText(tester, 'Addresses');
    expect(find.text('Addresses'), findsOneWidget);
    expect(find.text('Favorite drinks'), findsNothing);
    await _scrollToText(tester, 'Help and account');
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('Questions and answers'), findsOneWidget);
    await _scrollToText(tester, 'Sign out');
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.textContaining('История заказов'), findsNothing);
  });

  testWidgets('profile editor saves customer name without opening picker', (
    WidgetTester tester,
  ) async {
    final controller =
        AppStateController(
            languagePreferences: _MemoryLanguagePreferenceStore(),
          )
          ..setLanguage(AppLanguage.en)
          ..seedDemo(auth: true);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Profile');
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Birth date'), findsOneWidget);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'Mira');
    await tester.enterText(fields.at(1), 'Asan');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(controller.state.firstName, 'Mira');
    expect(controller.state.lastName, 'Asan');
    expect(find.text('Mira Asan'), findsOneWidget);
  });

  testWidgets('support and FAQ routes use honest localized content', (
    WidgetTester tester,
  ) async {
    final controller =
        AppStateController(
            languagePreferences: _MemoryLanguagePreferenceStore(),
          )
          ..setLanguage(AppLanguage.en)
          ..seedDemo(auth: true);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Profile');
    await _scrollToText(tester, 'Contact support');
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    expect(find.text('Support is currently in demo mode'), findsOneWidget);
    expect(find.text('Available after setup'), findsNWidgets(2));

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _scrollToText(tester, 'Questions and answers');
    await tester.tap(find.text('Questions and answers'));
    await tester.pumpAndSettle();
    expect(find.text('How do I earn and spend points?'), findsOneWidget);
    expect(find.text('What is the QR code for?'), findsOneWidget);
  });

  testWidgets('guest cannot open protected profile data routes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 900));

    appRouter.go('/profile/loyalty');
    await tester.pumpAndSettle();
    expect(find.text('Войдите в аккаунт'), findsOneWidget);
    expect(find.text('Бонусный баланс'), findsNothing);

    appRouter.go('/profile/edit');
    await tester.pumpAndSettle();
    expect(find.text('Войдите в аккаунт'), findsOneWidget);
    expect(find.text('Редактирование профиля'), findsNothing);
  });

  testWidgets('Kyrgyz profile and loyalty routes use localized copy', (
    WidgetTester tester,
  ) async {
    final controller =
        AppStateController(
            languagePreferences: _MemoryLanguagePreferenceStore(),
          )
          ..setLanguage(AppLanguage.ky)
          ..seedDemo(auth: true);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Профиль');
    expect(find.text('Өзгөртүү'), findsOneWidget);
    expect(find.text('Упайлар'), findsOneWidget);
    await tester.tap(find.text('Упайлар'));
    await tester.pumpAndSettle();
    expect(find.text('Бонустук баланс'), findsOneWidget);
    expect(find.text('Упайлар кандай иштейт'), findsOneWidget);
    expect(find.text('Досуңузду чакырыңыз'), findsOneWidget);
  });

  testWidgets('catalog favorites filter updates as hearts are toggled', (
    WidgetTester tester,
  ) async {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
    )..setLanguage(AppLanguage.en);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Catalog');
    final favoritesChipFinder = find.widgetWithText(FilterChip, 'Favorites');
    var favoritesChip = tester.widget<FilterChip>(favoritesChipFinder);
    expect((favoritesChip.avatar! as Icon).icon, Icons.favorite);
    expect(favoritesChip.showCheckmark, isFalse);

    await tester.tap(favoritesChipFinder);
    await tester.pumpAndSettle();
    favoritesChip = tester.widget<FilterChip>(favoritesChipFinder);
    expect(favoritesChip.selected, isTrue);
    expect((favoritesChip.avatar! as Icon).icon, Icons.favorite);
    expect(favoritesChip.showCheckmark, isFalse);

    expect(find.text('Pink Moon milk tea'), findsOneWidget);
    expect(find.text('Matcha Mint Cloud'), findsNothing);
    await tester.tap(find.byTooltip('Remove from favourites').first);
    await tester.pumpAndSettle();
    expect(find.text('Pink Moon milk tea'), findsNothing);
  });

  testWidgets('catalog categories support independent multi-select', (
    WidgetTester tester,
  ) async {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
    )..setLanguage(AppLanguage.en);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Catalog');
    final milkFinder = find.widgetWithText(FilterChip, 'Milk tea');
    final fruitFinder = find.widgetWithText(FilterChip, 'Fruit tea');
    final allFinder = find.widgetWithText(ChoiceChip, 'All');

    await tester.tap(milkFinder);
    await tester.pumpAndSettle();
    await tester.tap(fruitFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<FilterChip>(milkFinder).selected, isTrue);
    expect(tester.widget<FilterChip>(fruitFinder).selected, isTrue);
    expect(tester.widget<ChoiceChip>(allFinder).selected, isFalse);

    await tester.tap(allFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(milkFinder).selected, isFalse);
    expect(tester.widget<FilterChip>(fruitFinder).selected, isFalse);
    expect(tester.widget<ChoiceChip>(allFinder).selected, isTrue);
  });
}

String _regularSpaces(String value) =>
    value.replaceAll('\u00a0', ' ').replaceAll('\u202f', ' ');

IconData? _navigationIcon(Widget widget) {
  if (widget is Icon) return widget.icon;
  if (widget is Badge && widget.child is Icon) {
    return (widget.child! as Icon).icon;
  }
  return null;
}

Future<void> _openNavigationTab(WidgetTester tester, String label) async {
  final destination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
  expect(destination, findsOneWidget);
  await tester.tap(destination);
  await tester.pumpAndSettle();
}

Future<void> _selectLanguage(WidgetTester tester, String nativeName) async {
  final item = find.ancestor(
    of: find.text(nativeName),
    matching: find.byType(CheckedPopupMenuItem<AppLanguage>),
  );
  expect(item, findsOneWidget);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> _scrollToText(
  WidgetTester tester,
  String text, {
  double delta = 260,
}) async {
  await tester.scrollUntilVisible(
    find.text(text),
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Widget _testApp([LanguagePreferenceStore? preferences]) {
  appRouter.go('/');
  final store = preferences ?? _MemoryLanguagePreferenceStore();
  return ProviderScope(
    overrides: [
      appStateProvider.overrideWith(
        (ref) => AppStateController(languagePreferences: store),
      ),
    ],
    child: const SweetTimeApp(),
  );
}

Widget _testAppWithController(AppStateController controller) {
  appRouter.go('/');
  return ProviderScope(
    overrides: [appStateProvider.overrideWith((ref) => controller)],
    child: const SweetTimeApp(),
  );
}

/// Токены в памяти: платформенных каналов (Keystore/Keychain) в тестах нет.
class _MemoryAuthStore implements AuthStore {
  _MemoryAuthStore({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;
  int clearCount = 0;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    accessToken = null;
    refreshToken = null;
  }
}

/// API недоступен: все запросы отвечают как офлайн.
/// Даёт детерминированность — тест не зависит от того, поднят ли реальный :8010.
class _OfflineApiClient extends ApiClient {
  @override
  Future<CompanyConfig?> fetchConfig() async => null;

  @override
  Future<ApiResult<CustomerSession>> otpVerify(String phone, String code) async
  => const ApiResult<CustomerSession>.unavailable();

  @override
  Future<ApiResult<CustomerProfile>> fetchCustomerMe(String accessToken) async
  => const ApiResult<CustomerProfile>.unavailable();

  @override
  Future<bool> otpRequest(String phone) async => false;
}

/// Сервер с одним известным клиентом: access-токен `good`, refresh `fresh`.
class _FakeAuthApiClient extends ApiClient {
  _FakeAuthApiClient({required this.profile});

  final CustomerProfile profile;
  final List<String> customerMeCalls = [];

  @override
  Future<CompanyConfig?> fetchConfig() async => null;

  @override
  Future<ApiResult<CustomerProfile>> fetchCustomerMe(String accessToken) async {
    customerMeCalls.add(accessToken);
    if (accessToken != 'good') {
      return const ApiResult<CustomerProfile>.rejected();
    }
    return ApiResult<CustomerProfile>.ok(profile);
  }

  @override
  Future<ApiResult<CustomerSession>> otpVerify(String phone, String code) async {
    if (code != '1111') return const ApiResult<CustomerSession>.rejected();
    return ApiResult<CustomerSession>.ok(
      CustomerSession(
        tokens: const TokenPair(accessToken: 'good', refreshToken: 'fresh'),
        profile: profile,
      ),
    );
  }
}

class _MemoryLanguagePreferenceStore implements LanguagePreferenceStore {
  String? code;
  String? themeMode;

  @override
  Future<String?> readLanguageCode() async => code;

  @override
  Future<void> writeLanguageCode(String code) async {
    this.code = code;
  }

  @override
  Future<String?> readThemeMode() async => themeMode;

  @override
  Future<void> writeThemeMode(String value) async {
    themeMode = value;
  }
}

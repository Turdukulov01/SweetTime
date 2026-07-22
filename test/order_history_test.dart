import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweettime/core/api_client.dart';
import 'package:sweettime/core/auth_store.dart';
import 'package:sweettime/core/cart_store.dart';
import 'package:sweettime/core/google_identity.dart';
import 'package:sweettime/core/localization/app_localizations.dart';
import 'package:sweettime/core/order_history_store.dart';
import 'package:sweettime/core/theme/app_theme.dart';
import 'package:sweettime/features/profile/order_history_page.dart';
import 'package:sweettime/features/profile/profile_page.dart';
import 'package:sweettime/shared/app_models.dart';
import 'package:sweettime/shared/app_state.dart';

void main() {
  test('hidden order ids are cleared from memory on sign-out', () async {
    final visibilityStore = _MemoryOrderHistoryStore();
    final controller = _controller(visibilityStore)
      ..seedDemo(auth: true, history: true);
    final hiddenId = controller.state.orders.first.id;

    await controller.hideOrdersOnDevice([hiddenId]);
    expect(
      controller.state.visibleOrders.map((order) => order.id),
      isNot(contains(hiddenId)),
    );
    expect(visibilityStore.ids, contains(hiddenId));

    controller.logout();
    expect(controller.state.hiddenOrderIds, isEmpty);
  });

  test('account deletion clears locally hidden order ids', () async {
    final visibilityStore = _MemoryOrderHistoryStore();
    final controller = _controller(visibilityStore)
      ..seedDemo(auth: true, history: true);
    await controller.hideOrdersOnDevice([controller.state.orders.first.id]);

    expect(await controller.deleteAccount(), AccountDeletionResult.success);
    expect(controller.state.hiddenOrderIds, isEmpty);
    expect(visibilityStore.clearCalls, 1);
    expect(visibilityStore.ids, isEmpty);
  });

  test('order parser keeps immutable order and product snapshots', () {
    final order = parseCustomerOrderHistoryEntry({
      'id': 'o-future',
      'number': 'SW-3001',
      'branchId': 'b1',
      'branchName': 'SweetTime Center',
      'branchAddress': '123 Chuy Avenue',
      'customerPhone': '+996 700 123 456',
      'type': 'pickup',
      'status': 'preparing',
      'readyTime': 'asap',
      'itemsVersion': 2,
      'items': [
        {
          'productId': 'removed-product',
          'productName': 'Snapshot drink',
          'productDescription': 'Snapshot description',
          'imageUrl': 'https://cdn.example/drink.webp',
          'sizeId': 'm',
          'sizeName': 'Medium',
          'toppingIds': ['pearls'],
          'toppings': [
            {'id': 'pearls', 'name': 'Pearls', 'priceDelta': 50},
          ],
          'sugarPercent': 50,
          'ice': 'regular',
          'unitPrice': 320,
          'quantity': 1,
          'total': 320,
        },
      ],
      'total': 320,
      'paymentMethod': 'cash',
      'pointsUsed': 0,
      'pointsEarned': 16,
      'createdAt': '2026-07-16T10:00:00Z',
      'comment': 'Less ice',
    });

    expect(order?.comment, 'Less ice');
    expect(order?.customerPhone, '+996 700 123 456');
    expect(order?.branchName, 'SweetTime Center');
    expect(order?.branchAddress, '123 Chuy Avenue');
    expect(order?.items.single.imageUrl, 'https://cdn.example/drink.webp');
    expect(
      order?.items.single.productDescription?.resolve(AppLanguage.en),
      'Snapshot description',
    );
    expect(order?.items.single.toppings?.single.id, 'pearls');
    expect(order?.items.single.toppings?.single.priceDelta, 50);
  });

  test('order parser accepts backend snapshots with pending translations', () {
    final order = parseCustomerOrderHistoryEntry({
      'id': 'o-partial-locales',
      'number': 'SW-3002',
      'branchId': 'b1',
      'type': 'pickup',
      'status': 'new',
      'readyTime': 'asap',
      'itemsVersion': 2,
      'items': [
        {
          'productId': 'strawberry-jam',
          'productName': {
            'ru': 'Клубничный джем',
            'ky': null,
            'en': '',
          },
          'productDescription': null,
          'sizeId': 's',
          'size': {'ru': 'Маленький', 'ky': null, 'en': null},
          'toppingIds': ['pearls'],
          'toppings': [
            {
              'id': 'pearls',
              'name': {'ru': 'Тапиока', 'ky': null, 'en': null},
              'priceDelta': 40,
            },
          ],
          'sugarPercent': 50,
          'ice': 'regular',
          'unitPrice': 3000,
          'quantity': 1,
          'total': 3000,
        },
      ],
      'total': 3000,
      'paymentMethod': 'mock',
      'pointsUsed': 0,
      'pointsEarned': 150,
      'createdAt': '2026-07-21T09:30:00Z',
    });

    expect(order, isNotNull);
    expect(
      order!.items.single.productName.resolve(AppLanguage.ky),
      'Клубничный джем',
    );
    expect(
      order.items.single.productName.resolve(AppLanguage.en),
      'Клубничный джем',
    );
    expect(
      order.items.single.toppings!.single.name.resolve(AppLanguage.en),
      'Тапиока',
    );
  });

  testWidgets('profile shows one compact order-history entry', (tester) async {
    final controller = _controller(_MemoryOrderHistoryStore())
      ..seedDemo(auth: true, history: true)
      ..setLanguage(AppLanguage.en);
    await _pump(tester, controller, const ProfilePage());

    expect(
      find.byKey(const ValueKey('profile-order-history-entry')),
      findsOneWidget,
    );
    expect(find.text('Order history'), findsOneWidget);
    expect(find.text('SW-1048'), findsNothing);
    expect(find.text('SW-1031'), findsNothing);
  });

  testWidgets(
    'order detail is large, scrollable and closes with Android back',
    (tester) async {
      final controller = _controller(_MemoryOrderHistoryStore())
        ..seedDemo(auth: true, history: true)
        ..setLanguage(AppLanguage.en);
      await _pump(tester, controller, const OrderHistoryPage());

      await tester.tap(find.byKey(const ValueKey('order-SW-1048')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order-detail-sheet')), findsOneWidget);
      expect(find.text('Order details'), findsOneWidget);
      expect(find.text('Pink Moon milk tea'), findsOneWidget);
      expect(find.textContaining('Creamy strawberry oolong'), findsOneWidget);
      expect(find.text('Quantity: 1'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order-detail-sheet')), findsNothing);
      expect(find.byKey(const ValueKey('order-SW-1048')), findsOneWidget);
    },
  );

  testWidgets('selection back, select all and local hide work', (tester) async {
    final visibilityStore = _MemoryOrderHistoryStore();
    final controller = _controller(visibilityStore)
      ..seedDemo(auth: true, history: true)
      ..setLanguage(AppLanguage.en);
    await _pump(tester, controller, const OrderHistoryPage());

    await tester.tap(find.byKey(const ValueKey('manage-order-history')));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('manage-order-history')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('manage-order-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hide-selected-orders')));
    await tester.pumpAndSettle();
    expect(find.textContaining('hidden only on this device'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(controller.state.visibleOrders, isEmpty);
    expect(visibilityStore.ids, hasLength(2));
    expect(find.text('No orders yet'), findsOneWidget);
  });
}

AppStateController _controller(_MemoryOrderHistoryStore visibilityStore) {
  return AppStateController(
    api: _OfflineApiClient(),
    languagePreferences: _MemoryPreferences(),
    authStore: _MemoryAuthStore(),
    cartStore: _MemoryCartStore(),
    googleIdentity: _MemoryGoogleIdentity(),
    orderHistoryVisibilityStore: visibilityStore,
  );
}

Future<void> _pump(
  WidgetTester tester,
  AppStateController controller,
  Widget home,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appStateProvider.overrideWith((ref) => controller)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: [
          for (final language in AppLanguage.values) language.locale,
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryOrderHistoryStore implements OrderHistoryVisibilityStore {
  final Map<String, Set<String>> _idsByAccount = {};
  int clearCalls = 0;

  Set<String> get ids => _idsByAccount.values.expand((ids) => ids).toSet();

  @override
  Future<void> clear(String accountId) async {
    clearCalls++;
    _idsByAccount.remove(accountId);
  }

  @override
  Future<Set<String>> readHiddenOrderIds(String accountId) async =>
      Set.unmodifiable(_idsByAccount[accountId] ?? const {});

  @override
  Future<void> writeHiddenOrderIds(String accountId, Set<String> ids) async {
    _idsByAccount[accountId] = Set.of(ids);
  }
}

class _MemoryPreferences implements LanguagePreferenceStore {
  @override
  Future<String?> readLanguageCode() async => 'en';

  @override
  Future<String?> readThemeMode() async => null;

  @override
  Future<void> writeLanguageCode(String code) async {}

  @override
  Future<void> writeThemeMode(String value) async {}

  @override
  Future<String?> readBackgroundOverride() async => null;

  @override
  Future<void> writeBackgroundOverride(String? value) async {}
}

class _MemoryAuthStore implements AuthStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

class _MemoryCartStore implements CartStore {
  @override
  Future<List<CartDraftItem>> read() async => const [];

  @override
  Future<void> write(List<CartDraftItem> items) async {}
}

class _MemoryGoogleIdentity implements GoogleIdentityProvider {
  @override
  bool get isConfigured => true;

  @override
  Future<GoogleIdentityResult> authenticate() async =>
      const GoogleIdentityResult.cancelled();

  @override
  Future<void> signOut() async {}
}

class _OfflineApiClient extends ApiClient {
  @override
  Future<CompanyConfig?> fetchConfig() async => null;
}

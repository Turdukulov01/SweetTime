import 'dart:async';

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
import 'package:sweettime/shared/app_models.dart';
import 'package:sweettime/shared/app_state.dart';
import 'package:sweettime/shared/demo_data.dart';

void main() {
  test('temporary refresh outage does not clear the saved session', () async {
    final auth = _MemoryAuthStore(
      accessToken: 'expired',
      refreshToken: 'refresh-1',
    );
    final api = _SessionApi()
      ..refreshResult = const ApiResult<TokenPair>.unavailable();
    final controller = _controller(api, auth);

    await controller.bootstrap();

    expect(controller.state.isGuest, isTrue);
    expect(auth.accessToken, 'expired');
    expect(auth.refreshToken, 'refresh-1');
    expect(auth.clearCalls, 0);
    expect(api.refreshCalls, 1);
  });

  test('refresh token alone restores session without Google login', () async {
    final auth = _MemoryAuthStore(refreshToken: 'refresh-1');
    final google = _MemoryGoogleIdentity();
    final api = _SessionApi();
    final controller = _controller(api, auth, google: google);

    await controller.bootstrap();

    expect(controller.state.isGuest, isFalse);
    expect(controller.state.customerId, _profile.id);
    expect(auth.accessToken, 'good-next');
    expect(auth.refreshToken, 'refresh-2');
    expect(api.refreshCalls, 1);
    expect(google.authenticateCalls, 0);
  });

  test('resume and history refresh share one rotating-token request', () async {
    final auth = _MemoryAuthStore(
      accessToken: 'good',
      refreshToken: 'refresh-1',
    );
    final api = _SessionApi();
    final controller = _controller(api, auth);
    await controller.bootstrap();
    expect(controller.state.isGuest, isFalse);

    auth.accessToken = 'expired';
    final gate = Completer<void>();
    api.refreshGate = gate;
    final resume = controller.resumeCustomerSession();
    final history = controller.refreshCustomerOrders();
    await Future<void>.delayed(Duration.zero);

    expect(api.refreshCalls, 1);
    gate.complete();
    expect(await resume, CustomerSessionResumeResult.active);
    expect(await history, CustomerHistoryRefreshResult.success);
    expect(auth.accessToken, 'good-next');
    expect(auth.refreshToken, 'refresh-2');
  });

  test('definitively rejected refresh expires an active session', () async {
    final auth = _MemoryAuthStore(
      accessToken: 'good',
      refreshToken: 'refresh-1',
    );
    final api = _SessionApi();
    final controller = _controller(api, auth);
    await controller.bootstrap();
    expect(controller.state.isGuest, isFalse);

    auth.accessToken = 'expired';
    api.refreshResult = const ApiResult<TokenPair>.rejected();

    expect(
      await controller.resumeCustomerSession(),
      CustomerSessionResumeResult.sessionExpired,
    );
    expect(controller.state.isGuest, isTrue);
    expect(controller.state.orders, isEmpty);
    expect(auth.accessToken, isNull);
    expect(auth.refreshToken, isNull);
  });

  testWidgets(
    'pull refresh preserves old orders on error and retry replaces them',
    (tester) async {
      final oldOrder = _order('SW-old');
      final newOrder = _order('SW-new');
      final auth = _MemoryAuthStore(
        accessToken: 'good',
        refreshToken: 'refresh-1',
      );
      final api = _SessionApi()
        ..ordersResult = ApiResult<List<OrderHistoryEntry>>.ok([oldOrder]);
      final controller = _controller(api, auth);
      await controller.bootstrap();
      api.ordersResult = const ApiResult<List<OrderHistoryEntry>>.unavailable();
      await _pump(tester, controller);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 360));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('order-SW-old')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('order-history-refresh-error')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Could not refresh history. Your last loaded orders are still here.',
        ),
        findsOneWidget,
      );

      api.ordersResult = ApiResult<List<OrderHistoryEntry>>.ok([newOrder]);
      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('order-SW-old')), findsNothing);
      expect(find.byKey(const ValueKey('order-SW-new')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('order-history-refresh-error')),
        findsNothing,
      );
    },
  );

  testWidgets('visible order history polls and keeps pull refresh available', (
    tester,
  ) async {
    final oldOrder = _order('SW-old');
    final newOrder = _order('SW-new');
    final auth = _MemoryAuthStore(
      accessToken: 'good',
      refreshToken: 'refresh-1',
    );
    final api = _SessionApi()
      ..ordersResult = ApiResult<List<OrderHistoryEntry>>.ok([oldOrder]);
    final controller = _controller(api, auth);
    await controller.bootstrap();
    await _pump(tester, controller);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    api.ordersResult = ApiResult<List<OrderHistoryEntry>>.ok([newOrder]);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(find.byKey(const ValueKey('order-SW-old')), findsNothing);
    expect(find.byKey(const ValueKey('order-SW-new')), findsOneWidget);
  });
}

AppStateController _controller(
  _SessionApi api,
  _MemoryAuthStore auth, {
  _MemoryGoogleIdentity? google,
}) {
  return AppStateController(
    api: api,
    authStore: auth,
    cartStore: _MemoryCartStore(),
    languagePreferences: _MemoryPreferences(),
    googleIdentity: google ?? _MemoryGoogleIdentity(),
    orderHistoryVisibilityStore: _MemoryOrderHistoryStore(),
  );
}

Future<void> _pump(WidgetTester tester, AppStateController controller) async {
  controller.setLanguage(AppLanguage.en);
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
        home: const OrderHistoryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _profile = CustomerProfile(
  id: 'customer-1',
  phone: '+996 700 123 456',
  firstName: 'Aigerim',
  lastName: 'Osmonova',
  birthDate: null,
  points: 120,
  referralCode: 'SWEET-1',
  invitedByCode: null,
);

OrderHistoryEntry _order(String id) => OrderHistoryEntry.fromLocal(
  CustomerOrder(
    id: id,
    items: [
      CartItem(
        product: DemoData.products.first,
        quantity: 1,
        sizeId: 'm',
        sugarPercent: 50,
        ice: IceLevel.regular,
        toppingIds: const ['tapioca'],
        total: 400,
      ),
    ],
    branch: DemoData.branches.first,
    type: OrderType.pickup,
    status: OrderStatus.preparing,
    paymentMethod: PaymentMethod.cash,
    readyTime: const OrderReadyTime(kind: OrderReadyTimeKind.asap),
    total: 400,
    pointsUsed: 0,
    pointsEarned: 20,
  ),
);

class _SessionApi extends ApiClient {
  ApiResult<TokenPair> refreshResult = const ApiResult<TokenPair>.ok(
    TokenPair(accessToken: 'good-next', refreshToken: 'refresh-2'),
  );
  ApiResult<List<OrderHistoryEntry>> ordersResult =
      const ApiResult<List<OrderHistoryEntry>>.ok([]);
  Completer<void>? refreshGate;
  int refreshCalls = 0;

  @override
  Future<CompanyConfig?> fetchConfig() async => null;

  @override
  Future<ApiResult<CustomerProfile>> fetchCustomerMe(
    String accessToken,
  ) async => accessToken == 'good' || accessToken == 'good-next'
      ? const ApiResult<CustomerProfile>.ok(_profile)
      : const ApiResult<CustomerProfile>.rejected();

  @override
  Future<ApiResult<List<String>>> fetchCustomerFavorites(
    String accessToken,
  ) async => const ApiResult<List<String>>.ok([]);

  @override
  Future<ApiResult<List<OrderHistoryEntry>>> fetchCustomerOrders(
    String accessToken,
  ) async => accessToken == 'good' || accessToken == 'good-next'
      ? ordersResult
      : const ApiResult<List<OrderHistoryEntry>>.rejected();

  @override
  Future<ApiResult<RecurringOrder?>> fetchCustomerRecurring(
    String accessToken,
  ) async => const ApiResult<RecurringOrder?>.ok(null);

  @override
  Future<ApiResult<List<RecurringOrder>>> fetchCustomerRecurringOrders(
    String accessToken,
  ) async => const ApiResult<List<RecurringOrder>>.ok([]);

  @override
  Future<ApiResult<List<RecurringRefund>>> fetchCustomerRecurringRefunds(
    String accessToken,
  ) async => const ApiResult<List<RecurringRefund>>.ok([]);

  @override
  Future<ApiResult<TokenPair>> refreshTokens(String refreshToken) async {
    refreshCalls++;
    final gate = refreshGate;
    if (gate != null) await gate.future;
    return refreshResult;
  }
}

class _MemoryAuthStore implements AuthStore {
  _MemoryAuthStore({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;
  int clearCalls = 0;

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
    clearCalls++;
    accessToken = null;
    refreshToken = null;
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

class _MemoryCartStore implements CartStore {
  @override
  Future<List<CartDraftItem>> read() async => const [];

  @override
  Future<void> write(List<CartDraftItem> items) async {}
}

class _MemoryGoogleIdentity implements GoogleIdentityProvider {
  int authenticateCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<GoogleIdentityResult> authenticate() async {
    authenticateCalls++;
    return const GoogleIdentityResult.cancelled();
  }

  @override
  Future<void> signOut() async {}
}

class _MemoryOrderHistoryStore implements OrderHistoryVisibilityStore {
  @override
  Future<void> clear(String accountId) async {}

  @override
  Future<Set<String>> readHiddenOrderIds(String accountId) async => const {};

  @override
  Future<void> writeHiddenOrderIds(String accountId, Set<String> ids) async {}
}

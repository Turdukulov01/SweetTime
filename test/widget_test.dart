import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweettime/core/api_client.dart';
import 'package:sweettime/core/auth_store.dart';
import 'package:sweettime/core/cart_store.dart';
import 'package:sweettime/core/format.dart';
import 'package:sweettime/core/google_identity.dart';
import 'package:sweettime/core/localization/app_localizations.dart';
import 'package:sweettime/core/router.dart';
import 'package:sweettime/core/theme/app_theme.dart';
import 'package:sweettime/features/product/product_page.dart';
import 'package:sweettime/main.dart';
import 'package:sweettime/shared/app_models.dart';
import 'package:sweettime/shared/app_state.dart';
import 'package:sweettime/shared/demo_data.dart';

const _testCustomerProfile = CustomerProfile(
  id: 'c-test',
  phone: '+996700123456',
  firstName: 'Test',
  lastName: 'Customer',
  birthDate: null,
  points: 0,
  referralCode: null,
  invitedByCode: null,
);

Map<String, dynamic> _v2OrderJson({
  int itemTotal = 430,
  int orderTotal = 430,
}) => <String, dynamic>{
  'id': 'o-2001',
  'number': 'SW-2001',
  'customerName': 'Test Customer',
  'branchId': DemoData.branches.first.id,
  'type': 'pickup',
  'status': 'preparing',
  'readyTime': 'asap',
  'itemsVersion': 2,
  'items': <Map<String, dynamic>>[
    {
      'productName': {
        'ru': 'Розовая луна с молочным чаем',
        'ky': 'Кызгылт ай сүттүү чайы',
        'en': 'Pink Moon milk tea',
      },
      'size': 'M',
      'quantity': 1,
      'total': itemTotal,
      'productId': DemoData.products.first.id,
      'sizeId': 'm',
      'toppingIds': ['tapioca'],
      'sugarPercent': 50,
      'ice': 'regular',
      'unitPrice': itemTotal,
    },
  ],
  'total': orderTotal,
  'paymentMethod': 'qr',
  'pointsUsed': 0,
  'pointsEarned': 21,
  'createdAt': '2026-07-15T12:00:00Z',
};

Map<String, dynamic> _v1OrderJson() => <String, dynamic>{
  'id': 'o-legacy',
  'number': 'SW-1001',
  'customerName': 'Test Customer',
  'branchId': DemoData.branches.first.id,
  'type': 'pickup',
  'status': 'done',
  'readyTime': 'asap',
  'itemsVersion': 1,
  'items': <Map<String, dynamic>>[
    {
      'productName': DemoData.products.first.name.ru,
      'size': 'M',
      'quantity': 1,
      'total': 400,
    },
  ],
  'total': 400,
  'paymentMethod': 'cash',
  'pointsUsed': 0,
  'pointsEarned': 20,
  'createdAt': '2026-07-01T12:00:00Z',
};

Map<String, dynamic> _recurringJson({String? paidUntil}) => <String, dynamic>{
  'productIds': [DemoData.products.first.id],
  'time': '11:00',
  'branchId': DemoData.branches.first.id,
  'plan': 'week',
  'paidUntil': paidUntil ?? '2026-07-22T12:00:00Z',
  'active': true,
};

void main() {
  test('catalog starting price uses the lowest final size price', () {
    final product = DemoData.products.first;
    final expected = product.sizes
        .map((size) => product.basePrice + size.priceDelta)
        .reduce((left, right) => left < right ? left : right);

    expect(product.startingPrice, expected);
  });

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

  test('quick add reports failure for an unavailable product', () async {
    final original = DemoData.products.first;
    final unavailable = Product(
      id: original.id,
      category: original.category,
      name: original.name,
      description: original.description,
      basePrice: original.basePrice,
      accentColor: original.accentColor,
      rating: original.rating,
      reviewsCount: original.reviewsCount,
      sizes: original.sizes,
      toppings: original.toppings,
      availableBranchIds: const [],
      assetImage: original.assetImage,
      isNew: original.isNew,
      isBestSeller: original.isBestSeller,
    );
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      cartStore: _MemoryCartStore(),
      api: _OfflineApiClient(),
    );

    expect(await controller.quickAdd(unavailable), isFalse);
    expect(controller.state.cart, isEmpty);
  });

  test('order submission uses stable ids independent of language', () async {
    final api = _CapturingOrderApiClient();
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(accessToken: 'good'),
      cartStore: _MemoryCartStore(),
      api: api,
    );
    await controller.bootstrap();
    controller.login('+996700123456');
    final product = DemoData.products.first;
    final item = CartItem(
      product: product,
      quantity: 2,
      sizeId: 'm',
      sugarPercent: 50,
      ice: IceLevel.regular,
      toppingIds: const ['tapioca'],
      total: 800,
    );

    for (final language in [AppLanguage.ru, AppLanguage.en]) {
      controller.setLanguage(language);
      await controller.submitOrder(
        clientRequestId: 'stable-order-request',
        type: OrderType.pickup,
        readyTime: 'asap',
        items: [item],
        branch: DemoData.branches.first,
        pointsUsed: 0,
        comment: 'Без трубочки',
        paymentMethod: PaymentMethod.qrDemo,
      );
    }

    expect(api.requests, hasLength(2));
    expect(api.requests[0], api.requests[1]);
    final request = api.requests.first;
    expect(request['paymentMethod'], 'qr');
    expect(request['readyTime'], 'asap');
    expect(request['comment'], 'Без трубочки');
    expect(request['items'], [
      {
        'productId': product.id,
        'sizeId': 'm',
        'toppingIds': ['tapioca'],
        'sugarPercent': 50,
        'ice': 'regular',
        'quantity': 2,
      },
    ]);
    final encodedItem = (request['items']! as List).single as Map;
    expect(encodedItem, isNot(contains('productName')));
    expect(encodedItem, isNot(contains('total')));
  });

  test('a product without sizes is submitted with a null sizeId', () async {
    final original = DemoData.products.first;
    final product = Product(
      id: original.id,
      category: original.category,
      name: original.name,
      description: original.description,
      basePrice: original.basePrice,
      accentColor: original.accentColor,
      rating: original.rating,
      reviewsCount: original.reviewsCount,
      sizes: const [],
      toppings: const [],
      availableBranchIds: original.availableBranchIds,
      assetImage: original.assetImage,
      isNew: original.isNew,
      isBestSeller: original.isBestSeller,
    );
    final api = _CapturingOrderApiClient(products: [product]);
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(accessToken: 'good'),
      cartStore: _MemoryCartStore(),
      api: api,
    );
    await controller.bootstrap();
    controller.login('+996700123456');

    expect(await controller.quickAdd(controller.state.products.single), isTrue);
    expect(controller.state.cart.single.sizeId, isNull);

    final result = await controller.submitOrder(
      clientRequestId: 'no-size-order-request',
      type: OrderType.pickup,
      readyTime: 'asap',
      items: controller.state.cart,
      branch: controller.state.selectedBranch,
      pointsUsed: 0,
    );

    expect(result.isOk, isTrue);
    final encodedItem = (api.requests.single['items']! as List).single as Map;
    expect(encodedItem['sizeId'], isNull);
  });

  test(
    'failed server order keeps cart and never invents local history',
    () async {
      final api = _CapturingOrderApiClient(
        orderResult: const ApiResult<CreatedOrder>.unavailable(),
      );
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(accessToken: 'good'),
        cartStore: _MemoryCartStore(),
        api: api,
      );
      await controller.bootstrap();
      controller.login('+996700123456');
      await controller.quickAdd(controller.state.products.first);
      final cart = controller.state.cart;

      final result = await controller.submitOrder(
        clientRequestId: 'failed-order-request',
        type: OrderType.pickup,
        readyTime: 'asap',
        items: cart,
        branch: controller.state.selectedBranch,
        pointsUsed: 0,
      );

      expect(result.isOk, isFalse);
      expect(controller.state.cart, cart);
      expect(controller.state.orders, isEmpty);
    },
  );

  test('committed order appears in history before a follow-up fetch', () async {
    final historyEntry = parseCustomerOrderHistoryEntry(_v2OrderJson())!;
    final api = _CapturingOrderApiClient(
      orderResult: ApiResult<CreatedOrder>.ok(
        CreatedOrder(
          number: historyEntry.number,
          pointsEarned: historyEntry.pointsEarned,
          historyEntry: historyEntry,
        ),
      ),
    );
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(accessToken: 'good'),
      cartStore: _MemoryCartStore(),
      api: api,
    );
    await controller.bootstrap();
    controller.login('+996700123456');
    await controller.quickAdd(controller.state.products.first);

    final result = await controller.submitOrder(
      clientRequestId: 'immediate-history-request',
      type: OrderType.pickup,
      readyTime: 'asap',
      items: controller.state.cart,
      branch: controller.state.selectedBranch,
      pointsUsed: 0,
    );

    expect(result.isOk, isTrue);
    expect(controller.state.orders, hasLength(1));
    expect(controller.state.orders.single.id, historyEntry.id);
  });

  test(
    'expired access token refreshes before the committed order clears cart',
    () async {
      final api = _CapturingOrderApiClient(rejectToken: 'expired');
      final authStore = _MemoryAuthStore(
        accessToken: 'expired',
        refreshToken: 'fresh',
      );
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: authStore,
        cartStore: _MemoryCartStore(),
        api: api,
      );
      await controller.bootstrap();
      controller.login('+996700123456');
      await controller.quickAdd(controller.state.products.first);

      final result = await controller.submitOrder(
        clientRequestId: 'refresh-order-request',
        type: OrderType.pickup,
        readyTime: 'asap',
        items: controller.state.cart,
        branch: controller.state.selectedBranch,
        pointsUsed: 0,
      );

      expect(result.isOk, isTrue);
      expect(api.accessTokens, ['expired', 'good']);
      expect(authStore.accessToken, 'good');
      expect(controller.state.cart, isEmpty);
    },
  );

  test(
    'customer order parser accepts V2 and preserves localized snapshots',
    () {
      final order = parseCustomerOrderHistoryEntry(_v2OrderJson());

      expect(order, isNotNull);
      expect(order!.number, 'SW-2001');
      expect(order.itemsVersion, 2);
      expect(order.status, OrderStatus.preparing);
      expect(order.paymentMethod, PaymentMethod.qrDemo);
      expect(order.items.single.productId, DemoData.products.first.id);
      expect(order.items.single.sizeId, 'm');
      expect(order.items.single.toppingIds, ['tapioca']);
      expect(
        order.items.single.productName.resolve(AppLanguage.en),
        'Pink Moon milk tea',
      );
    },
  );

  test('malformed V2 order is unavailable instead of empty history', () {
    final raw = _v2OrderJson();
    (raw['items']! as List<Map<String, dynamic>>).single.remove('productId');

    expect(parseCustomerOrderHistoryEntry(raw), isNull);
  });

  test(
    'cart accepts only known promo codes and supports partial points',
    () async {
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(),
        cartStore: _MemoryCartStore(),
      );
      final product = DemoData.products.first;
      expect(
        await controller.addConfigured(
          product,
          sizeId: product.sizes.first.id,
          sugarPercent: 50,
          ice: IceLevel.regular,
          toppingIds: const [],
        ),
        isTrue,
      );

      expect(controller.applyPromoCode('missing'), isFalse);
      expect(controller.state.promoCode, isNull);
      expect(controller.applyPromoCode(DemoData.promotions.first.code), isTrue);
      expect(
        controller.state.promoCode,
        DemoData.promotions.first.code.toUpperCase(),
      );
      expect(controller.applyPromoCode('missing'), isFalse);
      expect(controller.state.promoCode, isNull);

      controller.setUseBonus(true);
      controller.setBonusPointsToUse(10);
      expect(controller.state.bonusApplied, 10);
      expect(controller.state.total, controller.state.subtotal - 10);
    },
  );

  test(
    'company refresh accepts empty storefront content and reads later changes',
    () async {
      final api = _MutableCompanyContentApiClient(
        news: const [],
        promotions: const [],
      );
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(),
        cartStore: _MemoryCartStore(),
        api: api,
      );

      await controller.bootstrap();

      expect(controller.state.newsStories, isEmpty);
      expect(controller.state.promotions, isEmpty);
      expect(api.newsCalls, 1);

      api.news = [DemoData.newsStories.last];
      api.promotions = [DemoData.promotions.last];
      await controller.refreshCompanyData(force: true);

      expect(controller.state.newsStories.single.id, api.news!.single.id);
      expect(controller.state.promotions.single.id, api.promotions!.single.id);
      expect(api.newsCalls, 2);

      final activeCode = api.promotions!.single.code;
      expect(controller.applyPromoCode(activeCode), isTrue);
      api.promotions = null;
      expect(await controller.validatePromoCode(activeCode), isFalse);
      expect(controller.state.promoCode, isNull);
      expect(controller.applyPromoCode(activeCode), isTrue);
      api.promotions = const [];
      expect(await controller.validatePromoCode(activeCode), isFalse);
      expect(controller.state.promoCode, isNull);
    },
  );

  test(
    'server history loads and exact V2 reorder uses current catalog price',
    () async {
      final order = parseCustomerOrderHistoryEntry(
        _v2OrderJson(itemTotal: 1, orderTotal: 1),
      )!;
      final api = _CatalogAuthApiClient(
        profile: _testCustomerProfile,
        orders: [order],
      );
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
        cartStore: _MemoryCartStore(),
        api: api,
      );

      await controller.bootstrap();
      expect(controller.state.catalogAuthoritative, isTrue);
      expect(controller.state.orders.single.number, 'SW-2001');

      final result = await controller.repeatOrder(order);
      final product = DemoData.products.first;
      final expectedUnitPrice =
          product.basePrice +
          product.sizes.firstWhere((size) => size.id == 'm').priceDelta +
          product.toppings
              .firstWhere((topping) => topping.id == 'tapioca')
              .priceDelta;

      expect(result, RepeatOrderResult.success);
      expect(controller.state.cart.single.product.id, product.id);
      expect(controller.state.cart.single.total, expectedUnitPrice);
      expect(controller.state.cart.single.total, isNot(order.total));
    },
  );

  test('empty server order history clears stale local history', () async {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
      cartStore: _MemoryCartStore(),
      api: _CatalogAuthApiClient(profile: _testCustomerProfile),
    )..seedDemo(history: true);

    expect(controller.state.orders, isNotEmpty);
    await controller.bootstrap();

    expect(controller.state.orders, isEmpty);
  });

  test('late order history response cannot leak back after logout', () async {
    final order = parseCustomerOrderHistoryEntry(_v2OrderJson())!;
    final api = _ControlledOrdersApiClient(profile: _testCustomerProfile);
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
      cartStore: _MemoryCartStore(),
      api: api,
    );

    final bootstrap = controller.bootstrap();
    while (api.orderGetCalls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    controller.logout();
    api.completeOrders([order]);
    await bootstrap;

    expect(controller.state.isGuest, isTrue);
    expect(controller.state.orders, isEmpty);
  });

  test(
    'legacy history is display-only and never matched by product name',
    () async {
      final legacy = parseCustomerOrderHistoryEntry(_v1OrderJson())!;
      final api = _CatalogAuthApiClient(
        profile: _testCustomerProfile,
        orders: [legacy],
      );
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
        cartStore: _MemoryCartStore(),
        api: api,
      );

      await controller.bootstrap();
      final result = await controller.repeatOrder(legacy);

      expect(result, RepeatOrderResult.legacyOrder);
      expect(controller.state.cart, isEmpty);
    },
  );

  test(
    'one unavailable V2 selection blocks the whole repeated order',
    () async {
      final raw = _v2OrderJson();
      final items = raw['items']! as List<Map<String, dynamic>>;
      items.add({...items.single, 'productId': 'removed-product'});
      final order = parseCustomerOrderHistoryEntry(raw)!;
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
        cartStore: _MemoryCartStore(),
        api: _CatalogAuthApiClient(
          profile: _testCustomerProfile,
          orders: [order],
        ),
      );

      await controller.bootstrap();
      final result = await controller.repeatOrder(order);

      expect(result, RepeatOrderResult.unavailableSelection);
      expect(controller.state.cart, isEmpty);
    },
  );

  test('offline demo catalog cannot authorize a V2 reorder', () async {
    final order = parseCustomerOrderHistoryEntry(_v2OrderJson())!;
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      cartStore: _MemoryCartStore(),
      api: _OfflineApiClient(),
    );

    final result = await controller.repeatOrder(order);

    expect(result, RepeatOrderResult.catalogUnavailable);
    expect(controller.state.cart, isEmpty);
  });

  test('recurring parser accepts stable IDs and server paidUntil', () {
    final recurring = parseCustomerRecurringOrder(_recurringJson());

    expect(recurring, isNotNull);
    expect(recurring!.productIds, [DemoData.products.first.id]);
    expect(recurring.branchId, DemoData.branches.first.id);
    expect(recurring.plan, RecurringPlan.week);
    expect(recurring.paidUntil, DateTime.utc(2026, 7, 22, 12));

    final invalid = _recurringJson()..['time'] = '25:00';
    expect(parseCustomerRecurringOrder(invalid), isNull);
  });

  test(
    'server recurring hydrates and authoritative null clears stale state',
    () async {
      final recurring = parseCustomerRecurringOrder(_recurringJson())!;
      final restored = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
        cartStore: _MemoryCartStore(),
        api: _CatalogAuthApiClient(
          profile: _testCustomerProfile,
          recurring: recurring,
        ),
      );
      await restored.bootstrap();
      expect(restored.state.recurring?.paidUntil, recurring.paidUntil);

      final cleared = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
        cartStore: _MemoryCartStore(),
        api: _CatalogAuthApiClient(profile: _testCustomerProfile),
      )..seedDemo(recurring: true);
      expect(cleared.state.recurring, isNotNull);
      await cleared.bootstrap();
      expect(cleared.state.recurring, isNull);
    },
  );

  test('recurring PUT and DELETE use server-authoritative state', () async {
    final api = _CatalogAuthApiClient(profile: _testCustomerProfile);
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
      cartStore: _MemoryCartStore(),
      api: api,
    );
    await controller.bootstrap();

    final saved = await controller.setRecurring(
      products: [DemoData.products.first],
      time: '11:00',
      branch: DemoData.branches.first,
      plan: RecurringPlan.week,
    );

    expect(saved, isTrue);
    expect(api.recurringPutCalls, [
      [DemoData.products.first.id],
    ]);
    expect(controller.state.recurring?.paidUntil, DateTime.utc(2026, 7, 22));

    expect(await controller.cancelRecurring(), isTrue);
    expect(api.recurringDeleteCalls, 1);
    expect(controller.state.recurring, isNull);
  });

  test(
    'late recurring PUT cannot restore private state after logout',
    () async {
      final api = _ControlledRecurringApiClient(profile: _testCustomerProfile);
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
        cartStore: _MemoryCartStore(),
        api: api,
      );
      await controller.bootstrap();

      final saving = controller.setRecurring(
        products: [DemoData.products.first],
        time: '11:00',
        branch: DemoData.branches.first,
        plan: RecurringPlan.week,
      );
      await Future<void>.delayed(Duration.zero);
      controller.logout();
      api.completePut(parseCustomerRecurringOrder(_recurringJson())!);

      expect(await saving, isFalse);
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.recurring, isNull);
    },
  );

  test('local cart survives controller restart using stable ids', () async {
    final cartStore = _MemoryCartStore();
    final product = DemoData.products.first;
    final size = product.sizes.last;
    final topping = product.toppings.first;
    final first = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(),
      cartStore: cartStore,
      api: _OfflineApiClient(),
    );

    await first.addConfigured(
      product,
      sizeId: size.id,
      sugarPercent: 30,
      ice: IceLevel.less,
      toppingIds: [topping.id],
    );
    await first.updateQuantity(0, 1);

    final restored = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(),
      cartStore: cartStore,
      api: _OfflineApiClient(),
    );
    await restored.bootstrap();

    final item = restored.state.cart.single;
    expect(item.product.id, product.id);
    expect(item.quantity, 2);
    expect(item.sizeId, size.id);
    expect(item.sugarPercent, 30);
    expect(item.ice, IceLevel.less);
    expect(item.toppingIds, [topping.id]);
    expect(
      item.total,
      (product.basePrice + size.priceDelta + topping.priceDelta) * 2,
    );
  });

  test(
    'editing one duplicate cart row replaces only that configuration',
    () async {
      final cartStore = _MemoryCartStore();
      final product = DemoData.products.first;
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(),
        cartStore: cartStore,
        api: _OfflineApiClient(),
      );

      await controller.addConfigured(
        product,
        sizeId: product.sizes.first.id,
        sugarPercent: 30,
        ice: IceLevel.less,
        toppingIds: const [],
      );
      await controller.updateQuantity(0, 1);
      await controller.addConfigured(
        product,
        sizeId: product.sizes.last.id,
        sugarPercent: 70,
        ice: IceLevel.extra,
        toppingIds: [product.toppings.last.id],
      );
      final untouched = controller.state.cart[1];

      final replaced = await controller.replaceConfiguredAt(
        0,
        product,
        sizeId: product.sizes[1].id,
        sugarPercent: 50,
        ice: IceLevel.regular,
        toppingIds: [product.toppings.first.id],
      );

      expect(replaced, isTrue);
      expect(controller.state.cart, hasLength(2));
      expect(controller.state.cart[0].quantity, 2);
      expect(controller.state.cart[0].sizeId, product.sizes[1].id);
      expect(controller.state.cart[0].toppingIds, [product.toppings.first.id]);
      expect(controller.state.cart[1].sizeId, untouched.sizeId);
      expect(controller.state.cart[1].toppingIds, untouched.toppingIds);
      expect(cartStore.items, hasLength(2));
      expect(cartStore.items[0].quantity, 2);
      expect(cartStore.items[0].sizeId, product.sizes[1].id);
    },
  );

  test('stale cart products and modifiers are cleaned safely', () async {
    final product = DemoData.products.first;
    final cartStore = _MemoryCartStore([
      const CartDraftItem(
        productId: 'deleted-product',
        quantity: 1,
        sizeId: 'm',
        sugarPercent: 50,
        ice: 'regular',
        toppingIds: [],
      ),
      CartDraftItem(
        productId: product.id,
        quantity: 1,
        sizeId: product.sizes.first.id,
        sugarPercent: 50,
        ice: 'regular',
        toppingIds: const ['deleted-topping'],
      ),
      CartDraftItem(
        productId: product.id,
        quantity: 1,
        sizeId: 'deleted-size',
        sugarPercent: 50,
        ice: 'regular',
        toppingIds: const [],
      ),
    ]);
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(),
      cartStore: cartStore,
      api: _OfflineApiClient(),
    );

    await controller.bootstrap();

    expect(controller.state.cart, hasLength(1));
    expect(controller.state.cart.single.product.id, product.id);
    expect(controller.state.cart.single.toppingIds, isEmpty);
    expect(cartStore.items, hasLength(1));
    expect(cartStore.items.single.toppingIds, isEmpty);
  });

  test('removing the last cart item persists an empty draft', () async {
    final cartStore = _MemoryCartStore();
    final first = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(),
      cartStore: cartStore,
      api: _OfflineApiClient(),
    );
    await first.quickAdd(DemoData.products.first);
    await first.removeFromCart(0);

    final restored = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(),
      cartStore: cartStore,
      api: _OfflineApiClient(),
    );
    await restored.bootstrap();

    expect(cartStore.items, isEmpty);
    expect(restored.state.cart, isEmpty);
  });

  test(
    'cart survives login and logout but account deletion clears it',
    () async {
      final cartStore = _MemoryCartStore();
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(),
        cartStore: cartStore,
        api: _OfflineApiClient(),
      );
      await controller.quickAdd(DemoData.products.first);

      controller.login('+996700123456');
      expect(controller.state.cart, isNotEmpty);
      controller.logout();
      expect(controller.state.cart, isNotEmpty);

      controller.login('+996700123456');
      expect(await controller.deleteAccount(), AccountDeletionResult.success);
      expect(controller.state.cart, isEmpty);
      expect(cartStore.items, isEmpty);
    },
  );

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
    );

    expect(controller.state.firstName, 'Алина');
    expect(controller.state.lastName, 'Садыкова');
    expect(controller.state.userName, 'Алина Садыкова');
    expect(controller.state.birthDate, birthDate);
    expect(controller.state.avatarUrl, isNull);

    controller.logout();
    expect(controller.state.isGuest, isTrue);
    expect(controller.state.userName, isEmpty);
    expect(controller.state.birthDate, isNull);
    expect(controller.state.avatarUrl, isNull);
    expect(controller.state.userContact, isEmpty);
  });

  test('demo account deletion clears personal and commerce state', () async {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
    )..seedDemo(auth: true, cart: true, history: true, recurring: true);

    expect(controller.state.points, greaterThan(0));
    expect(controller.state.favoriteIds, isNotEmpty);
    expect(controller.state.cart, isNotEmpty);
    expect(controller.state.orders, isNotEmpty);
    expect(controller.state.recurring, isNotNull);

    expect(await controller.deleteAccount(), AccountDeletionResult.success);

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
    'server account deletion succeeds before local data is cleared',
    () async {
      final authStore = _MemoryAuthStore(
        accessToken: 'good',
        refreshToken: 'fresh',
      );
      final cartStore = _MemoryCartStore();
      final api = _FakeAuthApiClient(profile: _testCustomerProfile);
      final google = _FakeGoogleIdentityProvider();
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: authStore,
        cartStore: cartStore,
        api: api,
        googleIdentity: google,
      );
      await controller.bootstrap();
      await controller.quickAdd(DemoData.products.first);

      expect(await controller.deleteAccount(), AccountDeletionResult.success);
      expect(api.accountDeleteCalls, 1);
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.cart, isEmpty);
      expect(authStore.accessToken, isNull);
      expect(authStore.refreshToken, isNull);
      expect(google.signOutCalls, 1);
    },
  );

  test('failed server deletion keeps the signed-in account intact', () async {
    final authStore = _MemoryAuthStore(
      accessToken: 'good',
      refreshToken: 'fresh',
    );
    final api = _FakeAuthApiClient(
      profile: _testCustomerProfile,
      accountDeleteResult: const ApiResult<bool>.unavailable(),
    );
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: authStore,
      cartStore: _MemoryCartStore(),
      api: api,
    );
    await controller.bootstrap();

    expect(await controller.deleteAccount(), AccountDeletionResult.unavailable);
    expect(api.accountDeleteCalls, 1);
    expect(controller.state.isGuest, isFalse);
    expect(controller.state.customerId, _testCustomerProfile.id);
    expect(authStore.accessToken, 'good');
  });

  test(
    'guest checkout and API submission are rejected without cart loss',
    () async {
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
      )..seedDemo(cart: true);

      final created = await controller.submitOrder(
        clientRequestId: 'guest-order-request',
        type: OrderType.pickup,
        readyTime: 'as soon as possible',
        items: controller.state.cart,
        branch: controller.state.selectedBranch,
        pointsUsed: 0,
      );

      expect(created.isOk, isFalse);
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.cart, isNotEmpty);
      expect(controller.state.orders, isEmpty);
    },
  );

  test(
    'saved token restores the server session and profile on start',
    () async {
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
        favoriteIds: [DemoData.products[1].id],
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
      expect(api.favoriteGetCalls, ['good']);
      expect(controller.state.favoriteIds, [DemoData.products[1].id]);
    },
  );

  test('empty server favorites are authoritative on bootstrap', () async {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(accessToken: 'good', refreshToken: 'fresh'),
      api: _FakeAuthApiClient(
        profile: const CustomerProfile(
          id: 'c-sw-aigerim',
          phone: '+996 555 123 456',
          firstName: 'Aigerim',
          lastName: '',
          birthDate: null,
          points: 1240,
          referralCode: null,
          invitedByCode: null,
        ),
      ),
    );

    expect(controller.state.favoriteIds, DemoData.favoriteIds);
    await controller.bootstrap();
    expect(controller.state.favoriteIds, isEmpty);
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
        favoriteIds: [DemoData.products[2].id],
      ),
    );

    expect(await controller.loginWithOtp('+996555123456', '9999'), isFalse);
    expect(controller.state.isGuest, isTrue);
    expect(authStore.accessToken, isNull);

    expect(await controller.loginWithOtp('+996555123456', '1111'), isTrue);
    expect(controller.state.isGuest, isFalse);
    expect(controller.state.points, 1240);
    expect(controller.state.favoriteIds, [DemoData.products[2].id]);
    expect(authStore.accessToken, 'good');
    expect(authStore.refreshToken, 'fresh');

    expect(
      await controller.uploadAvatar(
        bytes: const [1, 2, 3],
        filename: 'avatar.jpg',
        contentType: 'image/jpeg',
      ),
      isTrue,
    );
    expect(controller.state.avatarUrl, 'https://cdn.example/avatar.webp');

    expect(await controller.deleteAvatar(), isTrue);
    expect(controller.state.avatarUrl, isNull);

    controller.logout();
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.isGuest, isTrue);
    expect(controller.state.favoriteIds, isEmpty);
    expect(authStore.accessToken, isNull);
    expect(authStore.refreshToken, isNull);
    expect(authStore.clearCount, 1);
  });

  test(
    'offline OTP and cancelled Google do not create a local session',
    () async {
      final google = _FakeGoogleIdentityProvider(
        result: const GoogleIdentityResult.cancelled(),
      );
      final controller = AppStateController(
        languagePreferences: _MemoryLanguagePreferenceStore(),
        authStore: _MemoryAuthStore(),
        api: _OfflineApiClient(),
        googleIdentity: google,
      );

      expect(await controller.loginWithOtp('+996700123456', '1111'), isFalse);
      expect(await controller.loginWithGoogle(), GoogleLoginResult.cancelled);
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.customerId, isNull);
      expect(google.signOutCalls, 0);
    },
  );

  test('Google provider is signed out when backend exchange fails', () async {
    final google = _FakeGoogleIdentityProvider();
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(),
      api: _OfflineApiClient(),
      googleIdentity: google,
    );

    expect(await controller.loginWithGoogle(), GoogleLoginResult.unavailable);
    expect(controller.state.isGuest, isTrue);
    expect(google.signOutCalls, 1);
  });

  test('rapid favorite toggles serialize writes and keep newest set', () async {
    final api = _ControlledFavoritesApiClient(
      profile: const CustomerProfile(
        id: 'c-sw-aigerim',
        phone: '+996 555 123 456',
        firstName: 'Aigerim',
        lastName: '',
        birthDate: null,
        points: 1240,
        referralCode: null,
        invitedByCode: null,
      ),
    );
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(),
      api: api,
    );
    await controller.loginWithOtp('+996555123456', '1111');

    final first = DemoData.products[0];
    final second = DemoData.products[1];
    final firstSync = controller.toggleFavorite(first);
    await Future<void>.delayed(Duration.zero);
    final secondSync = controller.toggleFavorite(second);

    expect(controller.state.favoriteIds, [first.id, second.id]);
    expect(api.favoritePutCalls, [
      [first.id],
    ]);

    api.completeNextPut();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.favoriteIds, [first.id, second.id]);
    expect(api.favoritePutCalls, [
      [first.id],
      [first.id, second.id],
    ]);

    api.completeNextPut();
    await Future.wait([firstSync, secondSync]);
    expect(api.serverFavoriteIds, [first.id, second.id]);
    expect(controller.state.favoriteIds, [first.id, second.id]);
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

  testWidgets('quick add shows one transient notice at the top', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 900));
    await tester.tap(find.text('Каталог').first);
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(FilledButton, 'В корзину').first;
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(addButton);
    await tester.pump(const Duration(milliseconds: 220));

    final message = const AppLocalizations(
      AppLanguage.ru,
    ).productAdded(DemoData.products.first.name.ru);
    expect(find.text(message), findsOneWidget);
    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getTopLeft(find.text(message)).dy,
      lessThan(logicalHeight / 3),
    );

    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text(message), findsNothing);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('story-current-news-week-flavor')),
      findsOneWidget,
    );
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

  testWidgets('Android Back from checkout returns to the preserved cart', (
    WidgetTester tester,
  ) async {
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
    )..seedDemo(auth: true, cart: true);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    // A direct route has no Navigator history; Checkout must still fall back
    // to Cart instead of allowing Android to close the application.
    appRouter.go('/checkout');
    await tester.pumpAndSettle();
    expect(find.text('Оформление'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Итого'), findsOneWidget);
    expect(controller.state.cart, isNotEmpty);
  });

  testWidgets('cart edit opens configured product and replaces the same row', (
    tester,
  ) async {
    final product = DemoData.products.first;
    final topping = product.toppings.first;
    final controller = AppStateController(
      languagePreferences: _MemoryLanguagePreferenceStore(),
      authStore: _MemoryAuthStore(),
      cartStore: _MemoryCartStore(),
      api: _OfflineApiClient(),
    );
    await controller.addConfigured(
      product,
      sizeId: product.sizes.last.id,
      sugarPercent: 30,
      ice: IceLevel.less,
      toppingIds: [topping.id],
    );
    await controller.updateQuantity(0, 1);

    await tester.pumpWidget(_testAppWithController(controller));
    appRouter.go('/cart');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('edit-cart-item-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-cart-item-0')));
    await tester.pumpAndSettle();

    expect(find.byType(ProductPage), findsOneWidget);
    await tester.tap(find.textContaining('Сохранить').last);
    await tester.pumpAndSettle();

    expect(appRouter.routeInformationProvider.value.uri.path, '/cart');
    expect(controller.state.cart, hasLength(1));
    expect(controller.state.cart.single.quantity, 2);
    expect(controller.state.cart.single.sizeId, product.sizes.last.id);
    expect(controller.state.cart.single.sugarPercent, 30);
    expect(controller.state.cart.single.ice, IceLevel.less);
    expect(controller.state.cart.single.toppingIds, [topping.id]);
  });

  testWidgets('Android Back from a root tab returns to Home first', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 900));
    await _openNavigationTab(tester, 'Каталог');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('Google sign-in collects an unverified contact before checkout', (
    WidgetTester tester,
  ) async {
    final google = _FakeGoogleIdentityProvider();
    final api = _FakeAuthApiClient(
      profile: const CustomerProfile(
        id: 'google-customer',
        phone: null,
        phoneVerified: false,
        firstName: 'Google',
        lastName: 'Customer',
        birthDate: null,
        points: 0,
        referralCode: null,
        invitedByCode: null,
      ),
    );
    final controller =
        AppStateController(
            languagePreferences: _MemoryLanguagePreferenceStore(),
            authStore: _MemoryAuthStore(),
            api: api,
            googleIdentity: google,
          )
          ..setLanguage(AppLanguage.en)
          ..seedDemo(cart: true);
    await tester.pumpWidget(_testAppWithController(controller));
    await tester.pump(const Duration(milliseconds: 900));

    await _openNavigationTab(tester, 'Cart');
    await tester.tap(find.textContaining('Checkout').last);
    await tester.pumpAndSettle();

    expect(find.text('Sign in or register'), findsOneWidget);
    expect(find.text('SMS sign-in is temporarily unavailable'), findsOneWidget);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(google.authenticateCalls, 1);
    expect(api.googleIdTokens, ['google-id-token']);
    expect(controller.state.isGuest, isFalse);
    expect(controller.state.accountReady, isFalse);
    expect(find.text('Add a contact phone'), findsOneWidget);
    expect(find.textContaining('this number is not verified'), findsOneWidget);

    final phoneField = find.byType(TextField);
    expect(phoneField, findsOneWidget);
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

    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();

    expect(controller.state.isGuest, isFalse);
    expect(controller.state.userContact, '+996708381382');
    expect(controller.state.phoneVerified, isFalse);
    expect(controller.state.accountReady, isTrue);
    expect(api.contactPhoneCalls, ['+996708381382']);
    expect(controller.state.cart, isNotEmpty);
    expect(find.text('Fulfillment method'), findsOneWidget);
  });

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
    await _scrollToText(tester, 'Our branches');
    expect(find.text('Our branches'), findsOneWidget);
    expect(find.textContaining('Zhal microdistrict'), findsNothing);
    expect(find.textContaining('Manas Ave.'), findsNothing);
    await tester.tap(find.text('Our branches'));
    await tester.pumpAndSettle();
    expect(find.text('SweetTime on Chuy'), findsOneWidget);
    await tester.tap(find.text('SweetTime on Chuy'));
    await tester.pumpAndSettle();
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
        (ref) => AppStateController(
          languagePreferences: store,
          cartStore: _MemoryCartStore(),
        ),
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

class _MemoryCartStore implements CartStore {
  _MemoryCartStore([List<CartDraftItem> initial = const []])
    : items = List.unmodifiable(initial);

  List<CartDraftItem> items;

  @override
  Future<List<CartDraftItem>> read() async => List.unmodifiable(items);

  @override
  Future<void> write(List<CartDraftItem> items) async {
    this.items = List.unmodifiable(items);
  }
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

class _FakeGoogleIdentityProvider implements GoogleIdentityProvider {
  _FakeGoogleIdentityProvider({
    this.result = const GoogleIdentityResult.success('google-id-token'),
  });

  GoogleIdentityResult result;
  int authenticateCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isConfigured => result.status != GoogleIdentityStatus.notConfigured;

  @override
  Future<GoogleIdentityResult> authenticate() async {
    authenticateCalls++;
    return result;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

/// API недоступен: все запросы отвечают как офлайн.
/// Даёт детерминированность — тест не зависит от того, поднят ли реальный :8010.
class _OfflineApiClient extends ApiClient {
  @override
  Future<CompanyConfig?> fetchConfig() async => null;

  @override
  Future<ApiResult<CustomerSession>> otpVerify(
    String phone,
    String code,
  ) async => const ApiResult<CustomerSession>.unavailable();

  @override
  Future<ApiResult<CustomerSession>> googleSignIn(String idToken) async =>
      const ApiResult<CustomerSession>.unavailable();

  @override
  Future<ApiResult<CustomerProfile>> patchCustomerContact(
    String accessToken,
    String phone,
  ) async => const ApiResult<CustomerProfile>.unavailable();

  @override
  Future<ApiResult<CustomerProfile>> fetchCustomerMe(
    String accessToken,
  ) async => const ApiResult<CustomerProfile>.unavailable();

  @override
  Future<ApiResult<List<String>>> fetchCustomerFavorites(
    String accessToken,
  ) async => const ApiResult<List<String>>.unavailable();

  @override
  Future<ApiResult<List<OrderHistoryEntry>>> fetchCustomerOrders(
    String accessToken,
  ) async => const ApiResult<List<OrderHistoryEntry>>.unavailable();

  @override
  Future<ApiResult<RecurringOrder?>> fetchCustomerRecurring(
    String accessToken,
  ) async => const ApiResult<RecurringOrder?>.unavailable();

  @override
  Future<ApiResult<RecurringOrder?>> replaceCustomerRecurring(
    String accessToken, {
    required List<String> productIds,
    required String time,
    required String branchId,
    required RecurringPlan plan,
  }) async => const ApiResult<RecurringOrder?>.unavailable();

  @override
  Future<ApiResult<bool>> deleteCustomerRecurring(String accessToken) async =>
      const ApiResult<bool>.unavailable();

  @override
  Future<ApiResult<List<String>>> replaceCustomerFavorites(
    String accessToken,
    List<String> productIds,
  ) async => const ApiResult<List<String>>.unavailable();

  @override
  Future<bool> otpRequest(String phone) async => false;
}

class _CapturingOrderApiClient extends _OfflineApiClient {
  _CapturingOrderApiClient({
    this.orderResult = const ApiResult<CreatedOrder>.ok(
      CreatedOrder(number: 'SW-test', pointsEarned: 0),
    ),
    this.rejectToken,
    this.products = DemoData.products,
  });

  final List<Map<String, Object?>> requests = [];
  final List<String> accessTokens = [];
  final ApiResult<CreatedOrder> orderResult;
  final String? rejectToken;
  final List<Product> products;

  @override
  Future<CompanyConfig?> fetchConfig() async => const CompanyConfig(
    appName: 'SweetTime',
    accentColor: null,
    earnRate: 0.05,
    maxSpendShare: 0.3,
  );

  @override
  Future<List<Product>?> fetchProducts() async => products;

  @override
  Future<List<Branch>?> fetchBranches() async => DemoData.branches;

  @override
  Future<ApiResult<CreatedOrder>> createOrder(
    String accessToken, {
    required String clientRequestId,
    required String branchId,
    required String type,
    required String readyTime,
    required List<Map<String, Object?>> items,
    required String paymentMethod,
    required int pointsUsed,
    String? promoCode,
    String? comment,
  }) async {
    accessTokens.add(accessToken);
    requests.add({
      'clientRequestId': clientRequestId,
      'branchId': branchId,
      'type': type,
      'readyTime': readyTime,
      'items': items,
      'paymentMethod': paymentMethod,
      'pointsUsed': pointsUsed,
      'promoCode': promoCode,
      'comment': comment,
    });
    if (accessToken == rejectToken) {
      return const ApiResult<CreatedOrder>.rejected();
    }
    return orderResult;
  }

  @override
  Future<ApiResult<TokenPair>> refreshTokens(String refreshToken) async =>
      refreshToken == 'fresh'
      ? const ApiResult<TokenPair>.ok(
          TokenPair(accessToken: 'good', refreshToken: 'fresh-next'),
        )
      : const ApiResult<TokenPair>.rejected();
}

/// Сервер с одним известным клиентом: access-токен `good`, refresh `fresh`.
class _FakeAuthApiClient extends ApiClient {
  _FakeAuthApiClient({
    required this.profile,
    this.favoriteIds = const [],
    this.orders = const [],
    RecurringOrder? recurring,
    this.accountDeleteResult = const ApiResult<bool>.ok(true),
  }) : serverRecurring = recurring;

  final CustomerProfile profile;
  final List<String> favoriteIds;
  final List<OrderHistoryEntry> orders;
  RecurringOrder? serverRecurring;
  final ApiResult<bool> accountDeleteResult;
  final List<String> customerMeCalls = [];
  final List<String> favoriteGetCalls = [];
  final List<String> orderGetCalls = [];
  final List<String> recurringGetCalls = [];
  final List<String> googleIdTokens = [];
  final List<String> contactPhoneCalls = [];
  final List<List<String>> recurringPutCalls = [];
  int recurringDeleteCalls = 0;
  int accountDeleteCalls = 0;
  final List<List<String>> favoritePutCalls = [];

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
  Future<ApiResult<bool>> deleteCustomerAccount(String accessToken) async {
    accountDeleteCalls++;
    if (accessToken != 'good') return const ApiResult<bool>.rejected();
    return accountDeleteResult;
  }

  @override
  Future<ApiResult<CustomerSession>> otpVerify(
    String phone,
    String code,
  ) async {
    if (code != '1111') return const ApiResult<CustomerSession>.rejected();
    return ApiResult<CustomerSession>.ok(
      CustomerSession(
        tokens: const TokenPair(accessToken: 'good', refreshToken: 'fresh'),
        profile: profile,
      ),
    );
  }

  @override
  Future<ApiResult<CustomerSession>> googleSignIn(String idToken) async {
    googleIdTokens.add(idToken);
    return ApiResult<CustomerSession>.ok(
      CustomerSession(
        tokens: const TokenPair(accessToken: 'good', refreshToken: 'fresh'),
        profile: profile,
      ),
    );
  }

  @override
  Future<ApiResult<CustomerProfile>> patchCustomerContact(
    String accessToken,
    String phone,
  ) async {
    contactPhoneCalls.add(phone);
    if (accessToken != 'good') {
      return const ApiResult<CustomerProfile>.rejected();
    }
    return ApiResult<CustomerProfile>.ok(
      profile.copyWith(phone: phone, phoneVerified: false),
    );
  }

  @override
  Future<ApiResult<List<String>>> fetchCustomerFavorites(
    String accessToken,
  ) async {
    favoriteGetCalls.add(accessToken);
    if (accessToken != 'good') {
      return const ApiResult<List<String>>.rejected();
    }
    return ApiResult<List<String>>.ok(List.unmodifiable(favoriteIds));
  }

  @override
  Future<ApiResult<List<OrderHistoryEntry>>> fetchCustomerOrders(
    String accessToken,
  ) async {
    orderGetCalls.add(accessToken);
    if (accessToken != 'good') {
      return const ApiResult<List<OrderHistoryEntry>>.rejected();
    }
    return ApiResult<List<OrderHistoryEntry>>.ok(List.unmodifiable(orders));
  }

  @override
  Future<ApiResult<RecurringOrder?>> fetchCustomerRecurring(
    String accessToken,
  ) async {
    recurringGetCalls.add(accessToken);
    if (accessToken != 'good') {
      return const ApiResult<RecurringOrder?>.rejected();
    }
    return ApiResult<RecurringOrder?>.ok(serverRecurring);
  }

  @override
  Future<ApiResult<RecurringOrder?>> replaceCustomerRecurring(
    String accessToken, {
    required List<String> productIds,
    required String time,
    required String branchId,
    required RecurringPlan plan,
  }) async {
    recurringPutCalls.add(List.unmodifiable(productIds));
    if (accessToken != 'good') {
      return const ApiResult<RecurringOrder?>.rejected();
    }
    serverRecurring = RecurringOrder(
      productIds: List.unmodifiable(productIds),
      time: time,
      branchId: branchId,
      plan: plan,
      paidUntil: DateTime.utc(2026, 7, 22),
    );
    return ApiResult<RecurringOrder?>.ok(serverRecurring);
  }

  @override
  Future<ApiResult<bool>> deleteCustomerRecurring(String accessToken) async {
    recurringDeleteCalls++;
    if (accessToken != 'good') return const ApiResult<bool>.rejected();
    serverRecurring = null;
    return const ApiResult<bool>.ok(true);
  }

  @override
  Future<ApiResult<List<String>>> replaceCustomerFavorites(
    String accessToken,
    List<String> productIds,
  ) async {
    favoritePutCalls.add(List.unmodifiable(productIds));
    if (accessToken != 'good') {
      return const ApiResult<List<String>>.rejected();
    }
    return ApiResult<List<String>>.ok(List.unmodifiable(productIds));
  }

  @override
  Future<ApiResult<CustomerProfile>> uploadCustomerAvatar(
    String accessToken, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    if (accessToken != 'good') {
      return const ApiResult<CustomerProfile>.rejected();
    }
    return ApiResult<CustomerProfile>.ok(
      profile.copyWith(avatarUrl: 'https://cdn.example/avatar.webp'),
    );
  }

  @override
  Future<ApiResult<bool>> deleteCustomerAvatar(String accessToken) async {
    if (accessToken != 'good') return const ApiResult<bool>.rejected();
    return const ApiResult<bool>.ok(true);
  }
}

class _CatalogAuthApiClient extends _FakeAuthApiClient {
  _CatalogAuthApiClient({
    required super.profile,
    super.orders,
    super.recurring,
  });

  @override
  Future<CompanyConfig?> fetchConfig() async => const CompanyConfig(
    appName: 'SweetTime',
    accentColor: AppColors.candy500,
    earnRate: Loyalty.earnRate,
    maxSpendShare: Loyalty.maxSpendShare,
  );

  @override
  Future<List<Product>?> fetchProducts() async => DemoData.products;

  @override
  Future<List<Branch>?> fetchBranches() async => DemoData.branches;

  @override
  Future<List<NewsStory>?> fetchNews() async => null;

  @override
  Future<List<NewsStory>?> fetchHomeStories({int limit = 30}) async => null;

  @override
  Future<List<StoryCollection>?> fetchStoryCollections() async => null;

  @override
  Future<List<NewsPost>?> fetchNewsPosts() async => null;

  @override
  Future<List<Promotion>?> fetchPromotions() async => null;
}

class _MutableCompanyContentApiClient extends ApiClient {
  _MutableCompanyContentApiClient({
    required this.news,
    required this.promotions,
  });

  List<NewsStory>? news;
  List<Promotion>? promotions;
  int newsCalls = 0;

  @override
  Future<CompanyConfig?> fetchConfig() async => const CompanyConfig(
    appName: 'SweetTime',
    accentColor: AppColors.candy500,
    earnRate: Loyalty.earnRate,
    maxSpendShare: Loyalty.maxSpendShare,
  );

  @override
  Future<List<Product>?> fetchProducts() async => DemoData.products;

  @override
  Future<List<Branch>?> fetchBranches() async => DemoData.branches;

  @override
  Future<List<NewsStory>?> fetchNews() async {
    newsCalls++;
    return news;
  }

  @override
  Future<List<NewsStory>?> fetchHomeStories({int limit = 30}) async => null;

  @override
  Future<List<StoryCollection>?> fetchStoryCollections() async => null;

  @override
  Future<List<NewsPost>?> fetchNewsPosts() async => null;

  @override
  Future<List<Promotion>?> fetchPromotions() async => promotions;
}

class _ControlledOrdersApiClient extends _CatalogAuthApiClient {
  _ControlledOrdersApiClient({required super.profile});

  final Completer<ApiResult<List<OrderHistoryEntry>>> _ordersCompleter =
      Completer<ApiResult<List<OrderHistoryEntry>>>();

  @override
  Future<ApiResult<List<OrderHistoryEntry>>> fetchCustomerOrders(
    String accessToken,
  ) {
    orderGetCalls.add(accessToken);
    return _ordersCompleter.future;
  }

  void completeOrders(List<OrderHistoryEntry> orders) {
    _ordersCompleter.complete(
      ApiResult<List<OrderHistoryEntry>>.ok(List.unmodifiable(orders)),
    );
  }
}

class _ControlledRecurringApiClient extends _CatalogAuthApiClient {
  _ControlledRecurringApiClient({required super.profile});

  final Completer<ApiResult<RecurringOrder?>> _putCompleter =
      Completer<ApiResult<RecurringOrder?>>();

  @override
  Future<ApiResult<RecurringOrder?>> replaceCustomerRecurring(
    String accessToken, {
    required List<String> productIds,
    required String time,
    required String branchId,
    required RecurringPlan plan,
  }) {
    recurringPutCalls.add(List.unmodifiable(productIds));
    return _putCompleter.future;
  }

  void completePut(RecurringOrder recurring) {
    _putCompleter.complete(ApiResult<RecurringOrder?>.ok(recurring));
  }
}

class _ControlledFavoritesApiClient extends _FakeAuthApiClient {
  _ControlledFavoritesApiClient({required super.profile});

  final List<_PendingFavoritePut> _pendingFavoritePuts = [];
  List<String> serverFavoriteIds = [];

  @override
  Future<ApiResult<List<String>>> fetchCustomerFavorites(
    String accessToken,
  ) async {
    favoriteGetCalls.add(accessToken);
    if (accessToken != 'good') {
      return const ApiResult<List<String>>.rejected();
    }
    return ApiResult<List<String>>.ok(List.unmodifiable(serverFavoriteIds));
  }

  @override
  Future<ApiResult<List<String>>> replaceCustomerFavorites(
    String accessToken,
    List<String> productIds,
  ) {
    final snapshot = List<String>.unmodifiable(productIds);
    favoritePutCalls.add(snapshot);
    final pending = _PendingFavoritePut(
      snapshot,
      Completer<ApiResult<List<String>>>(),
    );
    _pendingFavoritePuts.add(pending);
    return pending.completer.future;
  }

  void completeNextPut() {
    final pending = _pendingFavoritePuts.removeAt(0);
    serverFavoriteIds = [...pending.productIds];
    pending.completer.complete(
      ApiResult<List<String>>.ok(List.unmodifiable(serverFavoriteIds)),
    );
  }
}

class _PendingFavoritePut {
  const _PendingFavoritePut(this.productIds, this.completer);

  final List<String> productIds;
  final Completer<ApiResult<List<String>>> completer;
}

class _MemoryLanguagePreferenceStore implements LanguagePreferenceStore {
  String? code;
  String? themeMode;
  String? backgroundOverride;

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

  @override
  Future<String?> readBackgroundOverride() async => backgroundOverride;

  @override
  Future<void> writeBackgroundOverride(String? value) async {
    backgroundOverride = value;
  }
}

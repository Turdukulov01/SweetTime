import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/auth_store.dart';
import '../core/cart_store.dart';
import '../core/google_identity.dart';
import '../core/theme/app_theme.dart';
import 'app_models.dart';
import 'demo_data.dart';

final appStateProvider = StateNotifierProvider<AppStateController, AppState>((
  ref,
) {
  return AppStateController();
});

/// Разрешённые точки возврата после входа.
///
/// Это закрытый список, а не произвольный URL: так auth-flow не превращается
/// в open redirect при появлении реального backend-входа.
enum AuthReturnDestination {
  checkout(location: '/checkout', queryValue: 'checkout');

  const AuthReturnDestination({
    required this.location,
    required this.queryValue,
  });

  final String location;
  final String queryValue;

  String get authLocation =>
      Uri(path: '/auth', queryParameters: {'returnTo': queryValue}).toString();
}

enum GoogleLoginResult {
  success,
  needsContact,
  cancelled,
  notConfigured,
  rejected,
  unavailable,
  busy,
}

enum ContactSaveResult { success, rejected, unavailable, busy }

abstract interface class LanguagePreferenceStore {
  Future<String?> readLanguageCode();
  Future<void> writeLanguageCode(String code);
  Future<String?> readThemeMode();
  Future<void> writeThemeMode(String value);
}

class SharedPreferencesLanguagePreferenceStore
    implements LanguagePreferenceStore {
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<String?> readLanguageCode() =>
      _instance.getString(AppStateController.languagePreferenceKey);

  @override
  Future<void> writeLanguageCode(String code) =>
      _instance.setString(AppStateController.languagePreferenceKey, code);

  @override
  Future<String?> readThemeMode() =>
      _instance.getString(AppStateController.themePreferenceKey);

  @override
  Future<void> writeThemeMode(String value) =>
      _instance.setString(AppStateController.themePreferenceKey, value);
}

@immutable
class AppState {
  const AppState({
    required this.apiConnected,
    required this.catalogAuthoritative,
    required this.appName,
    required this.accentColor,
    required this.loyaltyEarnRate,
    required this.loyaltyMaxSpendShare,
    required this.themeMode,
    required this.language,
    required this.isGuest,
    required this.customerId,
    required this.pendingAuthReturn,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.avatarUrl,
    required this.userContact,
    required this.phoneVerified,
    required this.userCode,
    required this.invitedByCode,
    required this.points,
    required this.branches,
    required this.selectedBranch,
    required this.categories,
    required this.products,
    required this.promotions,
    required this.newsStories,
    required this.favoriteIds,
    required this.cart,
    required this.useBonus,
    required this.orders,
    required this.pointEvents,
    required this.recurring,
  });

  /// true, если при старте удалось достучаться до demo-API;
  /// показывается только мелкой подписью в футере главной.
  final bool apiConnected;

  /// True only when products and branches came from the current backend.
  /// A reachable config endpoint alone is not enough for safe V2 reorder.
  final bool catalogAuthoritative;

  /// Брендинг компании из API (или дефолт SweetTime, если офлайн).
  final String appName;
  final Color accentColor;

  /// Правила лояльности: дефолты из [Loyalty], могут прийти из конфига API.
  final double loyaltyEarnRate;
  final double loyaltyMaxSpendShare;

  final ThemeMode themeMode;
  final AppLanguage language;
  final bool isGuest;
  final String? customerId;
  final AuthReturnDestination? pendingAuthReturn;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final String? avatarUrl;
  final String userContact;
  final bool phoneVerified;

  bool get hasContactPhone => userContact.trim().isNotEmpty;
  bool get accountReady => !isGuest && hasContactPhone;

  String get userName => '$firstName $lastName'.trim();

  /// Личный 6-значный код: лояльность на кассе + рефералка (REFERRAL_LOGIC.md).
  final String userCode;

  /// Код пригласившего; записывается один раз и навсегда.
  final String? invitedByCode;
  final int points;
  final List<Branch> branches;
  final Branch selectedBranch;
  final List<MenuCategory> categories;
  final List<Product> products;
  final List<Promotion> promotions;
  final List<NewsStory> newsStories;
  final List<String> favoriteIds;
  final List<CartItem> cart;
  final bool useBonus;
  final List<OrderHistoryEntry> orders;
  final List<PointEvent> pointEvents;
  final RecurringOrder? recurring;

  int get cartCount => cart.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal => cart.fold(0, (sum, item) => sum + item.total);

  /// Баллами можно оплатить до 30% заказа, 1 балл = 1 сом.
  int get maxBonusSpend {
    final cap = (subtotal * loyaltyMaxSpendShare).floor();
    return points < cap ? points : cap;
  }

  int get bonusApplied => useBonus ? maxBonusSpend : 0;

  int get total {
    final value = subtotal - bonusApplied;
    return value < 0 ? 0 : value;
  }

  /// Кешбэк 5% от оплаченной суммы.
  int get pointsEarned => (total * loyaltyEarnRate).round();

  List<Product> get favorites =>
      products.where((p) => favoriteIds.contains(p.id)).toList();

  List<CartItem> unavailableForSelectedBranch() =>
      cart.where((item) => !item.product.availableIn(selectedBranch)).toList();

  AppState copyWith({
    bool? apiConnected,
    bool? catalogAuthoritative,
    String? appName,
    Color? accentColor,
    double? loyaltyEarnRate,
    double? loyaltyMaxSpendShare,
    ThemeMode? themeMode,
    AppLanguage? language,
    bool? isGuest,
    String? customerId,
    AuthReturnDestination? pendingAuthReturn,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? avatarUrl,
    String? userContact,
    bool? phoneVerified,
    String? invitedByCode,
    int? points,
    List<Branch>? branches,
    Branch? selectedBranch,
    List<MenuCategory>? categories,
    List<Product>? products,
    List<Promotion>? promotions,
    List<NewsStory>? newsStories,
    List<String>? favoriteIds,
    List<CartItem>? cart,
    bool? useBonus,
    List<OrderHistoryEntry>? orders,
    List<PointEvent>? pointEvents,
    RecurringOrder? recurring,
    bool clearBirthDate = false,
    bool clearAvatarUrl = false,
    bool clearCustomerId = false,
    bool clearInvitedByCode = false,
    bool clearPendingAuthReturn = false,
    bool clearRecurring = false,
  }) {
    return AppState(
      apiConnected: apiConnected ?? this.apiConnected,
      catalogAuthoritative: catalogAuthoritative ?? this.catalogAuthoritative,
      appName: appName ?? this.appName,
      accentColor: accentColor ?? this.accentColor,
      loyaltyEarnRate: loyaltyEarnRate ?? this.loyaltyEarnRate,
      loyaltyMaxSpendShare: loyaltyMaxSpendShare ?? this.loyaltyMaxSpendShare,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      isGuest: isGuest ?? this.isGuest,
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      pendingAuthReturn: clearPendingAuthReturn
          ? null
          : (pendingAuthReturn ?? this.pendingAuthReturn),
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      userContact: userContact ?? this.userContact,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      userCode: userCode,
      invitedByCode: clearInvitedByCode
          ? null
          : (invitedByCode ?? this.invitedByCode),
      points: points ?? this.points,
      branches: branches ?? this.branches,
      selectedBranch: selectedBranch ?? this.selectedBranch,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      promotions: promotions ?? this.promotions,
      newsStories: newsStories ?? this.newsStories,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      cart: cart ?? this.cart,
      useBonus: useBonus ?? this.useBonus,
      orders: orders ?? this.orders,
      pointEvents: pointEvents ?? this.pointEvents,
      recurring: clearRecurring ? null : (recurring ?? this.recurring),
    );
  }
}

class AppStateController extends StateNotifier<AppState> {
  AppStateController({
    LanguagePreferenceStore? languagePreferences,
    AuthStore? authStore,
    CartStore? cartStore,
    ApiClient? api,
    GoogleIdentityProvider? googleIdentity,
  }) : _languagePreferences =
           languagePreferences ?? SharedPreferencesLanguagePreferenceStore(),
       _authStore = authStore ?? SecureAuthStore(),
       _cartStore =
           cartStore ??
           SharedPreferencesCartStore(companyId: api?.companyId ?? 'sweettime'),
       _api = api ?? ApiClient(),
       _googleIdentity = googleIdentity ?? PluginGoogleIdentityProvider(),
       super(
         AppState(
           apiConnected: false,
           catalogAuthoritative: false,
           appName: 'SweetTime',
           accentColor: AppColors.candy500,
           loyaltyEarnRate: Loyalty.earnRate,
           loyaltyMaxSpendShare: Loyalty.maxSpendShare,
           themeMode: ThemeMode.light,
           language: AppLanguage.ru,
           isGuest: true,
           customerId: null,
           pendingAuthReturn: null,
           firstName: '',
           lastName: '',
           birthDate: null,
           avatarUrl: null,
           userContact: '',
           phoneVerified: false,
           userCode: DemoData.demoUserCode,
           invitedByCode: null,
           points: DemoData.demoPoints,
           branches: DemoData.branches,
           selectedBranch: DemoData.branches.first,
           categories: DemoData.categories,
           products: DemoData.products,
           promotions: DemoData.promotions,
           newsStories: DemoData.newsStories,
           favoriteIds: DemoData.favoriteIds,
           cart: const [],
           useBonus: false,
           orders: const [],
           pointEvents: DemoData.pointEvents,
           recurring: null,
         ),
       );

  final ApiClient _api;
  final GoogleIdentityProvider _googleIdentity;
  final LanguagePreferenceStore _languagePreferences;
  final CartStore _cartStore;

  /// Токены сессии на устройстве: вход переживает перезапуск приложения.
  final AuthStore _authStore;
  static const languagePreferenceKey = 'app_language';
  static const themePreferenceKey = 'app_theme_mode';
  bool _bootstrapped = false;
  int _accountEpoch = 0;
  bool _authInProgress = false;
  bool _contactSaveInProgress = false;
  bool _favoritesSyncRunning = false;
  bool _favoritesSyncDirty = false;
  Completer<void>? _favoritesSyncCompleter;
  int _cartRevision = 0;
  bool _cartPersistRunning = false;
  bool _cartPersistDirty = false;
  Completer<void>? _cartPersistCompleter;
  int _recurringMutationRevision = 0;

  /// Однократная попытка подключиться к demo-API при старте (таймаут 2 с
  /// на запрос внутри [ApiClient]). При успехе подменяем каталог/филиалы и
  /// брендинг серверными данными; при любой ошибке молча остаёмся на
  /// [DemoData] — APK обязан работать автономно.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final cartRevision = _cartRevision;
    final cartDraftFuture = _readCartDraft();
    try {
      final savedLanguage = await _languagePreferences.readLanguageCode();
      final language = AppLanguage.values.where(
        (candidate) => candidate.locale.languageCode == savedLanguage,
      );
      if (language.isNotEmpty) {
        state = state.copyWith(language: language.first);
      }
      // Сохранённая тема (тёмная/светлая) — восстанавливаем при запуске.
      final savedTheme = await _languagePreferences.readThemeMode();
      if (savedTheme == 'dark' || savedTheme == 'light') {
        state = state.copyWith(
          themeMode: savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light,
        );
      }
    } catch (_) {
      // Настройки языка/темы не должны блокировать автономный запуск приложения.
    }
    await _loadCompanyData();
    await _restoreCart(cartDraftFuture, cartRevision);
    await _restoreSession();
  }

  Future<List<CartDraftItem>> _readCartDraft() async {
    try {
      return await _cartStore.read();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _restoreCart(
    Future<List<CartDraftItem>> cartDraftFuture,
    int revisionAtStart,
  ) async {
    final draft = await cartDraftFuture;
    if (revisionAtStart != _cartRevision || draft.isEmpty) return;

    final restored = <CartItem>[];
    for (final stored in draft) {
      if (stored.quantity <= 0 ||
          stored.quantity > 99 ||
          !DemoData.sugarLevels.contains(stored.sugarPercent)) {
        continue;
      }
      final product = state.products
          .where((candidate) => candidate.id == stored.productId)
          .firstOrNull;
      if (product == null) continue;
      final size = product.sizes
          .where((candidate) => candidate.id == stored.sizeId)
          .firstOrNull;
      if (size == null) continue;
      final ice = IceLevel.values
          .where((candidate) => candidate.name == stored.ice)
          .firstOrNull;
      if (ice == null) continue;

      final toppingIds = <String>[];
      var toppingPrice = 0;
      for (final toppingId in stored.toppingIds) {
        final topping = product.toppings
            .where((candidate) => candidate.id == toppingId)
            .firstOrNull;
        if (topping == null || toppingIds.contains(topping.id)) continue;
        toppingIds.add(topping.id);
        toppingPrice += topping.priceDelta;
      }
      final unitPrice = product.basePrice + size.priceDelta + toppingPrice;
      restored.add(
        CartItem(
          product: product,
          quantity: stored.quantity,
          sizeId: size.id,
          sugarPercent: stored.sugarPercent,
          ice: ice,
          toppingIds: List.unmodifiable(toppingIds),
          total: unitPrice * stored.quantity,
        ),
      );
    }

    if (revisionAtStart != _cartRevision) return;
    state = state.copyWith(cart: List.unmodifiable(restored), useBonus: false);
    await _queueCartPersist();
  }

  Future<void> _loadCompanyData() async {
    try {
      final config = await _api.fetchConfig();
      if (config == null) return; // сервер недоступен — остаёмся на демо
      final products = await _api.fetchProducts();
      final branches = await _api.fetchBranches();
      // Контент витрины из админки; при ошибке остаётся локальный demo.
      final news = await _api.fetchNews();
      final promotions = await _api.fetchPromotions();
      final catalogAuthoritative =
          products != null &&
          products.isNotEmpty &&
          branches != null &&
          branches.isNotEmpty;

      final nextProducts = (products == null || products.isEmpty)
          ? state.products
          : products;
      final nextBranches = (branches == null || branches.isEmpty)
          ? state.branches
          : branches;
      final selected = nextBranches.firstWhere(
        (b) => b.id == state.selectedBranch.id,
        orElse: () => nextBranches.first,
      );
      final categories = <MenuCategory>[];
      for (final product in nextProducts) {
        if (!categories.any((category) => category.id == product.category.id)) {
          categories.add(product.category);
        }
      }

      state = state.copyWith(
        apiConnected: true,
        catalogAuthoritative: catalogAuthoritative,
        appName: config.appName,
        accentColor: config.accentColor,
        loyaltyEarnRate: config.earnRate,
        loyaltyMaxSpendShare: config.maxSpendShare,
        products: nextProducts,
        branches: nextBranches,
        selectedBranch: selected,
        categories: categories.isEmpty ? state.categories : categories,
        // news/promotions от сервера; null или пусто — оставляем локальный demo
        newsStories: (news == null || news.isEmpty) ? state.newsStories : news,
        promotions: (promotions == null || promotions.isEmpty)
            ? state.promotions
            : promotions,
      );
    } catch (_) {
      // Любая неожиданная ошибка не должна ронять запуск приложения.
    }
  }

  /// Восстановление сессии по сохранённому токену: профиль живёт на сервере,
  /// поэтому вход переживает перезапуск и переустановку приложения.
  ///
  /// Токен протух -> пробуем refresh; refresh не принят -> чистим токены и
  /// остаёмся гостем. Сеть недоступна -> ничего не трогаем: офлайн не должен
  /// разлогинивать пользователя.
  Future<void> _restoreSession() async {
    final epoch = _accountEpoch;
    try {
      final accessToken = await _authStore.readAccessToken();
      if (epoch != _accountEpoch ||
          accessToken == null ||
          accessToken.isEmpty) {
        return;
      }

      var result = await _api.fetchCustomerMe(accessToken);
      if (result.isRejected) {
        final refreshed = await _refreshAccessToken();
        if (refreshed != null) result = await _api.fetchCustomerMe(refreshed);
      }
      if (epoch != _accountEpoch) return;
      switch (result.status) {
        case ApiAuthStatus.ok:
          _applyCustomerProfile(result.value!);
          await _loadCustomerFavorites();
          await _loadCustomerOrders();
          await _loadCustomerRecurring();
        case ApiAuthStatus.rejected:
          await _authStore.clear();
        case ApiAuthStatus.unavailable:
          break; // офлайн: состояние не меняем
      }
    } catch (_) {
      // Восстановление сессии не должно ронять запуск приложения.
    }
  }

  /// Новая пара токенов по refresh-токену. null — обновиться не удалось;
  /// при явном отказе сервера токены с устройства удаляются.
  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _authStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _authStore.clear();
      return null;
    }
    final result = await _api.refreshTokens(refreshToken);
    if (!result.isOk) {
      if (result.isRejected) await _authStore.clear();
      return null;
    }
    final tokens = result.value!;
    await _authStore.writeTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return tokens.accessToken;
  }

  /// Серверный профиль -> состояние приложения. Личные данные показываем
  /// такими, какими их хранит сервер, а не такими, какими их помнит устройство.
  void _applyCustomerProfile(CustomerProfile profile) {
    state = state.copyWith(
      isGuest: false,
      customerId: profile.id,
      firstName: profile.firstName,
      lastName: profile.lastName,
      birthDate: profile.birthDate,
      clearBirthDate: profile.birthDate == null,
      userContact: profile.phone ?? '',
      phoneVerified: profile.phoneVerified,
      points: profile.points,
      avatarUrl: profile.avatarUrl,
      clearAvatarUrl: profile.avatarUrl == null,
    );
  }

  Future<void> _loadCustomerFavorites() async {
    final epoch = _accountEpoch;
    final customerId = state.customerId;
    if (state.isGuest || customerId == null) return;
    final result = await _withCustomerToken(_api.fetchCustomerFavorites);
    if (!result.isOk) return;
    if (epoch != _accountEpoch ||
        state.isGuest ||
        state.customerId != customerId) {
      return;
    }
    state = state.copyWith(favoriteIds: List.unmodifiable(result.value!));
  }

  Future<void> _loadCustomerOrders() async {
    final epoch = _accountEpoch;
    final customerId = state.customerId;
    if (state.isGuest || customerId == null) return;
    final result = await _withCustomerToken(_api.fetchCustomerOrders);
    if (!result.isOk) return;
    if (epoch != _accountEpoch ||
        state.isGuest ||
        state.customerId != customerId) {
      return;
    }
    state = state.copyWith(orders: List.unmodifiable(result.value!));
  }

  Future<void> _loadCustomerRecurring() async {
    final epoch = _accountEpoch;
    final customerId = state.customerId;
    if (state.isGuest || customerId == null) return;
    final result = await _withCustomerToken(_api.fetchCustomerRecurring);
    if (!result.isOk) return;
    if (epoch != _accountEpoch ||
        state.isGuest ||
        state.customerId != customerId) {
      return;
    }
    final recurring = result.value;
    state = recurring == null
        ? state.copyWith(clearRecurring: true)
        : state.copyWith(recurring: recurring);
  }

  /// Вход по OTP работает только через backend. Публичного fallback с кодом
  /// 1111 нет: недоступный SMS/backend не должен создавать локальную сессию.
  Future<bool> loginWithOtp(String phone, String code) async {
    if (_authInProgress) return false;
    _authInProgress = true;
    final epoch = _accountEpoch;
    try {
      final result = await _api.otpVerify(phone, code);
      if (!result.isOk || epoch != _accountEpoch) return false;
      return _installCustomerSession(result.value!, epoch);
    } finally {
      _authInProgress = false;
    }
  }

  Future<bool> _installCustomerSession(
    CustomerSession session,
    int expectedEpoch,
  ) async {
    if (expectedEpoch != _accountEpoch) return false;
    try {
      await _authStore.writeTokens(
        accessToken: session.tokens.accessToken,
        refreshToken: session.tokens.refreshToken,
      );
    } catch (_) {
      return false;
    }
    if (expectedEpoch != _accountEpoch) {
      await _clearTokens();
      return false;
    }
    login(session.profile.phone ?? '');
    _applyCustomerProfile(session.profile);
    await _loadCustomerFavorites();
    await _loadCustomerOrders();
    await _loadCustomerRecurring();
    return true;
  }

  Future<GoogleLoginResult> loginWithGoogle() async {
    if (_authInProgress) return GoogleLoginResult.busy;
    _authInProgress = true;
    final epoch = _accountEpoch;
    try {
      final identity = await _googleIdentity.authenticate();
      if (epoch != _accountEpoch) {
        await _googleIdentity.signOut();
        return GoogleLoginResult.cancelled;
      }
      switch (identity.status) {
        case GoogleIdentityStatus.cancelled:
          return GoogleLoginResult.cancelled;
        case GoogleIdentityStatus.notConfigured:
          return GoogleLoginResult.notConfigured;
        case GoogleIdentityStatus.unavailable:
          return GoogleLoginResult.unavailable;
        case GoogleIdentityStatus.success:
          break;
      }

      final result = await _api.googleSignIn(identity.idToken!);
      if (epoch != _accountEpoch) {
        await _googleIdentity.signOut();
        return GoogleLoginResult.cancelled;
      }
      if (result.isRejected) {
        await _googleIdentity.signOut();
        return GoogleLoginResult.rejected;
      }
      if (!result.isOk) {
        await _googleIdentity.signOut();
        return GoogleLoginResult.unavailable;
      }
      final installed = await _installCustomerSession(result.value!, epoch);
      if (!installed) {
        await _googleIdentity.signOut();
        return GoogleLoginResult.unavailable;
      }
      return state.hasContactPhone
          ? GoogleLoginResult.success
          : GoogleLoginResult.needsContact;
    } finally {
      _authInProgress = false;
    }
  }

  Future<ContactSaveResult> saveContactPhone(String phone) async {
    if (_contactSaveInProgress) return ContactSaveResult.busy;
    if (!RegExp(r'^\+996\d{9}$').hasMatch(phone)) {
      return ContactSaveResult.rejected;
    }
    final epoch = _accountEpoch;
    final customerId = state.customerId;
    if (state.isGuest || customerId == null) {
      return ContactSaveResult.rejected;
    }
    _contactSaveInProgress = true;
    try {
      final result = await _withCustomerToken(
        (token) => _api.patchCustomerContact(token, phone),
      );
      if (epoch != _accountEpoch || state.customerId != customerId) {
        return ContactSaveResult.unavailable;
      }
      if (result.isRejected) return ContactSaveResult.rejected;
      if (!result.isOk) return ContactSaveResult.unavailable;
      _applyCustomerProfile(result.value!);
      return state.hasContactPhone
          ? ContactSaveResult.success
          : ContactSaveResult.unavailable;
    } finally {
      _contactSaveInProgress = false;
    }
  }

  Future<bool> requestOtp(String phone) async {
    try {
      return await _api.otpRequest(phone);
    } catch (_) {
      return false;
    }
  }

  /// POST заказа на сервер (если API доступен). null — офлайн/ошибка сети:
  /// заказ при этом уже оформлен локально, поведение прежнее.
  ///
  /// Сервер принимает заказ только по токену клиента (401 без него) и берёт имя
  /// заказчика из токена. Без токена (демо-вход офлайн) запрос ожидаемо не
  /// пройдёт — заказ останется локальным, как и раньше.
  Future<CreatedOrder?> submitOrder({
    required OrderType type,
    required String readyTime,
    required List<CartItem> items,
    required Branch branch,
    required int pointsUsed,
    PaymentMethod paymentMethod = PaymentMethod.mock,
  }) async {
    if (state.isGuest || items.isEmpty) return null;
    String? accessToken;
    try {
      accessToken = await _authStore.readAccessToken();
    } catch (_) {
      accessToken = null;
    }
    final created = await _api.createOrder(
      accessToken: accessToken,
      branchId: branch.id,
      type: switch (type) {
        OrderType.pickup => 'pickup',
        OrderType.scheduled => 'scheduled',
        OrderType.qrCafe => 'qr',
      },
      readyTime: readyTime,
      items: [
        for (final item in items)
          {
            'productId': item.product.id,
            'sizeId': item.sizeId,
            'toppingIds': item.toppingIds,
            'sugarPercent': item.sugarPercent,
            'ice': item.ice.name,
            'quantity': item.quantity,
          },
      ],
      paymentMethod: switch (paymentMethod) {
        PaymentMethod.mock => 'mock',
        PaymentMethod.cash => 'cash',
        PaymentMethod.qrDemo => 'qr',
      },
      pointsUsed: pointsUsed,
    );
    if (created != null && accessToken != null) {
      await _loadCustomerOrders();
    }
    return created;
  }

  void toggleTheme() {
    final next = state.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    state = state.copyWith(themeMode: next);
    unawaited(_persistTheme(next));
  }

  Future<void> _persistTheme(ThemeMode mode) async {
    try {
      await _languagePreferences.writeThemeMode(
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {
      // UI уже переключён; ошибка локального хранилища не должна ломать приложение.
    }
  }

  void setLanguage(AppLanguage language) {
    if (state.language == language) return;
    state = state.copyWith(language: language);
    unawaited(_persistLanguage(language));
  }

  Future<void> _persistLanguage(AppLanguage language) async {
    try {
      await _languagePreferences.writeLanguageCode(
        language.locale.languageCode,
      );
    } catch (_) {
      // UI уже переключён; ошибка локального хранилища не должна ломать приложение.
    }
  }

  void login(String phone) {
    _accountEpoch++;
    _favoritesSyncDirty = false;
    state = state.copyWith(
      isGuest: false,
      clearCustomerId: true,
      firstName: '',
      lastName: '',
      clearBirthDate: true,
      clearAvatarUrl: true,
      userContact: phone,
      phoneVerified: phone.trim().isNotEmpty,
      clearInvitedByCode: true,
      points: 0,
      favoriteIds: const [],
      orders: const [],
      pointEvents: const [],
      clearRecurring: true,
    );
  }

  void requestAuthentication(AuthReturnDestination destination) {
    state = state.copyWith(pendingAuthReturn: destination);
  }

  AuthReturnDestination? takePendingAuthReturn() {
    final destination = state.pendingAuthReturn;
    if (destination != null) {
      state = state.copyWith(clearPendingAuthReturn: true);
    }
    return destination;
  }

  void cancelAuthReturn() {
    if (state.pendingAuthReturn == null) return;
    state = state.copyWith(clearPendingAuthReturn: true);
  }

  /// Имя/фамилия/дата рождения. Локально применяем сразу (UI не ждёт сеть),
  /// затем сохраняем на сервере — там профиль переживает переустановку.
  /// Аватар загружается отдельно multipart-запросом в [uploadAvatar].
  void updateProfile({
    required String firstName,
    required String lastName,
    DateTime? birthDate,
    bool clearBirthDate = false,
  }) {
    state = state.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      birthDate: birthDate,
      clearBirthDate: clearBirthDate,
    );
    unawaited(
      _syncProfileToServer(
        firstName: state.firstName,
        lastName: state.lastName,
        birthDate: state.birthDate,
      ),
    );
  }

  /// Аватар хранится на сервере. Локальный путь image_picker используется
  /// только для предпросмотра и никогда не становится данными профиля.
  Future<bool> uploadAvatar({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final result = await _withCustomerToken(
      (token) => _api.uploadCustomerAvatar(
        token,
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      ),
    );
    if (!result.isOk) return false;
    _applyCustomerProfile(result.value!);
    return true;
  }

  Future<bool> deleteAvatar() async {
    final result = await _withCustomerToken(_api.deleteCustomerAvatar);
    if (!result.isOk) return false;
    state = state.copyWith(clearAvatarUrl: true);
    return true;
  }

  Future<ApiResult<T>> _withCustomerToken<T>(
    Future<ApiResult<T>> Function(String token) request,
  ) async {
    try {
      var token = await _authStore.readAccessToken();
      if (token == null || token.isEmpty) {
        return ApiResult<T>.unavailable();
      }
      var result = await request(token);
      if (result.isRejected) {
        token = await _refreshAccessToken();
        if (token == null) return ApiResult<T>.rejected();
        result = await request(token);
      }
      return result;
    } catch (_) {
      return ApiResult<T>.unavailable();
    }
  }

  /// `PATCH auth/customer/me`. Без токена (демо-вход офлайн) — тихо выходим:
  /// локальное изменение уже применено. Ответ сервера считаем истиной.
  Future<void> _syncProfileToServer({
    required String firstName,
    required String lastName,
    required DateTime? birthDate,
  }) async {
    try {
      final token = await _authStore.readAccessToken();
      if (token == null || token.isEmpty) return;
      // Пустая строка = очистить дату на сервере (контракт customer/me).
      final isoBirthDate = birthDate == null ? '' : _isoDate(birthDate);
      var result = await _api.patchCustomerMe(
        token,
        firstName: firstName,
        lastName: lastName,
        birthDate: isoBirthDate,
      );
      if (result.isRejected) {
        final refreshed = await _refreshAccessToken();
        if (refreshed == null) return;
        result = await _api.patchCustomerMe(
          refreshed,
          firstName: firstName,
          lastName: lastName,
          birthDate: isoBirthDate,
        );
      }
      if (result.isOk) _applyCustomerProfile(result.value!);
    } catch (_) {
      // Офлайн: локальные данные остаются, сервер догонит при следующем сохранении.
    }
  }

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void logout() {
    _accountEpoch++;
    _favoritesSyncDirty = false;
    unawaited(_clearTokens());
    unawaited(_googleIdentity.signOut());
    state = state.copyWith(
      isGuest: true,
      clearCustomerId: true,
      firstName: '',
      lastName: '',
      clearBirthDate: true,
      clearAvatarUrl: true,
      userContact: '',
      phoneVerified: false,
      clearPendingAuthReturn: true,
      clearInvitedByCode: true,
      points: 0,
      favoriteIds: const [],
      orders: const [],
      pointEvents: const [],
      clearRecurring: true,
    );
    _cartRevision++;
    unawaited(_queueCartPersist());
  }

  /// Токены с устройства убираем всегда, даже если хранилище ругнулось:
  /// иначе следующий запуск восстановит «выключённую» сессию.
  Future<void> _clearTokens() async {
    try {
      await _authStore.clear();
    } catch (_) {
      // Хранилище недоступно — сессия всё равно уже сброшена в состоянии.
    }
  }

  Future<void> deleteAccount() async {
    // Серверного удаления аккаунта ещё нет: убираем токены, чтобы устройство
    // не восстановило сессию, и чистим локальные данные, как раньше.
    _accountEpoch++;
    _favoritesSyncDirty = false;
    unawaited(_clearTokens());
    unawaited(_googleIdentity.signOut());
    state = state.copyWith(
      isGuest: true,
      clearCustomerId: true,
      firstName: '',
      lastName: '',
      clearBirthDate: true,
      clearAvatarUrl: true,
      userContact: '',
      phoneVerified: false,
      clearPendingAuthReturn: true,
      clearInvitedByCode: true,
      points: 0,
      favoriteIds: const [],
      cart: const [],
      useBonus: false,
      orders: const [],
      pointEvents: const [],
      clearRecurring: true,
    );
    _cartRevision++;
    await _queueCartPersist();
  }

  void selectBranch(Branch branch) {
    state = state.copyWith(selectedBranch: branch);
  }

  Future<void> toggleFavorite(Product product) async {
    final ids = [...state.favoriteIds];
    if (ids.contains(product.id)) {
      ids.remove(product.id);
    } else {
      ids.add(product.id);
    }
    state = state.copyWith(favoriteIds: ids);
    if (state.isGuest || state.customerId == null) return;
    await _queueFavoritesSync();
  }

  Future<void> _queueFavoritesSync() {
    _favoritesSyncDirty = true;
    final completer = _favoritesSyncCompleter ??= Completer<void>();
    if (!_favoritesSyncRunning) unawaited(_drainFavoritesSync());
    return completer.future;
  }

  Future<void> _drainFavoritesSync() async {
    if (_favoritesSyncRunning) return;
    _favoritesSyncRunning = true;
    try {
      while (_favoritesSyncDirty) {
        _favoritesSyncDirty = false;
        final epoch = _accountEpoch;
        final customerId = state.customerId;
        if (state.isGuest || customerId == null) continue;
        final requestedIds = List<String>.unmodifiable(state.favoriteIds);
        final result = await _withCustomerToken(
          (token) => _api.replaceCustomerFavorites(token, requestedIds),
        );
        if (!result.isOk ||
            epoch != _accountEpoch ||
            state.isGuest ||
            state.customerId != customerId ||
            !listEquals(state.favoriteIds, requestedIds)) {
          continue;
        }
        state = state.copyWith(favoriteIds: List.unmodifiable(result.value!));
      }
    } finally {
      _favoritesSyncRunning = false;
      final completer = _favoritesSyncCompleter;
      _favoritesSyncCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  Future<bool> quickAdd(Product product) async {
    if (!product.availableIn(state.selectedBranch) || product.sizes.isEmpty) {
      return false;
    }

    final size = product.sizes.firstWhere(
      (option) => option.id == 'm',
      orElse: () => product.sizes.first,
    );
    final topping = product.toppings
        .where((option) => option.id == 'tapioca')
        .firstOrNull;

    return addConfigured(
      product,
      sizeId: size.id,
      sugarPercent: 50,
      ice: IceLevel.regular,
      toppingIds: topping == null ? const [] : [topping.id],
    );
  }

  Future<bool> addConfigured(
    Product product, {
    required String sizeId,
    required int sugarPercent,
    required IceLevel ice,
    required List<String> toppingIds,
  }) async {
    final currentProduct = state.products
        .where((candidate) => candidate.id == product.id)
        .firstOrNull;
    if (currentProduct == null ||
        !currentProduct.availableIn(state.selectedBranch) ||
        !DemoData.sugarLevels.contains(sugarPercent) ||
        toppingIds.length != toppingIds.toSet().length) {
      return false;
    }
    final size = currentProduct.sizes
        .where((candidate) => candidate.id == sizeId)
        .firstOrNull;
    if (size == null) return false;
    var toppingPrice = 0;
    for (final toppingId in toppingIds) {
      final topping = currentProduct.toppings
          .where((candidate) => candidate.id == toppingId)
          .firstOrNull;
      if (topping == null) return false;
      toppingPrice += topping.priceDelta;
    }
    final item = CartItem(
      product: currentProduct,
      quantity: 1,
      sizeId: size.id,
      sugarPercent: sugarPercent,
      ice: ice,
      toppingIds: List.unmodifiable(toppingIds),
      total: currentProduct.basePrice + size.priceDelta + toppingPrice,
    );
    state = state.copyWith(cart: [...state.cart, item]);
    _cartRevision++;
    await _queueCartPersist();
    return true;
  }

  Future<void> updateQuantity(int index, int delta) async {
    final cart = [...state.cart];
    final item = cart[index];
    final unitPrice = (item.total / item.quantity).round();
    final nextQty = item.quantity + delta;
    if (nextQty <= 0) {
      cart.removeAt(index);
    } else {
      cart[index] = item.copyWith(
        quantity: nextQty,
        total: unitPrice * nextQty,
      );
    }
    state = state.copyWith(cart: cart);
    _cartRevision++;
    await _queueCartPersist();
  }

  Future<void> removeFromCart(int index) async {
    final cart = [...state.cart]..removeAt(index);
    state = state.copyWith(cart: cart);
    _cartRevision++;
    await _queueCartPersist();
  }

  void setUseBonus(bool value) {
    state = state.copyWith(useBonus: value);
  }

  CustomerOrder? checkout({
    required OrderType type,
    required OrderReadyTime readyTime,
    required PaymentMethod paymentMethod,
  }) {
    if (state.isGuest || state.cart.isEmpty) return null;

    final pointsUsed = state.bonusApplied;
    final earned = state.pointsEarned;
    final order = CustomerOrder(
      id: 'SW-${1049 + state.orders.length + 1}',
      items: state.cart,
      branch: state.selectedBranch,
      type: type,
      status: OrderStatus.preparing,
      paymentMethod: paymentMethod,
      readyTime: readyTime,
      total: state.total,
      pointsUsed: pointsUsed,
      pointsEarned: earned,
    );
    state = state.copyWith(
      cart: const [],
      useBonus: false,
      orders: [OrderHistoryEntry.fromLocal(order), ...state.orders],
      points: state.points - pointsUsed + earned,
      pointEvents: [
        PointEvent(
          title: LocalizedText(
            ru: 'Начисление за ${order.id}',
            ky: '${order.id} үчүн упай кошулду',
            en: 'Points earned for ${order.id}',
          ),
          amount: earned,
          date: const LocalizedText(ru: 'Сегодня', ky: 'Бүгүн', en: 'Today'),
        ),
        if (pointsUsed > 0)
          PointEvent(
            title: LocalizedText(
              ru: 'Списание за ${order.id}',
              ky: '${order.id} үчүн упай алынды',
              en: 'Points redeemed for ${order.id}',
            ),
            amount: -pointsUsed,
            date: const LocalizedText(ru: 'Сегодня', ky: 'Бүгүн', en: 'Today'),
          ),
        ...state.pointEvents,
      ],
    );
    _cartRevision++;
    unawaited(_queueCartPersist());
    return order;
  }

  Future<RepeatOrderResult> repeatOrder(OrderHistoryEntry order) async {
    if (!order.supportsExactRepeat) return RepeatOrderResult.legacyOrder;
    if (!state.catalogAuthoritative) {
      return RepeatOrderResult.catalogUnavailable;
    }

    final repeatedItems = <CartItem>[];
    for (final item in order.items) {
      final productId = item.productId;
      final sizeId = item.sizeId;
      final toppingIds = item.toppingIds;
      final sugarPercent = item.sugarPercent;
      final ice = item.ice;
      if (productId == null ||
          sizeId == null ||
          toppingIds == null ||
          sugarPercent == null ||
          ice == null) {
        return RepeatOrderResult.unavailableSelection;
      }
      final product = state.products
          .where((candidate) => candidate.id == productId)
          .firstOrNull;
      if (product == null || !product.availableIn(state.selectedBranch)) {
        return RepeatOrderResult.unavailableSelection;
      }
      final size = product.sizes
          .where((candidate) => candidate.id == sizeId)
          .firstOrNull;
      if (size == null || toppingIds.length != toppingIds.toSet().length) {
        return RepeatOrderResult.unavailableSelection;
      }

      var toppingPrice = 0;
      for (final toppingId in toppingIds) {
        final topping = product.toppings
            .where((candidate) => candidate.id == toppingId)
            .firstOrNull;
        if (topping == null) return RepeatOrderResult.unavailableSelection;
        toppingPrice += topping.priceDelta;
      }
      final unitPrice = product.basePrice + size.priceDelta + toppingPrice;
      repeatedItems.add(
        CartItem(
          product: product,
          quantity: item.quantity,
          sizeId: size.id,
          sugarPercent: sugarPercent,
          ice: ice,
          toppingIds: List.unmodifiable(toppingIds),
          total: unitPrice * item.quantity,
        ),
      );
    }

    state = state.copyWith(cart: [...state.cart, ...repeatedItems]);
    _cartRevision++;
    await _queueCartPersist();
    return RepeatOrderResult.success;
  }

  Future<void> _queueCartPersist() {
    _cartPersistDirty = true;
    final completer = _cartPersistCompleter ??= Completer<void>();
    if (!_cartPersistRunning) unawaited(_drainCartPersist());
    return completer.future;
  }

  Future<void> _drainCartPersist() async {
    if (_cartPersistRunning) return;
    _cartPersistRunning = true;
    try {
      while (_cartPersistDirty) {
        _cartPersistDirty = false;
        final snapshot = List<CartDraftItem>.unmodifiable([
          for (final item in state.cart)
            CartDraftItem(
              productId: item.product.id,
              quantity: item.quantity,
              sizeId: item.sizeId,
              sugarPercent: item.sugarPercent,
              ice: item.ice.name,
              toppingIds: List.unmodifiable(item.toppingIds),
            ),
        ]);
        try {
          await _cartStore.write(snapshot);
        } catch (_) {
          // Корзина уже обновлена в UI; временная ошибка локального хранилища
          // не должна ломать покупки в текущей сессии.
        }
      }
    } finally {
      _cartPersistRunning = false;
      final completer = _cartPersistCompleter;
      _cartPersistCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  /// Постоянный заказ с demo-предоплатой. Состояние меняется только после
  /// подтверждения API: это платный server-scoped объект, а не локальный draft.
  Future<bool> setRecurring({
    required List<Product> products,
    required String time,
    required Branch branch,
    required RecurringPlan plan,
  }) async {
    if (state.isGuest ||
        !state.catalogAuthoritative ||
        products.isEmpty ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      return false;
    }
    final currentBranch = state.branches
        .where((candidate) => candidate.id == branch.id)
        .firstOrNull;
    if (currentBranch == null) return false;
    final productIds = <String>[];
    for (final requested in products) {
      final currentProduct = state.products
          .where((candidate) => candidate.id == requested.id)
          .firstOrNull;
      if (currentProduct == null ||
          !currentProduct.availableIn(currentBranch) ||
          productIds.contains(currentProduct.id)) {
        return false;
      }
      productIds.add(currentProduct.id);
    }

    final epoch = _accountEpoch;
    final mutationRevision = ++_recurringMutationRevision;
    final customerId = state.customerId;
    if (customerId == null) return false;
    final result = await _withCustomerToken(
      (token) => _api.replaceCustomerRecurring(
        token,
        productIds: productIds,
        time: time,
        branchId: currentBranch.id,
        plan: plan,
      ),
    );
    final recurring = result.value;
    if (!result.isOk ||
        recurring == null ||
        mutationRevision != _recurringMutationRevision ||
        epoch != _accountEpoch ||
        state.isGuest ||
        state.customerId != customerId) {
      return false;
    }
    state = state.copyWith(recurring: recurring);
    return true;
  }

  Future<bool> cancelRecurring() async {
    if (state.isGuest || state.recurring == null) return false;
    final epoch = _accountEpoch;
    final mutationRevision = ++_recurringMutationRevision;
    final customerId = state.customerId;
    if (customerId == null) return false;
    final result = await _withCustomerToken(_api.deleteCustomerRecurring);
    if (!result.isOk ||
        mutationRevision != _recurringMutationRevision ||
        epoch != _accountEpoch ||
        state.isGuest ||
        state.customerId != customerId) {
      return false;
    }
    state = state.copyWith(clearRecurring: true);
    return true;
  }

  /// Привязка по коду друга. Правила анти-накрутки — docs/design/REFERRAL_LOGIC.md:
  /// один пригласивший навсегда; только новый клиент (без выполненных заказов);
  /// нельзя пригласить себя; +100 пригласившему — после первого заказа.
  ReferralResult applyReferral(String rawCode) {
    final code = rawCode.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) return ReferralResult.invalidCode;
    if (code == state.userCode) return ReferralResult.selfCode;
    if (state.invitedByCode != null) return ReferralResult.alreadyInvited;
    if (state.orders.isNotEmpty) return ReferralResult.notNewUser;

    state = state.copyWith(
      invitedByCode: code,
      points: state.points + Referral.invitedBonus,
      pointEvents: [
        PointEvent(
          title: LocalizedText(
            ru: 'Бонус за приглашение (код ${code.substring(0, 3)} ${code.substring(3)})',
            ky: 'Чакыруу бонусу (код ${code.substring(0, 3)} ${code.substring(3)})',
            en: 'Invitation bonus (code ${code.substring(0, 3)} ${code.substring(3)})',
          ),
          amount: Referral.invitedBonus,
          date: const LocalizedText(ru: 'Сегодня', ky: 'Бүгүн', en: 'Today'),
        ),
        ...state.pointEvents,
      ],
    );
    return ReferralResult.success;
  }

  /// Демо-наполнение для превью/скриншотов (по query-параметру `?seed=`), в проде не вызывается.
  void seedDemo({
    bool auth = false,
    bool cart = false,
    bool history = false,
    bool recurring = false,
  }) {
    var next = state;
    if (auth) {
      next = next.copyWith(
        isGuest: false,
        firstName: DemoData.demoUserFirstName,
        lastName: DemoData.demoUserLastName,
        clearBirthDate: true,
        clearAvatarUrl: true,
        userContact: DemoData.demoUserPhone,
        phoneVerified: true,
      );
    }
    if (cart) {
      final p1 = DemoData.products[0];
      final p3 = DemoData.products[2];
      next = next.copyWith(
        cart: [
          CartItem(
            product: p1,
            quantity: 1,
            sizeId: 'm',
            sugarPercent: 50,
            ice: IceLevel.regular,
            toppingIds: const ['tapioca'],
            total: p1.basePrice + 50,
          ),
          CartItem(
            product: p3,
            quantity: 1,
            sizeId: 'l',
            sugarPercent: 30,
            ice: IceLevel.less,
            toppingIds: const ['coffee-jelly'],
            total: p3.basePrice + 50 + 45,
          ),
        ],
        useBonus: true,
      );
    }
    if (history) {
      next = next.copyWith(
        orders: [
          OrderHistoryEntry.fromLocal(
            CustomerOrder(
              id: 'SW-1048',
              items: [
                CartItem(
                  product: DemoData.products[0],
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
              paymentMethod: PaymentMethod.mock,
              readyTime: const OrderReadyTime(kind: OrderReadyTimeKind.asap),
              total: 640,
              pointsUsed: 0,
              pointsEarned: 32,
            ),
          ),
          OrderHistoryEntry.fromLocal(
            CustomerOrder(
              id: 'SW-1031',
              items: [
                CartItem(
                  product: DemoData.products[2],
                  quantity: 1,
                  sizeId: 'm',
                  sugarPercent: 30,
                  ice: IceLevel.regular,
                  toppingIds: const [],
                  total: 700,
                ),
              ],
              branch: DemoData.branches[1],
              type: OrderType.scheduled,
              status: OrderStatus.completed,
              paymentMethod: PaymentMethod.cash,
              readyTime: const OrderReadyTime(
                kind: OrderReadyTimeKind.scheduled,
                value: '11:00',
              ),
              total: 700,
              pointsUsed: 0,
              pointsEarned: 35,
            ),
          ),
        ],
      );
    }
    if (recurring) {
      next = next.copyWith(
        recurring: RecurringOrder(
          productIds: [DemoData.products[0].id],
          time: '11:00',
          branchId: DemoData.branches.first.id,
          plan: RecurringPlan.week,
          paidUntil: DateTime.now().add(const Duration(days: 7)),
        ),
      );
    }
    state = next;
  }
}

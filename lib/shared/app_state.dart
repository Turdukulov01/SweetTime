import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/auth_store.dart';
import '../core/cart_store.dart';
import '../core/branding_store.dart';
import '../core/google_identity.dart';
import '../core/order_history_store.dart';
import '../core/story_view_store.dart';
import '../core/theme/app_theme.dart';
import 'app_models.dart';
import 'demo_data.dart';

final initialBrandingProvider = Provider<CompanyConfig?>((ref) => null);

final appStateProvider = StateNotifierProvider<AppStateController, AppState>((
  ref,
) {
  return AppStateController(
    initialBranding: ref.watch(initialBrandingProvider),
  );
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

enum AccountDeletionResult { success, rejected, unavailable, busy }

enum CustomerHistoryRefreshResult { success, unavailable, sessionExpired }

enum CustomerSessionResumeResult { active, unavailable, sessionExpired, none }

ApiResult<T> _resultWithoutValue<T>(ApiAuthStatus status) => switch (status) {
  ApiAuthStatus.ok => throw StateError('An ok result must carry a value.'),
  ApiAuthStatus.rejected => ApiResult<T>.rejected(),
  ApiAuthStatus.invalid => ApiResult<T>.invalid(),
  ApiAuthStatus.unavailable => ApiResult<T>.unavailable(),
};

abstract interface class LanguagePreferenceStore {
  Future<String?> readLanguageCode();
  Future<void> writeLanguageCode(String code);
  Future<String?> readThemeMode();
  Future<void> writeThemeMode(String value);
  Future<String?> readBackgroundOverride();
  Future<void> writeBackgroundOverride(String? value);
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

  @override
  Future<String?> readBackgroundOverride() =>
      _instance.getString(AppStateController.backgroundOverridePreferenceKey);

  @override
  Future<void> writeBackgroundOverride(String? value) async {
    final key = AppStateController.backgroundOverridePreferenceKey;
    if (value == null) {
      await _instance.remove(key);
    } else {
      await _instance.setString(key, value);
    }
  }
}

@immutable
class AppState {
  const AppState({
    required this.apiConnected,
    required this.catalogAuthoritative,
    required this.appName,
    required this.accentColor,
    required this.logoUrl,
    required this.logoThumbnailUrl,
    required this.backgroundTheme,
    this.backgroundOverride,
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
    required this.storyCollections,
    required this.newsPosts,
    required this.viewedStoryIds,
    required this.favoriteIds,
    required this.cart,
    required this.useBonus,
    required this.bonusPointsToUse,
    required this.promoCode,
    required this.orders,
    required this.hiddenOrderIds,
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
  final String? logoUrl;
  final String? logoThumbnailUrl;

  /// Фон компании из админки (сервер) — общий для всех клиентов.
  final BrandBackgroundTheme backgroundTheme;

  /// Локальный выбор фона юзером — перекрывает серверный (как тема/язык):
  /// `null` — «как в приложении» (следует за админкой, меняется вместе с ней);
  /// `'off'` — фон выключен совсем (только базовая заливка);
  /// `'plain'|'bubbles'|'coffee'` — свой узор.
  /// Если юзер выбрал своё или выключил, смена фона в админке его не трогает.
  final String? backgroundOverride;

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
  final List<StoryCollection> storyCollections;
  final List<NewsPost> newsPosts;
  final Set<String> viewedStoryIds;
  final List<String> favoriteIds;
  final List<CartItem> cart;
  final bool useBonus;
  final int bonusPointsToUse;
  final String? promoCode;
  final List<OrderHistoryEntry> orders;
  final Set<String> hiddenOrderIds;

  List<OrderHistoryEntry> get visibleOrders => orders
      .where((order) => !hiddenOrderIds.contains(order.id))
      .toList(growable: false);
  final List<PointEvent> pointEvents;
  final RecurringOrder? recurring;

  int get cartCount => cart.fold(0, (sum, item) => sum + item.quantity);

  int get subtotal => cart.fold(0, (sum, item) => sum + item.total);

  /// Баллами можно оплатить до 30% заказа, 1 балл = 1 сом.
  int get maxBonusSpend {
    final cap = (subtotal * loyaltyMaxSpendShare).floor();
    return points < cap ? points : cap;
  }

  int get bonusApplied {
    if (!useBonus || maxBonusSpend <= 0) return 0;
    return bonusPointsToUse.clamp(0, maxBonusSpend);
  }

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
    String? logoUrl,
    String? logoThumbnailUrl,
    BrandBackgroundTheme? backgroundTheme,
    String? backgroundOverride,
    bool clearBackgroundOverride = false,
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
    String? userCode,
    String? invitedByCode,
    int? points,
    List<Branch>? branches,
    Branch? selectedBranch,
    List<MenuCategory>? categories,
    List<Product>? products,
    List<Promotion>? promotions,
    List<NewsStory>? newsStories,
    List<StoryCollection>? storyCollections,
    List<NewsPost>? newsPosts,
    Set<String>? viewedStoryIds,
    List<String>? favoriteIds,
    List<CartItem>? cart,
    bool? useBonus,
    int? bonusPointsToUse,
    String? promoCode,
    List<OrderHistoryEntry>? orders,
    Set<String>? hiddenOrderIds,
    List<PointEvent>? pointEvents,
    RecurringOrder? recurring,
    bool clearBirthDate = false,
    bool clearAvatarUrl = false,
    bool clearCustomerId = false,
    bool clearInvitedByCode = false,
    bool clearPendingAuthReturn = false,
    bool clearRecurring = false,
    bool clearPromoCode = false,
    bool clearLogo = false,
  }) {
    return AppState(
      apiConnected: apiConnected ?? this.apiConnected,
      catalogAuthoritative: catalogAuthoritative ?? this.catalogAuthoritative,
      appName: appName ?? this.appName,
      accentColor: accentColor ?? this.accentColor,
      logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
      logoThumbnailUrl: clearLogo
          ? null
          : (logoThumbnailUrl ?? this.logoThumbnailUrl),
      backgroundTheme: backgroundTheme ?? this.backgroundTheme,
      backgroundOverride: clearBackgroundOverride
          ? null
          : (backgroundOverride ?? this.backgroundOverride),
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
      userCode: userCode ?? this.userCode,
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
      storyCollections: storyCollections ?? this.storyCollections,
      newsPosts: newsPosts ?? this.newsPosts,
      viewedStoryIds: viewedStoryIds ?? this.viewedStoryIds,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      cart: cart ?? this.cart,
      useBonus: useBonus ?? this.useBonus,
      bonusPointsToUse: bonusPointsToUse ?? this.bonusPointsToUse,
      promoCode: clearPromoCode ? null : (promoCode ?? this.promoCode),
      orders: orders ?? this.orders,
      hiddenOrderIds: hiddenOrderIds ?? this.hiddenOrderIds,
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
    OrderHistoryVisibilityStore? orderHistoryVisibilityStore,
    StoryViewStore? storyViewStore,
    ApiClient? api,
    GoogleIdentityProvider? googleIdentity,
    CompanyConfig? initialBranding,
    BrandingStore? brandingStore,
  }) : _languagePreferences =
           languagePreferences ?? SharedPreferencesLanguagePreferenceStore(),
       _authStore = authStore ?? SecureAuthStore(),
       _cartStore =
           cartStore ??
           SharedPreferencesCartStore(companyId: api?.companyId ?? 'sweettime'),
       _orderHistoryVisibilityStore =
           orderHistoryVisibilityStore ??
           SharedPreferencesOrderHistoryVisibilityStore(
             companyId: api?.companyId ?? 'sweettime',
           ),
       _storyViewStore =
           storyViewStore ??
           SharedPreferencesStoryViewStore(
             companyId: api?.companyId ?? 'sweettime',
           ),
       _api = api ?? ApiClient(),
       _googleIdentity = googleIdentity ?? PluginGoogleIdentityProvider(),
       _brandingStore =
           brandingStore ??
           SharedPreferencesBrandingStore(
             companyId: api?.companyId ?? 'sweettime',
           ),
       super(
         AppState(
           apiConnected: false,
           catalogAuthoritative: false,
           appName: initialBranding?.appName ?? 'SweetTime',
           accentColor: initialBranding?.accentColor ?? AppColors.candy500,
           logoUrl: initialBranding?.logoUrl,
           logoThumbnailUrl: initialBranding?.logoThumbnailUrl,
           backgroundTheme:
               initialBranding?.backgroundTheme ?? const BrandBackgroundTheme(),
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
           storyCollections: DemoData.storyCollections,
           newsPosts: DemoData.newsPosts,
           viewedStoryIds: const {},
           favoriteIds: DemoData.favoriteIds,
           cart: const [],
           useBonus: false,
           bonusPointsToUse: 0,
           promoCode: null,
           orders: const [],
           hiddenOrderIds: const {},
           pointEvents: DemoData.pointEvents,
           recurring: null,
         ),
       );

  final ApiClient _api;
  final GoogleIdentityProvider _googleIdentity;
  final LanguagePreferenceStore _languagePreferences;
  final CartStore _cartStore;
  final OrderHistoryVisibilityStore _orderHistoryVisibilityStore;
  final StoryViewStore _storyViewStore;
  final BrandingStore _brandingStore;

  /// Токены сессии на устройстве: вход переживает перезапуск приложения.
  final AuthStore _authStore;
  static const languagePreferenceKey = 'app_language';
  static const themePreferenceKey = 'app_theme_mode';
  static const backgroundOverridePreferenceKey = 'app_background_override';
  bool _bootstrapped = false;
  int _accountEpoch = 0;
  bool _authInProgress = false;
  bool _contactSaveInProgress = false;
  bool _accountDeletionInProgress = false;
  bool _favoritesSyncRunning = false;
  bool _favoritesSyncDirty = false;
  Completer<void>? _favoritesSyncCompleter;
  Future<ApiResult<String>>? _tokenRefreshInFlight;
  Future<CustomerSessionResumeResult>? _sessionResumeInFlight;
  Future<void>? _companyRefreshInFlight;
  DateTime? _lastCompanyRefreshAt;
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
    final hiddenOrderIdsFuture = _readHiddenOrderIds();
    final viewedStoryIdsFuture = _readViewedStoryIds();
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
      // Личный выбор фона (перекрывает админский). Отсутствие ключа = «как в
      // приложении», поэтому смена фона в админке подхватится автоматически.
      final savedBackground = await _languagePreferences
          .readBackgroundOverride();
      if (savedBackground != null && savedBackground.isNotEmpty) {
        state = state.copyWith(backgroundOverride: savedBackground);
      }
    } catch (_) {
      // Настройки языка/темы/фона не должны блокировать автономный запуск.
    }
    await refreshCompanyData(force: true);
    await _restoreCart(cartDraftFuture, cartRevision);
    final hiddenOrderIds = await hiddenOrderIdsFuture;
    final viewedStoryIds = await viewedStoryIdsFuture;
    state = state.copyWith(
      hiddenOrderIds: hiddenOrderIds,
      viewedStoryIds: viewedStoryIds,
    );
    await _restoreSession();
  }

  Future<Set<String>> _readHiddenOrderIds() async {
    try {
      return await _orderHistoryVisibilityStore.readHiddenOrderIds();
    } catch (_) {
      return const {};
    }
  }

  Future<Set<String>> _readViewedStoryIds() async {
    try {
      return await _storyViewStore.readViewedStoryIds();
    } catch (_) {
      return const {};
    }
  }

  /// Records a story as viewed as soon as it becomes the active full-screen
  /// story. The ring is device-local UI state and does not require a login.
  Future<void> markStoryViewed(String storyId) async {
    final normalized = storyId.trim();
    if (normalized.isEmpty || state.viewedStoryIds.contains(normalized)) return;
    final viewed = Set<String>.of(state.viewedStoryIds)..add(normalized);
    state = state.copyWith(viewedStoryIds: Set.unmodifiable(viewed));
    try {
      await _storyViewStore.writeViewedStoryIds(viewed);
    } catch (_) {
      // A preferences failure must not interrupt story playback.
    }
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
      final size = product.sizes.isEmpty
          ? null
          : product.sizes
                .where((candidate) => candidate.id == stored.sizeId)
                .firstOrNull;
      if (product.sizes.isNotEmpty && size == null) continue;
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
      final unitPrice =
          product.basePrice + (size?.priceDelta ?? 0) + toppingPrice;
      restored.add(
        CartItem(
          product: product,
          quantity: stored.quantity,
          sizeId: size?.id,
          sugarPercent: stored.sugarPercent,
          ice: ice,
          toppingIds: List.unmodifiable(toppingIds),
          total: unitPrice * stored.quantity,
        ),
      );
    }

    if (revisionAtStart != _cartRevision) return;
    state = state.copyWith(
      cart: List.unmodifiable(restored),
      useBonus: false,
      bonusPointsToUse: 0,
    );
    await _queueCartPersist();
  }

  /// Обновляет управляемый из админки контент.
  ///
  /// Параллельные запросы объединяются, а автоматическое обновление после
  /// возврата в приложение ограничено одним разом в 30 секунд. Явный pull to
  /// refresh использует [force] и всегда обращается к серверу.
  Future<void> refreshCompanyData({bool force = false}) {
    final active = _companyRefreshInFlight;
    if (active != null) return active;

    final lastRefresh = _lastCompanyRefreshAt;
    if (!force &&
        lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < const Duration(seconds: 30)) {
      return Future<void>.value();
    }

    late final Future<void> operation;
    operation = _loadCompanyData()
        .then((loaded) {
          if (loaded) _lastCompanyRefreshAt = DateTime.now();
        })
        .whenComplete(() {
          if (identical(_companyRefreshInFlight, operation)) {
            _companyRefreshInFlight = null;
          }
        });
    _companyRefreshInFlight = operation;
    return operation;
  }

  Future<bool> _loadCompanyData() async {
    try {
      final config = await _api.fetchConfig();
      if (config == null) return false; // сервер недоступен — сохраняем UI
      final products = await _api.fetchProducts();
      final branches = await _api.fetchBranches();
      // null означает ошибку сети; пустой список — валидное состояние админки.
      final homeStories = await _api.fetchHomeStories();
      final legacyNews = homeStories == null ? await _api.fetchNews() : null;
      final collections = await _api.fetchStoryCollections();
      final newsPosts = await _api.fetchNewsPosts();
      final promotions = await _api.fetchPromotions();
      final catalogAuthoritative =
          products != null && branches != null && branches.isNotEmpty;

      final nextProducts = products ?? state.products;
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

      final nextPromotions = promotions ?? state.promotions;
      final appliedPromo = state.promoCode;
      final promoStillActive =
          appliedPromo == null ||
          nextPromotions.any(
            (promotion) => promotion.code.trim().toUpperCase() == appliedPromo,
          );

      state = state.copyWith(
        apiConnected: true,
        catalogAuthoritative: catalogAuthoritative,
        appName: config.appName,
        accentColor: config.accentColor,
        logoUrl: config.logoUrl,
        logoThumbnailUrl: config.logoThumbnailUrl,
        backgroundTheme: config.backgroundTheme,
        clearLogo: config.logoUrl == null && config.logoThumbnailUrl == null,
        loyaltyEarnRate: config.earnRate,
        loyaltyMaxSpendShare: config.maxSpendShare,
        products: nextProducts,
        branches: nextBranches,
        selectedBranch: selected,
        categories: products == null ? state.categories : categories,
        newsStories: homeStories != null
            ? selectHomeStories(homeStories)
            : legacyNews != null
            ? selectHomeStories(legacyNews)
            : state.newsStories,
        storyCollections:
            collections ??
            (legacyNews != null ? const [] : state.storyCollections),
        newsPosts:
            newsPosts ?? (legacyNews != null ? const [] : state.newsPosts),
        promotions: nextPromotions,
        clearPromoCode: !promoStillActive,
      );
      try {
        await _brandingStore.write(config);
      } catch (_) {
        // A failed cache write must never turn a successful refresh into an error.
      }
      return true;
    } catch (_) {
      // Любая неожиданная ошибка не должна ронять запуск приложения.
      return false;
    }
  }

  Future<List<NewsStory>?> fetchCollectionStories(String collectionId) {
    return _api.fetchCollectionStories(collectionId);
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
      final result = await _withCustomerToken(_api.fetchCustomerMe);
      if (epoch != _accountEpoch) return;
      switch (result.status) {
        case ApiAuthStatus.ok:
          _applyCustomerProfile(result.value!);
          await _loadCustomerFavorites();
          await _loadCustomerOrders();
          await _loadCustomerRecurring();
        case ApiAuthStatus.rejected:
          _expireCustomerSession();
        case ApiAuthStatus.invalid:
        case ApiAuthStatus.unavailable:
          break; // офлайн: состояние не меняем
      }
    } catch (_) {
      // Восстановление сессии не должно ронять запуск приложения.
    }
  }

  /// Revalidates an already active customer session after app resume.
  ///
  /// Temporary network failures preserve both tokens and the last successful
  /// private state. A local logout happens only after the refresh credential is
  /// definitively rejected and the profile request still cannot authenticate.
  Future<CustomerSessionResumeResult> resumeCustomerSession() {
    final active = _sessionResumeInFlight;
    if (active != null) return active;
    final resume = _performSessionResume();
    _sessionResumeInFlight = resume;
    unawaited(
      resume.whenComplete(() {
        if (identical(_sessionResumeInFlight, resume)) {
          _sessionResumeInFlight = null;
        }
      }),
    );
    return resume;
  }

  Future<CustomerSessionResumeResult> _performSessionResume() async {
    if (state.isGuest) return CustomerSessionResumeResult.none;
    final epoch = _accountEpoch;
    final customerId = state.customerId;
    final result = await _withCustomerToken(_api.fetchCustomerMe);
    if (epoch != _accountEpoch || state.isGuest) {
      return CustomerSessionResumeResult.none;
    }
    switch (result.status) {
      case ApiAuthStatus.ok:
        if (customerId != null && result.value!.id != customerId) {
          _expireCustomerSession();
          return CustomerSessionResumeResult.sessionExpired;
        }
        _applyCustomerProfile(result.value!);
        await _loadCustomerOrders();
        return CustomerSessionResumeResult.active;
      case ApiAuthStatus.rejected:
        _expireCustomerSession();
        return CustomerSessionResumeResult.sessionExpired;
      case ApiAuthStatus.invalid:
      case ApiAuthStatus.unavailable:
        return CustomerSessionResumeResult.unavailable;
    }
  }

  /// Requests a rotated pair by refresh token. Concurrent callers share one
  /// request, which is required when the server rotates refresh credentials.
  /// Only an explicit rejection clears stored tokens; network errors preserve
  /// the current session for a later retry.
  Future<ApiResult<String>> _refreshAccessToken() {
    final active = _tokenRefreshInFlight;
    if (active != null) return active;
    final refresh = _performTokenRefresh();
    _tokenRefreshInFlight = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (identical(_tokenRefreshInFlight, refresh)) {
          _tokenRefreshInFlight = null;
        }
      }),
    );
    return refresh;
  }

  Future<ApiResult<String>> _performTokenRefresh() async {
    try {
      final refreshToken = await _authStore.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _clearTokens();
        return const ApiResult<String>.rejected();
      }
      final result = await _api.refreshTokens(refreshToken);
      if (!result.isOk) {
        if (result.isRejected) await _clearTokens();
        return _resultWithoutValue<String>(result.status);
      }
      final tokens = result.value!;
      await _authStore.writeTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return ApiResult<String>.ok(tokens.accessToken);
    } catch (_) {
      return const ApiResult<String>.unavailable();
    }
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
      // Own invite code is server-issued and permanent (see auth.py
      // _new_referral_code); it must never fall back to the shared demo
      // placeholder once a real profile has loaded.
      userCode: (profile.referralCode?.isNotEmpty ?? false)
          ? profile.referralCode
          : null,
    );
  }

  Future<void> _loadCustomerProfile() async {
    final epoch = _accountEpoch;
    final customerId = state.customerId;
    if (state.isGuest || customerId == null) return;
    final result = await _withCustomerToken(_api.fetchCustomerMe);
    if (!result.isOk) return;
    if (epoch != _accountEpoch ||
        state.isGuest ||
        state.customerId != customerId) {
      return;
    }
    _applyCustomerProfile(result.value!);
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

  /// Pull-to-refresh entry point for the customer order history.
  ///
  /// The existing list is replaced only by a fully parsed successful response.
  /// Network/schema errors leave the last successful list untouched.
  Future<CustomerHistoryRefreshResult> refreshCustomerOrders() async {
    final epoch = _accountEpoch;
    final customerId = state.customerId;
    if (state.isGuest) return CustomerHistoryRefreshResult.sessionExpired;
    if (customerId == null) return CustomerHistoryRefreshResult.unavailable;
    final result = await _withCustomerToken(_api.fetchCustomerOrders);
    if (epoch != _accountEpoch || state.isGuest) {
      return CustomerHistoryRefreshResult.sessionExpired;
    }
    if (result.isOk) {
      state = state.copyWith(orders: List.unmodifiable(result.value!));
      return CustomerHistoryRefreshResult.success;
    }
    if (result.isRejected) {
      final session = await resumeCustomerSession();
      return session == CustomerSessionResumeResult.sessionExpired
          ? CustomerHistoryRefreshResult.sessionExpired
          : CustomerHistoryRefreshResult.unavailable;
    }
    return CustomerHistoryRefreshResult.unavailable;
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

  /// Серверное оформление заказа. Корзина очищается только после подтверждения
  /// commit; 401 один раз проходит через refresh-token. Любая ошибка оставляет
  /// корзину и локальные баллы без изменений.
  Future<ApiResult<CreatedOrder>> submitOrder({
    required String clientRequestId,
    required OrderType type,
    required String readyTime,
    required List<CartItem> items,
    required Branch branch,
    required int pointsUsed,
    String? promoCode,
    String? comment,
    PaymentMethod paymentMethod = PaymentMethod.mock,
  }) async {
    if (state.isGuest || items.isEmpty || !state.catalogAuthoritative) {
      return const ApiResult<CreatedOrder>.unavailable();
    }
    final result = await _withCustomerToken(
      (accessToken) => _api.createOrder(
        accessToken,
        clientRequestId: clientRequestId,
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
        promoCode: promoCode,
        comment: comment,
      ),
    );

    if (result.isOk) {
      state = state.copyWith(
        cart: const [],
        useBonus: false,
        bonusPointsToUse: 0,
        clearPromoCode: true,
      );
      _cartRevision++;
      await _queueCartPersist();
      await _loadCustomerOrders();
      await _loadCustomerProfile();
    }
    return result;
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

  /// Личный выбор фона. `null` — «как в приложении» (следовать за админкой);
  /// `'off'` — выключить; `'plain'|'bubbles'|'coffee'` — свой узор.
  void setBackgroundOverride(String? value) {
    if (state.backgroundOverride == value) return;
    state = state.copyWith(
      backgroundOverride: value,
      clearBackgroundOverride: value == null,
    );
    unawaited(_persistBackgroundOverride(value));
  }

  Future<void> _persistBackgroundOverride(String? value) async {
    try {
      await _languagePreferences.writeBackgroundOverride(value);
    } catch (_) {
      // Выбор уже применён в UI; ошибка хранилища не критична.
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
        final refreshed = await _refreshAccessToken();
        if (!refreshed.isOk) {
          return _resultWithoutValue<T>(refreshed.status);
        }
        token = refreshed.value!;
      }
      var result = await request(token);
      if (result.isRejected) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed.isOk) {
          return _resultWithoutValue<T>(refreshed.status);
        }
        result = await request(refreshed.value!);
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
        if (!refreshed.isOk) return;
        result = await _api.patchCustomerMe(
          refreshed.value!,
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

  void _expireCustomerSession() {
    _accountEpoch++;
    _favoritesSyncDirty = false;
    unawaited(_clearTokens());
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

  void logout() {
    _expireCustomerSession();
    unawaited(_googleIdentity.signOut());
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

  Future<AccountDeletionResult> deleteAccount() async {
    if (_accountDeletionInProgress) return AccountDeletionResult.busy;
    if (state.isGuest) return AccountDeletionResult.rejected;

    // Preview/demo sessions have no server identity. Production identities
    // always carry a customer id and must be deleted remotely first.
    final serverCustomerId = state.customerId;
    if (serverCustomerId != null) {
      _accountDeletionInProgress = true;
      try {
        final result = await _withCustomerToken(_api.deleteCustomerAccount);
        if (result.isRejected) return AccountDeletionResult.rejected;
        if (!result.isOk) return AccountDeletionResult.unavailable;
      } finally {
        _accountDeletionInProgress = false;
      }
    }

    _accountEpoch++;
    _favoritesSyncDirty = false;
    await _clearTokens();
    try {
      await _googleIdentity.signOut();
    } catch (_) {
      // Server deletion already succeeded; provider sign-out is best effort.
    }
    try {
      await _orderHistoryVisibilityStore.clear();
    } catch (_) {
      // Account deletion still clears in-memory private state if local storage
      // is temporarily unavailable.
    }
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
      bonusPointsToUse: 0,
      clearPromoCode: true,
      orders: const [],
      hiddenOrderIds: const {},
      pointEvents: const [],
      clearRecurring: true,
    );
    _cartRevision++;
    await _queueCartPersist();
    return AccountDeletionResult.success;
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
    if (!product.availableIn(state.selectedBranch)) {
      return false;
    }

    final size = product.sizes.isEmpty
        ? null
        : product.sizes.firstWhere(
            (option) => option.id == 'm',
            orElse: () => product.sizes.first,
          );
    final topping = product.toppings
        .where((option) => option.id == 'tapioca')
        .firstOrNull;

    return addConfigured(
      product,
      sizeId: size?.id,
      sugarPercent: 50,
      ice: IceLevel.regular,
      toppingIds: topping == null ? const [] : [topping.id],
    );
  }

  Future<bool> addConfigured(
    Product product, {
    required String? sizeId,
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
    final size = currentProduct.sizes.isEmpty
        ? null
        : currentProduct.sizes
              .where((candidate) => candidate.id == sizeId)
              .firstOrNull;
    if ((currentProduct.sizes.isEmpty && sizeId != null) ||
        (currentProduct.sizes.isNotEmpty && size == null)) {
      return false;
    }
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
      sizeId: size?.id,
      sugarPercent: sugarPercent,
      ice: ice,
      toppingIds: List.unmodifiable(toppingIds),
      total: currentProduct.basePrice + (size?.priceDelta ?? 0) + toppingPrice,
    );
    state = state.copyWith(cart: [...state.cart, item]);
    _cartRevision++;
    await _queueCartPersist();
    return true;
  }

  /// Replaces exactly one cart row while preserving its quantity.
  ///
  /// The index and product ID are both checked because two independently
  /// configured rows may contain the same product. Editing must never merge
  /// them or append a duplicate.
  Future<bool> replaceConfiguredAt(
    int index,
    Product product, {
    required String? sizeId,
    required int sugarPercent,
    required IceLevel ice,
    required List<String> toppingIds,
  }) async {
    if (index < 0 || index >= state.cart.length) return false;
    final original = state.cart[index];
    final currentProduct = state.products
        .where((candidate) => candidate.id == product.id)
        .firstOrNull;
    if (currentProduct == null ||
        original.product.id != currentProduct.id ||
        !currentProduct.availableIn(state.selectedBranch) ||
        !DemoData.sugarLevels.contains(sugarPercent) ||
        toppingIds.length != toppingIds.toSet().length) {
      return false;
    }

    final size = currentProduct.sizes.isEmpty
        ? null
        : currentProduct.sizes
              .where((candidate) => candidate.id == sizeId)
              .firstOrNull;
    if ((currentProduct.sizes.isEmpty && sizeId != null) ||
        (currentProduct.sizes.isNotEmpty && size == null)) {
      return false;
    }

    var toppingPrice = 0;
    for (final toppingId in toppingIds) {
      final topping = currentProduct.toppings
          .where((candidate) => candidate.id == toppingId)
          .firstOrNull;
      if (topping == null) return false;
      toppingPrice += topping.priceDelta;
    }

    final unitPrice =
        currentProduct.basePrice + (size?.priceDelta ?? 0) + toppingPrice;
    final cart = [...state.cart];
    cart[index] = CartItem(
      product: currentProduct,
      quantity: original.quantity,
      sizeId: size?.id,
      sugarPercent: sugarPercent,
      ice: ice,
      toppingIds: List.unmodifiable(toppingIds),
      total: unitPrice * original.quantity,
    );
    state = state.copyWith(cart: cart);
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
    if (!value || state.maxBonusSpend <= 0) {
      state = state.copyWith(useBonus: false, bonusPointsToUse: 0);
      return;
    }
    state = state.copyWith(
      useBonus: true,
      bonusPointsToUse: state.maxBonusSpend,
    );
  }

  void setBonusPointsToUse(int value) {
    final next = value.clamp(0, state.maxBonusSpend);
    state = state.copyWith(useBonus: next > 0, bonusPointsToUse: next);
  }

  bool applyPromoCode(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) {
      state = state.copyWith(clearPromoCode: true);
      return true;
    }
    final exists = state.promotions.any(
      (promotion) => promotion.code.trim().toUpperCase() == normalized,
    );
    if (!exists) {
      state = state.copyWith(clearPromoCode: true);
      return false;
    }
    state = state.copyWith(promoCode: normalized);
    return true;
  }

  /// Rechecks a promo against the server's current active list before the
  /// customer can continue to checkout. A non-empty code cannot pass when
  /// that verification is unavailable; the backend also performs the final
  /// validation when the order is sent.
  Future<bool> validatePromoCode(String value) async {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return applyPromoCode('');

    final promotions = await _api.fetchPromotions();
    if (promotions == null) {
      state = state.copyWith(clearPromoCode: true);
      return false;
    }
    state = state.copyWith(promotions: List.unmodifiable(promotions));
    return applyPromoCode(normalized);
  }

  Future<void> hideOrdersOnDevice(Iterable<String> orderIds) async {
    final knownIds = state.orders.map((order) => order.id).toSet();
    final requested = orderIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && knownIds.contains(id));
    final next = {...state.hiddenOrderIds, ...requested};
    if (next.length == state.hiddenOrderIds.length) return;
    final snapshot = Set<String>.unmodifiable(next);
    state = state.copyWith(hiddenOrderIds: snapshot);
    try {
      await _orderHistoryVisibilityStore.writeHiddenOrderIds(snapshot);
    } catch (_) {
      // The current session remains consistent; persistence can recover on a
      // later hide operation without ever deleting the server-side order.
    }
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
      final size = product.sizes.isEmpty
          ? null
          : product.sizes
                .where((candidate) => candidate.id == sizeId)
                .firstOrNull;
      if ((product.sizes.isEmpty && sizeId != null) ||
          (product.sizes.isNotEmpty && size == null) ||
          toppingIds.length != toppingIds.toSet().length) {
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
      final unitPrice =
          product.basePrice + (size?.priceDelta ?? 0) + toppingPrice;
      repeatedItems.add(
        CartItem(
          product: product,
          quantity: item.quantity,
          sizeId: size?.id,
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

  /// Погашение кода друга — теперь на сервере (правила и защита от накрутки —
  /// docs/design/REFERRAL_LOGIC.md, серверная ручка POST /customer/me/referral).
  /// Локальная проверка формата убрана: код буквенно-цифровой (SWEETT-XXXXXX),
  /// а привязку/бонус решает сервер. Возвращаемый профиль — источник истины.
  Future<ReferralResult> applyReferral(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty) return ReferralResult.invalidCode;
    if (state.isGuest) return ReferralResult.networkError;

    final epoch = _accountEpoch;
    final result = await _withCustomerToken(
      (token) => _api.redeemReferral(token, code),
    );
    if (epoch != _accountEpoch || state.isGuest) {
      return ReferralResult.networkError;
    }
    if (!result.isOk || result.value == null) {
      // rejected/invalid/unavailable — все трактуем как «нет связи/сессии».
      return ReferralResult.networkError;
    }
    final outcome = result.value!;
    if (outcome.profile != null) {
      _applyCustomerProfile(outcome.profile!);
      return ReferralResult.success;
    }
    // Бизнес-отказ: машинный detail сервера -> локализованный результат.
    return switch (outcome.detail) {
      'self_code' => ReferralResult.selfCode,
      'already_invited' => ReferralResult.alreadyInvited,
      'not_new_user' => ReferralResult.notNewUser,
      _ => ReferralResult.invalidCode, // code_not_found / empty_code
    };
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

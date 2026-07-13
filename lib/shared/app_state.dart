import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
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

abstract interface class LanguagePreferenceStore {
  Future<String?> readLanguageCode();
  Future<void> writeLanguageCode(String code);
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
}

@immutable
class AppState {
  const AppState({
    required this.apiConnected,
    required this.appName,
    required this.accentColor,
    required this.loyaltyEarnRate,
    required this.loyaltyMaxSpendShare,
    required this.themeMode,
    required this.language,
    required this.isGuest,
    required this.pendingAuthReturn,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.avatarPath,
    required this.userContact,
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

  /// Брендинг компании из API (или дефолт SweetTime, если офлайн).
  final String appName;
  final Color accentColor;

  /// Правила лояльности: дефолты из [Loyalty], могут прийти из конфига API.
  final double loyaltyEarnRate;
  final double loyaltyMaxSpendShare;

  final ThemeMode themeMode;
  final AppLanguage language;
  final bool isGuest;
  final AuthReturnDestination? pendingAuthReturn;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final String? avatarPath;
  final String userContact;

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
  final List<CustomerOrder> orders;
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
    String? appName,
    Color? accentColor,
    double? loyaltyEarnRate,
    double? loyaltyMaxSpendShare,
    ThemeMode? themeMode,
    AppLanguage? language,
    bool? isGuest,
    AuthReturnDestination? pendingAuthReturn,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? avatarPath,
    String? userContact,
    String? invitedByCode,
    int? points,
    List<Branch>? branches,
    Branch? selectedBranch,
    List<MenuCategory>? categories,
    List<Product>? products,
    List<NewsStory>? newsStories,
    List<String>? favoriteIds,
    List<CartItem>? cart,
    bool? useBonus,
    List<CustomerOrder>? orders,
    List<PointEvent>? pointEvents,
    RecurringOrder? recurring,
    bool clearBirthDate = false,
    bool clearAvatarPath = false,
    bool clearInvitedByCode = false,
    bool clearPendingAuthReturn = false,
    bool clearRecurring = false,
  }) {
    return AppState(
      apiConnected: apiConnected ?? this.apiConnected,
      appName: appName ?? this.appName,
      accentColor: accentColor ?? this.accentColor,
      loyaltyEarnRate: loyaltyEarnRate ?? this.loyaltyEarnRate,
      loyaltyMaxSpendShare: loyaltyMaxSpendShare ?? this.loyaltyMaxSpendShare,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      isGuest: isGuest ?? this.isGuest,
      pendingAuthReturn: clearPendingAuthReturn
          ? null
          : (pendingAuthReturn ?? this.pendingAuthReturn),
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
      userContact: userContact ?? this.userContact,
      userCode: userCode,
      invitedByCode: clearInvitedByCode
          ? null
          : (invitedByCode ?? this.invitedByCode),
      points: points ?? this.points,
      branches: branches ?? this.branches,
      selectedBranch: selectedBranch ?? this.selectedBranch,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      promotions: promotions,
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
  AppStateController({LanguagePreferenceStore? languagePreferences})
    : _languagePreferences =
          languagePreferences ?? SharedPreferencesLanguagePreferenceStore(),
      super(
        AppState(
          apiConnected: false,
          appName: 'SweetTime',
          accentColor: AppColors.candy500,
          loyaltyEarnRate: Loyalty.earnRate,
          loyaltyMaxSpendShare: Loyalty.maxSpendShare,
          themeMode: ThemeMode.light,
          language: AppLanguage.ru,
          isGuest: true,
          pendingAuthReturn: null,
          firstName: '',
          lastName: '',
          birthDate: null,
          avatarPath: null,
          userContact: '',
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

  final ApiClient _api = ApiClient();
  final LanguagePreferenceStore _languagePreferences;
  static const languagePreferenceKey = 'app_language';
  bool _bootstrapped = false;

  /// Однократная попытка подключиться к demo-API при старте (таймаут 2 с
  /// на запрос внутри [ApiClient]). При успехе подменяем каталог/филиалы и
  /// брендинг серверными данными; при любой ошибке молча остаёмся на
  /// [DemoData] — APK обязан работать автономно.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    try {
      final savedLanguage = await _languagePreferences.readLanguageCode();
      final language = AppLanguage.values.where(
        (candidate) => candidate.locale.languageCode == savedLanguage,
      );
      if (language.isNotEmpty) {
        state = state.copyWith(language: language.first);
      }
    } catch (_) {
      // Настройка языка не должна блокировать автономный запуск приложения.
    }
    try {
      final config = await _api.fetchConfig();
      if (config == null) return; // сервер недоступен — остаёмся на демо
      final products = await _api.fetchProducts();
      final branches = await _api.fetchBranches();

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
        appName: config.appName,
        accentColor: config.accentColor,
        loyaltyEarnRate: config.earnRate,
        loyaltyMaxSpendShare: config.maxSpendShare,
        products: nextProducts,
        branches: nextBranches,
        selectedBranch: selected,
        categories: categories.isEmpty ? state.categories : categories,
      );
    } catch (_) {
      // Любая неожиданная ошибка не должна ронять запуск приложения.
    }
  }

  /// POST заказа на сервер (если API доступен). null — офлайн/ошибка сети:
  /// заказ при этом уже оформлен локально, поведение прежнее.
  Future<CreatedOrder?> submitOrder({
    required OrderType type,
    required String readyTime,
    required List<CartItem> items,
    required Branch branch,
    required int total,
    required int pointsUsed,
  }) {
    if (state.isGuest || items.isEmpty) {
      return Future<CreatedOrder?>.value();
    }
    final customerName = state.userName.isNotEmpty
        ? state.userName
        : state.userContact.trim();
    return _api.createOrder(
      customerName: customerName,
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
            'productName': item.product.name.resolve(state.language),
            'size': item.sizeId,
            'quantity': item.quantity,
            'total': item.total,
          },
      ],
      total: total,
      pointsUsed: pointsUsed,
    );
  }

  void toggleTheme() {
    state = state.copyWith(
      themeMode: state.themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
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
    state = state.copyWith(
      isGuest: false,
      firstName: '',
      lastName: '',
      clearBirthDate: true,
      clearAvatarPath: true,
      userContact: phone,
      clearInvitedByCode: true,
      points: 0,
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

  void updateProfile({
    required String firstName,
    required String lastName,
    DateTime? birthDate,
    String? avatarPath,
    bool clearBirthDate = false,
    bool clearAvatarPath = false,
  }) {
    state = state.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      birthDate: birthDate,
      avatarPath: avatarPath,
      clearBirthDate: clearBirthDate,
      clearAvatarPath: clearAvatarPath,
    );
  }

  void logout() {
    state = state.copyWith(
      isGuest: true,
      firstName: '',
      lastName: '',
      clearBirthDate: true,
      clearAvatarPath: true,
      userContact: '',
      clearPendingAuthReturn: true,
      clearInvitedByCode: true,
      points: 0,
      orders: const [],
      pointEvents: const [],
      clearRecurring: true,
    );
  }

  void deleteAccount() {
    state = state.copyWith(
      isGuest: true,
      firstName: '',
      lastName: '',
      clearBirthDate: true,
      clearAvatarPath: true,
      userContact: '',
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
  }

  void selectBranch(Branch branch) {
    state = state.copyWith(selectedBranch: branch);
  }

  void toggleFavorite(Product product) {
    final ids = [...state.favoriteIds];
    if (ids.contains(product.id)) {
      ids.remove(product.id);
    } else {
      ids.add(product.id);
    }
    state = state.copyWith(favoriteIds: ids);
  }

  void quickAdd(Product product) {
    if (product.sizes.isEmpty) return;

    final size = product.sizes.firstWhere(
      (option) => option.id == 'm',
      orElse: () => product.sizes.first,
    );
    final topping = product.toppings
        .where((option) => option.id == 'tapioca')
        .firstOrNull;

    addConfigured(
      product,
      sizeId: size.id,
      sugarPercent: 50,
      ice: IceLevel.regular,
      toppingIds: topping == null ? const [] : [topping.id],
      total: product.basePrice + size.priceDelta + (topping?.priceDelta ?? 0),
    );
  }

  void addConfigured(
    Product product, {
    required String sizeId,
    required int sugarPercent,
    required IceLevel ice,
    required List<String> toppingIds,
    required int total,
  }) {
    final item = CartItem(
      product: product,
      quantity: 1,
      sizeId: sizeId,
      sugarPercent: sugarPercent,
      ice: ice,
      toppingIds: toppingIds,
      total: total,
    );
    state = state.copyWith(cart: [...state.cart, item]);
  }

  void updateQuantity(int index, int delta) {
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
  }

  void removeFromCart(int index) {
    final cart = [...state.cart]..removeAt(index);
    state = state.copyWith(cart: cart);
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
      orders: [order, ...state.orders],
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
    return order;
  }

  void repeatOrder(CustomerOrder order) {
    state = state.copyWith(cart: [...state.cart, ...order.items]);
  }

  /// Постоянный заказ с предоплатой вперёд (день/неделя/месяц).
  void setRecurring({
    required List<Product> products,
    required String time,
    required Branch branch,
    required RecurringPlan plan,
  }) {
    final paidUntil = DateTime.now().add(Duration(days: plan.days));
    state = state.copyWith(
      recurring: RecurringOrder(
        products: products,
        time: time,
        branch: branch,
        plan: plan,
        paidUntil: paidUntil,
      ),
    );
  }

  void cancelRecurring() {
    state = state.copyWith(clearRecurring: true);
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
        clearAvatarPath: true,
        userContact: DemoData.demoUserPhone,
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
        ],
      );
    }
    if (recurring) {
      next = next.copyWith(
        recurring: RecurringOrder(
          products: [DemoData.products[0]],
          time: '11:00',
          branch: DemoData.branches.first,
          plan: RecurringPlan.week,
          paidUntil: DateTime.now().add(const Duration(days: 7)),
        ),
      );
    }
    state = next;
  }
}

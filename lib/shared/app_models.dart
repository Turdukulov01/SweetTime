import 'package:flutter/material.dart';

enum AppLanguage {
  ru('RU', 'Русский', Locale('ru')),
  ky('KG', 'Кыргызча', Locale('ky')),
  en('EN', 'English', Locale('en'));

  const AppLanguage(this.shortLabel, this.nativeName, this.locale);

  final String shortLabel;
  final String nativeName;
  final Locale locale;

  static AppLanguage fromLocale(Locale locale) => switch (locale.languageCode) {
    'ky' => AppLanguage.ky,
    'en' => AppLanguage.en,
    _ => AppLanguage.ru,
  };
}

class LocalizedText {
  const LocalizedText({required this.ru, this.ky, this.en});

  final String ru;
  final String? ky;
  final String? en;

  String resolve(AppLanguage language) => switch (language) {
    AppLanguage.ru => ru,
    AppLanguage.ky => _presentOrRussian(ky),
    AppLanguage.en => _presentOrRussian(en),
  };

  String _presentOrRussian(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? ru : normalized;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalizedText &&
          other.ru == ru &&
          other.ky == ky &&
          other.en == en;

  @override
  int get hashCode => Object.hash(ru, ky, en);
}

class MenuCategory {
  const MenuCategory({required this.id, required this.name});

  final String id;
  final LocalizedText name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MenuCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

enum NewsStoryVisual { sparkle, storefront, qr, loyalty }

enum NewsMediaType { none, image, video }

extension NewsStoryVisualUi on NewsStoryVisual {
  IconData get icon => switch (this) {
    NewsStoryVisual.sparkle => Icons.auto_awesome,
    NewsStoryVisual.storefront => Icons.storefront_outlined,
    NewsStoryVisual.qr => Icons.qr_code_scanner,
    NewsStoryVisual.loyalty => Icons.loyalty_outlined,
  };
}

class NewsStory {
  const NewsStory({
    required this.id,
    required this.title,
    required this.body,
    required this.badge,
    required this.accentHex,
    required this.visual,
    required this.publishedAt,
    required this.sortOrder,
    this.expiresAt,
    this.isPublished = true,
    this.companyId,
    this.collectionId,
    this.showOnHome = true,
    this.isPinned = false,
    this.assetImage,
    this.imageUrl,
    this.mediaType = NewsMediaType.none,
    this.mediaUrl,
    this.thumbnailUrl,
    this.ctaLabel,
    this.ctaRoute,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText body;
  final LocalizedText badge;

  /// Серверный контракт хранит строку #RRGGBB; demo использует числовое значение.
  final int accentHex;
  final NewsStoryVisual visual;
  final String publishedAt;
  final String? expiresAt;
  final bool isPublished;
  final int sortOrder;
  final String? companyId;
  final String? collectionId;
  final bool showOnHome;
  final bool isPinned;
  final String? assetImage;
  final String? imageUrl;
  final NewsMediaType mediaType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final LocalizedText? ctaLabel;
  final String? ctaRoute;

  Color get accentColor => Color(accentHex);

  String? get effectiveMediaUrl => mediaUrl ?? imageUrl;

  NewsMediaType get effectiveMediaType {
    if (mediaType != NewsMediaType.none) return mediaType;
    return effectiveMediaUrl == null ? NewsMediaType.none : NewsMediaType.image;
  }

  DateTime? get publishedDate => DateTime.tryParse(publishedAt);

  bool isActiveAt(DateTime now) {
    if (!isPublished) return false;
    final start = DateTime.tryParse(publishedAt);
    final end = expiresAt == null ? null : DateTime.tryParse(expiresAt!);
    if (start == null || start.isAfter(now)) return false;
    if (end != null && !end.isAfter(now)) return false;
    return true;
  }
}

class StoryCollection {
  const StoryCollection({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.companyId,
    this.description,
    this.coverImageUrl,
    this.accentHex = 0xFFFF5A96,
    this.visual = NewsStoryVisual.sparkle,
    this.isPublished = true,
  });

  final String id;
  final String? companyId;
  final LocalizedText name;
  final LocalizedText? description;
  final String? coverImageUrl;
  final int accentHex;
  final NewsStoryVisual visual;
  final int sortOrder;
  final bool isPublished;

  Color get accentColor => Color(accentHex);
}

class NewsPost {
  const NewsPost({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.publishedAt,
    this.companyId,
    this.isPublished = true,
    this.mediaType = NewsMediaType.none,
    this.mediaUrl,
    this.thumbnailUrl,
    this.imageUrl,
  });

  final String id;
  final String? companyId;
  final LocalizedText title;
  final LocalizedText summary;
  final LocalizedText body;
  final bool isPublished;
  final String publishedAt;
  final NewsMediaType mediaType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? imageUrl;

  String? get effectiveMediaUrl => mediaUrl ?? imageUrl;

  NewsMediaType get effectiveMediaType {
    if (mediaType != NewsMediaType.none) return mediaType;
    return effectiveMediaUrl == null ? NewsMediaType.none : NewsMediaType.image;
  }

  DateTime? get publishedDate => DateTime.tryParse(publishedAt);

  bool isActiveAt(DateTime now) {
    final date = publishedDate;
    return isPublished && date != null && !date.isAfter(now);
  }
}

List<NewsStory> selectHomeStories(
  Iterable<NewsStory> stories, {
  DateTime? now,
  int limit = 30,
}) {
  final effectiveNow = now ?? DateTime.now().toUtc();
  final safeLimit = limit.clamp(0, 30);
  final result =
      stories
          .where((story) => story.showOnHome && story.isActiveAt(effectiveNow))
          .toList(growable: false)
        ..sort(compareNewsStories);
  return result.take(safeLimit).toList(growable: false);
}

int compareNewsStories(NewsStory left, NewsStory right) {
  if (left.isPinned != right.isPinned) return left.isPinned ? -1 : 1;
  final leftDate = left.publishedDate;
  final rightDate = right.publishedDate;
  if (leftDate != null && rightDate != null) {
    final dateResult = rightDate.compareTo(leftDate);
    if (dateResult != 0) return dateResult;
  } else if (leftDate != null) {
    return -1;
  } else if (rightDate != null) {
    return 1;
  }
  return left.id.compareTo(right.id);
}

/// Правила лояльности SweetTime: 1 балл = 1 сом.
abstract final class Loyalty {
  static const int pointValueKgs = 1;
  static const double earnRate = 0.05; // начисляем 5% от оплаченной суммы
  static const double maxSpendShare =
      0.3; // баллами можно оплатить до 30% заказа
  static const int expiryMonths = 12;
}

/// Реферальная программа: приглашённому 50, пригласившему 100 после первого заказа.
abstract final class Referral {
  static const int invitedBonus = 50;
  static const int inviterBonus = 100;
}

class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.hours,
    required this.phone,
    required this.isOpen,
    required this.twoGisUrl,
    required this.googleMapsUrl,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText address;
  final String hours;
  final String phone;
  final bool isOpen;
  final String twoGisUrl;
  final String googleMapsUrl;
}

class Product {
  const Product({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.accentColor,
    required this.rating,
    required this.reviewsCount,
    required this.sizes,
    required this.toppings,
    required this.availableBranchIds,
    this.assetImage,
    this.imageUrl,
    this.isNew = false,
    this.isBestSeller = false,
  });

  final String id;
  final MenuCategory category;
  final LocalizedText name;
  final LocalizedText description;
  final int basePrice;
  final Color accentColor;
  final double rating;
  final int reviewsCount;
  final List<ModifierOption> sizes;
  final List<ModifierOption> toppings;
  final List<String> availableBranchIds;
  final String? assetImage;
  final String? imageUrl;
  final bool isNew;
  final bool isBestSeller;

  bool availableIn(Branch branch) => availableBranchIds.contains(branch.id);

  /// Lowest configured final price shown in catalog cards.
  ///
  /// Size prices are stored as deltas for order calculations, but the admin
  /// edits them as final prices. Showing [basePrice] here would therefore
  /// disagree with the initially selected size whenever it is cheaper.
  int get startingPrice {
    if (sizes.isEmpty) return basePrice;
    return sizes
        .map((size) => basePrice + size.priceDelta)
        .reduce((left, right) => left < right ? left : right);
  }
}

class ModifierOption {
  const ModifierOption({
    required this.id,
    required this.name,
    required this.priceDelta,
  });

  final String id;
  final LocalizedText name;
  final int priceDelta;
}

enum IceLevel { none, less, regular, extra }

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    required this.sizeId,
    required this.sugarPercent,
    required this.ice,
    required this.toppingIds,
    required this.total,
  });

  final Product product;
  final int quantity;
  final String? sizeId;
  final int sugarPercent;
  final IceLevel ice;
  final List<String> toppingIds;
  final int total;

  ModifierOption? get sizeOption {
    for (final option in product.sizes) {
      if (option.id == sizeId) return option;
    }
    return null;
  }

  List<ModifierOption> get toppingOptions => product.toppings
      .where((option) => toppingIds.contains(option.id))
      .toList(growable: false);

  CartItem copyWith({int? quantity, int? total}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      sizeId: sizeId,
      sugarPercent: sugarPercent,
      ice: ice,
      toppingIds: toppingIds,
      total: total ?? this.total,
    );
  }
}

class Promotion {
  const Promotion({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    this.imageUrl,
    this.thumbnailUrl,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText description;
  final String code;
  final String? imageUrl;
  final String? thumbnailUrl;
}

class PointEvent {
  const PointEvent({
    required this.title,
    required this.amount,
    required this.date,
  });

  final LocalizedText title;
  final int amount;
  final LocalizedText date;
}

enum OrderReadyTimeKind { asap, scheduled, table }

class OrderReadyTime {
  const OrderReadyTime({required this.kind, this.value});

  final OrderReadyTimeKind kind;
  final String? value;
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.items,
    required this.branch,
    required this.type,
    required this.status,
    required this.paymentMethod,
    required this.readyTime,
    required this.total,
    required this.pointsUsed,
    required this.pointsEarned,
    this.promoCode,
  });

  final String id;
  final List<CartItem> items;
  final Branch branch;
  final OrderType type;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final OrderReadyTime readyTime;
  final int total;
  final int pointsUsed;
  final int pointsEarned;
  final String? promoCode;
}

/// Immutable order-history snapshot returned by the customer API.
///
/// History deliberately does not keep a [Product] reference: legacy orders and
/// removed catalog items must remain readable without guessing identity from a
/// translated display name.
class OrderHistoryItem {
  const OrderHistoryItem({
    required this.productName,
    required this.quantity,
    required this.total,
    this.productDescription,
    this.imageUrl,
    this.sizeName,
    this.productId,
    this.sizeId,
    this.toppingIds,
    this.toppings,
    this.sugarPercent,
    this.ice,
    this.unitPrice,
  });

  final LocalizedText productName;
  final LocalizedText? productDescription;
  final String? imageUrl;
  final LocalizedText? sizeName;
  final int quantity;
  final int total;
  final String? productId;
  final String? sizeId;
  final List<String>? toppingIds;
  final List<ModifierOption>? toppings;
  final int? sugarPercent;
  final IceLevel? ice;
  final int? unitPrice;

  factory OrderHistoryItem.fromCartItem(CartItem item) => OrderHistoryItem(
    productName: item.product.name,
    productDescription: item.product.description,
    sizeName: item.sizeOption?.name,
    quantity: item.quantity,
    total: item.total,
    productId: item.product.id,
    sizeId: item.sizeId,
    toppingIds: List.unmodifiable(item.toppingIds),
    toppings: List.unmodifiable(item.toppingOptions),
    sugarPercent: item.sugarPercent,
    ice: item.ice,
    unitPrice: (item.total / item.quantity).round(),
  );
}

class OrderHistoryEntry {
  const OrderHistoryEntry({
    required this.id,
    required this.number,
    required this.branchId,
    required this.type,
    required this.status,
    required this.paymentMethod,
    required this.readyTime,
    required this.itemsVersion,
    required this.items,
    required this.total,
    required this.pointsUsed,
    required this.pointsEarned,
    this.createdAt,
    this.customerPhone,
    this.branchName,
    this.branchAddress,
    this.comment,
    this.promoCode,
    this.isRecurring = false,
    this.scheduledFor,
  });

  final String id;
  final String number;
  final String branchId;
  final OrderType type;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final OrderReadyTime readyTime;
  final int itemsVersion;
  final List<OrderHistoryItem> items;
  final int total;
  final int pointsUsed;
  final int pointsEarned;
  final DateTime? createdAt;
  final String? customerPhone;
  final String? branchName;
  final String? branchAddress;
  final String? comment;
  final String? promoCode;

  /// Заказ сгенерирован подпиской «постоянный заказ», а не оформлен вручную.
  final bool isRecurring;

  /// Плановое время готовности сгенерированного постоянного заказа (UTC).
  final DateTime? scheduledFor;

  bool get supportsExactRepeat => itemsVersion == 2;

  factory OrderHistoryEntry.fromLocal(CustomerOrder order) => OrderHistoryEntry(
    id: order.id,
    number: order.id,
    branchId: order.branch.id,
    type: order.type,
    status: order.status,
    paymentMethod: order.paymentMethod,
    readyTime: order.readyTime,
    itemsVersion: 2,
    items: List.unmodifiable(order.items.map(OrderHistoryItem.fromCartItem)),
    total: order.total,
    pointsUsed: order.pointsUsed,
    pointsEarned: order.pointsEarned,
    promoCode: order.promoCode,
  );
}

enum RepeatOrderResult {
  success,
  legacyOrder,
  catalogUnavailable,
  unavailableSelection,
}

enum OrderType {
  pickup(Icons.shopping_bag_outlined),
  scheduled(Icons.schedule_outlined),
  qrCafe(Icons.qr_code_2_outlined);

  const OrderType(this.icon);

  final IconData icon;
}

enum PaymentMethod {
  mock(Icons.credit_card_outlined),
  cash(Icons.payments_outlined),
  qrDemo(Icons.qr_code_scanner_outlined);

  const PaymentMethod(this.icon);

  final IconData icon;
}

enum OrderStatus {
  created,

  /// Сгенерированный постоянный заказ на сегодня: ещё не в работе, сервер сам
  /// переведёт его в `new` за 10 минут до времени готовности.
  scheduled,
  awaitingPayment,
  paid,
  accepted,
  preparing,
  ready,
  completed,
  cancelled,
}

/// Результат сканирования/ввода кода друга (правила — docs/design/REFERRAL_LOGIC.md).
enum ReferralResult {
  success,
  selfCode,
  alreadyInvited,
  notNewUser,
  invalidCode,
  networkError;

  bool get isSuccess => this == ReferralResult.success;
}

/// Постоянный заказ: любимые напитки к нужному времени с предоплатой вперёд.
enum RecurringPlan {
  single(1),
  week(7),
  month(30);

  const RecurringPlan(this.days);

  final int days;
}

class RecurringOrder {
  const RecurringOrder({
    required this.productIds,
    required this.time,
    required this.branchId,
    required this.plan,
    required this.paidUntil,
    required this.dailyTotal,
    this.comment,
  });

  final List<String> productIds;
  final String time;
  final String branchId;
  final RecurringPlan plan;
  final DateTime? paidUntil;

  /// Актуальная серверная цена набора за один день по текущему каталогу.
  /// После редактирования состава или смены цен сервер пересчитывает сумму.
  final int dailyTotal;

  /// Пожелания клиента к каждому заказу (до 500 символов).
  final String? comment;
}

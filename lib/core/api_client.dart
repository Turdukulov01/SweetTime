import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../shared/app_models.dart';
import '../shared/demo_data.dart';

/// Базовый URL API. Для локальной разработки backend обычно слушает порт 8010;
/// production-сборка должна явно указывать HTTPS-домен:
/// `flutter build apk --dart-define=API_BASE=http://10.0.2.2:8010` (эмулятор) или
/// `--dart-define=API_BASE=https://lnp-corporation.duckdns.org` (телефон/релиз).
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://127.0.0.1:8010',
);

/// Брендинг и правила компании из `GET /config`. Поля nullable:
/// отсутствующее значение не затирает локальные дефолты.
class CompanyConfig {
  const CompanyConfig({
    required this.appName,
    required this.accentColor,
    required this.earnRate,
    required this.maxSpendShare,
  });

  final String? appName;
  final Color? accentColor;
  final double? earnRate;
  final double? maxSpendShare;
}

/// Ответ сервера на `POST /orders` — то, что показываем в диалоге успеха.
class CreatedOrder {
  const CreatedOrder({required this.number, required this.pointsEarned});

  final String number;
  final int pointsEarned;
}

/// Чем закончился запрос к auth-API.
///
/// Отказ сервера и недоступность сети — принципиально разные случаи:
/// на [rejected] показываем ошибку и чистим токены, на [unavailable]
/// приложение остаётся в офлайн-режиме и НЕ разлогинивает пользователя.
enum ApiAuthStatus { ok, rejected, unavailable }

/// Результат auth-запроса: статус + payload только при [ApiAuthStatus.ok].
class ApiResult<T> {
  const ApiResult.ok(T this.value) : status = ApiAuthStatus.ok;
  const ApiResult.rejected() : status = ApiAuthStatus.rejected, value = null;
  const ApiResult.unavailable()
    : status = ApiAuthStatus.unavailable,
      value = null;

  final ApiAuthStatus status;
  final T? value;

  bool get isOk => status == ApiAuthStatus.ok;
  bool get isRejected => status == ApiAuthStatus.rejected;
}

/// Профиль клиента с сервера (`auth/customer/me`). Источник правды по личным
/// данным: переживает переустановку приложения, в отличие от локального стейта.
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.phone,
    this.phoneVerified = false,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.points,
    required this.referralCode,
    required this.invitedByCode,
    this.avatarUrl,
  });

  final String id;
  final String? phone;
  final bool phoneVerified;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final int points;
  final String? referralCode;
  final String? invitedByCode;
  final String? avatarUrl;

  static CustomerProfile? tryParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    if (id == null) return null;
    return CustomerProfile(
      id: id.toString(),
      phone: raw['phone'] as String?,
      phoneVerified: (raw['phoneVerified'] as bool?) ?? false,
      firstName: (raw['firstName'] as String?) ?? '',
      lastName: (raw['lastName'] as String?) ?? '',
      birthDate: DateTime.tryParse((raw['birthDate'] as String?) ?? ''),
      points: (raw['points'] as num?)?.toInt() ?? 0,
      referralCode: raw['referralCode'] as String?,
      invitedByCode: raw['invitedByCode'] as String?,
      avatarUrl: raw['avatarUrl'] as String?,
    );
  }

  CustomerProfile copyWith({
    String? phone,
    bool? phoneVerified,
    String? avatarUrl,
    bool clearAvatarUrl = false,
  }) {
    return CustomerProfile(
      id: id,
      phone: phone ?? this.phone,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
      points: points,
      referralCode: referralCode,
      invitedByCode: invitedByCode,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
    );
  }
}

/// Пара токенов; вместе с профилем — результат успешного входа по OTP.
class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  static TokenPair? tryParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final access = raw['accessToken'];
    final refresh = raw['refreshToken'];
    if (access is! String || refresh is! String) return null;
    if (access.isEmpty || refresh.isEmpty) return null;
    return TokenPair(accessToken: access, refreshToken: refresh);
  }
}

/// Успешный вход клиента: токены + профиль с сервера.
class CustomerSession {
  const CustomerSession({required this.tokens, required this.profile});

  final TokenPair tokens;
  final CustomerProfile profile;
}

/// Strict parser for the versioned customer order-history contract.
///
/// A malformed response is rejected as unavailable by [ApiClient] instead of
/// being mistaken for a valid empty history. V1 is intentionally display-only;
/// only V2 carries the stable selection needed for exact reorder.
OrderHistoryEntry? parseCustomerOrderHistoryEntry(dynamic raw) {
  if (raw is! Map<String, dynamic>) return null;
  final id = _requiredString(raw['id']);
  final number = _requiredString(raw['number']);
  final branchId = _requiredString(raw['branchId']);
  final type = _orderType(raw['type']);
  final status = _orderStatus(raw['status']);
  final paymentMethod = _paymentMethod(raw['paymentMethod']);
  final itemsVersion = _wholeInt(raw['itemsVersion']);
  final total = _nonNegativeInt(raw['total']);
  final pointsUsed = _nonNegativeInt(raw['pointsUsed']);
  final pointsEarned = _nonNegativeInt(raw['pointsEarned']);
  final createdAtRaw = raw['createdAt'];
  final createdAt = createdAtRaw is String
      ? DateTime.tryParse(createdAtRaw)
      : null;
  final rawItems = raw['items'];
  if (id == null ||
      number == null ||
      branchId == null ||
      type == null ||
      status == null ||
      paymentMethod == null ||
      (itemsVersion != 1 && itemsVersion != 2) ||
      total == null ||
      pointsUsed == null ||
      pointsEarned == null ||
      createdAt == null ||
      rawItems is! List<dynamic> ||
      rawItems.isEmpty) {
    return null;
  }

  final items = <OrderHistoryItem>[];
  for (final rawItem in rawItems) {
    final item = _parseOrderHistoryItem(rawItem, itemsVersion!);
    if (item == null) return null;
    items.add(item);
  }

  final readyTimeRaw = raw['readyTime'];
  if (readyTimeRaw != null && readyTimeRaw is! String) return null;
  final readyTimeValue = (readyTimeRaw as String?)?.trim();
  final readyTime = switch (type) {
    OrderType.scheduled => OrderReadyTime(
      kind: OrderReadyTimeKind.scheduled,
      value: readyTimeValue,
    ),
    OrderType.qrCafe => OrderReadyTime(
      kind: OrderReadyTimeKind.table,
      value: readyTimeValue,
    ),
    OrderType.pickup =>
      readyTimeValue == null ||
              readyTimeValue.isEmpty ||
              readyTimeValue == 'asap'
          ? const OrderReadyTime(kind: OrderReadyTimeKind.asap)
          : OrderReadyTime(
              kind: OrderReadyTimeKind.scheduled,
              value: readyTimeValue,
            ),
  };

  return OrderHistoryEntry(
    id: id,
    number: number,
    branchId: branchId,
    type: type,
    status: status,
    paymentMethod: paymentMethod,
    readyTime: readyTime,
    itemsVersion: itemsVersion!,
    items: List.unmodifiable(items),
    total: total,
    pointsUsed: pointsUsed,
    pointsEarned: pointsEarned,
    createdAt: createdAt,
  );
}

OrderHistoryItem? _parseOrderHistoryItem(dynamic raw, int itemsVersion) {
  if (raw is! Map<String, dynamic>) return null;
  final productName = _localizedSnapshot(raw['productName']);
  final quantity = _positiveInt(raw['quantity']);
  final total = _nonNegativeInt(raw['total']);
  final sizeName = _localizedSnapshot(raw['sizeName'] ?? raw['size']);
  if (productName == null || quantity == null || total == null) return null;

  if (itemsVersion == 1) {
    return OrderHistoryItem(
      productName: productName,
      sizeName: sizeName,
      quantity: quantity,
      total: total,
    );
  }

  final productId = _requiredString(raw['productId']);
  final sizeIdRaw = raw['sizeId'];
  final sizeId = sizeIdRaw == null ? null : _requiredString(sizeIdRaw);
  final toppingIds = _stringList(raw['toppingIds']);
  final sugarPercent = _wholeInt(raw['sugarPercent']);
  final ice = _iceLevel(raw['ice']);
  final unitPrice = _nonNegativeInt(raw['unitPrice']);
  if (productId == null ||
      (sizeIdRaw != null && sizeId == null) ||
      toppingIds == null ||
      toppingIds.length != toppingIds.toSet().length ||
      !const [0, 30, 50, 70, 100].contains(sugarPercent) ||
      ice == null ||
      unitPrice == null) {
    return null;
  }
  return OrderHistoryItem(
    productName: productName,
    sizeName: sizeName,
    quantity: quantity,
    total: total,
    productId: productId,
    sizeId: sizeId,
    toppingIds: List.unmodifiable(toppingIds),
    sugarPercent: sugarPercent,
    ice: ice,
    unitPrice: unitPrice,
  );
}

String? _requiredString(dynamic raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  return raw.trim();
}

int? _wholeInt(dynamic raw) {
  if (raw is! num || raw.isNaN || raw.isInfinite) return null;
  final value = raw.toInt();
  return value == raw ? value : null;
}

int? _positiveInt(dynamic raw) {
  final value = _wholeInt(raw);
  return value != null && value > 0 ? value : null;
}

int? _nonNegativeInt(dynamic raw) {
  final value = _wholeInt(raw);
  return value != null && value >= 0 ? value : null;
}

List<String>? _stringList(dynamic raw) {
  if (raw is! List<dynamic>) return null;
  final values = <String>[];
  for (final value in raw) {
    final parsed = _requiredString(value);
    if (parsed == null) return null;
    values.add(parsed);
  }
  return values;
}

LocalizedText? _localizedSnapshot(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    final value = _requiredString(raw);
    return value == null
        ? null
        : LocalizedText(ru: value, ky: value, en: value);
  }
  if (raw is! Map<String, dynamic>) return null;
  final ru = _requiredString(raw['ru']);
  final ky = _requiredString(raw['ky']);
  final en = _requiredString(raw['en']);
  if (ru == null || ky == null || en == null) return null;
  return LocalizedText(ru: ru, ky: ky, en: en);
}

OrderType? _orderType(dynamic raw) => switch (raw) {
  'pickup' => OrderType.pickup,
  'scheduled' => OrderType.scheduled,
  'qr' => OrderType.qrCafe,
  _ => null,
};

OrderStatus? _orderStatus(dynamic raw) => switch (raw) {
  'new' => OrderStatus.created,
  'awaiting_payment' => OrderStatus.awaitingPayment,
  'paid' => OrderStatus.paid,
  'accepted' => OrderStatus.accepted,
  'preparing' => OrderStatus.preparing,
  'ready' => OrderStatus.ready,
  'done' || 'completed' => OrderStatus.completed,
  'cancelled' => OrderStatus.cancelled,
  _ => null,
};

PaymentMethod? _paymentMethod(dynamic raw) => switch (raw) {
  'mock' => PaymentMethod.mock,
  'cash' => PaymentMethod.cash,
  'qr' => PaymentMethod.qrDemo,
  _ => null,
};

IceLevel? _iceLevel(dynamic raw) => switch (raw) {
  'none' => IceLevel.none,
  'less' => IceLevel.less,
  'regular' => IceLevel.regular,
  'extra' => IceLevel.extra,
  _ => null,
};

RecurringOrder? parseCustomerRecurringOrder(dynamic raw) {
  if (raw is! Map<String, dynamic>) return null;
  final productIds = _stringList(raw['productIds']);
  final time = _requiredString(raw['time']);
  final branchId = _requiredString(raw['branchId']);
  final plan = _recurringPlan(raw['plan']);
  final paidUntilRaw = raw['paidUntil'];
  final paidUntil = paidUntilRaw is String
      ? DateTime.tryParse(paidUntilRaw)
      : null;
  if (productIds == null ||
      productIds.isEmpty ||
      productIds.length != productIds.toSet().length ||
      time == null ||
      !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time) ||
      branchId == null ||
      plan == null ||
      (paidUntilRaw != null && paidUntil == null) ||
      raw['active'] != true) {
    return null;
  }
  return RecurringOrder(
    productIds: List.unmodifiable(productIds),
    time: time,
    branchId: branchId,
    plan: plan,
    paidUntil: paidUntil,
  );
}

RecurringPlan? _recurringPlan(dynamic raw) => switch (raw) {
  'single' => RecurringPlan.single,
  'week' => RecurringPlan.week,
  'month' => RecurringPlan.month,
  _ => null,
};

/// Разбор цвета `#RRGGBB` из API; null при любом другом формате.
Color? parseHexColor(String? raw) {
  if (raw == null) return null;
  final hex = raw.trim().replaceFirst('#', '');
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

/// Клиент demo-API. Все методы «мягкие»: таймаут 2 секунды на запрос,
/// любая ошибка сети/формата -> null, приложение продолжает жить на DemoData.
class ApiClient {
  ApiClient({this.companyId = 'sweettime'});

  final String companyId;

  static const Duration _timeout = Duration(seconds: 2);
  static const Duration _googleAuthTimeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(seconds: 30);

  Uri _uri(String path) => Uri.parse('$apiBase/api/companies/$companyId$path');

  Future<dynamic> _getJson(String path) async {
    final response = await http.get(_uri(path)).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', _uri(path));
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// `GET /config` — брендинг (appName, accentColor) и правила лояльности.
  Future<CompanyConfig?> fetchConfig() async {
    try {
      final json = await _getJson('/config') as Map<String, dynamic>;
      final loyalty = json['loyalty'];
      final loyaltyMap = loyalty is Map<String, dynamic>
          ? loyalty
          : const <String, dynamic>{};
      return CompanyConfig(
        appName: (json['appName'] ?? json['name']) as String?,
        accentColor: parseHexColor(json['accentColor'] as String?),
        earnRate: (loyaltyMap['earnRate'] as num?)?.toDouble(),
        maxSpendShare: (loyaltyMap['maxSpendShare'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  /// `GET /products` — активные товары, смапленные в существующую модель [Product].
  /// Недостающие в API поля (rating, картинка) берём из демо-товара с тем же id.
  Future<List<Product>?> fetchProducts() async {
    try {
      final json = await _getJson('/products') as List<dynamic>;
      return [
        for (final item in json.whereType<Map<String, dynamic>>())
          if (item['active'] != false) _mapProduct(item),
      ];
    } catch (_) {
      return null;
    }
  }

  /// `GET /branches` — филиалы; ссылок на карты в API нет, берём из демо-данных.
  Future<List<Branch>?> fetchBranches() async {
    try {
      final json = await _getJson('/branches') as List<dynamic>;
      return [
        for (final item in json.whereType<Map<String, dynamic>>())
          _mapBranch(item),
      ];
    } catch (_) {
      return null;
    }
  }

  /// `GET /news` — новости-сторис витрины (только опубликованные, по sortOrder).
  /// Форма — docs/design/DEMO_API.md §«Управление контентом витрины».
  Future<List<NewsStory>?> fetchNews() async {
    try {
      final json = await _getJson('/news') as List<dynamic>;
      final stories = [
        for (final item in json.whereType<Map<String, dynamic>>())
          if (item['isPublished'] != false) mapNewsStory(item),
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return stories;
    } catch (_) {
      return null;
    }
  }

  Future<List<NewsStory>?> fetchHomeStories({int limit = 30}) async {
    try {
      final safeLimit = limit.clamp(0, 30);
      final json = await _getJson('/stories/home?limit=$safeLimit');
      return selectHomeStories([
        for (final item in _pageItems(json).whereType<Map<String, dynamic>>())
          mapNewsStory(item),
      ], limit: safeLimit);
    } catch (_) {
      return null;
    }
  }

  Future<List<StoryCollection>?> fetchStoryCollections() async {
    try {
      final json = await _getJson('/story-collections');
      final collections =
          [
            for (final item in _pageItems(
              json,
            ).whereType<Map<String, dynamic>>())
              if (item['isPublished'] != false) mapStoryCollection(item),
          ]..sort((left, right) {
            final order = left.sortOrder.compareTo(right.sortOrder);
            return order == 0 ? left.id.compareTo(right.id) : order;
          });
      return collections;
    } catch (_) {
      return null;
    }
  }

  Future<List<NewsStory>?> fetchCollectionStories(String collectionId) async {
    try {
      final encodedId = Uri.encodeComponent(collectionId);
      final json = await _fetchAllPages(
        '/story-collections/$encodedId/stories',
      );
      final stories =
          [
                for (final item in json.whereType<Map<String, dynamic>>())
                  mapNewsStory(item),
              ]
              .where((story) => story.isActiveAt(DateTime.now().toUtc()))
              .toList()
            ..sort(compareNewsStories);
      return stories;
    } catch (_) {
      return null;
    }
  }

  Future<List<NewsPost>?> fetchNewsPosts() async {
    try {
      final json = await _fetchAllPages('/news-posts');
      final now = DateTime.now().toUtc();
      final posts =
          [
            for (final item in json.whereType<Map<String, dynamic>>())
              mapNewsPost(item),
          ].where((post) => post.isActiveAt(now)).toList()..sort((left, right) {
            final leftDate = left.publishedDate;
            final rightDate = right.publishedDate;
            if (leftDate != null && rightDate != null) {
              final date = rightDate.compareTo(leftDate);
              if (date != 0) return date;
            }
            return left.id.compareTo(right.id);
          });
      return posts;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _pageItems(Object? json) {
    if (json is List<dynamic>) return json;
    if (json is Map<String, dynamic> && json['items'] is List<dynamic>) {
      return json['items'] as List<dynamic>;
    }
    throw const FormatException('Expected a list or page envelope');
  }

  Future<List<dynamic>> _fetchAllPages(String path) async {
    final result = <dynamic>[];
    String? cursor;
    final seenCursors = <String>{};
    for (var page = 0; page < 100; page++) {
      final separator = path.contains('?') ? '&' : '?';
      final cursorQuery = cursor == null
          ? ''
          : '&cursor=${Uri.encodeQueryComponent(cursor)}';
      final json = await _getJson('$path${separator}limit=50$cursorQuery');
      result.addAll(_pageItems(json));
      if (json is! Map<String, dynamic>) break;
      final next = json['nextCursor']?.toString().trim();
      if (next == null || next.isEmpty || !seenCursors.add(next)) break;
      cursor = next;
    }
    return result;
  }

  /// `GET /promotions` — сезонные акции (только активные, по sortOrder).
  Future<List<Promotion>?> fetchPromotions() async {
    try {
      final json = await _getJson('/promotions') as List<dynamic>;
      final maps =
          json
              .whereType<Map<String, dynamic>>()
              .where((item) => item['active'] != false)
              .toList()
            ..sort(
              (a, b) => ((a['sortOrder'] as num?)?.toInt() ?? 0).compareTo(
                (b['sortOrder'] as num?)?.toInt() ?? 0,
              ),
            );
      return [for (final item in maps) _mapPromotion(item)];
    } catch (_) {
      return null;
    }
  }

  /// `POST /auth/otp/request` — просим сервер выслать код на телефон.
  /// SMS-провайдера пока нет: сервер отвечает `mode: "mock"` и кодом `1111`.
  /// true = сервер принял запрос; false = офлайн/ошибка (демо-код всё равно работает).
  Future<bool> otpRequest(String phone) async {
    try {
      final response = await http
          .post(
            _uri('/auth/otp/request'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone}),
          )
          .timeout(_timeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// `POST /auth/otp/verify` — вход по коду. 400 -> [ApiAuthStatus.rejected]
  /// (неверный код), ошибка сети -> [ApiAuthStatus.unavailable].
  Future<ApiResult<CustomerSession>> otpVerify(
    String phone,
    String code,
  ) async {
    try {
      final response = await http
          .post(
            _uri('/auth/otp/verify'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'code': code}),
          )
          .timeout(_timeout);
      if (response.statusCode == 400 || response.statusCode == 401) {
        return const ApiResult<CustomerSession>.rejected();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ApiResult<CustomerSession>.unavailable();
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) {
        return const ApiResult<CustomerSession>.unavailable();
      }
      final tokens = TokenPair.tryParse(json);
      final parsedProfile = CustomerProfile.tryParse(json['user']);
      final profile = parsedProfile == null
          ? null
          : _resolveProfileMedia(parsedProfile);
      if (tokens == null || profile == null) {
        return const ApiResult<CustomerSession>.unavailable();
      }
      return ApiResult<CustomerSession>.ok(
        CustomerSession(tokens: tokens, profile: profile),
      );
    } catch (_) {
      return const ApiResult<CustomerSession>.unavailable();
    }
  }

  /// Exchanges a Google OpenID Connect ID token for SweetTime's own session.
  /// Email/name from the device are deliberately not sent or trusted.
  Future<ApiResult<CustomerSession>> googleSignIn(String idToken) async {
    try {
      final response = await http
          .post(
            _uri('/auth/google'),
            headers: _jsonHeader,
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(_googleAuthTimeout);
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        return const ApiResult<CustomerSession>.rejected();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ApiResult<CustomerSession>.unavailable();
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return const ApiResult<CustomerSession>.unavailable();
      }
      final tokens = TokenPair.tryParse(decoded);
      final parsedProfile = CustomerProfile.tryParse(decoded['user']);
      final profile = parsedProfile == null
          ? null
          : _resolveProfileMedia(parsedProfile);
      if (tokens == null || profile == null) {
        return const ApiResult<CustomerSession>.unavailable();
      }
      return ApiResult<CustomerSession>.ok(
        CustomerSession(tokens: tokens, profile: profile),
      );
    } catch (_) {
      return const ApiResult<CustomerSession>.unavailable();
    }
  }

  /// Saves a contact number for a signed-in customer. This endpoint does not
  /// verify ownership; [CustomerProfile.phoneVerified] remains server-owned.
  Future<ApiResult<CustomerProfile>> patchCustomerContact(
    String accessToken,
    String phone,
  ) async {
    try {
      final response = await http
          .patch(
            _uri('/auth/customer/me/contact'),
            headers: {..._bearer(accessToken), ..._jsonHeader},
            body: jsonEncode({'phone': phone}),
          )
          .timeout(_timeout);
      return _parseProfileResponse(response);
    } catch (_) {
      return const ApiResult<CustomerProfile>.unavailable();
    }
  }

  /// `GET /auth/customer/me` — восстановление сессии по сохранённому токену.
  /// 401 -> [ApiAuthStatus.rejected]: токен протух, нужен refresh.
  Future<ApiResult<CustomerProfile>> fetchCustomerMe(String accessToken) async {
    try {
      final response = await http
          .get(_uri('/auth/customer/me'), headers: _bearer(accessToken))
          .timeout(_timeout);
      return _parseProfileResponse(response);
    } catch (_) {
      return const ApiResult<CustomerProfile>.unavailable();
    }
  }

  /// `DELETE /auth/customer/me` — окончательное удаление серверного аккаунта.
  Future<ApiResult<bool>> deleteCustomerAccount(String accessToken) async {
    try {
      final response = await http
          .delete(_uri('/auth/customer/me'), headers: _bearer(accessToken))
          .timeout(_timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const ApiResult<bool>.rejected();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ApiResult<bool>.unavailable();
      }
      return const ApiResult<bool>.ok(true);
    } catch (_) {
      return const ApiResult<bool>.unavailable();
    }
  }

  /// `PATCH /auth/customer/me` — свои имя/фамилия/дата рождения на сервере.
  /// `birthDate`: ISO `YYYY-MM-DD`; пустая строка — очистить поле.
  Future<ApiResult<CustomerProfile>> patchCustomerMe(
    String accessToken, {
    String? firstName,
    String? lastName,
    String? birthDate,
  }) async {
    try {
      final response = await http
          .patch(
            _uri('/auth/customer/me'),
            headers: {..._bearer(accessToken), ..._jsonHeader},
            body: jsonEncode({
              // null-поля не отправляем: PATCH частичный, сервер их не трогает.
              'firstName': ?firstName,
              'lastName': ?lastName,
              'birthDate': ?birthDate,
            }),
          )
          .timeout(_timeout);
      return _parseProfileResponse(response);
    } catch (_) {
      return const ApiResult<CustomerProfile>.unavailable();
    }
  }

  /// `PUT /auth/customer/me/avatar` — multipart WebP/JPEG/PNG; tenant и
  /// владелец берутся сервером из JWT, путь/slug клиент не присылает.
  Future<ApiResult<CustomerProfile>> uploadCustomerAvatar(
    String accessToken, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        _uri('/auth/customer/me/avatar'),
      )..headers.addAll(_bearer(accessToken));
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType.parse(contentType),
        ),
      );
      final streamed = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamed);
      return _parseProfileResponse(response);
    } catch (_) {
      return const ApiResult<CustomerProfile>.unavailable();
    }
  }

  /// `DELETE /auth/customer/me/avatar` — идемпотентное удаление.
  Future<ApiResult<bool>> deleteCustomerAvatar(String accessToken) async {
    try {
      final response = await http
          .delete(
            _uri('/auth/customer/me/avatar'),
            headers: _bearer(accessToken),
          )
          .timeout(_timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const ApiResult<bool>.rejected();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ApiResult<bool>.unavailable();
      }
      return const ApiResult<bool>.ok(true);
    } catch (_) {
      return const ApiResult<bool>.unavailable();
    }
  }

  /// `GET /auth/customer/me/favorites` — серверный список избранного клиента.
  /// Пустой список является полноценным успешным ответом и не заменяется demo-данными.
  Future<ApiResult<List<String>>> fetchCustomerFavorites(
    String accessToken,
  ) async {
    try {
      final response = await http
          .get(
            _uri('/auth/customer/me/favorites'),
            headers: _bearer(accessToken),
          )
          .timeout(_timeout);
      return _parseFavoritesResponse(response);
    } catch (_) {
      return const ApiResult<List<String>>.unavailable();
    }
  }

  /// Полностью заменяет избранное. Серверный ответ авторитетен: API удаляет
  /// дубли, неизвестные товары и ID другой компании.
  /// `GET /auth/customer/me/orders` — newest customer orders first.
  ///
  /// An empty list is authoritative. Any malformed order makes the response
  /// unavailable so corrupted payloads are never presented as an empty history.
  Future<ApiResult<List<OrderHistoryEntry>>> fetchCustomerOrders(
    String accessToken,
  ) async {
    try {
      final response = await http
          .get(_uri('/auth/customer/me/orders'), headers: _bearer(accessToken))
          .timeout(_timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const ApiResult<List<OrderHistoryEntry>>.rejected();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ApiResult<List<OrderHistoryEntry>>.unavailable();
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List<dynamic>) {
        return const ApiResult<List<OrderHistoryEntry>>.unavailable();
      }
      final orders = <OrderHistoryEntry>[];
      for (final rawOrder in decoded) {
        final order = parseCustomerOrderHistoryEntry(rawOrder);
        if (order == null) {
          return const ApiResult<List<OrderHistoryEntry>>.unavailable();
        }
        orders.add(order);
      }
      return ApiResult<List<OrderHistoryEntry>>.ok(List.unmodifiable(orders));
    } catch (_) {
      return const ApiResult<List<OrderHistoryEntry>>.unavailable();
    }
  }

  /// `GET /auth/customer/me/recurring` — `null` is the authoritative
  /// no-active-subscription state.
  Future<ApiResult<RecurringOrder?>> fetchCustomerRecurring(
    String accessToken,
  ) async {
    try {
      final response = await http
          .get(
            _uri('/auth/customer/me/recurring'),
            headers: _bearer(accessToken),
          )
          .timeout(_timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const ApiResult<RecurringOrder?>.rejected();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ApiResult<RecurringOrder?>.unavailable();
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded == null) return const ApiResult<RecurringOrder?>.ok(null);
      final recurring = parseCustomerRecurringOrder(decoded);
      return recurring == null
          ? const ApiResult<RecurringOrder?>.unavailable()
          : ApiResult<RecurringOrder?>.ok(recurring);
    } catch (_) {
      return const ApiResult<RecurringOrder?>.unavailable();
    }
  }

  Future<ApiResult<RecurringOrder?>> replaceCustomerRecurring(
    String accessToken, {
    required List<String> productIds,
    required String time,
    required String branchId,
    required RecurringPlan plan,
  }) async {
    try {
      final response = await http
          .put(
            _uri('/auth/customer/me/recurring'),
            headers: {..._bearer(accessToken), ..._jsonHeader},
            body: jsonEncode({
              'productIds': productIds,
              'time': time,
              'branchId': branchId,
              'plan': plan.name,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const ApiResult<RecurringOrder?>.rejected();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ApiResult<RecurringOrder?>.unavailable();
      }
      final recurring = parseCustomerRecurringOrder(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
      return recurring == null
          ? const ApiResult<RecurringOrder?>.unavailable()
          : ApiResult<RecurringOrder?>.ok(recurring);
    } catch (_) {
      return const ApiResult<RecurringOrder?>.unavailable();
    }
  }

  Future<ApiResult<bool>> deleteCustomerRecurring(String accessToken) async {
    try {
      final response = await http
          .delete(
            _uri('/auth/customer/me/recurring'),
            headers: _bearer(accessToken),
          )
          .timeout(_timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const ApiResult<bool>.rejected();
      }
      if (response.statusCode != 204) {
        return const ApiResult<bool>.unavailable();
      }
      return const ApiResult<bool>.ok(true);
    } catch (_) {
      return const ApiResult<bool>.unavailable();
    }
  }

  /// Fully replaces favorites with the server-authoritative ID list.
  Future<ApiResult<List<String>>> replaceCustomerFavorites(
    String accessToken,
    List<String> productIds,
  ) async {
    try {
      final response = await http
          .put(
            _uri('/auth/customer/me/favorites'),
            headers: {..._bearer(accessToken), ..._jsonHeader},
            body: jsonEncode({'productIds': productIds}),
          )
          .timeout(_timeout);
      return _parseFavoritesResponse(response);
    } catch (_) {
      return const ApiResult<List<String>>.unavailable();
    }
  }

  /// `POST /auth/refresh` — новая пара токенов, когда access протух.
  Future<ApiResult<TokenPair>> refreshTokens(String refreshToken) async {
    try {
      final response = await http
          .post(
            _uri('/auth/refresh'),
            headers: _jsonHeader,
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);
      if (response.statusCode == 400 || response.statusCode == 401) {
        return const ApiResult<TokenPair>.rejected();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ApiResult<TokenPair>.unavailable();
      }
      final tokens = TokenPair.tryParse(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
      return tokens == null
          ? const ApiResult<TokenPair>.unavailable()
          : ApiResult<TokenPair>.ok(tokens);
    } catch (_) {
      return const ApiResult<TokenPair>.unavailable();
    }
  }

  ApiResult<CustomerProfile> _parseProfileResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const ApiResult<CustomerProfile>.rejected();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const ApiResult<CustomerProfile>.unavailable();
    }
    final parsedProfile = CustomerProfile.tryParse(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
    final profile = parsedProfile == null
        ? null
        : _resolveProfileMedia(parsedProfile);
    return profile == null
        ? const ApiResult<CustomerProfile>.unavailable()
        : ApiResult<CustomerProfile>.ok(profile);
  }

  ApiResult<List<String>> _parseFavoritesResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const ApiResult<List<String>>.rejected();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const ApiResult<List<String>>.unavailable();
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return const ApiResult<List<String>>.unavailable();
      }
      final rawIds = decoded['productIds'];
      if (rawIds is! List<dynamic>) {
        return const ApiResult<List<String>>.unavailable();
      }
      final ids = <String>[];
      for (final rawId in rawIds) {
        if (rawId is! String) {
          return const ApiResult<List<String>>.unavailable();
        }
        ids.add(rawId);
      }
      return ApiResult<List<String>>.ok(List.unmodifiable(ids));
    } catch (_) {
      return const ApiResult<List<String>>.unavailable();
    }
  }

  CustomerProfile _resolveProfileMedia(CustomerProfile profile) {
    final raw = profile.avatarUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return profile.copyWith(clearAvatarUrl: true);
    }
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) return profile;
    final base = Uri.parse(apiBase.endsWith('/') ? apiBase : '$apiBase/');
    final relative = raw.startsWith('/') ? raw.substring(1) : raw;
    return profile.copyWith(avatarUrl: base.resolve(relative).toString());
  }

  static const Map<String, String> _jsonHeader = {
    'Content-Type': 'application/json',
  };

  static Map<String, String> _bearer(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
  };

  /// `POST /orders` — заказ из приложения. Требует токен клиента: имя заказчика
  /// сервер берёт из токена, а не из тела. null = офлайн/ошибка:
  /// вызывающий код оформляет заказ локально, как раньше.
  Future<CreatedOrder?> createOrder({
    required String branchId,
    required String type, // pickup | scheduled | qr
    required String readyTime,
    required List<Map<String, Object?>> items,
    required String paymentMethod,
    required int pointsUsed,
    String? accessToken,
  }) async {
    try {
      final response = await http
          .post(
            _uri('/orders'),
            headers: {
              ..._jsonHeader,
              if (accessToken != null) ..._bearer(accessToken),
            },
            body: jsonEncode({
              'branchId': branchId,
              'type': type,
              'readyTime': readyTime,
              'items': items,
              'paymentMethod': paymentMethod,
              'pointsUsed': pointsUsed,
            }),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final number = json['number'];
      if (number == null) return null;
      return CreatedOrder(
        number: number.toString(),
        pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static Product _mapProduct(Map<String, dynamic> json) {
    final id = json['id'].toString();
    Product? demo;
    for (final p in DemoData.products) {
      if (p.id == id) {
        demo = p;
        break;
      }
    }
    return Product(
      id: id,
      category: _mapCategory(json, demo?.category),
      name: _mapLocalizedText(
        json['name'],
        known: demo?.name,
        fallback: const LocalizedText(
          ru: 'Напиток',
          ky: 'Суусундук',
          en: 'Drink',
        ),
      ),
      description: _mapLocalizedText(
        json['description'],
        known: demo?.description,
        fallback: const LocalizedText(ru: '', ky: '', en: ''),
      ),
      basePrice: (json['price'] as num?)?.toInt() ?? demo?.basePrice ?? 0,
      accentColor:
          parseHexColor(json['color'] as String?) ??
          demo?.accentColor ??
          const Color(0xFFFF9EC6),
      rating: demo?.rating ?? 4.8,
      reviewsCount: demo?.reviewsCount ?? 120,
      sizes: _mapModifiers(json['sizes'], demo?.sizes),
      toppings: _mapModifiers(json['toppings'], demo?.toppings),
      availableBranchIds: [
        for (final b
            in (json['availableBranchIds'] as List<dynamic>? ?? const []))
          b.toString(),
      ],
      assetImage: demo?.assetImage,
      isNew: (json['isNew'] as bool?) ?? false,
      isBestSeller: (json['isBestSeller'] as bool?) ?? false,
    );
  }

  static List<ModifierOption> _mapModifiers(
    dynamic json,
    List<ModifierOption>? fallback,
  ) {
    if (json is! List) return fallback ?? const [];
    final options = <ModifierOption>[];
    for (final (index, item)
        in json.whereType<Map<String, dynamic>>().indexed) {
      final requestedId = item['id']?.toString();
      ModifierOption? known;
      if (requestedId != null) {
        for (final option in fallback ?? const <ModifierOption>[]) {
          if (option.id == requestedId) {
            known = option;
            break;
          }
        }
      }
      final legacyName = item['name'] is String ? item['name'] as String : null;
      if (known == null && legacyName != null) {
        for (final option in fallback ?? const <ModifierOption>[]) {
          if (option.name.ru == legacyName) {
            known = option;
            break;
          }
        }
      }
      if (known == null && fallback != null && index < fallback.length) {
        known = fallback[index];
      }
      final name = _mapLocalizedText(
        item['name'],
        known: known?.name,
        fallback: const LocalizedText(ru: '', ky: '', en: ''),
      );
      options.add(
        ModifierOption(
          id: requestedId ?? known?.id ?? _stableId(name.ru, 'modifier-$index'),
          name: name,
          priceDelta: (item['priceDelta'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return options.isEmpty ? (fallback ?? const []) : options;
  }

  static Branch _mapBranch(Map<String, dynamic> json) {
    final id = json['id'].toString();
    Branch? demo;
    for (final b in DemoData.branches) {
      if (b.id == id) {
        demo = b;
        break;
      }
    }
    return Branch(
      id: id,
      name: _mapLocalizedText(
        json['name'],
        known: demo?.name,
        fallback: const LocalizedText(ru: 'Филиал', ky: 'Филиал', en: 'Branch'),
      ),
      address: _mapLocalizedText(
        json['address'],
        known: demo?.address,
        fallback: const LocalizedText(ru: '', ky: '', en: ''),
      ),
      hours: (json['hours'] as String?) ?? demo?.hours ?? '',
      phone: (json['phone'] as String?) ?? demo?.phone ?? '',
      isOpen: (json['isOpen'] as bool?) ?? true,
      twoGisUrl: demo?.twoGisUrl ?? 'https://2gis.kg/bishkek',
      googleMapsUrl: demo?.googleMapsUrl ?? 'https://maps.google.com',
    );
  }

  /// `#RRGGBB` -> 0xFFRRGGBB (int для NewsStory.accentHex); [fallback] при ошибке.
  static int _parseHexInt(String? raw, int fallback) {
    if (raw == null) return fallback;
    final hex = raw.trim().replaceFirst('#', '');
    if (hex.length != 6) return fallback;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : (0xFF000000 | value);
  }

  static NewsMediaType _mapNewsMediaType(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    return NewsMediaType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => NewsMediaType.none,
    );
  }

  static NewsStory mapNewsStory(Map<String, dynamic> json) {
    final visualRaw = (json['visual'] as String?)?.trim();
    final visual = NewsStoryVisual.values.firstWhere(
      (v) => v.name == visualRaw,
      orElse: () => NewsStoryVisual.sparkle,
    );
    final ctaLabelRaw = json['ctaLabel'];
    return NewsStory(
      id: json['id'].toString(),
      title: _mapLocalizedText(
        json['title'],
        fallback: const LocalizedText(ru: 'Новость', ky: 'Жаңылык', en: 'News'),
      ),
      body: _mapLocalizedText(
        json['body'],
        fallback: const LocalizedText(ru: '', ky: '', en: ''),
      ),
      badge: _mapLocalizedText(
        json['badge'],
        fallback: const LocalizedText(ru: '', ky: '', en: ''),
      ),
      accentHex: _parseHexInt(json['accentColor'] as String?, 0xFFFF5C9A),
      visual: visual,
      publishedAt: (json['publishedAt'] as String?)?.trim() ?? '',
      expiresAt: json['expiresAt'] as String?,
      isPublished: (json['isPublished'] as bool?) ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      companyId: json['companyId']?.toString(),
      collectionId: json['collectionId']?.toString(),
      showOnHome: (json['showOnHome'] as bool?) ?? true,
      isPinned: (json['isPinned'] as bool?) ?? false,
      imageUrl: json['imageUrl'] as String?,
      mediaType: _mapNewsMediaType(json['mediaType']),
      mediaUrl: json['mediaUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      ctaLabel: ctaLabelRaw == null
          ? null
          : _mapLocalizedText(
              ctaLabelRaw,
              fallback: const LocalizedText(ru: '', ky: '', en: ''),
            ),
      ctaRoute: json['ctaRoute'] as String?,
    );
  }

  static StoryCollection mapStoryCollection(Map<String, dynamic> json) {
    final visualRaw = (json['visual'] as String?)?.trim();
    final visual = NewsStoryVisual.values.firstWhere(
      (candidate) => candidate.name == visualRaw,
      orElse: () => NewsStoryVisual.sparkle,
    );
    final description = json['description'];
    return StoryCollection(
      id: json['id'].toString(),
      companyId: json['companyId']?.toString(),
      name: _mapLocalizedText(
        json['name'] ?? json['title'],
        fallback: const LocalizedText(
          ru: 'Новости',
          ky: 'Жаңылыктар',
          en: 'News',
        ),
      ),
      description: description == null
          ? null
          : _mapLocalizedText(
              description,
              fallback: const LocalizedText(ru: '', ky: '', en: ''),
            ),
      coverImageUrl:
          (json['coverImageUrl'] ?? json['coverThumbnail']) as String?,
      accentHex: _parseHexInt(json['accentColor'] as String?, 0xFFFF5C9A),
      visual: visual,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isPublished: (json['isPublished'] as bool?) ?? true,
    );
  }

  static NewsPost mapNewsPost(Map<String, dynamic> json) {
    return NewsPost(
      id: json['id'].toString(),
      companyId: json['companyId']?.toString(),
      title: _mapLocalizedText(
        json['title'],
        fallback: const LocalizedText(ru: 'Новость', ky: 'Жаңылык', en: 'News'),
      ),
      summary: _mapLocalizedText(
        json['summary'],
        fallback: const LocalizedText(ru: '', ky: '', en: ''),
      ),
      body: _mapLocalizedText(
        json['body'],
        fallback: const LocalizedText(ru: '', ky: '', en: ''),
      ),
      isPublished: (json['isPublished'] as bool?) ?? true,
      publishedAt: (json['publishedAt'] as String?)?.trim() ?? '',
      mediaType: _mapNewsMediaType(json['mediaType']),
      mediaUrl: json['mediaUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  static Promotion _mapPromotion(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'].toString(),
      title: _mapLocalizedText(
        json['title'],
        fallback: const LocalizedText(ru: 'Акция', ky: 'Акция', en: 'Promo'),
      ),
      description: _mapLocalizedText(
        json['description'],
        fallback: const LocalizedText(ru: '', ky: '', en: ''),
      ),
      code: (json['code'] as String?) ?? '',
    );
  }

  static MenuCategory _mapCategory(
    Map<String, dynamic> productJson,
    MenuCategory? demoCategory,
  ) {
    final raw = productJson['category'];
    final rawMap = raw is Map<String, dynamic> ? raw : null;
    final explicitId =
        productJson['categoryId']?.toString() ?? rawMap?['id']?.toString();
    final legacyName = raw is String ? raw : null;

    MenuCategory? known;
    if (explicitId != null) {
      for (final category in DemoData.categories) {
        if (category.id == explicitId) {
          known = category;
          break;
        }
      }
    }
    if (known == null && legacyName != null) {
      for (final category in DemoData.categories) {
        if (category.name.ru == legacyName) {
          known = category;
          break;
        }
      }
    }
    known ??= demoCategory;
    final nameSource = rawMap?['name'] ?? raw;
    final name = _mapLocalizedText(
      nameSource,
      known: known?.name,
      fallback: const LocalizedText(ru: 'Меню', ky: 'Меню', en: 'Menu'),
    );
    return MenuCategory(
      id: explicitId ?? known?.id ?? _stableId(name.ru, 'menu'),
      name: name,
    );
  }

  static LocalizedText _mapLocalizedText(
    dynamic raw, {
    LocalizedText? known,
    required LocalizedText fallback,
  }) {
    if (raw is String) {
      final ru = raw.trim().isEmpty ? (known?.ru ?? fallback.ru) : raw;
      return LocalizedText(
        ru: ru,
        ky: known?.ky ?? fallback.ky,
        en: known?.en ?? fallback.en,
      );
    }
    if (raw is Map<String, dynamic>) {
      return LocalizedText(
        ru: _presentString(raw['ru']) ?? known?.ru ?? fallback.ru,
        ky: _presentString(raw['ky']) ?? known?.ky ?? fallback.ky,
        en: _presentString(raw['en']) ?? known?.en ?? fallback.en,
      );
    }
    return known ?? fallback;
  }

  static String? _presentString(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  static String _stableId(String value, String fallback) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? fallback : normalized;
  }
}

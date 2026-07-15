import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../shared/app_models.dart';
import '../shared/demo_data.dart';

/// Базовый URL боевого API (`backend/api`, порт 8010). Переопределяется при сборке:
/// `flutter build apk --dart-define=API_BASE=http://10.0.2.2:8010` (эмулятор) или
/// `--dart-define=API_BASE=http://<ip-сервера>:8010` (телефон/деплой).
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
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.points,
    required this.referralCode,
    required this.invitedByCode,
  });

  final String id;
  final String phone;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  final int points;
  final String? referralCode;
  final String? invitedByCode;

  static CustomerProfile? tryParse(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    if (id == null) return null;
    return CustomerProfile(
      id: id.toString(),
      phone: (raw['phone'] as String?) ?? '',
      firstName: (raw['firstName'] as String?) ?? '',
      lastName: (raw['lastName'] as String?) ?? '',
      birthDate: DateTime.tryParse((raw['birthDate'] as String?) ?? ''),
      points: (raw['points'] as num?)?.toInt() ?? 0,
      referralCode: raw['referralCode'] as String?,
      invitedByCode: raw['invitedByCode'] as String?,
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
          if (item['isPublished'] != false) _mapNews(item),
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return stories;
    } catch (_) {
      return null;
    }
  }

  /// `GET /promotions` — сезонные акции (только активные, по sortOrder).
  Future<List<Promotion>?> fetchPromotions() async {
    try {
      final json = await _getJson('/promotions') as List<dynamic>;
      final maps = json
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
  Future<ApiResult<CustomerSession>> otpVerify(String phone, String code) async {
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
      final profile = CustomerProfile.tryParse(json['user']);
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
    final profile = CustomerProfile.tryParse(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
    return profile == null
        ? const ApiResult<CustomerProfile>.unavailable()
        : ApiResult<CustomerProfile>.ok(profile);
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
    required List<Map<String, Object>> items,
    required int total,
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
              'total': total,
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

  static NewsStory _mapNews(Map<String, dynamic> json) {
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
      publishedAt:
          (json['publishedAt'] as String?) ?? DateTime.now().toIso8601String(),
      expiresAt: json['expiresAt'] as String?,
      isPublished: (json['isPublished'] as bool?) ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      ctaLabel: ctaLabelRaw == null
          ? null
          : _mapLocalizedText(
              ctaLabelRaw,
              fallback: const LocalizedText(ru: '', ky: '', en: ''),
            ),
      ctaRoute: json['ctaRoute'] as String?,
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

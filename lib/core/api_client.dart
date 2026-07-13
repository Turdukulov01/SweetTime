import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../shared/app_models.dart';
import '../shared/demo_data.dart';

/// Базовый URL demo-API (docs/design/DEMO_API.md). Переопределяется при сборке:
/// `flutter build apk --dart-define=API_BASE=http://10.0.2.2:8000`.
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://127.0.0.1:8000',
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

  /// `POST /orders` — заказ из приложения. null = офлайн/ошибка:
  /// вызывающий код оформляет заказ локально, как раньше.
  Future<CreatedOrder?> createOrder({
    required String customerName,
    required String branchId,
    required String type, // pickup | scheduled | qr
    required String readyTime,
    required List<Map<String, Object>> items,
    required int total,
    required int pointsUsed,
  }) async {
    try {
      final response = await http
          .post(
            _uri('/orders'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'customerName': customerName,
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

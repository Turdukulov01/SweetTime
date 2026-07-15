import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Минимальный локальный снимок позиции корзины.
///
/// Названия, цены и целые Product намеренно не сохраняются: после перезапуска
/// они восстанавливаются из свежего каталога по стабильным ID.
class CartDraftItem {
  const CartDraftItem({
    required this.productId,
    required this.quantity,
    required this.sizeId,
    required this.sugarPercent,
    required this.ice,
    required this.toppingIds,
  });

  final String productId;
  final int quantity;
  final String sizeId;
  final int sugarPercent;
  final String ice;
  final List<String> toppingIds;

  Map<String, Object> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'sizeId': sizeId,
    'sugarPercent': sugarPercent,
    'ice': ice,
    'toppingIds': toppingIds,
  };

  static CartDraftItem? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final productId = raw['productId'];
    final quantity = raw['quantity'];
    final sizeId = raw['sizeId'];
    final sugarPercent = raw['sugarPercent'];
    final ice = raw['ice'];
    final toppingIds = raw['toppingIds'];
    if (productId is! String ||
        productId.isEmpty ||
        quantity is! num ||
        sizeId is! String ||
        sizeId.isEmpty ||
        sugarPercent is! num ||
        ice is! String ||
        toppingIds is! List<dynamic> ||
        toppingIds.any((id) => id is! String)) {
      return null;
    }
    return CartDraftItem(
      productId: productId,
      quantity: quantity.toInt(),
      sizeId: sizeId,
      sugarPercent: sugarPercent.toInt(),
      ice: ice,
      toppingIds: List<String>.unmodifiable(toppingIds.cast<String>()),
    );
  }
}

abstract interface class CartStore {
  Future<List<CartDraftItem>> read();
  Future<void> write(List<CartDraftItem> items);
}

/// Корзина — device-scoped черновик. SharedPreferences подходит для маленького
/// JSON; секретов и платёжных данных здесь нет.
class SharedPreferencesCartStore implements CartStore {
  SharedPreferencesCartStore({required String companyId})
    : _storageKey = 'cart_draft_v1_$companyId';

  final String _storageKey;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<List<CartDraftItem>> read() async {
    final raw = await _instance.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        return const [];
      }
      final rawItems = decoded['items'];
      if (rawItems is! List<dynamic>) return const [];
      return List.unmodifiable([
        for (final rawItem in rawItems) ?CartDraftItem.tryParse(rawItem),
      ]);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write(List<CartDraftItem> items) async {
    if (items.isEmpty) {
      await _instance.remove(_storageKey);
      return;
    }
    await _instance.setString(
      _storageKey,
      jsonEncode({
        'version': 1,
        'items': [for (final item in items) item.toJson()],
      }),
    );
  }
}

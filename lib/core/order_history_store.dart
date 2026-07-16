import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OrderHistoryVisibilityStore {
  Future<Set<String>> readHiddenOrderIds();
  Future<void> writeHiddenOrderIds(Set<String> ids);
  Future<void> clear();
}

class SharedPreferencesOrderHistoryVisibilityStore
    implements OrderHistoryVisibilityStore {
  SharedPreferencesOrderHistoryVisibilityStore({required String companyId})
    : _storageKey = 'hidden_order_ids_v1_$companyId';

  final String _storageKey;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<Set<String>> readHiddenOrderIds() async {
    final raw = await _instance.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        return const {};
      }
      final ids = decoded['ids'];
      if (ids is! List<dynamic>) return const {};
      return Set.unmodifiable(
        ids
            .whereType<String>()
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty),
      );
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<void> writeHiddenOrderIds(Set<String> ids) async {
    final normalized =
        ids
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (normalized.isEmpty) {
      await clear();
      return;
    }
    await _instance.setString(
      _storageKey,
      jsonEncode({'version': 1, 'ids': normalized}),
    );
  }

  @override
  Future<void> clear() => _instance.remove(_storageKey);
}

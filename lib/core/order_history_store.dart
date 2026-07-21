import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OrderHistoryVisibilityStore {
  Future<Set<String>> readHiddenOrderIds(String accountId);
  Future<void> writeHiddenOrderIds(String accountId, Set<String> ids);
  Future<void> clear(String accountId);
}

class SharedPreferencesOrderHistoryVisibilityStore
    implements OrderHistoryVisibilityStore {
  SharedPreferencesOrderHistoryVisibilityStore({required this.companyId});

  final String companyId;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<Set<String>> readHiddenOrderIds(String accountId) async {
    final raw = await _instance.getString(_storageKey(accountId));
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
  Future<void> writeHiddenOrderIds(String accountId, Set<String> ids) async {
    final normalized =
        ids
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    if (normalized.isEmpty) {
      await clear(accountId);
      return;
    }
    await _instance.setString(
      _storageKey(accountId),
      jsonEncode({'version': 1, 'ids': normalized}),
    );
  }

  @override
  Future<void> clear(String accountId) =>
      _instance.remove(_storageKey(accountId));

  String _storageKey(String accountId) =>
      'hidden_order_ids_v2_${companyId}_${Uri.encodeComponent(accountId)}';
}

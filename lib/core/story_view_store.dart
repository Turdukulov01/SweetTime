import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-local record of stories that have already been opened.
///
/// Story viewing is presentation state rather than account data, so it is
/// intentionally kept on the device and isolated by company.
abstract interface class StoryViewStore {
  Future<Set<String>> readViewedStoryIds();
  Future<void> writeViewedStoryIds(Set<String> ids);
}

class SharedPreferencesStoryViewStore implements StoryViewStore {
  SharedPreferencesStoryViewStore({required String companyId})
    : _storageKey = 'viewed_story_ids_v1_$companyId';

  final String _storageKey;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<Set<String>> readViewedStoryIds() async {
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
  Future<void> writeViewedStoryIds(Set<String> ids) async {
    final normalized =
        ids
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    await _instance.setString(
      _storageKey,
      jsonEncode({'version': 1, 'ids': normalized}),
    );
  }
}

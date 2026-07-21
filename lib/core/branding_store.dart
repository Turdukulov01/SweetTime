import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

abstract interface class BrandingStore {
  Future<CompanyConfig?> read();
  Future<void> write(CompanyConfig config);
}

class SharedPreferencesBrandingStore implements BrandingStore {
  SharedPreferencesBrandingStore({required this.companyId});

  final String companyId;
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();
  String get _key => 'company_branding_v1_$companyId';

  @override
  Future<CompanyConfig?> read() async {
    final raw = await _instance.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CompanyConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(CompanyConfig config) =>
      _instance.setString(_key, jsonEncode(config.toJson()));
}

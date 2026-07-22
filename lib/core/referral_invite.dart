import 'package:shared_preferences/shared_preferences.dart';

const referralInviteHost = 'lnp-corporation.duckdns.org';
const referralCompanyId = 'sweettime';
const _legacyReferralPrefix = 'SWEETTIME:REF:';

final RegExp _safeReferralCode = RegExp(r'^[A-Z0-9-]{4,64}$');
final RegExp _safeCompanyId = RegExp(r'^[a-z0-9-]{2,64}$');

/// Public invitation URL used by QR codes, the system share sheet and App Links.
String referralInviteUrl(
  String rawCode, {
  String companyId = referralCompanyId,
}) {
  final code = normalizeReferralCode(rawCode);
  final company = companyId.trim().toLowerCase();
  if (code == null || !_safeCompanyId.hasMatch(company)) {
    throw ArgumentError('Invalid referral invitation');
  }
  return Uri.https(referralInviteHost, '/invite/$company/$code').toString();
}

/// Accepts a plain code, the legacy in-app QR payload or the new HTTPS link.
String? normalizeReferralCode(String raw) {
  var value = raw.trim();
  if (value.startsWith(_legacyReferralPrefix)) {
    value = value.substring(_legacyReferralPrefix.length);
  } else {
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.host.toLowerCase() == referralInviteHost &&
        uri.pathSegments.length == 3 &&
        uri.pathSegments.first == 'invite' &&
        uri.pathSegments[1].toLowerCase() == referralCompanyId) {
      value = uri.pathSegments[2];
    }
  }
  final normalized = value.trim().toUpperCase();
  return _safeReferralCode.hasMatch(normalized) ? normalized : null;
}

abstract interface class ReferralInviteStore {
  Future<String?> read();
  Future<void> write(String code);
  Future<void> clear();
}

class SharedPreferencesReferralInviteStore implements ReferralInviteStore {
  SharedPreferencesReferralInviteStore({this.companyId = referralCompanyId});

  final String companyId;
  SharedPreferencesAsync? _preferences;

  String get _key => 'pending_referral_invite_$companyId';
  SharedPreferencesAsync get _instance =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<String?> read() async {
    final raw = await _instance.getString(_key);
    return raw == null ? null : normalizeReferralCode(raw);
  }

  @override
  Future<void> write(String code) async {
    final normalized = normalizeReferralCode(code);
    if (normalized == null) throw ArgumentError.value(code, 'code');
    await _instance.setString(_key, normalized);
  }

  @override
  Future<void> clear() => _instance.remove(_key);
}

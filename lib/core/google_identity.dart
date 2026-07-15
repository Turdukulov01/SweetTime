import 'package:google_sign_in/google_sign_in.dart';

const String googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue:
      '23205820785-ap4kgng4fef97ie9l69e5erlufjc8v2i.apps.googleusercontent.com',
);

enum GoogleIdentityStatus { success, cancelled, notConfigured, unavailable }

class GoogleIdentityResult {
  const GoogleIdentityResult._(this.status, this.idToken);

  const GoogleIdentityResult.success(String idToken)
    : this._(GoogleIdentityStatus.success, idToken);
  const GoogleIdentityResult.cancelled()
    : this._(GoogleIdentityStatus.cancelled, null);
  const GoogleIdentityResult.notConfigured()
    : this._(GoogleIdentityStatus.notConfigured, null);
  const GoogleIdentityResult.unavailable()
    : this._(GoogleIdentityStatus.unavailable, null);

  final GoogleIdentityStatus status;
  final String? idToken;
}

abstract interface class GoogleIdentityProvider {
  bool get isConfigured;

  Future<GoogleIdentityResult> authenticate();

  Future<void> signOut();
}

/// Google Sign-In v7 adapter. The app sends only the ID token to SweetTime's
/// backend; device-provided email/name are never accepted as account identity.
class PluginGoogleIdentityProvider implements GoogleIdentityProvider {
  PluginGoogleIdentityProvider({String webClientId = googleWebClientId})
    : _webClientId = webClientId.trim();

  final String _webClientId;
  Future<void>? _initialization;

  @override
  bool get isConfigured => _webClientId.isNotEmpty;

  Future<void> _initialize() {
    return _initialization ??= GoogleSignIn.instance.initialize(
      serverClientId: _webClientId,
    );
  }

  @override
  Future<GoogleIdentityResult> authenticate() async {
    if (!isConfigured) return const GoogleIdentityResult.notConfigured();
    try {
      await _initialize();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return const GoogleIdentityResult.unavailable();
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken?.trim();
      if (idToken == null || idToken.isEmpty) {
        return const GoogleIdentityResult.unavailable();
      }
      return GoogleIdentityResult.success(idToken);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return const GoogleIdentityResult.cancelled();
      }
      return const GoogleIdentityResult.unavailable();
    } catch (_) {
      return const GoogleIdentityResult.unavailable();
    }
  }

  @override
  Future<void> signOut() async {
    if (!isConfigured || _initialization == null) return;
    try {
      await _initialize();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // SweetTime's own tokens are cleared independently. Provider sign-out is
      // best effort and must never keep the user logged in locally.
    }
  }
}

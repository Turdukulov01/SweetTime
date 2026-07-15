import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище токенов сессии клиента.
///
/// Абстракция, а не прямой вызов плагина: тесты подставляют in-memory фейк
/// (платформенных каналов в `flutter test` нет), а реализацию хранения можно
/// заменить, не трогая [AppStateController].
abstract interface class AuthStore {
  /// Access-токен для заголовка `Authorization: Bearer` (короткоживущий).
  Future<String?> readAccessToken();

  /// Refresh-токен: по нему получаем новую пару, когда access протух.
  Future<String?> readRefreshToken();

  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  });

  /// Полный выход: токенов на устройстве не остаётся.
  Future<void> clear();
}

/// Боевая реализация: Keystore (Android) / Keychain (iOS) через
/// `flutter_secure_storage`. Токены переживают перезапуск приложения,
/// но не переустановку — профиль при этом не теряется, он живёт на сервере.
class SecureAuthStore implements AuthStore {
  SecureAuthStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Обычные SharedPreferences на Android читаются на rooted-устройстве
            // и попадают в бэкапы, поэтому просим шифрованное хранилище.
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

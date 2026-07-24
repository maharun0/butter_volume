import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keystore-backed storage for auth material (doc §4: flutter_secure_storage).
class SecureTokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kDeviceUuid = 'device_uuid';
  static const _kDeviceId = 'device_id';
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kOfflineEntitlementToken = 'offline_entitlement_token';

  Future<String?> get deviceUuid => _storage.read(key: _kDeviceUuid);
  Future<void> setDeviceUuid(String v) =>
      _storage.write(key: _kDeviceUuid, value: v);

  Future<String?> get deviceId => _storage.read(key: _kDeviceId);
  Future<void> setDeviceId(String v) =>
      _storage.write(key: _kDeviceId, value: v);

  Future<String?> get accessToken => _storage.read(key: _kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);

  Future<void> setTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _kAccessToken, value: access);
    await _storage.write(key: _kRefreshToken, value: refresh);
  }

  /// Signed offline entitlement token — the local premium trust root
  /// (doc §11.2 / backend doc §8.4).
  Future<String?> get offlineEntitlementToken =>
      _storage.read(key: _kOfflineEntitlementToken);
  Future<void> setOfflineEntitlementToken(String v) =>
      _storage.write(key: _kOfflineEntitlementToken, value: v);

  Future<void> clearAuth() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/env.dart';
import '../di/providers.dart';
import '../error/log.dart';
import '../storage/secure_token_store.dart';

/// Backend client (backend doc §7). Design constraint: **every call may
/// fail and the app must not care** (doc §14.1 graceful degradation) — so
/// the public surface returns nullables/bools instead of throwing.
class ApiClient {
  ApiClient(this._tokens) {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _attachAuth));
  }

  final SecureTokenStore _tokens;
  late final Dio _dio;
  Future<bool>? _registration;

  Future<void> _attachAuth(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.path != '/devices/register') {
      final access = await _tokens.accessToken;
      if (access != null) options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  // ---- Device auth (backend doc §5.1) ----

  /// Random v4 UUID — deliberately app-generated, never a hardware id.
  static String generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// Idempotent registration; concurrent callers share one in-flight attempt.
  Future<bool> ensureRegistered() => _registration ??= _register()
    ..whenComplete(() => _registration = null);

  Future<bool> _register() async {
    try {
      if (await _tokens.accessToken != null) return true;
      var uuid = await _tokens.deviceUuid;
      if (uuid == null) {
        uuid = generateUuid();
        await _tokens.setDeviceUuid(uuid);
      }
      final info = await PackageInfo.fromPlatform();
      final res = await _dio.post<Map<String, dynamic>>('/devices/register',
          data: {
            'device_uuid': uuid,
            'model': Platform.operatingSystemVersion,
            'os_version': Platform.operatingSystemVersion,
            'app_version': info.version,
            'locale': Platform.localeName,
          });
      final data = res.data;
      if (data == null) return false;
      await _tokens.setDeviceId(data['device_id'] as String);
      await _tokens.setTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      return true;
    } catch (e) {
      Log.d('device registration unavailable: $e');
      return false;
    }
  }

  Future<bool> _refresh() async {
    try {
      final refresh = await _tokens.refreshToken;
      if (refresh == null) return false;
      final res = await _dio.post<Map<String, dynamic>>('/auth/refresh',
          data: {'refresh_token': refresh});
      final data = res.data;
      if (data == null) return false;
      await _tokens.setTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Authenticated call with one 401-refresh retry; null on any failure.
  Future<Map<String, dynamic>?> _call(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    bool retried = false,
  }) async {
    if (!await ensureRegistered()) return null;
    try {
      final res = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
      return res.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && !retried) {
        final refreshed = await _refresh();
        if (!refreshed) await _tokens.clearAuth();
        return _call(method, path, data: data, query: query, retried: true);
      }
      Log.d('api $path unavailable: ${e.message}');
      return null;
    } catch (e) {
      Log.d('api $path failed: $e');
      return null;
    }
  }

  // ---- Endpoints (backend doc §7) ----

  Future<Map<String, dynamic>?> verifyPurchase(
          String productId, String purchaseToken) =>
      _call('POST', '/purchases/verify', data: {
        'product_id': productId,
        'purchase_token': purchaseToken,
      });

  Future<Map<String, dynamic>?> restorePurchases(
          List<Map<String, String>> purchases) =>
      _call('POST', '/purchases/restore', data: {'purchases': purchases});

  Future<Map<String, dynamic>?> entitlementsMe() =>
      _call('GET', '/entitlements/me');

  Future<Map<String, dynamic>?> googleLogin(String idToken) =>
      _call('POST', '/auth/google', data: {'id_token': idToken});

  Future<void> logout() => _call('POST', '/auth/logout');

  Future<Map<String, dynamic>?> config() => _call('GET', '/config');

  Future<Map<String, dynamic>?> flags() => _call('GET', '/flags');

  Future<Map<String, dynamic>?> versionCheck(String current) =>
      _call('GET', '/version-check', query: {'current': current});

  Future<bool> sendAnalytics(List<Map<String, Object?>> events) async =>
      await _call('POST', '/analytics/events', data: {'events': events}) !=
      null;

  Future<bool> sendFeedback({
    required String category,
    required String message,
    Map<String, Object?>? diagnostics,
  }) async =>
      await _call('POST', '/feedback', data: {
        'category': category,
        'message': message,
        'diagnostics': ?diagnostics,
      }) !=
      null;

  Future<void> deleteAccount() => _call('DELETE', '/account');
}

final apiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(secureTokenStoreProvider)));

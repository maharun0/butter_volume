import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/providers.dart';
import '../network/api_client.dart';

/// Remote config + feature flags + version check (backend doc §7.5–7.6),
/// cached in prefs so the app never depends on the network (doc §14.1).
class RemoteConfigService {
  RemoteConfigService(this._prefs, this._api);

  static const _kConfig = 'remote.config';
  static const _kFlags = 'remote.flags';
  static const _kVersion = 'remote.version';

  final SharedPreferences _prefs;
  final ApiClient _api;

  Map<String, dynamic> _cached(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return {};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Fire-and-forget on app open.
  Future<void> refresh() async {
    final config = await _api.config();
    if (config != null) {
      await _prefs.setString(_kConfig, jsonEncode(config['config'] ?? {}));
    }
    final flags = await _api.flags();
    if (flags != null) {
      await _prefs.setString(_kFlags, jsonEncode(flags['flags'] ?? {}));
    }
    final info = await PackageInfo.fromPlatform();
    final version = await _api.versionCheck(info.version);
    if (version != null) {
      await _prefs.setString(_kVersion, jsonEncode(version));
    }
  }

  // Flags — defaults chosen so a missing backend changes nothing (§7.5).
  bool get adsEnabled => _cached(_kFlags)['ads_enabled'] as bool? ?? true;

  bool get updateRequired =>
      _cached(_kVersion)['update_required'] as bool? ?? false;

  String? get forceUpdateMessage =>
      _cached(_kVersion)['force_update_message'] as String?;

  int get freeSessionHours =>
      (_cached(_kConfig)['free_session_hours'] as num?)?.toInt() ?? 12;
}

final remoteConfigProvider = Provider<RemoteConfigService>((ref) =>
    RemoteConfigService(
        ref.watch(sharedPreferencesProvider), ref.watch(apiClientProvider)));

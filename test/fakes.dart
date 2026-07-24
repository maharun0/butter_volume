import 'package:butter_volume/core/config/constants.dart';
import 'package:butter_volume/core/platform/overlay_channel.dart';
import 'package:butter_volume/core/platform/permissions_channel.dart';
import 'package:butter_volume/core/platform/slider_channel.dart';
import 'package:butter_volume/core/platform/timer_channel.dart';
import 'package:butter_volume/core/platform/volume_channel.dart';
import 'package:butter_volume/core/storage/secure_token_store.dart';

/// In-memory fakes for the platform-channel interfaces (doc §3.2 rule:
/// channels are wrapped so they can be faked in tests).

class FakeOverlayChannel implements OverlayChannel {
  bool running = false;
  int refreshStyleCalls = 0;
  int resetPositionCalls = 0;

  @override
  Future<void> start() async => running = true;

  @override
  Future<void> stop() async => running = false;

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> refreshStyle() async => refreshStyleCalls++;

  @override
  Future<void> resetPosition() async => resetPositionCalls++;
}

class FakeSliderChannel implements SliderChannel {
  bool running = false;
  int refreshCalls = 0;

  @override
  Future<void> start() async => running = true;

  @override
  Future<void> stop() async => running = false;

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> refresh() async => refreshCalls++;
}

class FakeVolumeChannel implements VolumeChannel {
  final Map<VolumeStream, double> percents = {
    for (final s in VolumeStream.values) s: 0.5,
  };

  @override
  Future<double> getPercent(VolumeStream stream) async => percents[stream]!;

  @override
  Future<void> setPercent(VolumeStream stream, double percent) async =>
      percents[stream] = percent.clamp(0.0, 1.0);

  @override
  Future<void> toggleMute(VolumeStream stream) async =>
      percents[stream] = percents[stream] == 0 ? 0.5 : 0;
}

class FakeTimerChannel implements TimerChannel {
  final Map<AppFeature, DateTime> scheduled = {};
  final List<AppFeature> cancelled = [];

  @override
  Future<void> scheduleExpiry(AppFeature feature, DateTime at) async =>
      scheduled[feature] = at;

  @override
  Future<void> cancelExpiry(AppFeature feature) async {
    scheduled.remove(feature);
    cancelled.add(feature);
  }
}

class FakePermissionsChannel implements PermissionsChannel {
  bool overlay = true;
  bool notifications = true;
  bool batteryExempt = true;

  @override
  Future<bool> hasOverlayPermission() async => overlay;

  @override
  Future<void> requestOverlayPermission() async {}

  @override
  Future<bool> hasNotificationPermission() async => notifications;

  @override
  Future<bool> requestNotificationPermission() async => notifications;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => batteryExempt;

  @override
  Future<void> openBatteryOptimizationSettings() async {}
}

class FakeSecureTokenStore extends SecureTokenStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> get deviceUuid async => _store['device_uuid'];

  @override
  Future<void> setDeviceUuid(String v) async => _store['device_uuid'] = v;

  @override
  Future<String?> get deviceId async => _store['device_id'];

  @override
  Future<void> setDeviceId(String v) async => _store['device_id'] = v;

  @override
  Future<String?> get accessToken async => _store['access'];

  @override
  Future<String?> get refreshToken async => _store['refresh'];

  @override
  Future<void> setTokens({required String access, required String refresh}) async {
    _store['access'] = access;
    _store['refresh'] = refresh;
  }

  @override
  Future<String?> get offlineEntitlementToken async => _store['offline'];

  @override
  Future<void> setOfflineEntitlementToken(String v) async =>
      _store['offline'] = v;

  @override
  Future<void> clearAuth() async {
    _store.remove('access');
    _store.remove('refresh');
  }
}

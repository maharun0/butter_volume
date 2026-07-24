import 'package:flutter/services.dart';

import '../config/nav_signals.dart';
import 'channel_names.dart';

/// Permission state + special-access intents (doc §12).
abstract interface class PermissionsChannel {
  Future<bool> hasOverlayPermission();

  /// Launches ACTION_MANAGE_OVERLAY_PERMISSION; result re-checked on resume.
  Future<void> requestOverlayPermission();

  Future<bool> hasNotificationPermission();

  /// Runtime POST_NOTIFICATIONS prompt (API 33+; true below).
  Future<bool> requestNotificationPermission();

  Future<bool> isIgnoringBatteryOptimizations();

  /// Opens the best-known battery/autostart settings screen (doc §13.4).
  Future<void> openBatteryOptimizationSettings();
}

class MethodPermissionsChannel implements PermissionsChannel {
  static const _channel = MethodChannel(ChannelNames.permissions);

  @override
  Future<bool> hasOverlayPermission() async =>
      await _channel.invokeMethod<bool>('hasOverlay') ?? false;

  @override
  Future<void> requestOverlayPermission() {
    NavSignals.notifyExternalNav();
    return _channel.invokeMethod<void>('requestOverlay');
  }

  @override
  Future<bool> hasNotificationPermission() async =>
      await _channel.invokeMethod<bool>('hasNotifications') ?? false;

  @override
  Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotifications') ?? false;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async =>
      await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
      true;

  @override
  Future<void> openBatteryOptimizationSettings() {
    NavSignals.notifyExternalNav();
    return _channel.invokeMethod<void>('openBatterySettings');
  }
}

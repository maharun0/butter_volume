import 'package:flutter/services.dart';

import 'channel_names.dart';

/// Controls the floating-button overlay service (doc §6.2) from the main app.
abstract interface class OverlayChannel {
  Future<void> start();
  Future<void> stop();
  Future<bool> isRunning();

  /// Push the current theme/behavior JSON from prefs to a live overlay
  /// (doc §6.2.3 live customization).
  Future<void> refreshStyle();

  Future<void> resetPosition();
}

class MethodOverlayChannel implements OverlayChannel {
  static const _channel = MethodChannel(ChannelNames.overlayControl);

  @override
  Future<void> start() => _channel.invokeMethod<void>('start');

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<bool> isRunning() async =>
      await _channel.invokeMethod<bool>('isRunning') ?? false;

  @override
  Future<void> refreshStyle() => _channel.invokeMethod<void>('refreshStyle');

  @override
  Future<void> resetPosition() => _channel.invokeMethod<void>('resetPosition');
}

import 'package:flutter/services.dart';

import 'channel_names.dart';

/// Controls the notification-slider service (doc §6.3) from the main app.
abstract interface class SliderChannel {
  Future<void> start();
  Future<void> stop();
  Future<bool> isRunning();

  /// Re-render the notification after a settings change (doc §8.9).
  Future<void> refresh();
}

class MethodSliderChannel implements SliderChannel {
  static const _channel = MethodChannel(ChannelNames.sliderControl);

  @override
  Future<void> start() => _channel.invokeMethod<void>('start');

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<bool> isRunning() async =>
      await _channel.invokeMethod<bool>('isRunning') ?? false;

  @override
  Future<void> refresh() => _channel.invokeMethod<void>('refresh');
}

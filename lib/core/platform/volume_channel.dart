import 'package:flutter/services.dart';

import '../config/constants.dart';
import 'channel_names.dart';

/// Native AudioManager access (doc §4 volume-control row). Registered on both
/// engines; the overlay's hot path stays fully native — this channel is for
/// UI reads and settings-screen interactions.
abstract interface class VolumeChannel {
  /// Current volume of [stream] as 0.0–1.0.
  Future<double> getPercent(VolumeStream stream);

  Future<void> setPercent(VolumeStream stream, double percent);

  Future<void> toggleMute(VolumeStream stream);
}

class MethodVolumeChannel implements VolumeChannel {
  static const _channel = MethodChannel(ChannelNames.volume);

  @override
  Future<double> getPercent(VolumeStream stream) async =>
      await _channel.invokeMethod<double>('getPercent', {'stream': stream.id}) ??
      0.0;

  @override
  Future<void> setPercent(VolumeStream stream, double percent) =>
      _channel.invokeMethod<void>('setPercent', {
        'stream': stream.id,
        'percent': percent.clamp(0.0, 1.0),
      });

  @override
  Future<void> toggleMute(VolumeStream stream) =>
      _channel.invokeMethod<void>('toggleMute', {'stream': stream.id});
}

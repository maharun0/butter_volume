import 'package:flutter/services.dart';

import '../config/constants.dart';
import 'channel_names.dart';

/// Free-tier expiry alarms via AlarmManager (doc §6.1). Windowed inexact —
/// no SCHEDULE_EXACT_ALARM permission needed (doc §12 recommendation).
abstract interface class TimerChannel {
  Future<void> scheduleExpiry(AppFeature feature, DateTime at);
  Future<void> cancelExpiry(AppFeature feature);
}

class MethodTimerChannel implements TimerChannel {
  static const _channel = MethodChannel(ChannelNames.timers);

  @override
  Future<void> scheduleExpiry(AppFeature feature, DateTime at) =>
      _channel.invokeMethod<void>('scheduleExpiry', {
        'feature': feature.id,
        'atMs': at.millisecondsSinceEpoch,
      });

  @override
  Future<void> cancelExpiry(AppFeature feature) =>
      _channel.invokeMethod<void>('cancelExpiry', {'feature': feature.id});
}

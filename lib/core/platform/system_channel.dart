import 'package:flutter/services.dart';

import 'channel_names.dart';

/// System UI facts read natively (replaces the dynamic_color plugin).
abstract interface class SystemChannel {
  /// Material You wallpaper accent (Android 12+); null when unavailable.
  Future<Color?> systemAccentColor();
}

class MethodSystemChannel implements SystemChannel {
  static const _channel = MethodChannel(ChannelNames.system);

  @override
  Future<Color?> systemAccentColor() async {
    try {
      final argb = await _channel.invokeMethod<int>('accentColor');
      if (argb == null) return null;
      // Android sends a signed 32-bit ARGB int.
      return Color(argb & 0xFFFFFFFF);
    } catch (_) {
      return null;
    }
  }
}

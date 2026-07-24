/// Channel name constants — the Dart mirror of `channels/AppChannels.kt`.
/// Keep the two files in lockstep.
abstract final class ChannelNames {
  /// Engine A → OverlayService control (start/stop/refreshStyle/…).
  static const String overlayControl = 'bv/overlay/control';

  /// Engine B ↔ OverlayService (window expand/collapse, initial state).
  static const String overlayWindow = 'bv/overlay/window';

  /// EventChannel: OverlayService → Engine B gesture/state events.
  static const String overlayEvents = 'bv/overlay/events';

  /// Engine A → NotificationSliderService control.
  static const String sliderControl = 'bv/slider/control';

  /// AudioManager volume ops (registered on both engines).
  static const String volume = 'bv/volume';

  /// AlarmManager expiry scheduling.
  static const String timers = 'bv/timers';

  /// Permission checks and special-access intents.
  static const String permissions = 'bv/permissions';
}

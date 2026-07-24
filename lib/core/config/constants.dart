import 'env.dart';

/// Product-wide constants (doc §6.1, §11).
abstract final class AppConstants {
  /// Free-tier session length per feature (doc §6.1).
  static Duration get freeSessionDuration => Env.debugShortTimer
      ? const Duration(minutes: 2)
      : const Duration(hours: 12);

  /// "Session ending soon" reminder lead time (doc §6.1 step 2).
  static Duration get expiryWarningLead => Env.debugShortTimer
      ? const Duration(seconds: 30)
      : const Duration(minutes: 30);

  // Play Billing product IDs (doc §11.1).
  static const String monthlyProductId = 'bv_premium_monthly';
  static const String lifetimeProductId = 'bv_premium_lifetime';

  // App Open Ad frequency caps (doc §11.3).
  static const Duration adMinInterval = Duration(hours: 4);
  static const int adMaxPerDay = 2;

  /// Suppression window after an expected external navigation
  /// (permission-settings round trip, doc §11.3).
  static const Duration adExternalNavSuppression = Duration(seconds: 10);

  // Links (doc §16.3).
  static const String privacyPolicyUrl = 'https://buttervolume.app/privacy';
  static const String supportUrl = 'https://buttervolume.app/support';

  /// Analytics batching (doc §17).
  static const int analyticsBatchMax = 50;
  static const Duration analyticsFlushInterval = Duration(seconds: 30);
}

/// The two independently activatable features (doc §6.1).
enum AppFeature {
  floatingButton('floating_button'),
  notificationSlider('notification_slider');

  const AppFeature(this.id);

  /// Stable id used in prefs keys, channel calls and analytics events.
  final String id;
}

/// Volume streams the controller can address (doc §6.2, user decision:
/// media default, user-switchable).
enum VolumeStream {
  media('media'),
  ring('ring'),
  alarm('alarm'),
  notification('notification'),
  call('call');

  const VolumeStream(this.id);

  final String id;

  static VolumeStream fromId(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => VolumeStream.media);
}

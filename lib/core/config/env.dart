/// Build-time environment, injected via --dart-define / --dart-define-from-file.
///
/// Doc §15.1: flavors `dev` and `prod` differ only in these values.
abstract final class Env {
  static const String flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'dev',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.dev.buttervolume.app/v1',
  );

  /// Sentry is initialized only when a DSN is provided (doc plan: guarded
  /// integrations — no DSN, no Sentry).
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Local-testing override: treat the user as premium without billing.
  static const bool debugPremium = bool.fromEnvironment('DEBUG_PREMIUM');

  /// Local-testing override: free-tier sessions expire after 2 minutes
  /// instead of 12 hours so the expiry loop can be exercised quickly.
  static const bool debugShortTimer = bool.fromEnvironment('DEBUG_SHORT_TIMER');

  static const bool isProd = flavor == 'prod';
}

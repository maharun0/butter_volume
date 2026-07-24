import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

/// Typed facade over SharedPreferences (doc §4: settings are flat key-values).
///
/// IMPORTANT: uses the legacy `SharedPreferences` API on purpose — it writes
/// the `FlutterSharedPreferences` file that the Kotlin services read directly
/// (keys prefixed `flutter.` on the native side; see `Prefs.kt`).
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  // ---- Keys (Kotlin mirror in Prefs.kt adds the `flutter.` prefix) ----
  static const _kOnboardingDone = 'onboarding.done';
  static const _kThemeMode = 'app.theme_mode';
  static const _kDynamicColor = 'app.dynamic_color';
  static const _kAccentSeed = 'app.accent_seed';
  static const _kAnimationSpeed = 'app.animation_speed';
  static const _kAnalyticsEnabled = 'app.analytics_enabled';
  static const _kAutostart = 'settings.autostart';
  static const _kOverlayTheme = 'overlay.theme';
  static const _kActiveThemeId = 'overlay.active_theme_id';
  static const _kOverlayBehavior = 'overlay.behavior';
  static const _kSliderConfig = 'slider.config';
  static const _kIsPremium = 'entitlement.is_premium';
  static const _kEntitlementStatus = 'entitlement.status';
  static const _kAuthEmail = 'auth.email';
  static const _kAdLastShown = 'ads.last_shown_ms';
  static const _kAdDay = 'ads.day';
  static const _kAdShownToday = 'ads.shown_today';

  static String _enabledKey(AppFeature f) => 'feature.${f.id}.enabled';
  static String _expiryKey(AppFeature f) => 'expiry.${f.id}';

  // ---- Onboarding ----
  bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;
  Future<void> setOnboardingDone() => _prefs.setBool(_kOnboardingDone, true);

  // ---- Appearance ----
  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  bool get dynamicColor => _prefs.getBool(_kDynamicColor) ?? true;
  Future<void> setDynamicColor(bool v) => _prefs.setBool(_kDynamicColor, v);

  int? get accentSeed => _prefs.getInt(_kAccentSeed);
  Future<void> setAccentSeed(int argb) => _prefs.setInt(_kAccentSeed, argb);

  double get animationSpeed => _prefs.getDouble(_kAnimationSpeed) ?? 1.0;
  Future<void> setAnimationSpeed(double v) =>
      _prefs.setDouble(_kAnimationSpeed, v);

  bool get analyticsEnabled => _prefs.getBool(_kAnalyticsEnabled) ?? true;
  Future<void> setAnalyticsEnabled(bool v) =>
      _prefs.setBool(_kAnalyticsEnabled, v);

  // ---- Features (doc §6.1) ----
  bool isFeatureEnabled(AppFeature f) =>
      _prefs.getBool(_enabledKey(f)) ?? false;
  Future<void> setFeatureEnabled(AppFeature f, bool v) =>
      _prefs.setBool(_enabledKey(f), v);

  /// Epoch millis when the free-tier session for [f] expires; null when no
  /// session is running (premium or feature off).
  DateTime? featureExpiry(AppFeature f) {
    final ms = _prefs.getInt(_expiryKey(f)) ?? 0;
    return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setFeatureExpiry(AppFeature f, DateTime? at) =>
      _prefs.setInt(_expiryKey(f), at?.millisecondsSinceEpoch ?? 0);

  // ---- Overlay style/behavior (raw JSON; parsed by feature repositories,
  //      read natively by the overlay service) ----
  String? get overlayThemeJson => _prefs.getString(_kOverlayTheme);
  Future<void> setOverlayThemeJson(String json) =>
      _prefs.setString(_kOverlayTheme, json);

  /// Which theme the current style derives from (gallery highlight).
  String? get activeThemeId => _prefs.getString(_kActiveThemeId);
  Future<void> setActiveThemeId(String id) =>
      _prefs.setString(_kActiveThemeId, id);

  String? get overlayBehaviorJson => _prefs.getString(_kOverlayBehavior);
  Future<void> setOverlayBehaviorJson(String json) =>
      _prefs.setString(_kOverlayBehavior, json);

  String? get sliderConfigJson => _prefs.getString(_kSliderConfig);
  Future<void> setSliderConfigJson(String json) =>
      _prefs.setString(_kSliderConfig, json);

  // ---- Entitlement cache (advisory only; the trust root is the signed
  //      offline token, doc §11.2. Kotlin BootReceiver reads is_premium.) ----
  bool get isPremiumCached => _prefs.getBool(_kIsPremium) ?? false;
  String get entitlementStatusCached =>
      _prefs.getString(_kEntitlementStatus) ?? 'free';
  Future<void> cacheEntitlement({
    required bool isPremium,
    required String status,
  }) async {
    await _prefs.setBool(_kIsPremium, isPremium);
    await _prefs.setString(_kEntitlementStatus, status);
  }

  // ---- Account ----
  String? get authEmail => _prefs.getString(_kAuthEmail);
  Future<void> setAuthEmail(String? email) => email == null
      ? _prefs.remove(_kAuthEmail)
      : _prefs.setString(_kAuthEmail, email);

  // ---- General ----
  bool get autostart => _prefs.getBool(_kAutostart) ?? false;
  Future<void> setAutostart(bool v) => _prefs.setBool(_kAutostart, v);

  // ---- Ad frequency capping state (doc §11.3) ----
  DateTime? get adLastShown {
    final ms = _prefs.getInt(_kAdLastShown) ?? 0;
    return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  int adShownOn(String day) =>
      (_prefs.getString(_kAdDay) == day) ? (_prefs.getInt(_kAdShownToday) ?? 0) : 0;

  Future<void> recordAdShown(DateTime now, String day) async {
    await _prefs.setInt(_kAdLastShown, now.millisecondsSinceEpoch);
    final count = adShownOn(day);
    await _prefs.setString(_kAdDay, day);
    await _prefs.setInt(_kAdShownToday, count + 1);
  }

  /// Reset all settings (doc §10 General). Themes are kept — they live in the
  /// theme store, not prefs.
  Future<void> resetAll() async {
    for (final key in _prefs.getKeys()) {
      await _prefs.remove(key);
    }
  }
}

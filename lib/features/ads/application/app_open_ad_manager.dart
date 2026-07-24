import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/constants.dart';
import '../../../core/config/env.dart';
import '../../../core/config/nav_signals.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/log.dart';
import '../../subscription/application/entitlement_controller.dart';

/// App Open Ads with strict caps (doc §11.3):
///  - never on first-ever launch, never for premium/grace users;
///  - ≥ 4 h between ads, ≤ 2/day;
///  - suppressed within 10 s of an expected external nav (permission flows);
///  - the ad SDK is not even initialized for premium users;
///  - remote kill switch `ads_enabled`.
class AppOpenAdManager {
  AppOpenAdManager(this._ref);

  final Ref _ref;
  bool _sdkInitialized = false;
  bool _showing = false;

  // Google sample App Open ad unit. TODO(deploy): real unit via env config.
  static const _adUnitId = 'ca-app-pub-3940256099942544/9257395921';

  Future<void> maybeShowOnAppOpen() async {
    if (_showing) return;
    if (_ref.read(isPremiumProvider)) return;
    if (!_ref.read(remoteConfigProvider).adsEnabled) return;

    final settings = _ref.read(settingsRepositoryProvider);
    if (!settings.onboardingDone) return; // never the first-ever launch

    final now = DateTime.now();
    final nav = NavSignals.lastExternalNav;
    if (nav != null &&
        now.difference(nav) < AppConstants.adExternalNavSuppression) {
      return;
    }
    final last = settings.adLastShown;
    if (last != null && now.difference(last) < AppConstants.adMinInterval) {
      return;
    }
    final day = '${now.year}-${now.month}-${now.day}';
    if (settings.adShownOn(day) >= AppConstants.adMaxPerDay) return;

    try {
      if (!_sdkInitialized) {
        await MobileAds.instance.initialize();
        _sdkInitialized = true;
      }
      final loadStart = DateTime.now();
      await AppOpenAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _showing = true;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                _showing = false;
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (ad, _) {
                _showing = false;
                ad.dispose();
              },
            );
            ad.show();
            settings.recordAdShown(DateTime.now(), day);
            _ref.read(analyticsProvider).track('ad_shown', {
              'latency_ms':
                  DateTime.now().difference(loadStart).inMilliseconds,
            });
          },
          onAdFailedToLoad: (error) {
            _ref
                .read(analyticsProvider)
                .track('ad_failed', {'error': error.code.toString()});
            if (!Env.isProd) Log.d('app open ad failed: $error');
          },
        ),
      );
    } catch (e) {
      Log.d('ads unavailable: $e');
    }
  }
}

final appOpenAdManagerProvider =
    Provider<AppOpenAdManager>(AppOpenAdManager.new);

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/analytics/analytics_service.dart';
import 'core/config/remote_config_service.dart';
import 'core/di/providers.dart';
import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/motion.dart';
import 'features/ads/application/app_open_ad_manager.dart';
import 'features/settings/application/appearance_controller.dart';
import 'features/subscription/application/entitlement_controller.dart';

class ButterVolumeApp extends ConsumerStatefulWidget {
  const ButterVolumeApp({super.key});

  @override
  ConsumerState<ButterVolumeApp> createState() => _ButterVolumeAppState();
}

class _ButterVolumeAppState extends ConsumerState<ButterVolumeApp>
    with WidgetsBindingObserver {
  DateTime sessionStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  void _bootstrap() {
    // Analytics → backend transport (doc §17); silent when offline.
    final api = ref.read(apiClientProvider);
    ref.read(analyticsProvider).sender =
        (batch) => api.sendAnalytics([for (final e in batch) e.toJson()]);

    final entitlement = ref.read(entitlementProvider);
    ref.read(analyticsProvider).track('app_open', {
      'source': 'icon',
      'entitlement': entitlement.id,
    });

    // Fire-and-forget: remote config + app-open ad (both no-ops offline /
    // premium, doc §11.3).
    unawaited(ref.read(remoteConfigProvider).refresh());
    unawaited(ref.read(appOpenAdManagerProvider).maybeShowOnAppOpen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        sessionStart = DateTime.now();
        unawaited(ref.read(appOpenAdManagerProvider).maybeShowOnAppOpen());
        unawaited(ref.read(entitlementProvider.notifier).refreshFromServer());
      case AppLifecycleState.paused:
        ref.read(analyticsProvider).track('session_end', {
          'duration_s': DateTime.now().difference(sessionStart).inSeconds,
        });
        unawaited(ref.read(analyticsProvider).flush());
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final router = ref.watch(appRouterProvider);

    // Dynamic color applies to the app UI only — never the floating button,
    // whose theme is user-authoritative (doc §2.5). The wallpaper accent is
    // read natively over `bv/system` (no plugin) and seeds both schemes.
    final systemAccent = ref.watch(systemAccentProvider).value;
    final seed = appearance.dynamicColor && systemAccent != null
        ? systemAccent
        : appearance.accentSeed;

    return MaterialApp.router(
      title: 'Butter Volume',
      debugShowCheckedModeBanner: false,
      themeMode: appearance.themeMode,
      theme: AppTheme.light(seed),
      darkTheme: AppTheme.dark(seed),
      themeAnimationDuration: Motion.themeCrossFade,
      themeAnimationCurve: Motion.settle,
      routerConfig: router,
    );
  }
}

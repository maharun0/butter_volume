import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/log.dart';
import '../../subscription/application/entitlement_controller.dart';

enum ActivationResult {
  started,
  stopped,
  needsOverlayPermission,
  needsNotificationPermission,
  failed,
}

@immutable
class FeatureState {
  const FeatureState({
    required this.enabled,
    required this.running,
    this.expiry,
    this.killDetected = false,
  });

  final bool enabled;
  final bool running;

  /// Free-tier session end; null for premium or when off (doc §6.1).
  final DateTime? expiry;

  /// Enabled + session valid but the service is dead ⇒ the OEM killed us
  /// (doc §13.4 detection).
  final bool killDetected;

  Duration? remaining(DateTime now) => expiry?.difference(now);
}

@immutable
class FeaturesState {
  const FeaturesState({required this.byFeature});

  final Map<AppFeature, FeatureState> byFeature;

  FeatureState of(AppFeature f) =>
      byFeature[f] ?? const FeatureState(enabled: false, running: false);
}

/// Activation lifecycle for both features (doc §6.1 activation flow).
class FeaturesController extends Notifier<FeaturesState> {
  @override
  FeaturesState build() {
    final settings = ref.watch(settingsRepositoryProvider);
    final state = FeaturesState(byFeature: {
      for (final f in AppFeature.values)
        f: FeatureState(
          enabled: settings.isFeatureEnabled(f),
          running: false,
          expiry: settings.featureExpiry(f),
        ),
    });
    // Reconcile with reality asynchronously (services may be up already).
    unawaited(Future<void>.microtask(refresh));
    return state;
  }

  Future<ActivationResult> toggle(AppFeature feature) async {
    final current = state.of(feature);
    return current.enabled ? deactivate(feature) : activate(feature);
  }

  Future<ActivationResult> activate(AppFeature feature) async {
    final permissions = ref.read(permissionsChannelProvider);
    final settings = ref.read(settingsRepositoryProvider);
    final isPremium = ref.read(isPremiumProvider);

    try {
      // Permission gates (doc §6.1 table).
      if (feature == AppFeature.floatingButton &&
          !await permissions.hasOverlayPermission()) {
        return ActivationResult.needsOverlayPermission;
      }
      if (feature == AppFeature.notificationSlider &&
          !await permissions.hasNotificationPermission()) {
        final granted = await permissions.requestNotificationPermission();
        if (!granted) return ActivationResult.needsNotificationPermission;
      }

      // Start the service.
      switch (feature) {
        case AppFeature.floatingButton:
          await ref.read(overlayChannelProvider).start();
        case AppFeature.notificationSlider:
          await ref.read(sliderChannelProvider).start();
      }

      await settings.setFeatureEnabled(feature, true);

      // Free tier: independent 12 h timer per feature (doc §6.1).
      DateTime? expiry;
      if (!isPremium) {
        expiry = DateTime.now().add(AppConstants.freeSessionDuration);
        await settings.setFeatureExpiry(feature, expiry);
        await ref.read(timerChannelProvider).scheduleExpiry(feature, expiry);
      } else {
        await settings.setFeatureExpiry(feature, null);
      }

      _update(feature,
          FeatureState(enabled: true, running: true, expiry: expiry));
      ref
          .read(analyticsProvider)
          .track('feature_activated', {
        'feature': feature.id,
        'entitlement': isPremium ? 'premium' : 'free',
      });
      return ActivationResult.started;
    } catch (e, st) {
      Log.e('activate ${feature.id} failed', error: e, stackTrace: st);
      return ActivationResult.failed;
    }
  }

  Future<ActivationResult> deactivate(AppFeature feature) async {
    final settings = ref.read(settingsRepositoryProvider);
    try {
      switch (feature) {
        case AppFeature.floatingButton:
          await ref.read(overlayChannelProvider).stop();
        case AppFeature.notificationSlider:
          await ref.read(sliderChannelProvider).stop();
      }
      await ref.read(timerChannelProvider).cancelExpiry(feature);
      await settings.setFeatureEnabled(feature, false);
      await settings.setFeatureExpiry(feature, null);
      _update(feature, const FeatureState(enabled: false, running: false));
      ref
          .read(analyticsProvider)
          .track('feature_deactivated', {'feature': feature.id, 'reason': 'user'});
      return ActivationResult.stopped;
    } catch (e, st) {
      Log.e('deactivate ${feature.id} failed', error: e, stackTrace: st);
      return ActivationResult.failed;
    }
  }

  /// Reconcile UI state with services + prefs — called on build and on app
  /// resume (timers fire while the app is closed; OEMs kill services,
  /// doc §13.4).
  Future<void> refresh() async {
    final settings = ref.read(settingsRepositoryProvider);
    final isPremium = ref.read(isPremiumProvider);
    final now = DateTime.now();

    for (final feature in AppFeature.values) {
      final enabled = settings.isFeatureEnabled(feature);
      final expiry = settings.featureExpiry(feature);
      bool running;
      try {
        running = switch (feature) {
          AppFeature.floatingButton =>
            await ref.read(overlayChannelProvider).isRunning(),
          AppFeature.notificationSlider =>
            await ref.read(sliderChannelProvider).isRunning(),
        };
      } catch (_) {
        running = false;
      }
      if (!ref.mounted) return;

      final sessionValid =
          isPremium || (expiry != null && expiry.isAfter(now));
      final killDetected = enabled && !running && sessionValid;
      if (killDetected) {
        ref.read(analyticsProvider).track('feature_deactivated',
            {'feature': feature.id, 'reason': 'oem_kill_detected'});
      }

      _update(
        feature,
        FeatureState(
          enabled: enabled && (running || killDetected),
          running: running,
          expiry: sessionValid ? expiry : null,
          killDetected: killDetected,
        ),
      );
    }
  }

  void _update(AppFeature feature, FeatureState fs) {
    if (!ref.mounted) return;
    state = FeaturesState(byFeature: {...state.byFeature, feature: fs});
  }
}

final featuresProvider =
    NotifierProvider<FeaturesController, FeaturesState>(FeaturesController.new);

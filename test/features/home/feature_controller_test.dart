import 'package:butter_volume/core/config/constants.dart';
import 'package:butter_volume/core/di/providers.dart';
import 'package:butter_volume/features/home/application/feature_controller.dart';
import 'package:butter_volume/features/subscription/application/entitlement_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeOverlayChannel overlay;
  late FakeSliderChannel slider;
  late FakeTimerChannel timers;
  late FakePermissionsChannel permissions;

  Future<ProviderContainer> makeContainer({bool premium = false}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    overlay = FakeOverlayChannel();
    slider = FakeSliderChannel();
    timers = FakeTimerChannel();
    permissions = FakePermissionsChannel();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      overlayChannelProvider.overrideWithValue(overlay),
      sliderChannelProvider.overrideWithValue(slider),
      timerChannelProvider.overrideWithValue(timers),
      permissionsChannelProvider.overrideWithValue(permissions),
      secureTokenStoreProvider.overrideWithValue(FakeSecureTokenStore()),
      isPremiumProvider.overrideWithValue(premium),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('activation (doc §6.1)', () {
    test('free activation starts service and schedules a ~12 h expiry',
        () async {
      final container = await makeContainer();
      final controller = container.read(featuresProvider.notifier);

      final result = await controller.activate(AppFeature.floatingButton);

      expect(result, ActivationResult.started);
      expect(overlay.running, isTrue);
      final expiry = timers.scheduled[AppFeature.floatingButton];
      expect(expiry, isNotNull);
      final remaining = expiry!.difference(DateTime.now());
      expect(remaining.inMinutes,
          closeTo(AppConstants.freeSessionDuration.inMinutes, 2));
      expect(
        container
            .read(settingsRepositoryProvider)
            .isFeatureEnabled(AppFeature.floatingButton),
        isTrue,
      );
    });

    test('premium activation schedules no timer', () async {
      final container = await makeContainer(premium: true);
      final controller = container.read(featuresProvider.notifier);

      await controller.activate(AppFeature.floatingButton);

      expect(overlay.running, isTrue);
      expect(timers.scheduled, isEmpty);
      expect(
        container.read(featuresProvider).of(AppFeature.floatingButton).expiry,
        isNull,
      );
    });

    test('overlay permission gate blocks feature 1', () async {
      final container = await makeContainer();
      permissions.overlay = false;

      final result = await container
          .read(featuresProvider.notifier)
          .activate(AppFeature.floatingButton);

      expect(result, ActivationResult.needsOverlayPermission);
      expect(overlay.running, isFalse);
    });

    test('features are independent (doc §6.1)', () async {
      final container = await makeContainer();
      final controller = container.read(featuresProvider.notifier);

      await controller.activate(AppFeature.floatingButton);
      await controller.activate(AppFeature.notificationSlider);
      await controller.deactivate(AppFeature.floatingButton);

      expect(overlay.running, isFalse);
      expect(slider.running, isTrue);
      expect(timers.scheduled.containsKey(AppFeature.notificationSlider),
          isTrue);
      expect(
          timers.scheduled.containsKey(AppFeature.floatingButton), isFalse);
    });

    test('deactivation cancels the timer and clears prefs', () async {
      final container = await makeContainer();
      final controller = container.read(featuresProvider.notifier);

      await controller.activate(AppFeature.notificationSlider);
      final result =
          await controller.deactivate(AppFeature.notificationSlider);

      expect(result, ActivationResult.stopped);
      expect(slider.running, isFalse);
      expect(timers.cancelled, contains(AppFeature.notificationSlider));
      final settings = container.read(settingsRepositoryProvider);
      expect(
          settings.isFeatureEnabled(AppFeature.notificationSlider), isFalse);
      expect(settings.featureExpiry(AppFeature.notificationSlider), isNull);
    });
  });

  group('refresh / OEM-kill detection (doc §13.4)', () {
    test('enabled + session valid + dead service ⇒ killDetected', () async {
      final container = await makeContainer();
      final controller = container.read(featuresProvider.notifier);
      await controller.activate(AppFeature.floatingButton);

      overlay.running = false; // simulate the OEM killing the service
      await controller.refresh();

      final state =
          container.read(featuresProvider).of(AppFeature.floatingButton);
      expect(state.killDetected, isTrue);
    });

    test('expired session on refresh clears expiry', () async {
      final container = await makeContainer();
      final settings = container.read(settingsRepositoryProvider);
      await settings.setFeatureEnabled(AppFeature.floatingButton, true);
      await settings.setFeatureExpiry(AppFeature.floatingButton,
          DateTime.now().subtract(const Duration(minutes: 5)));

      await container.read(featuresProvider.notifier).refresh();

      final state =
          container.read(featuresProvider).of(AppFeature.floatingButton);
      expect(state.expiry, isNull);
      expect(state.killDetected, isFalse);
    });
  });
}

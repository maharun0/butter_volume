import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/overlay_channel.dart';
import '../platform/permissions_channel.dart';
import '../platform/slider_channel.dart';
import '../platform/timer_channel.dart';
import '../platform/volume_channel.dart';
import '../storage/secure_token_store.dart';
import '../storage/settings_repository.dart';

/// Overridden in main() with the real instance before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Overridden at boot'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final secureTokenStoreProvider = Provider<SecureTokenStore>(
  (_) => SecureTokenStore(),
);

// Platform channels — abstract interfaces so tests override with fakes
// (doc §3.2 rules).
final overlayChannelProvider =
    Provider<OverlayChannel>((_) => MethodOverlayChannel());

final sliderChannelProvider =
    Provider<SliderChannel>((_) => MethodSliderChannel());

final volumeChannelProvider =
    Provider<VolumeChannel>((_) => MethodVolumeChannel());

final timerChannelProvider = Provider<TimerChannel>((_) => MethodTimerChannel());

final permissionsChannelProvider =
    Provider<PermissionsChannel>((_) => MethodPermissionsChannel());

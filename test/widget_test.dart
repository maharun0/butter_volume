import 'package:butter_volume/core/di/providers.dart';
import 'package:butter_volume/features/home/presentation/home_screen.dart';
import 'package:butter_volume/features/subscription/application/entitlement_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  testWidgets('Home renders both feature cards (doc §8.5)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          overlayChannelProvider.overrideWithValue(FakeOverlayChannel()),
          sliderChannelProvider.overrideWithValue(FakeSliderChannel()),
          timerChannelProvider.overrideWithValue(FakeTimerChannel()),
          permissionsChannelProvider.overrideWithValue(FakePermissionsChannel()),
          volumeChannelProvider.overrideWithValue(FakeVolumeChannel()),
          secureTokenStoreProvider.overrideWithValue(FakeSecureTokenStore()),
          isPremiumProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Floating button'), findsOneWidget);
    expect(find.text('Notification slider'), findsOneWidget);
    // Free user sees the premium banner (doc §8.5).
    expect(find.textContaining('lifetime'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
  });
}

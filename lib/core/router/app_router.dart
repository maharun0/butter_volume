import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/floating_button/presentation/floating_button_settings_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notification_slider/presentation/notification_slider_settings_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/permission_setup_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/settings/presentation/feedback_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import '../../features/themes/presentation/theme_editor_screen.dart';
import '../../features/themes/presentation/theme_gallery_screen.dart';

/// Route table (doc §8.1). Deep links: expiry notification opens
/// `/home?reactivate=<feature>`.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
          path: '/permissions',
          builder: (_, _) => const PermissionSetupScreen()),
      GoRoute(
        path: '/home',
        builder: (_, state) => HomeScreen(
          reactivateFeature: state.uri.queryParameters['reactivate'],
        ),
      ),
      GoRoute(
          path: '/floating-button',
          builder: (_, _) => const FloatingButtonSettingsScreen()),
      GoRoute(path: '/themes', builder: (_, _) => const ThemeGalleryScreen()),
      GoRoute(
        path: '/themes/edit/:id',
        builder: (_, state) =>
            ThemeEditorScreen(themeId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: '/notification-slider',
          builder: (_, _) => const NotificationSliderSettingsScreen()),
      GoRoute(
        path: '/subscription',
        builder: (_, state) => SubscriptionScreen(
          source: state.uri.queryParameters['source'] ?? 'unknown',
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      GoRoute(path: '/feedback', builder: (_, _) => const FeedbackScreen()),
    ],
  );
});

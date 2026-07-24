import 'package:flutter/material.dart';

/// Brand palette (doc §2.5). App-UI theming only — the floating button is
/// themed exclusively by the button-theme system (doc §7) and never follows
/// dynamic color.
abstract final class BrandColors {
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDark = Color(0xFF818CF8);
  static const Color accent = Color(0xFFFFB020);
  static const Color accentDark = Color(0xFFFFC94D);
  static const Color surfaceLight = Color(0xFFFAFAFC);
  static const Color surfaceDark = Color(0xFF0F1115);
  static const Color success = Color(0xFF12B76A);
  static const Color successDark = Color(0xFF32D583);
}

/// Accent seeds offered when dynamic color is off (doc §10 Appearance).
const List<Color> kAccentSeeds = [
  BrandColors.primary,
  Color(0xFF1E88E5), // ocean
  Color(0xFF2E7D32), // forest
  Color(0xFFD32F2F), // red
  Color(0xFFF4511E), // sunset
  Color(0xFF7C4DFF), // purple
  Color(0xFF00897B), // teal
  Color(0xFF546E7A), // slate
];

abstract final class AppTheme {
  static ThemeData light(Color seed) =>
      _base(ColorScheme.fromSeed(seedColor: seed));

  static ThemeData dark(Color seed) => _base(
      ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark));

  static ThemeData _base(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? BrandColors.surfaceDark : BrandColors.surfaceLight,
      // Headings use the brand font (Manrope, bundled later); body stays on
      // the platform default for native feel (doc §2.4).
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor:
            isDark ? BrandColors.surfaceDark : BrandColors.surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

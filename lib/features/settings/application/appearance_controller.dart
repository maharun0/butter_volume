import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';

/// Appearance settings state (doc §10 Appearance).
@immutable
class AppearanceState {
  const AppearanceState({
    required this.themeMode,
    required this.dynamicColor,
    required this.accentSeed,
    required this.animationSpeed,
  });

  final ThemeMode themeMode;
  final bool dynamicColor;
  final Color accentSeed;
  final double animationSpeed;

  AppearanceState copyWith({
    ThemeMode? themeMode,
    bool? dynamicColor,
    Color? accentSeed,
    double? animationSpeed,
  }) =>
      AppearanceState(
        themeMode: themeMode ?? this.themeMode,
        dynamicColor: dynamicColor ?? this.dynamicColor,
        accentSeed: accentSeed ?? this.accentSeed,
        animationSpeed: animationSpeed ?? this.animationSpeed,
      );
}

class AppearanceController extends Notifier<AppearanceState> {
  @override
  AppearanceState build() {
    final settings = ref.watch(settingsRepositoryProvider);
    return AppearanceState(
      themeMode: switch (settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      dynamicColor: settings.dynamicColor,
      accentSeed: settings.accentSeed != null
          ? Color(settings.accentSeed!)
          : BrandColors.primary,
      animationSpeed: settings.animationSpeed,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(settingsRepositoryProvider).setThemeMode(switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        });
  }

  Future<void> setDynamicColor(bool enabled) async {
    state = state.copyWith(dynamicColor: enabled);
    await ref.read(settingsRepositoryProvider).setDynamicColor(enabled);
  }

  Future<void> setAccentSeed(Color seed) async {
    state = state.copyWith(accentSeed: seed);
    await ref.read(settingsRepositoryProvider).setAccentSeed(seed.toARGB32());
  }

  Future<void> setAnimationSpeed(double speed) async {
    state = state.copyWith(animationSpeed: speed);
    await ref.read(settingsRepositoryProvider).setAnimationSpeed(speed);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
        AppearanceController.new);

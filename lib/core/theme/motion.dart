import 'package:flutter/widgets.dart';

/// Central motion spec (doc §9). All durations are multiplied by the user's
/// animation-speed setting via [scaled]; accessibility "remove animations"
/// forces everything to zero.
abstract final class Motion {
  // Overlay
  static const Duration morphExpand = Duration(milliseconds: 240);
  static const Duration morphCollapse = Duration(milliseconds: 200);
  static const Duration snapToEdge = Duration(milliseconds: 250);
  static const Duration peekShrink = Duration(milliseconds: 300);
  static const Duration arcStep = Duration(milliseconds: 90);
  static const Duration percentBadgeFade = Duration(milliseconds: 800);

  // App
  static const Duration screenTransition = Duration(milliseconds: 300);
  static const Duration heroFlight = Duration(milliseconds: 350);
  static const Duration gridStaggerStep = Duration(milliseconds: 40);
  static const Duration themeCrossFade = Duration(milliseconds: 250);
  static const Duration checkOff = Duration(milliseconds: 200);
  static const Duration liveTweak = Duration(milliseconds: 150);
  static const Duration overlayThemeLerp = Duration(milliseconds: 300);

  // Premium unlock (doc §8.10)
  static const Duration unlockArc = Duration(milliseconds: 500);
  static const Duration unlockConfetti = Duration(milliseconds: 300);
  static const Duration unlockCascadeStep = Duration(milliseconds: 60);

  // Splash
  static const Duration splashArc = Duration(milliseconds: 600);

  // Curves
  static const Curve emphasized = Curves.fastOutSlowIn;
  static const Curve exit = Curves.easeOutCubic;
  static const Curve collapse = Curves.easeOutBack;
  static const Curve settle = Curves.easeInOut;

  /// Scales [base] by the user's animation-speed setting (0.5×–1.5×,
  /// doc §10) and honors the OS "remove animations" accessibility setting.
  static Duration scaled(BuildContext context, Duration base, double speed) {
    if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
    final s = speed.clamp(0.5, 1.5);
    return Duration(microseconds: (base.inMicroseconds / s).round());
  }
}

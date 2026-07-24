import 'package:flutter/material.dart';

import 'floating_button_view.dart';
import 'overlay_state.dart';
import 'radial_controller_view.dart';

/// Root of the overlay engine's UI (doc §6.2). The native window sizes are
/// dp == logical px, so painting coordinates line up 1:1 with the geometry
/// the service reports.
class OverlayApp extends StatefulWidget {
  const OverlayApp({super.key});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp>
    with TickerProviderStateMixin {
  late final OverlayUiController controller;
  late final AnimationController morph;
  late final AnimationController tapPulse;
  RadialPhase _lastPhase = RadialPhase.idle;
  int _lastTap = 0;

  @override
  void initState() {
    super.initState();
    controller = OverlayUiController();
    morph = AnimationController(vsync: this);
    tapPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    controller.addListener(_onStateChanged);
    morph.addStatusListener(_onMorphStatus);
  }

  void _onStateChanged() {
    final spec = morphSpecFor(controller.theme.animationStyle);
    final speed = controller.behavior.animationSpeed.clamp(0.5, 1.5);

    if (controller.phase != _lastPhase) {
      _lastPhase = controller.phase;
      switch (controller.phase) {
        case RadialPhase.expanding:
          morph.duration = spec.expand * (1 / speed);
          morph.forward();
        case RadialPhase.collapsing:
          morph.duration = spec.collapse * (1 / speed);
          morph.reverse();
        case RadialPhase.idle:
          if (morph.value != 0 && !morph.isAnimating) morph.value = 0;
        case RadialPhase.active:
          break;
      }
    }

    if (controller.tapPulse != _lastTap) {
      _lastTap = controller.tapPulse;
      tapPulse.forward(from: 0);
    }
    setState(() {});
  }

  void _onMorphStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        controller.phase == RadialPhase.collapsing) {
      controller.onCollapseAnimationDone();
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onStateChanged);
    morph.dispose();
    tapPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery.fromView(
        view: View.of(context),
        child: AnimatedBuilder(
          animation: Listenable.merge([morph, tapPulse]),
          builder: (context, _) {
            final theme = controller.theme;
            final expanded = controller.phase != RadialPhase.idle;
            final spec = morphSpecFor(theme.animationStyle);
            final curve = controller.phase == RadialPhase.collapsing
                ? spec.collapseCurve
                : spec.expandCurve;
            final t = curve.transform(morph.value);

            if (expanded) {
              return CustomPaint(
                size: Size.infinite,
                painter: RadialControllerPainter(
                  theme: theme,
                  morphT: t,
                  percent: controller.volumePercent,
                  center: controller.ringCenter,
                  streamId: controller.activeStream,
                  showStreamChip: controller.phase == RadialPhase.active,
                ),
              );
            }

            // Idle: the window is button-sized; render the button centered
            // with the tap micro-pulse (doc §6.2.1) and post-release badge.
            // Triangle pulse: 1.0 → 0.95 → 1.0 across the controller run.
            final scale =
                1.0 - 0.05 * (1 - (2 * tapPulse.value - 1).abs());
            return Center(
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FloatingButtonView(theme: theme),
                    AnimatedOpacity(
                      opacity: controller.showBadge ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(controller.volumePercent * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

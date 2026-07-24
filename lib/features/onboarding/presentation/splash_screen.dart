import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';

/// Brand moment + async boot (doc §8.2). Logo arc sweeps 0→270° while the
/// route decision is made; target < 1.2 s on screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController intro;

  @override
  void initState() {
    super.initState();
    intro = AnimationController(vsync: this, duration: Motion.splashArc)
      ..forward();
    Future<void>.delayed(const Duration(milliseconds: 900), _route);
  }

  void _route() {
    if (!mounted) return;
    final settings = ref.read(settingsRepositoryProvider);
    context.go(settings.onboardingDone ? '/home' : '/onboarding');
  }

  @override
  void dispose() {
    intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: intro,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(intro.value);
            return Transform.scale(
              scale: 0.9 + 0.1 * t,
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(120),
                      painter: _ArcPainter(
                        sweep: t * 1.5 * math.pi,
                        color: BrandColors.accent,
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volume_up_rounded,
                          color: Colors.white, size: 36),
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

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.sweep, required this.color});

  final double sweep;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
      -math.pi / 2,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.sweep != sweep || old.color != color;
}

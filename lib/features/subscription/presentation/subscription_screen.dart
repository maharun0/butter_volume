import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/constants.dart';
import '../../../core/theme/motion.dart';
import '../../themes/domain/presets.dart';
import '../../themes/presentation/widgets/theme_preview.dart';
import '../application/billing_controller.dart';
import '../application/entitlement_controller.dart';

/// The paywall (doc §8.10): convert with clarity, not pressure. Lifetime is
/// the pre-selected anchor (doc §11.1).
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key, required this.source});

  /// Attribution (doc §17 `paywall_viewed.source`).
  final String source;

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String selected = AppConstants.lifetimeProductId;
  int heroTheme = 5; // start on a premium theme
  Timer? heroCycler;
  bool showUnlock = false;

  static const _premiumThemeIndexes = [5, 8, 9]; // sunset, neon, cyber

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).track('paywall_viewed', {
      'source': widget.source,
    });
    // Hero cycles premium themes with the real morph painter (doc §8.10).
    var i = 0;
    heroCycler = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) {
        i = (i + 1) % _premiumThemeIndexes.length;
        setState(() => heroTheme = _premiumThemeIndexes[i]);
      }
    });
  }

  @override
  void dispose() {
    heroCycler?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingProvider);
    final isPremium = ref.watch(isPremiumProvider);

    // Premium unlock animation, then pop back to origin (doc §8.10).
    ref.listen(billingProvider, (prev, next) {
      if (next.justUnlocked && !(prev?.justUnlocked ?? false)) {
        setState(() => showUnlock = true);
        ref.read(billingProvider.notifier).consumeUnlockFlag();
        Future<void>.delayed(const Duration(milliseconds: 1900), () {
          if (!mounted) return;
          this.context.pop();
        });
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: showUnlock
          ? const _UnlockCelebration()
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: ThemePreview(
                      key: ValueKey(heroTheme),
                      theme: kBuiltInThemes[heroTheme],
                      expanded: true,
                      size: 180,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Butter Volume Premium',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                for (final benefit in const [
                  'Unlimited sessions — no 12-hour timers',
                  'All 10 hand-crafted themes',
                  'Create & save custom themes',
                  'Auto-start after reboot',
                  'No ads, ever',
                  'Cloud theme sync',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(benefit)),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                _PlanCard(
                  title: 'Lifetime',
                  price: billing.lifetimePrice,
                  subtitle: 'One payment, yours forever',
                  badge: 'Best value',
                  selected: selected == AppConstants.lifetimeProductId,
                  onTap: () => setState(
                      () => selected = AppConstants.lifetimeProductId),
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  title: 'Monthly',
                  price: '${billing.monthlyPrice}/month',
                  subtitle: 'Cancel anytime',
                  selected: selected == AppConstants.monthlyProductId,
                  onTap: () => setState(
                      () => selected = AppConstants.monthlyProductId),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: (billing.purchasing || isPremium)
                      ? null
                      : () =>
                          ref.read(billingProvider.notifier).purchase(selected),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: billing.purchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isPremium
                            ? 'You\'re premium ✓'
                            : 'Continue'),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(entitlementProvider.notifier).restore(),
                  child: const Text('Restore purchases'),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: Text('Maybe later',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Wrap(
                    spacing: 16,
                    children: [
                      TextButton(
                        onPressed: () => launchUrl(
                            Uri.parse(AppConstants.privacyPolicyUrl)),
                        child: const Text('Privacy',
                            style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () =>
                            launchUrl(Uri.parse(AppConstants.supportUrl)),
                        child: const Text('Support',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String subtitle;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: Motion.checkOff,
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB020),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(badge!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87)),
                          ),
                        ],
                      ],
                    ),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(price, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold arc draws a full circle around a checkmark + restrained confetti
/// (doc §9 premium unlock).
class _UnlockCelebration extends StatefulWidget {
  const _UnlockCelebration();

  @override
  State<_UnlockCelebration> createState() => _UnlockCelebrationState();
}

class _UnlockCelebrationState extends State<_UnlockCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController anim;

  @override
  void initState() {
    super.initState();
    anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
  }

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          final arcT = Curves.easeOutCubic
              .transform((anim.value / 0.45).clamp(0.0, 1.0));
          final popT = Curves.elasticOut
              .transform(((anim.value - 0.35) / 0.5).clamp(0.0, 1.0));
          final confettiT = ((anim.value - 0.45) / 0.3).clamp(0.0, 1.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _UnlockPainter(
                      arcT: arcT, confettiT: confettiT),
                  child: Center(
                    child: Transform.scale(
                      scale: popT,
                      child: const Icon(Icons.check_rounded,
                          size: 64, color: Color(0xFFFFB020)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Opacity(
                opacity: confettiT,
                child: Text('Welcome to Premium',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UnlockPainter extends CustomPainter {
  _UnlockPainter({required this.arcT, required this.confettiT});

  final double arcT;
  final double confettiT;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFB020);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width / 2 - 6),
      -math.pi / 2,
      arcT * 2 * math.pi,
      false,
      paint,
    );
    if (confettiT > 0) {
      final rng = math.Random(7);
      for (var i = 0; i < 14; i++) {
        final angle = rng.nextDouble() * 2 * math.pi;
        final distance =
            (size.width / 2) * (0.7 + 0.6 * confettiT) * rng.nextDouble();
        final dot = Paint()
          ..color = [
            const Color(0xFFFFB020),
            const Color(0xFF4F46E5),
            const Color(0xFF12B76A),
          ][i % 3]
              .withValues(alpha: 1 - confettiT);
        canvas.drawCircle(
          center + Offset(math.cos(angle), math.sin(angle)) * distance,
          3 - 1.5 * confettiT,
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_UnlockPainter old) =>
      old.arcT != arcT || old.confettiT != confettiT;
}

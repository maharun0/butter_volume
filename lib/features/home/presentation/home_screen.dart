import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/constants.dart';
import '../../../core/di/providers.dart';
import '../../floating_button/application/overlay_style_controller.dart';
import '../../subscription/application/entitlement_controller.dart';
import '../../themes/application/theme_controller.dart';
import '../../themes/domain/presets.dart';
import '../../themes/presentation/widgets/theme_preview.dart';
import '../application/feature_controller.dart';

/// The control room (doc §8.5): two feature cards + status at a glance.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.reactivateFeature});

  /// Set when arriving from an expiry notification deep link (doc §8.1).
  final String? reactivateFeature;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Timer? ticker;
  DateTime now = DateTime.now();
  bool bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 1 fps countdown repaint (doc §9 motion table).
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers fire and OEMs kill services while we're away (doc §13.4).
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(featuresProvider.notifier).refresh());
    }
  }

  Future<void> _toggle(AppFeature feature) async {
    final result = await ref.read(featuresProvider.notifier).toggle(feature);
    if (!mounted) return;
    switch (result) {
      case ActivationResult.needsOverlayPermission:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Overlay permission needed'),
            action: SnackBarAction(
              label: 'Grant',
              onPressed: () => ref
                  .read(permissionsChannelProvider)
                  .requestOverlayPermission(),
            ),
          ),
        );
      case ActivationResult.needsNotificationPermission:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification permission needed')),
        );
      case ActivationResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong — try again')),
        );
      case ActivationResult.started:
      case ActivationResult.stopped:
        break;
    }
  }

  void _quickThemeSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: 168,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final theme in kBuiltInThemes)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final result = ref.applyButtonTheme(theme);
                    Navigator.pop(sheetContext);
                    if (result == ApplyThemeResult.premiumRequired) {
                      context.push('/subscription?source=theme_gate');
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ThemePreview(theme: theme, size: 96),
                      Text(theme.name,
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final features = ref.watch(featuresProvider);
    final entitlement = ref.watch(entitlementProvider);
    final style = ref.watch(overlayStyleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Butter Volume',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (entitlement.needsPaymentFix)
            _PaymentFixBanner(onTap: () =>
                context.push('/subscription?source=payment_fix')),
          _FeatureCard(
            title: 'Floating button',
            subtitle: 'Volume control that floats above everything',
            preview: ThemePreview(theme: style, size: 72),
            state: features.of(AppFeature.floatingButton),
            now: now,
            isPremium: entitlement.isPremium,
            onToggle: () => _toggle(AppFeature.floatingButton),
            onTap: () => context.push('/floating-button'),
            onLongPress: _quickThemeSheet,
          ),
          const SizedBox(height: 14),
          _FeatureCard(
            title: 'Notification slider',
            subtitle: 'Volume controls in your notification shade',
            preview: Icon(Icons.notifications_active_rounded,
                size: 44, color: Theme.of(context).colorScheme.primary),
            state: features.of(AppFeature.notificationSlider),
            now: now,
            isPremium: entitlement.isPremium,
            onToggle: () => _toggle(AppFeature.notificationSlider),
            onTap: () => context.push('/notification-slider'),
          ),
          const SizedBox(height: 20),
          if (!entitlement.isPremium && !bannerDismissed)
            _PremiumBanner(
              onTap: () => context.push('/subscription?source=home_banner'),
              onDismiss: () => setState(() => bannerDismissed = true),
            ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.state,
    required this.now,
    required this.isPremium,
    required this.onToggle,
    required this.onTap,
    this.onLongPress,
  });

  final String title;
  final String subtitle;
  final Widget preview;
  final FeatureState state;
  final DateTime now;
  final bool isPremium;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  String _status() {
    if (state.killDetected) return 'Stopped by your phone — tap to fix';
    if (!state.enabled) return 'Off';
    if (isPremium) return 'Active';
    final remaining = state.remaining(now);
    if (remaining == null) return 'Active';
    if (remaining.isNegative) return 'Session ended';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    return h > 0 ? 'Active · ${h}h ${m}m left' : 'Active · ${m}m ${s}s left';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = state.remaining(now);
    final progress = (!isPremium && remaining != null && !remaining.isNegative)
        ? (remaining.inSeconds /
                AppConstants.freeSessionDuration.inSeconds)
            .clamp(0.0, 1.0)
        : null;

    return Card(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: state.enabled || state.killDetected ? 1 : 0.75,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(width: 72, height: 72, child: Center(child: preview)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _status(),
                          key: ValueKey(_status()),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: state.killDetected
                                    ? scheme.error
                                    : state.enabled
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (progress != null)
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    if (progress != null) const SizedBox(height: 8),
                    Switch(
                      value: state.enabled,
                      onChanged: (_) => onToggle(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.onTap, required this.onDismiss});

  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unlimited sessions + all themes — \$7 lifetime',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: scheme.onPrimaryContainer,
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentFixBanner extends StatelessWidget {
  const _PaymentFixBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        color: scheme.errorContainer,
        child: ListTile(
          leading: Icon(Icons.error_outline_rounded,
              color: scheme.onErrorContainer),
          title: Text('Payment issue — premium may pause soon',
              style: TextStyle(color: scheme.onErrorContainer)),
          onTap: onTap,
        ),
      ),
    );
  }
}

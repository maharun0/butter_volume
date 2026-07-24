import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/motion.dart';

/// Honest, staged permission asks (doc §8.4). Never blocks: every permission
/// is skippable; features gate themselves later. State re-checks on resume
/// after the system-settings round trip.
class PermissionSetupScreen extends ConsumerStatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  ConsumerState<PermissionSetupScreen> createState() =>
      _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends ConsumerState<PermissionSetupScreen>
    with WidgetsBindingObserver {
  bool overlayGranted = false;
  bool notificationsGranted = false;
  bool batteryExempt = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Card animates to ✓ when the user returns from settings (doc §8.4).
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final permissions = ref.read(permissionsChannelProvider);
    try {
      final overlay = await permissions.hasOverlayPermission();
      final notifications = await permissions.hasNotificationPermission();
      final battery = await permissions.isIgnoringBatteryOptimizations();
      if (!mounted) return;
      setState(() {
        overlayGranted = overlay;
        notificationsGranted = notifications;
        batteryExempt = battery;
      });
    } catch (_) {}
  }

  Future<void> _finish() async {
    await ref.read(settingsRepositoryProvider).setOnboardingDone();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.read(permissionsChannelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Set up Butter Volume')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Two quick permissions make the magic work. You can skip any of '
            'them — features simply wait until they\'re granted.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _PermissionCard(
            icon: Icons.picture_in_picture_alt_rounded,
            title: 'Display over other apps',
            reason: 'Lets the floating button live above every app.',
            granted: overlayGranted,
            onTap: () => permissions.requestOverlayPermission(),
          ),
          const SizedBox(height: 12),
          _PermissionCard(
            icon: Icons.notifications_active_rounded,
            title: 'Notifications',
            reason:
                'Powers the notification slider and session reminders.',
            granted: notificationsGranted,
            onTap: () async {
              await permissions.requestNotificationPermission();
              await _check();
            },
          ),
          if (!batteryExempt) ...[
            const SizedBox(height: 12),
            _PermissionCard(
              icon: Icons.battery_saver_rounded,
              title: 'Battery optimization',
              reason:
                  'Optional: stops your phone from pausing Butter Volume in '
                  'the background.',
              granted: batteryExempt,
              onTap: () => permissions.openBatteryOptimizationSettings(),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _finish,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.reason,
    required this.granted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String reason;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: granted ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon,
                  size: 32,
                  color: granted ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(reason,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: Motion.checkOff,
                child: granted
                    ? Icon(Icons.check_circle_rounded,
                        key: const ValueKey('ok'), color: scheme.primary)
                    : Chip(
                        key: const ValueKey('needed'),
                        label: const Text('Grant'),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: scheme.outline),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

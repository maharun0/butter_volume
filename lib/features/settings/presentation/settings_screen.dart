import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../subscription/application/entitlement_controller.dart';
import '../application/appearance_controller.dart';

/// Everything else (doc §8.11, catalog §10).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final appearanceCtl = ref.read(appearanceProvider.notifier);
    final settings = ref.watch(settingsRepositoryProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SectionHeader('Appearance'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('App theme'),
            trailing: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system, icon: Icon(Icons.brightness_auto)),
                ButtonSegment(
                    value: ThemeMode.light, icon: Icon(Icons.light_mode)),
                ButtonSegment(
                    value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
              ],
              selected: {appearance.themeMode},
              onSelectionChanged: (s) => appearanceCtl.setThemeMode(s.first),
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Dynamic color'),
            subtitle: const Text('Match your wallpaper (Android 12+)'),
            value: appearance.dynamicColor,
            onChanged: appearanceCtl.setDynamicColor,
          ),
          if (!appearance.dynamicColor)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Wrap(
                spacing: 10,
                children: [
                  for (final seed in kAccentSeeds)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => appearanceCtl.setAccentSeed(seed),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: seed,
                          shape: BoxShape.circle,
                        ),
                        child: appearance.accentSeed.toARGB32() ==
                                seed.toARGB32()
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          const SectionHeader('General'),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Row(
              children: [
                const Text('Auto-start after reboot'),
                if (!isPremium) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.lock_rounded,
                      size: 14, color: Theme.of(context).colorScheme.outline),
                ],
              ],
            ),
            subtitle: const Text('Restart active features when your phone boots'),
            value: settings.autostart && isPremium,
            onChanged: (v) async {
              if (!isPremium) {
                await context.push('/subscription?source=settings');
                return;
              }
              await settings.setAutostart(v);
              ref.invalidate(settingsRepositoryProvider);
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.battery_saver_rounded),
            title: const Text('Battery optimization'),
            subtitle:
                const Text('Stop your phone from pausing Butter Volume'),
            onTap: () => ref
                .read(permissionsChannelProvider)
                .openBatteryOptimizationSettings(),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Share anonymous usage stats'),
            value: settings.analyticsEnabled,
            onChanged: (v) async {
              await settings.setAnalyticsEnabled(v);
              ref.invalidate(settingsRepositoryProvider);
            },
          ),
          const SectionHeader('Account'),
          auth.signedIn
              ? ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.account_circle_rounded),
                  title: Text(auth.email ?? 'Signed in'),
                  subtitle: const Text('Cloud theme sync enabled'),
                  trailing: TextButton(
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                    child: const Text('Sign out'),
                  ),
                )
              : ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.login_rounded),
                  title: const Text('Sign in with Google'),
                  subtitle: const Text(
                      'Optional — syncs themes and purchases across devices'),
                  onTap: () async {
                    final ok = await ref.read(authProvider.notifier).signIn();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Sign-in unavailable right now')));
                    }
                  },
                ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.restore_rounded),
            title: const Text('Restore purchases'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              await ref.read(entitlementProvider.notifier).restore();
              messenger.showSnackBar(
                  const SnackBar(content: Text('Restore requested')));
            },
          ),
          const SectionHeader('Data'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.delete_forever_rounded),
            title: const Text('Reset all settings'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Reset all settings?'),
                  content: const Text(
                      'Preferences return to defaults. Your custom themes are kept.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Reset')),
                  ],
                ),
              );
              if (confirmed ?? false) {
                await settings.resetAll();
                ref.invalidate(settingsRepositoryProvider);
              }
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About'),
            onTap: () => context.push('/about'),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: const Text('Send feedback'),
            onTap: () => context.push('/feedback'),
          ),
          const SizedBox(height: 12),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  snapshot.hasData
                      ? 'Butter Volume ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                      : '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

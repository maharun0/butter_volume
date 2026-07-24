import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/motion.dart';
import '../../subscription/application/entitlement_controller.dart';
import '../application/theme_controller.dart';
import '../domain/button_theme_spec.dart';
import '../domain/presets.dart';
import 'widgets/theme_preview.dart';

/// Preset + custom theme browser (doc §8.7). Cards render the real overlay
/// painter — always accurate. Premium presets carry a PRO chip; gated taps
/// route to the paywall with theme context.
class ThemeGalleryScreen extends ConsumerStatefulWidget {
  const ThemeGalleryScreen({super.key});

  @override
  ConsumerState<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

class _ThemeGalleryScreenState extends ConsumerState<ThemeGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  late final AnimationController entrance;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
    entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    tabs.dispose();
    entrance.dispose();
    super.dispose();
  }

  void _apply(ButtonThemeSpec theme) {
    final result = ref.applyButtonTheme(theme);
    if (result == ApplyThemeResult.premiumRequired) {
      context.push('/subscription?source=theme_gate');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${theme.name} applied'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    final customs = ref.watch(customThemesProvider);
    final activeId = ref.watch(settingsRepositoryProvider).activeThemeId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Themes'),
        bottom: TabBar(
          controller: tabs,
          tabs: const [Tab(text: 'Presets'), Tab(text: 'My themes')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/themes/edit/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create theme'),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          // -- Presets --
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemCount: kBuiltInThemes.length,
            itemBuilder: (context, i) {
              final theme = kBuiltInThemes[i];
              // Staggered entrance: 40 ms/item fade + rise (doc §9).
              final start = (i * 0.06).clamp(0.0, 0.7);
              final anim = CurvedAnimation(
                parent: entrance,
                curve: Interval(start, (start + 0.3).clamp(0.0, 1.0),
                    curve: Curves.easeOutCubic),
              );
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                          begin: const Offset(0, 0.06), end: Offset.zero)
                      .animate(anim),
                  child: _ThemeCard(
                    theme: theme,
                    locked: !isPremium && !kFreeThemeIds.contains(theme.id),
                    active: activeId == theme.id,
                    onTap: () => _apply(theme),
                    onLongPress: () => _previewSheet(theme),
                  ),
                ),
              );
            },
          ),
          // -- My themes --
          customs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load themes: $e')),
            data: (themes) => themes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.brush_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text('No custom themes yet'),
                        const SizedBox(height: 4),
                        Text('Tap "Create theme" to design one',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.86,
                    ),
                    itemCount: themes.length,
                    itemBuilder: (context, i) => _ThemeCard(
                      theme: themes[i],
                      locked: !isPremium,
                      active: activeId == themes[i].id,
                      onTap: () => _apply(themes[i]),
                      onLongPress: () => _customMenu(themes[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Long-press preview-in-place (doc §8.7): expanded radial demo.
  void _previewSheet(ButtonThemeSpec theme) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(theme.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ThemePreview(theme: theme, expanded: true, size: 220),
          ],
        ),
      ),
    );
  }

  void _customMenu(ButtonThemeSpec theme) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(sheetContext);
              context.push('/themes/edit/${theme.id}');
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Duplicate'),
            onTap: () {
              Navigator.pop(sheetContext);
              ref.read(customThemesProvider.notifier).duplicate(theme);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(sheetContext);
              ref.read(customThemesProvider.notifier).delete(theme.id);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.locked,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final ButtonThemeSpec theme;
  final bool locked;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: active
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Center(child: ThemePreview(theme: theme, size: 110)),
                    if (locked)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB020),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    if (active)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Icon(Icons.check_circle_rounded,
                            size: 20, color: scheme.primary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              AnimatedDefaultTextStyle(
                duration: Motion.checkOff,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: active ? scheme.primary : scheme.onSurface,
                    ),
                child: Text(theme.name, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

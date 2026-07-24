import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/constants.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../application/slider_config_controller.dart';

/// Feature 2 configuration (doc §8.9) with a live notification mock.
class NotificationSliderSettingsScreen extends ConsumerWidget {
  const NotificationSliderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(sliderConfigProvider);
    final ctl = ref.read(sliderConfigProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification slider')),
      body: ListView(
        children: [
          // Live mock (doc §8.9): shared-axis-ish switch compact ↔ expanded.
          Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedSwitcher(
              duration: Motion.screenTransition,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                          begin: const Offset(0.08, 0), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: _NotificationMock(
                key: ValueKey(config.layout),
                expanded: config.layout == 'expanded',
                presets: config.presets,
                showMute: config.showMute,
                showStream: config.showStream,
                stream: config.stream,
              ),
            ),
          ),
          const SectionHeader('Layout'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'compact', label: Text('Compact')),
                ButtonSegment(value: 'expanded', label: Text('Expanded')),
              ],
              selected: {config.layout},
              onSelectionChanged: (s) =>
                  ctl.update((c) => c.copyWith(layout: s.first)),
            ),
          ),
          const SectionHeader('Step size'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('1 step')),
                ButtonSegment(value: 5, label: Text('5%')),
                ButtonSegment(value: 10, label: Text('10%')),
              ],
              selected: {config.stepPercent},
              onSelectionChanged: (s) =>
                  ctl.update((c) => c.copyWith(stepPercent: s.first)),
            ),
          ),
          const SectionHeader('Quick presets'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: [
                for (final p in const [0, 25, 50, 75, 100])
                  FilterChip(
                    label: Text('$p%'),
                    selected: config.presets.contains(p),
                    onSelected: (on) => ctl.update((c) {
                      final next = [...c.presets];
                      on ? next.add(p) : next.remove(p);
                      next.sort();
                      return c.copyWith(presets: next);
                    }),
                  ),
              ],
            ),
          ),
          const SectionHeader('Controls'),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Mute button'),
            value: config.showMute,
            onChanged: (v) => ctl.update((c) => c.copyWith(showMute: v)),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Show stream label'),
            value: config.showStream,
            onChanged: (v) => ctl.update((c) => c.copyWith(showStream: v)),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('Volume stream'),
            trailing: DropdownButton<String>(
              value: config.stream,
              underline: const SizedBox.shrink(),
              items: [
                for (final s in VolumeStream.values)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(s.id[0].toUpperCase() + s.id.substring(1)),
                  ),
              ],
              onChanged: (v) =>
                  v == null ? null : ctl.update((c) => c.copyWith(stream: v)),
            ),
          ),
          const SizedBox(height: 8),
          // Swipe-away reality hint (doc §6.3, Android 13+).
          Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'On Android 13+ you can swipe this notification away. '
                        'It returns automatically the next time your volume '
                        'changes.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faithful render of the RemoteViews layouts (doc §8.9 "pixel-accurate").
class _NotificationMock extends StatelessWidget {
  const _NotificationMock({
    super.key,
    required this.expanded,
    required this.presets,
    required this.showMute,
    required this.showStream,
    required this.stream,
  });

  final bool expanded;
  final List<int> presets;
  final bool showMute;
  final bool showStream;
  final String stream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text('Butter Volume',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (showMute) ...[
                Icon(Icons.volume_off_rounded,
                    size: 22, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
              ],
              Icon(Icons.remove_rounded,
                  size: 22, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: 0.65, minHeight: 6, color: scheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.add_rounded, size: 22, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text('65%', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          if (expanded && presets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final p in presets)
                  Text('$p%',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: scheme.primary)),
              ],
            ),
          ],
          if (expanded && showStream) ...[
            const SizedBox(height: 6),
            Text(
              '${stream[0].toUpperCase()}${stream.substring(1)} volume',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

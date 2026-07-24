import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/color_picker_row.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/value_slider_tile.dart';
import '../../themes/domain/button_theme_spec.dart';
import '../../themes/domain/presets.dart';
import '../../themes/domain/theme_icons.dart';
import '../../themes/presentation/widgets/theme_preview.dart';
import '../application/overlay_style_controller.dart';

/// Full live customization (doc §8.6): every control writes through to the
/// real overlay while you drag (doc §6.2.3). The pinned preview is the same
/// widget the overlay renders, so it is always accurate.
class FloatingButtonSettingsScreen extends ConsumerWidget {
  const FloatingButtonSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(overlayStyleProvider);
    final behavior = ref.watch(overlayBehaviorProvider);
    final styleCtl = ref.read(overlayStyleProvider.notifier);
    final behaviorCtl = ref.read(overlayBehaviorProvider.notifier);

    void updateButton(ButtonStyleSpec Function(ButtonStyleSpec) f) =>
        styleCtl.update((t) => t.copyWith(button: f(t.button)));

    return Scaffold(
      appBar: AppBar(title: const Text('Floating button')),
      body: Column(
        children: [
          // Pinned live preview header (doc §8.6).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 150),
                child: ThemePreview(theme: style, size: 120),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                const SectionHeader('Appearance'),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme gallery'),
                  subtitle: const Text('Presets and your custom themes'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/themes'),
                ),
                ValueSliderTile(
                  label: 'Size',
                  value: style.button.size,
                  min: 40,
                  max: 72,
                  divisions: 32,
                  display: (v) => '${v.round()} dp',
                  onChanged: (v) => updateButton((b) => b.copyWith(size: v)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SegmentedButton<ButtonShape>(
                    segments: const [
                      ButtonSegment(
                          value: ButtonShape.circle,
                          icon: Icon(Icons.circle_outlined),
                          label: Text('Circle')),
                      ButtonSegment(
                          value: ButtonShape.squircle,
                          icon: Icon(Icons.rounded_corner_rounded),
                          label: Text('Squircle')),
                      ButtonSegment(
                          value: ButtonShape.roundedSquare,
                          icon: Icon(Icons.crop_square_rounded),
                          label: Text('Square')),
                    ],
                    selected: {style.button.shape},
                    onSelectionChanged: (s) =>
                        updateButton((b) => b.copyWith(shape: s.first)),
                  ),
                ),
                ColorPickerRow(
                  label: 'Color',
                  color: style.button.color,
                  onChanged: (c) => updateButton((b) => b.copyWith(color: c)),
                ),
                ValueSliderTile(
                  label: 'Opacity',
                  value: style.button.opacity,
                  min: 0.2,
                  max: 1,
                  display: (v) => '${(v * 100).round()}%',
                  onChanged: (v) => updateButton((b) => b.copyWith(opacity: v)),
                ),
                ValueSliderTile(
                  label: 'Elevation',
                  value: style.button.elevation,
                  min: 0,
                  max: 12,
                  divisions: 12,
                  display: (v) => v.round().toString(),
                  onChanged: (v) =>
                      updateButton((b) => b.copyWith(elevation: v)),
                ),
                ValueSliderTile(
                  label: 'Border width',
                  value: style.button.border.width,
                  min: 0,
                  max: 4,
                  divisions: 8,
                  display: (v) => v.toStringAsFixed(1),
                  onChanged: (v) => updateButton(
                      (b) => b.copyWith(border: b.border.copyWith(width: v))),
                ),
                ColorPickerRow(
                  label: 'Border color',
                  color: style.button.border.color,
                  onChanged: (c) => updateButton(
                      (b) => b.copyWith(border: b.border.copyWith(color: c))),
                ),
                ValueSliderTile(
                  label: 'Shadow',
                  value: style.button.shadow.opacity,
                  min: 0,
                  max: 1,
                  display: (v) => '${(v * 100).round()}%',
                  onChanged: (v) => updateButton(
                      (b) => b.copyWith(shadow: b.shadow.copyWith(opacity: v))),
                ),
                const SectionHeader('Icon'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in kThemeIconIds)
                        _IconChoice(
                          icon: themeIcon(id),
                          selected: style.button.icon == id,
                          onTap: () =>
                              updateButton((b) => b.copyWith(icon: id)),
                        ),
                    ],
                  ),
                ),
                ValueSliderTile(
                  label: 'Icon size',
                  value: style.button.iconSize,
                  min: 16,
                  max: 40,
                  divisions: 24,
                  display: (v) => '${v.round()} dp',
                  onChanged: (v) =>
                      updateButton((b) => b.copyWith(iconSize: v)),
                ),
                ColorPickerRow(
                  label: 'Icon color',
                  color: style.button.iconColor,
                  onChanged: (c) =>
                      updateButton((b) => b.copyWith(iconColor: c)),
                ),
                const SectionHeader('Behavior'),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Default volume stream'),
                  trailing: DropdownButton<String>(
                    value: behavior.stream,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final s in VolumeStream.values)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(s.id[0].toUpperCase() + s.id.substring(1)),
                        ),
                    ],
                    onChanged: (v) => v == null
                        ? null
                        : behaviorCtl.update((b) => b.copyWith(stream: v)),
                  ),
                ),
                ValueSliderTile(
                  label: 'Sensitivity',
                  value: behavior.sensitivity,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  display: (v) => '${v.toStringAsFixed(1)}×',
                  onChanged: (v) =>
                      behaviorCtl.update((b) => b.copyWith(sensitivity: v)),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Snap to edge'),
                  value: behavior.edgeSnap,
                  onChanged: (v) =>
                      behaviorCtl.update((b) => b.copyWith(edgeSnap: v)),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Free placement'),
                  subtitle: const Text('Place the button anywhere'),
                  value: behavior.freePlacement,
                  onChanged: (v) =>
                      behaviorCtl.update((b) => b.copyWith(freePlacement: v)),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Peek mode'),
                  subtitle: const Text('Shrink to the edge when idle'),
                  value: behavior.peekMode,
                  onChanged: (v) =>
                      behaviorCtl.update((b) => b.copyWith(peekMode: v)),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Vibrate on long-press'),
                  value: behavior.longPressHaptic,
                  onChanged: (v) =>
                      behaviorCtl.update((b) => b.copyWith(longPressHaptic: v)),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Haptic volume ticks'),
                  value: behavior.hapticTicks,
                  onChanged: (v) =>
                      behaviorCtl.update((b) => b.copyWith(hapticTicks: v)),
                ),
                ValueSliderTile(
                  label: 'Animation speed',
                  value: behavior.animationSpeed,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  display: (v) => '${v.toStringAsFixed(1)}×',
                  onChanged: (v) =>
                      behaviorCtl.update((b) => b.copyWith(animationSpeed: v)),
                ),
                const SectionHeader('Position'),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: const Text('Reset position'),
                  onTap: () async {
                    await ref.read(overlayChannelProvider).resetPosition();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Position reset')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
          border: selected ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        child: Icon(icon,
            size: 22,
            color: selected ? scheme.primary : scheme.onSurfaceVariant),
      ),
    );
  }
}

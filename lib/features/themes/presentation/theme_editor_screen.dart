import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/color_picker_row.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/value_slider_tile.dart';
import '../../floating_button/application/overlay_style_controller.dart';
import '../../subscription/application/entitlement_controller.dart';
import '../application/theme_controller.dart';
import '../domain/button_theme_spec.dart';
import '../domain/presets.dart';
import 'widgets/theme_preview.dart';

/// Create/edit custom themes (doc §8.8). All edits are live against the
/// preview; "Try on screen" pushes to the real overlay; Save is
/// premium-gated (free users get the paywall, draft kept — doc §7.3).
class ThemeEditorScreen extends ConsumerStatefulWidget {
  const ThemeEditorScreen({super.key, required this.themeId});

  /// Existing custom-theme id, or `new`.
  final String themeId;

  @override
  ConsumerState<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends ConsumerState<ThemeEditorScreen> {
  ButtonThemeSpec? draft;
  bool expandedPreview = false;
  bool dirty = false;
  late final TextEditingController nameController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    ButtonThemeSpec base;
    if (widget.themeId == 'new') {
      base = ref.read(overlayStyleProvider).copyWith(
            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
            name: 'My theme',
            isBuiltIn: false,
            basedOn: ref.read(overlayStyleProvider).isBuiltIn
                ? ref.read(overlayStyleProvider).id
                : null,
          );
    } else {
      base = await ref.read(themeRepositoryProvider).byId(widget.themeId) ??
          kDefaultTheme.copyWith(
            id: widget.themeId,
            name: 'My theme',
            isBuiltIn: false,
          );
    }
    if (!mounted) return;
    setState(() {
      draft = base;
      nameController.text = base.name;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _mutate(ButtonThemeSpec Function(ButtonThemeSpec) f) {
    setState(() {
      draft = f(draft!);
      dirty = true;
    });
  }

  Future<void> _save() async {
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) {
      // Draft stays in memory; the paywall reassures (doc §8.8).
      await context.push('/subscription?source=save_gate');
      if (!ref.read(isPremiumProvider)) return;
    }
    final spec = draft!.copyWith(name: nameController.text.trim().isEmpty
        ? 'My theme'
        : nameController.text.trim());
    await ref.read(customThemesProvider.notifier).save(spec);
    if (!mounted) return;
    dirty = false;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Theme saved')));
    context.pop();
  }

  Future<bool> _confirmDiscard() async {
    if (!dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits to this theme will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep editing')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final d = draft;
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    void updateButton(ButtonStyleSpec Function(ButtonStyleSpec) f) =>
        _mutate((t) => t.copyWith(button: f(t.button)));
    void updateRadial(RadialStyleSpec Function(RadialStyleSpec) f) =>
        _mutate((t) => t.copyWith(radial: f(t.radial)));

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (!mounted) return;
        if (discard) this.context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.themeId == 'new' ? 'New theme' : 'Edit theme'),
          actions: [
            TextButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
        body: Column(
          children: [
            // Live preview with idle ↔ expanded toggle (doc §8.8).
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => expandedPreview = !expandedPreview),
                    child: ThemePreview(
                        theme: d, expanded: expandedPreview, size: 130),
                  ),
                  Text(
                    expandedPreview ? 'Radial view · tap to switch' : 'Idle view · tap to switch',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Theme name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => dirty = true,
                    ),
                  ),
                  const SectionHeader('Button'),
                  ValueSliderTile(
                    label: 'Size',
                    value: d.button.size,
                    min: 40,
                    max: 72,
                    divisions: 32,
                    display: (v) => '${v.round()} dp',
                    onChanged: (v) => updateButton((b) => b.copyWith(size: v)),
                  ),
                  ColorPickerRow(
                    label: 'Color',
                    color: d.button.color,
                    onChanged: (c) => updateButton((b) => b.copyWith(color: c)),
                  ),
                  ValueSliderTile(
                    label: 'Opacity',
                    value: d.button.opacity,
                    min: 0.2,
                    max: 1,
                    display: (v) => '${(v * 100).round()}%',
                    onChanged: (v) =>
                        updateButton((b) => b.copyWith(opacity: v)),
                  ),
                  ColorPickerRow(
                    label: 'Icon color',
                    color: d.button.iconColor,
                    onChanged: (c) =>
                        updateButton((b) => b.copyWith(iconColor: c)),
                  ),
                  ColorPickerRow(
                    label: 'Border color',
                    color: d.button.border.color,
                    onChanged: (c) => updateButton(
                        (b) => b.copyWith(border: b.border.copyWith(color: c))),
                  ),
                  ValueSliderTile(
                    label: 'Border width',
                    value: d.button.border.width,
                    min: 0,
                    max: 4,
                    divisions: 8,
                    display: (v) => v.toStringAsFixed(1),
                    onChanged: (v) => updateButton(
                        (b) => b.copyWith(border: b.border.copyWith(width: v))),
                  ),
                  ColorPickerRow(
                    label: 'Shadow color',
                    color: d.button.shadow.color,
                    onChanged: (c) => updateButton(
                        (b) => b.copyWith(shadow: b.shadow.copyWith(color: c))),
                  ),
                  const SectionHeader('Radial'),
                  ColorPickerRow(
                    label: 'Track color',
                    color: d.radial.trackColor,
                    onChanged: (c) =>
                        updateRadial((r) => r.copyWith(trackColor: c)),
                  ),
                  ColorPickerRow(
                    label: 'Progress start',
                    color: d.radial.progressColors.first,
                    onChanged: (c) => updateRadial((r) => r.copyWith(
                        progressColors: [c, r.progressColors.last])),
                  ),
                  ColorPickerRow(
                    label: 'Progress end',
                    color: d.radial.progressColors.last,
                    onChanged: (c) => updateRadial((r) => r.copyWith(
                        progressColors: [r.progressColors.first, c])),
                  ),
                  ValueSliderTile(
                    label: 'Stroke width',
                    value: d.radial.strokeWidth,
                    min: 4,
                    max: 18,
                    divisions: 14,
                    display: (v) => '${v.round()} dp',
                    onChanged: (v) =>
                        updateRadial((r) => r.copyWith(strokeWidth: v)),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: const Text('Glow'),
                    value: d.radial.glow,
                    onChanged: (v) => updateRadial((r) => r.copyWith(glow: v)),
                  ),
                  if (d.radial.glow)
                    ColorPickerRow(
                      label: 'Glow color',
                      color: d.radial.glowColor,
                      onChanged: (c) =>
                          updateRadial((r) => r.copyWith(glowColor: c)),
                    ),
                  const SectionHeader('Animation style'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final style in ThemeAnimationStyle.values)
                          ChoiceChip(
                            label: Text(style.id),
                            selected: d.animationStyle == style,
                            onSelected: (_) => _mutate(
                                (t) => t.copyWith(animationStyle: style)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Try on screen'),
                      onPressed: () {
                        // Temporary live push — not saved (doc §8.8).
                        ref.read(overlayStyleProvider.notifier).apply(d);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Applied to your floating button')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

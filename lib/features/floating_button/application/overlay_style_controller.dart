import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../themes/domain/button_theme_spec.dart';
import '../../themes/domain/presets.dart';
import '../domain/overlay_behavior.dart';

/// The *current* overlay style — the `overlay.theme` pref is the single
/// source the overlay service renders from. Applying a gallery theme copies
/// its spec here; tweaking a slider edits it in place. Every write pushes
/// live to a running overlay (doc §6.2.3).
class OverlayStyleController extends Notifier<ButtonThemeSpec> {
  @override
  ButtonThemeSpec build() {
    final settings = ref.watch(settingsRepositoryProvider);
    final raw = settings.overlayThemeJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        return ButtonThemeSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return kDefaultTheme;
  }

  Future<void> apply(ButtonThemeSpec spec, {String? sourceThemeId}) async {
    state = spec;
    final settings = ref.read(settingsRepositoryProvider);
    await settings.setOverlayThemeJson(jsonEncode(spec.toJson()));
    if (sourceThemeId != null) {
      await settings.setActiveThemeId(sourceThemeId);
    }
    // Live push; silently fine when the overlay isn't running.
    unawaited(_refresh());
  }

  Future<void> update(ButtonThemeSpec Function(ButtonThemeSpec) mutate) =>
      apply(mutate(state));

  Future<void> _refresh() async {
    try {
      await ref.read(overlayChannelProvider).refreshStyle();
    } catch (_) {}
  }
}

final overlayStyleProvider =
    NotifierProvider<OverlayStyleController, ButtonThemeSpec>(
        OverlayStyleController.new);

/// Behavior settings, same live write-through pattern.
class OverlayBehaviorController extends Notifier<OverlayBehavior> {
  @override
  OverlayBehavior build() {
    final settings = ref.watch(settingsRepositoryProvider);
    final raw = settings.overlayBehaviorJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        return OverlayBehavior.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return const OverlayBehavior();
  }

  Future<void> update(OverlayBehavior Function(OverlayBehavior) mutate) async {
    state = mutate(state);
    await ref
        .read(settingsRepositoryProvider)
        .setOverlayBehaviorJson(jsonEncode(state.toJson()));
    try {
      await ref.read(overlayChannelProvider).refreshStyle();
    } catch (_) {}
  }
}

final overlayBehaviorProvider =
    NotifierProvider<OverlayBehaviorController, OverlayBehavior>(
        OverlayBehaviorController.new);

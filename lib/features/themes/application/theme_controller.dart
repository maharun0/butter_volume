import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../floating_button/application/overlay_style_controller.dart';
import '../../subscription/application/entitlement_controller.dart';
import '../data/theme_repository.dart';
import '../domain/button_theme_spec.dart';
import '../domain/presets.dart';

final themeRepositoryProvider = Provider<ThemeRepository>((_) => ThemeRepository());

/// Custom themes list (built-ins are const, doc §7.2).
final customThemesProvider =
    AsyncNotifierProvider<CustomThemesController, List<ButtonThemeSpec>>(
        CustomThemesController.new);

class CustomThemesController extends AsyncNotifier<List<ButtonThemeSpec>> {
  @override
  Future<List<ButtonThemeSpec>> build() =>
      ref.watch(themeRepositoryProvider).customThemes();

  /// Save (create/update) a custom theme — premium-gated at the call site
  /// (doc §7.3: free users get the paywall on save).
  Future<void> save(ButtonThemeSpec spec) async {
    final stamped = spec.copyWith(
      isBuiltIn: false,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(themeRepositoryProvider).upsert(stamped);
    ref.read(analyticsProvider).track('theme_created', {
      'based_on': stamped.basedOn ?? 'scratch',
    });
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(themeRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }

  Future<void> duplicate(ButtonThemeSpec spec) async {
    final copy = spec.copyWith(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: '${spec.name} copy',
      isBuiltIn: false,
      basedOn: spec.isBuiltIn ? spec.id : spec.basedOn,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.read(themeRepositoryProvider).upsert(copy);
    ref.invalidateSelf();
  }
}

/// Apply outcome — the gallery routes gated attempts to the paywall.
enum ApplyThemeResult { applied, premiumRequired }

extension ApplyTheme on WidgetRef {
  /// Premium gating (doc §6.4): free tier gets 4 presets; customs and the
  /// other 6 presets require premium.
  ApplyThemeResult applyButtonTheme(ButtonThemeSpec spec) {
    final isPremium = read(isPremiumProvider);
    final isFree = spec.isBuiltIn && kFreeThemeIds.contains(spec.id);
    if (!isPremium && !isFree) return ApplyThemeResult.premiumRequired;

    read(overlayStyleProvider.notifier).apply(spec, sourceThemeId: spec.id);
    read(analyticsProvider).track('theme_applied', {
      'theme_id': spec.isBuiltIn ? spec.id : 'custom',
      'is_custom': !spec.isBuiltIn,
    });
    return ApplyThemeResult.applied;
  }
}

import 'dart:convert';

import 'package:butter_volume/features/themes/domain/button_theme_spec.dart';
import 'package:butter_volume/features/themes/domain/presets.dart';
import 'package:butter_volume/features/themes/domain/theme_icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ButtonThemeSpec JSON (doc §7.1 canonical schema)', () {
    test('all built-in presets round-trip through JSON', () {
      for (final preset in kBuiltInThemes) {
        final json = jsonEncode(preset.toJson());
        final restored =
            ButtonThemeSpec.fromJson(jsonDecode(json) as Map<String, dynamic>);
        expect(restored.id, preset.id);
        expect(restored.name, preset.name);
        expect(restored.button.size, preset.button.size);
        expect(restored.button.shape, preset.button.shape);
        expect(restored.button.color, preset.button.color);
        expect(restored.radial.progressColors, preset.radial.progressColors);
        expect(restored.animationStyle, preset.animationStyle);
        expect(restored.schemaVersion, 1);
      }
    });

    test('exactly 10 presets, 4 free (doc §6.4)', () {
      expect(kBuiltInThemes, hasLength(10));
      expect(kFreeThemeIds, hasLength(4));
      final ids = kBuiltInThemes.map((t) => t.id).toSet();
      expect(ids.containsAll(kFreeThemeIds), isTrue);
      expect(ids, hasLength(10)); // unique ids
    });

    test('color hex helpers are inverse', () {
      const hex = '#1E88E5';
      expect(colorToHex(colorFromHex(hex)), hex);
    });

    test('unknown enum ids fall back safely (forward compatibility)', () {
      expect(ButtonShape.fromId('hexagon'), ButtonShape.circle);
      expect(ThemeAnimationStyle.fromId('warp'), ThemeAnimationStyle.smooth);
    });

    test('every advertised icon id resolves to a glyph', () {
      expect(themeIconsCoverIds, isTrue);
    });
  });
}

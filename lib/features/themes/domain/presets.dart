import 'dart:ui';

import 'button_theme_spec.dart';

/// The ~12 curated icons a theme may use (doc §7.1). Icon names map to
/// Material glyphs in the presentation layers (app + overlay) via
/// `theme_icons.dart` so this file stays pure Dart.
const List<String> kThemeIconIds = [
  'volume_up',
  'music_note',
  'graphic_eq',
  'speaker',
  'headphones',
  'equalizer',
  'tune',
  'campaign',
  'surround_sound',
  'radio',
  'album',
  'waves',
];

final _epoch = DateTime.utc(2026);

ButtonThemeSpec _preset({
  required String id,
  required String name,
  required Color color,
  double opacity = 1.0,
  double elevation = 6,
  BorderSpec border =
      const BorderSpec(width: 0, color: Color(0xFFFFFFFF), opacity: 0),
  required ShadowSpec shadow,
  Color iconColor = const Color(0xFFFFFFFF),
  required Color trackColor,
  double trackOpacity = 0.5,
  required List<Color> progressColors,
  bool glow = false,
  Color? glowColor,
  Color centerLabelColor = const Color(0xFFFFFFFF),
  ThemeAnimationStyle animationStyle = ThemeAnimationStyle.smooth,
}) =>
    ButtonThemeSpec(
      id: id,
      name: name,
      isBuiltIn: true,
      button: ButtonStyleSpec(
        size: 56,
        shape: ButtonShape.circle,
        color: color,
        opacity: opacity,
        elevation: elevation,
        border: border,
        shadow: shadow,
        icon: 'volume_up',
        iconSize: 26,
        iconColor: iconColor,
      ),
      radial: RadialStyleSpec(
        trackColor: trackColor,
        trackOpacity: trackOpacity,
        progressColors: progressColors,
        strokeWidth: 10,
        glow: glow,
        glowColor: glowColor ?? progressColors.first,
        centerLabelColor: centerLabelColor,
      ),
      animationStyle: animationStyle,
      updatedAt: _epoch,
    );

/// Built-in presets (doc §7.2). First four are the free tier (doc §6.4).
final List<ButtonThemeSpec> kBuiltInThemes = [
  _preset(
    id: 'minimal_white',
    name: 'Minimal White',
    color: const Color(0xFFFFFFFF),
    opacity: 0.95,
    elevation: 4,
    border: const BorderSpec(
        width: 1, color: Color(0xFFE0E0E0), opacity: 1),
    shadow: const ShadowSpec(
        color: Color(0xFF9E9E9E), blurRadius: 12, offsetY: 3, opacity: 0.35),
    iconColor: const Color(0xFF212121),
    trackColor: const Color(0xFFE0E0E0),
    trackOpacity: 0.8,
    progressColors: const [Color(0xFF616161)],
    centerLabelColor: const Color(0xFF212121),
  ),
  _preset(
    id: 'amoled_black',
    name: 'AMOLED Black',
    color: const Color(0xFF000000),
    elevation: 0,
    border: const BorderSpec(
        width: 1, color: Color(0xFF333333), opacity: 1),
    shadow: const ShadowSpec(
        color: Color(0xFF000000), blurRadius: 0, offsetY: 0, opacity: 0),
    trackColor: const Color(0xFF222222),
    trackOpacity: 1,
    progressColors: const [Color(0xFFEEEEEE)],
    animationStyle: ThemeAnimationStyle.snappy,
  ),
  _preset(
    id: 'ocean_blue',
    name: 'Ocean Blue',
    color: const Color(0xFF1E88E5),
    opacity: 0.92,
    border: const BorderSpec(
        width: 1.5, color: Color(0xFFFFFFFF), opacity: 0.35),
    shadow: const ShadowSpec(
        color: Color(0xFF0A2540), blurRadius: 14, offsetY: 4, opacity: 0.3),
    trackColor: const Color(0xFF12314F),
    trackOpacity: 0.55,
    progressColors: const [Color(0xFF42A5F5), Color(0xFF1E88E5)],
    glow: true,
    glowColor: const Color(0xFF42A5F5),
  ),
  _preset(
    id: 'material_red',
    name: 'Material Red',
    color: const Color(0xFFD32F2F),
    shadow: const ShadowSpec(
        color: Color(0xFF7F1D1D), blurRadius: 12, offsetY: 4, opacity: 0.35),
    trackColor: const Color(0xFF5C1010),
    progressColors: const [Color(0xFFEF5350), Color(0xFFD32F2F)],
  ),
  _preset(
    id: 'forest_green',
    name: 'Forest Green',
    color: const Color(0xFF2E7D32),
    opacity: 0.9,
    shadow: const ShadowSpec(
        color: Color(0xFF1B3B1D), blurRadius: 12, offsetY: 4, opacity: 0.35),
    trackColor: const Color(0xFF16351A),
    progressColors: const [Color(0xFF66BB6A), Color(0xFF2E7D32)],
  ),
  _preset(
    id: 'sunset_orange',
    name: 'Sunset Orange',
    color: const Color(0xFFF4511E),
    shadow: const ShadowSpec(
        color: Color(0xFFFFB020), blurRadius: 16, offsetY: 4, opacity: 0.4),
    trackColor: const Color(0xFF4E1A0A),
    progressColors: const [Color(0xFFF4511E), Color(0xFFFFB020)],
    glow: true,
    glowColor: const Color(0xFFFFB020),
    animationStyle: ThemeAnimationStyle.bouncy,
  ),
  _preset(
    id: 'purple_glass',
    name: 'Purple Glass',
    color: const Color(0xFF7C4DFF),
    opacity: 0.55,
    elevation: 2,
    border: const BorderSpec(
        width: 1.5, color: Color(0xFFFFFFFF), opacity: 0.3),
    shadow: const ShadowSpec(
        color: Color(0xFF4527A0), blurRadius: 18, offsetY: 6, opacity: 0.35),
    trackColor: const Color(0xFFFFFFFF),
    trackOpacity: 0.25,
    progressColors: const [Color(0xFFB388FF), Color(0xFF7C4DFF)],
    animationStyle: ThemeAnimationStyle.glass,
  ),
  _preset(
    id: 'frosted_glass',
    name: 'Frosted Glass',
    color: const Color(0xFFFFFFFF),
    opacity: 0.35,
    elevation: 2,
    border: const BorderSpec(
        width: 1.5, color: Color(0xFFFFFFFF), opacity: 0.5),
    shadow: const ShadowSpec(
        color: Color(0xFF90A4AE), blurRadius: 20, offsetY: 6, opacity: 0.3),
    trackColor: const Color(0xFFFFFFFF),
    trackOpacity: 0.3,
    progressColors: const [Color(0xFFFFFFFF)],
    animationStyle: ThemeAnimationStyle.glass,
  ),
  _preset(
    id: 'neon',
    name: 'Neon',
    color: const Color(0xFF0A0A0F),
    border: const BorderSpec(
        width: 1.5, color: Color(0xFF39FF14), opacity: 0.8),
    shadow: const ShadowSpec(
        color: Color(0xFF39FF14), blurRadius: 18, offsetY: 0, opacity: 0.5),
    iconColor: const Color(0xFF39FF14),
    trackColor: const Color(0xFF103310),
    progressColors: const [Color(0xFF39FF14)],
    glow: true,
    glowColor: const Color(0xFF39FF14),
    centerLabelColor: const Color(0xFF39FF14),
    animationStyle: ThemeAnimationStyle.snappy,
  ),
  _preset(
    id: 'cyber',
    name: 'Cyber',
    color: const Color(0xFF0D0221),
    border: const BorderSpec(
        width: 1.5, color: Color(0xFF00E5FF), opacity: 0.7),
    shadow: const ShadowSpec(
        color: Color(0xFF000000), blurRadius: 6, offsetY: 6, opacity: 0.6),
    iconColor: const Color(0xFF00E5FF),
    trackColor: const Color(0xFF1A0B3D),
    progressColors: const [Color(0xFF00E5FF), Color(0xFFFF2079)],
    glow: true,
    glowColor: const Color(0xFF00E5FF),
    animationStyle: ThemeAnimationStyle.snappy,
  ),
];

/// Free-tier preset ids (doc §6.4).
const Set<String> kFreeThemeIds = {
  'minimal_white',
  'amoled_black',
  'ocean_blue',
  'material_red',
};

ButtonThemeSpec get kDefaultTheme => kBuiltInThemes[2]; // Ocean Blue

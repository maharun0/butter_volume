import 'dart:ui';

/// Canonical button-theme model (doc §7.1). This mirrors the backend's
/// `themes.payload` JSON schema exactly — keep both in lockstep.
///
/// Pure Dart (`dart:ui` only) so the overlay engine can import it within its
/// slim import budget (doc §13.1).

Color colorFromHex(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

String colorToHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

enum ButtonShape {
  circle('circle'),
  squircle('squircle'),
  roundedSquare('rounded_square');

  const ButtonShape(this.id);
  final String id;

  static ButtonShape fromId(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => ButtonShape.circle);
}

enum ThemeAnimationStyle {
  smooth('smooth'),
  snappy('snappy'),
  bouncy('bouncy'),
  glass('glass');

  const ThemeAnimationStyle(this.id);
  final String id;

  static ThemeAnimationStyle fromId(String id) =>
      values.firstWhere((s) => s.id == id, orElse: () => ThemeAnimationStyle.smooth);
}

class BorderSpec {
  const BorderSpec({
    required this.width,
    required this.color,
    required this.opacity,
  });

  final double width;
  final Color color;
  final double opacity;

  BorderSpec copyWith({double? width, Color? color, double? opacity}) =>
      BorderSpec(
        width: width ?? this.width,
        color: color ?? this.color,
        opacity: opacity ?? this.opacity,
      );

  Map<String, dynamic> toJson() => {
        'width': width,
        'color': colorToHex(color),
        'opacity': opacity,
      };

  factory BorderSpec.fromJson(Map<String, dynamic> json) => BorderSpec(
        width: (json['width'] as num).toDouble(),
        color: colorFromHex(json['color'] as String),
        opacity: (json['opacity'] as num).toDouble(),
      );
}

class ShadowSpec {
  const ShadowSpec({
    required this.color,
    required this.blurRadius,
    required this.offsetY,
    required this.opacity,
  });

  final Color color;
  final double blurRadius;
  final double offsetY;
  final double opacity;

  ShadowSpec copyWith(
          {Color? color, double? blurRadius, double? offsetY, double? opacity}) =>
      ShadowSpec(
        color: color ?? this.color,
        blurRadius: blurRadius ?? this.blurRadius,
        offsetY: offsetY ?? this.offsetY,
        opacity: opacity ?? this.opacity,
      );

  Map<String, dynamic> toJson() => {
        'color': colorToHex(color),
        'blurRadius': blurRadius,
        'offsetY': offsetY,
        'opacity': opacity,
      };

  factory ShadowSpec.fromJson(Map<String, dynamic> json) => ShadowSpec(
        color: colorFromHex(json['color'] as String),
        blurRadius: (json['blurRadius'] as num).toDouble(),
        offsetY: (json['offsetY'] as num).toDouble(),
        opacity: (json['opacity'] as num).toDouble(),
      );
}

class ButtonStyleSpec {
  const ButtonStyleSpec({
    required this.size,
    required this.shape,
    required this.color,
    required this.opacity,
    required this.elevation,
    required this.border,
    required this.shadow,
    required this.icon,
    required this.iconSize,
    required this.iconColor,
  });

  /// Diameter in dp (40–72, doc §8.6).
  final double size;
  final ButtonShape shape;
  final Color color;
  final double opacity;
  final double elevation;
  final BorderSpec border;
  final ShadowSpec shadow;

  /// Key into [kThemeIcons] (doc §7.1: curated Material Symbols).
  final String icon;
  final double iconSize;
  final Color iconColor;

  ButtonStyleSpec copyWith({
    double? size,
    ButtonShape? shape,
    Color? color,
    double? opacity,
    double? elevation,
    BorderSpec? border,
    ShadowSpec? shadow,
    String? icon,
    double? iconSize,
    Color? iconColor,
  }) =>
      ButtonStyleSpec(
        size: size ?? this.size,
        shape: shape ?? this.shape,
        color: color ?? this.color,
        opacity: opacity ?? this.opacity,
        elevation: elevation ?? this.elevation,
        border: border ?? this.border,
        shadow: shadow ?? this.shadow,
        icon: icon ?? this.icon,
        iconSize: iconSize ?? this.iconSize,
        iconColor: iconColor ?? this.iconColor,
      );

  Map<String, dynamic> toJson() => {
        'size': size,
        'shape': shape.id,
        'color': colorToHex(color),
        'opacity': opacity,
        'elevation': elevation,
        'border': border.toJson(),
        'shadow': shadow.toJson(),
        'icon': icon,
        'iconSize': iconSize,
        'iconColor': colorToHex(iconColor),
      };

  factory ButtonStyleSpec.fromJson(Map<String, dynamic> json) =>
      ButtonStyleSpec(
        size: (json['size'] as num).toDouble(),
        shape: ButtonShape.fromId(json['shape'] as String),
        color: colorFromHex(json['color'] as String),
        opacity: (json['opacity'] as num).toDouble(),
        elevation: (json['elevation'] as num).toDouble(),
        border: BorderSpec.fromJson(json['border'] as Map<String, dynamic>),
        shadow: ShadowSpec.fromJson(json['shadow'] as Map<String, dynamic>),
        icon: json['icon'] as String,
        iconSize: (json['iconSize'] as num).toDouble(),
        iconColor: colorFromHex(json['iconColor'] as String),
      );
}

class RadialStyleSpec {
  const RadialStyleSpec({
    required this.trackColor,
    required this.trackOpacity,
    required this.progressColors,
    required this.strokeWidth,
    required this.glow,
    required this.glowColor,
    required this.centerLabelColor,
  });

  final Color trackColor;
  final double trackOpacity;

  /// 1–2 colors; two form a sweep gradient (doc §7.1).
  final List<Color> progressColors;
  final double strokeWidth;
  final bool glow;
  final Color glowColor;
  final Color centerLabelColor;

  RadialStyleSpec copyWith({
    Color? trackColor,
    double? trackOpacity,
    List<Color>? progressColors,
    double? strokeWidth,
    bool? glow,
    Color? glowColor,
    Color? centerLabelColor,
  }) =>
      RadialStyleSpec(
        trackColor: trackColor ?? this.trackColor,
        trackOpacity: trackOpacity ?? this.trackOpacity,
        progressColors: progressColors ?? this.progressColors,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        glow: glow ?? this.glow,
        glowColor: glowColor ?? this.glowColor,
        centerLabelColor: centerLabelColor ?? this.centerLabelColor,
      );

  Map<String, dynamic> toJson() => {
        'trackColor': colorToHex(trackColor),
        'trackOpacity': trackOpacity,
        'progressColors': progressColors.map(colorToHex).toList(),
        'strokeWidth': strokeWidth,
        'glow': glow,
        'glowColor': colorToHex(glowColor),
        'centerLabelColor': colorToHex(centerLabelColor),
      };

  factory RadialStyleSpec.fromJson(Map<String, dynamic> json) =>
      RadialStyleSpec(
        trackColor: colorFromHex(json['trackColor'] as String),
        trackOpacity: (json['trackOpacity'] as num).toDouble(),
        progressColors: (json['progressColors'] as List)
            .map((c) => colorFromHex(c as String))
            .toList(),
        strokeWidth: (json['strokeWidth'] as num).toDouble(),
        glow: json['glow'] as bool,
        glowColor: colorFromHex(json['glowColor'] as String),
        centerLabelColor: colorFromHex(json['centerLabelColor'] as String),
      );
}

class ButtonThemeSpec {
  const ButtonThemeSpec({
    this.schemaVersion = 1,
    required this.id,
    required this.name,
    required this.isBuiltIn,
    this.basedOn,
    required this.button,
    required this.radial,
    required this.animationStyle,
    required this.updatedAt,
  });

  final int schemaVersion;
  final String id;
  final String name;
  final bool isBuiltIn;
  final String? basedOn;
  final ButtonStyleSpec button;
  final RadialStyleSpec radial;
  final ThemeAnimationStyle animationStyle;
  final DateTime updatedAt;

  ButtonThemeSpec copyWith({
    String? id,
    String? name,
    bool? isBuiltIn,
    String? basedOn,
    ButtonStyleSpec? button,
    RadialStyleSpec? radial,
    ThemeAnimationStyle? animationStyle,
    DateTime? updatedAt,
  }) =>
      ButtonThemeSpec(
        schemaVersion: schemaVersion,
        id: id ?? this.id,
        name: name ?? this.name,
        isBuiltIn: isBuiltIn ?? this.isBuiltIn,
        basedOn: basedOn ?? this.basedOn,
        button: button ?? this.button,
        radial: radial ?? this.radial,
        animationStyle: animationStyle ?? this.animationStyle,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'isBuiltIn': isBuiltIn,
        if (basedOn != null) 'basedOn': basedOn,
        'button': button.toJson(),
        'radial': radial.toJson(),
        'animationStyle': animationStyle.id,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory ButtonThemeSpec.fromJson(Map<String, dynamic> json) =>
      ButtonThemeSpec(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        id: json['id'] as String,
        name: json['name'] as String,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
        basedOn: json['basedOn'] as String?,
        button: ButtonStyleSpec.fromJson(json['button'] as Map<String, dynamic>),
        radial: RadialStyleSpec.fromJson(json['radial'] as Map<String, dynamic>),
        animationStyle:
            ThemeAnimationStyle.fromId(json['animationStyle'] as String? ?? 'smooth'),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
      );
}

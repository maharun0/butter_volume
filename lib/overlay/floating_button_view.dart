import 'package:flutter/material.dart';

import '../features/themes/domain/button_theme_spec.dart';
import '../features/themes/domain/theme_icons.dart';

/// The idle floating button rendered from a [ButtonThemeSpec]. Reused by the
/// main app for live previews and theme-gallery cards (doc §6.2.3, §8.7) —
/// previews are guaranteed accurate because they run this exact widget.
class FloatingButtonView extends StatelessWidget {
  const FloatingButtonView({super.key, required this.theme, this.scale = 1.0});

  final ButtonThemeSpec theme;

  /// Render scale (gallery cards render at < 1).
  final double scale;

  @override
  Widget build(BuildContext context) {
    final b = theme.button;
    final size = b.size * scale;
    final borderRadius = switch (b.shape) {
      ButtonShape.circle => BorderRadius.circular(size / 2),
      ButtonShape.squircle => BorderRadius.circular(size * 0.42),
      ButtonShape.roundedSquare => BorderRadius.circular(size * 0.25),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: b.color.withValues(alpha: b.opacity),
        borderRadius: borderRadius,
        border: b.border.width > 0
            ? Border.all(
                width: b.border.width * scale,
                color: b.border.color.withValues(alpha: b.border.opacity),
              )
            : null,
        boxShadow: b.shadow.opacity > 0 && b.shadow.blurRadius > 0
            ? [
                BoxShadow(
                  color: b.shadow.color.withValues(alpha: b.shadow.opacity),
                  blurRadius: b.shadow.blurRadius * scale,
                  offset: Offset(0, b.shadow.offsetY * scale),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          themeIcon(b.icon),
          size: b.iconSize * scale,
          color: b.iconColor,
        ),
      ),
    );
  }
}

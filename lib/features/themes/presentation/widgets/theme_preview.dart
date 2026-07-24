import 'package:flutter/material.dart';

import '../../../../overlay/radial_controller_view.dart';
import '../../domain/button_theme_spec.dart';

/// Accurate mini preview — renders the real overlay painter (doc §8.7:
/// "no screenshots; always accurate").
class ThemePreview extends StatelessWidget {
  const ThemePreview({
    super.key,
    required this.theme,
    this.expanded = false,
    this.percent = 0.65,
    this.size = 140,
  });

  final ButtonThemeSpec theme;

  /// false = idle button, true = open radial.
  final bool expanded;
  final double percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final paintSize = theme.button.size * 2.4 + 44;
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        child: SizedBox(
          width: paintSize,
          height: paintSize,
          child: CustomPaint(
            painter: RadialControllerPainter(
              theme: theme,
              morphT: expanded ? 1 : 0,
              percent: percent,
              center: Offset(paintSize / 2, paintSize / 2),
              streamId: 'media',
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/themes/domain/button_theme_spec.dart';
import '../features/themes/domain/theme_icons.dart';

/// Paints the button ⇄ radial morph as one continuous surface (doc §6.2.2):
/// at `morphT = 0` only the button disc; as it grows, the track and volume
/// arc sweep out of the disc edge.
class RadialControllerPainter extends CustomPainter {
  RadialControllerPainter({
    required this.theme,
    required this.morphT,
    required this.percent,
    required this.center,
    required this.streamId,
    this.showStreamChip = false,
  });

  final ButtonThemeSpec theme;

  /// 0 = idle button, 1 = fully open radial.
  final double morphT;
  final double percent;
  final Offset center;
  final String streamId;
  final bool showStreamChip;

  static const _startAngle = -math.pi / 2; // 12 o'clock, clockwise (doc §6.2.2)

  IconData get _streamIcon => switch (streamId) {
        'ring' => Icons.notifications_active_rounded,
        'alarm' => Icons.alarm_rounded,
        'notification' => Icons.notifications_rounded,
        'call' => Icons.phone_in_talk_rounded,
        _ => Icons.music_note_rounded,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final b = theme.button;
    final r = theme.radial;
    final buttonRadius = b.size / 2;
    final ringRadius = b.size * 1.2 - r.strokeWidth / 2 - 2;
    final arcRadius =
        buttonRadius + (ringRadius - buttonRadius) * Curves.easeOut.transform(morphT);

    // -- shadow --
    if (b.shadow.opacity > 0 && b.shadow.blurRadius > 0) {
      final shadowPaint = Paint()
        ..color = b.shadow.color.withValues(alpha: b.shadow.opacity)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, b.shadow.blurRadius * 0.6);
      canvas.drawPath(
        _shapePath(center.translate(0, b.shadow.offsetY), buttonRadius),
        shadowPaint,
      );
    }

    // -- track ring --
    if (morphT > 0.05) {
      final trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.strokeWidth
        ..color = r.trackColor.withValues(alpha: r.trackOpacity * morphT);
      canvas.drawCircle(center, arcRadius, trackPaint);

      // -- progress arc (with optional glow) --
      final sweep = percent * 2 * math.pi;
      final rect = Rect.fromCircle(center: center, radius: arcRadius);
      final colors = r.progressColors.length >= 2
          ? r.progressColors
          : [r.progressColors.first, r.progressColors.first];
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: colors,
          transform: const GradientRotation(_startAngle),
        ).createShader(rect);

      if (r.glow) {
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r.strokeWidth * 2.2
          ..strokeCap = StrokeCap.round
          ..color = r.glowColor.withValues(alpha: 0.45 * morphT)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        if (sweep > 0.01) {
          canvas.drawArc(rect, _startAngle, sweep, false, glowPaint);
        }
      }
      if (sweep > 0.01) {
        canvas.drawArc(rect, _startAngle, sweep, false, arcPaint);
      }
    }

    // -- button disc --
    final disc = Paint()..color = b.color.withValues(alpha: b.opacity);
    canvas.drawPath(_shapePath(center, buttonRadius), disc);
    if (b.border.width > 0) {
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = b.border.width
        ..color = b.border.color.withValues(alpha: b.border.opacity);
      canvas.drawPath(_shapePath(center, buttonRadius), borderPaint);
    }

    // -- center content: icon fades out, % label fades in --
    final iconAlpha = (1 - morphT * 2).clamp(0.0, 1.0);
    final labelAlpha = (morphT * 2 - 1).clamp(0.0, 1.0);
    if (iconAlpha > 0) {
      _paintIcon(
        canvas,
        themeIcon(b.icon),
        center,
        b.iconSize,
        b.iconColor.withValues(alpha: iconAlpha),
      );
    }
    if (labelAlpha > 0) {
      final label = TextPainter(
        text: TextSpan(
          text: '${(percent * 100).round()}%',
          style: TextStyle(
            color: r.centerLabelColor.withValues(alpha: labelAlpha),
            fontSize: b.size * 0.30,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        center - Offset(label.width / 2, label.height / 2 + b.size * 0.08),
      );
      _paintIcon(
        canvas,
        _streamIcon,
        center.translate(0, b.size * 0.22),
        b.size * 0.20,
        r.centerLabelColor.withValues(alpha: labelAlpha * 0.85),
      );
    }

    // -- stream chip at the bottom of the ring (doc §6.2.2) --
    if (showStreamChip && morphT > 0.9) {
      final chipCenter = center.translate(0, arcRadius + r.strokeWidth + 10);
      canvas.drawCircle(
        chipCenter,
        11,
        Paint()..color = b.color.withValues(alpha: 0.9),
      );
      _paintIcon(canvas, _streamIcon, chipCenter, 13, b.iconColor);
    }
  }

  Path _shapePath(Offset c, double radius) {
    final rect = Rect.fromCircle(center: c, radius: radius);
    return switch (theme.button.shape) {
      ButtonShape.circle => Path()..addOval(rect),
      ButtonShape.squircle => Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.84))),
      ButtonShape.roundedSquare => Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.5))),
    };
  }

  void _paintIcon(
      Canvas canvas, IconData icon, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(RadialControllerPainter old) =>
      old.morphT != morphT ||
      old.percent != percent ||
      old.theme != theme ||
      old.center != center ||
      old.streamId != streamId ||
      old.showStreamChip != showStreamChip;
}

/// Curve/duration per theme animation style (doc §7.1 animationStyle).
({Duration expand, Duration collapse, Curve expandCurve, Curve collapseCurve})
    morphSpecFor(ThemeAnimationStyle style) => switch (style) {
          ThemeAnimationStyle.smooth => (
              expand: const Duration(milliseconds: 240),
              collapse: const Duration(milliseconds: 200),
              expandCurve: Curves.easeOutBack,
              collapseCurve: Curves.easeOutCubic,
            ),
          ThemeAnimationStyle.snappy => (
              expand: const Duration(milliseconds: 170),
              collapse: const Duration(milliseconds: 140),
              expandCurve: Curves.easeOutCubic,
              collapseCurve: Curves.easeOutCubic,
            ),
          ThemeAnimationStyle.bouncy => (
              expand: const Duration(milliseconds: 320),
              collapse: const Duration(milliseconds: 220),
              expandCurve: Curves.elasticOut,
              collapseCurve: Curves.easeOutBack,
            ),
          ThemeAnimationStyle.glass => (
              expand: const Duration(milliseconds: 320),
              collapse: const Duration(milliseconds: 260),
              expandCurve: Curves.easeInOutCubic,
              collapseCurve: Curves.easeInOutCubic,
            ),
        };

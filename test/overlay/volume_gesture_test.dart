import 'package:butter_volume/overlay/volume_gesture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('volumePercentForDrag (doc §6.2.2)', () {
    test('upward drag increases volume', () {
      final result = volumePercentForDrag(
        startPercent: 0.5,
        dyDp: -120, // up = negative dy
        screenHeightDp: 800,
        sensitivity: 1.0,
      );
      expect(result, greaterThan(0.5));
      // Full range maps to 60% of screen: 120/480 = 0.25 delta.
      expect(result, closeTo(0.75, 1e-9));
    });

    test('downward drag decreases volume', () {
      final result = volumePercentForDrag(
        startPercent: 0.5,
        dyDp: 240,
        screenHeightDp: 800,
        sensitivity: 1.0,
      );
      expect(result, closeTo(0.0, 1e-9));
    });

    test('clamps to 0..1', () {
      expect(
        volumePercentForDrag(
            startPercent: 0.9, dyDp: -999, screenHeightDp: 800, sensitivity: 1),
        1.0,
      );
      expect(
        volumePercentForDrag(
            startPercent: 0.1, dyDp: 999, screenHeightDp: 800, sensitivity: 1),
        0.0,
      );
    });

    test('sensitivity scales the delta', () {
      final gentle = volumePercentForDrag(
          startPercent: 0.5, dyDp: -100, screenHeightDp: 800, sensitivity: 0.5);
      final sharp = volumePercentForDrag(
          startPercent: 0.5, dyDp: -100, screenHeightDp: 800, sensitivity: 1.5);
      expect(sharp - 0.5, closeTo((gentle - 0.5) * 3, 1e-9));
    });

    test('degenerate screen height is safe', () {
      expect(
        volumePercentForDrag(
            startPercent: 0.4, dyDp: -50, screenHeightDp: 0, sensitivity: 1),
        0.4,
      );
    });
  });

  group('stepFor (haptic ticks)', () {
    test('maps percent to discrete steps', () {
      expect(stepFor(0.0, 15), 0);
      expect(stepFor(1.0, 15), 15);
      expect(stepFor(0.5, 15), 8); // round(7.5)
    });
  });

  group('streamCycleSteps (stream chip)', () {
    test('one step per threshold', () {
      expect(streamCycleSteps(0), 0);
      expect(streamCycleSteps(55), 0);
      expect(streamCycleSteps(56), 1);
      expect(streamCycleSteps(112), 2);
    });
  });
}

/// Pure gesture math (doc §6.2.2): vertical drag → volume percent.
/// Kept dependency-free so it is trivially unit-tested (doc §14.3).
library;

/// `Δvolume = −Δy × sensitivity`, where full range maps to 60 % of screen
/// height at sensitivity 1.0.
double volumePercentForDrag({
  required double startPercent,
  required double dyDp,
  required double screenHeightDp,
  required double sensitivity,
}) {
  if (screenHeightDp <= 0) return startPercent.clamp(0.0, 1.0);
  final range = 0.6 * screenHeightDp;
  final delta = (-dyDp / range) * sensitivity;
  return (startPercent + delta).clamp(0.0, 1.0);
}

/// Discrete step index for haptic ticks (doc §6.2.2).
int stepFor(double percent, int maxSteps) =>
    (percent.clamp(0.0, 1.0) * maxSteps).round();

/// Stream cycling from horizontal travel: one step per [thresholdDp] of
/// cumulative horizontal drag (doc §6.2.2 stream chip).
int streamCycleSteps(double dxDp, {double thresholdDp = 56}) =>
    dxDp ~/ thresholdDp;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/platform/channel_names.dart';
import '../features/floating_button/domain/overlay_behavior.dart';
import '../features/themes/domain/button_theme_spec.dart';
import '../features/themes/domain/presets.dart';
import 'volume_gesture.dart';

/// Radial state machine (doc §6.2.2):
/// idle → expanding → active → collapsing → idle
enum RadialPhase { idle, expanding, active, collapsing }

/// Engine-B state controller. Deliberately a [ChangeNotifier] — the overlay
/// engine keeps its import budget slim (doc §13.1); Riverpod stays in the
/// main app.
class OverlayUiController extends ChangeNotifier {
  OverlayUiController() {
    _init();
  }

  static const _window = MethodChannel(ChannelNames.overlayWindow);
  static const _events = EventChannel(ChannelNames.overlayEvents);
  static const _volume = MethodChannel(ChannelNames.volume);

  ButtonThemeSpec theme = kDefaultTheme;
  OverlayBehavior behavior = const OverlayBehavior();

  RadialPhase phase = RadialPhase.idle;

  /// Geometry from the native window (dp == logical px).
  Offset ringCenter = Offset.zero;
  Size windowSize = Size.zero;
  double screenHeightDp = 800;

  /// Volume state.
  String activeStream = 'media';
  double volumePercent = 0.5;
  int maxSteps = 15;
  double _dragStartPercent = 0.5;
  int _lastTickStep = -1;
  int _lastStreamCycle = 0;

  /// Post-release % badge (doc §6.2.2 step 4).
  bool showBadge = false;

  /// Tap micro-acknowledge pulse (doc §6.2.1).
  int tapPulse = 0;

  static const List<String> _streamOrder = [
    'media',
    'ring',
    'alarm',
    'notification',
    'call',
  ];

  Future<void> _init() async {
    try {
      final state =
          await _window.invokeMapMethod<String, dynamic>('getState');
      if (state != null) _applyState(state);
    } catch (_) {
      // Defaults stand; a styleChanged event will correct us.
    }
    _events.receiveBroadcastStream().listen(_onEvent);
    notifyListeners();
  }

  void _applyState(Map<String, dynamic> state) {
    final themeJson = state['themeJson'] as String?;
    if (themeJson != null && themeJson.isNotEmpty) {
      try {
        theme = ButtonThemeSpec.fromJson(
            jsonDecode(themeJson) as Map<String, dynamic>);
      } catch (_) {}
    }
    final behaviorJson = state['behaviorJson'] as String?;
    if (behaviorJson != null && behaviorJson.isNotEmpty) {
      try {
        behavior = OverlayBehavior.fromJson(
            jsonDecode(behaviorJson) as Map<String, dynamic>);
      } catch (_) {}
    }
    activeStream = behavior.stream;
    volumePercent =
        (state['volumePercent'] as num?)?.toDouble() ?? volumePercent;
    maxSteps = (state['maxSteps'] as num?)?.toInt() ?? maxSteps;
  }

  void _onEvent(dynamic raw) {
    final event = (raw as Map).cast<String, dynamic>();
    switch (event['type'] as String?) {
      case 'radialOpen':
        ringCenter = Offset(
          (event['centerX'] as num).toDouble(),
          (event['centerY'] as num).toDouble(),
        );
        windowSize = Size(
          (event['windowW'] as num).toDouble(),
          (event['windowH'] as num).toDouble(),
        );
        screenHeightDp =
            (event['screenH'] as num?)?.toDouble() ?? screenHeightDp;
        volumePercent =
            (event['volumePercent'] as num?)?.toDouble() ?? volumePercent;
        maxSteps = (event['maxSteps'] as num?)?.toInt() ?? maxSteps;
        activeStream = behavior.stream;
        _dragStartPercent = volumePercent;
        _lastTickStep = stepFor(volumePercent, maxSteps);
        _lastStreamCycle = 0;
        phase = RadialPhase.expanding;
        notifyListeners();

      case 'drag':
        if (phase == RadialPhase.expanding) phase = RadialPhase.active;
        if (phase != RadialPhase.active) return;
        _handleDrag(
          (event['dx'] as num).toDouble(),
          (event['dy'] as num).toDouble(),
        );

      case 'release':
        if (phase == RadialPhase.expanding || phase == RadialPhase.active) {
          phase = RadialPhase.collapsing;
          notifyListeners();
        }

      case 'cancel':
        phase = RadialPhase.idle;
        unawaited(_window.invokeMethod<void>('collapsed'));
        notifyListeners();

      case 'tapped':
        tapPulse++;
        notifyListeners();

      case 'styleChanged':
        _applyState(event);
        notifyListeners();
    }
  }

  void _handleDrag(double dx, double dy) {
    // Stream cycling from horizontal travel (doc §6.2.2).
    final cycle = streamCycleSteps(dx);
    if (cycle != _lastStreamCycle) {
      _cycleStream(cycle - _lastStreamCycle);
      _lastStreamCycle = cycle;
      return;
    }

    volumePercent = volumePercentForDrag(
      startPercent: _dragStartPercent,
      dyDp: dy,
      screenHeightDp: screenHeightDp,
      sensitivity: behavior.sensitivity,
    );

    final step = stepFor(volumePercent, maxSteps);
    if (step != _lastTickStep) {
      _lastTickStep = step;
      unawaited(_window.invokeMethod<void>('haptic', {'kind': 'tick'}));
    }

    // Applied natively; fire-and-forget keeps render latency at zero.
    unawaited(_volume.invokeMethod<void>('setPercent', {
      'stream': activeStream,
      'percent': volumePercent,
    }));
    notifyListeners();
  }

  Future<void> _cycleStream(int delta) async {
    final index = _streamOrder.indexOf(activeStream);
    final next = _streamOrder[
        (index + delta % _streamOrder.length + _streamOrder.length) %
            _streamOrder.length];
    activeStream = next;
    try {
      volumePercent = await _volume
              .invokeMethod<double>('getPercent', {'stream': next}) ??
          volumePercent;
      maxSteps =
          await _volume.invokeMethod<int>('maxSteps', {'stream': next}) ??
              maxSteps;
    } catch (_) {}
    _dragStartPercent = volumePercent;
    _lastTickStep = stepFor(volumePercent, maxSteps);
    notifyListeners();
  }

  /// Called by the view when the collapse animation completes.
  void onCollapseAnimationDone() {
    if (phase != RadialPhase.collapsing) return;
    phase = RadialPhase.idle;
    showBadge = true;
    notifyListeners();
    unawaited(_window.invokeMethod<void>('collapsed'));
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      showBadge = false;
      notifyListeners();
    });
  }
}

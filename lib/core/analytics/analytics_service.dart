import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../error/log.dart';

/// One analytics event (doc §17 canonical contract).
class AnalyticsEvent {
  AnalyticsEvent(this.name, this.props) : clientTs = DateTime.now().toUtc();

  final String name;
  final Map<String, Object?> props;
  final DateTime clientTs;

  Map<String, Object?> toJson() => {
        'name': name,
        'client_ts': clientTs.toIso8601String(),
        'props': props,
      };
}

/// Pluggable transport — M5 provides the API sender
/// (`POST /v1/analytics/events`); until then events queue in memory.
typedef AnalyticsSender = Future<bool> Function(List<AnalyticsEvent> batch);

/// Thin first-party pipeline (doc §17): local queue → batched send,
/// fire-and-forget, silent on failure. No PII by contract.
class AnalyticsService {
  AnalyticsService(this._enabled, [this._sender]);

  static const int _maxQueue = 500;
  static const int _batchMax = 50;

  final bool Function() _enabled;
  AnalyticsSender? _sender;
  final Queue<AnalyticsEvent> _queue = Queue();
  bool _flushing = false;

  /// M5 attaches the network sender once the API client exists.
  set sender(AnalyticsSender? s) => _sender = s;

  void track(String name, [Map<String, Object?> props = const {}]) {
    if (!_enabled()) return;
    _queue.add(AnalyticsEvent(name, props));
    while (_queue.length > _maxQueue) {
      _queue.removeFirst(); // drop oldest — analytics must never grow unbounded
    }
    Log.d('analytics: $name $props');
    if (_queue.length >= _batchMax) {
      flush();
    }
  }

  Future<void> flush() async {
    final sender = _sender;
    if (sender == null || _flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        final batch = <AnalyticsEvent>[];
        while (batch.length < _batchMax && _queue.isNotEmpty) {
          batch.add(_queue.removeFirst());
        }
        final ok = await sender(batch);
        if (!ok) {
          // Put the batch back and stop — retry on the next flush.
          for (final e in batch.reversed) {
            _queue.addFirst(e);
          }
          break;
        }
      }
    } catch (_) {
      // Silent by design (doc §17 fire-and-forget).
    } finally {
      _flushing = false;
    }
  }
}

final analyticsProvider = Provider<AnalyticsService>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return AnalyticsService(() => settings.analyticsEnabled);
});

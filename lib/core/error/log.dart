import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Leveled logging (doc §14.2): verbose in debug, warning+ in release.
/// Sentry breadcrumbs are attached by the Sentry integration when enabled.
abstract final class Log {
  static void d(String message, {String tag = 'bv'}) {
    if (kDebugMode) developer.log(message, name: tag, level: 500);
  }

  static void i(String message, {String tag = 'bv'}) {
    if (kDebugMode) developer.log(message, name: tag, level: 800);
  }

  static void w(String message, {String tag = 'bv', Object? error}) {
    developer.log(message, name: tag, level: 900, error: error);
  }

  static void e(String message,
      {String tag = 'bv', Object? error, StackTrace? stackTrace}) {
    developer.log(message,
        name: tag, level: 1000, error: error, stackTrace: stackTrace);
  }
}

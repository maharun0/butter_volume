import 'log.dart';

/// Crash-reporting seam (doc §14.1 targets Sentry).
///
/// NOTE: `sentry_flutter` currently fails to compile on this project's
/// toolchain (it pins Kotlin languageVersion 1.6; AGP 9 / Kotlin 2.3 refuse
/// it). Until Sentry ships a compatible release, this logs locally; swap the
/// body for `Sentry.captureException` when the dependency returns.
abstract final class ErrorReporter {
  static Future<void> report(Object error, StackTrace? stackTrace,
      {String? hint}) async {
    Log.e(hint ?? 'Unhandled error', error: error, stackTrace: stackTrace);
  }
}

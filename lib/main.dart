import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/di/providers.dart';
import 'core/error/error_reporter.dart';

Future<void> main() async {
  await runZonedGuarded(_run, (error, stack) {
    unawaited(ErrorReporter.report(error, stack, hint: 'Uncaught zone error'));
  });
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(ErrorReporter.report(details.exception, details.stack,
        hint: 'Flutter framework error'));
  };

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ButterVolumeApp(),
    ),
  );
}

import 'package:flutter/material.dart';

import 'overlay/overlay_app.dart';

/// Entrypoint for FlutterEngine B, spawned by `OverlayService` via
/// `FlutterEngineGroup` (doc §3.3). Import budget: this file's transitive
/// imports must stay slim — no dio, billing, or router (doc §13.1).
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

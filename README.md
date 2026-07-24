# Butter Volume

> Volume, smooth as butter.

A premium Android utility: a floating, movable, deeply customizable volume
button that long-presses into a radial volume controller — plus an independent
notification-based volume slider.

Full product & technical design: [`docs/flutter-app-documentation.md`](docs/flutter-app-documentation.md)
· Backend spec: [`docs/fastapi-backend-documentation.md`](docs/fastapi-backend-documentation.md)

## Architecture at a glance

- **Main app** — Flutter (Riverpod 2, go_router, Material 3, dynamic color).
- **Floating button** — custom Kotlin `TYPE_APPLICATION_OVERLAY` window hosting
  a second FlutterEngine (spawned from a shared `FlutterEngineGroup`); drag is
  fully native, the radial UI renders in Dart (`lib/overlay/`).
- **Notification slider** — Kotlin foreground service with custom RemoteViews
  (mute / − / + / preset chips; Android forbids interactive sliders in
  notifications).
- **Free tier** — each feature runs 12 h per activation via AlarmManager;
  premium ($0.67/mo or $7 lifetime) removes timers. Purchases are verified
  server-side; premium works offline via a signed entitlement token.
- **Backend clients** (device auth, entitlements, config, flags, analytics)
  degrade gracefully — the app is fully functional with no backend at all.

## Building

```sh
flutter pub get
flutter analyze
flutter test
flutter run --flavor dev --dart-define-from-file=env/dev.json
```

Flavors: `dev` (`app.buttervolume.android.dev`, AdMob test IDs) and `prod`.

Useful debug defines:

| Define | Effect |
|---|---|
| `DEBUG_PREMIUM=true` | Treat the user as premium (no billing needed) |
| `DEBUG_SHORT_TIMER=true` | Free-tier sessions last 2 minutes instead of 12 h |
| `SENTRY_DSN=…` | Reserved — see `core/error/error_reporter.dart` |

## Testing the core loops on a device/emulator

1. Grant "Display over other apps" → toggle **Floating button** on Home.
2. Drag the button (native, snaps to edges); long-press → radial controller;
   slide vertically to change volume; slide horizontally to switch streams.
3. Toggle **Notification slider** → check the shade (−/+/mute/presets).
4. With `DEBUG_SHORT_TIMER=true`, watch the free session expire after 2 min
   and the reopen loop kick in.

## Repository layout

```
lib/            Flutter app (feature-first; lib/overlay = engine-B UI only)
android/…/app/buttervolume/android/   Kotlin: overlay, notification, timers
docs/           Product & backend design documents
env/            Per-flavor dart-defines
test/           Unit + widget tests (fakes for all platform channels)
```

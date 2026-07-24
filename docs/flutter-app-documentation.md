# Butter Volume — Flutter Application Documentation

**Version:** 1.0
**Date:** 2026-07-23
**Status:** Approved for development
**Platform:** Android (iOS-aware architecture, no iOS work in v1)
**Companion document:** `fastapi-backend-documentation.md`

---

## Table of Contents

1. [Product Vision & Design Philosophy](#1-product-vision--design-philosophy)
2. [Branding](#2-branding)
3. [Architecture Overview](#3-architecture-overview)
4. [Technology Decisions & Rationale](#4-technology-decisions--rationale)
5. [Project & Package Structure](#5-project--package-structure)
6. [Feature Specifications](#6-feature-specifications)
7. [Theme System](#7-theme-system)
8. [Screens & UI Flow](#8-screens--ui-flow)
9. [Animation Catalog](#9-animation-catalog)
10. [Settings Catalog](#10-settings-catalog)
11. [Monetization](#11-monetization)
12. [Permissions](#12-permissions)
13. [Technical Considerations](#13-technical-considerations)
14. [Error Handling, Logging & Testing](#14-error-handling-logging--testing)
15. [CI/CD & Build Flavors](#15-cicd--build-flavors)
16. [Play Store Launch Strategy](#16-play-store-launch-strategy)
17. [Analytics](#17-analytics)
18. [Implementation Roadmap](#18-implementation-roadmap)

---

## 1. Product Vision & Design Philosophy

Butter Volume is a **premium Android utility** that puts volume control anywhere on screen: a floating, movable button that morphs into a radial volume controller on long-press, plus an independent notification-based volume slider.

### 1.1 Design principles

| Principle | What it means in practice |
|---|---|
| **Native feel** | Material Design 3 everywhere; dynamic color on Android 12+; respects system light/dark; no custom chrome that fights the OS. |
| **Minimal** | One primary feature per screen. No dashboards, no badges, no gamification. Whitespace is a feature. |
| **Premium motion** | Every state change animates. Spring curves, not linear. Nothing "pops" into existence — things grow, morph, and settle. |
| **Lightweight** | Cold start < 1.5 s, overlay memory < 40 MB, zero jank at 120 Hz. The overlay must never make the phone feel slower. |
| **Respectful monetization** | Ads only at app open, never during use. The free tier is genuinely useful (12-hour sessions). |
| **Customizable, not complicated** | Deep customization lives behind a clean surface: presets first, sliders second, raw values last. |

### 1.2 Non-goals (v1)

- No equalizer, no audio effects, no per-app volume.
- No home-screen widgets (roadmap).
- No tablets-first layouts (works, but phone-first).
- No iOS (architecture keeps platform code isolated so iOS can be added later without rewrites).

---

## 2. Branding

### 2.1 Name

**Butter Volume** — the confirmed product name. "Butter" communicates the core promise: *smoothness*. It is short, memorable, brandable, and pairs naturally with the marketing line below. Package ID: `app.buttervolume.android` (replace the scaffold's `com.example.butter_volume` before first release — the applicationId is permanent on Play).

Alternates considered (kept for reference only): *Orbi Volume*, *Flow Volume*, *Halo Volume*, *VolumeDot*.

### 2.2 Slogan

> **"Volume, smooth as butter."**

Secondary lines: "Your volume, anywhere." / "One button. Total control."

### 2.3 Logo direction

- A **soft rounded-square (squircle) app icon** containing a circle with a partial arc around it — the floating button + radial controller in one glyph.
- Gradient from warm gold (`#FFC94D`, butter) into deep indigo (`#4F46E5`) for the premium accent.
- Monochrome variant for themed icons (Android 13+ `adaptive-icon` monochrome layer — required for a premium feel on Pixel).

### 2.4 Typography

- **Display / headings:** [Manrope](https://fonts.google.com/specimen/Manrope) (geometric, modern, free for commercial use).
- **Body / UI:** default platform font (Roboto / system) — keeps the native feel and saves APK size. Only headings use the brand font.

### 2.5 Brand palette

| Token | Light | Dark | Use |
|---|---|---|---|
| `brand.primary` | `#4F46E5` | `#818CF8` | Buttons, active states |
| `brand.accent` | `#FFB020` | `#FFC94D` | Premium highlights, "butter" moments |
| `surface` | M3 dynamic / `#FAFAFC` | M3 dynamic / `#0F1115` | Backgrounds |
| `success` | `#12B76A` | `#32D583` | Active feature chips |
| `error` | `#B3261E` | `#F2B8B5` | M3 defaults |

When dynamic color is enabled (default on Android 12+), M3 `ColorScheme.fromSeed` from the wallpaper replaces `brand.primary` inside the app UI; the **floating button itself always uses the selected theme preset**, never dynamic color, so the user's customization is authoritative.

---

## 3. Architecture Overview

### 3.1 High-level system diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                            ANDROID DEVICE                              │
│                                                                        │
│  ┌──────────────────────────┐      ┌────────────────────────────────┐  │
│  │   Main Flutter App       │      │  Overlay Foreground Service    │  │
│  │   (full UI, settings,    │      │  (Kotlin)                      │  │
│  │   paywall, theme editor) │      │  ┌──────────────────────────┐  │  │
│  │                          │      │  │ 2nd FlutterEngine        │  │  │
│  │  Riverpod state          │◄────►│  │ (overlay entrypoint:     │  │  │
│  │  go_router navigation    │ Meth.│  │  button + radial UI)     │  │  │
│  │                          │ Chan.│  └──────────────────────────┘  │  │
│  └────────────┬─────────────┘      │  WindowManager (TYPE_APPLICA-  │  │
│               │                    │  TION_OVERLAY), AudioManager   │  │
│  ┌────────────▼─────────────┐      └────────────────────────────────┘  │
│  │ Notification Foreground  │                                          │
│  │ Service (Kotlin)         │      ┌────────────────────────────────┐  │
│  │ custom RemoteViews:      │      │ AlarmManager                   │  │
│  │ mute / − / + / presets   │      │ (free-tier 12 h expiry per     │  │
│  │ + progress bar           │      │  feature, boot re-schedule)    │  │
│  └──────────────────────────┘      └────────────────────────────────┘  │
│                                                                        │
│  Local: SharedPreferences · Isar (themes) · flutter_secure_storage     │
└───────────────┬────────────────────────────────────────────────────────┘
                │ HTTPS (dio)
┌───────────────▼────────────────────────────────────────────────────────┐
│  Butter Volume Backend (FastAPI) — https://api.buttervolume.app/v1     │
│  device auth · purchase verification · entitlements · theme sync       │
│  remote config · feature flags · analytics · version check             │
└───────────────┬────────────────────────────────────────────────────────┘
                │
     Google Play Billing ── Play Developer API / RTDN ──► backend
     AdMob (App Open Ads) · Sentry (crash) · Google Sign-In (optional)
```

### 3.2 In-app layered architecture

Feature-first Clean-ish architecture. Each feature owns its vertical slice; shared plumbing lives in `core/`.

```
┌───────────────────────────────────────────────┐
│ PRESENTATION   widgets, screens, animations   │   Flutter widgets only.
├───────────────────────────────────────────────┤
│ APPLICATION    Riverpod Notifiers/controllers │   Orchestrates use cases,
│                                               │   exposes UI state.
├───────────────────────────────────────────────┤
│ DOMAIN         entities, value objects,       │   Pure Dart. No Flutter,
│                repository interfaces          │   no packages.
├───────────────────────────────────────────────┤
│ DATA           repository impls, DTOs, dio    │   Talks to storage, API,
│                clients, platform channels     │   platform channels.
└───────────────────────────────────────────────┘
```

Rules:
- Presentation never imports data. Everything crosses through application-layer providers.
- Platform channels are wrapped in Dart services (`core/platform/`) with abstract interfaces so they can be faked in tests.
- The overlay engine runs a **separate, minimal entrypoint** (`overlay_main.dart`) that shares only `domain` + a slim `overlay/` presentation package — it must not pull in dio, billing, or router code (memory discipline, see §13.1).

### 3.3 Process & engine model

| Component | Process | Engine | Lifetime |
|---|---|---|---|
| Main app | main | FlutterEngine A (from `FlutterEngineGroup`) | While app open |
| Floating button overlay | main | FlutterEngine B (same `FlutterEngineGroup` → shared heap/isolate group, cheap spawn) | While `OverlayService` (foreground service) runs |
| Notification slider | main | none — pure Kotlin `RemoteViews` | While `NotificationSliderService` runs |
| Timers | n/a | none — `AlarmManager` + `BroadcastReceiver` | Scheduled |

Using one `FlutterEngineGroup` for both engines is the key memory optimization: the second engine shares the loaded AOT snapshot and isolate group, costing ~10–15 MB instead of ~40 MB for a cold second engine.

---

## 4. Technology Decisions & Rationale

| Concern | Choice | Why (and why not the alternative) |
|---|---|---|
| State management | **Riverpod 2 (with codegen `@riverpod`)** | Compile-safe DI + reactive state in one tool; providers work without `BuildContext`, which matters because the overlay engine and background callbacks have no widget tree at times. Testable via `ProviderContainer` overrides. Bloc was considered but adds ceremony for a settings-heavy app; GetX rejected (global mutable state, weak discipline). |
| Dependency injection | **Riverpod itself** | One mental model. No `get_it` — avoids two competing service locators. |
| Navigation | **go_router** | Declarative, deep-link ready (needed for notification taps → specific screens, and future App Links), official Flutter team support. |
| Local settings storage | **SharedPreferences** (via a typed `SettingsRepository`) | Settings are flat key-values; SP is battle-tested and readable from Kotlin (`FlutterSharedPreferences`) — the overlay service reads button position/theme directly at boot without spinning Dart. |
| Structured local storage | **JSON file store** (app-support dir) behind a `ThemeRepository` interface | *(Revised from Isar during implementation:)* Isar 3.x is unmaintained and broken on Dart 3.12. Custom themes are ≤ 50 small documents (backend limit) — a single JSON document with per-entry sync metadata (`dirty`/`deleted`/`updatedAt`) covers it with zero dependency risk. The repository interface is unchanged, so the backing store is swappable if requirements grow. |
| Secure storage | **flutter_secure_storage** | JWTs + refresh tokens in Android Keystore-backed EncryptedSharedPreferences. |
| HTTP | **dio** + interceptors | Interceptors for auth-token refresh, retry with backoff, and request logging. |
| Serialization | **Hand-written immutable models** (manual `toJson`/`fromJson`/`copyWith`, Dart 3 sealed classes for unions) | *(Revised from freezed + json_serializable during implementation:)* the model surface is small (~6 classes) and hand-written models remove build_runner from the loop entirely — faster builds, no codegen drift, and Dart 3 sealed classes already give exhaustive state machines. Revisit codegen if the DTO count grows past ~15. |
| Overlay | **Custom Kotlin `WindowManager` overlay hosting FlutterEngine B** (details §6.2) | `flutter_overlay_window` was evaluated: it proves the approach but has known issues (janky drag on some OEMs, single fixed engine cost, limited touch-passthrough control, stale maintenance). We own the ~600 lines of Kotlin: `TYPE_APPLICATION_OVERLAY` window + `FlutterView`, drag handled natively (no Dart round-trip per frame), gestures forwarded via `EventChannel`. This is the single most important quality lever in the product. |
| Volume control | **Native `AudioManager`** via MethodChannel | `setStreamVolume(stream, index, 0)` with no system UI flag. Dart packages for volume are thin wrappers anyway; owning it lets us support stream switching (media/ring/alarm/notification/call) and DND edge cases directly. |
| Notification slider | **Kotlin foreground service + custom `RemoteViews`** | See constraint in §6.3 — interactive `SeekBar` is not allowed in notifications, so we design around it. |
| Billing | **`in_app_purchase`** + backend verification | Official plugin. All purchases verified server-side via Play Developer API; RTDN keeps state fresh (see backend doc §7). RevenueCat considered — great product, but we already need a backend for theme sync/config, and at a $0.67 price point every margin percent matters. |
| Ads | **google_mobile_ads — App Open Ads only** | The one format that satisfies "ads only when opening the app". Frequency-capped (max 1 per 4 h), never on first launch, never after returning from a permission-settings round trip. |
| Sign-in | **google_sign_in** (optional) → backend token exchange | Only path we need; unlocks cloud theme sync + cross-device restore. App is fully functional anonymously. |
| Crash reporting | **Sentry (sentry_flutter)** — *temporarily on hold* | Captures Dart + Kotlin (NDK) crashes, breadcrumbs, release health; pairs with the backend's Sentry. **Implementation note:** `sentry_flutter` currently pins Kotlin languageVersion 1.6, which AGP 9 / Kotlin 2.3 refuse to compile. The app ships an `ErrorReporter` seam (`core/error/error_reporter.dart`) that logs locally; swap in Sentry when a toolchain-compatible release lands. |
| Analytics | **Backend-first** (`/v1/analytics/events`, batched) with a thin `AnalyticsService` | We own the data; no third-party SDK bloat; events double as product metrics in our own Postgres. See §17. |
| Local notifications / FGS plumbing | Hand-rolled Kotlin | The two foreground services are core product; wrapping them in generic plugins costs control. |
| Lints | `flutter_lints` + stricter custom rules (`always_use_package_imports`, `unawaited_futures`) | Consistency. |

---

## 5. Project & Package Structure

```
butter_volume/
├── android/
│   └── app/src/main/kotlin/app/buttervolume/android/
│       ├── MainActivity.kt
│       ├── overlay/
│       │   ├── OverlayService.kt          # FGS; owns WindowManager + FlutterEngine B
│       │   ├── OverlayWindow.kt           # window params, drag, snap, edge logic
│       │   ├── OverlayTouchController.kt  # long-press detection, gesture forwarding
│       │   └── OverlayChannels.kt         # Method/EventChannel registration
│       ├── notification/
│       │   ├── NotificationSliderService.kt   # FGS; RemoteViews notification
│       │   ├── SliderNotificationBuilder.kt   # compact + expanded layouts
│       │   └── NotificationActionReceiver.kt  # mute / vol− / vol+ / preset actions
│       ├── audio/
│       │   └── VolumeController.kt        # AudioManager wrapper, stream switching
│       ├── timers/
│       │   ├── FeatureExpiryScheduler.kt  # AlarmManager scheduling per feature
│       │   ├── FeatureExpiryReceiver.kt   # stops the matching service
│       │   └── BootReceiver.kt            # re-arm alarms + restart services
│       └── channels/
│           └── AppChannels.kt             # channel name constants (mirror of Dart)
│
├── lib/
│   ├── main.dart                    # main app entrypoint
│   ├── overlay_main.dart            # @pragma('vm:entry-point') overlay UI entrypoint
│   ├── app.dart                     # MaterialApp.router, theming, lifecycle
│   │
│   ├── core/
│   │   ├── config/                  # flavors, env, constants, remote-config client
│   │   ├── di/                      # top-level providers (dio, isar, prefs)
│   │   ├── network/                 # dio setup, interceptors, ApiClient, error mapping
│   │   ├── platform/                # channel wrappers: OverlayChannel, VolumeChannel,
│   │   │                            #   NotificationChannel, TimerChannel (+ fakes)
│   │   ├── storage/                 # SettingsRepository, SecureTokenStore, IsarProvider
│   │   ├── theme/                   # M3 app theming (NOT button themes), typography
│   │   ├── analytics/               # AnalyticsService, event definitions, batching queue
│   │   ├── error/                   # Failure types, global error handler, Sentry glue
│   │   └── utils/
│   │
│   ├── features/
│   │   ├── onboarding/              # splash, onboarding, permission setup
│   │   │   ├── application/  domain/  data/  presentation/
│   │   ├── home/                    # home screen, feature activation cards
│   │   ├── floating_button/         # settings UI + live preview + overlay state
│   │   ├── notification_slider/     # settings UI + service control
│   │   ├── themes/                  # gallery, editor, preset definitions, sync
│   │   ├── subscription/            # paywall, billing, entitlement state machine
│   │   ├── auth/                    # optional Google Sign-In, account linking
│   │   ├── settings/                # general settings, about, feedback
│   │   └── ads/                     # AppOpenAdManager, frequency capping
│   │
│   └── overlay/                     # UI for FlutterEngine B ONLY (keep imports slim)
│       ├── overlay_app.dart
│       ├── floating_button_view.dart
│       ├── radial_controller_view.dart   # CustomPainter arc, gesture math
│       └── overlay_state.dart            # listens to EventChannel from service
│
├── test/                            # unit + widget tests, mirrors lib/
├── integration_test/
├── docs/
└── pubspec.yaml
```

Each `features/<name>/` follows the same four-folder slice: `domain/` (entities + repo interfaces), `data/` (impls, DTOs), `application/` (Riverpod notifiers), `presentation/` (screens, widgets).

---

## 6. Feature Specifications

### 6.1 Feature model & activation

Two independent features, each with its own switch, its own foreground service, and (for free users) its own 12-hour timer:

| | Feature 1: Floating Button | Feature 2: Notification Slider |
|---|---|---|
| Service | `OverlayService` | `NotificationSliderService` |
| Permission gate | `SYSTEM_ALERT_WINDOW` + `POST_NOTIFICATIONS` (FGS notification) | `POST_NOTIFICATIONS` |
| Free-tier session | 12 h from activation | 12 h from activation |
| Timer key | `expiry.floating_button` | `expiry.notification_slider` |
| Premium | Unlimited, auto-start on boot | Unlimited, auto-start on boot |

**Activation flow (free user):**
1. User toggles feature ON on Home → permission check → service starts → `FeatureExpiryScheduler` sets an `AlarmManager` alarm at `now + 12h` (windowed inexact alarm ±10 min; exact only if user grants `SCHEDULE_EXACT_ALARM` — see §12).
2. At T−30 min, the feature's own notification shows a gentle "Session ending soon — open Butter Volume to extend, or go unlimited" line.
3. At expiry, `FeatureExpiryReceiver` stops that service only. The other feature is untouched.
4. Reopening the app re-enables activation (a fresh 12 h). No daily quota — the mechanic is "come back to the app", which is also the ad impression opportunity.

**Premium:** timers are never scheduled; `BootReceiver` restarts enabled services after reboot (if auto-start setting is on).

Entitlement states (identical vocabulary to the backend, see backend doc §7): `free`, `premium_monthly`, `premium_lifetime`, `grace_period` (treated as premium), `on_hold` (treated as free + fix-payment banner), `paused` (free until resume), `expired` (free).

### 6.2 Floating button & radial controller

#### 6.2.1 Idle button

- Rendered by FlutterEngine B inside a small `TYPE_APPLICATION_OVERLAY` window (window sized to button + margin, **not** fullscreen — smaller surfaces composite cheaper and don't intercept touches elsewhere).
- **Drag:** handled natively in `OverlayWindow.kt` (`ACTION_MOVE` → `WindowManager.updateViewLayout`). No Dart involvement per frame → 120 Hz drag on any OEM.
- **Snap:** on release, animates (native `ValueAnimator`, overshoot interpolator) to the nearest vertical edge unless "free placement" is enabled in settings.
- **Position persistence:** normalized `(edge, yFraction)` — survives rotation and resolution changes — written to SharedPreferences on every drop; read by the service at start (including after reboot).
- **Idle behavior options:** shrink-to-edge after 4 s of inactivity (peek mode, 40% visible, reduced opacity), configurable.
- **Tap:** nothing (reserved; a subtle 0.95→1.0 scale "acknowledge" micro-animation only).

#### 6.2.2 Long-press → radial controller morph

State machine (lives in `overlay_state.dart`, mirrored by the service):

```
 idle ──long-press (350 ms)──► expanding ──► active ──finger-up──► collapsing ──► idle
   ▲                                                                    │
   └────────────────────────────────────────────────────────────────────┘
```

1. **Long-press detected** (native, 350 ms, with slop tolerance). Service expands the window (still not fullscreen: a square of `2.4 × buttonSize` centered on the button, clamped to screen), fires haptic `CLICK`, and notifies Dart via EventChannel.
2. **Expanding (240 ms, spring):** the circle morphs outward into a ring — the button's own surface grows into the radial track (one continuous surface, not a new element appearing). Current volume arc draws in clockwise from 12 o'clock during the expansion.
3. **Active:** the finger never lifts. **Vertical drag** adjusts volume:
   - `Δvolume = −Δy × sensitivity`, sensitivity default = full range over 60% of screen height (adjustable in settings).
   - The arc (`CustomPainter`, `drawArc` with round stroke caps + optional glow per theme) animates in real time; a center label shows `%` and the active stream's icon.
   - Every discrete volume step fires a light haptic tick (`HapticFeedbackConstants.CLOCK_TICK`), toggleable.
   - Volume is applied natively (`VolumeController.kt`) with ≤ 16 ms latency; Dart only renders.
   - **Stream switching:** a small stream chip (media/ring/alarm/notification/call icons) sits at the bottom of the ring; while still pressing, sliding horizontally onto it cycles streams. Default stream is a setting (default: media).
4. **Collapsing (200 ms, ease-out-back):** ring shrinks back into the button; a brief `%` toast fades on the button for 800 ms; window shrinks back to button size.

Cancel conditions: incoming full-screen intent, screen off, service stop → immediate graceful collapse.

#### 6.2.3 Live customization

Every property in §7's theme schema applies to the overlay **live**: the settings screen writes to SharedPreferences and pings the service (`MethodChannel: overlay/refreshStyle`), which forwards to Engine B — the user watches the real floating button change while dragging sliders. The settings screen also embeds an in-app preview widget (same `FloatingButtonView` widget reused) for users who haven't granted overlay permission yet.

### 6.3 Notification volume slider

**Platform constraint (important):** Android does **not** allow interactive `SeekBar`/`Slider` widgets inside notification `RemoteViews`. Any design showing a draggable notification slider is not implementable. The spec below is the best achievable pattern (and matches what successful volume apps ship):

- **Foreground service** posts a persistent, silenced (`IMPORTANCE_LOW`), ongoing notification on its own channel.
- **Compact (collapsed) layout:** `[mute/unmute] [−] [ progress bar ] [+]` — a real `ProgressBar` visualizes level; taps on −/+ step volume (step size configurable: 1 step / 5% / 10%).
- **Expanded layout:** adds a row of **preset chips: 0% · 25% · 50% · 75% · 100%** (tap to jump — this is the "slider-like" affordance), an active-stream label, and an "open app" action.
- Actions route through `NotificationActionReceiver` → `VolumeController.kt` → notification re-render (throttled to ≤ 4 renders/s).
- A `VolumeContentObserver` (observing `android.provider.Settings.System.VOLUME_SETTINGS`... in practice: `AudioManager` volume change broadcasts `VOLUME_CHANGED_ACTION`) keeps the bar in sync when volume changes elsewhere (hardware keys, the floating button).
- Compact/expanded mode preference, quick-action selection, and stream selection are all settings (§10).
- Android 13+: user can swipe away FGS notifications — the service keeps running; we re-post on next volume change and note this in a one-time hint.

### 6.4 Free vs Premium matrix

| Capability | Free | Premium |
|---|---|---|
| Floating button | 12 h/activation | Unlimited |
| Notification slider | 12 h/activation | Unlimited |
| Auto-start on boot | ✗ | ✓ |
| Built-in themes | 4 (Minimal White, AMOLED Black, Ocean Blue, Material Red) | All 10 |
| Custom theme editor | Preview only | Full save/apply |
| Cloud theme sync (signed in) | ✗ | ✓ |
| App Open Ads | ✓ | ✗ (none) |

---

## 7. Theme System

### 7.1 Theme model (canonical JSON schema)

This schema is the single source of truth, **identical** on the backend (`themes.payload`, see backend doc §5/§6.6). Version it from day one.

```json
{
  "schemaVersion": 1,
  "id": "9f6f2c1e-4b1a-4c5e-9a3f-2f8f0a7d1c22",
  "name": "Ocean Blue",
  "isBuiltIn": false,
  "basedOn": "ocean_blue",
  "button": {
    "size": 56,
    "shape": "circle",
    "color": "#1E88E5",
    "opacity": 0.92,
    "elevation": 6,
    "border": { "width": 1.5, "color": "#FFFFFF", "opacity": 0.35 },
    "shadow": { "color": "#0A2540", "blurRadius": 14, "offsetY": 4, "opacity": 0.30 },
    "icon": "volume_up",
    "iconSize": 26,
    "iconColor": "#FFFFFF"
  },
  "radial": {
    "trackColor": "#12314F",
    "trackOpacity": 0.55,
    "progressColors": ["#42A5F5", "#1E88E5"],
    "strokeWidth": 10,
    "glow": true,
    "glowColor": "#42A5F5",
    "centerLabelColor": "#FFFFFF"
  },
  "animationStyle": "smooth",
  "updatedAt": "2026-07-23T10:00:00Z"
}
```

- `shape`: `circle | squircle | rounded_square`
- `icon`: enum of ~12 curated Material Symbols (`volume_up`, `music_note`, `graphic_eq`, `speaker`, …)
- `animationStyle`: `smooth` (default springs) | `snappy` (shorter, sharper) | `bouncy` (overshoot) | `glass` (slower + blur emphasis)
- `basedOn`: preset id if derived, for analytics.

Storage: Isar collection `ThemeDoc` (payload + `dirty`/`deleted` flags + `updatedAt` for last-write-wins sync — see backend doc §6.6).

### 7.2 Built-in presets

| Preset | id | Character (colors / shadow / border / opacity / animation) | Tier |
|---|---|---|---|
| Minimal White | `minimal_white` | White `#FFFFFF`, soft gray shadow, hairline border, 0.95 opacity, `smooth` | Free |
| AMOLED Black | `amoled_black` | Pure `#000000`, no shadow, subtle `#333` border, 1.0, `snappy` | Free |
| Ocean Blue | `ocean_blue` | `#1E88E5` gradient arc, deep navy shadow, `smooth` | Free |
| Material Red | `material_red` | `#D32F2F`, warm shadow, no border, `smooth` | Free |
| Forest Green | `forest_green` | `#2E7D32`, moss shadow, 0.9, `smooth` | Premium |
| Sunset Orange | `sunset_orange` | `#F4511E→#FFB020` arc gradient, amber glow, `bouncy` | Premium |
| Purple Glass | `purple_glass` | `#7C4DFF` @ 0.55 opacity, blurred look, white 0.3 border, `glass` | Premium |
| Frosted Glass | `frosted_glass` | White @ 0.35, heavy blur illusion (semi-transparent + border), `glass` | Premium |
| Neon | `neon` | Near-black button, `#39FF14` icon + glowing arc, glow=true, `snappy` | Premium |
| Cyber | `cyber` | `#0D0221` + `#00E5FF`/`#FF2079` dual-gradient arc, hard shadow, `snappy` | Premium |

True `BlurEffect` behind an overlay window is not reliably available (`FLAG_BLUR_BEHIND` works only for some window types / API 31+); "glass" presets simulate it with opacity + border + saturated shadow, and use real `RenderEffect` blur *inside* the Flutter surface where possible.

### 7.3 Theme Gallery & Editor

Specified as screens in §8.7–8.8. Editor edits a working copy live against the preview *and* the real overlay; Save requires premium (free users can play, get a tasteful paywall on save — a proven conversion moment).

---

## 8. Screens & UI Flow

### 8.1 Navigation map

```
Splash ──► (first run) Onboarding ──► Permission Setup ──► Home
   └─────► (returning) Home

Home ─┬─► Floating Button Settings ──► Theme Gallery ──► Theme Editor
      ├─► Notification Slider Settings
      ├─► Subscription (paywall)          ◄── also from: timer expiry, theme save,
      ├─► Settings ─┬─► About                 premium preset tap
      │             └─► Feedback
      └─► (App Open Ad interstitial point, free users, capped)
```

go_router routes: `/`, `/onboarding`, `/permissions`, `/home`, `/floating-button`, `/themes`, `/themes/edit/:id`, `/notification-slider`, `/subscription`, `/settings`, `/about`, `/feedback`. Deep links: notification "open app" → `/home`; expiry notification → `/home?reactivate=<feature>`.

For each screen: **Purpose / Components / Interactions / Navigation / Animations.**

### 8.2 Splash
- **Purpose:** brand moment + async boot (read entitlement cache, init Isar, decide route). Target < 1.2 s.
- **Components:** logo glyph on `surface`, subtle arc sweep around the logo.
- **Interactions:** none.
- **Navigation:** → Onboarding (first run) or Home. App Open Ad may show after Home is ready (free, capped, never first-ever launch).
- **Animations:** logo scale 0.9→1.0 + arc draws 0→270°, 600 ms, `Curves.easeOutCubic`; exits with fade-through to next screen.

### 8.3 Onboarding (3 pages)
- **Purpose:** show the promise in ≤ 20 s. Pages: (1) "Volume anywhere" — animated mock of the floating button morphing; (2) "Also in your notifications"; (3) "Make it yours" — theme carousel auto-cycling.
- **Components:** `PageView`, animated illustrations (Rive or hand-built implicit animations — decide by asset budget; hand-built preferred, zero dependency), page dots, Skip, Continue.
- **Interactions:** swipe/skip/continue.
- **Navigation:** → Permission Setup.
- **Animations:** parallax between layers on swipe; dots morph width (M3 style).

### 8.4 Permission Setup
- **Purpose:** honest, staged permission asks. Never block: every permission is skippable, features gate themselves later.
- **Components:** checklist cards — Overlay permission (`Settings.ACTION_MANAGE_OVERLAY_PERMISSION`), Notifications (`POST_NOTIFICATIONS` runtime), optional Battery-optimization exemption card (shown only if OEM is on the aggressive list, §13.4). Each card: icon, one-line why, state chip (Granted ✓ / Needed), button.
- **Interactions:** tapping a card launches the system flow; on return, state re-checks via lifecycle observer and the card animates to ✓.
- **Navigation:** → Home ("Continue" always enabled).
- **Animations:** card check-off: chip cross-fades to success color + checkmark draws (200 ms); completed cards settle 2 dp lower elevation.

### 8.5 Home
- **Purpose:** the control room. Two feature cards + status at a glance.
- **Components:**
  - **Floating Button card:** live mini-preview of current theme, master switch, status line ("Active · 9 h 12 m left" free / "Active" premium), countdown ring around the switch for free users.
  - **Notification Slider card:** same pattern with a mini mock of the notification row.
  - **Premium banner** (free users): slim, dismissible-per-session, "Unlimited sessions + all themes — $7 lifetime".
  - App bar: logo word-mark, Settings gear.
- **Interactions:** switch toggles feature (permission-gated); card tap → that feature's settings; long-press card → quick theme switcher sheet.
- **Navigation:** as mapped in §8.1.
- **Animations:** switches use M3 motion; countdown ring animates continuously (1 fps update, cheap); when a timer expires while visible, the card desaturates with a 300 ms fade and status swaps via shared-axis Y.

### 8.6 Floating Button Settings
- **Purpose:** full live customization of the button + behavior.
- **Components:** pinned **live preview** header (real overlay mirrors every change if active); sections: *Appearance* (theme entry point → Gallery; size 40–72 dp slider; shape selector; color; opacity; elevation; border width/color; shadow; icon picker grid; icon size/color), *Behavior* (default stream, drag sensitivity, edge snap toggle, peek/shrink toggle, vibration & haptic ticks, animation speed ×0.5–×1.5), *Position* (free placement toggle, "reset position").
- **Interactions:** every control writes-through live (§6.2.3); sliders show value bubbles; color rows open a M3 color sheet (presets + wheel + hex).
- **Navigation:** → Theme Gallery; back → Home.
- **Animations:** preview responds with 150 ms implicit animations; section headers use shared-axis transitions when collapsing/expanding.

### 8.7 Theme Gallery
- **Purpose:** browse presets + user themes; premium showcase.
- **Components:** 2-column grid of theme cards — each renders a real mini floating-button + arc using that theme (no screenshots; always accurate). Premium presets carry a small gold `PRO` chip. FAB: "Create theme". Tabs: Presets / My themes.
- **Interactions:** tap = apply (premium check) with instant overlay update; long-press = preview-in-place (card expands, radial demo animates); user themes: swipe actions edit/duplicate/delete.
- **Navigation:** FAB or edit → Theme Editor; premium-gated tap → Subscription (with the tapped theme as hero context).
- **Animations:** staggered grid entrance (40 ms/item fade+rise); apply = selected card's button glyph does a hero-style flight to the preview slot; premium chip shimmers once on first view.

### 8.8 Theme Editor
- **Purpose:** create/edit custom themes.
- **Components:** large live preview (idle ↔ expanded toggle to see the arc), name field, grouped controls mirroring the schema (§7.1): button group, radial group, animation style selector (4 animated chips that demo their curve on tap).
- **Interactions:** all live; "Try on screen" pushes to the real overlay temporarily; Save (premium) / Save-as-copy; unsaved-changes guard sheet.
- **Navigation:** back → Gallery; Save on free tier → paywall with "your theme is kept safe" reassurance (draft persisted).
- **Animations:** preview toggle idle↔expanded runs the real morph animation; color changes cross-fade 150 ms.

### 8.9 Notification Slider Settings
- **Purpose:** configure feature 2.
- **Components:** live notification mock (pixel-accurate compact & expanded render), master switch, layout mode (compact/expanded default), step size (1 step/5%/10%), preset chips on/off + which (0/25/50/75/100 multi-select), mute button toggle, stream selector, "re-post if swiped away" hint card.
- **Interactions:** mock updates live; changes re-render the real notification immediately when active.
- **Navigation:** back → Home.
- **Animations:** mock uses shared-axis X when switching compact↔expanded.

### 8.10 Subscription (Paywall)
- **Purpose:** convert with clarity, not pressure.
- **Components:** hero area (animated: floating button morphs through 3 premium themes), benefit list (Unlimited sessions · All 10 themes · Custom themes · Auto-start · No ads · Cloud sync), two plan cards — **Lifetime $7** (pre-selected, "Best value" chip) and **Monthly $0.67**, CTA button, "Restore purchases", legal links, subtle "maybe later".
- **Interactions:** plan select animates card border; CTA → Play Billing sheet → verification (§11) → success state; restore → backend restore flow.
- **Navigation:** modal-style route, reachable from all gate points; success pops back to origin.
- **Animations:** hero theme-cycling every 2.5 s with morph; on success, the **premium unlock animation**: gold arc draws a full circle around a checkmark, light confetti burst (300 ms, restrained), then benefits list check items cascade.

### 8.11 Settings
- **Purpose:** everything else (full catalog §10).
- **Components:** grouped M3 list; Appearance / General / Account (optional sign-in) / Data (reset, export) sections; version footer.
- **Navigation:** → About, → Feedback.
- **Animations:** standard M3 list transitions; theme mode changes animate the whole app via `AnimatedTheme` cross-fade (250 ms).

### 8.12 About
- **Purpose:** version, credits, licenses (`showLicensePage`), privacy policy & ToS links, "rate us".
- **Animations:** logo idle micro-animation (arc slowly breathing) — a small delight.

### 8.13 Feedback
- **Purpose:** low-friction feedback → `/v1/feedback`.
- **Components:** category chips (Bug / Idea / Praise / Other), text field, optional email prefill (if signed in), attach-diagnostics toggle (device model, OS, app version — shown transparently), send.
- **Animations:** send button morphs to a progress ring, then a checkmark (M3 loading pattern).

---

## 9. Animation Catalog

Central motion spec — implemented as constants in `core/theme/motion.dart`; every duration multiplied by the user's *animation speed* setting and forced to ×0 when the OS "remove animations" accessibility setting is on.

| Animation | Where | Spec |
|---|---|---|
| Button morph (expand) | Overlay | 240 ms, spring (stiffness 500, damping 30); circle → ring, arc draws simultaneously |
| Button morph (collapse) | Overlay | 200 ms, `easeOutBack`; % badge fades 800 ms |
| Snap to edge | Overlay (native) | 250 ms, overshoot interpolator 1.2 |
| Peek shrink | Overlay | 300 ms `easeInOut` after 4 s idle |
| Volume arc fill | Overlay | Real-time; between discrete steps, 90 ms `easeOut` tween |
| Haptic ticks | Overlay | Per volume step; CLOCK_TICK strength |
| Screen transitions | App | M3 fade-through (top-level), shared-axis X (drill-in), 300 ms |
| Hero: theme card → preview | Gallery | 350 ms, `Curves.fastOutSlowIn` flight of button glyph |
| Staggered grid entrance | Gallery | 40 ms/item stagger, fade + 12 dp rise |
| Theme switch (app UI) | Everywhere | `AnimatedTheme` 250 ms cross-fade |
| Theme switch (overlay) | Overlay | Colors/sizes lerp 300 ms live |
| Countdown ring | Home | Continuous, 1 fps repaint |
| Permission check-off | Permission Setup | 200 ms chip cross-fade + checkmark path draw |
| Premium unlock | Paywall success | Gold arc 360° draw (500 ms) + restrained confetti (300 ms) + benefit cascade (60 ms stagger) |
| Ripple | All touchables | M3 default ink sparkle |
| Splash arc | Splash | 600 ms `easeOutCubic` |
| Send morph | Feedback | Button → ring → check, M3 pattern |

---

## 10. Settings Catalog

**Appearance**
- App theme: System / Light / Dark
- Dynamic color (Android 12+): on/off (app UI only; never the overlay button)
- Accent color (when dynamic off): 8 curated seeds

**Floating Button** *(duplicated entry points: Home card → settings screen)*
- Enable/disable · Size · Shape · Color · Opacity · Elevation · Border · Shadow · Icon / size / color (via theme system)
- Default volume stream: Media / Ring / Alarm / Notification / Call
- Drag sensitivity · Edge snap · Free placement · Peek mode
- Animation speed: 0.5×–1.5×
- Vibration on long-press: on/off · Haptic volume ticks: on/off
- Reset position

**Notification Slider**
- Enable/disable · Default layout: Compact / Expanded
- Step size: 1 step / 5% / 10%
- Preset chips: on/off + selection · Mute button: on/off
- Stream selector visible: on/off

**General**
- Auto-start after reboot (premium; shows lock chip on free)
- Battery optimization helper (opens OEM-specific guidance, §13.4)
- Accessibility: reduce animations (also auto-follows system) · larger touch target for the button (+8 dp invisible padding)
- Language (follows system; explicit picker on roadmap)
- Reset all settings (confirmation dialog; themes kept, offered separately)

**Account & Data**
- Sign in with Google (optional) / Sign out
- Cloud theme sync toggle (premium + signed in)
- Restore purchases
- Export settings (JSON share) — free; Import — free
- Delete account & data (calls backend `/v1/account`, GDPR)

---

## 11. Monetization

### 11.1 Products

| Product | Play product ID | Type | Price |
|---|---|---|---|
| Monthly | `bv_premium_monthly` | Auto-renewing subscription (base plan `monthly`) | $0.67/mo (set per-market with Play's price templates) |
| Lifetime | `bv_premium_lifetime` | One-time in-app product (non-consumable) | $7 |

Pricing note: $0.67 monthly is an impulse price ("less than a coffee, per year cheaper than most"); $7 lifetime ≈ 10.4 months of monthly — the paywall highlights lifetime as the anchor, which is deliberate: lifetime buyers of utilities churn less and review better.

### 11.2 Purchase flow

```
Paywall ► in_app_purchase.buy…() ► Play sheet ► purchaseStream update
   ► POST /v1/purchases/verify {productId, purchaseToken}
   ► backend verifies with Play Developer API, acknowledges, returns
     entitlement + signed offline token
   ► EntitlementController updates state ► services drop timers ► unlock animation
```

- **Client never self-grants premium.** The only local trust root is the backend's **signed offline entitlement token** (Ed25519, ~7-day validity for subscriptions / long-lived for lifetime; format in backend doc §7.4) cached in secure storage — this is the offline behavior: premium keeps working up to the token's grace window without network.
- **Acknowledgement** happens server-side post-verification (within Play's 3-day window; unacknowledged → refunded).
- **Restoration:** "Restore purchases" → `in_app_purchase.restorePurchases()` → tokens re-verified via backend. Signed-in users additionally get entitlements attached to their account across devices.
- **Grace period / on-hold / pause:** driven by backend RTDN state (backend doc §7.3): grace = premium + "payment issue" banner; on-hold/paused = free behavior + fix-payment banner.
- **Trial:** none at launch (price is already an impulse). Play's built-in intro offers can be enabled later without code changes (backend already models offer states).

### 11.3 Ads (free users only)

- **Format:** AdMob **App Open Ads** — full-screen at app open, dismissible, designed by Google exactly for this "only when opening" policy.
- **Rules:** never on first-ever launch; never within 10 s of returning from a system-settings round-trip (permission flows) — tracked via a "expected external nav" flag; frequency cap: 1 per 4 h *and* max 2/day; never for premium/grace users; ad SDK not even initialized for premium users (startup win); remote kill-switch flag `ads_enabled` (backend doc §6.8).
- No banners, no interstitials during use, no rewarded ads in v1 (a "watch ad → +12 h" rewarded option is on the roadmap as an experiment, backend-flagged).

---

## 12. Permissions

| Permission | Required for | Optional? | Flow | Play Store implications |
|---|---|---|---|---|
| `SYSTEM_ALERT_WINDOW` | Floating button | Yes — only if feature 1 used | Special access: `ACTION_MANAGE_OVERLAY_PERMISSION` intent from Permission Setup / feature toggle; re-checked on resume | Sensitive but common for overlay utilities; must demo clearly in review notes + video. Cannot be requested at runtime like normal perms. |
| `POST_NOTIFICATIONS` (API 33+) | Both features' FGS notifications + expiry reminders | Yes, but features degrade (services still run; Android shows them in task manager) | Standard runtime prompt with pre-prompt rationale card | None special |
| `FOREGROUND_SERVICE` | Both services | Bundled | Manifest | None |
| `FOREGROUND_SERVICE_SPECIAL_USE` (API 34+) | `OverlayService`, `NotificationSliderService` | Bundled | Manifest + `<property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" android:value="Floating on-screen volume controller / persistent volume notification"/>` | **Play policy declaration required** for the special-use FGS type — fill the Play Console declaration honestly; `mediaPlayback` type would be a misdeclaration (we don't play media), don't use it. |
| `RECEIVE_BOOT_COMPLETED` | Auto-start (premium) + re-arming expiry alarms | Yes | Manifest; gated by setting | None |
| `INTERNET`, `ACCESS_NETWORK_STATE` | API, billing, ads | Bundled | Manifest | None |
| `SCHEDULE_EXACT_ALARM` (API 31+) | Precise 12 h expiry | **Optional** — default is windowed inexact alarm (±10 min is fine for this product); exact only if user opts in via "precise timer" | Special access intent | Play restricts `USE_EXACT_ALARM`; we use the softer `SCHEDULE_EXACT_ALARM` only, or skip entirely — recommended: **ship without it**, inexact is sufficient. |
| `com.android.vending.BILLING` | Purchases | Bundled | Manifest (via plugin) | None |
| `VIBRATE` | Haptics | Bundled | Manifest | None |
| DND access (`ACCESS_NOTIFICATION_POLICY`) | Only edge case: lowering ring volume to 0 / mute while DND rules block it | Yes — requested contextually with explanation only when the user hits the wall | Special access intent | Fine if contextual |

**Permission UX rules:** never ask before explaining; never ask two things at once; every deny leaves the app usable; Permission Setup screen doubles as a health dashboard reachable from Settings.

---

## 13. Technical Considerations

### 13.1 Overlay performance & memory
- `FlutterEngineGroup` spawn for Engine B (shared AOT/isolate group) → second engine ≈ 10–15 MB.
- Overlay window kept at minimal size; enlarged only during the radial state (§6.2.2). `FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL` so the rest of the screen behaves normally.
- Drag = native only. Dart renders only state changes (idle/expanding/active/collapsing + arc value).
- `overlay_main.dart` import budget enforced by a CI check (no dio/billing/router in the overlay's transitive imports).
- Engine B paused (`lifecycleChannel appIsPaused`) during idle-peek to stop raster work; resumed on touch.

### 13.2 Battery
- No polling anywhere. Everything is event-driven (touch, volume-change broadcasts, alarms).
- Foreground services declare low-importance notifications; no wakelocks.
- Target: < 1% battery/day with both features active (verify with Battery Historian in QA).

### 13.3 Android version compatibility

| Range | Notes |
|---|---|
| minSdk **26** (Android 8.0) | `TYPE_APPLICATION_OVERLAY` baseline; notification channels exist. Covers ~97% of active devices. |
| 8–12 | Full behavior. |
| 13 (33) | `POST_NOTIFICATIONS` runtime; FGS notification dismissible — handled (§6.3). |
| 14 (34) | FGS types mandatory → `specialUse` + Play declaration; BOOT_COMPLETED FGS-start restrictions: overlay FGS start from boot is allowed for specialUse via `startForegroundService` within the window — verified in QA matrix. |
| 15 (35) | Edge-to-edge enforced — app UI already edge-to-edge; overlay unaffected. |
| targetSdk | Always latest required by Play (35 at time of writing). |

### 13.4 OEM restrictions (the #1 support topic for overlay apps)
- Maintain an OEM quirk table (Xiaomi/MIUI "Display pop-up windows while running in background" + Autostart; Huawei/Honor protected apps; Oppo/Vivo/OnePlus battery managers; Samsung "never sleeping apps").
- `Battery optimization helper` in Settings deep-links to the right OEM screen where intents are known (community-maintained intent list), otherwise shows illustrated per-OEM instructions.
- Detect service kills: on app open, if a feature was enabled but its service is dead and no expiry fired → show a "Your phone stopped Butter Volume — here's the fix" card with the OEM guide. This turns 1-star "it stops working" reviews into support wins.

### 13.5 Accessibility
- Overlay button exposes a virtual accessibility node ("Volume button, double-tap and hold to adjust volume"); radial state announces value changes ("Media volume 60 percent") via live region.
- Full TalkBack pass on all screens; 48 dp minimum targets (overlay button optionally padded, §10).
- Honors system font scale (app UI) and "remove animations" (§9).
- Notification actions are inherently accessible (system renders them).

### 13.6 Background execution summary
- Two independent FGS (one per feature) — never combined, so each can stop without the other.
- `BootReceiver` (premium + auto-start): re-launch enabled services; (free): re-arm pending expiry alarms only — sessions do *not* survive reboot for free users? **Decision:** they do — remaining time continues after reboot (fairer, simpler mental model); alarm re-armed with remaining duration.

---

## 14. Error Handling, Logging & Testing

### 14.1 Error handling
- Domain-level sealed `Failure` union (freezed): `NetworkFailure`, `AuthFailure`, `BillingFailure(code)`, `PlatformFailure(channel, code)`, `StorageFailure`.
- `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` → Sentry; Kotlin exceptions → Sentry Android.
- **Graceful-degradation policy:** backend unreachable ⇒ app fully functional (cached entitlement token, cached config, queued analytics). Only purchases require connectivity (and Play requires it anyway).
- User-facing errors: M3 snackbars with a retry action; never raw exception text.

### 14.2 Logging
- `logger`-style leveled logging behind `core/error/log.dart`; debug builds verbose, release builds warning+ with Sentry breadcrumbs.
- Kotlin side mirrors levels; channel calls logged with correlation ids in debug.

### 14.3 Testing strategy

| Layer | Tooling | Coverage focus |
|---|---|---|
| Domain/unit | `flutter_test`, `mocktail` | Entitlement state machine, timer math, theme (de)serialization + schema migration, gesture math (Δy→volume) |
| Application | `ProviderContainer` overrides | Notifier flows: activation, expiry, purchase, sync conflict |
| Widget | `flutter_test` + golden tests (`alchemist`) | Theme presets render (goldens per preset, light/dark), paywall, cards |
| Platform channels | Dart fakes + Kotlin unit tests (JUnit/Robolectric) | Volume controller stream logic, notification builder layouts, expiry scheduler |
| Integration | `integration_test` on Firebase Test Lab matrix (incl. one Xiaomi, one Samsung) | Activation E2E, overlay grant flow, billing (Play test tracks + license testers) |
| Manual QA matrix | Checklist | OEM kill behavior, reboot, DND, rotation, 120 Hz drag feel |

---

## 15. CI/CD & Build Flavors

### 15.1 Flavors

| Flavor | appId suffix | Backend | Ads | Purpose |
|---|---|---|---|---|
| `dev` | `.dev` | `https://api.dev.buttervolume.app/v1` | AdMob test IDs | Daily dev, verbose logging |
| `prod` | — | `https://api.buttervolume.app/v1` | Real | Release |

`--dart-define-from-file=env/<flavor>.json` for API base URL, Sentry DSN, AdMob IDs. No secrets in the repo; signing keys in CI secrets.

### 15.2 GitHub Actions pipeline

```
PR:        analyze ► test ► goldens ► overlay-import-budget check ► build debug apk
main:      all of the above ► build prod appbundle (signed) ► upload to Play
           internal track (fastlane supply / gradle-play-publisher)
tag v*:    promote internal ► closed beta ► (manual approval) production staged rollout
```

- Version: `pubspec.yaml` version + CI-injected build number (`--build-number=$GITHUB_RUN_NUMBER`).
- Release health gate: Sentry crash-free sessions ≥ 99.5% on beta before production promote.

---

## 16. Play Store Launch Strategy

### 16.1 Target audience
Android power users & customizers (the Tasker/Nova/KWGT crowd), media-heavy users (headphone listeners wanting fast fine control), accessibility-adjacent users (broken volume keys — a surprisingly large search segment), users of aging devices with failing hardware buttons.

### 16.2 Listing

- **Title:** `Butter Volume — Floating Volume Button` (30 chars is tight; fallback: `Butter Volume: Volume Button`)
- **Short description:** *"A smooth floating volume button + notification slider. Your volume, anywhere."*
- **Long description (structure):** hook (broken/awkward volume keys) → the floating button story → radial controller → notification slider → customization/themes → premium pitch ($7 lifetime, honest) → permissions honesty section (why overlay permission) → support link. Keyword-natural, no stuffing.
- **Keywords/ASO targets:** volume button, floating volume, volume slider, volume control, assistive volume, volume booster *(do not claim boosting — target the search, disambiguate in listing)*, broken volume button, volume panel.
- **Screenshots (8):** 1 hero "volume anywhere" over a game, 2 radial morph sequence, 3 theme gallery, 4 theme editor, 5 notification slider, 6 dark/AMOLED, 7 free vs premium, 8 "smooth as butter" brand card. Device frames, short captions, consistent gradient background.
- **Feature graphic:** butter-gold → indigo gradient, floating button + arc glyph center, word-mark, no text clutter.
- **Promo video (30 s):** screen capture: music playing → long-press → radial swipe → release; theme switch montage; notification slider; end card with slogan.

### 16.3 Policy & compliance
- **Privacy policy** (hosted at `buttervolume.app/privacy`, backend doc §9 hosts it): data collected = device metadata, anonymized analytics, purchase tokens, optional Google account email; no data sold; deletion via in-app "Delete account & data".
- **Data safety form** must match exactly: Data collected (App interactions, Device IDs, Purchase history; Email only if signed in), all encrypted in transit, deletable.
- Special-use FGS declaration (§12); overlay usage demo video attached to review notes.
- **Support page + FAQ** at `buttervolume.app/support` (FAQ: Why does it stop after 12 hours? Why overlay permission? Why does my Xiaomi kill it? How do I restore my purchase? Real slider in notification? — honest answer re Android limits).

### 16.4 Release plan
1. **Internal testing** (team, 1 week): permissions, billing with license testers.
2. **Closed beta** (50–200 users recruited from r/androidapps + Telegram/Discord, 2–3 weeks): OEM coverage, crash-free ≥ 99.5%, collect reviews of the 12 h mechanic.
3. **Open beta** (optional, 1–2 weeks) with pre-registration campaign.
4. **Production staged rollout:** 10% → 25% → 50% → 100% over ~2 weeks, halt on crash spikes (Sentry + Play vitals).
5. Post-launch: respond to every review for the first 90 days; OEM fix cards (§13.4) iterated from real complaints.

### 16.5 Monetization strategy summary
Free tier is a real product (12 h sessions) → daily reopen habit → App Open Ad impressions fund free users → conversion moments are *earned* (timer expiry, premium theme tap, theme save), each deep-linking the paywall with context → lifetime anchor pricing. KPIs: D1/D7/D30 retention, activation rate, expiry→reopen rate, paywall view→purchase ≥ 3% target, refund rate < 2%.

---

## 17. Analytics

Thin first-party pipeline: `AnalyticsService` → local queue (Isar) → batched `POST /v1/analytics/events` (≤ 50 events or 30 s, whichever first; flush on background). Anonymous by `device_id`; `user_id` attached only if signed in. **Event names below are the canonical contract** (backend doc §6.9 ingests them verbatim).

| Event | Properties | Answers |
|---|---|---|
| `app_open` | `source` (icon/notification/expiry_notice), `entitlement` | DAU, reopen loops |
| `onboarding_completed` | `skipped_pages` | Funnel |
| `permission_result` | `permission`, `granted` | Drop-off |
| `feature_activated` | `feature` (floating_button/notification_slider), `entitlement` | Core activation |
| `feature_deactivated` | `feature`, `reason` (user/timer/oem_kill_detected) | Health + OEM pain |
| `timer_expired` | `feature`, `session_hours` | Free-loop mechanics |
| `radial_opened` | `duration_ms`, `stream` | Engagement depth |
| `volume_changed` | `source` (radial/notification), `stream`, `delta` | Which surface wins |
| `theme_applied` | `theme_id`, `is_custom` | Theme popularity (feeds trending, backend §10) |
| `theme_created` | `based_on` | Editor usage |
| `customization_changed` | `property` | Which knobs matter |
| `paywall_viewed` | `source` (expiry/theme_gate/save_gate/home_banner/settings) | Conversion attribution |
| `purchase_initiated` / `purchase_completed` / `purchase_failed` | `product_id`, (`error_code`) | Funnel |
| `purchase_restored` | `product_id` | Restore health |
| `ad_shown` / `ad_failed` | `latency_ms` / `error` | Ad ops |
| `session_end` | `duration_s`, `screens_visited` | Session length |
| `settings_reset` | — | Frustration signal |

Retention & crash-rate are derived server-side (backend doc §6.9) and from Sentry release health — no extra client events needed. **No PII in any event.** Analytics off switch honored (Settings → also GDPR-friendly).

---

## 18. Implementation Roadmap

### Phase 0 — Foundation (week 1–2)
Rename package to `app.buttervolume.android`; flavors, CI skeleton, Riverpod/go_router/Isar scaffolding, design tokens, motion constants.

### Phase 1 — MVP core (week 3–6)
Kotlin overlay (drag/snap/persist) + Engine B + morph radial + native volume; SharedPreferences settings write-through; Home + Floating Button Settings; 4 free presets.

### Phase 2 — Feature 2 + free-tier mechanics (week 7–8)
Notification slider service + settings screen; expiry scheduler + reminders + reopen loop; onboarding + permission setup.

### Phase 3 — Monetization + backend integration (week 9–11)
Device registration + entitlement client + offline token; billing + server verification + restore; paywall + unlock animation; App Open Ads with capping; remote config/flags/version-check clients; analytics pipeline.

### Phase 4 — Polish & launch (week 12–14)
All 10 presets + theme editor + optional sign-in + cloud sync; goldens, Test Lab matrix, OEM QA; store assets; internal → beta → staged production.

### Future roadmap (post-1.0, in rough priority order)
1. **Brightness control** — second arc / mode toggle in the radial (same overlay infra).
2. **Media controls** — track title + prev/play/next in expanded radial via `MediaSession` (needs `NOTIFICATION_LISTENER` — big permission, keep optional).
3. **Custom gestures** — single-tap/double-tap/swipe-on-button actions (mute, stream cycle, flashlight?).
4. **Rewarded "+12 h" experiment** — backend-flagged.
5. **Widget support** — Glance-based home-screen volume widget.
6. **Backup & restore / full cloud sync** — settings (not just themes) via backend (already modeled, backend doc §11).
7. **Automation rules** — "headphones connected → switch stream to media", time-based theme switching.
8. **AI automation (exploratory)** — suggest volume profiles from usage patterns; strictly on-device.
9. **Wear OS** — remote volume tile.
10. **iOS** — evaluate honestly: no overlay APIs on iOS; product becomes "custom volume HUD inside apps that integrate" or Control-Center-adjacent — likely a different product; revisit only with real demand.
11. **Desktop (Windows/macOS)** — tray-based volume orb; the Flutter codebase's domain layer carries over.

---

*End of Flutter Application Documentation. Backend contract details referenced throughout live in `fastapi-backend-documentation.md`.*

package app.buttervolume.android

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import app.buttervolume.android.audio.VolumeController
import app.buttervolume.android.channels.AppChannels
import app.buttervolume.android.notification.NotificationSliderService
import app.buttervolume.android.overlay.OverlayService
import app.buttervolume.android.timers.FeatureExpiryScheduler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val RC_NOTIFICATIONS = 1001
    }

    private var pendingNotificationResult: MethodChannel.Result? = null

    /** Engine A comes from the shared FlutterEngineGroup (doc §3.3). */
    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine =
        EngineHost.createMainEngine(context)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val volume = VolumeController(this)

        // ---- Feature 1 control (doc §6.2) ----
        MethodChannel(messenger, AppChannels.OVERLAY_CONTROL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        result.error("no_permission", "Overlay permission not granted", null)
                    } else {
                        OverlayService.start(this)
                        result.success(null)
                    }
                }
                "stop" -> {
                    OverlayService.stop(this)
                    result.success(null)
                }
                "isRunning" -> result.success(OverlayService.isRunning)
                "refreshStyle" -> {
                    OverlayService.instance?.refreshStyle()
                    result.success(null)
                }
                "resetPosition" -> {
                    OverlayService.instance?.resetPosition()
                        ?: Prefs.native(this).edit().clear().apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ---- Feature 2 control (doc §6.3) ----
        MethodChannel(messenger, AppChannels.SLIDER_CONTROL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    NotificationSliderService.start(this)
                    result.success(null)
                }
                "stop" -> {
                    NotificationSliderService.stop(this)
                    result.success(null)
                }
                "isRunning" -> result.success(NotificationSliderService.isRunning)
                "refresh" -> {
                    NotificationSliderService.instance?.rerender()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ---- Volume ops for the main app UI ----
        MethodChannel(messenger, AppChannels.VOLUME).setMethodCallHandler { call, result ->
            val stream = call.argument<String>("stream") ?: "media"
            when (call.method) {
                "getPercent" -> result.success(volume.getPercent(stream))
                "setPercent" -> {
                    volume.setPercent(stream, call.argument<Double>("percent") ?: 0.0)
                    result.success(null)
                }
                "maxSteps" -> result.success(volume.maxSteps(stream))
                "toggleMute" -> {
                    volume.toggleMute(stream)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ---- Free-tier expiry alarms (doc §6.1) ----
        MethodChannel(messenger, AppChannels.TIMERS).setMethodCallHandler { call, result ->
            val feature = call.argument<String>("feature") ?: ""
            when (call.method) {
                "scheduleExpiry" -> {
                    val atMs = call.argument<Long>("atMs")
                        ?: call.argument<Int>("atMs")?.toLong() ?: 0L
                    FeatureExpiryScheduler.schedule(this, feature, atMs)
                    result.success(null)
                }
                "cancelExpiry" -> {
                    FeatureExpiryScheduler.cancel(this, feature)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ---- Permissions (doc §12) ----
        MethodChannel(messenger, AppChannels.PERMISSIONS).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlay" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlay" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"),
                        ),
                    )
                    result.success(null)
                }
                "hasNotifications" -> result.success(
                    getSystemService(android.app.NotificationManager::class.java)
                        .areNotificationsEnabled(),
                )
                "requestNotifications" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        pendingNotificationResult = result
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            RC_NOTIFICATIONS,
                        )
                    } else {
                        result.success(
                            getSystemService(android.app.NotificationManager::class.java)
                                .areNotificationsEnabled(),
                        )
                    }
                }
                "isIgnoringBatteryOptimizations" -> result.success(
                    getSystemService(PowerManager::class.java)
                        .isIgnoringBatteryOptimizations(packageName),
                )
                "openBatterySettings" -> {
                    // The general list, not the direct exemption dialog — the
                    // direct request permission is Play-restricted (doc §13.4).
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        @Suppress("DEPRECATION")
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RC_NOTIFICATIONS) {
            pendingNotificationResult?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
            )
            pendingNotificationResult = null
        }
    }
}

package app.buttervolume.android.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.os.Build
import android.os.IBinder
import app.buttervolume.android.EngineHost
import app.buttervolume.android.MainActivity
import app.buttervolume.android.Prefs
import app.buttervolume.android.audio.VolumeController
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine

/**
 * Feature 1 foreground service (doc §6.2): owns FlutterEngine B, the overlay
 * window and the gesture pipeline. Independent from the notification-slider
 * service so each feature stops on its own (doc §13.6).
 */
class OverlayService : Service() {

    companion object {
        const val CHANNEL_ID = "bv_overlay"
        const val NOTIFICATION_ID = 101

        @Volatile
        var instance: OverlayService? = null
            private set

        val isRunning: Boolean get() = instance != null

        fun start(context: Context) {
            context.startForegroundService(Intent(context, OverlayService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, OverlayService::class.java))
        }
    }

    private lateinit var engine: FlutterEngine
    private lateinit var flutterView: FlutterView
    private lateinit var window: OverlayWindow
    private lateinit var touch: OverlayTouchController
    private lateinit var channels: OverlayChannels

    override fun onCreate() {
        super.onCreate()
        instance = this
        startInForeground()

        engine = EngineHost.createOverlayEngine(this)
        engine.lifecycleChannel.appIsResumed()

        flutterView = FlutterView(this, FlutterTextureView(this).apply { isOpaque = false })

        window = OverlayWindow(this, flutterView) { ev -> touch.onTouch(ev) }

        channels = OverlayChannels(
            engine,
            this,
            VolumeController(this),
            onCollapsed = { window.collapseToIdle() },
            onHapticTick = { touch.tickHaptic() },
        )

        touch = OverlayTouchController(
            this,
            window,
            object : OverlayTouchController.Listener {
                override fun onTapped() = channels.emitTapped()
                override fun onRadialOpened(info: OverlayWindow.ExpandInfo) =
                    channels.emitRadialOpen(info)

                override fun onRadialDrag(dxDp: Float, dyDp: Float) =
                    channels.emitDrag(dxDp, dyDp)

                override fun onRadialReleased() = channels.emitRelease()
                override fun onRadialCancelled() {
                    channels.emitCancel()
                    window.collapseToIdle()
                }
            },
        )

        flutterView.attachToFlutterEngine(engine)
        window.show()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY

    override fun onDestroy() {
        touch.cancel()
        window.destroy()
        flutterView.detachFromFlutterEngine()
        engine.destroy()
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        window.onScreenChanged()
    }

    /** Live customization push (doc §6.2.3). */
    fun refreshStyle() {
        window.applyButtonSize(Prefs.buttonSizeDp(this))
        channels.emitStyleChanged()
    }

    fun resetPosition() = window.resetPosition()

    /** Session countdown shown for free users (updated again by M3 timers). */
    fun updateNotification(text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun startInForeground() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Floating button",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { setShowBadge(false) },
        )
        val notification = buildNotification("Floating volume button is active")
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(text: String): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setContentTitle("Butter Volume")
            .setContentText(text)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .build()
    }
}

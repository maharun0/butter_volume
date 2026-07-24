package app.buttervolume.android.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import app.buttervolume.android.audio.VolumeController

/**
 * Feature 2 foreground service (doc §6.3): persistent notification volume
 * controls. Fully independent from OverlayService (doc §13.6).
 */
class NotificationSliderService : Service() {

    companion object {
        const val CHANNEL_ID = "bv_slider"
        const val NOTIFICATION_ID = 102
        private const val RENDER_THROTTLE_MS = 250L

        @Volatile
        var instance: NotificationSliderService? = null
            private set

        val isRunning: Boolean get() = instance != null

        fun start(context: Context) {
            context.startForegroundService(
                Intent(context, NotificationSliderService::class.java),
            )
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, NotificationSliderService::class.java))
        }
    }

    private lateinit var volume: VolumeController
    private lateinit var builder: SliderNotificationBuilder
    private val handler = Handler(Looper.getMainLooper())
    private var lastRender = 0L
    private var renderQueued = false

    /** Keeps the bar in sync with hardware keys / the floating button (doc §6.3). */
    private val volumeChangedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == "android.media.VOLUME_CHANGED_ACTION") rerender()
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        volume = VolumeController(this)
        builder = SliderNotificationBuilder(this, CHANNEL_ID)

        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Volume slider",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                setShowBadge(false)
                setSound(null, null)
            },
        )

        val notification = builder.build(volume)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        registerReceiver(
            volumeChangedReceiver,
            IntentFilter("android.media.VOLUME_CHANGED_ACTION"),
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY

    override fun onDestroy() {
        runCatching { unregisterReceiver(volumeChangedReceiver) }
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /** Throttled to ≤ 4 renders/s (doc §6.3). */
    fun rerender() {
        val now = System.currentTimeMillis()
        val elapsed = now - lastRender
        if (elapsed >= RENDER_THROTTLE_MS) {
            lastRender = now
            postNotification()
        } else if (!renderQueued) {
            renderQueued = true
            handler.postDelayed({
                renderQueued = false
                lastRender = System.currentTimeMillis()
                postNotification()
            }, RENDER_THROTTLE_MS - elapsed)
        }
    }

    private fun postNotification() {
        // Also the swipe-away recovery: re-posting brings the controls back
        // on the next volume change (doc §6.3, Android 13+).
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, builder.build(volume))
    }
}

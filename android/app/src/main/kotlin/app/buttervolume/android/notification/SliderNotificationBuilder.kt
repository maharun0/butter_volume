package app.buttervolume.android.notification

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import app.buttervolume.android.MainActivity
import app.buttervolume.android.Prefs
import app.buttervolume.android.R
import app.buttervolume.android.audio.VolumeController
import org.json.JSONObject
import kotlin.math.roundToInt

/**
 * Builds the compact + expanded RemoteViews notification (doc §6.3).
 * Config comes from the `slider.config` pref JSON written by the app.
 */
class SliderNotificationBuilder(
    private val context: Context,
    private val channelId: String,
) {

    private fun config(): JSONObject =
        try {
            JSONObject(Prefs.getString(context, Prefs.KEY_SLIDER_CONFIG) ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }

    fun build(volume: VolumeController): Notification {
        val cfg = config()
        val stream = cfg.optString("stream", "media")
        val percent = (volume.getPercent(stream) * 100).roundToInt()
        val muted = volume.isMuted(stream)
        val expandedMode = cfg.optString("layout", "expanded") == "expanded"

        val compact = fillRow(
            RemoteViews(context.packageName, R.layout.notif_slider_compact),
            cfg, stream, percent, muted,
        )

        val builder = Notification.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(compact)
            .setContentIntent(openAppIntent())
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)

        if (expandedMode) {
            val expanded = fillRow(
                RemoteViews(context.packageName, R.layout.notif_slider_expanded),
                cfg, stream, percent, muted,
            )
            fillExpanded(expanded, cfg, stream)
            builder.setCustomBigContentView(expanded)
        }

        // Free-tier session countdown surfaces here too (doc §6.1 step 2).
        val expiry = Prefs.getLong(context, Prefs.expiryKey("notification_slider"))
        if (expiry > 0 && !Prefs.getBool(context, Prefs.KEY_IS_PREMIUM)) {
            val remainingMin = (expiry - System.currentTimeMillis()) / 60000
            if (remainingMin in 1..30) {
                builder.setSubText("Session ending soon — open Butter Volume")
            }
        }

        return builder.build()
    }

    private fun fillRow(
        views: RemoteViews,
        cfg: JSONObject,
        stream: String,
        percent: Int,
        muted: Boolean,
    ): RemoteViews {
        views.setProgressBar(R.id.volume_bar, 100, percent, false)
        views.setTextViewText(R.id.volume_label, "$percent%")
        views.setImageViewResource(
            R.id.btn_mute,
            if (muted) android.R.drawable.ic_lock_silent_mode
            else android.R.drawable.ic_lock_silent_mode_off,
        )
        val showMute = cfg.optBoolean("showMute", true)
        views.setViewVisibility(
            R.id.btn_mute,
            if (showMute) android.view.View.VISIBLE else android.view.View.GONE,
        )
        views.setOnClickPendingIntent(
            R.id.btn_mute,
            action(NotificationActionReceiver.ACTION_MUTE, stream),
        )
        views.setOnClickPendingIntent(
            R.id.btn_down,
            action(NotificationActionReceiver.ACTION_DOWN, stream),
        )
        views.setOnClickPendingIntent(
            R.id.btn_up,
            action(NotificationActionReceiver.ACTION_UP, stream),
        )
        return views
    }

    private fun fillExpanded(views: RemoteViews, cfg: JSONObject, stream: String) {
        val enabled = cfg.optJSONArray("presets")
        val wanted: Set<Int> = if (enabled == null) {
            setOf(0, 25, 50, 75, 100)
        } else {
            buildSet { for (i in 0 until enabled.length()) add(enabled.getInt(i)) }
        }
        val ids = mapOf(
            0 to R.id.preset_0,
            25 to R.id.preset_25,
            50 to R.id.preset_50,
            75 to R.id.preset_75,
            100 to R.id.preset_100,
        )
        for ((pct, id) in ids) {
            if (wanted.contains(pct)) {
                views.setViewVisibility(id, android.view.View.VISIBLE)
                views.setOnClickPendingIntent(
                    id,
                    action(NotificationActionReceiver.ACTION_PRESET, stream, pct),
                )
            } else {
                views.setViewVisibility(id, android.view.View.GONE)
            }
        }
        views.setTextViewText(
            R.id.stream_label,
            stream.replaceFirstChar { it.uppercase() } + " volume",
        )
        views.setViewVisibility(
            R.id.stream_label,
            if (cfg.optBoolean("showStream", true)) android.view.View.VISIBLE
            else android.view.View.GONE,
        )
    }

    private fun action(action: String, stream: String, percent: Int = -1): PendingIntent {
        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            this.action = action
            putExtra(NotificationActionReceiver.EXTRA_STREAM, stream)
            if (percent >= 0) putExtra(NotificationActionReceiver.EXTRA_PERCENT, percent)
        }
        // Distinct requestCodes so PendingIntents don't collapse into one.
        val requestCode = action.hashCode() + percent
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}

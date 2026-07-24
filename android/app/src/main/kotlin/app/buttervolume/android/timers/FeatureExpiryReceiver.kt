package app.buttervolume.android.timers

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import app.buttervolume.android.MainActivity
import app.buttervolume.android.Prefs
import app.buttervolume.android.notification.NotificationSliderService
import app.buttervolume.android.overlay.OverlayService

/**
 * Free-tier expiry (doc §6.1 steps 3–4): stops only the matching feature's
 * service, clears its prefs, and posts a gentle "reopen to reactivate"
 * notification that feeds the reopen loop.
 */
class FeatureExpiryReceiver : BroadcastReceiver() {

    companion object {
        private const val STATUS_CHANNEL_ID = "bv_status"
        private const val STATUS_ID_BASE = 200
    }

    override fun onReceive(context: Context, intent: Intent) {
        val feature = intent.getStringExtra(FeatureExpiryScheduler.EXTRA_FEATURE) ?: return

        when (intent.action) {
            FeatureExpiryScheduler.ACTION_REMIND -> remind(feature)

            FeatureExpiryScheduler.ACTION_EXPIRE -> {
                // Premium flipped since scheduling? Never expire premium.
                if (Prefs.getBool(context, Prefs.KEY_IS_PREMIUM)) return
                when (feature) {
                    "floating_button" -> OverlayService.stop(context)
                    "notification_slider" -> NotificationSliderService.stop(context)
                    else -> return
                }
                Prefs.setBool(context, Prefs.featureEnabledKey(feature), false)
                Prefs.setLong(context, Prefs.expiryKey(feature), 0L)
                postExpiredNotification(context, feature)
            }
        }
    }

    private fun remind(feature: String) {
        when (feature) {
            "floating_button" -> OverlayService.instance?.updateNotification(
                "Session ending soon — open Butter Volume to extend",
            )
            // Slider notification reads the expiry pref on its next render.
            "notification_slider" -> NotificationSliderService.instance?.rerender()
        }
    }

    private fun postExpiredNotification(context: Context, feature: String) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                STATUS_CHANNEL_ID,
                "Session status",
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
        val label =
            if (feature == "floating_button") "floating button" else "notification slider"
        val contentIntent = PendingIntent.getActivity(
            context,
            feature.hashCode(),
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = Notification.Builder(context, STATUS_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setContentTitle("Session ended")
            .setContentText("Your $label session ended — tap to start a new one.")
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()
        nm.notify(STATUS_ID_BASE + feature.hashCode() % 50, notification)
    }
}

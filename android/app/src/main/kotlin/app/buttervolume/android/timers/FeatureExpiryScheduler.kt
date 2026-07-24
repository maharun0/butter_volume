package app.buttervolume.android.timers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * Free-tier 12 h session alarms (doc §6.1). Windowed inexact (±10 min) —
 * precise enough for the product, and needs no SCHEDULE_EXACT_ALARM
 * permission (doc §12 recommendation: ship without it).
 */
object FeatureExpiryScheduler {

    const val ACTION_EXPIRE = "app.buttervolume.android.action.EXPIRE"
    const val ACTION_REMIND = "app.buttervolume.android.action.REMIND"
    const val EXTRA_FEATURE = "feature"

    private const val WINDOW_MS = 10 * 60_000L
    private const val REMIND_LEAD_MS = 30 * 60_000L

    fun schedule(context: Context, feature: String, atMs: Long) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        alarm.setWindow(
            AlarmManager.RTC_WAKEUP,
            atMs,
            WINDOW_MS,
            pending(context, feature, ACTION_EXPIRE),
        )
        // T−30 min "session ending soon" reminder (doc §6.1 step 2).
        val remindAt = atMs - REMIND_LEAD_MS
        if (remindAt > System.currentTimeMillis()) {
            alarm.setWindow(
                AlarmManager.RTC_WAKEUP,
                remindAt,
                WINDOW_MS,
                pending(context, feature, ACTION_REMIND),
            )
        }
    }

    fun cancel(context: Context, feature: String) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        alarm.cancel(pending(context, feature, ACTION_EXPIRE))
        alarm.cancel(pending(context, feature, ACTION_REMIND))
    }

    private fun pending(context: Context, feature: String, action: String): PendingIntent {
        val intent = Intent(context, FeatureExpiryReceiver::class.java).apply {
            this.action = action
            putExtra(EXTRA_FEATURE, feature)
        }
        return PendingIntent.getBroadcast(
            context,
            action.hashCode() + feature.hashCode(),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}

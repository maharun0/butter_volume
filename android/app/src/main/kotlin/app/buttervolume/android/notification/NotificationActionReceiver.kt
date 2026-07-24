package app.buttervolume.android.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import app.buttervolume.android.Prefs
import app.buttervolume.android.audio.VolumeController
import org.json.JSONObject

/** Handles mute / − / + / preset taps from the slider notification (doc §6.3). */
class NotificationActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_MUTE = "app.buttervolume.android.action.MUTE"
        const val ACTION_DOWN = "app.buttervolume.android.action.VOL_DOWN"
        const val ACTION_UP = "app.buttervolume.android.action.VOL_UP"
        const val ACTION_PRESET = "app.buttervolume.android.action.PRESET"
        const val EXTRA_STREAM = "stream"
        const val EXTRA_PERCENT = "percent"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val volume = VolumeController(context)
        val stream = intent.getStringExtra(EXTRA_STREAM) ?: "media"

        when (intent.action) {
            ACTION_MUTE -> volume.toggleMute(stream)

            ACTION_DOWN, ACTION_UP -> {
                val sign = if (intent.action == ACTION_UP) 1 else -1
                val stepPercent = stepPercent(context)
                val current = volume.getPercent(stream)
                val next = if (stepPercent == 0) {
                    // Step size "1 step" = one discrete AudioManager index.
                    val max = volume.maxSteps(stream)
                    if (max > 0) current + sign * (1.0 / max) else current
                } else {
                    current + sign * (stepPercent / 100.0)
                }
                volume.setPercent(stream, next)
            }

            ACTION_PRESET -> {
                val pct = intent.getIntExtra(EXTRA_PERCENT, -1)
                if (pct >= 0) volume.setPercent(stream, pct / 100.0)
            }

            else -> return
        }

        NotificationSliderService.instance?.rerender()
    }

    private fun stepPercent(context: Context): Int =
        try {
            JSONObject(Prefs.getString(context, Prefs.KEY_SLIDER_CONFIG) ?: "{}")
                .optInt("stepPercent", 10)
        } catch (_: Exception) {
            10
        }
}

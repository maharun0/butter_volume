package app.buttervolume.android.audio

import android.content.Context
import android.media.AudioManager
import kotlin.math.roundToInt

/**
 * AudioManager wrapper with stream switching (doc §4 volume-control row).
 * DND edge case: adjusting ring/notification while a DND rule blocks it
 * throws SecurityException — swallowed here; the app surfaces a contextual
 * DND-access card instead (doc §12).
 */
class VolumeController(context: Context) {

    private val audio = context.applicationContext
        .getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun streamOf(id: String): Int = when (id) {
        "ring" -> AudioManager.STREAM_RING
        "alarm" -> AudioManager.STREAM_ALARM
        "notification" -> AudioManager.STREAM_NOTIFICATION
        "call" -> AudioManager.STREAM_VOICE_CALL
        else -> AudioManager.STREAM_MUSIC
    }

    fun getPercent(streamId: String): Double {
        val stream = streamOf(streamId)
        val max = audio.getStreamMaxVolume(stream)
        if (max <= 0) return 0.0
        return audio.getStreamVolume(stream).toDouble() / max
    }

    fun setPercent(streamId: String, percent: Double) {
        val stream = streamOf(streamId)
        val max = audio.getStreamMaxVolume(stream)
        val index = (percent.coerceIn(0.0, 1.0) * max).roundToInt()
        try {
            audio.setStreamVolume(stream, index, 0 /* no system UI */)
        } catch (_: SecurityException) {
            // DND policy blocked the change (doc §12 DND row).
        }
    }

    /** Number of discrete steps for haptic ticks (doc §6.2.2). */
    fun maxSteps(streamId: String): Int = audio.getStreamMaxVolume(streamOf(streamId))

    fun toggleMute(streamId: String) {
        try {
            audio.adjustStreamVolume(
                streamOf(streamId),
                AudioManager.ADJUST_TOGGLE_MUTE,
                0,
            )
        } catch (_: SecurityException) {
        }
    }

    fun isMuted(streamId: String): Boolean =
        audio.isStreamMute(streamOf(streamId))
}

package app.buttervolume.android.overlay

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import app.buttervolume.android.Prefs
import app.buttervolume.android.audio.VolumeController
import app.buttervolume.android.channels.AppChannels
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Engine-B channel wiring (doc §5 OverlayChannels): the window method channel
 * (Dart → service), the gesture event stream (service → Dart) and volume ops.
 */
class OverlayChannels(
    engine: FlutterEngine,
    private val context: Context,
    private val volume: VolumeController,
    private val onCollapsed: () -> Unit,
    private val onHapticTick: () -> Unit,
) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, AppChannels.OVERLAY_WINDOW)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getState" -> result.success(stateMap())
                    "collapsed" -> {
                        onCollapsed()
                        result.success(null)
                    }
                    "haptic" -> {
                        when (call.argument<String>("kind")) {
                            "tick" -> onHapticTick()
                            else -> Unit
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, AppChannels.OVERLAY_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(engine.dartExecutor.binaryMessenger, AppChannels.VOLUME)
            .setMethodCallHandler { call, result ->
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
    }

    private fun stateMap(): Map<String, Any?> {
        val behavior = Prefs.behavior(context)
        val stream = behavior.optString("stream", "media")
        return mapOf(
            "themeJson" to Prefs.getString(context, Prefs.KEY_OVERLAY_THEME),
            "behaviorJson" to Prefs.getString(context, Prefs.KEY_OVERLAY_BEHAVIOR),
            "volumePercent" to volume.getPercent(stream),
            "maxSteps" to volume.maxSteps(stream),
        )
    }

    private fun emit(event: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(event) }
    }

    fun emitRadialOpen(info: OverlayWindow.ExpandInfo) {
        val behavior = Prefs.behavior(context)
        val stream = behavior.optString("stream", "media")
        val metrics = context.resources.displayMetrics
        emit(
            mapOf(
                "type" to "radialOpen",
                "centerX" to info.centerXDp.toDouble(),
                "centerY" to info.centerYDp.toDouble(),
                "windowW" to info.widthDp.toDouble(),
                "windowH" to info.heightDp.toDouble(),
                "screenH" to (metrics.heightPixels / metrics.density).toDouble(),
                "volumePercent" to volume.getPercent(stream),
                "maxSteps" to volume.maxSteps(stream),
            ),
        )
    }

    fun emitDrag(dxDp: Float, dyDp: Float) = emit(
        mapOf("type" to "drag", "dx" to dxDp.toDouble(), "dy" to dyDp.toDouble()),
    )

    fun emitRelease() = emit(mapOf("type" to "release"))

    fun emitCancel() = emit(mapOf("type" to "cancel"))

    fun emitTapped() = emit(mapOf("type" to "tapped"))

    fun emitStyleChanged() = emit(
        mapOf(
            "type" to "styleChanged",
            "themeJson" to Prefs.getString(context, Prefs.KEY_OVERLAY_THEME),
            "behaviorJson" to Prefs.getString(context, Prefs.KEY_OVERLAY_BEHAVIOR),
        ),
    )
}

/** Haptic constants used from the service side. */
object OverlayHaptics {
    const val TICK = HapticFeedbackConstants.CLOCK_TICK
}

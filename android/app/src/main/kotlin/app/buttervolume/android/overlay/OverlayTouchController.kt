package app.buttervolume.android.overlay

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.ViewConfiguration
import app.buttervolume.android.Prefs

/**
 * Gesture disambiguation on the overlay window (doc §6.2.2):
 *
 *   down ─┬─ move > slop before 350 ms ──► DRAG (native window move)
 *         ├─ 350 ms elapses ────────────► RADIAL (expand + forward moves)
 *         └─ up before either ──────────► TAP (micro-acknowledge only)
 */
class OverlayTouchController(
    private val context: Context,
    private val window: OverlayWindow,
    private val listener: Listener,
) {

    interface Listener {
        fun onTapped()
        fun onRadialOpened(info: OverlayWindow.ExpandInfo)
        fun onRadialDrag(dxDp: Float, dyDp: Float)
        fun onRadialReleased()
        fun onRadialCancelled()
    }

    private enum class State { IDLE, PRESSED, DRAGGING, RADIAL }

    companion object {
        private const val LONG_PRESS_MS = 350L
    }

    private val density = context.resources.displayMetrics.density
    private val slop = ViewConfiguration.get(context).scaledTouchSlop
    private val handler = Handler(Looper.getMainLooper())

    private var state = State.IDLE
    private var downRawX = 0f
    private var downRawY = 0f
    private var lastRawX = 0f
    private var lastRawY = 0f
    private var radialStartX = 0f
    private var radialStartY = 0f

    private val longPressRunnable = Runnable {
        if (state != State.PRESSED) return@Runnable
        state = State.RADIAL
        radialStartX = lastRawX
        radialStartY = lastRawY
        if (Prefs.behavior(context).optBoolean("longPressHaptic", true)) {
            window.performHaptic(HapticFeedbackConstants.LONG_PRESS)
        }
        listener.onRadialOpened(window.expand())
    }

    fun onTouch(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                window.wake()
                state = State.PRESSED
                downRawX = event.rawX
                downRawY = event.rawY
                lastRawX = downRawX
                lastRawY = downRawY
                handler.postDelayed(longPressRunnable, LONG_PRESS_MS)
            }

            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - lastRawX
                val dy = event.rawY - lastRawY
                lastRawX = event.rawX
                lastRawY = event.rawY
                when (state) {
                    State.PRESSED -> {
                        val totalDx = event.rawX - downRawX
                        val totalDy = event.rawY - downRawY
                        if (totalDx * totalDx + totalDy * totalDy > slop * slop) {
                            handler.removeCallbacks(longPressRunnable)
                            state = State.DRAGGING
                            window.moveBy(dx, dy)
                        }
                    }

                    State.DRAGGING -> window.moveBy(dx, dy)

                    State.RADIAL -> listener.onRadialDrag(
                        (event.rawX - radialStartX) / density,
                        (event.rawY - radialStartY) / density,
                    )

                    State.IDLE -> Unit
                }
            }

            MotionEvent.ACTION_UP -> {
                handler.removeCallbacks(longPressRunnable)
                when (state) {
                    State.PRESSED -> listener.onTapped()
                    State.DRAGGING -> window.endDrag()
                    State.RADIAL -> listener.onRadialReleased()
                    State.IDLE -> Unit
                }
                state = State.IDLE
            }

            MotionEvent.ACTION_CANCEL -> {
                handler.removeCallbacks(longPressRunnable)
                if (state == State.RADIAL) listener.onRadialCancelled()
                if (state == State.DRAGGING) window.endDrag()
                state = State.IDLE
            }
        }
        return true
    }

    /** External cancel (screen off, service stopping — doc §6.2.2). */
    fun cancel() {
        handler.removeCallbacks(longPressRunnable)
        if (state == State.RADIAL) listener.onRadialCancelled()
        state = State.IDLE
    }

    fun tickHaptic() {
        if (Prefs.behavior(context).optBoolean("hapticTicks", true)) {
            window.performHaptic(HapticFeedbackConstants.CLOCK_TICK)
        }
    }
}

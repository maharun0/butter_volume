package app.buttervolume.android.overlay

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Point
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import app.buttervolume.android.Prefs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Owns the TYPE_APPLICATION_OVERLAY window (doc §6.2.1):
 *  - small idle window (button + shadow padding), expanded only while the
 *    radial is open — smaller surfaces composite cheaper;
 *  - drag handled natively (no Dart round-trip per frame);
 *  - edge snap with overshoot; position persisted as (edge, fractions) so it
 *    survives rotation and reboots;
 *  - optional peek mode (shrink to edge after 4 s idle).
 */
class OverlayWindow(
    private val context: Context,
    flutterView: View,
    private val onTouch: (MotionEvent) -> Boolean,
) {

    /** Container that swallows every touch — the FlutterView only renders. */
    @SuppressLint("ViewConstructor")
    private class TouchLayout(
        context: Context,
        private val handler: (MotionEvent) -> Boolean,
    ) : FrameLayout(context) {
        override fun onInterceptTouchEvent(ev: MotionEvent): Boolean = true

        @SuppressLint("ClickableViewAccessibility")
        override fun onTouchEvent(event: MotionEvent): Boolean = handler(event)
    }

    companion object {
        private const val IDLE_PAD_DP = 14f
        private const val RING_FACTOR = 2.4f
        private const val EXPAND_PAD_DP = 22f
        private const val EDGE_MARGIN_DP = 2f
        private const val PEEK_DELAY_MS = 4000L
        private const val PEEK_ALPHA = 0.55f

        private const val K_EDGE = "pos.edge"
        private const val K_Y_FRAC = "pos.yFrac"
        private const val K_X_FRAC = "pos.xFrac"
    }

    private val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val density = context.resources.displayMetrics.density
    private val container = TouchLayout(context) { ev -> onTouch(ev) }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var snapAnimator: ValueAnimator? = null
    private var peekRunnable: Runnable? = null
    private var peeking = false

    private var buttonSizeDp = Prefs.buttonSizeDp(context)

    var isExpanded = false
        private set

    private val params = WindowManager.LayoutParams(
        idlePx(), idlePx(),
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT,
    ).apply { gravity = Gravity.TOP or Gravity.START }

    init {
        container.addView(
            flutterView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
    }

    private fun dp(px: Int): Float = px / density
    private fun px(dp: Float): Int = (dp * density).roundToInt()
    private fun idlePx(): Int = px(buttonSizeDp + IDLE_PAD_DP * 2)
    private fun expandedPx(): Int = px(buttonSizeDp * RING_FACTOR + EXPAND_PAD_DP * 2)

    private fun screenSize(): Point {
        if (Build.VERSION.SDK_INT >= 30) {
            val b = wm.currentWindowMetrics.bounds
            return Point(b.width(), b.height())
        }
        @Suppress("DEPRECATION")
        return Point().also { wm.defaultDisplay.getRealSize(it) }
    }

    // ---- lifecycle ----

    fun show() {
        restorePosition()
        wm.addView(container, params)
        schedulePeek()
    }

    fun destroy() {
        cancelPeek()
        snapAnimator?.cancel()
        runCatching { wm.removeView(container) }
    }

    /** Re-clamp after rotation using persisted fractions. */
    fun onScreenChanged() {
        if (isExpanded) return
        restorePosition()
        runCatching { wm.updateViewLayout(container, params) }
    }

    /** Live size change from the theme editor (doc §6.2.3). */
    fun applyButtonSize(newSizeDp: Float) {
        if (newSizeDp == buttonSizeDp) return
        buttonSizeDp = newSizeDp
        if (!isExpanded) {
            params.width = idlePx()
            params.height = idlePx()
            clampIdle()
            runCatching { wm.updateViewLayout(container, params) }
        }
    }

    // ---- drag / snap (doc §6.2.1) ----

    fun wake() {
        cancelPeek()
        if (peeking) {
            peeking = false
            params.alpha = 1f
            clampIdle()
            runCatching { wm.updateViewLayout(container, params) }
        }
    }

    fun moveBy(dxPx: Float, dyPx: Float) {
        snapAnimator?.cancel()
        params.x += dxPx.roundToInt()
        params.y += dyPx.roundToInt()
        runCatching { wm.updateViewLayout(container, params) }
    }

    fun endDrag() {
        val behavior = Prefs.behavior(context)
        val edgeSnap = behavior.optBoolean("edgeSnap", true)
        val freePlacement = behavior.optBoolean("freePlacement", false)
        clampIdle()
        if (edgeSnap && !freePlacement) {
            val screen = screenSize()
            val margin = px(EDGE_MARGIN_DP)
            val toLeft = params.x + params.width / 2 <= screen.x / 2
            val targetX = if (toLeft) margin else screen.x - params.width - margin
            animateX(targetX) { persistPosition(if (toLeft) "left" else "right") }
        } else {
            runCatching { wm.updateViewLayout(container, params) }
            persistPosition("free")
        }
        schedulePeek()
    }

    private fun animateX(targetX: Int, onEnd: () -> Unit) {
        snapAnimator?.cancel()
        snapAnimator = ValueAnimator.ofInt(params.x, targetX).apply {
            duration = 250
            interpolator = OvershootInterpolator(1.2f)
            addUpdateListener {
                params.x = it.animatedValue as Int
                runCatching { wm.updateViewLayout(container, params) }
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) = onEnd()
            })
            start()
        }
    }

    private fun clampIdle() {
        val screen = screenSize()
        params.x = max(-params.width / 3, min(params.x, screen.x - params.width * 2 / 3))
        params.y = max(0, min(params.y, screen.y - params.height))
    }

    // ---- position persistence (normalized, doc §6.2.1) ----

    private fun persistPosition(edge: String) {
        val screen = screenSize()
        val yFrac = params.y.toFloat() / max(1, screen.y - params.height)
        val xFrac = params.x.toFloat() / max(1, screen.x - params.width)
        Prefs.native(context).edit()
            .putString(K_EDGE, edge)
            .putFloat(K_Y_FRAC, yFrac.coerceIn(0f, 1f))
            .putFloat(K_X_FRAC, xFrac.coerceIn(0f, 1f))
            .apply()
    }

    private fun restorePosition() {
        val native = Prefs.native(context)
        val screen = screenSize()
        val size = idlePx()
        params.width = size
        params.height = size
        val yFrac = native.getFloat(K_Y_FRAC, 0.35f)
        params.y = (yFrac * (screen.y - size)).roundToInt()
        params.x = when (native.getString(K_EDGE, "right")) {
            "left" -> px(EDGE_MARGIN_DP)
            "free" -> (native.getFloat(K_X_FRAC, 0.9f) * (screen.x - size)).roundToInt()
            else -> screen.x - size - px(EDGE_MARGIN_DP)
        }
    }

    fun resetPosition() {
        Prefs.native(context).edit().clear().apply()
        if (!isExpanded) {
            restorePosition()
            runCatching { wm.updateViewLayout(container, params) }
        }
    }

    // ---- radial expand/collapse (doc §6.2.2) ----

    /** Geometry handed to Dart so the ring morphs from the true button spot. */
    data class ExpandInfo(
        val centerXDp: Float,
        val centerYDp: Float,
        val widthDp: Float,
        val heightDp: Float,
    )

    fun expand(): ExpandInfo {
        cancelPeek()
        snapAnimator?.cancel()
        val screen = screenSize()
        val idle = params.width
        val centerX = params.x + idle / 2
        val centerY = params.y + idle / 2
        val size = expandedPx()
        val originX = max(0, min(centerX - size / 2, screen.x - size))
        val originY = max(0, min(centerY - size / 2, screen.y - size))
        params.x = originX
        params.y = originY
        params.width = size
        params.height = size
        isExpanded = true
        runCatching { wm.updateViewLayout(container, params) }
        return ExpandInfo(
            centerXDp = dp(centerX - originX),
            centerYDp = dp(centerY - originY),
            widthDp = dp(size),
            heightDp = dp(size),
        )
    }

    /** Called after Dart finishes the collapse animation (doc §6.2.2 step 4). */
    fun collapseToIdle() {
        if (!isExpanded) return
        val size = idlePx()
        // Keep the button visually in place: expanded window was centered on it.
        val centerX = params.x + params.width / 2
        val centerY = params.y + params.height / 2
        params.width = size
        params.height = size
        params.x = centerX - size / 2
        params.y = centerY - size / 2
        isExpanded = false
        clampIdle()
        runCatching { wm.updateViewLayout(container, params) }
        endDrag() // re-snap + persist + peek scheduling
    }

    // ---- peek mode (doc §6.2.1 idle behavior) ----

    private fun schedulePeek() {
        cancelPeek()
        val behavior = Prefs.behavior(context)
        if (!behavior.optBoolean("peekMode", false)) return
        if (behavior.optBoolean("freePlacement", false)) return
        val r = Runnable {
            if (isExpanded) return@Runnable
            val screen = screenSize()
            val hidden = (params.width * 0.6f).roundToInt()
            val onLeft = params.x + params.width / 2 <= screen.x / 2
            params.x = if (onLeft) -hidden else screen.x - params.width + hidden
            params.alpha = PEEK_ALPHA
            peeking = true
            runCatching { wm.updateViewLayout(container, params) }
        }
        peekRunnable = r
        mainHandler.postDelayed(r, PEEK_DELAY_MS)
    }

    private fun cancelPeek() {
        peekRunnable?.let { mainHandler.removeCallbacks(it) }
        peekRunnable = null
    }

    fun performHaptic(feedbackConstant: Int) {
        container.performHapticFeedback(feedbackConstant)
    }
}

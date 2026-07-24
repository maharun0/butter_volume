package app.buttervolume.android

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * Native access to settings.
 *
 * Two stores:
 *  - Flutter-written settings live in the `FlutterSharedPreferences` file with
 *    a `flutter.` key prefix (legacy shared_preferences backend — kept on
 *    purpose, doc §4). Native code only reads strings/booleans/longs from it;
 *    doubles use a special Flutter encoding and are avoided cross-language.
 *  - Native-owned state (overlay position) lives in `bv_native`.
 */
object Prefs {
    private const val FLUTTER_FILE = "FlutterSharedPreferences"
    private const val P = "flutter."
    private const val NATIVE_FILE = "bv_native"

    // Flutter-side keys (mirror of SettingsRepository)
    const val KEY_OVERLAY_THEME = "overlay.theme"
    const val KEY_OVERLAY_BEHAVIOR = "overlay.behavior"
    const val KEY_SLIDER_CONFIG = "slider.config"
    const val KEY_IS_PREMIUM = "entitlement.is_premium"
    const val KEY_AUTOSTART = "settings.autostart"

    fun featureEnabledKey(feature: String) = "feature.$feature.enabled"
    fun expiryKey(feature: String) = "expiry.$feature"

    private fun flutter(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(FLUTTER_FILE, Context.MODE_PRIVATE)

    fun native(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(NATIVE_FILE, Context.MODE_PRIVATE)

    fun getString(ctx: Context, key: String): String? =
        flutter(ctx).getString(P + key, null)

    fun getBool(ctx: Context, key: String, def: Boolean = false): Boolean =
        flutter(ctx).getBoolean(P + key, def)

    fun getLong(ctx: Context, key: String, def: Long = 0L): Long =
        try {
            flutter(ctx).getLong(P + key, def)
        } catch (_: ClassCastException) {
            // Dart ints small enough may be stored as Int by older plugin versions.
            flutter(ctx).getInt(P + key, def.toInt()).toLong()
        }

    fun setBool(ctx: Context, key: String, value: Boolean) {
        flutter(ctx).edit().putBoolean(P + key, value).apply()
    }

    fun setLong(ctx: Context, key: String, value: Long) {
        flutter(ctx).edit().putLong(P + key, value).apply()
    }

    /** Button diameter in dp, parsed from the active theme JSON (default 56). */
    fun buttonSizeDp(ctx: Context): Float =
        try {
            val theme = getString(ctx, KEY_OVERLAY_THEME)
            if (theme == null) 56f
            else JSONObject(theme).getJSONObject("button").getDouble("size").toFloat()
        } catch (_: Exception) {
            56f
        }

    /** Behavior flags needed natively (edge snap / free placement / haptics). */
    fun behavior(ctx: Context): JSONObject =
        try {
            JSONObject(getString(ctx, KEY_OVERLAY_BEHAVIOR) ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
}

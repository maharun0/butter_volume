package app.buttervolume.android.timers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import app.buttervolume.android.Prefs
import app.buttervolume.android.notification.NotificationSliderService
import app.buttervolume.android.overlay.OverlayService

/**
 * Reboot behavior (doc §13.6):
 *  - premium + auto-start: relaunch enabled services;
 *  - free: sessions survive reboot — restart services whose session is still
 *    running and re-arm the remaining alarm; clear anything already expired.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val premium = Prefs.getBool(context, Prefs.KEY_IS_PREMIUM)
        val autostart = Prefs.getBool(context, Prefs.KEY_AUTOSTART)
        val now = System.currentTimeMillis()

        for (feature in listOf("floating_button", "notification_slider")) {
            if (!Prefs.getBool(context, Prefs.featureEnabledKey(feature))) continue

            if (premium) {
                if (autostart) startFeature(context, feature)
                continue
            }

            val expiry = Prefs.getLong(context, Prefs.expiryKey(feature))
            if (expiry > now) {
                startFeature(context, feature)
                FeatureExpiryScheduler.schedule(context, feature, expiry)
            } else {
                Prefs.setBool(context, Prefs.featureEnabledKey(feature), false)
                Prefs.setLong(context, Prefs.expiryKey(feature), 0L)
            }
        }
    }

    private fun startFeature(context: Context, feature: String) {
        when (feature) {
            "floating_button" ->
                if (Settings.canDrawOverlays(context)) OverlayService.start(context)
            "notification_slider" -> NotificationSliderService.start(context)
        }
    }
}

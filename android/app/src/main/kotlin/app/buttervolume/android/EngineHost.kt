package app.buttervolume.android

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * One FlutterEngineGroup for the whole process (doc §3.3): engine A (main UI)
 * and engine B (overlay) share the AOT snapshot + isolate group, keeping the
 * second engine at ~10–15 MB instead of a cold ~40 MB.
 */
object EngineHost {

    @Volatile
    private var group: FlutterEngineGroup? = null

    private fun group(context: Context): FlutterEngineGroup =
        group ?: synchronized(this) {
            group ?: FlutterEngineGroup(context.applicationContext).also { group = it }
        }

    /** Engine A — default `main` entrypoint, used by MainActivity. */
    fun createMainEngine(context: Context): FlutterEngine =
        group(context).createAndRunDefaultEngine(context.applicationContext)

    /** Engine B — `overlayMain` entrypoint (doc §13.1 slim import budget). */
    fun createOverlayEngine(context: Context): FlutterEngine =
        group(context).createAndRunEngine(
            context.applicationContext,
            DartExecutor.DartEntrypoint(
                io.flutter.FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "overlayMain",
            ),
        )
}

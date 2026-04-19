// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

package app.gosl.mirkfall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Boot / package-replace receiver for the Plan 05-05 auto-resume path.
 *
 * On `BOOT_COMPLETED` or `MY_PACKAGE_REPLACED`:
 *   1. Warm a background FlutterEngine.
 *   2. Execute the Dart top-level entry point `runBootWatchdogEntryPoint`.
 *   3. Invoke `runWatchdog` on the MethodChannel — Dart side checks the
 *      DB and fires a "tap to resume" notification if an active session
 *      was interrupted at kill time.
 *   4. Destroy the engine + release the broadcast slot.
 *
 * This receiver DOES NOT attempt to start the geolocator foreground
 * service directly. Android 14+ raises a SecurityException when a
 * BroadcastReceiver tries to start a location fg-service without
 * ACCESS_BACKGROUND_LOCATION-at-invocation-time permission
 * (05-RESEARCH.md Pitfall #5). The notification-only path is the
 * compliant design: the user taps the notification -> the activity
 * launches -> the user presses Start from a foreground context, which
 * is then a legitimate fg-service start.
 *
 * Zero third-party dependencies. Uses only:
 *   - Android SDK: BroadcastReceiver, Context, Intent, Log.
 *   - Flutter embedding API: FlutterInjector, FlutterEngine, DartExecutor,
 *     MethodChannel — all shipped by the Flutter engine and pulled in by
 *     the flutter_android Gradle plugin.
 *
 * See [lib/infrastructure/platform/boot_completed_watchdog.dart] for the
 * Dart-side entry point and watchdog logic.
 */
class BootCompletedReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootCompletedReceiver"

        /**
         * MethodChannel name — mirrored in
         * `lib/infrastructure/platform/boot_completed_watchdog.dart` and
         * `ios/Runner/AppDelegate.swift`. Changing this requires updating
         * all three sides in lockstep.
         */
        private const val CHANNEL = "app.gosl.mirkfall/boot_watchdog"

        /**
         * Dart top-level function name — must match the `@pragma(
         * 'vm:entry-point')`-annotated function in
         * `boot_completed_watchdog.dart`.
         */
        private const val ENTRY_POINT = "runBootWatchdogEntryPoint"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }

        // `goAsync()` keeps the broadcast pending while the Flutter engine
        // warms up. BroadcastReceivers have a 10-second max wall-clock
        // budget enforced by Android; the Dart watchdog must complete
        // within that window or the OS will kill the receiver's hosting
        // process. The DB open + single SELECT is well under 1s on
        // consumer-grade hardware; the notification post is a few tens
        // of milliseconds.
        val pendingResult = goAsync()

        try {
            val engine = FlutterEngine(context.applicationContext)
            val appBundlePath = FlutterInjector.instance()
                .flutterLoader()
                .findAppBundlePath()
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(appBundlePath, ENTRY_POINT),
            )
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            channel.invokeMethod("runWatchdog", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    engine.destroy()
                    pendingResult.finish()
                }

                override fun error(code: String, message: String?, details: Any?) {
                    // Dart-side throws during `runWatchdog` are caught +
                    // swallowed by the watchdog body; anything reaching
                    // this callback is an infrastructure-layer issue
                    // (engine warmup failure, channel wiring broken).
                    Log.w(TAG, "Watchdog MethodChannel error: $code $message")
                    engine.destroy()
                    pendingResult.finish()
                }

                override fun notImplemented() {
                    // Dart side did not register the MethodCallHandler
                    // before the Kotlin side invoked. Should not happen
                    // because executeDartEntrypoint blocks until the
                    // entry point returns, but guard anyway.
                    Log.w(TAG, "Watchdog not implemented on Dart side")
                    engine.destroy()
                    pendingResult.finish()
                }
            })
        } catch (t: Throwable) {
            // Engine-warmup failure, applicationContext null, etc. — log
            // + release the pendingResult so the OS does not ANR. The
            // device user will simply not see the resume notification
            // for this boot cycle; they can still re-open the app
            // manually and start their session.
            Log.w(TAG, "Watchdog glue failed (swallowed)", t)
            pendingResult.finish()
        }
    }
}

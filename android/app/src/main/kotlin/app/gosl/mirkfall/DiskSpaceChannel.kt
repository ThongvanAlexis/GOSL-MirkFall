// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

package app.gosl.mirkfall

import android.os.StatFs
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

/**
 * Android side of the Phase 07 disk-space MethodChannel.
 *
 * Dart side: `lib/infrastructure/platform/disk_space_checker.dart`
 * (constant `kDiskSpaceChannelName`).
 *
 * Exposes one method: `freeBytes({path: String}) -> Long` — returns the
 * `availableBytes` reported by Android's `StatFs` for the filesystem
 * hosting [path]. No-ops are impossible here (StatFs either succeeds or
 * throws `IllegalArgumentException` on an invalid path); we forward
 * any IOException via `result.error("IO_ERROR", …)` so the Dart side
 * can surface a structured `DiskSpaceCheckException`.
 */
object DiskSpaceChannel {
    private const val TAG = "DiskSpaceChannel"

    /**
     * MethodChannel name — mirrored in
     * `lib/infrastructure/platform/disk_space_checker.dart`
     * (`kDiskSpaceChannelName`). Any change must land on both sides
     * in the same commit.
     */
    private const val CHANNEL = "app.gosl.mirkfall/disk_space"

    /**
     * Registers the channel handler against [messenger]. Call once per
     * FlutterEngine lifecycle from `MainActivity.configureFlutterEngine`.
     */
    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "freeBytes" -> handleFreeBytes(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleFreeBytes(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "path argument is required", null)
            return
        }
        try {
            val bytes: Long = StatFs(path).availableBytes
            result.success(bytes)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "freeBytes: invalid path $path", e)
            result.error("INVALID_ARGUMENT", e.message, null)
        } catch (e: IOException) {
            Log.w(TAG, "freeBytes: IO error on $path", e)
            result.error("IO_ERROR", e.message, null)
        } catch (e: Throwable) {
            // Defensive catch — native side must never propagate an
            // unhandled Throwable through the MethodChannel (the Flutter
            // runtime interprets it as a driver-level crash).
            Log.w(TAG, "freeBytes: unexpected error on $path", e)
            result.error("UNEXPECTED", e.message, null)
        }
    }
}

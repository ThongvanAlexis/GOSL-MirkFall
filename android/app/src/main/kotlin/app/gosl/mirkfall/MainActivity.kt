// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

package app.gosl.mirkfall

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /**
     * Registers Phase 07 hand-rolled MethodChannels (disk-space probe)
     * against the Flutter engine created for the main activity.
     *
     * Phase 05's `BootCompletedReceiver` warms its OWN FlutterEngine via
     * `FlutterEngine(context.applicationContext)` + `executeDartEntrypoint`
     * inside a BroadcastReceiver, so that receiver is not touched here.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DiskSpaceChannel.register(flutterEngine.dartExecutor.binaryMessenger)
    }
}

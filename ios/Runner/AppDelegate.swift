// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import Flutter
import UIKit

/// Minimal iOS app delegate — standard Flutter bootstrap only.
///
/// Phase 05 Plan 05-05 initially landed a scene-based
/// `FlutterImplicitEngineDelegate` wiring here to support the iOS
/// significant-change auto-resume path (CLLocationManager wake →
/// MethodChannel `runWatchdog` → Dart-side resume notification). That
/// wiring broke when the CI iOS runner moved to macos-26 / Xcode 26
/// (required because `device_info_plus 12.4.0` uses
/// `isiOSAppOnVision` from the iOS 26.1 SDK). The Xcode 26 Flutter
/// framework exposes a different shape for the implicit-engine
/// delegate and the previous code no longer compiled.
///
/// Rather than chase the API across Flutter patch versions during a
/// POC-validation phase, the MethodChannel + CLLocationManager wiring
/// is deliberately dropped here. Consequences :
///
/// - The Dart side (`IosSignificantChangeWatchdog.startMonitoring` /
///   `stopMonitoring`) now gets `MissingPluginException` — the Dart
///   contract already swallows that best-effort, so session start /
///   stop still work end-to-end, including background tracking while
///   the app is alive (UIBackgroundModes = location is still set in
///   Info.plist).
/// - What is LOST : the ability for iOS to wake the app after it has
///   been killed and restart the "tap to resume" notification flow.
///   A user-visible fix (manual tap to reopen the app after kill) is
///   the fallback.
///
/// Restoring the full auto-resume behaviour is tracked as Phase 15
/// polish : wire a MethodChannel + CLLocationManagerDelegate using
/// the scene-based API shape shipping in the Flutter version we end
/// up pinning at release. Until then, the Android half
/// (BroadcastReceiver) still covers GPS-06 for the majority of
/// devices.
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

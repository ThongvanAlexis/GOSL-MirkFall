// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import CoreLocation
import Flutter
import UIKit

/// iOS half of the Plan 05-05 auto-resume path.
///
/// Two responsibilities:
///
/// 1. **Cold-start-after-significant-change**: when iOS wakes the app
///    because `CLLocationManager.startMonitoringSignificantLocationChanges`
///    detected a meaningful move, `launchOptions[.location]` is non-nil.
///    We invoke `runWatchdog` on the Dart-side MethodChannel so the Dart
///    watchdog checks the DB and (if applicable) fires the "tap to resume"
///    notification.
///
/// 2. **Outbound control** from Dart to CLLocationManager — the
///    [IosSignificantChangeWatchdog] Dart class calls
///    `startSignificantChangeMonitoring` / `stopSignificantChangeMonitoring`
///    on the same channel. We translate those to
///    `CLLocationManager.startMonitoringSignificantLocationChanges` /
///    `.stopMonitoringSignificantLocationChanges` and act as the
///    `CLLocationManagerDelegate` for the wake callbacks.
///
/// Zero third-party dependencies. Uses only:
///   - UIKit (standard iOS SDK)
///   - Flutter.framework (shipped by flutter build ios)
///   - CoreLocation.framework (standard iOS SDK)
///
/// See [lib/infrastructure/platform/boot_completed_watchdog.dart] for
/// the Dart side.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  /// MethodChannel name — mirrored in
  /// `lib/infrastructure/platform/boot_completed_watchdog.dart` and
  /// `android/app/src/main/kotlin/app/gosl/mirkfall/BootCompletedReceiver.kt`.
  /// Changing this requires updating all three sides in lockstep.
  private static let watchdogChannelName = "app.gosl.mirkfall/boot_watchdog"

  private let locationManager = CLLocationManager()
  private var watchdogChannel: FlutterMethodChannel?
  private var wakeFromLocationChange = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Stash whether this is a location-triggered wake so we can fire
    // `runWatchdog` once the implicit FlutterEngine is ready (see
    // `didInitializeImplicitFlutterEngine` below — the channel has to
    // be wired to an engine before we can invoke).
    if launchOptions?[UIApplication.LaunchOptionsKey.location] != nil {
      wakeFromLocationChange = true
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.watchdogChannelName,
      binaryMessenger: engineBridge.binaryMessenger
    )
    watchdogChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "startSignificantChangeMonitoring":
        self.locationManager.delegate = self
        self.locationManager.startMonitoringSignificantLocationChanges()
        result(nil)
      case "stopSignificantChangeMonitoring":
        self.locationManager.stopMonitoringSignificantLocationChanges()
        result(nil)
      default:
        // `runWatchdog` is an INBOUND call from native -> Dart only;
        // the Dart side registers the handler. We never receive it
        // here.
        result(FlutterMethodNotImplemented)
      }
    }

    if wakeFromLocationChange {
      wakeFromLocationChange = false
      // Ping the Dart side — if it has registered the `runWatchdog`
      // handler by now it fires the watchdog; otherwise the invocation
      // is dropped (Dart side returns MissingPluginException, caught
      // by the FlutterMethodChannel callback and ignored).
      channel.invokeMethod("runWatchdog", arguments: nil)
    }
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(
    _ manager: CLLocationManager,
    didChangeAuthorization status: CLAuthorizationStatus
  ) {
    // Required delegate method; authorization is handled Dart-side via
    // permission_handler (Plan 05-03). No-op here on purpose — if we
    // branched on `status` we would duplicate the Dart-side state
    // machine and drift.
  }

  func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    // Significant-change fire during app lifetime — ping the Dart
    // watchdog. The watchdog is a no-op when no session is active, so
    // firing on every meaningful move is safe (and idempotent: the
    // resume notification uses a stable id).
    watchdogChannel?.invokeMethod("runWatchdog", arguments: nil)
  }

  func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {
    // Significant-change failures are not actionable on our side —
    // Apple documents them as "network error" / "heading-only device"
    // sentinels. Swallowed; the watchdog will run next time CoreLocation
    // recovers.
  }
}

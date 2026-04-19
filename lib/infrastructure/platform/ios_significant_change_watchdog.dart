// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// Dart-side bridge to iOS `CLLocationManager` significant-change monitoring.
///
/// Plan 05-05 auto-resume path (iOS half):
///
///   iOS app enters background -> killed by OS -> user moves significantly ->
///   iOS wakes the app for a few seconds -> AppDelegate's
///   `didChangeSignificantLocation` fires -> invokes MethodChannel
///   `runWatchdog` -> Dart watchdog checks DB -> fires resume notification
///   if an active session was interrupted (see [BootCompletedWatchdog]).
///
/// This class is the outbound half of the same MethodChannel — it tells
/// iOS native code to START or STOP monitoring significant-location
/// changes. The controller calls [startMonitoring] on session start and
/// [stopMonitoring] on session stop so iOS only holds the CLLocationManager
/// subscription while it is actually useful.
///
/// All operations no-op on non-iOS platforms — Android uses the
/// BroadcastReceiver path instead. Platform exceptions are swallowed
/// best-effort: CLLocationManager permission quirks should never block a
/// session start.
class IosSignificantChangeWatchdog {
  const IosSignificantChangeWatchdog();

  /// MethodChannel name shared with the Android
  /// `BootCompletedReceiver.kt` and iOS `AppDelegate.swift`. Do NOT
  /// change without updating both native sides.
  static const MethodChannel _channel = MethodChannel('app.gosl.mirkfall/boot_watchdog');

  static final Logger _log = Logger('infrastructure.platform.ios_significant_change_watchdog');

  /// Asks iOS to begin monitoring significant location changes. No-op on
  /// non-iOS platforms. Idempotent (the native side may already be
  /// monitoring; `startMonitoringSignificantLocationChanges` is also
  /// idempotent per Apple's docs).
  Future<void> startMonitoring() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('startSignificantChangeMonitoring');
    } on PlatformException catch (e, st) {
      _log.warning('startMonitoring platform error (swallowed): ${e.code} ${e.message}', e, st);
    } on Object catch (e, st) {
      // MissingPluginException on cold start before the AppDelegate has
      // registered the channel handler, and any unexpected error — all
      // best-effort per the contract.
      _log.warning('startMonitoring unexpected error (swallowed): $e', e, st);
    }
  }

  /// Stops significant-change monitoring. No-op on non-iOS platforms.
  Future<void> stopMonitoring() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('stopSignificantChangeMonitoring');
    } on PlatformException catch (e, st) {
      _log.warning('stopMonitoring platform error (swallowed): ${e.code} ${e.message}', e, st);
    } on Object catch (e, st) {
      _log.warning('stopMonitoring unexpected error (swallowed): $e', e, st);
    }
  }
}

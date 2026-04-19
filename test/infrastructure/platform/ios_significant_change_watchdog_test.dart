// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/platform/ios_significant_change_watchdog.dart';

/// Covers GPS-06 (iOS side) — MethodChannel wrapper for
/// CLLocationManager.startMonitoringSignificantLocationChanges.
///
/// The real native side is validated via Plan 05-06 real-device POC; this
/// suite verifies the Dart wrapper's contract: only fires MethodChannel
/// calls on iOS, swallows platform errors, matches the documented
/// MethodChannel name + method names.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('app.gosl.mirkfall/boot_watchdog');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      log.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('startMonitoring dispatches startSignificantChangeMonitoring on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const watchdog = IosSignificantChangeWatchdog();

    await watchdog.startMonitoring();

    expect(log, hasLength(1));
    expect(log.single.method, 'startSignificantChangeMonitoring');
  });

  test('stopMonitoring dispatches stopSignificantChangeMonitoring on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const watchdog = IosSignificantChangeWatchdog();

    await watchdog.stopMonitoring();

    expect(log, hasLength(1));
    expect(log.single.method, 'stopSignificantChangeMonitoring');
  });

  test('startMonitoring is a no-op on non-iOS platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const watchdog = IosSignificantChangeWatchdog();

    await watchdog.startMonitoring();

    expect(log, isEmpty);
  });

  test('stopMonitoring is a no-op on non-iOS platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const watchdog = IosSignificantChangeWatchdog();

    await watchdog.stopMonitoring();

    expect(log, isEmpty);
  });

  test('startMonitoring swallows PlatformException (best-effort)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      throw PlatformException(code: 'ERR', message: 'simulated platform failure');
    });
    const watchdog = IosSignificantChangeWatchdog();

    // Must NOT rethrow — CLLocationManager permission quirks should never
    // block session start.
    await watchdog.startMonitoring();
  });
}

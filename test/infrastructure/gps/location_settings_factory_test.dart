// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mirkfall/infrastructure/gps/location_settings_factory.dart';

/// Covers GPS-05 — platform-branching `LocationSettings` factory.
///
/// Uses `debugDefaultTargetPlatformOverride` to exercise each branch without
/// a real device. Every test restores the override in `tearDown` to avoid
/// leaking platform state into sibling tests.
void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('buildLocationSettings — Android branch', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    test('returns AndroidSettings with the caller-supplied distance filter', () {
      final LocationSettings settings = buildLocationSettings(distanceFilterMeters: 7, sessionDisplayName: 'Test walk');
      expect(settings, isA<AndroidSettings>());
      expect(settings.distanceFilter, 7);
    });

    test('enables the wake lock on the foreground-service config (Pitfall #4)', () {
      final AndroidSettings settings = buildLocationSettings(distanceFilterMeters: 5, sessionDisplayName: 'Morning loop') as AndroidSettings;
      final ForegroundNotificationConfig? config = settings.foregroundNotificationConfig;
      expect(config, isNotNull);
      expect(config!.enableWakeLock, isTrue);
      expect(config.setOngoing, isTrue);
    });

    test('foreground notification title includes the session display name', () {
      final AndroidSettings settings = buildLocationSettings(distanceFilterMeters: 5, sessionDisplayName: 'Canal-St-Martin') as AndroidSettings;
      expect(settings.foregroundNotificationConfig!.notificationTitle, contains('Canal-St-Martin'));
      expect(settings.foregroundNotificationConfig!.notificationTitle, startsWith('MirkFall'));
    });
  });

  group('buildLocationSettings — iOS branch', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    test('returns AppleSettings with pauseLocationUpdatesAutomatically FALSE (Pitfall #3)', () {
      final AppleSettings settings = buildLocationSettings(distanceFilterMeters: 5, sessionDisplayName: 'Commute') as AppleSettings;
      expect(settings.pauseLocationUpdatesAutomatically, isFalse);
    });

    test('activityType is ActivityType.fitness (walking/running hint)', () {
      final AppleSettings settings = buildLocationSettings(distanceFilterMeters: 5, sessionDisplayName: 'Commute') as AppleSettings;
      expect(settings.activityType, ActivityType.fitness);
    });

    test('showBackgroundLocationIndicator is TRUE (user-visible transparency)', () {
      final AppleSettings settings = buildLocationSettings(distanceFilterMeters: 5, sessionDisplayName: 'Commute') as AppleSettings;
      expect(settings.showBackgroundLocationIndicator, isTrue);
      expect(settings.allowBackgroundLocationUpdates, isTrue);
    });

    test('propagates the caller-supplied distance filter', () {
      final AppleSettings settings = buildLocationSettings(distanceFilterMeters: 12, sessionDisplayName: 'Commute') as AppleSettings;
      expect(settings.distanceFilter, 12);
    });
  });

  group('buildLocationSettings — desktop fallback', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    });

    test('returns a plain LocationSettings (no Android/Apple specifics)', () {
      final LocationSettings settings = buildLocationSettings(distanceFilterMeters: 3, sessionDisplayName: 'Dev run');
      expect(settings, isNot(isA<AndroidSettings>()));
      expect(settings, isNot(isA<AppleSettings>()));
      expect(settings.distanceFilter, 3);
    });
  });
}

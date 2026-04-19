// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Builds platform-appropriate [LocationSettings] for the active session.
///
/// [distanceFilterMeters] comes from SharedPreferences (user-adjustable
/// slider in the Phase 05-04 settings screen, default
/// `kDefaultDistanceFilterMeters`).
/// [sessionDisplayName] feeds the Android foreground-service notification
/// title; the iOS + desktop branches ignore it (kept in the signature so
/// callers never have to switch on platform themselves).
///
/// Flag-by-flag rationale is inlined as comments below — every flag maps
/// to a named pitfall in `.planning/phases/05-gps-session-lifecycle/05-RESEARCH.md`
/// §Common Pitfalls 2-4 + §Pattern 1. Maintainers should read the pitfall
/// entries before flipping any of them.
LocationSettings buildLocationSettings({required int distanceFilterMeters, required String sessionDisplayName}) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
      // forceLocationManager: false — rely on FusedLocationProviderClient
      // (more accurate indoor). Set to true ONLY on HMS devices (Huawei
      // post-2020 without Google Play Services) — handled via runtime
      // detection in Phase 15 if ever needed. Documented pitfall: see
      // 05-RESEARCH.md §Anti-Patterns (`forceLocationManager: true` breaks
      // streaming on typical Google-services devices — geolocator #1290).
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: 'MirkFall • $sessionDisplayName',
        notificationText: 'Suivi actif',
        notificationChannelName: 'MirkFall session tracking',
        // enableWakeLock: true — required to prevent Android from
        // suspending location callbacks when the screen is off >~30 min
        // (Doze). Pitfall #4 in 05-RESEARCH.md (geolocator #1023).
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      // ActivityType.fitness hints iOS the user is walking/running —
      // best match for MirkFall exploration. Alternatives
      // (.otherNavigation, .other) leave iOS free to assume "stopped car
      // = park and leave" and kill updates. Pattern 1 in 05-RESEARCH.md.
      activityType: ActivityType.fitness,
      // distanceFilter is declared as `int` at the LocationSettings base
      // class level (see geolocator_platform_interface/location_settings.dart)
      // even though CoreLocation expects a CLLocationDistance (double) on
      // the native side. The bridge casts internally — we pass the int.
      distanceFilter: distanceFilterMeters,
      // pauseLocationUpdatesAutomatically: FALSE.
      //
      // iOS community examples commonly pass `true` (battery-friendly),
      // but that makes iOS silently pause updates during stationary
      // moments (café, lunch). For a 30-min walk with stops, we WANT
      // continuous tracking — an explicit Stop is the only valid pause.
      // Pitfall #3 in 05-RESEARCH.md. Matches the geolocator_apple default
      // (false) but we set it EXPLICITLY so any future default flip does
      // not silently re-enable the pause behaviour.
      // ignore: avoid_redundant_argument_values
      pauseLocationUpdatesAutomatically: false,
      // Matches geolocator_apple default (true) — kept explicit because a
      // future default flip here would silently break background tracking.
      // ignore: avoid_redundant_argument_values
      allowBackgroundLocationUpdates: true,
      // showBackgroundLocationIndicator: true — shows the blue bar/pill
      // at the top of the screen when the app is getting location in
      // background. User-visible transparency, aligns with GOSL ethics.
      showBackgroundLocationIndicator: true,
    );
  }
  // Desktop (Windows/macOS/Linux): fall back to plain LocationSettings,
  // used only by dev flow `flutter run -d windows`. No background concerns.
  return LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilterMeters);
}

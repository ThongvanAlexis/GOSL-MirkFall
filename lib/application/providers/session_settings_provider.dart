// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'session_settings_provider.g.dart';

/// SharedPreferences key — user-tunable distance filter (meters).
///
/// Namespace-free flat key matches Phase 01 convention (see
/// `file_logger_screen` / `debug_menu_screen` for precedent).
const String _prefsKeyDistanceFilterMeters = 'distanceFilter_meters';

/// SharedPreferences key — true after the two-step permission flow was
/// completed at least once. Used by Plan 05-04 to skip the rationale
/// screen on subsequent starts (only re-prompt on revocation).
const String _prefsKeyPermissionFlowCompleted = 'permission_flow_completed';

/// SharedPreferences key — true after the OEM battery-killer guidance
/// screen was shown. One-shot per-device (Plan 05-04).
const String _prefsKeyOemGuidanceSeen = 'oem_guidance_seen';

/// Inclusive lower bound for the distance-filter slider.
///
/// Below 2 m the GPS noise floor dominates the signal (5 m accuracy is
/// best-case outdoor open-sky — see `kMaxAcceptableAccuracyMeters`).
/// 2 m keeps the slider exposing a meaningful range without inviting
/// the user to set a value that would be filtered out by stationary
/// dedup anyway.
const int kMinDistanceFilterMeters = 2;

/// Inclusive upper bound for the distance-filter slider. 100 m is the
/// roadmap-imposed ceiling — above, the trace becomes too sparse for
/// the fog-rendering quality targeted by Phase 09.
const int kMaxDistanceFilterMeters = 100;

/// Immutable snapshot of the tracking-related SharedPreferences state.
///
/// A separate class (rather than three discrete providers) keeps the
/// controller's initialization read-path small — one `await` pulls
/// everything it needs for `start()`.
class SessionSettingsSnapshot {
  const SessionSettingsSnapshot({required this.distanceFilterMeters, required this.permissionFlowCompleted, required this.oemGuidanceSeen});

  /// Distance filter in meters, clamped to `[kMinDistanceFilterMeters,
  /// kMaxDistanceFilterMeters]`. The controller passes this directly
  /// into `LocationStream.positions(distanceFilterMeters: ...)`.
  final int distanceFilterMeters;

  final bool permissionFlowCompleted;

  final bool oemGuidanceSeen;

  SessionSettingsSnapshot copyWith({int? distanceFilterMeters, bool? permissionFlowCompleted, bool? oemGuidanceSeen}) => SessionSettingsSnapshot(
    distanceFilterMeters: distanceFilterMeters ?? this.distanceFilterMeters,
    permissionFlowCompleted: permissionFlowCompleted ?? this.permissionFlowCompleted,
    oemGuidanceSeen: oemGuidanceSeen ?? this.oemGuidanceSeen,
  );
}

/// Clamps [raw] into the `[kMin, kMax]DistanceFilterMeters` range.
/// Extracted so callers that read a user-entered value can snap before
/// writing (avoids persisting an out-of-range value that would later
/// trip the slider UI).
int clampDistanceFilterMeters(int raw) => raw.clamp(kMinDistanceFilterMeters, kMaxDistanceFilterMeters);

/// Riverpod Notifier backing the SharedPreferences-persisted tracking
/// settings: distanceFilter + one-shot flags (permission flow completed,
/// OEM guidance seen).
///
/// `keepAlive: true` — SharedPreferences is a process-singleton handle;
/// recomputing on every consumer subscription would be wasted async
/// work with no observable benefit. The notifier itself is stateless
/// beyond what's in `state`.
///
/// Writes go through the notifier methods ([setDistanceFilterMeters],
/// [markPermissionFlowCompleted], [markOemGuidanceSeen]); every method
/// persists to SharedPreferences and updates `state` in the same
/// transaction so subscribers see the new value synchronously on the
/// next frame.
@Riverpod(keepAlive: true)
class SessionSettings extends _$SessionSettings {
  @override
  Future<SessionSettingsSnapshot> build() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDistance = prefs.getInt(_prefsKeyDistanceFilterMeters) ?? kDefaultDistanceFilterMeters;
    return SessionSettingsSnapshot(
      distanceFilterMeters: clampDistanceFilterMeters(rawDistance),
      permissionFlowCompleted: prefs.getBool(_prefsKeyPermissionFlowCompleted) ?? false,
      oemGuidanceSeen: prefs.getBool(_prefsKeyOemGuidanceSeen) ?? false,
    );
  }

  /// Persists [value] (clamped) and updates `state`. Idempotent — a
  /// write with the already-current value is allowed and costs one
  /// SharedPreferences round-trip.
  Future<void> setDistanceFilterMeters(int value) async {
    final clamped = clampDistanceFilterMeters(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyDistanceFilterMeters, clamped);
    final current = await future;
    state = AsyncData(current.copyWith(distanceFilterMeters: clamped));
  }

  /// Marks the two-step permission flow as completed. Irreversible by
  /// design — once completed, Plan 05-04's rationale screen is skipped
  /// on subsequent starts.
  Future<void> markPermissionFlowCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyPermissionFlowCompleted, true);
    final current = await future;
    state = AsyncData(current.copyWith(permissionFlowCompleted: true));
  }

  /// Marks the OEM guidance screen as shown. One-shot per device.
  Future<void> markOemGuidanceSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyOemGuidanceSeen, true);
    final current = await future;
    state = AsyncData(current.copyWith(oemGuidanceSeen: true));
  }
}

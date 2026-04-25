// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../fixes/fix.dart';
import '../ids/session_id.dart';

/// Abstract port over the platform GPS stream.
///
/// Implementations (e.g. `GeolocatorLocationStream` in
/// `lib/infrastructure/gps/`) translate a platform `Position` into a domain
/// [Fix] before emitting downstream.
///
/// Port upgrade (Plan 05-02): `sessionId` is now typed [SessionId] (was
/// `Object` in the Plan 05-01 stub) now that the infrastructure impl lives in
/// the same plan — the lateral-import concern that motivated `Object` no
/// longer applies; keeping the weaker type would only defer the type error
/// to impl-construction time. `sessionDisplayName` is required to feed the
/// Android foreground-service notification title (see
/// `lib/infrastructure/gps/location_settings_factory.dart`).
abstract class LocationStream {
  /// Emits accepted [Fix] values for an active session.
  ///
  /// [distanceFilterMeters] controls the minimum distance between emissions
  /// (set by the user via the Phase 05-04 settings slider).
  /// [sessionDisplayName] is surfaced in the Android foreground-service
  /// notification title; on iOS/desktop it is unused but kept at the port
  /// so the shape is platform-agnostic.
  ///
  /// Platform-level errors are propagated as stream errors typed via
  /// `lib/domain/gps/gps_errors.dart` — subscribers pattern-match over the
  /// sealed [`GpsError`] hierarchy.
  Stream<Fix> positions({required SessionId sessionId, required int distanceFilterMeters, required String sessionDisplayName});

  /// The most recently emitted [Fix] from the current or last [positions]
  /// subscription, or `null` if no fix has been emitted yet.
  ///
  /// Populated on every stream emission. Consumed by Phase 09
  /// [`ActiveSessionController.start`] to write an immediate initial 20 m
  /// reveal without waiting for the next GPS fix.
  ///
  /// Returns `null` after a fresh session start before the platform GPS
  /// has yielded any position. Implementations MAY cache across
  /// [dispose] for short-reconnect scenarios — the production
  /// `GeolocatorLocationStream` does so. Consumers MUST still null-check
  /// before use; the cache may be empty on first launch.
  Fix? get lastKnownFix;

  /// Cancels the stream cleanly. Safe to call more than once.
  Future<void> dispose();
}

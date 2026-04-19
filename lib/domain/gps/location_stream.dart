// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../fixes/fix.dart';

/// Abstract port over the platform GPS stream.
///
/// Implementations (e.g. `GeolocatorLocationStream` in Plan 05-03) translate
/// a platform `Position` into a domain [Fix] before emitting downstream.
///
/// `sessionId` is intentionally typed `Object` (not `SessionId`) to keep the
/// port minimal — forcing `SessionId` here would force a direct peer-domain
/// import from `sessions/`, creating a lateral import chain. Plan 05-03 can
/// tighten to `SessionId` in the concrete impl if desired.
abstract class LocationStream {
  /// Emits accepted [Fix] values for an active session.
  ///
  /// `distanceFilterMeters` controls the minimum distance between emissions.
  /// Platform-level errors (permission denied, service disabled) are
  /// propagated as stream errors typed via `lib/domain/gps/gps_errors.dart`
  /// (created Plan 05-03).
  Stream<Fix> positions({
    required Object sessionId,
    required int distanceFilterMeters,
  });

  /// Cancels the stream cleanly. Safe to call more than once.
  Future<void> dispose();
}

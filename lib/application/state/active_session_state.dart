// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/gps/gps_errors.dart';
import 'package:mirkfall/domain/ids/session_id.dart';

/// Sealed state machine for `ActiveSessionController`.
///
/// Transitions enforced by the controller:
/// - `Idle` -> `Starting` when [`ActiveSessionController.start`] begins.
/// - `Starting` -> `Tracking` when the location subscription is live.
/// - `Starting` / `Tracking` -> `ErrorState` when a [GpsError] fires.
/// - `Tracking` -> `Idle` when [`ActiveSessionController.stop`] completes.
///
/// Sealed hierarchy enables exhaustive `switch` in the UI layer
/// (Plan 05-04) — compiler catches any missed variant when a new state
/// is added.
sealed class ActiveSessionState {
  const ActiveSessionState();
}

/// Controller is idle — no session active, no subscription, no DB rows
/// pending. Initial state and the state after [`ActiveSessionController.stop`].
final class Idle extends ActiveSessionState {
  const Idle();
}

/// Session activation is underway: DB `activate()` + notification
/// `initialize()` + subscription bootstrap. UI should render a spinner
/// with "Starting..." / "Démarrage...".
final class Starting extends ActiveSessionState {
  const Starting(this.sessionId);

  /// Session being activated. Surfaced so the UI can render the name
  /// eagerly (the `Session` row is already loaded by the caller).
  final SessionId sessionId;
}

/// Session is active and the location subscription is delivering fixes.
/// [lastFix] is `null` until the first fix arrives; [fixCount] increments
/// by 1 on every accepted fix (post-filter, post-dedup).
final class Tracking extends ActiveSessionState {
  const Tracking({required this.sessionId, required this.startedAtUtc, required this.fixCount, required this.distanceFilterMeters, this.lastFix});

  final SessionId sessionId;
  final DateTime startedAtUtc;
  final int fixCount;
  final Fix? lastFix;
  final int distanceFilterMeters;

  /// Returns a new [Tracking] with [fixCount] / [lastFix] overridden.
  /// Session-level fields (id, startedAtUtc, distanceFilterMeters) are
  /// immutable for the lifetime of the state — changing them would mean
  /// a different session, which goes through a new `start()` call.
  Tracking copyWith({int? fixCount, Fix? lastFix}) => Tracking(
    sessionId: sessionId,
    startedAtUtc: startedAtUtc,
    fixCount: fixCount ?? this.fixCount,
    lastFix: lastFix ?? this.lastFix,
    distanceFilterMeters: distanceFilterMeters,
  );
}

/// A [GpsError] fired during `start()` or on the live subscription.
/// UI pattern-matches over the [GpsError] variant to render the
/// appropriate recovery screen (permission-denied, service-disabled,
/// background-killed).
final class ErrorState extends ActiveSessionState {
  const ErrorState(this.error);

  final GpsError error;
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/session_id.dart';

/// Sealed state machine for `ActiveSessionController`.
///
/// Transitions enforced by the controller:
/// - `Idle` -> `Starting` when [`ActiveSessionController.start`] begins.
/// - `Starting` -> `Tracking` when the location subscription is live.
/// - `Starting` / `Tracking` -> `AsyncError` when ANY exception fires
///   (GpsError or otherwise). See note below on why the state machine
///   does NOT carry its own ErrorState variant.
/// - `Tracking` -> `Idle` when [`ActiveSessionController.stop`] completes.
///
/// Sealed hierarchy enables exhaustive `switch` in the UI layer
/// (Plan 05-04) — compiler catches any missed variant when a new state
/// is added.
///
/// ## Error channel (row #37 cleanup)
///
/// Prior to 2026-04-23 the hierarchy carried an `ErrorState(GpsError)`
/// variant to surface recoverable GPS errors. Consumers had to
/// pattern-match on BOTH `AsyncError` (for non-GpsError exceptions
/// like `ConcurrentActivationException`) and `AsyncData(ErrorState)`
/// — duplicate error channels for what is, semantically, the same
/// signal: "the controller hit a problem, surface it". All exceptions
/// (including `GpsError`) now propagate via Riverpod's `AsyncError`;
/// UI consumers read `asyncState.error` and pattern-match on the
/// runtime type (`e is GpsError` → recovery screen; otherwise → the
/// existing generic error UI). Row #37 in 08-REVIEW.md §3
/// (smell:over-state-machine).
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

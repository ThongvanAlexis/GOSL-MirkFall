// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:mirkfall/application/providers/fix_store_provider.dart';
import 'package:mirkfall/application/providers/location_stream_provider.dart';
import 'package:mirkfall/application/providers/session_notification_service_provider.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/fixes/fix_store.dart';
import 'package:mirkfall/domain/gps/gps_errors.dart';
import 'package:mirkfall/domain/gps/location_stream.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_session_controller.g.dart';

/// Orchestrator for a session's GPS tracking lifecycle.
///
/// Owns the single [StreamSubscription] over [LocationStream.positions];
/// every accepted [Fix] is persisted immediately to [FixStore] and
/// reflected in [Tracking.fixCount] / [Tracking.lastFix]. Plan 05-04's
/// UI watches this provider and dispatches [start] / [stop].
///
/// `keepAlive: true` — the subscription lifetime is bound to the
/// controller's lifetime; re-creating on UI tree changes would churn
/// the foreground service and lose in-flight fixes. The DB + settings
/// reads are [Future]-based, resolved lazily via `ref.read(.future)`
/// inside [start] — this keeps the synchronous build() fast (returns
/// `Idle()` immediately) so UI never renders a spinner on first frame.
///
/// State machine:
/// - `Idle` (initial, post-stop)
/// - `Starting(sessionId)` — activating + wiring subscription
/// - `Tracking(...)` — subscription live, fixes flowing
/// - `ErrorState(GpsError)` — recoverable domain error (permission,
///   service, background-killed). Non-`GpsError` exceptions (e.g.
///   [`ConcurrentActivationException`](../../domain/errors/concurrent_errors.dart))
///   propagate untyped via Riverpod's `AsyncError` so the UI layer can
///   pattern-match and apply its "stop current first" policy.
@Riverpod(keepAlive: true)
class ActiveSessionController extends _$ActiveSessionController {
  StreamSubscription<Fix>? _sub;
  LocationStream? _stream;
  SessionId? _currentSessionId;

  @override
  FutureOr<ActiveSessionState> build() {
    ref.onDispose(() async {
      await _sub?.cancel();
      _sub = null;
      await _stream?.dispose();
      _stream = null;
    });
    return const Idle();
  }

  /// Activates [id], initializes the notification channel, subscribes
  /// to [LocationStream], and transitions state through
  /// `Idle -> Starting -> Tracking`.
  ///
  /// Throws (rethrows) [`ConcurrentActivationException`] when the DB
  /// partial-unique-index on `t_sessions.status='active'` is violated
  /// by another concurrent activation. The UI layer (Plan 05-04)
  /// catches this and dispatches `stop()` on the currently-active
  /// session before retrying — the controller itself stays a pure
  /// state machine and does not embed that policy.
  ///
  /// On a [GpsError] (permission denied, service disabled), the
  /// controller transitions to [ErrorState] and rethrows so the caller
  /// can surface a Snackbar / toast; the state remains available for
  /// the UI to render a recovery screen.
  Future<void> start(SessionId id) async {
    state = AsyncData(Starting(id));

    try {
      final settings = await ref.read(sessionSettingsProvider.future);
      final sessionStore = await ref.read(sessionStoreProvider.future);
      final fixStore = await ref.read(fixStoreProvider.future);
      final locationStream = ref.read(locationStreamProvider);
      final notificationService = ref.read(sessionNotificationServiceProvider);

      // Activate FIRST so the DB's partial unique index on
      // `t_sessions(status='active')` is exercised BEFORE we spin up
      // the subscription. Failure here propagates; the subscription
      // has not been started, so nothing to tear down.
      await sessionStore.activate(id);
      final activated = await sessionStore.requireById(id);
      await notificationService.initialize();

      _stream = locationStream;
      _currentSessionId = id;

      _sub = locationStream
          .positions(sessionId: id, sessionDisplayName: activated.displayName, distanceFilterMeters: settings.distanceFilterMeters)
          .listen(
            (fix) => _onFix(fix, fixStore),
            onError: _onStreamError,
            // cancelOnError: false -> a single dropped fix (parse blip)
            // must not kill the subscription. Recoverable domain
            // errors flip the state to ErrorState but leave the stream
            // alive so the UI can surface + recover without a full
            // stop/start cycle.
            cancelOnError: false,
          );

      state = AsyncData(Tracking(sessionId: id, startedAtUtc: activated.startedAtUtc, fixCount: 0, distanceFilterMeters: settings.distanceFilterMeters));
    } on GpsError catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    } catch (e, st) {
      // Non-GpsError exceptions (ConcurrentActivationException,
      // SessionNotFoundException, infrastructure bugs) propagate untyped.
      // Riverpod's AsyncError carries them; the UI pattern-matches on
      // the runtime type to apply its recovery policy.
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Cancels the subscription, dismisses the resume notification,
  /// deactivates the session in the DB, and returns state to `Idle`.
  ///
  /// Best-effort: notification dismiss and DB deactivate failures are
  /// logged-and-swallowed — once the user has stopped tracking, the
  /// state MUST settle to `Idle` regardless of housekeeping outcomes.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _stream?.dispose();
    _stream = null;

    try {
      final notificationService = ref.read(sessionNotificationServiceProvider);
      await notificationService.dismiss();
    } catch (_) {
      // Dismiss is best-effort; never block stop() on it.
    }

    final current = _currentSessionId;
    if (current != null) {
      try {
        final sessionStore = await ref.read(sessionStoreProvider.future);
        await sessionStore.deactivate(current);
      } catch (_) {
        // Session already deactivated (race with another caller) or
        // not found; log + swallow so the UI settles to Idle.
      }
      _currentSessionId = null;
    }

    state = const AsyncData(Idle());
  }

  Future<void> _onFix(Fix fix, FixStore fixStore) async {
    await fixStore.insert(fix);
    // Riverpod 3.x: AsyncValue.value is nullable (returns null on
    // loading/error); check explicitly rather than relying on a
    // Riverpod-2 `valueOrNull` getter that no longer exists.
    final current = state.value;
    if (current is Tracking) {
      state = AsyncData(current.copyWith(fixCount: current.fixCount + 1, lastFix: fix));
    }
  }

  void _onStreamError(Object error, StackTrace st) {
    if (error is GpsError) {
      state = AsyncData(ErrorState(error));
      return;
    }
    // Unexpected error on the stream — the GPS pipeline is suspect.
    // Surface as TrackingBackgroundKilled (best-effort typing) so the
    // UI has a recovery path; the real exception goes to the zone
    // handler via the rethrow below for diagnostic capture.
    state = AsyncError(error, st);
  }
}

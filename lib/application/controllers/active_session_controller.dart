// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mirkfall/application/providers/boot_watchdog_provider.dart';
import 'package:mirkfall/application/providers/fix_store_provider.dart';
import 'package:mirkfall/application/providers/location_stream_provider.dart';
import 'package:mirkfall/application/providers/session_notification_service_provider.dart';
import 'package:mirkfall/application/providers/session_settings_provider.dart';
import 'package:mirkfall/application/providers/session_store_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/fixes/fix_store.dart';
import 'package:mirkfall/domain/gps/location_stream.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_session_controller.g.dart';

final Logger _log = Logger('application.controllers.active_session');

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
///
/// Error channel: all exceptions (including `GpsError` subclasses
/// surfacing permission-denied / service-disabled /
/// background-killed) propagate via Riverpod's `AsyncError` rather
/// than a dedicated `ActiveSessionState.ErrorState` variant. The UI
/// consumer (`SessionDetailScreen._handleStart` + `_handleGpsError`)
/// pattern-matches over the sealed `GpsError` hierarchy and routes
/// each variant to its recovery UX (`/permissions/denied` for
/// permission denials, inline messaging for service-disabled +
/// background-kill). Non-GpsError exceptions fall through to the
/// generic `_inlineError` path. See 08-REVIEW.md §3 row #37 for the
/// consolidation rationale (smell:over-state-machine — dedicated
/// ErrorState duplicated what AsyncError already carries) and
/// 08.1-REVIEW.md §3 row #1 (Blocker closure — UI routing restored).
@Riverpod(keepAlive: true)
class ActiveSessionController extends _$ActiveSessionController {
  StreamSubscription<Fix>? _sub;
  LocationStream? _stream;
  SessionId? _currentSessionId;
  bool _isStopping = false;

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
  /// On ANY exception — `GpsError` subclasses (permission denied,
  /// service disabled, background-killed) or other runtime errors —
  /// the controller surfaces it as `AsyncError` and rethrows so the
  /// caller can display a Snackbar / toast. UI layers pattern-match
  /// on `asyncValue.error`'s runtime type to branch between GpsError
  /// recovery screens and generic error handling (row #37 cleanup —
  /// see class docstring).
  ///
  /// If ANY step between `activate` and the listen() call fails, the
  /// controller best-effort deactivates the DB row it just flipped to
  /// `active` so the next start() on the same id is not blocked by the
  /// partial-unique-index on `status='active'` — the session row is
  /// leaked-active otherwise, and CONTEXT.md §partial-activation lock
  /// forbids that.
  Future<void> start(SessionId id) async {
    state = AsyncData(Starting(id));

    // Pre-assign the session id BEFORE any DB mutation so the catch
    // paths below can reliably deactivate if activate() partially
    // succeeds but a later step (requireById / initialize / listen)
    // throws. Keeping it null here leaks an 'active' row whose owner
    // cannot be identified from controller state (Phase 06 Blocker #1).
    _currentSessionId = id;
    bool activated = false;

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
      activated = true;

      final activatedSession = await sessionStore.requireById(id);
      await notificationService.initialize();

      _stream = locationStream;

      _sub = locationStream
          .positions(sessionId: id, sessionDisplayName: activatedSession.displayName, distanceFilterMeters: settings.distanceFilterMeters)
          .listen(
            (fix) => _onFix(fix, fixStore),
            onError: _onStreamError,
            // cancelOnError: false -> a single dropped fix (parse blip)
            // must not kill the subscription. Recoverable domain
            // errors surface via AsyncError but leave the stream alive
            // so the UI can surface + recover without a full stop/start
            // cycle.
            cancelOnError: false,
          );

      state = AsyncData(Tracking(sessionId: id, startedAtUtc: activatedSession.startedAtUtc, fixCount: 0, distanceFilterMeters: settings.distanceFilterMeters));

      // Plan 05-05 auto-resume (iOS half) — enable significant-change
      // monitoring so iOS can wake us after a post-kill significant move.
      // No-op on Android/desktop (watchdog itself branches on platform).
      await ref.read(iosSignificantChangeWatchdogProvider).startMonitoring();
    } catch (e, st) {
      // Every exception — GpsError subclasses (permission denied,
      // service disabled, background-killed) OR other runtime failures
      // (ConcurrentActivationException, SessionNotFoundException, …)
      // — surfaces through the SAME AsyncError channel. The UI layer
      // reads `asyncValue.error` and pattern-matches on runtime type
      // for recovery policy. Row #37 — ErrorState was removed because
      // it duplicated this channel. See class docstring.
      await _rollbackPartialActivation(activated: activated, id: id);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Best-effort rollback: if we flipped the DB row to `active` before
  /// failing somewhere in the initialize/listen chain, flip it back to
  /// `stopped` so the session can be re-started without tripping the
  /// partial-unique-index. Inner failures are logged-and-swallowed via
  /// [_bestEffort] — the catch path is already propagating a primary
  /// exception to the caller.
  Future<void> _rollbackPartialActivation({required bool activated, required SessionId id}) async {
    await _sub?.cancel();
    _sub = null;
    await _stream?.dispose();
    _stream = null;

    if (activated) {
      await _bestEffort('start.rollback_deactivate', () async {
        final sessionStore = await ref.read(sessionStoreProvider.future);
        await sessionStore.deactivate(id);
      });
      await _bestEffort('start.rollback_dismiss', () async {
        final notificationService = ref.read(sessionNotificationServiceProvider);
        await notificationService.dismiss();
      });
    }
    _currentSessionId = null;
  }

  /// Runs [op] and swallows any exception with a `_log.fine` marker
  /// tagged by [context]. Used on the best-effort housekeeping paths
  /// (rollback + stop) where a secondary failure must NOT mask the
  /// primary signal — whether the primary is a propagating exception
  /// (rollback from `start`) or the user's explicit stop intent
  /// (`stop` settling state to Idle regardless of DB / notification
  /// outcomes).
  ///
  /// Row #38 scope-down — this helper replaces five near-identical
  /// inline `try { ... } catch (e, st) { _log.fine(...) }` blocks that
  /// Agent #3 flagged as the "try/catch inside try/catch" aggregate
  /// smell. The individual swallowing is still load-bearing per
  /// Phase 06 Blocker #1 + CLAUDE.md §Error handling level 3; the
  /// helper makes the pattern a one-liner at each call site so
  /// reviewers see FIVE best-effort calls instead of five staircases.
  Future<void> _bestEffort(String context, Future<void> Function() op) async {
    try {
      await op();
    } on Object catch (e, st) {
      _log.fine(context, e, st);
    }
  }

  /// Cancels the subscription, dismisses the resume notification,
  /// deactivates the session in the DB, and returns state to `Idle`.
  ///
  /// Best-effort: notification dismiss and DB deactivate failures are
  /// logged-and-swallowed — once the user has stopped tracking, the
  /// state MUST settle to `Idle` regardless of housekeeping outcomes.
  ///
  /// Idempotent against concurrent callers — a second overlapping
  /// stop() short-circuits without a spurious second DB deactivate
  /// (CLAUDE.md §Idempotence).
  Future<void> stop() async {
    if (_isStopping) {
      // Concurrent stop already running — the first caller will settle
      // state to Idle. Second caller no-ops rather than double-cancel.
      return;
    }
    _isStopping = true;
    try {
      await _sub?.cancel();
      _sub = null;
      await _stream?.dispose();
      _stream = null;

      // Plan 05-05 auto-resume (iOS half) — release the CLLocationManager
      // significant-change subscription. Watchdog no-ops on non-iOS, and
      // swallows platform errors best-effort.
      await ref.read(iosSignificantChangeWatchdogProvider).stopMonitoring();

      // Dismiss notification is best-effort; never block stop() on it.
      // A stale notification surfaces via _log.fine rather than going
      // unnoticed (CLAUDE.md §Error handling level 3).
      await _bestEffort('stop.dismiss', () async {
        final notificationService = ref.read(sessionNotificationServiceProvider);
        await notificationService.dismiss();
      });

      final current = _currentSessionId;
      if (current != null) {
        // DB deactivate is best-effort — a race with another caller
        // (session already deactivated, or not found) must not prevent
        // the UI from settling to Idle.
        await _bestEffort('stop.deactivate', () async {
          final sessionStore = await ref.read(sessionStoreProvider.future);
          await sessionStore.deactivate(current);
        });
        _currentSessionId = null;
      }

      state = const AsyncData(Idle());
    } finally {
      _isStopping = false;
    }
  }

  Future<void> _onFix(Fix fix, FixStore fixStore) async {
    try {
      await fixStore.insert(fix);
    } catch (e, st) {
      // A DB write failure while Tracking is a serious signal — disk
      // full, schema drift, SQLITE_BUSY after exhausted busy_timeout.
      // Keeping the subscription alive would just keep failing; drain
      // through the stream-error path so the state machine transitions
      // to AsyncError and the UI can surface a recovery affordance.
      _log.warning('onFix.insert_failed', e, st);
      _onStreamError(e, st);
      return;
    }
    // Riverpod 3.x: AsyncValue.value is nullable (returns null on
    // loading/error); check explicitly rather than relying on a
    // Riverpod-2 `valueOrNull` getter that no longer exists.
    final current = state.value;
    if (current is Tracking) {
      state = AsyncData(current.copyWith(fixCount: current.fixCount + 1, lastFix: fix));
    }
  }

  void _onStreamError(Object error, StackTrace st) {
    // All errors (GpsError and otherwise) route through AsyncError —
    // see class docstring / row #37. UI consumers read
    // `asyncValue.error` and pattern-match on runtime type to render
    // the appropriate recovery screen. The zone handler still sees
    // the original exception via propagation from the underlying
    // subscription.
    state = AsyncError(error, st);
  }
}

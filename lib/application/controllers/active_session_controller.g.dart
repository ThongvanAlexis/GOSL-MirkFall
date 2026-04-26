// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(ActiveSessionController)
final activeSessionControllerProvider = ActiveSessionControllerProvider._();

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
final class ActiveSessionControllerProvider extends $AsyncNotifierProvider<ActiveSessionController, ActiveSessionState> {
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
  ActiveSessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSessionControllerHash();

  @$internal
  @override
  ActiveSessionController create() => ActiveSessionController();
}

String _$activeSessionControllerHash() => r'4e168bc5b059ce0542ce71aee19fa520b3046beb';

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

abstract class _$ActiveSessionController extends $AsyncNotifier<ActiveSessionState> {
  FutureOr<ActiveSessionState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ActiveSessionState>, ActiveSessionState>;
    final element =
        ref.element as $ClassProviderElement<AnyNotifier<AsyncValue<ActiveSessionState>, ActiveSessionState>, AsyncValue<ActiveSessionState>, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

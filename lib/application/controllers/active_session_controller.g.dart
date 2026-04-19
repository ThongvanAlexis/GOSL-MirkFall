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
/// - `ErrorState(GpsError)` — recoverable domain error (permission,
///   service, background-killed). Non-`GpsError` exceptions (e.g.
///   [`ConcurrentActivationException`](../../domain/errors/concurrent_errors.dart))
///   propagate untyped via Riverpod's `AsyncError` so the UI layer can
///   pattern-match and apply its "stop current first" policy.

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
/// - `ErrorState(GpsError)` — recoverable domain error (permission,
///   service, background-killed). Non-`GpsError` exceptions (e.g.
///   [`ConcurrentActivationException`](../../domain/errors/concurrent_errors.dart))
///   propagate untyped via Riverpod's `AsyncError` so the UI layer can
///   pattern-match and apply its "stop current first" policy.
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
  /// - `ErrorState(GpsError)` — recoverable domain error (permission,
  ///   service, background-killed). Non-`GpsError` exceptions (e.g.
  ///   [`ConcurrentActivationException`](../../domain/errors/concurrent_errors.dart))
  ///   propagate untyped via Riverpod's `AsyncError` so the UI layer can
  ///   pattern-match and apply its "stop current first" policy.
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

String _$activeSessionControllerHash() => r'04be060696e651a730ea9258e8b4962e869960eb';

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

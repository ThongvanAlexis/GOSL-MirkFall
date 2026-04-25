// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reveal_streaming_controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Resolves a [RevealStreamingController] bound to the current
/// `Tracking` session, or `null` when no session is active.
///
/// The controller is session-scoped — its `sessionId` field is the
/// active `Tracking.sessionId`, so a session change MUST invalidate
/// this provider so the next read produces a fresh controller for the
/// new session id. Riverpod's data dependency on
/// [activeSessionControllerProvider] handles that automatically: any
/// transition through `Idle` / `Starting` re-runs the build body and
/// returns `null`, then re-runs again when the next `Tracking` lands.
///
/// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
/// turn flushes any still-buffered fixes — so provider disposal never
/// loses reveal data.
///
/// NOT `keepAlive: true` — the controller's buffer is only meaningful
/// for the live `Tracking` session it was constructed for; carrying it
/// across `Idle` would risk flushing stale fixes to a freshly-restarted
/// session.

@ProviderFor(revealStreamingController)
final revealStreamingControllerProvider = RevealStreamingControllerProvider._();

/// Resolves a [RevealStreamingController] bound to the current
/// `Tracking` session, or `null` when no session is active.
///
/// The controller is session-scoped — its `sessionId` field is the
/// active `Tracking.sessionId`, so a session change MUST invalidate
/// this provider so the next read produces a fresh controller for the
/// new session id. Riverpod's data dependency on
/// [activeSessionControllerProvider] handles that automatically: any
/// transition through `Idle` / `Starting` re-runs the build body and
/// returns `null`, then re-runs again when the next `Tracking` lands.
///
/// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
/// turn flushes any still-buffered fixes — so provider disposal never
/// loses reveal data.
///
/// NOT `keepAlive: true` — the controller's buffer is only meaningful
/// for the live `Tracking` session it was constructed for; carrying it
/// across `Idle` would risk flushing stale fixes to a freshly-restarted
/// session.

final class RevealStreamingControllerProvider
    extends
        $FunctionalProvider<
          RevealStreamingController?,
          RevealStreamingController?,
          RevealStreamingController?
        >
    with $Provider<RevealStreamingController?> {
  /// Resolves a [RevealStreamingController] bound to the current
  /// `Tracking` session, or `null` when no session is active.
  ///
  /// The controller is session-scoped — its `sessionId` field is the
  /// active `Tracking.sessionId`, so a session change MUST invalidate
  /// this provider so the next read produces a fresh controller for the
  /// new session id. Riverpod's data dependency on
  /// [activeSessionControllerProvider] handles that automatically: any
  /// transition through `Idle` / `Starting` re-runs the build body and
  /// returns `null`, then re-runs again when the next `Tracking` lands.
  ///
  /// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
  /// turn flushes any still-buffered fixes — so provider disposal never
  /// loses reveal data.
  ///
  /// NOT `keepAlive: true` — the controller's buffer is only meaningful
  /// for the live `Tracking` session it was constructed for; carrying it
  /// across `Idle` would risk flushing stale fixes to a freshly-restarted
  /// session.
  RevealStreamingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'revealStreamingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$revealStreamingControllerHash();

  @$internal
  @override
  $ProviderElement<RevealStreamingController?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RevealStreamingController? create(Ref ref) {
    return revealStreamingController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RevealStreamingController? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RevealStreamingController?>(value),
    );
  }
}

String _$revealStreamingControllerHash() =>
    r'cd4a6cc21033e7723a03ac6daa38955f733a6077';

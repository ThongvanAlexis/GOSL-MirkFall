// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reveal_streaming_controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Family-style provider that returns a [RevealStreamingController] for
/// the given [sessionId]. Returns `null` while the
/// [revealedTileStoreProvider] async bootstrap (path_provider boot) is
/// still resolving.
///
/// **Wiring rationale (Phase 09 plan 09-06).** This provider does NOT
/// `watch(activeSessionControllerProvider)` — that would create a
/// circular dependency, since `ActiveSessionController` itself reads
/// the reveal controller in its `_onFix` and `stop` paths. Callers that
/// want the "controller for the live session" pattern are expected to
/// resolve the active session id from `ActiveSessionController.state`
/// at the call site and pass it as the family parameter.
///
/// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
/// turn flushes any still-buffered fixes — so provider disposal never
/// loses reveal data. Each (sessionId) family slot is independently
/// disposed when no longer watched.
///
/// NOT `keepAlive: true` — the controller's buffer is only meaningful
/// for the session it was constructed for. Carrying it across session
/// changes would risk flushing stale fixes to a freshly-restarted
/// session.

@ProviderFor(revealStreamingController)
final revealStreamingControllerProvider = RevealStreamingControllerFamily._();

/// Family-style provider that returns a [RevealStreamingController] for
/// the given [sessionId]. Returns `null` while the
/// [revealedTileStoreProvider] async bootstrap (path_provider boot) is
/// still resolving.
///
/// **Wiring rationale (Phase 09 plan 09-06).** This provider does NOT
/// `watch(activeSessionControllerProvider)` — that would create a
/// circular dependency, since `ActiveSessionController` itself reads
/// the reveal controller in its `_onFix` and `stop` paths. Callers that
/// want the "controller for the live session" pattern are expected to
/// resolve the active session id from `ActiveSessionController.state`
/// at the call site and pass it as the family parameter.
///
/// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
/// turn flushes any still-buffered fixes — so provider disposal never
/// loses reveal data. Each (sessionId) family slot is independently
/// disposed when no longer watched.
///
/// NOT `keepAlive: true` — the controller's buffer is only meaningful
/// for the session it was constructed for. Carrying it across session
/// changes would risk flushing stale fixes to a freshly-restarted
/// session.

final class RevealStreamingControllerProvider extends $FunctionalProvider<RevealStreamingController?, RevealStreamingController?, RevealStreamingController?>
    with $Provider<RevealStreamingController?> {
  /// Family-style provider that returns a [RevealStreamingController] for
  /// the given [sessionId]. Returns `null` while the
  /// [revealedTileStoreProvider] async bootstrap (path_provider boot) is
  /// still resolving.
  ///
  /// **Wiring rationale (Phase 09 plan 09-06).** This provider does NOT
  /// `watch(activeSessionControllerProvider)` — that would create a
  /// circular dependency, since `ActiveSessionController` itself reads
  /// the reveal controller in its `_onFix` and `stop` paths. Callers that
  /// want the "controller for the live session" pattern are expected to
  /// resolve the active session id from `ActiveSessionController.state`
  /// at the call site and pass it as the family parameter.
  ///
  /// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
  /// turn flushes any still-buffered fixes — so provider disposal never
  /// loses reveal data. Each (sessionId) family slot is independently
  /// disposed when no longer watched.
  ///
  /// NOT `keepAlive: true` — the controller's buffer is only meaningful
  /// for the session it was constructed for. Carrying it across session
  /// changes would risk flushing stale fixes to a freshly-restarted
  /// session.
  RevealStreamingControllerProvider._({required RevealStreamingControllerFamily super.from, required SessionId super.argument})
    : super(retry: null, name: r'revealStreamingControllerProvider', isAutoDispose: true, dependencies: null, $allTransitiveDependencies: null);

  @override
  String debugGetCreateSourceHash() => _$revealStreamingControllerHash();

  @override
  String toString() {
    return r'revealStreamingControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<RevealStreamingController?> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  RevealStreamingController? create(Ref ref) {
    final argument = this.argument as SessionId;
    return revealStreamingController(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RevealStreamingController? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<RevealStreamingController?>(value));
  }

  @override
  bool operator ==(Object other) {
    return other is RevealStreamingControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$revealStreamingControllerHash() => r'ab87279a1a029f421bcd3830698f4a2546978056';

/// Family-style provider that returns a [RevealStreamingController] for
/// the given [sessionId]. Returns `null` while the
/// [revealedTileStoreProvider] async bootstrap (path_provider boot) is
/// still resolving.
///
/// **Wiring rationale (Phase 09 plan 09-06).** This provider does NOT
/// `watch(activeSessionControllerProvider)` — that would create a
/// circular dependency, since `ActiveSessionController` itself reads
/// the reveal controller in its `_onFix` and `stop` paths. Callers that
/// want the "controller for the live session" pattern are expected to
/// resolve the active session id from `ActiveSessionController.state`
/// at the call site and pass it as the family parameter.
///
/// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
/// turn flushes any still-buffered fixes — so provider disposal never
/// loses reveal data. Each (sessionId) family slot is independently
/// disposed when no longer watched.
///
/// NOT `keepAlive: true` — the controller's buffer is only meaningful
/// for the session it was constructed for. Carrying it across session
/// changes would risk flushing stale fixes to a freshly-restarted
/// session.

final class RevealStreamingControllerFamily extends $Family with $FunctionalFamilyOverride<RevealStreamingController?, SessionId> {
  RevealStreamingControllerFamily._()
    : super(retry: null, name: r'revealStreamingControllerProvider', dependencies: null, $allTransitiveDependencies: null, isAutoDispose: true);

  /// Family-style provider that returns a [RevealStreamingController] for
  /// the given [sessionId]. Returns `null` while the
  /// [revealedTileStoreProvider] async bootstrap (path_provider boot) is
  /// still resolving.
  ///
  /// **Wiring rationale (Phase 09 plan 09-06).** This provider does NOT
  /// `watch(activeSessionControllerProvider)` — that would create a
  /// circular dependency, since `ActiveSessionController` itself reads
  /// the reveal controller in its `_onFix` and `stop` paths. Callers that
  /// want the "controller for the live session" pattern are expected to
  /// resolve the active session id from `ActiveSessionController.state`
  /// at the call site and pass it as the family parameter.
  ///
  /// Lifecycle: `ref.onDispose` calls `controller.dispose()` which in
  /// turn flushes any still-buffered fixes — so provider disposal never
  /// loses reveal data. Each (sessionId) family slot is independently
  /// disposed when no longer watched.
  ///
  /// NOT `keepAlive: true` — the controller's buffer is only meaningful
  /// for the session it was constructed for. Carrying it across session
  /// changes would risk flushing stale fixes to a freshly-restarted
  /// session.

  RevealStreamingControllerProvider call(SessionId sessionId) => RevealStreamingControllerProvider._(argument: sessionId, from: this);

  @override
  String toString() => r'revealStreamingControllerProvider';
}

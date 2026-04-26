// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_mirk_renderer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Resolves the currently-active [MirkRenderer] for the active session.
///
/// Resolution cascade (top to bottom — each step short-circuits on
/// match):
/// 1. `ActiveSessionState` is `Idle` / `Starting` / loading / error
///    → return [NoopMirkRenderer] (no session, no fog).
/// 2. State is `Tracking(sessionId)` and the session row's
///    [Session.mirkStyleId] is non-null AND points to an existing
///    [MirkStyle] → return `factory.create(style.config)`.
/// 3. State is `Tracking` and `mirkStyleId` is null OR the referenced
///    style is missing → return `factory.create(AtmosphericConfig())`
///    (renderer-level default, atmospheric).
///
/// `UnknownConfig` payloads are handled inside the factory itself
/// (forward-compat fallback from plan 09-05 Task 1) — they never reach
/// this provider as a special case.
///
/// Lifecycle:
/// * `ref.onDispose` calls `renderer.dispose()` when the provider is
///   torn down (session change, style swap, app exit). This ensures GPU
///   resources, tickers, and noise generators are released exactly once
///   per renderer instance.
/// * NOT `keepAlive: true` — the renderer is session-scoped and should
///   be garbage-collected when the session ends or the style changes.
///   Plan 09-06's `MirkStyleSessionController.select()` calls
///   `ref.invalidate(activeMirkRendererProvider)` to force a swap when
///   the user picks a new style mid-session.

@ProviderFor(activeMirkRenderer)
final activeMirkRendererProvider = ActiveMirkRendererProvider._();

/// Resolves the currently-active [MirkRenderer] for the active session.
///
/// Resolution cascade (top to bottom — each step short-circuits on
/// match):
/// 1. `ActiveSessionState` is `Idle` / `Starting` / loading / error
///    → return [NoopMirkRenderer] (no session, no fog).
/// 2. State is `Tracking(sessionId)` and the session row's
///    [Session.mirkStyleId] is non-null AND points to an existing
///    [MirkStyle] → return `factory.create(style.config)`.
/// 3. State is `Tracking` and `mirkStyleId` is null OR the referenced
///    style is missing → return `factory.create(AtmosphericConfig())`
///    (renderer-level default, atmospheric).
///
/// `UnknownConfig` payloads are handled inside the factory itself
/// (forward-compat fallback from plan 09-05 Task 1) — they never reach
/// this provider as a special case.
///
/// Lifecycle:
/// * `ref.onDispose` calls `renderer.dispose()` when the provider is
///   torn down (session change, style swap, app exit). This ensures GPU
///   resources, tickers, and noise generators are released exactly once
///   per renderer instance.
/// * NOT `keepAlive: true` — the renderer is session-scoped and should
///   be garbage-collected when the session ends or the style changes.
///   Plan 09-06's `MirkStyleSessionController.select()` calls
///   `ref.invalidate(activeMirkRendererProvider)` to force a swap when
///   the user picks a new style mid-session.

final class ActiveMirkRendererProvider extends $FunctionalProvider<AsyncValue<MirkRenderer>, MirkRenderer, FutureOr<MirkRenderer>>
    with $FutureModifier<MirkRenderer>, $FutureProvider<MirkRenderer> {
  /// Resolves the currently-active [MirkRenderer] for the active session.
  ///
  /// Resolution cascade (top to bottom — each step short-circuits on
  /// match):
  /// 1. `ActiveSessionState` is `Idle` / `Starting` / loading / error
  ///    → return [NoopMirkRenderer] (no session, no fog).
  /// 2. State is `Tracking(sessionId)` and the session row's
  ///    [Session.mirkStyleId] is non-null AND points to an existing
  ///    [MirkStyle] → return `factory.create(style.config)`.
  /// 3. State is `Tracking` and `mirkStyleId` is null OR the referenced
  ///    style is missing → return `factory.create(AtmosphericConfig())`
  ///    (renderer-level default, atmospheric).
  ///
  /// `UnknownConfig` payloads are handled inside the factory itself
  /// (forward-compat fallback from plan 09-05 Task 1) — they never reach
  /// this provider as a special case.
  ///
  /// Lifecycle:
  /// * `ref.onDispose` calls `renderer.dispose()` when the provider is
  ///   torn down (session change, style swap, app exit). This ensures GPU
  ///   resources, tickers, and noise generators are released exactly once
  ///   per renderer instance.
  /// * NOT `keepAlive: true` — the renderer is session-scoped and should
  ///   be garbage-collected when the session ends or the style changes.
  ///   Plan 09-06's `MirkStyleSessionController.select()` calls
  ///   `ref.invalidate(activeMirkRendererProvider)` to force a swap when
  ///   the user picks a new style mid-session.
  ActiveMirkRendererProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeMirkRendererProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeMirkRendererHash();

  @$internal
  @override
  $FutureProviderElement<MirkRenderer> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<MirkRenderer> create(Ref ref) {
    return activeMirkRenderer(ref);
  }
}

String _$activeMirkRendererHash() => r'43292ee205f809e3a4827182ec1c20600001a047';

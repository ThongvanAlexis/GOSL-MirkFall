// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mirk_style_session_controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production [MirkStyleSessionController] — wires the controller with
/// [`sessionStoreProvider`], [`mirkStyleStoreProvider`], and an
/// `invalidateRenderer` callback that invalidates
/// [`activeMirkRendererProvider`] on style change.
///
/// Returned as `Future<MirkStyleSessionController>` because both store
/// providers are async (path_provider boot). Plan 09-07's burger-menu
/// picker awaits the future once and caches the controller for the
/// session's lifetime.
///
/// `keepAlive: true` — the controller has no long-lived state of its
/// own (it reads stores per-call) and re-creating it on widget-tree
/// changes would not save anything. Mirrors the rest of the
/// store-wrapping providers in the Phase 03/05 graph.

@ProviderFor(mirkStyleSessionController)
final mirkStyleSessionControllerProvider =
    MirkStyleSessionControllerProvider._();

/// Production [MirkStyleSessionController] — wires the controller with
/// [`sessionStoreProvider`], [`mirkStyleStoreProvider`], and an
/// `invalidateRenderer` callback that invalidates
/// [`activeMirkRendererProvider`] on style change.
///
/// Returned as `Future<MirkStyleSessionController>` because both store
/// providers are async (path_provider boot). Plan 09-07's burger-menu
/// picker awaits the future once and caches the controller for the
/// session's lifetime.
///
/// `keepAlive: true` — the controller has no long-lived state of its
/// own (it reads stores per-call) and re-creating it on widget-tree
/// changes would not save anything. Mirrors the rest of the
/// store-wrapping providers in the Phase 03/05 graph.

final class MirkStyleSessionControllerProvider
    extends
        $FunctionalProvider<
          AsyncValue<MirkStyleSessionController>,
          MirkStyleSessionController,
          FutureOr<MirkStyleSessionController>
        >
    with
        $FutureModifier<MirkStyleSessionController>,
        $FutureProvider<MirkStyleSessionController> {
  /// Production [MirkStyleSessionController] — wires the controller with
  /// [`sessionStoreProvider`], [`mirkStyleStoreProvider`], and an
  /// `invalidateRenderer` callback that invalidates
  /// [`activeMirkRendererProvider`] on style change.
  ///
  /// Returned as `Future<MirkStyleSessionController>` because both store
  /// providers are async (path_provider boot). Plan 09-07's burger-menu
  /// picker awaits the future once and caches the controller for the
  /// session's lifetime.
  ///
  /// `keepAlive: true` — the controller has no long-lived state of its
  /// own (it reads stores per-call) and re-creating it on widget-tree
  /// changes would not save anything. Mirrors the rest of the
  /// store-wrapping providers in the Phase 03/05 graph.
  MirkStyleSessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mirkStyleSessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mirkStyleSessionControllerHash();

  @$internal
  @override
  $FutureProviderElement<MirkStyleSessionController> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MirkStyleSessionController> create(Ref ref) {
    return mirkStyleSessionController(ref);
  }
}

String _$mirkStyleSessionControllerHash() =>
    r'9985b6dbf61c0336f0b31457bc03727443bb97aa';

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'visible_mirk_tiles_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Async provider returning the parent tiles intersecting the current
/// viewport, hydrated with their bitmap from [`RevealedTileStore`] and
/// pre-projected lat/lon extents.
///
/// Empty list is returned when:
/// * The session is not in `Tracking` state (no fog to paint).
/// * The viewport is not yet known ([`mapViewportProvider`] is null).
///
/// A parent tile with no row in the store yields a [VisibleMirkTile]
/// with an all-zero bitmap — the renderer paints the entire tile as
/// fog (which is the correct semantic for "this area has not been
/// revealed yet").
///
/// Phase 09 plan 09-07 Task 2 — viewport filtering (SC#5) seam.

@ProviderFor(visibleMirkTiles)
final visibleMirkTilesProvider = VisibleMirkTilesProvider._();

/// Async provider returning the parent tiles intersecting the current
/// viewport, hydrated with their bitmap from [`RevealedTileStore`] and
/// pre-projected lat/lon extents.
///
/// Empty list is returned when:
/// * The session is not in `Tracking` state (no fog to paint).
/// * The viewport is not yet known ([`mapViewportProvider`] is null).
///
/// A parent tile with no row in the store yields a [VisibleMirkTile]
/// with an all-zero bitmap — the renderer paints the entire tile as
/// fog (which is the correct semantic for "this area has not been
/// revealed yet").
///
/// Phase 09 plan 09-07 Task 2 — viewport filtering (SC#5) seam.

final class VisibleMirkTilesProvider extends $FunctionalProvider<AsyncValue<List<VisibleMirkTile>>, List<VisibleMirkTile>, FutureOr<List<VisibleMirkTile>>>
    with $FutureModifier<List<VisibleMirkTile>>, $FutureProvider<List<VisibleMirkTile>> {
  /// Async provider returning the parent tiles intersecting the current
  /// viewport, hydrated with their bitmap from [`RevealedTileStore`] and
  /// pre-projected lat/lon extents.
  ///
  /// Empty list is returned when:
  /// * The session is not in `Tracking` state (no fog to paint).
  /// * The viewport is not yet known ([`mapViewportProvider`] is null).
  ///
  /// A parent tile with no row in the store yields a [VisibleMirkTile]
  /// with an all-zero bitmap — the renderer paints the entire tile as
  /// fog (which is the correct semantic for "this area has not been
  /// revealed yet").
  ///
  /// Phase 09 plan 09-07 Task 2 — viewport filtering (SC#5) seam.
  VisibleMirkTilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'visibleMirkTilesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$visibleMirkTilesHash();

  @$internal
  @override
  $FutureProviderElement<List<VisibleMirkTile>> $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VisibleMirkTile>> create(Ref ref) {
    return visibleMirkTiles(ref);
  }
}

String _$visibleMirkTilesHash() => r'88cf79b7c5b486a01c7d03ed897aa775bb9fc7a3';

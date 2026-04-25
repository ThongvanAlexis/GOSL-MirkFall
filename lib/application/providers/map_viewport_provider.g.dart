// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_viewport_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Current MapLibre viewport bounds as a [MirkViewportBbox], or null
/// until the MapView is ready and the first viewport bounds settle.
///
/// Subscribes to [MapView.viewportUpdates] and republishes the bounds
/// derived from [MapView.queryViewportBounds] on each settled camera
/// change. Debounced 50 ms — see [_kViewportDebounce].
///
/// Phase 07 only exposes a scalar [`MapViewportZoom`] — this provider is
/// the Phase 09 addition (plan 09-07 Task 1, resolves revision S2).
///
/// `keepAlive: true` — bbox is a long-lived observable; tearing down the
/// subscription when the drawer closes would drop events during the gap
/// (same discipline as [`MapViewportZoom`]).

@ProviderFor(MapViewport)
final mapViewportProvider = MapViewportProvider._();

/// Current MapLibre viewport bounds as a [MirkViewportBbox], or null
/// until the MapView is ready and the first viewport bounds settle.
///
/// Subscribes to [MapView.viewportUpdates] and republishes the bounds
/// derived from [MapView.queryViewportBounds] on each settled camera
/// change. Debounced 50 ms — see [_kViewportDebounce].
///
/// Phase 07 only exposes a scalar [`MapViewportZoom`] — this provider is
/// the Phase 09 addition (plan 09-07 Task 1, resolves revision S2).
///
/// `keepAlive: true` — bbox is a long-lived observable; tearing down the
/// subscription when the drawer closes would drop events during the gap
/// (same discipline as [`MapViewportZoom`]).
final class MapViewportProvider
    extends $NotifierProvider<MapViewport, MirkViewportBbox?> {
  /// Current MapLibre viewport bounds as a [MirkViewportBbox], or null
  /// until the MapView is ready and the first viewport bounds settle.
  ///
  /// Subscribes to [MapView.viewportUpdates] and republishes the bounds
  /// derived from [MapView.queryViewportBounds] on each settled camera
  /// change. Debounced 50 ms — see [_kViewportDebounce].
  ///
  /// Phase 07 only exposes a scalar [`MapViewportZoom`] — this provider is
  /// the Phase 09 addition (plan 09-07 Task 1, resolves revision S2).
  ///
  /// `keepAlive: true` — bbox is a long-lived observable; tearing down the
  /// subscription when the drawer closes would drop events during the gap
  /// (same discipline as [`MapViewportZoom`]).
  MapViewportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapViewportProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapViewportHash();

  @$internal
  @override
  MapViewport create() => MapViewport();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MirkViewportBbox? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MirkViewportBbox?>(value),
    );
  }
}

String _$mapViewportHash() => r'84fc6c6afef884dc962d93d850bc1d40a9174b93';

/// Current MapLibre viewport bounds as a [MirkViewportBbox], or null
/// until the MapView is ready and the first viewport bounds settle.
///
/// Subscribes to [MapView.viewportUpdates] and republishes the bounds
/// derived from [MapView.queryViewportBounds] on each settled camera
/// change. Debounced 50 ms — see [_kViewportDebounce].
///
/// Phase 07 only exposes a scalar [`MapViewportZoom`] — this provider is
/// the Phase 09 addition (plan 09-07 Task 1, resolves revision S2).
///
/// `keepAlive: true` — bbox is a long-lived observable; tearing down the
/// subscription when the drawer closes would drop events during the gap
/// (same discipline as [`MapViewportZoom`]).

abstract class _$MapViewport extends $Notifier<MirkViewportBbox?> {
  MirkViewportBbox? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MirkViewportBbox?, MirkViewportBbox?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MirkViewportBbox?, MirkViewportBbox?>,
              MirkViewportBbox?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

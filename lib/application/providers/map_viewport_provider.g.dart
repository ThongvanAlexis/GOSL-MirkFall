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
/// derived from [MapView.queryViewportBounds] on each camera change.
///
/// ## Throttling — leading edge + trailing tail
///
/// `viewportUpdates` fires continuously during pan / pinch / zoom (every
/// `notifyListeners()` from the MapLibre controller). The naive shape
/// would call `queryViewportBounds` on every emission — too many
/// platform-channel round-trips. The earlier debounce shape (50 ms quiet
/// window before any refresh) had the opposite failure mode: during a
/// continuous gesture each emission RESET the timer, so the bbox was
/// only refreshed AFTER the gesture ended (the user observed the fog
/// snapping into place at gesture release rather than tracking the
/// pan in realtime — BUG-005, 2026-04-25).
///
/// The throttle here:
///  - **Leading edge** — first emission of a burst fires immediately. The
///    overlay sees the new bbox within one frame.
///  - **In-window emissions** — set a "trailing pending" flag. Do not
///    fire `queryViewportBounds`.
///  - **Window expiry** — if the trailing flag is set, fire a refresh
///    capturing whatever the camera state is now, and start a new
///    window. Otherwise idle.
///
/// Net effect: during continuous panning the bbox refreshes at ~20 Hz
/// (one leading + one trailing per window), and the LAST update of any
/// gesture is always captured.
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
/// derived from [MapView.queryViewportBounds] on each camera change.
///
/// ## Throttling — leading edge + trailing tail
///
/// `viewportUpdates` fires continuously during pan / pinch / zoom (every
/// `notifyListeners()` from the MapLibre controller). The naive shape
/// would call `queryViewportBounds` on every emission — too many
/// platform-channel round-trips. The earlier debounce shape (50 ms quiet
/// window before any refresh) had the opposite failure mode: during a
/// continuous gesture each emission RESET the timer, so the bbox was
/// only refreshed AFTER the gesture ended (the user observed the fog
/// snapping into place at gesture release rather than tracking the
/// pan in realtime — BUG-005, 2026-04-25).
///
/// The throttle here:
///  - **Leading edge** — first emission of a burst fires immediately. The
///    overlay sees the new bbox within one frame.
///  - **In-window emissions** — set a "trailing pending" flag. Do not
///    fire `queryViewportBounds`.
///  - **Window expiry** — if the trailing flag is set, fire a refresh
///    capturing whatever the camera state is now, and start a new
///    window. Otherwise idle.
///
/// Net effect: during continuous panning the bbox refreshes at ~20 Hz
/// (one leading + one trailing per window), and the LAST update of any
/// gesture is always captured.
///
/// Phase 07 only exposes a scalar [`MapViewportZoom`] — this provider is
/// the Phase 09 addition (plan 09-07 Task 1, resolves revision S2).
///
/// `keepAlive: true` — bbox is a long-lived observable; tearing down the
/// subscription when the drawer closes would drop events during the gap
/// (same discipline as [`MapViewportZoom`]).
final class MapViewportProvider extends $NotifierProvider<MapViewport, MirkViewportBbox?> {
  /// Current MapLibre viewport bounds as a [MirkViewportBbox], or null
  /// until the MapView is ready and the first viewport bounds settle.
  ///
  /// Subscribes to [MapView.viewportUpdates] and republishes the bounds
  /// derived from [MapView.queryViewportBounds] on each camera change.
  ///
  /// ## Throttling — leading edge + trailing tail
  ///
  /// `viewportUpdates` fires continuously during pan / pinch / zoom (every
  /// `notifyListeners()` from the MapLibre controller). The naive shape
  /// would call `queryViewportBounds` on every emission — too many
  /// platform-channel round-trips. The earlier debounce shape (50 ms quiet
  /// window before any refresh) had the opposite failure mode: during a
  /// continuous gesture each emission RESET the timer, so the bbox was
  /// only refreshed AFTER the gesture ended (the user observed the fog
  /// snapping into place at gesture release rather than tracking the
  /// pan in realtime — BUG-005, 2026-04-25).
  ///
  /// The throttle here:
  ///  - **Leading edge** — first emission of a burst fires immediately. The
  ///    overlay sees the new bbox within one frame.
  ///  - **In-window emissions** — set a "trailing pending" flag. Do not
  ///    fire `queryViewportBounds`.
  ///  - **Window expiry** — if the trailing flag is set, fire a refresh
  ///    capturing whatever the camera state is now, and start a new
  ///    window. Otherwise idle.
  ///
  /// Net effect: during continuous panning the bbox refreshes at ~20 Hz
  /// (one leading + one trailing per window), and the LAST update of any
  /// gesture is always captured.
  ///
  /// Phase 07 only exposes a scalar [`MapViewportZoom`] — this provider is
  /// the Phase 09 addition (plan 09-07 Task 1, resolves revision S2).
  ///
  /// `keepAlive: true` — bbox is a long-lived observable; tearing down the
  /// subscription when the drawer closes would drop events during the gap
  /// (same discipline as [`MapViewportZoom`]).
  MapViewportProvider._()
    : super(from: null, argument: null, retry: null, name: r'mapViewportProvider', isAutoDispose: false, dependencies: null, $allTransitiveDependencies: null);

  @override
  String debugGetCreateSourceHash() => _$mapViewportHash();

  @$internal
  @override
  MapViewport create() => MapViewport();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MirkViewportBbox? value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<MirkViewportBbox?>(value));
  }
}

String _$mapViewportHash() => r'173dc7763c8ceb74150fe76cd715499c99d81978';

/// Current MapLibre viewport bounds as a [MirkViewportBbox], or null
/// until the MapView is ready and the first viewport bounds settle.
///
/// Subscribes to [MapView.viewportUpdates] and republishes the bounds
/// derived from [MapView.queryViewportBounds] on each camera change.
///
/// ## Throttling — leading edge + trailing tail
///
/// `viewportUpdates` fires continuously during pan / pinch / zoom (every
/// `notifyListeners()` from the MapLibre controller). The naive shape
/// would call `queryViewportBounds` on every emission — too many
/// platform-channel round-trips. The earlier debounce shape (50 ms quiet
/// window before any refresh) had the opposite failure mode: during a
/// continuous gesture each emission RESET the timer, so the bbox was
/// only refreshed AFTER the gesture ended (the user observed the fog
/// snapping into place at gesture release rather than tracking the
/// pan in realtime — BUG-005, 2026-04-25).
///
/// The throttle here:
///  - **Leading edge** — first emission of a burst fires immediately. The
///    overlay sees the new bbox within one frame.
///  - **In-window emissions** — set a "trailing pending" flag. Do not
///    fire `queryViewportBounds`.
///  - **Window expiry** — if the trailing flag is set, fire a refresh
///    capturing whatever the camera state is now, and start a new
///    window. Otherwise idle.
///
/// Net effect: during continuous panning the bbox refreshes at ~20 Hz
/// (one leading + one trailing per window), and the LAST update of any
/// gesture is always captured.
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
    final element = ref.element as $ClassProviderElement<AnyNotifier<MirkViewportBbox?, MirkViewportBbox?>, MirkViewportBbox?, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_camera_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orchestrates the map camera on the /map screen:
/// - Opens a session view with Z=[kInitialSessionMapZoom] zoom centred on
///   the latest session fix (or the last-known fix from the active
///   session controller).
/// - Maintains follow-me: new fixes cause the camera to pan, preserving
///   the user's current zoom.
/// - Detects manual user pan (a viewport update NOT triggered by this
///   controller's own `moveCameraTo` calls) and disables follow-me.
///
/// Echo-suppression is done by timestamp comparison: every
/// controller-initiated `moveCameraTo` records `_lastProgrammaticMoveAt`.
/// A viewport update within [kMapCameraPendingMoveDebounce] of that
/// timestamp is treated as MapLibre's `onCameraIdle` echoing the
/// controller's own move back; anything older is a genuine user pan.
/// Per CLAUDE.md §State "préférer la déduction au tracking" — no
/// explicit boolean flag + no timer lifecycle to juggle.
///
/// Keyed to the Plan 07-06 `MapLibreMapViewWidget`'s `onReady` callback:
/// the widget publishes a [MapView] adapter via [mapViewProvider] and the
/// controller lazily attaches its listeners on first use.
///
/// ## iOS initial-camera seeding (Phase 07-07 fix)
///
/// [openForSession] deliberately does NOT issue any
/// camera-moving method-channel call on first open. Two earlier
/// attempts crashed MapLibre.framework with identical native stack
/// traces — once with `animateCamera` (commit 604988f) and once with
/// the animator-free `moveCamera` (commit 3b23c8d). The convergence
/// proves the bug is about ANY camera-state mutation issued in the
/// window right after `onStyleLoaded`, not about which method is
/// used. Resolution: the initial viewport is supplied via
/// `MapLibreMap.initialCameraPosition` at widget-build time (see
/// `_buildMapStack` in `map_screen.dart`); by the time
/// [openForSession] runs, the MLNMapView already shows the right
/// viewport and the controller only needs to prime the puck + flip
/// follow-me on.

@ProviderFor(MapCameraController)
final mapCameraControllerProvider = MapCameraControllerProvider._();

/// Orchestrates the map camera on the /map screen:
/// - Opens a session view with Z=[kInitialSessionMapZoom] zoom centred on
///   the latest session fix (or the last-known fix from the active
///   session controller).
/// - Maintains follow-me: new fixes cause the camera to pan, preserving
///   the user's current zoom.
/// - Detects manual user pan (a viewport update NOT triggered by this
///   controller's own `moveCameraTo` calls) and disables follow-me.
///
/// Echo-suppression is done by timestamp comparison: every
/// controller-initiated `moveCameraTo` records `_lastProgrammaticMoveAt`.
/// A viewport update within [kMapCameraPendingMoveDebounce] of that
/// timestamp is treated as MapLibre's `onCameraIdle` echoing the
/// controller's own move back; anything older is a genuine user pan.
/// Per CLAUDE.md §State "préférer la déduction au tracking" — no
/// explicit boolean flag + no timer lifecycle to juggle.
///
/// Keyed to the Plan 07-06 `MapLibreMapViewWidget`'s `onReady` callback:
/// the widget publishes a [MapView] adapter via [mapViewProvider] and the
/// controller lazily attaches its listeners on first use.
///
/// ## iOS initial-camera seeding (Phase 07-07 fix)
///
/// [openForSession] deliberately does NOT issue any
/// camera-moving method-channel call on first open. Two earlier
/// attempts crashed MapLibre.framework with identical native stack
/// traces — once with `animateCamera` (commit 604988f) and once with
/// the animator-free `moveCamera` (commit 3b23c8d). The convergence
/// proves the bug is about ANY camera-state mutation issued in the
/// window right after `onStyleLoaded`, not about which method is
/// used. Resolution: the initial viewport is supplied via
/// `MapLibreMap.initialCameraPosition` at widget-build time (see
/// `_buildMapStack` in `map_screen.dart`); by the time
/// [openForSession] runs, the MLNMapView already shows the right
/// viewport and the controller only needs to prime the puck + flip
/// follow-me on.
final class MapCameraControllerProvider extends $NotifierProvider<MapCameraController, MapCameraState> {
  /// Orchestrates the map camera on the /map screen:
  /// - Opens a session view with Z=[kInitialSessionMapZoom] zoom centred on
  ///   the latest session fix (or the last-known fix from the active
  ///   session controller).
  /// - Maintains follow-me: new fixes cause the camera to pan, preserving
  ///   the user's current zoom.
  /// - Detects manual user pan (a viewport update NOT triggered by this
  ///   controller's own `moveCameraTo` calls) and disables follow-me.
  ///
  /// Echo-suppression is done by timestamp comparison: every
  /// controller-initiated `moveCameraTo` records `_lastProgrammaticMoveAt`.
  /// A viewport update within [kMapCameraPendingMoveDebounce] of that
  /// timestamp is treated as MapLibre's `onCameraIdle` echoing the
  /// controller's own move back; anything older is a genuine user pan.
  /// Per CLAUDE.md §State "préférer la déduction au tracking" — no
  /// explicit boolean flag + no timer lifecycle to juggle.
  ///
  /// Keyed to the Plan 07-06 `MapLibreMapViewWidget`'s `onReady` callback:
  /// the widget publishes a [MapView] adapter via [mapViewProvider] and the
  /// controller lazily attaches its listeners on first use.
  ///
  /// ## iOS initial-camera seeding (Phase 07-07 fix)
  ///
  /// [openForSession] deliberately does NOT issue any
  /// camera-moving method-channel call on first open. Two earlier
  /// attempts crashed MapLibre.framework with identical native stack
  /// traces — once with `animateCamera` (commit 604988f) and once with
  /// the animator-free `moveCamera` (commit 3b23c8d). The convergence
  /// proves the bug is about ANY camera-state mutation issued in the
  /// window right after `onStyleLoaded`, not about which method is
  /// used. Resolution: the initial viewport is supplied via
  /// `MapLibreMap.initialCameraPosition` at widget-build time (see
  /// `_buildMapStack` in `map_screen.dart`); by the time
  /// [openForSession] runs, the MLNMapView already shows the right
  /// viewport and the controller only needs to prime the puck + flip
  /// follow-me on.
  MapCameraControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapCameraControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapCameraControllerHash();

  @$internal
  @override
  MapCameraController create() => MapCameraController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MapCameraState value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<MapCameraState>(value));
  }
}

String _$mapCameraControllerHash() => r'9fba8d9a34cde9a95824fd28ddb7435909de2e0a';

/// Orchestrates the map camera on the /map screen:
/// - Opens a session view with Z=[kInitialSessionMapZoom] zoom centred on
///   the latest session fix (or the last-known fix from the active
///   session controller).
/// - Maintains follow-me: new fixes cause the camera to pan, preserving
///   the user's current zoom.
/// - Detects manual user pan (a viewport update NOT triggered by this
///   controller's own `moveCameraTo` calls) and disables follow-me.
///
/// Echo-suppression is done by timestamp comparison: every
/// controller-initiated `moveCameraTo` records `_lastProgrammaticMoveAt`.
/// A viewport update within [kMapCameraPendingMoveDebounce] of that
/// timestamp is treated as MapLibre's `onCameraIdle` echoing the
/// controller's own move back; anything older is a genuine user pan.
/// Per CLAUDE.md §State "préférer la déduction au tracking" — no
/// explicit boolean flag + no timer lifecycle to juggle.
///
/// Keyed to the Plan 07-06 `MapLibreMapViewWidget`'s `onReady` callback:
/// the widget publishes a [MapView] adapter via [mapViewProvider] and the
/// controller lazily attaches its listeners on first use.
///
/// ## iOS initial-camera seeding (Phase 07-07 fix)
///
/// [openForSession] deliberately does NOT issue any
/// camera-moving method-channel call on first open. Two earlier
/// attempts crashed MapLibre.framework with identical native stack
/// traces — once with `animateCamera` (commit 604988f) and once with
/// the animator-free `moveCamera` (commit 3b23c8d). The convergence
/// proves the bug is about ANY camera-state mutation issued in the
/// window right after `onStyleLoaded`, not about which method is
/// used. Resolution: the initial viewport is supplied via
/// `MapLibreMap.initialCameraPosition` at widget-build time (see
/// `_buildMapStack` in `map_screen.dart`); by the time
/// [openForSession] runs, the MLNMapView already shows the right
/// viewport and the controller only needs to prime the puck + flip
/// follow-me on.

abstract class _$MapCameraController extends $Notifier<MapCameraState> {
  MapCameraState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MapCameraState, MapCameraState>;
    final element = ref.element as $ClassProviderElement<AnyNotifier<MapCameraState, MapCameraState>, MapCameraState, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

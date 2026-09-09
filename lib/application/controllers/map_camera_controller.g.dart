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
/// timestamp is treated as the map engine echoing the controller's own
/// move back on `viewportUpdates`; anything older is a genuine user pan.
/// Per CLAUDE.md §State "préférer la déduction au tracking" — no
/// explicit boolean flag + no timer lifecycle to juggle.
///
/// Keyed to the `FlutterMapMapViewWidget`'s `onReady` callback: the
/// widget publishes a [MapView] adapter via [mapViewProvider] and the
/// controller lazily attaches its listeners on first use.
///
/// ## Initial-camera seeding (Phase 07-07, kept under flutter_map)
///
/// [openForSession] deliberately does NOT issue any camera move on
/// first open: the initial viewport is supplied through the widget
/// constructor (`initialCamera`, see `_buildMapStack` in
/// `map_screen.dart`) at build time. By the time [openForSession]
/// runs, the map already shows the right viewport and the controller
/// only needs to prime the puck + flip
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
/// timestamp is treated as the map engine echoing the controller's own
/// move back on `viewportUpdates`; anything older is a genuine user pan.
/// Per CLAUDE.md §State "préférer la déduction au tracking" — no
/// explicit boolean flag + no timer lifecycle to juggle.
///
/// Keyed to the `FlutterMapMapViewWidget`'s `onReady` callback: the
/// widget publishes a [MapView] adapter via [mapViewProvider] and the
/// controller lazily attaches its listeners on first use.
///
/// ## Initial-camera seeding (Phase 07-07, kept under flutter_map)
///
/// [openForSession] deliberately does NOT issue any camera move on
/// first open: the initial viewport is supplied through the widget
/// constructor (`initialCamera`, see `_buildMapStack` in
/// `map_screen.dart`) at build time. By the time [openForSession]
/// runs, the map already shows the right viewport and the controller
/// only needs to prime the puck + flip
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
  /// timestamp is treated as the map engine echoing the controller's own
  /// move back on `viewportUpdates`; anything older is a genuine user pan.
  /// Per CLAUDE.md §State "préférer la déduction au tracking" — no
  /// explicit boolean flag + no timer lifecycle to juggle.
  ///
  /// Keyed to the `FlutterMapMapViewWidget`'s `onReady` callback: the
  /// widget publishes a [MapView] adapter via [mapViewProvider] and the
  /// controller lazily attaches its listeners on first use.
  ///
  /// ## Initial-camera seeding (Phase 07-07, kept under flutter_map)
  ///
  /// [openForSession] deliberately does NOT issue any camera move on
  /// first open: the initial viewport is supplied through the widget
  /// constructor (`initialCamera`, see `_buildMapStack` in
  /// `map_screen.dart`) at build time. By the time [openForSession]
  /// runs, the map already shows the right viewport and the controller
  /// only needs to prime the puck + flip
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
/// timestamp is treated as the map engine echoing the controller's own
/// move back on `viewportUpdates`; anything older is a genuine user pan.
/// Per CLAUDE.md §State "préférer la déduction au tracking" — no
/// explicit boolean flag + no timer lifecycle to juggle.
///
/// Keyed to the `FlutterMapMapViewWidget`'s `onReady` callback: the
/// widget publishes a [MapView] adapter via [mapViewProvider] and the
/// controller lazily attaches its listeners on first use.
///
/// ## Initial-camera seeding (Phase 07-07, kept under flutter_map)
///
/// [openForSession] deliberately does NOT issue any camera move on
/// first open: the initial viewport is supplied through the widget
/// constructor (`initialCamera`, see `_buildMapStack` in
/// `map_screen.dart`) at build time. By the time [openForSession]
/// runs, the map already shows the right viewport and the controller
/// only needs to prime the puck + flip
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

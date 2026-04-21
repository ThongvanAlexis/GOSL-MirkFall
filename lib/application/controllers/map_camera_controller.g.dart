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
/// The detection heuristic uses a pending-flag + debounce window. Before
/// every controller-initiated `moveCameraTo`, we set `_cameraMovePending`
/// and start a 1-second timer; viewport updates arriving while the flag
/// is set are ignored (they ARE the controller's own camera moves
/// echoing back through MapLibre's `onCameraIdle` callback). Updates
/// arriving OUTSIDE the pending window are treated as user pan.
///
/// Keyed to the Plan 07-06 `MapLibreMapViewWidget`'s `onReady` callback:
/// the widget publishes a [MapView] adapter via [mapViewProvider] and the
/// controller lazily attaches its listeners on first use.

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
/// The detection heuristic uses a pending-flag + debounce window. Before
/// every controller-initiated `moveCameraTo`, we set `_cameraMovePending`
/// and start a 1-second timer; viewport updates arriving while the flag
/// is set are ignored (they ARE the controller's own camera moves
/// echoing back through MapLibre's `onCameraIdle` callback). Updates
/// arriving OUTSIDE the pending window are treated as user pan.
///
/// Keyed to the Plan 07-06 `MapLibreMapViewWidget`'s `onReady` callback:
/// the widget publishes a [MapView] adapter via [mapViewProvider] and the
/// controller lazily attaches its listeners on first use.
final class MapCameraControllerProvider
    extends $NotifierProvider<MapCameraController, MapCameraState> {
  /// Orchestrates the map camera on the /map screen:
  /// - Opens a session view with Z=[kInitialSessionMapZoom] zoom centred on
  ///   the latest session fix (or the last-known fix from the active
  ///   session controller).
  /// - Maintains follow-me: new fixes cause the camera to pan, preserving
  ///   the user's current zoom.
  /// - Detects manual user pan (a viewport update NOT triggered by this
  ///   controller's own `moveCameraTo` calls) and disables follow-me.
  ///
  /// The detection heuristic uses a pending-flag + debounce window. Before
  /// every controller-initiated `moveCameraTo`, we set `_cameraMovePending`
  /// and start a 1-second timer; viewport updates arriving while the flag
  /// is set are ignored (they ARE the controller's own camera moves
  /// echoing back through MapLibre's `onCameraIdle` callback). Updates
  /// arriving OUTSIDE the pending window are treated as user pan.
  ///
  /// Keyed to the Plan 07-06 `MapLibreMapViewWidget`'s `onReady` callback:
  /// the widget publishes a [MapView] adapter via [mapViewProvider] and the
  /// controller lazily attaches its listeners on first use.
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
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MapCameraState>(value),
    );
  }
}

String _$mapCameraControllerHash() =>
    r'45ffae9b58583a7da327aa20fd1cbc3b7d5e4c1c';

/// Orchestrates the map camera on the /map screen:
/// - Opens a session view with Z=[kInitialSessionMapZoom] zoom centred on
///   the latest session fix (or the last-known fix from the active
///   session controller).
/// - Maintains follow-me: new fixes cause the camera to pan, preserving
///   the user's current zoom.
/// - Detects manual user pan (a viewport update NOT triggered by this
///   controller's own `moveCameraTo` calls) and disables follow-me.
///
/// The detection heuristic uses a pending-flag + debounce window. Before
/// every controller-initiated `moveCameraTo`, we set `_cameraMovePending`
/// and start a 1-second timer; viewport updates arriving while the flag
/// is set are ignored (they ARE the controller's own camera moves
/// echoing back through MapLibre's `onCameraIdle` callback). Updates
/// arriving OUTSIDE the pending window are treated as user pan.
///
/// Keyed to the Plan 07-06 `MapLibreMapViewWidget`'s `onReady` callback:
/// the widget publishes a [MapView] adapter via [mapViewProvider] and the
/// controller lazily attaches its listeners on first use.

abstract class _$MapCameraController extends $Notifier<MapCameraState> {
  MapCameraState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MapCameraState, MapCameraState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MapCameraState, MapCameraState>,
              MapCameraState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

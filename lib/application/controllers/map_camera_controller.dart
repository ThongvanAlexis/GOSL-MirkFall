// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_camera_controller.g.dart';

/// Sealed state machine for [MapCameraController].
///
/// Transitions driven by the controller:
/// - `Idle` — no session open; map stays where it is.
/// - `Centering` — waiting on first fix after `openForSession(id)` with
///   no prior fix available; UI surfaces "En attente du GPS…".
/// - `FollowingUser` — camera pans to every new fix (zoom preserved).
/// - `FreePan` — user manually panned; camera does not auto-follow.
sealed class MapCameraState {
  const MapCameraState();
}

/// No session open; the camera stays put and the controller ignores fix
/// updates. Initial state.
final class MapCameraIdle extends MapCameraState {
  const MapCameraIdle();
}

/// A session is open but no fix has arrived yet. The controller's
/// internal listener will transition to [MapCameraFollowing] as soon as
/// the first fix lands.
final class MapCameraCentering extends MapCameraState {
  const MapCameraCentering({required this.sessionId});

  final SessionId sessionId;
}

/// Follow-me is active. Every new fix triggers [MapView.moveCameraTo]
/// at the current zoom level. Manual pan transitions the controller to
/// [MapCameraFreePan].
final class MapCameraFollowing extends MapCameraState {
  const MapCameraFollowing({required this.sessionId});

  final SessionId sessionId;
}

/// User manually panned. Follow-me is disabled; new fixes are observed
/// (via [lastKnownFix]) but do NOT trigger camera moves. Toggling
/// follow-me re-centers on the last fix.
final class MapCameraFreePan extends MapCameraState {
  const MapCameraFreePan({required this.sessionId});

  final SessionId sessionId;
}

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
@Riverpod(keepAlive: true)
class MapCameraController extends _$MapCameraController {
  static final Logger _log = Logger('application.controllers.map_camera');

  MapView? _mapView;
  StreamSubscription<({double latitude, double longitude, double zoom})>? _viewportSub;
  bool _cameraMovePending = false;
  Timer? _pendingResetTimer;
  double _currentZoom = kInitialSessionMapZoom.toDouble();

  @override
  MapCameraState build() {
    ref.onDispose(_tearDown);
    // Two listener sources wired declaratively in build (both use
    // ref.listen so Riverpod owns their lifecycle + auto-cancels on
    // provider dispose — no per-field subscription bookkeeping):
    //
    //  1. mapViewProvider — adapter publications from the widget's
    //     onReady callback (fires AFTER build, so a lazy-attach from a
    //     public-entry call would otherwise miss the echoed viewport
    //     updates for subscribers that only listen post-ready).
    //  2. activeSessionControllerProvider — GPS fixes + session
    //     lifecycle (clear the puck on session-stop).
    //
    // The remaining `_viewportSub` is the ONLY manual StreamSubscription
    // because MapView.viewportUpdates is a plain Stream, not a provider.
    ref.listen<MapView?>(mapViewProvider, (previous, next) {
      _attachMapViewIfReady();
    });
    ref.listen<AsyncValue<ActiveSessionState>>(activeSessionControllerProvider, (previous, next) {
      _onSessionUpdate(next);
    });
    return const MapCameraIdle();
  }

  /// Opens the map for [sessionId]: centres the camera on the latest
  /// known fix at Z=[kInitialSessionMapZoom] and enables follow-me. If
  /// no fix is available yet, transitions to [MapCameraCentering] and
  /// waits for the first fix via the active-session listener.
  Future<void> openForSession(SessionId sessionId) async {
    _attachMapViewIfReady();
    final MapView? mapView = ref.read(mapViewProvider);
    final Fix? latestFix = _currentSessionLatestFix();

    if (mapView != null && latestFix != null) {
      // No camera-moving method-channel call on first open — initial
      // viewport is supplied at widget-build time via
      // `MapLibreMap.initialCameraPosition`. See "iOS initial-camera
      // seeding" in the class docstring for the full rationale. We
      // still track `_currentZoom` so subsequent GPS-driven moves
      // preserve the zoom the user started at + prime the puck on
      // the initial fix so the blue dot doesn't wait for fix #2.
      _currentZoom = kInitialSessionMapZoom.toDouble();
      unawaited(() async {
        try {
          await mapView.setUserLocation(latestFix);
        } on Object catch (e, st) {
          _log.warning('setUserLocation on openForSession failed (non-fatal)', e, st);
        }
      }());
      await mapView.setFollowMeEnabled(true);
      state = MapCameraFollowing(sessionId: sessionId);
      return;
    }

    // Either the MapView isn't ready yet or we have no fix; transition
    // to Centering and let the active-session listener drive the next
    // state change.
    state = MapCameraCentering(sessionId: sessionId);
  }

  /// Toggles follow-me. When enabling, re-centres on the last known fix
  /// (if any) and sets the adapter's follow-me flag. When disabling,
  /// leaves the camera where it is.
  Future<void> toggleFollowMe() async {
    _attachMapViewIfReady();
    final MapView? mapView = ref.read(mapViewProvider);
    if (mapView == null) return;
    final current = state;
    if (current is MapCameraFollowing) {
      await mapView.setFollowMeEnabled(false);
      state = MapCameraFreePan(sessionId: current.sessionId);
      return;
    }
    if (current is MapCameraFreePan) {
      await mapView.setFollowMeEnabled(true);
      // Re-centre on the last fix if available.
      final Fix? fix = _currentSessionLatestFix();
      if (fix != null) {
        await _moveCameraTo(mapView, latitude: fix.latitude, longitude: fix.longitude, zoom: _currentZoom);
      }
      state = MapCameraFollowing(sessionId: current.sessionId);
    }
  }

  void _attachMapViewIfReady() {
    final MapView? current = ref.read(mapViewProvider);
    if (current == null) {
      // Adapter was cleared (MapScreen popped). Drop our stale
      // reference + cancel the viewport subscription so no further
      // callbacks fire against a disposed native surface. Without
      // this the controller kept calling setUserLocation /
      // moveCameraTo on a dead adapter, cascading into iOS crashes
      // on the 2026-04-21 device smoke.
      //
      // Also cancel `_pendingResetTimer` — it filters echoes from the
      // MapView's viewport stream, pointless without a MapView. Keeps
      // widget-test teardown clean (otherwise the 1 s timer outlives
      // `tester.pumpAndSettle` and trips the test framework's
      // "Timer still pending after widget tree was disposed" check).
      _viewportSub?.cancel();
      _viewportSub = null;
      _pendingResetTimer?.cancel();
      _pendingResetTimer = null;
      _cameraMovePending = false;
      _mapView = null;
      return;
    }
    if (identical(current, _mapView)) return;
    _viewportSub?.cancel();
    _mapView = current;
    _viewportSub = current.viewportUpdates.listen(
      _onViewportUpdate,
      onError: (Object e, StackTrace st) {
        _log.warning('viewport stream error', e, st);
      },
    );
  }

  /// Reacts to an active-session state change emitted by
  /// [activeSessionControllerProvider]. Tracking → pan / update puck via
  /// [_onFix]; any non-Tracking variant → clear the puck (without this
  /// the blue dot would stay painted at the last-known fix forever
  /// after the user stops tracking).
  void _onSessionUpdate(AsyncValue<ActiveSessionState> next) {
    final value = next.value;
    if (value is Tracking) {
      _onFix(value.lastFix);
      return;
    }
    final MapView? mapView = _mapView;
    if (mapView == null) return;
    unawaited(() async {
      try {
        await mapView.setUserLocation(null);
      } on Object catch (e, st) {
        _log.warning('setUserLocation(null) failed on session-stop (non-fatal)', e, st);
      }
    }());
  }

  /// Handles a new fix from the active session. Always pushes the fix
  /// into [MapView.setUserLocation] so the location-puck stays in sync,
  /// independently of the camera follow-me state — the dot tracks the
  /// user even when they're free-panning.
  ///
  /// Camera behaviour:
  /// - [MapCameraCentering] → initial centre + transition to Following.
  /// - [MapCameraFollowing] → pan to the fix (preserves zoom).
  /// - [MapCameraFreePan] / [MapCameraIdle] → observe + update the puck
  ///   only.
  Future<void> _onFix(Fix? fix) async {
    if (fix == null) return;
    _attachMapViewIfReady();
    final MapView? mapView = _mapView;
    if (mapView == null) return;
    // Update the location puck on every fix, regardless of state. This
    // was the missing piece in the 2026-04-21 device smoke: the adapter
    // had setUserLocation wired but no one called it.
    unawaited(() async {
      try {
        await mapView.setUserLocation(fix);
      } on Object catch (e, st) {
        _log.warning('setUserLocation failed (non-fatal — puck will update on next fix)', e, st);
      }
    }());
    final current = state;
    if (current is MapCameraCentering) {
      await _moveCameraTo(mapView, latitude: fix.latitude, longitude: fix.longitude, zoom: kInitialSessionMapZoom.toDouble());
      await mapView.setFollowMeEnabled(true);
      state = MapCameraFollowing(sessionId: current.sessionId);
      return;
    }
    if (current is MapCameraFollowing) {
      await _moveCameraTo(mapView, latitude: fix.latitude, longitude: fix.longitude, zoom: _currentZoom);
      return;
    }
    // FreePan / Idle: observe but do not move the camera — the puck
    // has already been updated above.
  }

  /// Wraps [MapView.moveCameraTo] with the pending-flag bookkeeping so
  /// the controller's own camera moves do not feed back as user pans.
  Future<void> _moveCameraTo(MapView mapView, {required double latitude, required double longitude, required double zoom}) async {
    _cameraMovePending = true;
    _pendingResetTimer?.cancel();
    _pendingResetTimer = Timer(kMapCameraPendingMoveDebounce, () {
      _cameraMovePending = false;
    });
    _currentZoom = zoom;
    await mapView.moveCameraTo(latitude: latitude, longitude: longitude, zoom: zoom);
  }

  /// Handles a settled viewport event. If the flag is set, the move is
  /// our own echo and we ignore it. Otherwise the user manually panned
  /// — transition Following → FreePan + drop follow-me.
  Future<void> _onViewportUpdate(({double latitude, double longitude, double zoom}) v) async {
    _currentZoom = v.zoom;
    if (_cameraMovePending) {
      // This update is the settled echo of our own moveCameraTo call.
      // Clear the flag — subsequent updates within the debounce window
      // are treated as user pans (the legitimate user-intent signal).
      _cameraMovePending = false;
      _pendingResetTimer?.cancel();
      return;
    }
    final current = state;
    if (current is MapCameraFollowing) {
      final MapView? mapView = _mapView;
      if (mapView != null) {
        await mapView.setFollowMeEnabled(false);
      }
      state = MapCameraFreePan(sessionId: current.sessionId);
    }
  }

  Fix? _currentSessionLatestFix() {
    final AsyncValue<ActiveSessionState> snap = ref.read(activeSessionControllerProvider);
    final ActiveSessionState? value = snap.value;
    if (value is Tracking) return value.lastFix;
    return null;
  }

  void _tearDown() {
    _pendingResetTimer?.cancel();
    _pendingResetTimer = null;
    _viewportSub?.cancel();
    _viewportSub = null;
    _mapView = null;
  }
}

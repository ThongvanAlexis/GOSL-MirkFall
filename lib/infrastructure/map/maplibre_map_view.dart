// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_theme.dart';
import 'package:mirkfall/domain/map/map_view.dart';

import 'pmtiles_source.dart';
import 'style_rewriter.dart';

/// The ONLY file under `lib/` allowed to import `package:maplibre_gl/...`.
///
/// Enforced by `tool/check_avoid_maplibre_leak.dart` (MAP-06 CI gate).
/// Every other `lib/` module consumes the [MapView] domain port; MapLibre
/// SDK types (`MapLibreMapController`, `SymbolOptions`, `CameraUpdate`,
/// `LatLng`) never bubble above this boundary.
///
/// ## Phase 07 stub — mirk_fog / RepaintBoundary note
///
/// The bundled `assets/maps/style.json` ships `mirk_fog` as a transparent
/// `background` layer (background-opacity=0) — it paints nothing, so no
/// Flutter-level `RepaintBoundary` is wrapped around the map surface in
/// Phase 07. Phase 09 (mirk renderer) will:
///
/// 1. Replace the `mirk_fog` layer with a real `fill`-from-GeoJSON layer
///    wired to the MirkRenderer source, AND
/// 2. Own the `RepaintBoundary` wrapping of the fog surface when the
///    overlay actually paints.
///
/// This adapter INTENTIONALLY does NOT introduce a `RepaintBoundary` at
/// the widget level — that responsibility belongs to the Phase 09 owner
/// of the fog render pass. Do not add one pre-emptively; it would mask a
/// Phase 09 design decision.
class MapLibreMapViewWidget extends StatefulWidget {
  const MapLibreMapViewWidget({
    super.key,
    required this.styleRewriter,
    required this.pmtilesSource,
    required this.onReady,
    this.initialCountry,
    this.initialCamera = const CameraLatLngZoom(latitude: 0, longitude: 0, zoom: 2),
  });

  /// Style-rewriter used to swap the PMTiles URI into the bundled style
  /// at initial load and on every subsequent `showMap` call.
  final StyleRewriter styleRewriter;

  /// Pmtiles-URI resolver — supplies the URI for [initialCountry] during
  /// widget `initState` and is re-queried by [showMap].
  final PmtilesSource pmtilesSource;

  /// Fires once after the first `onStyleLoaded` callback with a
  /// fully-initialised [MapView] adapter. Callers (Plan 07-05
  /// MapCameraController, Plan 07-06 MapScreen) store the instance and
  /// drive the map through the port.
  final ValueChanged<MapView> onReady;

  /// Country to display on first render. `null` = world basemap.
  final CountryCode? initialCountry;

  /// Initial camera target. Defaults to a zoom-2 view over (0,0).
  final CameraLatLngZoom initialCamera;

  @override
  State<MapLibreMapViewWidget> createState() => _MapLibreMapViewWidgetState();
}

/// Narrow record-alike for the initial camera position. Declared as a
/// dedicated class (not the MapLibre `CameraPosition`) so the widget
/// public surface stays MapLibre-type-free even though the adapter body
/// below bridges to the SDK class.
class CameraLatLngZoom {
  const CameraLatLngZoom({required this.latitude, required this.longitude, required this.zoom});
  final double latitude;
  final double longitude;
  final double zoom;
}

class _MapLibreMapViewWidgetState extends State<MapLibreMapViewWidget> {
  static final Logger _log = Logger('infrastructure.map.maplibre');

  String? _initialStyleJson;
  MapLibreMapController? _controller;
  _MapLibreMapViewAdapter? _adapter;

  @override
  void initState() {
    super.initState();
    _prefetchStyle();
  }

  Future<void> _prefetchStyle() async {
    try {
      final String styleJson = await widget.styleRewriter.rewriteStyleForCountry(widget.initialCountry);
      if (!mounted) return;
      setState(() {
        _initialStyleJson = styleJson;
      });
    } on Object catch (e, st) {
      _log.severe('Failed to load initial style: $e', e, st);
      // Leave _initialStyleJson null — build() renders a placeholder
      // until the caller retries. Do not crash the widget tree.
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? styleJson = _initialStyleJson;
    if (styleJson == null) {
      // Style not yet loaded — render a blank placeholder. Production
      // callers typically wrap this widget in their own loading UI.
      return const SizedBox.expand();
    }

    // Platform-view rebuild guard (RESEARCH Pitfall #9): stable key
    // protects against parent-key churn flashing the platform view.
    return KeyedSubtree(
      key: const ValueKey<String>('mirkfall_map_view'),
      child: MapLibreMap(
        styleString: styleJson,
        initialCameraPosition: CameraPosition(target: LatLng(widget.initialCamera.latitude, widget.initialCamera.longitude), zoom: widget.initialCamera.zoom),
        trackCameraPosition: true,
        // Hide MapLibre's default attribution button off-screen; Phase 07-06
        // paints the MirkFall custom attribution surface instead.
        attributionButtonMargins: const math.Point<num>(-100, -100),
        onMapCreated: (MapLibreMapController c) {
          _controller = c;
        },
        onStyleLoadedCallback: () {
          final MapLibreMapController? c = _controller;
          if (c == null) return;
          final _MapLibreMapViewAdapter adapter = _adapter ??= _MapLibreMapViewAdapter(
            controller: c,
            styleRewriter: widget.styleRewriter,
            pmtilesSource: widget.pmtilesSource,
          );
          widget.onReady(adapter);
        },
      ),
    );
  }

  @override
  void dispose() {
    // The adapter owns the broadcast StreamController — close it here so
    // subscribers get the `onDone` notification.
    unawaited(_adapter?.dispose());
    super.dispose();
  }
}

/// Concrete [MapView] adapter backed by [MapLibreMapController].
///
/// Ownership:
/// - The adapter does NOT own the Flutter widget lifecycle — the
///   [MapLibreMapViewWidget] State does. Adapter `dispose()` releases
///   the broadcast controller + unsubscribes from the controller's
///   camera updates but leaves the widget's platform-view teardown to
///   Flutter.
///
/// Open Question #1 (camera preservation) is implemented in [showMap]:
/// the current camera is captured BEFORE `setStyle`, re-applied AFTER
/// `onStyleLoaded`.
///
/// Open Question #2 (source swap vs setStyle) is implemented by falling
/// back to `setStyle` every time. Rationale: [VectorSourceProperties.url]
/// documents the supported protocols as HTTP/HTTPS only (see
/// maplibre_gl_platform_interface 0.25.0 source_properties.dart:11). PMTiles
/// URIs like `pmtiles://file:///…` are handled by a custom protocol
/// handler that MapLibre Native wires up at style-load time — swapping
/// just the source via `removeSource+addSource` bypasses that wiring and
/// yields blank tiles. `setStyle` is the correct path in maplibre_gl
/// 0.25.0. Full-style re-parse is slower than a source swap but
/// negligible on the Phase 07 world+country style skeleton.
class _MapLibreMapViewAdapter implements MapView {
  _MapLibreMapViewAdapter({required MapLibreMapController controller, required StyleRewriter styleRewriter, required PmtilesSource pmtilesSource})
    : _controller = controller,
      _styleRewriter = styleRewriter,
      _pmtilesSource = pmtilesSource {
    // Subscribe to the controller's ChangeNotifier — every camera idle
    // bumps `cameraPosition`, which we re-emit on our broadcast stream.
    _cameraListener = () {
      final CameraPosition? cp = _controller.cameraPosition;
      if (cp == null) return;
      final ({double latitude, double longitude, double zoom}) event = (latitude: cp.target.latitude, longitude: cp.target.longitude, zoom: cp.zoom);
      if (!_viewportCtrl.isClosed) _viewportCtrl.add(event);
    };
    _controller.addListener(_cameraListener);
  }

  static final Logger _log = Logger('infrastructure.map.maplibre');

  final MapLibreMapController _controller;
  final StyleRewriter _styleRewriter;
  // ignore: unused_field — Phase 07 fallbacks to setStyle via the rewriter; kept for Phase 09 where source-swap becomes viable.
  final PmtilesSource _pmtilesSource;
  final StreamController<({double latitude, double longitude, double zoom})> _viewportCtrl =
      StreamController<({double latitude, double longitude, double zoom})>.broadcast();

  /// In-memory registry of POI symbols — keyed by the caller-supplied
  /// string ID so [removePointOfInterest] can look them up.
  final Map<String, Symbol> _poiSymbols = <String, Symbol>{};

  /// Single symbol tracking the user-location indicator; `null` when no
  /// fix has been supplied yet.
  Symbol? _userLocationSymbol;

  late final VoidCallback _cameraListener;
  bool _followMe = false;
  bool _disposed = false;

  @override
  Future<void> showMap(CountryCode? country) async {
    _ensureNotDisposed();

    // Open Question #1: capture camera BEFORE setStyle.
    final CameraPosition? prev = _controller.cameraPosition;
    final CameraPosition preserved = prev ?? const CameraPosition(target: LatLng(0, 0), zoom: 2);
    _log.info(
      'showMap(${country?.value ?? 'world'}): preserving camera target=(${preserved.target.latitude},${preserved.target.longitude}) zoom=${preserved.zoom}',
    );

    final String rewritten = await _styleRewriter.rewriteStyleForCountry(country);
    await _controller.setStyle(rewritten);

    // Re-apply camera AFTER setStyle resolves. MapLibre's setStyle
    // typically keeps the camera, but resetting explicitly covers the
    // edge case where a style carries its own initial camera.
    await _controller.moveCamera(CameraUpdate.newCameraPosition(preserved));
    _log.info('showMap(${country?.value ?? 'world'}): camera re-applied after setStyle');
  }

  @override
  Future<void> moveCameraTo({required double latitude, required double longitude, required double zoom}) async {
    _ensureNotDisposed();
    await _controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(latitude, longitude), zoom: zoom)));
  }

  @override
  Future<void> setTheme(MapTheme theme) async {
    _ensureNotDisposed();
    // Phase 07 ships a single theme (Standard). RpgParchment is a Phase
    // 13 stub; the adapter records the intent so future work can plug a
    // variant style.json without reshaping the port.
    _log.fine('setTheme(${theme.toJsonString()}) — Phase 07 no-op (single theme shipped)');
  }

  @override
  Future<void> setUserLocation(Fix? fix) async {
    _ensureNotDisposed();
    if (fix == null) {
      final Symbol? existing = _userLocationSymbol;
      if (existing != null) {
        await _controller.removeSymbol(existing);
        _userLocationSymbol = null;
      }
      return;
    }
    final LatLng pos = LatLng(fix.latitude, fix.longitude);
    final Symbol? existing = _userLocationSymbol;
    if (existing == null) {
      _userLocationSymbol = await _controller.addSymbol(SymbolOptions(geometry: pos, iconImage: 'dot', iconSize: 1.0));
    } else {
      await _controller.updateSymbol(existing, SymbolOptions(geometry: pos));
    }
    // Follow-me: centre the camera on the new fix. Uses animateCamera
    // so the motion is smooth rather than a jarring jump.
    if (_followMe) {
      await _controller.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }

  @override
  Future<({double latitude, double longitude, double zoom})> queryViewport() async {
    _ensureNotDisposed();
    final CameraPosition? cp = await _controller.queryCameraPosition();
    if (cp == null) {
      return (latitude: 0.0, longitude: 0.0, zoom: 0.0);
    }
    return (latitude: cp.target.latitude, longitude: cp.target.longitude, zoom: cp.zoom);
  }

  @override
  Stream<({double latitude, double longitude, double zoom})> get viewportUpdates => _viewportCtrl.stream;

  @override
  Future<void> markVisited(List<({double latitude, double longitude})> polygon) async {
    _ensureNotDisposed();
    // Phase 07 stub — revealed-tile integration lands in Phase 09 with
    // the real MirkRenderer. Record intent at FINE so future plumbing
    // can be traced without spamming INFO logs in production.
    _log.fine('markVisited(${polygon.length} vertices) — Phase 07 stub, no visual change');
  }

  @override
  Future<void> addPointOfInterest({required String id, required double latitude, required double longitude, required String iconId}) async {
    _ensureNotDisposed();
    // Idempotent — calling twice with the same id replaces the existing marker.
    final Symbol? existing = _poiSymbols[id];
    if (existing != null) {
      await _controller.updateSymbol(existing, SymbolOptions(geometry: LatLng(latitude, longitude), iconImage: iconId));
      return;
    }
    final Symbol s = await _controller.addSymbol(SymbolOptions(geometry: LatLng(latitude, longitude), iconImage: iconId));
    _poiSymbols[id] = s;
  }

  @override
  Future<void> removePointOfInterest(String id) async {
    _ensureNotDisposed();
    final Symbol? s = _poiSymbols.remove(id);
    if (s != null) {
      await _controller.removeSymbol(s);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      _controller.removeListener(_cameraListener);
    } on Object catch (_) {
      // Controller may already be disposed by the widget lifecycle —
      // swallow; the dispose contract is idempotent.
    }
    await _viewportCtrl.close();
  }

  @override
  bool get isFollowMeEnabled => _followMe;

  @override
  Future<void> setFollowMeEnabled(bool enabled) async {
    _ensureNotDisposed();
    _followMe = enabled;
    // No auto-pan here — [MapCameraController] in Plan 07-05 orchestrates
    // the follow-me motion by subscribing to Fix updates + calling
    // moveCameraTo. The adapter just tracks the flag.
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('MapLibreMapView adapter: method called after dispose()');
    }
  }
}

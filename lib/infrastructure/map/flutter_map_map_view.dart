// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_theme.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'map_theme_loader.dart';
import 'pmtiles_source.dart';

/// Narrow record-alike for the initial camera position. Declared as a
/// dedicated class (not the engine's `MapCamera` / `LatLng`) so the
/// widget's public surface stays engine-type-free even though the
/// adapter body below bridges to the flutter_map classes.
class CameraLatLngZoom {
  const CameraLatLngZoom({required this.latitude, required this.longitude, required this.zoom});
  final double latitude;
  final double longitude;
  final double zoom;
}

/// The ONLY place under `lib/` where `FlutterMap`, `MapController`,
/// `MapOptions` and `VectorTileLayer` are instantiated.
///
/// Enforced by `tool/check_avoid_flutter_map_leak.dart` (MAP-06 CI gate,
/// Phase 09.1). Every other `lib/` module consumes the [MapView] domain
/// port; engine types never bubble above this boundary.
///
/// Composition (bottom-to-top, the children order IS the z-order):
/// 1. `VectorTileLayer` — local PMTiles archive through
///    `PmTilesVectorTileProvider`, theme compiled once per [MapTheme] by
///    [MapThemeLoader].
/// 2. [fogLayers] — injected by the caller (plan 09.1-07 mounts the
///    `FogLayer` here so the fog is painted on the SAME canvas as the
///    tiles, the BUG-014 architectural fix). Empty until then.
/// 3. `CircleLayer` — the user-location puck, mounted only while a fix
///    is known.
///
/// Lifecycle: the widget publishes its [MapView] adapter through
/// [onReady] from `MapOptions.onMapReady` (a post-frame callback fired
/// after the first `FlutterMap` render), because `MapController.camera`
/// / `move` throw before that point.
class FlutterMapMapViewWidget extends StatefulWidget {
  const FlutterMapMapViewWidget({
    super.key,
    required this.pmtilesSource,
    required this.onReady,
    this.initialCamera = const CameraLatLngZoom(latitude: 0, longitude: 0, zoom: kMapWorldOverviewZoom),
    this.initialCountry,
    this.initialTheme = const MapThemeStandard(),
    this.fogLayers = const <Widget>[],
    this.themeLoader,
    this.cacheFolderOverride,
  });

  /// Resolves `CountryCode?` → absolute PMTiles path, at first mount and
  /// on every subsequent [MapView.showMap].
  final PmtilesSource pmtilesSource;

  /// Fires exactly once, after the first `FlutterMap` render, with a
  /// fully-initialised [MapView] adapter. Callers (MapCameraController,
  /// MapScreen) store the instance and drive the map through the port.
  final ValueChanged<MapView> onReady;

  /// Initial camera target. Defaults to the world overview over (0,0).
  final CameraLatLngZoom initialCamera;

  /// Country to display on first render. `null` = world basemap.
  final CountryCode? initialCountry;

  /// Theme compiled at first mount.
  final MapTheme initialTheme;

  /// Widgets inserted between the tile layer and the puck (same canvas).
  final List<Widget> fogLayers;

  /// Test seam — `null` uses a [MapThemeLoader] over `rootBundle`.
  final MapThemeLoader? themeLoader;

  /// Test seam — root directory of the vector-tile file cache. `null`
  /// uses `getTemporaryDirectory()` (unavailable in widget tests).
  final Future<Directory> Function()? cacheFolderOverride;

  @override
  State<FlutterMapMapViewWidget> createState() => _FlutterMapMapViewWidgetState();
}

class _FlutterMapMapViewWidgetState extends State<FlutterMapMapViewWidget> {
  static final Logger _log = Logger('infrastructure.map.flutter_map');

  /// Cache-directory + `ValueKey` segment used while the world archive
  /// is mounted (before any country swap).
  static const String _worldArchiveKey = 'world';

  final MapController _mapController = MapController();
  late final _FlutterMapMapViewAdapter _adapter;
  late final MapThemeLoader _themeLoader;

  vtr.Theme? _theme;
  _ArchiveTileProvider? _tileProvider;
  String _archiveKey = _worldArchiveKey;
  String? _currentArchivePath;
  Fix? _userFix;
  bool _ready = false;

  /// Serialises archive swaps: a `showMap` landing while the initial
  /// open is still in flight must wait for it, otherwise two providers
  /// could be mounted / closed out of order.
  Future<void> _swapChain = Future<void>.value();

  /// True once `MapOptions.onMapReady` fired — from then on
  /// `MapController.camera` / `move` are safe to call.
  bool get isReady => _ready;

  CameraLatLngZoom get initialCamera => widget.initialCamera;

  @override
  void initState() {
    super.initState();
    _themeLoader = widget.themeLoader ?? MapThemeLoader();
    _adapter = _FlutterMapMapViewAdapter(controller: _mapController, host: this);
    unawaited(_loadInitialTheme());
    unawaited(_openInitialArchive());
  }

  /// Expected external failure (level 2): a corrupt bundled style keeps
  /// the placeholder on screen rather than crashing the route.
  Future<void> _loadInitialTheme() async {
    try {
      await applyTheme(widget.initialTheme);
    } on Object catch (e, st) {
      _log.severe('Failed to compile the initial map theme — staying on the placeholder', e, st);
    }
  }

  /// Expected external failure (level 2): a missing / unreadable archive
  /// keeps the placeholder on screen rather than crashing the route.
  Future<void> _openInitialArchive() async {
    try {
      await swapArchive(widget.initialCountry);
    } on Object catch (e, st) {
      _log.severe('Failed to open the initial PMTiles archive (${widget.initialCountry?.value ?? 'world'}) — staying on the placeholder', e, st);
    }
  }

  /// Compiles [theme] (memoised by [MapThemeLoader]) and re-keys the
  /// tile layer so the vector_map_tiles caches restart on the new id.
  Future<void> applyTheme(MapTheme theme) async {
    final vtr.Theme compiled = await _themeLoader.load(theme);
    if (!mounted) return;
    setState(() => _theme = compiled);
  }

  /// Hot-swaps the mounted PMTiles archive to [country]'s (or the world
  /// bundle). No-op when the resolved path is already mounted — an
  /// uninstalled country resolves to the world path, so no layer
  /// rebuild happens in that case.
  Future<void> swapArchive(CountryCode? country) {
    final Future<void> thisSwap = _swapChain.then((_) => _swapArchiveSerialised(country));
    _swapChain = thisSwap.then<void>((_) {}, onError: (Object e) => _log.fine('swapArchive chain: previous swap failed ($e) — chain continues'));
    return thisSwap;
  }

  Future<void> _swapArchiveSerialised(CountryCode? country) async {
    final String label = country?.value ?? _worldArchiveKey;
    final String path = await widget.pmtilesSource.forCountry(country);
    if (path == _currentArchivePath) {
      _log.fine('swapArchive($label): archive unchanged ($path) — no layer rebuild');
      return;
    }
    final _ArchiveTileProvider next = _ArchiveTileProvider(await PmTilesVectorTileProvider.fromSource(path).timeout(kPmtilesArchiveOpenTimeout));
    if (!mounted) {
      unawaited(next.closeWhenIdle());
      return;
    }
    final _ArchiveTileProvider? previous = _tileProvider;
    setState(() {
      _tileProvider = next;
      _archiveKey = _archiveKeyForPath(path);
      _currentArchivePath = path;
    });
    _log.info('swapArchive($label): archive "$_archiveKey" mounted from $path');
    if (previous != null) {
      // Never close before the new layer is mounted; `closeWhenIdle` then
      // waits for the outgoing layer's in-flight reads to drain.
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(previous.closeWhenIdle()));
    }
  }

  /// Archive identity for cache isolation: `world` for the bundle,
  /// `<alpha3>` for per-country files (`maps/countries/<alpha3>.pmtiles`).
  static String _archiveKeyForPath(String path) => p.basenameWithoutExtension(path);

  /// One file-cache sub-directory per archive (Pitfall 3: the
  /// vector_map_tiles cache key is `source/z/x/y/theme.id`, without the
  /// archive identity — a shared folder would serve stale country tiles
  /// after a hot-swap). [archiveKey] is bound at build time so a layer
  /// keyed on the previous archive never resolves the new folder.
  Future<Directory> Function() _cacheFolderProviderFor(String archiveKey) => () async {
    final Future<Directory> Function()? override = widget.cacheFolderOverride;
    final Directory root = override != null ? await override() : await getTemporaryDirectory();
    return Directory(p.join(root.path, kMapVectorTileCacheDirName, archiveKey));
  };

  void setUserFix(Fix? fix) {
    if (!mounted) return;
    setState(() => _userFix = fix);
  }

  void _onMapReady() {
    _ready = true;
    _log.info('FlutterMap ready (archive "$_archiveKey", theme "${_theme?.id}") — publishing the MapView adapter');
    widget.onReady(_adapter);
  }

  @override
  void dispose() {
    unawaited(_adapter.dispose());
    final _ArchiveTileProvider? provider = _tileProvider;
    _tileProvider = null;
    if (provider != null) unawaited(provider.closeWhenIdle());
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vtr.Theme? theme = _theme;
    final _ArchiveTileProvider? tileProvider = _tileProvider;
    if (theme == null || tileProvider == null) {
      // Theme or archive still loading — paint the style background so
      // the transition to the first tiles is seamless.
      return const ColoredBox(color: Color(kMapBackgroundColorArgb), child: SizedBox.expand());
    }
    final Fix? userFix = _userFix;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(widget.initialCamera.latitude, widget.initialCamera.longitude),
        initialZoom: widget.initialCamera.zoom,
        minZoom: kMapMinZoom,
        maxZoom: kMapMaxZoom,
        backgroundColor: const Color(kMapBackgroundColorArgb),
        // UX-02: rotation disabled, north is always up. The fog painter
        // (plan 09.1-04) compensates the layer TRANSLATION only; a rotated
        // canvas would leave un-fogged wedges at the viewport corners
        // (POC FOG-16 path (b) deferred).
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onMapReady: _onMapReady,
      ),
      children: <Widget>[
        VectorTileLayer(
          // Re-keying on archive OR theme change drops the layer's memory
          // caches with it (Pitfall 3).
          key: ValueKey<String>('$_archiveKey/${theme.id}'),
          tileProviders: TileProviders(<String, VectorTileProvider>{kMapStyleSourceKey: tileProvider}),
          theme: theme,
          cacheFolder: _cacheFolderProviderFor(_archiveKey),
        ),
        ...widget.fogLayers,
        if (userFix != null) CircleLayer<Object>(circles: <CircleMarker<Object>>[_buildUserPuck(userFix)]),
      ],
    );
  }

  /// Solid blue disc with a white stroke — the convention every major
  /// GPS app uses. A custom icon later is a one-file adapter change.
  static CircleMarker<Object> _buildUserPuck(Fix fix) => CircleMarker<Object>(
    point: LatLng(fix.latitude, fix.longitude),
    radius: kMapUserPuckRadiusPx,
    color: const Color(kMapUserPuckColorArgb),
    borderStrokeWidth: kMapUserPuckBorderWidthPx,
    borderColor: const Color(kMapUserPuckBorderColorArgb),
  );
}

/// Owns a [PmTilesVectorTileProvider] and closes its archive only once no
/// tile read is in flight.
///
/// `VectorTileLayer` keeps requesting tiles for a few frames after it is
/// re-keyed (country hot-swap) or unmounted (`/map` pop), and `pmtiles`
/// throws `StateError: withResource() may not be called on a closed Pool`
/// for any read issued after `archive.close()` — which surfaced as a
/// non-silent image error on every teardown. Reads requested after
/// [closeWhenIdle] are answered with a 404 [ProviderException], which the
/// vector_map_tiles pipeline renders as an empty tile without reporting;
/// the real close runs when the last in-flight read returns.
class _ArchiveTileProvider extends VectorTileProvider {
  _ArchiveTileProvider(this._inner);

  static final Logger _log = Logger('infrastructure.map.flutter_map');

  /// HTTP-style status the pipeline maps to "no tile here" (see
  /// `VectorTileLoadingCache._loadTile`).
  static const int _kTileAbsentStatusCode = 404;

  final PmTilesVectorTileProvider _inner;
  int _inFlightReadCount = 0;
  bool _closeRequested = false;
  bool _closed = false;

  @override
  int get maximumZoom => _inner.maximumZoom;

  @override
  int get minimumZoom => _inner.minimumZoom;

  @override
  TileProviderType get type => _inner.type;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    if (_closeRequested) {
      throw ProviderException(message: 'PMTiles archive closed — tile $tile dropped', retryable: Retryable.none, statusCode: _kTileAbsentStatusCode);
    }
    _inFlightReadCount++;
    try {
      return await _inner.provide(tile);
    } finally {
      _inFlightReadCount--;
      if (_closeRequested && _inFlightReadCount == 0) unawaited(_closeNow());
    }
  }

  /// Rejects further reads and closes the archive as soon as the in-flight
  /// ones drain. Idempotent.
  Future<void> closeWhenIdle() async {
    if (_closeRequested) return;
    _closeRequested = true;
    if (_inFlightReadCount == 0) await _closeNow();
  }

  Future<void> _closeNow() async {
    if (_closed) return;
    _closed = true;
    try {
      await _inner.archive.close();
    } on Object catch (e, st) {
      _log.fine('PMTiles archive close failed (already closed?)', e, st);
    }
  }
}

/// Concrete [MapView] adapter backed by flutter_map's [MapController].
///
/// Ownership: the adapter does NOT own the widget lifecycle — the
/// [FlutterMapMapViewWidget] State does, and delegates layer mutations
/// (archive swap, theme, puck) back to it through [_host]. Adapter
/// `dispose()` only releases the viewport broadcast + the event
/// subscription.
class _FlutterMapMapViewAdapter implements MapView {
  _FlutterMapMapViewAdapter({required MapController controller, required _FlutterMapMapViewWidgetState host}) : _controller = controller, _host = host {
    _eventSub = _controller.mapEventStream.listen(_onMapEvent);
  }

  static final Logger _log = Logger('infrastructure.map.flutter_map');

  final MapController _controller;
  final _FlutterMapMapViewWidgetState _host;
  final StreamController<({double latitude, double longitude, double zoom})> _viewportCtrl =
      StreamController<({double latitude, double longitude, double zoom})>.broadcast();

  late final StreamSubscription<MapEvent> _eventSub;
  bool _followMe = false;
  bool _disposed = false;

  /// Forwards EVERY map event, including the echo of the adapter's own
  /// `move()` — `MapCameraController` treats a viewport update landing
  /// right after `moveCameraTo` as that echo, so suppressing it here
  /// would break its user-pan detection.
  void _onMapEvent(MapEvent event) {
    if (_viewportCtrl.isClosed) return;
    _viewportCtrl.add((latitude: event.camera.center.latitude, longitude: event.camera.center.longitude, zoom: event.camera.zoom));
  }

  @override
  Future<void> showMap(CountryCode? country) async {
    if (!_aliveOrLog('showMap')) return;
    await _host.swapArchive(country);
  }

  @override
  Future<void> moveCameraTo({required double latitude, required double longitude, required double zoom}) async {
    if (!_aliveOrLog('moveCameraTo')) return;
    if (!_host.isReady) {
      _log.fine('moveCameraTo($latitude, $longitude, $zoom) before the first render — ignored');
      return;
    }
    final bool moved = _controller.move(LatLng(latitude, longitude), zoom);
    if (!moved) _log.fine('moveCameraTo($latitude, $longitude, $zoom): camera unchanged (already at target or outside constraints)');
  }

  @override
  Future<void> setTheme(MapTheme theme) async {
    if (!_aliveOrLog('setTheme')) return;
    await _host.applyTheme(theme);
  }

  @override
  Future<void> setUserLocation(Fix? fix) async {
    if (!_aliveOrLog('setUserLocation')) return;
    _host.setUserFix(fix);
    if (fix == null) {
      _log.info('setUserLocation(null): puck cleared');
    } else {
      _log.fine('setUserLocation: puck at (${fix.latitude}, ${fix.longitude})');
    }
  }

  @override
  Future<({double latitude, double longitude, double zoom})> queryViewport() async {
    if (!_aliveOrLog('queryViewport')) {
      return (latitude: 0.0, longitude: 0.0, zoom: 0.0);
    }
    if (!_host.isReady) {
      final CameraLatLngZoom initial = _host.initialCamera;
      return (latitude: initial.latitude, longitude: initial.longitude, zoom: initial.zoom);
    }
    final MapCamera camera = _controller.camera;
    return (latitude: camera.center.latitude, longitude: camera.center.longitude, zoom: camera.zoom);
  }

  @override
  Stream<({double latitude, double longitude, double zoom})> get viewportUpdates => _viewportCtrl.stream;

  @override
  Future<MirkViewportBbox> queryViewportBounds() async {
    if (!_aliveOrLog('queryViewportBounds')) {
      // Benign 0-bbox on a disposed adapter — callers (mapViewportProvider)
      // treat the next viewportUpdates emission as the recovery path.
      return MirkViewportBbox(south: 0.0, west: 0.0, north: 0.0, east: 0.0);
    }
    if (!_host.isReady) {
      throw StateError('FlutterMap not rendered yet — retry on the next viewportUpdates event');
    }
    final LatLngBounds bounds = _controller.camera.visibleBounds;
    return MirkViewportBbox(south: bounds.south, west: bounds.west, north: bounds.north, east: bounds.east);
  }

  @override
  Future<void> addPointOfInterest({required String id, required double latitude, required double longitude, required String iconId}) async {
    if (!_aliveOrLog('addPointOfInterest')) return;
    _log.fine('addPointOfInterest($id, $latitude, $longitude, $iconId) — Phase 11 marker layer not mounted yet');
  }

  @override
  Future<void> removePointOfInterest(String id) async {
    if (!_aliveOrLog('removePointOfInterest')) return;
    _log.fine('removePointOfInterest($id) — Phase 11 marker layer not mounted yet');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _eventSub.cancel();
    await _viewportCtrl.close();
  }

  @override
  bool get isFollowMeEnabled => _followMe;

  @override
  Future<void> setFollowMeEnabled(bool enabled) async {
    if (!_aliveOrLog('setFollowMeEnabled')) return;
    _followMe = enabled;
    // No auto-pan here — MapCameraController orchestrates the follow-me
    // motion by subscribing to Fix updates + calling moveCameraTo. The
    // adapter just tracks the flag.
  }

  /// Returns `true` when the adapter is still usable. Every public
  /// method early-exits on `false` rather than throwing: after a `/map`
  /// pop the widget disposes the adapter before the long-lived Riverpod
  /// controllers (`keepAlive: true`) learn the provider value is stale,
  /// and any listener firing in that window would land here.
  bool _aliveOrLog(String method) {
    if (_disposed) {
      _log.fine('$method called after dispose() — silently ignored');
      return false;
    }
    return true;
  }
}

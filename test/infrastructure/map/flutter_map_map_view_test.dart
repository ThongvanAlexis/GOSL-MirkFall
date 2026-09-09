// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/infrastructure/map/flutter_map_map_view.dart';
import 'package:mirkfall/infrastructure/map/map_theme_loader.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:path/path.dart' as p;
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../fakes/fake_installed_manifest_repository.dart';

typedef _Viewport = ({double latitude, double longitude, double zoom});

/// Serves the repository's real `assets/maps/style.json` from disk.
class _FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(await File(key).readAsBytes());
}

const CameraLatLngZoom _initialCamera = CameraLatLngZoom(latitude: 48.5397, longitude: 2.6553, zoom: 5.0);
const Duration _readyTimeout = Duration(seconds: 20);
const Duration _pumpStep = Duration(milliseconds: 50);
const Duration _teardownDrain = Duration(milliseconds: 150);
const Duration _tileSettleTime = Duration(milliseconds: 600);
const String _fraRelativePath = 'maps/countries/fra.pmtiles';

Fix _fix({required double lat, required double lon}) => Fix(
  id: FixId.parse('fix_01ARZ3NDEKTSV4RRFFQ69G5FAV'),
  sessionId: SessionId.parse('sess_01ARZ3NDEKTSV4RRFFQ69G5FAV'),
  recordedAtUtc: DateTime.utc(2026, 9, 9, 10),
  recordedAtOffsetMinutes: 120,
  latitude: lat,
  longitude: lon,
  accuracyMeters: 10.0,
  speedMps: 1.0,
  headingDegrees: 0.0,
);

InstalledManifest _manifestWithFra() => InstalledManifest(
  schemaVersion: 1,
  catalogVersion: 'v20260419',
  installed: <String, InstalledCountry>{
    'fra': InstalledCountry(
      alpha3: CountryCode.parse('fra'),
      installedAtUtc: DateTime.utc(2026, 4, 20),
      fileSize: 1024,
      pmtilesVersion: 'v20260419',
      sha256: 'a' * 64,
      filePath: _fraRelativePath,
    ),
  },
);

void main() {
  late Directory tmpDir;
  late Directory cacheDir;
  late FakeInstalledManifestRepository manifestPort;
  late PmtilesSource source;
  late MapThemeLoader themeLoader;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('flutter_map_map_view_test_');
    cacheDir = await Directory(p.join(tmpDir.path, 'cache')).create(recursive: true);
    final File world = File('assets/maps/world.pmtiles');
    // Same archive under two paths: the "country" copy proves a hot-swap
    // is driven by the resolved PATH, not by the archive contents.
    await File(p.join(tmpDir.path, kWorldPmtilesInternalPath)).create(recursive: true);
    await world.copy(p.join(tmpDir.path, kWorldPmtilesInternalPath));
    await File(p.join(tmpDir.path, _fraRelativePath)).create(recursive: true);
    await world.copy(p.join(tmpDir.path, _fraRelativePath));
    manifestPort = FakeInstalledManifestRepository();
    manifestPort.seedWith(InstalledManifest.empty());
    source = PmtilesSource(installedManifestPort: manifestPort, appSupportDir: tmpDir.path);
    themeLoader = MapThemeLoader(bundle: _FileAssetBundle());
  });

  tearDown(() async {
    await manifestPort.close();
    try {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    } on Object {
      // Best-effort cleanup; Windows occasionally holds file handles.
    }
  });

  /// True for the `CancellationException` vector_map_tiles raises on
  /// cancelled tile jobs (matched by name: `executor_lib`, its owner, is a
  /// transitive package MirkFall deliberately does not import directly).
  bool isTileCancellation(Object? error) => error.runtimeType.toString() == 'CancellationException';

  /// Swallows the cancelled raster tile jobs that vector_map_tiles reports
  /// through the image resource service (`FlutterError.reportError(...,
  /// silent: true)`) when tiles are pruned after a move or a layer
  /// unmounts. Production ignores those; `flutter_test` would fail the
  /// test on each. Everything else — including a cancellation escaping as
  /// an uncaught zone error, which the binding insists on recording
  /// itself — is forwarded to the binding's handler. Must be called at
  /// the top of the test BODY (the binding overwrites `onError` after
  /// `setUp`); mirrors the POC helper `swallow_vector_map_tiles_cancellation.dart`.
  void installTileCancellationFilterForBody() {
    final void Function(FlutterErrorDetails details)? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.silent && isTileCancellation(details.exception)) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  /// Fallback for a cancellation that still escaped as a single uncaught
  /// zone error (a render job running when the layer's executor was
  /// disposed). Anything else pending — or several exceptions, which the
  /// binding coalesces into a synthetic "Multiple exceptions" message —
  /// still fails the test.
  void drainTileCancellationNoise(WidgetTester tester) {
    final Object? pending = tester.takeException();
    if (pending == null) return;
    expect(isTileCancellation(pending), isTrue, reason: 'only a single tile-job cancellation is tolerated at teardown, got: $pending');
  }

  /// Shrinks the test viewport so the tile layer requests a handful of
  /// tiles instead of the 800×600 default's dozens — less render work in
  /// flight at unmount, fewer cancellations.
  void useSmallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Lets in-flight tile jobs finish (real time + frames) so that a
  /// following unmount / archive swap disposes an idle layer: a render
  /// job caught mid-flight by the executor disposal escapes as an
  /// uncaught `CancellationException` (vector_map_tiles 8.0.0 internals).
  Future<void> settleTiles(WidgetTester tester) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < _tileSettleTime) {
      await tester.pump(_pumpStep);
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  /// Pumps the widget inside `runAsync` (real file I/O: theme asset +
  /// PMTiles archive) until `onReady` fires. Returns the adapter and the
  /// number of `onReady` invocations observed.
  Future<({MapView view, int readyCount})> pumpUntilReady(WidgetTester tester, {CountryCode? initialCountry}) async {
    final Completer<MapView> ready = Completer<MapView>();
    int readyCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterMapMapViewWidget(
          pmtilesSource: source,
          onReady: (MapView view) {
            readyCount++;
            if (!ready.isCompleted) ready.complete(view);
          },
          initialCamera: _initialCamera,
          initialCountry: initialCountry,
          themeLoader: themeLoader,
          cacheFolderOverride: () async => cacheDir,
        ),
      ),
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    while (!ready.isCompleted && stopwatch.elapsed < _readyTimeout) {
      await tester.pump(_pumpStep);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ready.isCompleted, isTrue, reason: 'onReady never fired within $_readyTimeout');
    // Extra frames + real time: a hypothetical second onReady would show,
    // and the first tile batch finishes before the body mutates the layer.
    await settleTiles(tester);
    return (view: await ready.future, readyCount: readyCount);
  }

  /// Unmounts the map so archives + isolates are released before the
  /// test binding checks for leaks.
  Future<void> unmount(WidgetTester tester) async {
    await settleTiles(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(_pumpStep);
    // Let the tile executors drain their cancelled jobs before the test
    // body returns (late cancellations would be attributed to the test).
    await Future<void>.delayed(_teardownDrain);
    await tester.pump(_pumpStep);
  }

  Key? vectorTileLayerKey(WidgetTester tester) => tester.widget<VectorTileLayer>(find.byType(VectorTileLayer)).key;

  testWidgets('onReady fires exactly once with a MapView; queryViewport then returns the initial camera', (WidgetTester tester) async {
    useSmallViewport(tester);
    installTileCancellationFilterForBody();
    await tester.runAsync(() async {
      final ({MapView view, int readyCount}) result = await pumpUntilReady(tester);
      expect(result.readyCount, equals(1));
      expect(result.view, isA<MapView>());
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(VectorTileLayer), findsOneWidget);

      final _Viewport viewport = await result.view.queryViewport();
      expect(viewport.latitude, closeTo(_initialCamera.latitude, 1e-6));
      expect(viewport.longitude, closeTo(_initialCamera.longitude, 1e-6));
      expect(viewport.zoom, closeTo(_initialCamera.zoom, 1e-9));
      await unmount(tester);
    });
    drainTileCancellationNoise(tester);
  });

  testWidgets('moveCameraTo echoes on viewportUpdates with the requested zoom and queryViewport reflects the new position', (WidgetTester tester) async {
    useSmallViewport(tester);
    installTileCancellationFilterForBody();
    await tester.runAsync(() async {
      final MapView view = (await pumpUntilReady(tester)).view;
      final Future<_Viewport> echo = view.viewportUpdates.first;
      await view.moveCameraTo(latitude: 45.75, longitude: 4.85, zoom: 9.0);
      final _Viewport event = await echo.timeout(const Duration(seconds: 5));
      expect(event.zoom, closeTo(9.0, 1e-9));
      expect(event.latitude, closeTo(45.75, 1e-6));
      expect(event.longitude, closeTo(4.85, 1e-6));

      await tester.pump(_pumpStep);
      final _Viewport viewport = await view.queryViewport();
      expect(viewport.latitude, closeTo(45.75, 1e-6));
      expect(viewport.longitude, closeTo(4.85, 1e-6));
      expect(viewport.zoom, closeTo(9.0, 1e-9));
      await unmount(tester);
    });
    drainTileCancellationNoise(tester);
  });

  testWidgets('queryViewportBounds returns a MirkViewportBbox with south < north and west < east around the centre', (WidgetTester tester) async {
    useSmallViewport(tester);
    installTileCancellationFilterForBody();
    await tester.runAsync(() async {
      final MapView view = (await pumpUntilReady(tester)).view;
      final MirkViewportBbox bbox = await view.queryViewportBounds();
      expect(bbox.south, lessThan(bbox.north));
      expect(bbox.west, lessThan(bbox.east));
      expect(_initialCamera.latitude, inExclusiveRange(bbox.south, bbox.north));
      expect(_initialCamera.longitude, inExclusiveRange(bbox.west, bbox.east));
      await unmount(tester);
    });
    drainTileCancellationNoise(tester);
  });

  testWidgets('setUserLocation(fix) mounts a CircleLayer puck, setUserLocation(null) removes it', (WidgetTester tester) async {
    useSmallViewport(tester);
    installTileCancellationFilterForBody();
    await tester.runAsync(() async {
      final MapView view = (await pumpUntilReady(tester)).view;
      expect(find.byType(CircleLayer<Object>), findsNothing);

      await view.setUserLocation(_fix(lat: 48.8566, lon: 2.3522));
      await tester.pump(_pumpStep);
      expect(find.byType(CircleLayer<Object>), findsOneWidget);
      final CircleLayer<Object> puckLayer = tester.widget<CircleLayer<Object>>(find.byType(CircleLayer<Object>));
      expect(puckLayer.circles, hasLength(1));
      expect(puckLayer.circles.single.point.latitude, closeTo(48.8566, 1e-9));
      expect(puckLayer.circles.single.radius, equals(kMapUserPuckRadiusPx));

      await view.setUserLocation(null);
      await tester.pump(_pumpStep);
      expect(find.byType(CircleLayer<Object>), findsNothing);
      await unmount(tester);
    });
    drainTileCancellationNoise(tester);
  });

  testWidgets('setFollowMeEnabled flips isFollowMeEnabled (pure flag, no auto-pan)', (WidgetTester tester) async {
    useSmallViewport(tester);
    installTileCancellationFilterForBody();
    await tester.runAsync(() async {
      final MapView view = (await pumpUntilReady(tester)).view;
      expect(view.isFollowMeEnabled, isFalse);
      await view.setFollowMeEnabled(true);
      expect(view.isFollowMeEnabled, isTrue);
      await view.setFollowMeEnabled(false);
      expect(view.isFollowMeEnabled, isFalse);
      await unmount(tester);
    });
    drainTileCancellationNoise(tester);
  });

  testWidgets('dispose() twice does not throw, closes viewportUpdates, and later calls are silently ignored', (WidgetTester tester) async {
    useSmallViewport(tester);
    installTileCancellationFilterForBody();
    await tester.runAsync(() async {
      final MapView view = (await pumpUntilReady(tester)).view;
      final Completer<void> done = Completer<void>();
      view.viewportUpdates.listen((_) {}, onDone: done.complete);

      await view.dispose();
      await view.dispose();
      await done.future.timeout(const Duration(seconds: 5));

      await expectLater(view.moveCameraTo(latitude: 0, longitude: 0, zoom: 3), completes);
      await expectLater(view.showMap(null), completes);
      final _Viewport afterDispose = await view.queryViewport();
      expect(afterDispose.zoom, equals(0.0));
      await unmount(tester);
    });
    drainTileCancellationNoise(tester);
  });

  testWidgets('showMap(fra) on a manifest WITHOUT fra keeps the world provider (VectorTileLayer key unchanged)', (WidgetTester tester) async {
    useSmallViewport(tester);
    installTileCancellationFilterForBody();
    await tester.runAsync(() async {
      final MapView view = (await pumpUntilReady(tester)).view;
      final Key? before = vectorTileLayerKey(tester);
      expect(before, equals(const ValueKey<String>('world/mirkfall-standard')));

      await view.showMap(CountryCode.parse('fra'));
      await tester.pump(_pumpStep);
      expect(vectorTileLayerKey(tester), equals(before));
      await unmount(tester);
    });
    drainTileCancellationNoise(tester);
  });

  testWidgets('showMap(fra) on a manifest WITH fra mounts a new provider (VectorTileLayer key changes), showMap(null) swaps back', (WidgetTester tester) async {
    useSmallViewport(tester);
    installTileCancellationFilterForBody();
    await tester.runAsync(() async {
      manifestPort.seedWith(_manifestWithFra());
      final MapView view = (await pumpUntilReady(tester)).view;
      expect(vectorTileLayerKey(tester), equals(const ValueKey<String>('world/mirkfall-standard')));

      await view.showMap(CountryCode.parse('fra'));
      await tester.pump(_pumpStep);
      await tester.pump(_pumpStep);
      expect(vectorTileLayerKey(tester), equals(const ValueKey<String>('fra/mirkfall-standard')));

      await view.showMap(null);
      await tester.pump(_pumpStep);
      await tester.pump(_pumpStep);
      expect(vectorTileLayerKey(tester), equals(const ValueKey<String>('world/mirkfall-standard')));
      await unmount(tester);
    });
    drainTileCancellationNoise(tester);
  });

  testWidgets('initialCountry=fra with fra installed boots directly on the fra archive', (WidgetTester tester) async {
    useSmallViewport(tester);
    installTileCancellationFilterForBody();
    await tester.runAsync(() async {
      manifestPort.seedWith(_manifestWithFra());
      await pumpUntilReady(tester, initialCountry: CountryCode.parse('fra'));
      expect(vectorTileLayerKey(tester), equals(const ValueKey<String>('fra/mirkfall-standard')));
      await unmount(tester);
    });
    drainTileCancellationNoise(tester);
  });
}

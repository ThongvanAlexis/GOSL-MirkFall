// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-07 — composition of the same-canvas fog in `MapScreen`.
//
// Locks the structural facts the BUG-014 fix rests on (the `FogLayer` is a CHILD
// of the `FlutterMap`, mounted through `MirkInitialRevealFade(FogLayerConnector())`
// with no `RepaintBoundary` / `IgnorePointer` of MirkFall's around it) and ports
// the behaviours of the deleted overlay-era suites that still matter:
//   * the overlay-era pointer pass-through suite — gestures reach the map (a drag pans
//     the camera even though the fog is painted on top of the tiles);
//   * the overlay-era swap suite — an in-session renderer swap disposes the old
//     renderer and paints with the new one;
//   * the overlay-era repaint-boundary suite — Ticker frames never rebuild the Stack
//     siblings (now because the Ticker drives the painter's `repaint:` Listenable,
//     not `setState` — no boundary needed).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/application/controllers/active_session_controller.dart';
import 'package:mirkfall/application/providers/active_mirk_renderer_provider.dart';
import 'package:mirkfall/application/providers/discs_in_viewport_provider.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/application/providers/map_viewport_provider.dart';
import 'package:mirkfall/application/state/active_session_state.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/presentation/screens/map_screen.dart';
import 'package:mirkfall/presentation/widgets/fog_layer.dart';
import 'package:mirkfall/presentation/widgets/fog_layer_connector.dart';
import 'package:mirkfall/presentation/widgets/mirk_initial_reveal_fade.dart';

import '../../_helpers/fog_layer_test_harness.dart' show SpyMirkRenderer;
import '../../fakes/fake_installed_manifest_repository.dart';
import '../../fakes/fake_map_view.dart';
import '../../fakes/fake_mirk_renderer.dart';
import '../_harness.dart';

const Duration _frame = Duration(milliseconds: 16);

/// Longer than `kInitialRevealFadeInMs` — the fog is fully opaque afterwards.
const Duration _pastInitialFade = Duration(milliseconds: 600);
const String _engineSourcePath = 'lib/infrastructure/map/flutter_map_map_view.dart';
const String _mapScreenSourcePath = 'lib/presentation/screens/map_screen.dart';
const int _tickerFrameCount = 10;
const SessionId _sessionId = SessionId('sess_fog_composition');

/// Stand-in for the engine widget: a REAL `FlutterMap` (no tile layer) hosting
/// the `fogLayers` MapScreen passes, exactly where `FlutterMapMapViewWidget`
/// mounts them, with a controller the test can read.
class _FakeMapWidget extends StatefulWidget {
  const _FakeMapWidget({required this.onReady, required this.fakeMapView, required this.fogLayers, required this.mapController});
  final ValueChanged<MapView> onReady;
  final FakeMapView fakeMapView;
  final List<Widget> fogLayers;
  final MapController mapController;

  @override
  State<_FakeMapWidget> createState() => _FakeMapWidgetState();
}

class _FakeMapWidgetState extends State<_FakeMapWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady(widget.fakeMapView));
  }

  @override
  Widget build(BuildContext context) => FlutterMap(
    mapController: widget.mapController,
    options: const MapOptions(initialCenter: kHarnessMapCentre, initialZoom: kHarnessMapZoom),
    children: widget.fogLayers,
  );
}

class _FakeActiveSessionController extends ActiveSessionController {
  _FakeActiveSessionController(this._seed);
  final ActiveSessionState _seed;

  @override
  ActiveSessionState build() => _seed;
}

class _SeededMapViewport extends MapViewport {
  _SeededMapViewport(this._seed);
  final MirkViewportBbox? _seed;

  @override
  MirkViewportBbox? build() => _seed;
}

Fix _fix() => Fix(
  id: FixId.parse('fix_01ARZ3NDEKTSV4RRFFQ69G5FAV'),
  sessionId: _sessionId,
  recordedAtUtc: DateTime.utc(2026, 4, 21, 10, 30),
  recordedAtOffsetMinutes: 120,
  latitude: kHarnessMapCentre.latitude,
  longitude: kHarnessMapCentre.longitude,
  accuracyMeters: 10.0,
  speedMps: 1.0,
  headingDegrees: 0.0,
);

Tracking _tracking() =>
    Tracking(sessionId: _sessionId, startedAtUtc: DateTime.utc(2026, 4, 25), fixCount: 1, distanceFilterMeters: kDefaultDistanceFilterMeters, lastFix: _fix());

CountryCatalog _oneCountryCatalog() {
  final ChunkPart part = ChunkPart(sha256: 'a' * 64, size: 1000, url: 'https://example.test/releases/download/v1/deu.part01');
  return CountryCatalog(
    countries: <CountryEntry>[
      CountryEntry(
        alpha3: CountryCode.parse('deu'),
        name: 'Allemagne',
        parts: <ChunkPart>[part],
        reassembled: ReassembledMeta(sha256: 'b' * 64, size: 1000),
      ),
    ],
  );
}

FogLayer _mountedFogLayer(WidgetTester tester) => tester.widget<FogLayer>(find.byType(FogLayer));

/// Widgets between the `FogLayer` and its `MirkInitialRevealFade` ancestor (exclusive).
List<Widget> _wrappersBetweenFogLayerAndFade(WidgetTester tester) {
  final List<Widget> wrappers = <Widget>[];
  tester.element(find.byType(FogLayer)).visitAncestorElements((Element element) {
    if (element.widget is MirkInitialRevealFade) return false;
    wrappers.add(element.widget);
    return true;
  });
  return wrappers;
}

bool _wrapsFogWidget(Widget? child) => child is FogLayer || child is FogLayerConnector || child is MirkInitialRevealFade;

void main() {
  late Directory tmpDir;
  late FakeInstalledManifestRepository fakeRepo;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('map_screen_fog_composition_test_');
    fakeRepo = FakeInstalledManifestRepository();
    fakeRepo.seedWith(InstalledManifest.empty());
  });

  tearDown(() async {
    try {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    } on Object {
      // Best-effort cleanup; Windows occasionally holds file handles.
    }
  });

  /// `MapScreen` under the fake engine widget; the renderer provider is the
  /// only fog input overridden (session Tracking so the fade reaches 1.0).
  Widget mapScreen({required MapController mapController, required FakeMapView fakeMapView, required FutureOr<MirkRenderer> Function() renderer}) {
    return ProviderScope(
      overrides: [
        appSupportDirProvider.overrideWith((ref) async => tmpDir.path),
        installedManifestRepositoryProvider.overrideWith((ref) async => fakeRepo),
        countryCatalogProvider.overrideWith((ref) async => _oneCountryCatalog()),
        activeSessionControllerProvider.overrideWith(() => _FakeActiveSessionController(_tracking())),
        activeMirkRendererProvider.overrideWith((ref) => renderer()),
      ],
      child: MaterialApp(
        home: MapScreen(
          mapViewBuilderForTest: ({required ValueChanged<MapView> onReady, required List<Widget> fogLayers}) {
            return _FakeMapWidget(onReady: onReady, fakeMapView: fakeMapView, fogLayers: fogLayers, mapController: mapController);
          },
        ),
      ),
    );
  }

  Future<void> pumpPastFade(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(_frame);
    await tester.pump(_pastInitialFade);
  }

  group('09.1-07 — MapScreen same-canvas fog composition (SC#2)', () {
    testWidgets('mounts MirkInitialRevealFade(FogLayerConnector) → FogLayer INSIDE the FlutterMap, with no RepaintBoundary / IgnorePointer around it', (
      WidgetTester tester,
    ) async {
      final MapController mapController = MapController();
      addTearDown(mapController.dispose);
      await tester.pumpWidget(mapScreen(mapController: mapController, fakeMapView: FakeMapView(), renderer: () async => FakeMirkRenderer()));
      await pumpPastFade(tester);

      expect(find.descendant(of: find.byType(FlutterMap), matching: find.byType(MirkInitialRevealFade)), findsOneWidget);
      expect(find.descendant(of: find.byType(FlutterMap), matching: find.byType(FogLayerConnector)), findsOneWidget);
      expect(find.descendant(of: find.byType(FlutterMap), matching: find.byType(FogLayer)), findsOneWidget);
      expect(
        find.descendant(of: find.byType(MirkInitialRevealFade), matching: find.byType(FogLayer)),
        findsOneWidget,
        reason: 'the fade wraps the layer',
      );

      final List<Widget> wrappers = _wrappersBetweenFogLayerAndFade(tester);
      expect(wrappers.whereType<RepaintBoundary>(), isEmpty, reason: 'a RepaintBoundary would put the fog one frame behind the tiles (BUG-014)');
      expect(wrappers.whereType<IgnorePointer>(), isEmpty, reason: 'nothing needs to shield the map from the fog any more');
      expect(find.byWidgetPredicate((Widget w) => w is RepaintBoundary && _wrapsFogWidget(w.child)), findsNothing);
      expect(find.byWidgetPredicate((Widget w) => w is IgnorePointer && _wrapsFogWidget(w.child)), findsNothing);
    });

    test('FlutterMapMapViewWidget mounts fogLayers between VectorTileLayer and the puck CircleLayer (source order)', () {
      final String engine = File(_engineSourcePath).readAsStringSync();
      final int childrenIndex = engine.indexOf('children: <Widget>[');
      final int tilesIndex = engine.indexOf('VectorTileLayer(', childrenIndex);
      final int fogIndex = engine.indexOf('...widget.fogLayers', childrenIndex);
      final int puckIndex = engine.indexOf('CircleLayer<Object>(', childrenIndex);
      expect(childrenIndex, isNonNegative);
      expect(tilesIndex, isNonNegative);
      expect(fogIndex, isNonNegative);
      expect(puckIndex, isNonNegative);
      expect(tilesIndex, lessThan(fogIndex), reason: 'fog above the tiles');
      expect(fogIndex, lessThan(puckIndex), reason: 'puck above the fog');
    });

    test('map_screen.dart passes MirkInitialRevealFade(FogLayerConnector()) as fogLayers and carries no overlay scaffolding', () {
      final String source = File(_mapScreenSourcePath).readAsStringSync();
      expect(source, contains('fogLayers: fogLayers'));
      expect(source, contains('MirkInitialRevealFade(child: FogLayerConnector())'));
      expect(source, isNot(contains('RepaintBoundary')));
      expect(source, isNot(contains('IgnorePointer')));
      expect(source, contains("import '../widgets/fog_layer_connector.dart';"));
    });

    testWidgets('a drag on the map pans the camera — the fog child does not capture pointers (pass-through port)', (WidgetTester tester) async {
      final MapController mapController = MapController();
      addTearDown(mapController.dispose);
      await tester.pumpWidget(mapScreen(mapController: mapController, fakeMapView: FakeMapView(), renderer: () async => FakeMirkRenderer()));
      await pumpPastFade(tester);
      expect(_mountedFogLayer(tester).renderer, isA<FakeMirkRenderer>());

      final LatLng before = mapController.camera.center;
      // Drag from the map centre — well away from the corner controls.
      await tester.drag(find.byType(FlutterMap), const Offset(-120.0, 0.0));
      await tester.pump();
      await tester.pump(_frame);
      final LatLng after = mapController.camera.center;

      expect(after.longitude, greaterThan(before.longitude), reason: 'dragging the map to the left moves the camera east — the gesture reached the map');
      expect(after.latitude, closeTo(before.latitude, 1e-6));
    });

    testWidgets('invalidating activeMirkRendererProvider mid-session swaps the FogLayer renderer (old one disposed, new one paints)', (
      WidgetTester tester,
    ) async {
      final FakeMirkRenderer firstRenderer = FakeMirkRenderer();
      final SpyMirkRenderer secondRenderer = SpyMirkRenderer();
      bool swapped = false;
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appSupportDirProvider.overrideWith((ref) async => tmpDir.path),
          installedManifestRepositoryProvider.overrideWith((ref) async => fakeRepo),
          countryCatalogProvider.overrideWith((ref) async => _oneCountryCatalog()),
          activeSessionControllerProvider.overrideWith(() => _FakeActiveSessionController(_tracking())),
          // Mirrors the production `ref.onDispose(renderer.dispose)` wiring.
          activeMirkRendererProvider.overrideWith((ref) async {
            final MirkRenderer renderer = swapped ? secondRenderer : firstRenderer;
            ref.onDispose(renderer.dispose);
            return renderer;
          }),
        ],
      );
      addTearDown(container.dispose);
      final MapController mapController = MapController();
      addTearDown(mapController.dispose);
      final FakeMapView fakeMapView = FakeMapView();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MapScreen(
              mapViewBuilderForTest: ({required ValueChanged<MapView> onReady, required List<Widget> fogLayers}) {
                return _FakeMapWidget(onReady: onReady, fakeMapView: fakeMapView, fogLayers: fogLayers, mapController: mapController);
              },
            ),
          ),
        ),
      );
      await pumpPastFade(tester);
      expect(_mountedFogLayer(tester).renderer, same(firstRenderer));
      expect(firstRenderer.paintCallCount, greaterThan(0));
      expect(firstRenderer.disposeCallCount, 0);
      expect(secondRenderer.paintSizes, isEmpty);

      swapped = true;
      container.invalidate(activeMirkRendererProvider);
      await tester.pump();
      await tester.pump(_frame);
      await tester.pump(_frame);

      expect(_mountedFogLayer(tester).renderer, same(secondRenderer), reason: 'the FogLayer renderer changed type: FakeMirkRenderer → SpyMirkRenderer');
      expect(firstRenderer.disposeCallCount, 1, reason: 'the previous renderer is disposed by its provider, never by the layer');
      expect(secondRenderer.paintSizes, isNotEmpty, reason: 'the new renderer paints');
    });

    testWidgets('Ticker frames do NOT rebuild sibling widgets (attribution, FAB, banner, chip) — no RepaintBoundary needed', (WidgetTester tester) async {
      int attributionBuildCount = 0;
      int fabBuildCount = 0;
      int bannerBuildCount = 0;
      int chipBuildCount = 0;
      final FakeMirkRenderer renderer = FakeMirkRenderer();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSessionControllerProvider.overrideWith(() => _FakeActiveSessionController(_tracking())),
            activeMirkRendererProvider.overrideWith((ref) async => renderer),
            discsInViewportProvider.overrideWith((ref, MirkViewportBbox viewport) async => const <RevealDisc>[]),
            mapViewportProvider.overrideWith(() => _SeededMapViewport(MirkViewportBbox(south: 48.84, west: 2.34, north: 48.86, east: 2.36))),
          ],
          child: TestMapScreenHarness(
            attributionBuilder: (BuildContext context) {
              attributionBuildCount++;
              return const SizedBox(width: 24, height: 24);
            },
            fabBuilder: (BuildContext context) {
              fabBuildCount++;
              return const SizedBox(width: 56, height: 56);
            },
            bannerBuilder: (BuildContext context) {
              bannerBuildCount++;
              return const SizedBox(width: 200, height: 40);
            },
            chipBuilder: (BuildContext context) {
              chipBuildCount++;
              return const SizedBox(width: 80, height: 24);
            },
          ),
        ),
      );
      await pumpPastFade(tester);
      expect(find.byType(FogLayer), findsOneWidget);
      final int paintsAtMount = renderer.paintCallCount;
      final int attributionAtMount = attributionBuildCount;
      final int fabAtMount = fabBuildCount;
      final int bannerAtMount = bannerBuildCount;
      final int chipAtMount = chipBuildCount;

      for (int i = 0; i < _tickerFrameCount; i++) {
        await tester.pump(_frame);
      }

      expect(renderer.paintCallCount, greaterThan(paintsAtMount), reason: 'the Ticker repaints the fog every frame');
      expect(attributionBuildCount, attributionAtMount, reason: 'attribution rebuilt during Ticker frames');
      expect(fabBuildCount, fabAtMount, reason: 'FAB rebuilt during Ticker frames');
      expect(bannerBuildCount, bannerAtMount, reason: 'banner rebuilt during Ticker frames');
      expect(chipBuildCount, chipAtMount, reason: 'chip rebuilt during Ticker frames');
    });
  });
}

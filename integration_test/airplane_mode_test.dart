// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Airplane-mode network-zero verification (MAP-01 unit-test subset of
// QUAL-05).
//
// Both scenarios wrap the pump body in an [HttpOverrides.runZoned] scope
// whose [createHttpClient] returns a [_FailAllHttpClient] — every method
// invocation on that client increments `invocationCount` then throws — and
// count the client constructions as well.
//
// 1. FAKE engine (Phase 07 shape, kept): MapScreen under a FakeMapView
//    stand-in that mounts the `fogLayers` in a tile-less `FlutterMap`,
//    pan + zoom + country-switch paths through the port, zero HTTP.
// 2. REAL engine (Phase 09.1 plan 09.1-07): MapScreen on the production
//    `FlutterMapMapViewWidget` over `assets/maps/world.pmtiles` copied where
//    `PmtilesSource` resolves the world bundle, the style compiled from the
//    repository asset, the `FogLayer` mounted as a child of the `FlutterMap`
//    (same canvas as the tiles): first render, three camera moves, a
//    country switch, unmount — not a single `HttpClient` constructed
//    (`PmTilesArchive.from(path)` → `FileAt`, RESEARCH §8).
//
// The device-level QUAL-05 (real airplane mode toggle on a real device) is
// covered by the smoke walks (Pixel 4a + iOS sideload). The present suite
// is a regression guard for the code-level contract: no HTTP request can
// sneak in from any map / fog code path under normal operation.
//
// Moved from `test/phase_07_integration/airplane_mode_test.dart` to
// `integration_test/` in Plan 08-04 (adversarial wave). Tagged
// `integration` so the CI unit fast-path can skip it via `--exclude-tags
// integration` while on-demand `flutter test integration_test/`
// discovers it normally.
//
// Mutation experiment (author-time, Plan 08-04 Task 1):
//   1. Commented out the `fakeMapView.showMap(...)` country-switch calls
//      inside the pump body.
//   2. Ran `flutter test integration_test/airplane_mode_test.dart` →
//      FAILED loudly with the inertness-guard reason "FakeMapView.showMap
//      never invoked — test would be inert…".
//   3. Restored the calls → green again.

@Tags(<String>['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/application/controllers/country_resolver_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/infrastructure/map/flutter_map_map_view.dart';
import 'package:mirkfall/infrastructure/map/map_theme_loader.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:mirkfall/presentation/screens/map_screen.dart';
import 'package:mirkfall/presentation/widgets/fog_layer.dart';
import 'package:path/path.dart' as p;
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../test/_helpers/tile_cancellation_noise.dart';
import '../test/fakes/fake_installed_manifest_repository.dart';
import '../test/fakes/fake_map_view.dart';

/// Melun at a country-level zoom — a handful of world tiles on the small viewport.
const CameraLatLngZoom _realEngineCamera = CameraLatLngZoom(latitude: 48.5397, longitude: 2.6553, zoom: 5.0);
const Duration _readyTimeout = Duration(seconds: 20);
const Duration _readyPollRealDelay = Duration(milliseconds: 10);
const Duration _teardownDrain = Duration(milliseconds: 150);
const String _worldAssetPath = 'assets/maps/world.pmtiles';

/// HTTP client that refuses every call. Any use — even property
/// reads — is logged on [invocationCount] and throws a SocketException
/// to signal the airplane-mode gate.
class _FailAllHttpClient implements HttpClient {
  _FailAllHttpClient();

  int invocationCount = 0;

  Never _fail(String method) {
    invocationCount++;
    throw const SocketException('airplane mode — network blocked');
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _fail('getUrl');
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _fail('postUrl');
  @override
  Future<HttpClientRequest> putUrl(Uri url) async => _fail('putUrl');
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async => _fail('deleteUrl');
  @override
  Future<HttpClientRequest> patchUrl(Uri url) async => _fail('patchUrl');
  @override
  Future<HttpClientRequest> headUrl(Uri url) async => _fail('headUrl');
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _fail('openUrl($method)');
  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) async => _fail('open($method)');
  @override
  Future<HttpClientRequest> get(String host, int port, String path) async => _fail('get');
  @override
  Future<HttpClientRequest> post(String host, int port, String path) async => _fail('post');
  @override
  Future<HttpClientRequest> put(String host, int port, String path) async => _fail('put');
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) async => _fail('delete');
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) async => _fail('patch');
  @override
  Future<HttpClientRequest> head(String host, int port, String path) async => _fail('head');

  @override
  void close({bool force = false}) {}

  @override
  bool get autoUncompress => true;
  @override
  set autoUncompress(bool _) {}
  @override
  Duration? get connectionTimeout => null;
  @override
  set connectionTimeout(Duration? _) {}
  @override
  Duration get idleTimeout => Duration.zero;
  @override
  set idleTimeout(Duration _) {}
  @override
  int? get maxConnectionsPerHost => null;
  @override
  set maxConnectionsPerHost(int? _) {}
  @override
  String? get userAgent => null;
  @override
  set userAgent(String? _) {}

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? _) {}
  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? _) {}
  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? _) {}
  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? _) {}
  @override
  set findProxy(String Function(Uri url)? _) {}
  @override
  set keyLog(void Function(String line)? _) {}

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}
  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}
}

/// Serves the repository's real `assets/maps/style.json` from disk.
class _FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(await File(key).readAsBytes());
}

/// Override for the CountryResolverController that keeps the build
/// result deterministic so the airplane-mode walk can drive
/// activeCountry / viewportCountry state without the 500 ms debounce
/// timer + viewport polygon load path.
class _FakeResolverController extends CountryResolverController {
  _FakeResolverController({required this.seed});
  final CountryResolverState seed;

  @override
  CountryResolverState build() => seed;
}

/// Stand-in for the engine widget (fake scenario): a tile-less `FlutterMap`
/// hosting the `fogLayers` MapScreen passes, publishing [FakeMapView] via
/// [onReady] after the first post-frame callback. Same pattern as
/// map_screen_test.dart.
class _FakeMapWidget extends StatefulWidget {
  const _FakeMapWidget({required this.onReady, required this.fakeMapView, required this.fogLayers});
  final ValueChanged<MapView> onReady;
  final FakeMapView fakeMapView;
  final List<Widget> fogLayers;

  @override
  State<_FakeMapWidget> createState() => _FakeMapWidgetState();
}

class _FakeMapWidgetState extends State<_FakeMapWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady(widget.fakeMapView);
    });
  }

  @override
  Widget build(BuildContext context) => FlutterMap(
    options: const MapOptions(initialCenter: LatLng(0, 0), initialZoom: kMapWorldOverviewZoom),
    children: widget.fogLayers,
  );
}

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

void main() {
  late Directory tmpDir;
  late FakeInstalledManifestRepository fakeRepo;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('airplane_mode_test_');
    fakeRepo = FakeInstalledManifestRepository();
    fakeRepo.seedWith(InstalledManifest.empty());
  });

  tearDown(() async {
    await fakeRepo.close();
    try {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    } on Object {
      // best-effort; Windows may hold handles
    }
  });

  Widget wrapScreen({required MapViewWidgetBuilder builder, CountryResolverState? resolverSeed}) {
    return ProviderScope(
      overrides: [
        appSupportDirProvider.overrideWith((ref) async => tmpDir.path),
        installedManifestRepositoryProvider.overrideWith((ref) async => fakeRepo),
        countryCatalogProvider.overrideWith((ref) async => _oneCountryCatalog()),
        if (resolverSeed != null) countryResolverControllerProvider.overrideWith(() => _FakeResolverController(seed: resolverSeed)),
      ],
      child: MaterialApp(home: MapScreen(mapViewBuilderForTest: builder)),
    );
  }

  testWidgets('airplane mode: MapScreen pump + pan + country-switch makes zero HTTP requests', (tester) async {
    final _FailAllHttpClient failClient = _FailAllHttpClient();

    // Run the pump body under HttpOverrides.runZoned so every new
    // HttpClient construction inside the widget lifecycle funnels
    // through failClient.
    await HttpOverrides.runZoned<Future<void>>(() async {
      final fakeMapView = FakeMapView();
      final CountryResolverState seed = CountryResolverState(viewportCountry: CountryCode.parse('deu'));

      await tester.pumpWidget(
        wrapScreen(
          resolverSeed: seed,
          builder: ({required ValueChanged<MapView> onReady, required List<Widget> fogLayers}) {
            return _FakeMapWidget(onReady: onReady, fakeMapView: fakeMapView, fogLayers: fogLayers);
          },
        ),
      );
      // Phase 09.1 — the FogLayer's Ticker runs forever, so a bare
      // pumpAndSettle never settles. Fixed-cadence pumps suffice
      // here: the route bootstrap + post-frame callbacks land in a
      // handful of frames and we don't need the test to wait for
      // animations.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Pan + zoom: push viewport updates.
      for (int i = 0; i < 10; i++) {
        fakeMapView.pushViewport(latitude: 48.0 + i * 0.1, longitude: 2.0 + i * 0.1, zoom: 8.0 + (i % 3).toDouble());
        await tester.pump(const Duration(milliseconds: 1));
      }

      // Country-switch path on the adapter surface.
      await fakeMapView.showMap(CountryCode.parse('deu'));
      await fakeMapView.showMap(CountryCode.parse('fra'));
      await fakeMapView.showMap(null);
      await tester.pump(const Duration(milliseconds: 10));
      // Inertness guard (Plan 08-04): prove the showMap code path was
      // actually exercised before we assert zero HTTP invocations.
      // Without this guard, any refactor that silently neutralises
      // `mapViewBuilderForTest` (e.g. returning a stub that never calls
      // into MapView) would still pass — the zero-HTTP assertion would
      // be inert.
      expect(
        fakeMapView.showMapInvocations.isNotEmpty,
        isTrue,
        reason: 'FakeMapView.showMap never invoked — test would be inert (pump did not reach MapScreen render path).',
      );
    }, createHttpClient: (SecurityContext? ctx) => failClient);

    expect(failClient.invocationCount, 0, reason: 'Expected no HTTP request from the Phase 07 code path under airplane conditions');
  });

  testWidgets('airplane mode (real engine): MapScreen on FlutterMapMapViewWidget + world.pmtiles from disk + FogLayer child constructs no HttpClient', (
    tester,
  ) async {
    final _FailAllHttpClient failClient = _FailAllHttpClient();
    int clientConstructionCount = 0;
    useSmallViewport(tester);
    installTileCancellationFilterForBody();

    // world.pmtiles where PmtilesSource resolves the world bundle (<app_support>/maps/world.pmtiles).
    final String worldPath = p.join(tmpDir.path, kWorldPmtilesInternalPath);
    await File(worldPath).create(recursive: true);
    await File(_worldAssetPath).copy(worldPath);
    final Directory cacheDir = await Directory(p.join(tmpDir.path, 'cache')).create(recursive: true);
    final PmtilesSource source = PmtilesSource(installedManifestPort: fakeRepo, appSupportDir: tmpDir.path);
    final MapThemeLoader themeLoader = MapThemeLoader(bundle: _FileAssetBundle());
    final Completer<MapView> ready = Completer<MapView>();

    await HttpOverrides.runZoned<Future<void>>(
      () async {
        // Real I/O (theme asset, PMTiles archive, tile decode) needs the real event loop.
        await tester.runAsync(() async {
          await tester.pumpWidget(
            wrapScreen(
              builder: ({required ValueChanged<MapView> onReady, required List<Widget> fogLayers}) {
                return FlutterMapMapViewWidget(
                  pmtilesSource: source,
                  onReady: (MapView view) {
                    if (!ready.isCompleted) ready.complete(view);
                    onReady(view);
                  },
                  initialCamera: _realEngineCamera,
                  themeLoader: themeLoader,
                  cacheFolderOverride: () async => cacheDir,
                  fogLayers: fogLayers,
                );
              },
            ),
          );
          final Stopwatch stopwatch = Stopwatch()..start();
          while (!ready.isCompleted && stopwatch.elapsed < _readyTimeout) {
            await tester.pump(kTilePumpStep);
            await Future<void>.delayed(_readyPollRealDelay);
          }
          expect(ready.isCompleted, isTrue, reason: 'onReady never fired within $_readyTimeout');
          await settleTiles(tester);

          // Inertness guards: the real tile layer rendered AND the fog is one of its siblings on the map canvas.
          expect(find.byType(VectorTileLayer), findsOneWidget, reason: 'the real engine is mounted');
          expect(
            find.descendant(of: find.byType(FlutterMap), matching: find.byType(FogLayer)),
            findsOneWidget,
            reason: 'the fog is a child of the FlutterMap',
          );

          final MapView view = await ready.future;
          await view.moveCameraTo(latitude: 48.6, longitude: 2.7, zoom: 6.0);
          await settleTiles(tester);
          await view.moveCameraTo(latitude: 48.7, longitude: 2.8, zoom: 7.0);
          await settleTiles(tester);
          await view.moveCameraTo(latitude: 48.8, longitude: 2.9, zoom: 8.0);
          await settleTiles(tester);
          await view.showMap(null);
          await settleTiles(tester);

          // Unmount INSIDE the zone so the teardown reads (archive close) stay HTTP-guarded.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(kTilePumpStep);
          await Future<void>.delayed(_teardownDrain);
          await tester.pump(kTilePumpStep);
        });
      },
      createHttpClient: (SecurityContext? ctx) {
        clientConstructionCount++;
        return failClient;
      },
    );
    drainTileCancellationNoise(tester);

    expect(clientConstructionCount, 0, reason: 'no HttpClient constructed at all: PMTiles from disk (FileAt), style from the bundle, fog on the canvas');
    expect(failClient.invocationCount, 0, reason: 'Expected no HTTP request from the real flutter_map engine under airplane conditions');
  });
}

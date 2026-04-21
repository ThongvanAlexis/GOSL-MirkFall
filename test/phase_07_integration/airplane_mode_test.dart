// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Airplane-mode network-zero verification (MAP-01 unit-test subset of
// QUAL-05).
//
// Wraps the pump body in an [HttpOverrides.runZoned] scope whose
// [createHttpClient] returns a [_FailAllHttpClient] — every
// method invocation on that client increments `invocationCount` then
// throws. The test pumps MapScreen under a FakeMapView override,
// exercises pan + zoom + country-switch paths, and asserts the counter
// is zero at the end.
//
// The device-level QUAL-05 (real airplane mode toggle on a real
// device) is covered by Plan 07-07 Task 2 (human-verify checkpoint on
// Pixel 4a + iOS sideload). The present test is a regression guard
// for the code-level contract: no HTTP request can sneak in from any
// Phase 07 code path under normal operation.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/country_resolver_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:mirkfall/infrastructure/map/style_rewriter.dart';
import 'package:mirkfall/presentation/screens/map_screen.dart';

import '../fakes/fake_installed_manifest_repository.dart';
import '../fakes/fake_map_view.dart';

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

/// Stub fake-map widget that publishes [FakeMapView] via [onReady]
/// after the first post-frame callback. Identical pattern to
/// map_screen_test.dart.
class _FakeMapWidget extends StatefulWidget {
  const _FakeMapWidget({required this.onReady, required this.fakeMapView});
  final ValueChanged<MapView> onReady;
  final FakeMapView fakeMapView;

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
  Widget build(BuildContext context) => const ColoredBox(color: Color(0xFFEFEFEF));
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
    try {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    } on Object {
      // best-effort; Windows may hold handles
    }
  });

  Widget wrapScreen({required FakeMapView fakeMapView, CountryResolverState? resolverSeed}) {
    return ProviderScope(
      overrides: [
        appSupportDirProvider.overrideWith((ref) async => tmpDir.path),
        installedManifestRepositoryProvider.overrideWith((ref) async => fakeRepo),
        countryCatalogProvider.overrideWith((ref) async => _oneCountryCatalog()),
        if (resolverSeed != null) countryResolverControllerProvider.overrideWith(() => _FakeResolverController(seed: resolverSeed)),
      ],
      child: MaterialApp(
        home: MapScreen(
          mapViewBuilderForTest: ({required StyleRewriter styleRewriter, required PmtilesSource pmtilesSource, required ValueChanged<MapView> onReady}) {
            return _FakeMapWidget(onReady: onReady, fakeMapView: fakeMapView);
          },
        ),
      ),
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

      await tester.pumpWidget(wrapScreen(fakeMapView: fakeMapView, resolverSeed: seed));
      await tester.pumpAndSettle();

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
    }, createHttpClient: (SecurityContext? ctx) => failClient);

    expect(failClient.invocationCount, 0, reason: 'Expected no HTTP request from the Phase 07 code path under airplane conditions');
  });
}

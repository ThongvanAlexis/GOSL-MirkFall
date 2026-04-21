// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/country_resolver_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/map/country_resolver.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../fakes/fake_map_view.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this._root);
  final Directory _root;
  @override
  Future<String?> getApplicationSupportPath() async => _root.path;
  @override
  Future<String?> getApplicationDocumentsPath() async => _root.path;
  @override
  Future<String?> getTemporaryPath() async => _root.path;
}

/// Fabricates a minimal rectangular polygon for alpha3 [code] covering
/// [bounds]. Returned in the GeoJSON FeatureCollection shape expected by
/// [CountryPolygonLoader]'s asset-loader seam.
String _buildRectPolygon({required String code, required double minLat, required double maxLat, required double minLon, required double maxLon}) {
  final List<List<double>> coords = <List<double>>[
    <double>[minLon, minLat],
    <double>[maxLon, minLat],
    <double>[maxLon, maxLat],
    <double>[minLon, maxLat],
    <double>[minLon, minLat],
  ];
  return jsonEncode(<String, Object?>{
    'type': 'FeatureCollection',
    'features': <Object?>[
      <String, Object?>{
        'type': 'Feature',
        'properties': <String, Object?>{'alpha3': code},
        'geometry': <String, Object?>{
          'type': 'Polygon',
          'coordinates': <Object?>[coords],
        },
      },
    ],
  });
}

InstalledCountry _mkInstalled(String alpha3) => InstalledCountry(
  alpha3: CountryCode.parse(alpha3),
  installedAtUtc: DateTime.utc(2026, 4, 21),
  fileSize: 1024,
  pmtilesVersion: 'v20260419',
  sha256: 'a' * 64,
  filePath: '$kCountriesDir/$alpha3.pmtiles',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_country_resolver_controller_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Swallow — Windows temp cleanup, same as Phase 01 convention.
      }
    }
  });

  /// Installs FRA + ESP polygons covering Paris / Madrid respectively in
  /// a synthetic map, and seeds the installed manifest so the resolver
  /// treats both as "installed".
  Future<ProviderContainer> buildContainer({required Set<String> installed}) async {
    final Map<String, String> polygons = <String, String>{
      'fra': _buildRectPolygon(code: 'fra', minLat: 42.0, maxLat: 51.0, minLon: -5.0, maxLon: 8.5),
      'esp': _buildRectPolygon(code: 'esp', minLat: 36.0, maxLat: 43.5, minLon: -9.5, maxLon: 3.3),
      'deu': _buildRectPolygon(code: 'deu', minLat: 47.3, maxLat: 55.0, minLon: 5.9, maxLon: 15.0),
    };

    // Synthesise a minimal CountryCatalog covering FRA + ESP + DEU so
    // the controller's resolver rebuild loads polygons for ALL three
    // (installed or not).
    final CountryCatalog syntheticCatalog = CountryCatalog(
      countries: [
        for (final String code in <String>['fra', 'esp', 'deu'])
          CountryEntry(
            alpha3: CountryCode.parse(code),
            name: code.toUpperCase(),
            parts: [ChunkPart(sha256: 'a' * 64, size: 1024, url: 'https://github.com/example/mirkfall/releases/download/v20260419/$code.part01')],
            reassembled: ReassembledMeta(sha256: 'b' * 64, size: 1024),
          ),
      ],
    );

    final container = ProviderContainer(overrides: [countryCatalogProvider.overrideWith((ref) async => syntheticCatalog)]);
    addTearDown(container.dispose);

    // Pre-resolve the catalog so the controller's resolver rebuild
    // reads a ready AsyncValue (not AsyncLoading).
    await container.read(countryCatalogProvider.future);

    // Seed the installed manifest via the repo BEFORE anything subscribes
    // to installedManifestProvider. The StreamProvider's first yield is a
    // `repo.read()` so the initial snapshot already reflects our seed.
    final repo = await container.read(installedManifestRepositoryProvider.future);
    InstalledManifest manifest = InstalledManifest.empty();
    for (final String code in installed) {
      manifest = manifest.copyWithInsert(_mkInstalled(code));
    }
    await repo.write(manifest);

    // Inject a polygon loader that uses our in-memory polygons.
    final loader = CountryPolygonLoaderTestSeam.withAssetLoader((String assetPath) async {
      // assetPath is `assets/maps/polygons/<alpha3>.geo.json`.
      final String basename = assetPath.split('/').last;
      final String code = basename.replaceAll('.geo.json', '');
      final String? json = polygons[code];
      if (json == null) throw StateError('no polygon for $code');
      return json;
    });

    // Trigger controller build, then wire the loader seam + force a
    // synchronous resolver rebuild from the seeded manifest + catalog.
    container.read(countryResolverControllerProvider);
    container.read(countryResolverControllerProvider.notifier).setPolygonLoaderForTest(loader);
    await container.read(countryResolverControllerProvider.notifier).rebuildNowForTest();

    return container;
  }

  group('CountryResolverController — initial state', () {
    test('build() returns empty CountryResolverState', () async {
      final container = await buildContainer(installed: <String>{});
      final state = container.read(countryResolverControllerProvider);
      expect(state.activeCountry, isNull);
      expect(state.viewportCountry, isNull);
      expect(state.viewportInInstalled, isFalse);
    });
  });

  group('CountryResolverController — viewport → country swap', () {
    test('viewport in FRA (installed) sets activeCountry=FRA + calls showMap(FRA)', () async {
      final container = await buildContainer(installed: <String>{'fra'});
      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      // Force listener attach on the next public-entry call.
      container.read(countryResolverControllerProvider.notifier);

      fakeMapView.pushViewport(latitude: 48.8566, longitude: 2.3522, zoom: 10.0);
      // Wait past the 500 ms debounce.
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final state = container.read(countryResolverControllerProvider);
      expect(state.activeCountry?.value, equals('fra'));
      expect(state.viewportCountry?.value, equals('fra'));
      expect(state.viewportInInstalled, isTrue);
      expect(fakeMapView.showMapInvocations, hasLength(1));
      expect(fakeMapView.showMapInvocations.single?.value, equals('fra'));
    });

    test('viewport in DEU (not installed) sets viewportCountry=DEU + inInstalled=false + NO showMap call', () async {
      final container = await buildContainer(installed: <String>{'fra'});
      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(countryResolverControllerProvider.notifier);

      // Munich (Germany): (48.1351, 11.5820).
      fakeMapView.pushViewport(latitude: 48.1351, longitude: 11.5820, zoom: 10.0);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final state = container.read(countryResolverControllerProvider);
      expect(state.viewportCountry?.value, equals('deu'));
      expect(state.viewportInInstalled, isFalse);
      // No showMap call since DEU is not installed.
      expect(fakeMapView.showMapInvocations, isEmpty);
    });

    test('viewport at zoom < kWorldFallbackZoomCutoff sets activeCountry=null + calls showMap(null) (world bundle)', () async {
      final container = await buildContainer(installed: <String>{'fra'});
      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(countryResolverControllerProvider.notifier);

      // First land in FRA (installed) so activeCountry becomes non-null.
      fakeMapView.pushViewport(latitude: 48.8566, longitude: 2.3522, zoom: 10.0);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(container.read(countryResolverControllerProvider).activeCountry?.value, equals('fra'));

      // Zoom out below the cutoff (threshold raised to 8 on 2026-04-21
      // device-smoke fix — zoom 2 is well below either old or new value).
      fakeMapView.pushViewport(latitude: 48.8566, longitude: 2.3522, zoom: 2.0);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final state = container.read(countryResolverControllerProvider);
      expect(state.activeCountry, isNull);
      expect(state.viewportCountry, isNull);
      // showMap(null) was issued for the zoom-out.
      expect(fakeMapView.showMapInvocations.last, isNull);
    });

    test('viewport at zoom 7 (between old cutoff 3 and new cutoff 8) uses world bundle', () async {
      // Regression guard for the device-smoke fix: at zoom 3-7, per-country
      // PMTiles files have no data for neighbouring countries and render
      // as blank white areas. The world bundle (upscaled past its native
      // z0-2) stays rectangle-to-rectangle continuous, even if blurry.
      final container = await buildContainer(installed: <String>{'fra'});
      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(countryResolverControllerProvider.notifier);

      // Land deep in FRA first.
      fakeMapView.pushViewport(latitude: 48.8566, longitude: 2.3522, zoom: 13.0);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(container.read(countryResolverControllerProvider).activeCountry?.value, equals('fra'));

      // Zoom out to 7 — still inside the old cutoff (3) but below the new
      // one (8), so should fall back to world.
      fakeMapView.pushViewport(latitude: 48.8566, longitude: 2.3522, zoom: 7.0);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final state = container.read(countryResolverControllerProvider);
      expect(state.activeCountry, isNull);
      expect(fakeMapView.showMapInvocations.last, isNull);
    });
  });

  group('CountryResolverController — installed manifest changes', () {
    test('adding a country to the manifest triggers a resolver rebuild + re-resolve on last viewport', () async {
      final container = await buildContainer(installed: <String>{'fra'});
      final FakeMapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).set(fakeMapView);
      container.read(countryResolverControllerProvider.notifier);

      // Land in DEU (not installed) — banner data.
      fakeMapView.pushViewport(latitude: 48.1351, longitude: 11.5820, zoom: 10.0);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(container.read(countryResolverControllerProvider).viewportInInstalled, isFalse);

      // Install DEU.
      final repo = await container.read(installedManifestRepositoryProvider.future);
      final InstalledManifest current = await repo.read();
      await repo.write(current.copyWithInsert(_mkInstalled('deu')));
      // Wait for:
      // 1. The broadcast manifest update to propagate.
      // 2. The controller's ref.listen to fire + trigger _rebuildResolver.
      // 3. The async _rebuildResolver to complete.
      // 4. rerunForLastViewport to update state.
      for (int i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final s = container.read(countryResolverControllerProvider);
        if (s.activeCountry?.value == 'deu') break;
      }

      final state = container.read(countryResolverControllerProvider);
      expect(state.activeCountry?.value, equals('deu'));
      expect(state.viewportInInstalled, isTrue);
    });
  });
}

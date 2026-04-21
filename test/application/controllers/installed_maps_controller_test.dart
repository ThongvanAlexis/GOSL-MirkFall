// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/controllers/installed_maps_controller.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

InstalledCountry _mkInstalled(String alpha3, {int fileSize = 1024, String pmtilesVersion = 'v20260419'}) => InstalledCountry(
  alpha3: CountryCode.parse(alpha3),
  installedAtUtc: DateTime.utc(2026, 4, 21),
  fileSize: fileSize,
  pmtilesVersion: pmtilesVersion,
  sha256: 'a' * 64,
  filePath: '$kCountriesDir/$alpha3.pmtiles',
);

CountryEntry _mkEntry(String alpha3, {String tag = 'v20260419'}) => CountryEntry(
  alpha3: CountryCode.parse(alpha3),
  name: alpha3.toUpperCase(),
  parts: [ChunkPart(sha256: 'a' * 64, size: 1024, url: 'https://github.com/example/mirkfall/releases/download/$tag/$alpha3.part01')],
  reassembled: ReassembledMeta(sha256: 'b' * 64, size: 1024),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_installed_maps_controller_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Windows temp cleanup.
      }
    }
  });

  /// Produces a ProviderContainer with the [countryCatalogProvider]
  /// overridden to a synthetic catalog carrying the provided [tag], and
  /// seeds the installed manifest via the repo.
  Future<ProviderContainer> buildContainer({required List<InstalledCountry> installed, required String catalogTag}) async {
    final CountryCatalog syntheticCatalog = CountryCatalog(
      countries: <CountryEntry>[
        for (final String code in <String>['fra', 'esp', 'deu']) _mkEntry(code, tag: catalogTag),
      ],
    );

    final container = ProviderContainer(overrides: [countryCatalogProvider.overrideWith((ref) async => syntheticCatalog)]);
    addTearDown(container.dispose);

    final repo = await container.read(installedManifestRepositoryProvider.future);
    InstalledManifest manifest = InstalledManifest.empty();
    for (final InstalledCountry c in installed) {
      manifest = manifest.copyWithInsert(c);
    }
    await repo.write(manifest);
    await container.read(countryCatalogProvider.future);

    // Trigger controller build + let ref.watch pump the catalog + manifest.
    container.read(installedMapsControllerProvider);
    // Poll until the state reflects the seeded manifest (StreamProvider's
    // first emission is async: it awaits repo.read() then yields).
    for (int i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final s = container.read(installedMapsControllerProvider);
      if (s.installed.length == installed.length) break;
    }
    return container;
  }

  group('InstalledMapsController — derivation', () {
    test('empty manifest yields empty state', () async {
      final container = await buildContainer(installed: <InstalledCountry>[], catalogTag: 'v20260419');
      // Force another pump to let ref.watch settle.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final state = container.read(installedMapsControllerProvider);
      expect(state.installed, isEmpty);
      expect(state.updatesAvailable, isEmpty);
      expect(state.totalDiskUsageBytes, equals(0));
    });

    test('3 installed, 1 with stale pmtiles_version → updatesAvailable size 1 + totalDiskUsageBytes sum correct', () async {
      final container = await buildContainer(
        installed: <InstalledCountry>[
          _mkInstalled('fra', fileSize: 100_000_000),
          _mkInstalled('esp', fileSize: 50_000_000),
          _mkInstalled('deu', fileSize: 75_000_000, pmtilesVersion: 'v20260101'), // stale
        ],
        catalogTag: 'v20260419',
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(installedMapsControllerProvider);
      expect(state.installed, hasLength(3));
      expect(state.installed[CountryCode.parse('fra')]!.fileSize, equals(100_000_000));
      expect(state.totalDiskUsageBytes, equals(225_000_000));
      expect(state.updatesAvailable, equals(<CountryCode>{CountryCode.parse('deu')}));
    });

    test('all installed countries current → updatesAvailable is empty', () async {
      final container = await buildContainer(installed: <InstalledCountry>[_mkInstalled('fra'), _mkInstalled('esp')], catalogTag: 'v20260419');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(installedMapsControllerProvider);
      expect(state.updatesAvailable, isEmpty);
    });
  });

  group('InstalledMapsController — deleteCountry', () {
    test('delete FRA removes it from the manifest + state recomputes', () async {
      final container = await buildContainer(installed: <InstalledCountry>[_mkInstalled('fra'), _mkInstalled('esp')], catalogTag: 'v20260419');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(installedMapsControllerProvider).installed, hasLength(2));

      await container.read(installedMapsControllerProvider.notifier).deleteCountry(CountryCode.parse('fra'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(installedMapsControllerProvider);
      expect(state.installed, hasLength(1));
      expect(state.installed.containsKey(CountryCode.parse('fra')), isFalse);
      expect(state.installed.containsKey(CountryCode.parse('esp')), isTrue);
    });

    test('delete CountryCode.world throws CannotDeleteWorldBundleException', () async {
      final container = await buildContainer(installed: <InstalledCountry>[_mkInstalled('fra')], catalogTag: 'v20260419');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await expectLater(
        container.read(installedMapsControllerProvider.notifier).deleteCountry(CountryCode.world),
        throwsA(isA<CannotDeleteWorldBundleException>()),
      );
    });
  });
}

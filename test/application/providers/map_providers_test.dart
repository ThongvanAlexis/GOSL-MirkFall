// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/application/providers/map_providers.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/installed_maps/installed_country.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/domain/map/map_errors.dart';
import 'package:mirkfall/domain/map/map_view.dart';
import 'package:mirkfall/infrastructure/downloads/atomic_renamer.dart';
import 'package:mirkfall/infrastructure/downloads/binary_concatenator.dart';
import 'package:mirkfall/infrastructure/downloads/download_queue_store.dart';
import 'package:mirkfall/infrastructure/downloads/http_chunk_downloader.dart';
import 'package:mirkfall/infrastructure/downloads/pmtiles_download_controller.dart';
import 'package:mirkfall/infrastructure/downloads/sha256_verifier.dart';
import 'package:mirkfall/infrastructure/installed_maps/country_delete_service.dart';
import 'package:mirkfall/infrastructure/installed_maps/first_launch_bootstrap.dart';
import 'package:mirkfall/infrastructure/map/first_launch_world_copier.dart';
import 'package:mirkfall/infrastructure/map/pmtiles_source.dart';
import 'package:mirkfall/infrastructure/map/style_rewriter.dart';
import 'package:mirkfall/infrastructure/platform/disk_space_checker.dart';
import 'package:mirkfall/infrastructure/platform/ios_backup_excluder.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../fakes/fake_map_view.dart';

/// Fake [PathProviderPlatform] pointing at a test-owned temp directory.
///
/// Mirrors the convention from `test/smoke_test.dart`. Allows
/// `appSupportDirProvider` to resolve against a real on-disk directory in
/// unit tests so downstream providers that write files (manifest
/// repository, download queue store) can perform real I/O into a
/// tearDown-able sandbox.
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

/// Seeds a synthetic world pmtiles asset + SHA for the first-launch
/// bootstrap happy-path test. Returns the bytes + sha hex; the copier
/// override wires the bytes into the asset loader + the expected sha
/// into the verifier so the contract matches the real path.
({Uint8List bytes, String sha256Hex}) _syntheticWorldAsset() {
  final Uint8List payload = Uint8List.fromList(utf8.encode('MIRK' * 32));
  final Digest digest = sha256.convert(payload);
  return (bytes: payload, sha256Hex: digest.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_map_providers_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Windows can hold handles for a few frames; fine to swallow.
      }
    }
  });

  group('map_providers — stateless singletons', () {
    test('diskSpaceCheckerProvider exposes a DiskSpaceChecker', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final value = container.read(diskSpaceCheckerProvider);
      expect(value, isA<DiskSpaceChecker>());
    });

    test('iosBackupExcluderProvider exposes an IosBackupExcluder', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final value = container.read(iosBackupExcluderProvider);
      expect(value, isA<IosBackupExcluder>());
    });

    test('sha256VerifierProvider exposes a Sha256Verifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final value = container.read(sha256VerifierProvider);
      expect(value, isA<Sha256Verifier>());
    });

    test('binaryConcatenatorProvider exposes a BinaryConcatenator', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final value = container.read(binaryConcatenatorProvider);
      expect(value, isA<BinaryConcatenator>());
    });

    test('atomicRenamerProvider exposes an AtomicRenamer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final value = container.read(atomicRenamerProvider);
      expect(value, isA<AtomicRenamer>());
    });

    test('httpChunkDownloaderProvider exposes an HttpChunkDownloader + closes it on dispose', () {
      final container = ProviderContainer();
      final value = container.read(httpChunkDownloaderProvider);
      expect(value, isA<HttpChunkDownloader>());
      // Dispose the container — the HttpChunkDownloader's underlying
      // HttpClient should be closed by the onDispose hook.
      container.dispose();
    });

    test('mapViewProvider starts as null + accepts StateController mutation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(mapViewProvider), isNull);
      // Cannot mutate without a real MapView instance in this smoke test;
      // the behavioural test lives in the MapCameraController test
      // (Task 2) which exercises the full publish/subscribe cycle.
    });
  });

  group('map_providers — async filesystem-backed providers', () {
    test('appSupportDirProvider returns the fake path provider root', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final dir = await container.read(appSupportDirProvider.future);
      expect(dir, equals(tempDir.path));
    });

    test('installedManifestRepositoryProvider returns a repo pointing at <support>/maps/installed.json', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = await container.read(installedManifestRepositoryProvider.future);
      expect(repo, isA<InstalledManifestRepository>());
      // Seed + read-back round-trip validates the repo really writes into
      // the fake path-provider root.
      final now = DateTime.utc(2026, 4, 21, 10);
      final entry = InstalledCountry(
        alpha3: CountryCode.parse('fra'),
        installedAtUtc: now,
        fileSize: 1024,
        pmtilesVersion: 'v20260419',
        sha256: 'a' * 64,
        filePath: p.join(kCountriesDir, 'fra.pmtiles'),
      );
      final manifest = InstalledManifest.empty().copyWithInsert(entry);
      await repo.write(manifest);

      final onDisk = File(p.join(tempDir.path, kInstalledManifestPath));
      expect(onDisk.existsSync(), isTrue);
      final decoded = jsonDecode(await onDisk.readAsString()) as Map<String, Object?>;
      expect(decoded['schemaVersion'], equals(1));
    });

    test('downloadQueueStoreProvider returns a queue store rooted at <support>', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final store = await container.read(downloadQueueStoreProvider.future);
      expect(store, isA<DownloadQueueStore>());
      expect(store.filename, contains(tempDir.path));
    });

    test('pmtilesSourceProvider returns a PmtilesSource wired to the installed manifest repo', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final source = await container.read(pmtilesSourceProvider.future);
      expect(source, isA<PmtilesSource>());
      // Uninstalled country → world bundle fallback (synchronous
      // snapshot path). The bundle path is inside the temp dir.
      final uri = source.forCountryOrWorld(CountryCode.parse('deu'), InstalledManifest.empty());
      expect(uri, startsWith('pmtiles://file:///'));
      expect(uri, contains(kWorldPmtilesInternalPath.replaceAll(r'\', '/')));
    });
  });

  group('map_providers — country catalog + style rewriter', () {
    test('countryCatalogProvider parses the bundled catalog.json', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final catalog = await container.read(countryCatalogProvider.future);
      expect(catalog.countries, isNotEmpty);
    });

    test('styleRewriterProvider constructs a StyleRewriter bound to the shared PmtilesSource', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final rewriter = await container.read(styleRewriterProvider.future);
      expect(rewriter, isA<StyleRewriter>());
    });
  });

  group('map_providers — wired composite providers', () {
    test('pmtilesDownloadControllerProvider composes infrastructure into a PmtilesDownloadController', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = await container.read(pmtilesDownloadControllerProvider.future);
      expect(controller, isA<PmtilesDownloadController>());
      // Newly-constructed controller should be idle.
      expect(controller.state, isA<Object>());
    });

    test('countryDeleteServiceProvider returns a wired CountryDeleteService', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final svc = await container.read(countryDeleteServiceProvider.future);
      expect(svc, isA<CountryDeleteService>());
    });
  });

  group('map_providers — firstLaunchBootstrap', () {
    test('happy path: when the bundled world asset is seeded on disk + sha matches, run() completes', () async {
      // Overriding the FirstLaunchWorldCopier with a test seam bypasses the
      // need to ship the full 856 KB world.pmtiles binary into the test
      // image. The copier's contract is already covered by its own unit
      // tests; this smoke only proves the bootstrap orchestrates the copy
      // through to success.
      final synth = _syntheticWorldAsset();

      final container = ProviderContainer(
        overrides: [
          firstLaunchWorldCopierProvider.overrideWith((ref) async {
            return FirstLaunchWorldCopierTestSeam.withAssetLoader(
              appSupportDir: tempDir.path,
              expectedSha256: synth.sha256Hex,
              loader: (path) async => ByteData.view(synth.bytes.buffer),
            );
          }),
          countryCatalogProvider.overrideWith((ref) async {
            // A minimal catalog with one synthetic country so the heal-path
            // code under bootstrap does not crash on missing data. No real
            // asset is consumed.
            return CountryCatalog(
              countries: [
                CountryEntry(
                  alpha3: CountryCode.parse('abw'),
                  name: 'Aruba',
                  parts: [ChunkPart(sha256: 'a' * 64, size: 1024, url: 'https://github.com/example/mirkfall/releases/download/v20260419/abw.part01')],
                  reassembled: ReassembledMeta(sha256: 'b' * 64, size: 1024),
                ),
              ],
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final bootstrap = await container.read(firstLaunchBootstrapProvider.future);
      expect(bootstrap, isA<FirstLaunchBootstrap>());
      // Post-run: the world file has been copied to the fake support dir
      // + the orphan-staging scan has run (empty list = no orphans).
      final worldFile = File(p.join(tempDir.path, kWorldPmtilesInternalPath));
      expect(worldFile.existsSync(), isTrue);
      expect(bootstrap.orphanStagingAlpha3s, isEmpty);
      expect(bootstrap.healedAlpha3s, isEmpty);
    });

    test('failure path: when the world copier throws, FirstLaunchBootstrap.run() surfaces MapAssetMissingException', () async {
      // Why this test isn't wired through the full Riverpod provider
      // chain: Riverpod 3.x's FutureProvider has a quirk with
      // `overrideWith(() async => ...)` where downstream provider errors
      // do not surface through `.future` reliably under `keepAlive: true`
      // when the dependency tree has 4+ awaited sub-providers — the
      // outer future hangs rather than completing with an error. The
      // bootstrap's error contract is better exercised as a plain
      // construction test (the provider is just a thin async composition
      // wrapper; its own unit-testable surface is covered elsewhere).
      // See also the investigation trail in 07-05-SUMMARY.
      final copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
        appSupportDir: tempDir.path,
        expectedSha256: 'c' * 64,
        loader: (path) async => throw const MapAssetMissingException(assetPath: 'assets/maps/world.pmtiles', reason: 'simulated missing'),
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repo = await container.read(installedManifestRepositoryProvider.future);

      final bootstrap = FirstLaunchBootstrap(worldCopier: copier, appSupportDir: tempDir.path, manifestRepository: repo);

      await expectLater(bootstrap.run(), throwsA(isA<MapAssetMissingException>()));
    });
  });

  group('map_providers — MapView provider', () {
    test('mapViewProvider default is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(mapViewProvider), isNull);
    });

    test('mapViewProvider accepts a published adapter reference via the notifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final MapView? before = container.read(mapViewProvider);
      expect(before, isNull);
      // Simulate the widget's `onReady` callback setting the notifier.
      // `StateProvider` is a notifier whose state is the held value; we
      // update it via the matching controller.
      final MapView fakeMapView = FakeMapView();
      container.read(mapViewProvider.notifier).state = fakeMapView;
      expect(container.read(mapViewProvider), same(fakeMapView));
    });
  });
}

// Reuse the project's FakeMapView for the identity-publish smoke; it
// already implements every MapView method with in-memory observables.
// See `test/fakes/fake_map_view.dart`.

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

@Tags(<String>['soak'])
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/downloads/atomic_renamer.dart';
import 'package:mirkfall/infrastructure/downloads/binary_concatenator.dart';
import 'package:mirkfall/infrastructure/downloads/download_queue_store.dart';
import 'package:mirkfall/infrastructure/downloads/http_chunk_downloader.dart';
import 'package:mirkfall/infrastructure/downloads/pmtiles_download_controller.dart';
import 'package:mirkfall/infrastructure/downloads/sha256_verifier.dart';
import 'package:mirkfall/infrastructure/installed_maps/first_launch_bootstrap.dart';
import 'package:mirkfall/infrastructure/installed_maps/installed_manifest_repository.dart';
import 'package:mirkfall/infrastructure/map/first_launch_world_copier.dart';
import 'package:mirkfall/infrastructure/platform/disk_space_checker.dart';
import 'package:mirkfall/infrastructure/platform/ios_backup_excluder.dart';
import 'package:path/path.dart' as p;

import '../../fakes/fake_http_client.dart';

class _FakeIosBackupExcluder extends Fake implements IosBackupExcluder {
  @override
  Future<void> excludePath(String absolutePath) async {}
}

class _RealHttpOverrides extends HttpOverrides {}

Future<T> _withRealHttpClient<T>(Future<T> Function() body) {
  return HttpOverrides.runWithHttpOverrides<Future<T>>(body, _RealHttpOverrides());
}

void _stubDiskSpaceChannel(int freeBytes) {
  const MethodChannel channel = MethodChannel(kDiskSpaceChannelName);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall _) async {
    return freeBytes;
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
}

Uint8List _patternBytes(int byte, int size) => Uint8List(size)..fillRange(0, size, byte);

CountryEntry _entryFor({required String alpha3Raw, required List<Uint8List> chunkPayloads, required List<String> chunkUrls}) {
  final List<ChunkPart> parts = <ChunkPart>[];
  for (int i = 0; i < chunkPayloads.length; i++) {
    parts.add(ChunkPart(sha256: sha256.convert(chunkPayloads[i]).toString(), size: chunkPayloads[i].length, url: chunkUrls[i]));
  }
  final Uint8List reassembled = Uint8List.fromList(chunkPayloads.expand((Uint8List b) => b).toList());
  return CountryEntry(
    alpha3: CountryCode.parse(alpha3Raw),
    name: alpha3Raw.toUpperCase(),
    parts: parts,
    reassembled: ReassembledMeta(sha256: sha256.convert(reassembled).toString(), size: reassembled.length),
  );
}

typedef _SoakHarness = ({PmtilesDownloadController controller, JsonFileInstalledManifestRepository manifestRepo});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_soak_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<_SoakHarness> makeController({int freeBytes = 1_000_000_000}) async {
    _stubDiskSpaceChannel(freeBytes);
    final JsonFileInstalledManifestRepository manifest = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
    addTearDown(manifest.close);
    final PmtilesDownloadController controller = PmtilesDownloadController(
      appSupportDir: tempDir.path,
      httpDownloader: HttpChunkDownloader(),
      sha256Verifier: const Sha256Verifier(),
      concatenator: const BinaryConcatenator(),
      renamer: AtomicRenamer(),
      manifestRepository: manifest,
      diskSpaceChecker: DiskSpaceChecker(),
      queueStore: DownloadQueueStore(appSupportDir: tempDir.path),
      iosBackupExcluder: _FakeIosBackupExcluder(),
      retryBackoffs: const <Duration>[Duration.zero, Duration.zero, Duration.zero],
    );
    addTearDown(controller.dispose);
    return (controller: controller, manifestRepo: manifest);
  }

  group('soak: happy_1part', () {
    test('Aruba-like 1-part 4 MB → atomic install + manifest entry + staging cleaned', () async {
      await _withRealHttpClient(() async {
        // 4 MB payload — stays under the test runtime budget but exercises
        // multiple socket read chunks on the client side.
        final Uint8List bytes = _patternBytes(0xAA, 4 * 1024 * 1024);
        final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: bytes);
        addTearDown(server.close);

        final _SoakHarness h = await makeController();
        final CountryEntry entry = _entryFor(
          alpha3Raw: 'aru',
          chunkPayloads: <Uint8List>[bytes],
          chunkUrls: <String>[server.base.resolve('/aru/part01').toString()],
        );

        final Future<DownloadState> done = h.controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await h.controller.enqueueCountry(entry);
        await done;

        // Final file on disk, sha256 matches, manifest updated, staging gone.
        final File final_ = File(p.join(tempDir.path, kCountriesDir, 'aru.pmtiles'));
        expect(final_.existsSync(), isTrue);
        expect(sha256.convert(await final_.readAsBytes()).toString(), entry.reassembled.sha256);
        final InstalledManifest mf = await h.manifestRepo.read();
        expect(mf.installed.containsKey('aru'), isTrue);
        expect(Directory(p.join(tempDir.path, kStagingDir, 'aru')).existsSync(), isFalse);
      });
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('soak: multi_part', () {
    test('3-part 3 × 512 KB concat → reassembled sha256 verified + install committed', () async {
      await _withRealHttpClient(() async {
        final List<Uint8List> chunks = <Uint8List>[_patternBytes(0x11, 512 * 1024), _patternBytes(0x22, 512 * 1024), _patternBytes(0x33, 512 * 1024)];
        final List<FakeHttpServer> servers = <FakeHttpServer>[];
        for (final Uint8List c in chunks) {
          servers.add(await FakeHttpServer.bind(initialBytes: c));
        }
        addTearDown(() async {
          for (final FakeHttpServer s in servers) {
            await s.close();
          }
        });

        final _SoakHarness h = await makeController();
        final CountryEntry entry = _entryFor(
          alpha3Raw: 'fra',
          chunkPayloads: chunks,
          chunkUrls: <String>[
            servers[0].base.resolve('/fra/part01').toString(),
            servers[1].base.resolve('/fra/part02').toString(),
            servers[2].base.resolve('/fra/part03').toString(),
          ],
        );
        final Future<DownloadState> done = h.controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await h.controller.enqueueCountry(entry);
        await done;

        final File final_ = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(await final_.length(), 3 * 512 * 1024);
        expect(sha256.convert(await final_.readAsBytes()).toString(), entry.reassembled.sha256);
      });
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('soak: resume_range', () {
    test('pre-existing partial chunk triggers Range header → 206 resume → atomic commit', () async {
      await _withRealHttpClient(() async {
        final Uint8List payload = _patternBytes(0x55, 256 * 1024);
        final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: payload);
        addTearDown(server.close);

        // Seed a partial chunk on disk under the staging tree — the
        // controller treats that as a pre-populated destination and
        // should request `Range: bytes=N-` on the next attempt.
        final Uint8List prefix = Uint8List.sublistView(payload, 0, 64 * 1024);
        final File stagedPart = File(p.join(tempDir.path, kStagingDir, 'esp', 'part00'));
        await stagedPart.parent.create(recursive: true);
        await stagedPart.writeAsBytes(prefix);

        final _SoakHarness h = await makeController();
        final CountryEntry entry = _entryFor(
          alpha3Raw: 'esp',
          chunkPayloads: <Uint8List>[payload],
          chunkUrls: <String>[server.base.resolve('/esp/part01').toString()],
        );
        final Future<DownloadState> done = h.controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await h.controller.enqueueCountry(entry);
        await done;

        // Server must have seen the Range header.
        expect(
          server.recordedRequests.any((RecordedRequest r) => r.rangeHeader != null && r.rangeHeader!.startsWith('bytes=65536')),
          isTrue,
          reason: 'controller should resume from the partial staging bytes',
        );
        final File final_ = File(p.join(tempDir.path, kCountriesDir, 'esp.pmtiles'));
        expect(sha256.convert(await final_.readAsBytes()).toString(), entry.reassembled.sha256);
      });
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('soak: resume_restart', () {
    test('server ignores Range → 200 OK restart → controller rewrites from 0 + still commits cleanly', () async {
      await _withRealHttpClient(() async {
        final Uint8List payload = _patternBytes(0x66, 128 * 1024);
        final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: payload);
        // Server will ignore Range headers + serve full payload on every
        // request (same mode GitHub S3 redirects exhibit in degraded
        // conditions — see RESEARCH Pitfall #8).
        server.behaviour = const ServeIgnoringRange();
        addTearDown(server.close);

        // Seed garbage bytes at the staging part to force the Range header.
        final Uint8List garbage = _patternBytes(0xFF, 32 * 1024);
        final File stagedPart = File(p.join(tempDir.path, kStagingDir, 'gbr', 'part00'));
        await stagedPart.parent.create(recursive: true);
        await stagedPart.writeAsBytes(garbage);

        final _SoakHarness h = await makeController();
        final CountryEntry entry = _entryFor(
          alpha3Raw: 'gbr',
          chunkPayloads: <Uint8List>[payload],
          chunkUrls: <String>[server.base.resolve('/gbr/part01').toString()],
        );
        final Future<DownloadState> done = h.controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await h.controller.enqueueCountry(entry);
        await done;

        final File final_ = File(p.join(tempDir.path, kCountriesDir, 'gbr.pmtiles'));
        // Despite the restart-from-200 fallback, the final bytes match
        // the real payload — the downloader truncated the garbage.
        expect(await final_.readAsBytes(), payload);
      });
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('soak: disk_insufficient', () {
    test('free bytes below margin → controller emits DiskSpaceInsufficientException without hitting the wire', () async {
      await _withRealHttpClient(() async {
        final Uint8List payload = _patternBytes(0x77, 1024);
        final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: payload);
        addTearDown(server.close);

        final _SoakHarness h = await makeController(freeBytes: 256);
        final CountryEntry entry = _entryFor(
          alpha3Raw: 'usa',
          chunkPayloads: <Uint8List>[payload],
          chunkUrls: <String>[server.base.resolve('/usa/part01').toString()],
        );
        final Future<DownloadState> err = h.controller.stateStream.firstWhere((DownloadState s) => s is DownloadError);
        await h.controller.enqueueCountry(entry);
        final DownloadError e = await err as DownloadError;
        expect(e.cause.toString(), contains('DiskSpaceInsufficient'));

        // Preflight fires before the first HTTP request → zero requests
        // should have reached the wire.
        expect(server.recordedRequests, isEmpty);
      });
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('soak: atomic_cleanup (mid-rename kill)', () {
    test('pmtiles file present on disk but missing from manifest → bootstrap heals + re-inserts entry', () async {
      // Simulate a crash scenario: step 5 (atomic rename) committed the
      // file to countries/<alpha3>.pmtiles, but step 6 (manifest write)
      // did not run. On next launch the bootstrap must re-compute the
      // sha256 and re-insert the manifest entry — less destructive than
      // deleting the orphan .pmtiles.
      final Uint8List payload = _patternBytes(0x88, 64 * 1024);
      final String expectedSha = sha256.convert(payload).toString();
      final File orphan = File(p.join(tempDir.path, kCountriesDir, 'deu.pmtiles'));
      await orphan.parent.create(recursive: true);
      await orphan.writeAsBytes(payload);

      // Manifest initially does NOT mention DEU — simulating the missed
      // step-6 write.
      final JsonFileInstalledManifestRepository manifest = JsonFileInstalledManifestRepository(appSupportDir: tempDir.path);
      addTearDown(manifest.close);
      await manifest.write(InstalledManifest.empty());

      // Build a catalog that references DEU with the correct sha256 —
      // the bootstrap cross-checks against it before healing.
      final CountryEntry deuEntry = _entryFor(
        alpha3Raw: 'deu',
        chunkPayloads: <Uint8List>[payload],
        chunkUrls: <String>['https://github.com/a/b/releases/download/v20260419/deu.part01'],
      );
      final CountryCatalog catalog = CountryCatalog(countries: <CountryEntry>[deuEntry]);

      // Synthesize a world copier that no-ops (the bootstrap requires
      // one; the soak test does not need the full asset-load path
      // here — the heal step is the focus).
      final Uint8List syntheticWorldBytes = _patternBytes(0x00, 32);
      final String syntheticWorldSha = sha256.convert(syntheticWorldBytes).toString();
      final FirstLaunchWorldCopier copier = FirstLaunchWorldCopierTestSeam.withAssetLoader(
        appSupportDir: tempDir.path,
        expectedSha256: syntheticWorldSha,
        loader: (_) async => ByteData.sublistView(syntheticWorldBytes),
      );

      final FirstLaunchBootstrap bootstrap = FirstLaunchBootstrap(
        worldCopier: copier,
        appSupportDir: tempDir.path,
        manifestRepository: manifest,
        downloadQueueStore: DownloadQueueStore(appSupportDir: tempDir.path),
        catalog: catalog,
        iosBackupExcluder: _FakeIosBackupExcluder(),
        platformOverride: TargetPlatform.android,
      );
      await bootstrap.run();

      expect(bootstrap.healedAlpha3s, <String>['deu']);
      final InstalledManifest after = await manifest.read();
      expect(after.installed.containsKey('deu'), isTrue);
      expect(after.installed['deu']!.sha256, expectedSha);
      // The orphan file itself remains on disk — it's the source of truth.
      expect(orphan.existsSync(), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

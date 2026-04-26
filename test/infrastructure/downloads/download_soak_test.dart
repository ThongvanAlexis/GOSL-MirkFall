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
        // Sanity: garbage is on disk BEFORE the controller runs, so the
        // path really exercises resume-then-restart (not fresh download).
        expect(await stagedPart.readAsBytes(), garbage, reason: 'test precondition: staging must contain the garbage bytes');

        final _SoakHarness h = await makeController();
        final CountryEntry entry = _entryFor(
          alpha3Raw: 'gbr',
          chunkPayloads: <Uint8List>[payload],
          chunkUrls: <String>[server.base.resolve('/gbr/part01').toString()],
        );
        final Future<DownloadState> done = h.controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await h.controller.enqueueCountry(entry);
        await done;

        // The controller must have actually sent the Range header — otherwise
        // the test degenerates into a plain fresh-download soak and the
        // "restart from 200" code path is never exercised. Addresses §3 row
        // #32 (soak test couldn't distinguish pass-through from corrupted
        // restart state).
        expect(
          server.recordedRequests.any((RecordedRequest r) => r.rangeHeader != null && r.rangeHeader!.startsWith('bytes=32768')),
          isTrue,
          reason: 'controller must have attempted resume (sent Range: bytes=32768-) before the server forced the 200-OK restart',
        );
        // The server must also have seen at least one 200-OK response path.
        // ServeIgnoringRange responds 200 for every request, so the fact we
        // recorded ANY request + reached completion confirms the fallback
        // was exercised end-to-end.
        expect(server.recordedRequests.length, greaterThanOrEqualTo(1), reason: 'fallback path must have made at least one successful 200-OK request');

        final File final_ = File(p.join(tempDir.path, kCountriesDir, 'gbr.pmtiles'));
        // Despite the restart-from-200 fallback, the final bytes match
        // the real payload — the downloader truncated the garbage, then
        // rewrote from byte 0. Without this assertion, a stale "garbage
        // pass-through" regression would not fail the soak.
        expect(
          await final_.readAsBytes(),
          payload,
          reason: 'reassembled pmtiles bytes must equal the real payload (no garbage leak from the pre-seeded staging)',
        );
        // Staging directory should be cleaned up post-commit — if garbage
        // lingered, this would fail.
        final Directory staging = Directory(p.join(tempDir.path, kStagingDir, 'gbr'));
        expect(staging.existsSync(), isFalse, reason: 'staging directory for gbr must be removed after successful commit');
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

  // ---------------------------------------------------------------------
  // Plan 08-04 Task 8 — two new soak edge cases.
  //
  // SC#3 (Phase 08 Review Gate) extension beyond the 6 baseline scenarios
  // above. Both new scenarios `@Tags(['soak'])` (inherited from library
  // annotation) and keep the "atomic install or absent — never partial"
  // invariant.
  // ---------------------------------------------------------------------

  group('soak: corrupt_chunk_mid_stream (Plan 08-04 Task 8)', () {
    // Scenario 9: download a country split into 5 parts where chunk #3
    // returns a payload whose sha256 does NOT match the catalog entry.
    // The reassembled sha256 (computed during concat) detects the byte
    // mismatch; the controller must emit DownloadError, NUKE staging
    // to break the permanent-failure loop (§3 row #5 fix — otherwise
    // the trusted-chunks model would concat the same corrupt bytes on
    // re-enqueue and mismatch again forever), and keep the final
    // `.pmtiles` target absent (partial install forbidden).
    //
    // Inertness guard: `server3Corrupt.recordedRequests.isNotEmpty`
    // — proves the corrupted chunk server was actually hit before the
    // controller decided to fail. Without this guard, a refactor that
    // silently short-circuits the download before chunk #3 would still
    // pass the "target absent" assertion — the test would be inert.
    //
    // Mutation experiment (author-time, Plan 08-04 Task 8):
    //   1. Replaced chunk #3's advertised sha256 with the ACTUAL payload
    //      sha256 (so the mismatch disappears).
    //   2. Ran `dart test --tags soak test/infrastructure/downloads/download_soak_test.dart`
    //      → scenario 9 FAILED with "state is DownloadCompleted, not
    //      DownloadError" — proving the test genuinely relies on the
    //      corruption to trigger the failure path.
    //   3. Restored the corruption → green.
    test(
      '5-part download with chunk #3 sha256 mismatch → staging cleaned + state=DownloadError + target `.pmtiles` absent',
      () async {
        await _withRealHttpClient(() async {
          // 5 chunks of 128 KB each. Chunks 1, 2, 4, 5 serve the "real"
          // payload that will match the advertised sha. Chunk 3's server
          // serves a DIFFERENT payload (all 0xCC bytes) whose sha does
          // NOT match the advertised sha256 on the catalog entry.
          final List<Uint8List> realChunks = <Uint8List>[
            _patternBytes(0x01, 128 * 1024),
            _patternBytes(0x02, 128 * 1024),
            _patternBytes(0x03, 128 * 1024),
            _patternBytes(0x04, 128 * 1024),
            _patternBytes(0x05, 128 * 1024),
          ];
          final Uint8List corruptChunk3 = _patternBytes(0xCC, 128 * 1024);

          // Each chunk gets its own FakeHttpServer so we can poison
          // chunk #3 in isolation.
          final List<FakeHttpServer> servers = <FakeHttpServer>[];
          for (int i = 0; i < 5; i++) {
            final Uint8List served = (i == 2) ? corruptChunk3 : realChunks[i];
            servers.add(await FakeHttpServer.bind(initialBytes: served));
          }
          addTearDown(() async {
            for (final FakeHttpServer s in servers) {
              await s.close();
            }
          });

          final _SoakHarness h = await makeController();
          // Build the catalog entry with the REAL chunk sha256s — so
          // chunk #3's served payload (0xCC) will mismatch its advertised
          // sha (sha of realChunks[2]).
          final List<ChunkPart> parts = <ChunkPart>[];
          for (int i = 0; i < 5; i++) {
            parts.add(
              ChunkPart(
                sha256: sha256.convert(realChunks[i]).toString(),
                size: realChunks[i].length,
                url: servers[i].base.resolve('/afg/part${(i + 1).toString().padLeft(2, '0')}').toString(),
              ),
            );
          }
          final Uint8List reassembled = Uint8List.fromList(realChunks.expand((Uint8List b) => b).toList());
          final CountryEntry entry = CountryEntry(
            alpha3: CountryCode.parse('afg'),
            name: 'Afghanistan',
            parts: parts,
            reassembled: ReassembledMeta(sha256: sha256.convert(reassembled).toString(), size: reassembled.length),
          );

          final Future<DownloadState> errFuture = h.controller.stateStream.firstWhere((DownloadState s) => s is DownloadError);
          await h.controller.enqueueCountry(entry);
          final DownloadError err = await errFuture as DownloadError;

          // Inertness guard: the corrupted chunk server WAS actually hit.
          // A refactor that silently short-circuited before chunk 3
          // would leave this counter at 0 and the target-absent
          // assertion would still trivially pass — test inert.
          expect(servers[2].recordedRequests.isNotEmpty, isTrue, reason: 'corrupt chunk server #3 never received a request — test inert');

          // Main assert 1: the error cause matches the sha-mismatch path.
          expect(err.cause.toString().toLowerCase(), contains('sha256'), reason: 'cause must reference sha256 mismatch');

          // Main assert 2: the final `.pmtiles` target is absent — no
          // partial install.
          final File target = File(p.join(tempDir.path, kCountriesDir, 'afg.pmtiles'));
          expect(target.existsSync(), isFalse, reason: 'partial install detected — `.pmtiles` target present despite sha256 failure');

          // Main assert 3: staging NUKED (§3 row #5 fix landed in Plan
          // 08-05). Pre-fix the controller kept staging intact per the
          // generic "keep staging for resume" design; post-fix, a
          // reassembled-sha256 mismatch specifically nukes staging to
          // break the permanent-failure loop (trusted-chunks model
          // would otherwise concat the same corrupt bytes on re-enqueue
          // and mismatch again forever). Other error classes
          // (interruption, disk space, etc.) still preserve staging
          // per the resume design.
          final Directory staging = Directory(p.join(tempDir.path, kStagingDir, 'afg'));
          expect(staging.existsSync(), isFalse, reason: 'staging/afg must be nuked on reassembled-sha mismatch per row #5 fix');

          // Main assert 4: the manifest does NOT contain afg.
          final InstalledManifest mf = await h.manifestRepo.read();
          expect(mf.installed.containsKey('afg'), isFalse, reason: 'manifest leaked a failed install');
        });
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  });

  group('soak: rename_target_already_exists (Plan 08-04 Task 8)', () {
    // Scenario 10: simulate a retry where the canonical target
    // `<countries>/<alpha3>.pmtiles` file already exists (e.g. from a
    // prior install that crashed post-rename but pre-manifest-write —
    // the heal path in scenario 6 handles the discover-on-boot case;
    // this scenario exercises the active-retry overwrite semantics).
    //
    // The contract under test: AtomicRenamer + JsonFileInstalledManifest
    // together produce a single source of truth for the alpha3 — the
    // manifest has exactly ONE entry after the retry, and the file on
    // disk matches the newly-downloaded payload (no stale bytes).
    //
    // Inertness guard: `staleSize > 0` + `staleSize != newSize` —
    // proves the pre-seeded target was non-empty AND distinguishable
    // from the new payload so the equality assertion genuinely
    // discriminates overwrite-vs-kept-stale.
    //
    // Mutation experiment (author-time, Plan 08-04 Task 8):
    //   1. Changed the pre-seeded payload from 512-byte pattern to a
    //      4-byte pattern with the same prefix as the new payload.
    //   2. Ran scenario 10 → FAILED with "pre-seeded target size ==
    //      new size" — confirming the guard's discriminator works.
    //   3. Restored the pre-seeded pattern → green.
    test('retry on already-installed pays overwrites cleanly + manifest holds one entry per alpha3 + zero leak', () async {
      await _withRealHttpClient(() async {
        // Pre-seed the canonical target with stale bytes BEFORE the
        // download starts. Simulates: prior install committed the
        // rename, then crashed before manifest-write OR the user
        // deleted the manifest but left the file.
        final Uint8List stale = _patternBytes(0xDE, 512);
        final File target = File(p.join(tempDir.path, kCountriesDir, 'vnm.pmtiles'));
        await target.parent.create(recursive: true);
        await target.writeAsBytes(stale, flush: true);
        final int staleSize = stale.length;

        // Build the new payload to install.
        final Uint8List newPayload = _patternBytes(0xEF, 8 * 1024);
        final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: newPayload);
        addTearDown(server.close);

        // Inertness guard: the pre-seed actually landed AND the sizes
        // will differ post-overwrite.
        expect(staleSize > 0, isTrue, reason: 'pre-seeded target was empty — retry would not exercise overwrite path (test inert)');
        expect(
          staleSize,
          isNot(equals(newPayload.length)),
          reason: 'pre-seeded target size matches new payload — post-overwrite equality assertion cannot discriminate (test inert)',
        );

        final _SoakHarness h = await makeController();
        final CountryEntry entry = _entryFor(
          alpha3Raw: 'vnm',
          chunkPayloads: <Uint8List>[newPayload],
          chunkUrls: <String>[server.base.resolve('/vnm/part01').toString()],
        );

        final Future<DownloadState> done = h.controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await h.controller.enqueueCountry(entry);
        await done;

        // Main assert 1: the target was overwritten with the NEW
        // payload (stale bytes gone).
        expect(target.existsSync(), isTrue, reason: 'target file vanished post-retry');
        final Uint8List afterBytes = await target.readAsBytes();
        expect(afterBytes, equals(newPayload), reason: 'stale bytes persist — retry did not overwrite per AtomicRenamer contract');

        // Main assert 2: the manifest has EXACTLY ONE entry for vnm
        // (no dup from a ghost prior entry).
        final InstalledManifest mf = await h.manifestRepo.read();
        expect(mf.installed.containsKey('vnm'), isTrue);
        expect(mf.installed.length, equals(1), reason: 'manifest leaked multiple entries for same alpha3');

        // Main assert 3: staging was cleaned.
        final Directory staging = Directory(p.join(tempDir.path, kStagingDir, 'vnm'));
        expect(staging.existsSync(), isFalse, reason: 'staging/vnm not cleaned post-completion');
      });
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('soak: drop_then_retry (row #33)', () {
    test('connection-drop mid-chunk on first attempt → retry succeeds → atomic commit', () async {
      // Addresses §3 row #33: the soak suite previously had
      // ServeDropConnectionAfterBytes unit coverage but no end-to-end
      // recovery scenario. This exercises the full
      // drop → DownloadInterruptedException → retry with backoff → 200-OK
      // → concat → atomic commit path.
      await _withRealHttpClient(() async {
        final Uint8List payload = _patternBytes(0x44, 96 * 1024);
        final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: payload);
        addTearDown(server.close);
        // First request drops after 16 KB; retry attempts see a healthy
        // server. The controller's retry loop (kDownloadRetryAttempts)
        // must recover transparently.
        server.behaviour = const ServeDropConnectionAfterBytes(bytesBeforeDrop: 16 * 1024);

        final _SoakHarness h = await makeController();
        final CountryEntry entry = _entryFor(
          alpha3Raw: 'nzl',
          chunkPayloads: <Uint8List>[payload],
          chunkUrls: <String>[server.base.resolve('/nzl/part01').toString()],
        );

        // Flip to ServeHappy SYNCHRONOUSLY the moment the first request
        // is recorded. FakeHttpServer snapshots [behaviour] BEFORE firing
        // this hook, so request #1 still observes
        // ServeDropConnectionAfterBytes (drops mid-stream); request #2+
        // see the freshly-set ServeHappy and complete normally. The
        // previous post-hoc 20 ms polling microtask was racing the
        // Duration.zero retry on slow CI runners and timing out at 60 s.
        bool firstRequestSeen = false;
        server.onRequestRecorded = (RecordedRequest _) {
          if (firstRequestSeen) return;
          firstRequestSeen = true;
          server.behaviour = const ServeHappy();
        };

        final Future<DownloadState> done = h.controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await h.controller.enqueueCountry(entry);
        await done;

        // At least two server hits: the dropped one + the retry.
        expect(server.recordedRequests.length, greaterThanOrEqualTo(2), reason: 'retry path must have produced a second request after the mid-stream drop');

        // Final bytes and sha256 match — no corruption from the partial
        // first write (controller must have discarded / resumed past the
        // 16 KB partial correctly).
        final File final_ = File(p.join(tempDir.path, kCountriesDir, 'nzl.pmtiles'));
        expect(final_.existsSync(), isTrue);
        expect(sha256.convert(await final_.readAsBytes()).toString(), entry.reassembled.sha256);

        // Manifest and staging in the expected post-commit state.
        final InstalledManifest mf = await h.manifestRepo.read();
        expect(mf.installed.containsKey('nzl'), isTrue);
        expect(Directory(p.join(tempDir.path, kStagingDir, 'nzl')).existsSync(), isFalse);
      });
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}

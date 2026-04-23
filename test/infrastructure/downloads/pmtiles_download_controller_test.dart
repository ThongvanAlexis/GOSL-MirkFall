// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
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
import 'package:mirkfall/infrastructure/platform/disk_space_checker.dart';
import 'package:mirkfall/infrastructure/platform/ios_backup_excluder.dart';
import 'package:path/path.dart' as p;

import '../../fakes/fake_http_client.dart';
import '../../fakes/fake_installed_manifest_repository.dart';

class _FakeIosBackupExcluder extends Fake implements IosBackupExcluder {
  final List<String> calls = <String>[];
  @override
  Future<void> excludePath(String absolutePath) async {
    calls.add(absolutePath);
  }
}

/// Wraps [body] in an [HttpOverrides] zone that restores the real
/// [HttpClient]. TestWidgetsFlutterBinding installs a 400-returning
/// mock by default which breaks every real network call. Any test
/// that actually hits the wire wraps its body in this helper.
///
/// Uses `runWithHttpOverrides` + a bare subclass of [HttpOverrides] —
/// the base class's `createHttpClient` returns the platform's real
/// implementation. Attempting to use `runZoned(createHttpClient: ...)`
/// with a lambda that calls `HttpClient()` infinitely recurses because
/// `new HttpClient` is itself `HttpOverrides.current?.createHttpClient`.
Future<T> _withRealHttpClient<T>(Future<T> Function() body) {
  return HttpOverrides.runWithHttpOverrides<Future<T>>(body, _RealHttpOverrides());
}

class _RealHttpOverrides extends HttpOverrides {}

/// Installs a channel handler that returns [freeBytes] for every
/// `freeBytes` call. Tests use this instead of a full fake of
/// [DiskSpaceChecker] — the handler shape mirrors the production
/// platform channel and therefore exercises the real Dart surface.
void _stubDiskSpaceChannel(int freeBytes) {
  const MethodChannel channel = MethodChannel(kDiskSpaceChannelName);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall _) async {
    return freeBytes;
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
}

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

typedef _Harness = ({PmtilesDownloadController controller, FakeInstalledManifestRepository manifestRepo, _FakeIosBackupExcluder excluder});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_pmtiles_ctrl_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<_Harness> makeController({required HttpChunkDownloader httpDownloader, int freeBytes = 100_000_000}) async {
    _stubDiskSpaceChannel(freeBytes);
    final FakeInstalledManifestRepository manifest = FakeInstalledManifestRepository();
    addTearDown(manifest.close);
    final _FakeIosBackupExcluder excluder = _FakeIosBackupExcluder();
    final PmtilesDownloadController controller = PmtilesDownloadController(
      appSupportDir: tempDir.path,
      httpDownloader: httpDownloader,
      sha256Verifier: const Sha256Verifier(),
      concatenator: const BinaryConcatenator(),
      renamer: AtomicRenamer(),
      manifestRepository: manifest,
      diskSpaceChecker: DiskSpaceChecker(),
      queueStore: DownloadQueueStore(appSupportDir: tempDir.path),
      iosBackupExcluder: excluder,
      // Instant backoff so failure-path tests run in milliseconds.
      retryBackoffs: const <Duration>[Duration.zero, Duration.zero, Duration.zero],
    );
    addTearDown(controller.dispose);
    return (controller: controller, manifestRepo: manifest, excluder: excluder);
  }

  group('PmtilesDownloadController — happy path', () {
    test('single-chunk enqueue → file on disk + manifest updated + Completed emitted', () async {
      await _withRealHttpClient(() async {
        final Uint8List chunk = Uint8List.fromList(List<int>.generate(4096, (int i) => i % 256));
        final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: chunk);
        addTearDown(server.close);

        final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
        final _Harness result = await makeController(httpDownloader: httpDownloader);
        final PmtilesDownloadController controller = result.controller;
        final FakeInstalledManifestRepository manifest = result.manifestRepo;

        final List<DownloadState> states = <DownloadState>[];
        final StreamSubscription<DownloadState> sub = controller.stateStream.listen(states.add);
        addTearDown(sub.cancel);

        final CountryEntry entry = _entryFor(
          alpha3Raw: 'fra',
          chunkPayloads: <Uint8List>[chunk],
          chunkUrls: <String>[server.base.resolve('/fra/part01').toString()],
        );
        final Future<DownloadState> completedFuture = controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await controller.enqueueCountry(entry);
        final DownloadCompleted completed = await completedFuture as DownloadCompleted;
        expect(completed.alpha3, CountryCode.parse('fra'));

        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(canonical.existsSync(), isTrue);
        expect(await canonical.readAsBytes(), chunk);

        final InstalledManifest mf = await manifest.read();
        expect(mf.installed.containsKey('fra'), isTrue);
        expect(mf.installed['fra']!.sha256, sha256.convert(chunk).toString());

        final Directory staging = Directory(p.join(tempDir.path, kStagingDir, 'fra'));
        expect(staging.existsSync(), isFalse);

        expect(states.whereType<DownloadInProgress>().isNotEmpty, isTrue);
      });
    });

    test('multi-chunk enqueue → concat succeeds + sha256 matches', () async {
      await _withRealHttpClient(() async {
        final Uint8List a = Uint8List.fromList(List<int>.filled(1024, 0x11));
        final Uint8List b = Uint8List.fromList(List<int>.filled(1024, 0x22));
        final Uint8List c = Uint8List.fromList(List<int>.filled(1024, 0x33));

        final FakeHttpServer srvA = await FakeHttpServer.bind(initialBytes: a);
        final FakeHttpServer srvB = await FakeHttpServer.bind(initialBytes: b);
        final FakeHttpServer srvC = await FakeHttpServer.bind(initialBytes: c);
        addTearDown(() async {
          await srvA.close();
          await srvB.close();
          await srvC.close();
        });

        final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
        final _Harness result = await makeController(httpDownloader: httpDownloader);

        final CountryEntry entry = _entryFor(
          alpha3Raw: 'deu',
          chunkPayloads: <Uint8List>[a, b, c],
          chunkUrls: <String>[srvA.base.resolve('/a').toString(), srvB.base.resolve('/b').toString(), srvC.base.resolve('/c').toString()],
        );
        final Future<DownloadState> completedFuture = result.controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await result.controller.enqueueCountry(entry);
        await completedFuture;

        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'deu.pmtiles'));
        final Uint8List onDisk = await canonical.readAsBytes();
        expect(onDisk, <int>[...a, ...b, ...c]);
      });
    });
  });

  group('PmtilesDownloadController — resume from staging', () {
    test('path 2: fully-sized chunk on disk → sha256 re-runs, network skipped', () async {
      // Simulates: prior session downloaded chunk A completely; app
      // killed before moving to chunk B. On resume the chunk is
      // already fully sized on disk, so the controller hashes it once
      // (a sized-but-corrupt chunk from a kill-during-sha256 would be
      // caught here) and, on match, proceeds without hitting the wire.
      await _withRealHttpClient(() async {
        final Uint8List a = Uint8List.fromList(List<int>.filled(1024, 0x11));
        final Uint8List b = Uint8List.fromList(List<int>.filled(1024, 0x22));

        final Directory fraStaging = Directory(p.join(tempDir.path, kStagingDir, 'fra'));
        await fraStaging.create(recursive: true);
        await File(p.join(fraStaging.path, 'part00')).writeAsBytes(a);

        final FakeHttpServer srvA = await FakeHttpServer.bind(initialBytes: a);
        final FakeHttpServer srvB = await FakeHttpServer.bind(initialBytes: b);
        addTearDown(() async {
          await srvA.close();
          await srvB.close();
        });

        final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
        final _Harness result = await makeController(httpDownloader: httpDownloader);
        final PmtilesDownloadController controller = result.controller;

        final List<DownloadState> states = <DownloadState>[];
        final StreamSubscription<DownloadState> sub = controller.stateStream.listen(states.add);
        addTearDown(sub.cancel);

        final CountryEntry entry = _entryFor(
          alpha3Raw: 'fra',
          chunkPayloads: <Uint8List>[a, b],
          chunkUrls: <String>[srvA.base.resolve('/a').toString(), srvB.base.resolve('/b').toString()],
        );

        final Future<DownloadState> completedFuture = controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await controller.enqueueCountry(entry);
        await completedFuture;

        expect(srvA.recordedRequests, isEmpty, reason: 'fully-sized local chunk should not be re-downloaded');

        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(await canonical.readAsBytes(), <int>[...a, ...b]);

        // verifyingChunk phase must have fired for partIndex=0 —
        // path 2 always hashes the pre-existing bytes before accepting
        // them, so a corrupt/incompletely-verified chunk is caught.
        final List<DownloadInProgress> verifyingForPart0 = states
            .whereType<DownloadInProgress>()
            .where((DownloadInProgress s) => s.phase == DownloadPhase.verifyingChunk && s.progress.currentPartIndex == 0)
            .toList();
        expect(verifyingForPart0, isNotEmpty, reason: 'pre-existing chunk must be hashed on resume');
      });
    });

    test('path 3: partial chunk on disk → HTTP Range resume finishes, then sha256', () async {
      // Simulates: prior session was downloading chunk A and got
      // killed halfway through. On resume the controller sees
      // localSize < part.size, sends `Range: bytes=localSize-` to the
      // CDN, appends the remaining bytes, and verifies the combined
      // full chunk.
      await _withRealHttpClient(() async {
        final Uint8List a = Uint8List.fromList(List<int>.filled(1024, 0x11));
        final Uint8List b = Uint8List.fromList(List<int>.filled(1024, 0x22));

        final Directory fraStaging = Directory(p.join(tempDir.path, kStagingDir, 'fra'));
        await fraStaging.create(recursive: true);
        await File(p.join(fraStaging.path, 'part00')).writeAsBytes(a.sublist(0, 400));

        final FakeHttpServer srvA = await FakeHttpServer.bind(initialBytes: a);
        final FakeHttpServer srvB = await FakeHttpServer.bind(initialBytes: b);
        addTearDown(() async {
          await srvA.close();
          await srvB.close();
        });

        final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
        final _Harness result = await makeController(httpDownloader: httpDownloader);
        final PmtilesDownloadController controller = result.controller;

        final CountryEntry entry = _entryFor(
          alpha3Raw: 'fra',
          chunkPayloads: <Uint8List>[a, b],
          chunkUrls: <String>[srvA.base.resolve('/a').toString(), srvB.base.resolve('/b').toString()],
        );

        final Future<DownloadState> completedFuture = controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await controller.enqueueCountry(entry);
        await completedFuture;

        // srvA was hit with a Range-resume request for the remaining
        // bytes — not a fresh download.
        expect(srvA.recordedRequests.map((r) => r.rangeHeader).toList(), <String?>['bytes=400-']);

        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(await canonical.readAsBytes(), <int>[...a, ...b]);
      });
    });

    test('frontier invariant: pre-frontier fully-sized chunks are trusted (no sha256)', () async {
      // Protocol invariant: the prior session would not have moved on
      // to chunk N+1 without successfully verifying chunk N. So when
      // the staging dir shows chunks 0..K fully sized + chunk K+1
      // partial, chunks 0..K are trusted (no sha256) and only K+1 is
      // hashed (after its Range-resumed download completes).
      await _withRealHttpClient(() async {
        final Uint8List a = Uint8List.fromList(List<int>.filled(1024, 0x11));
        final Uint8List b = Uint8List.fromList(List<int>.filled(1024, 0x22));
        final Uint8List c = Uint8List.fromList(List<int>.filled(1024, 0x33));
        final Uint8List d = Uint8List.fromList(List<int>.filled(1024, 0x44));

        final Directory fraStaging = Directory(p.join(tempDir.path, kStagingDir, 'fra'));
        await fraStaging.create(recursive: true);
        // chunks 0, 1 fully sized; chunk 2 partial; chunk 3 missing.
        await File(p.join(fraStaging.path, 'part00')).writeAsBytes(a);
        await File(p.join(fraStaging.path, 'part01')).writeAsBytes(b);
        await File(p.join(fraStaging.path, 'part02')).writeAsBytes(c.sublist(0, 500));

        final FakeHttpServer srvA = await FakeHttpServer.bind(initialBytes: a);
        final FakeHttpServer srvB = await FakeHttpServer.bind(initialBytes: b);
        final FakeHttpServer srvC = await FakeHttpServer.bind(initialBytes: c);
        final FakeHttpServer srvD = await FakeHttpServer.bind(initialBytes: d);
        addTearDown(() async {
          await srvA.close();
          await srvB.close();
          await srvC.close();
          await srvD.close();
        });

        final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
        final _Harness result = await makeController(httpDownloader: httpDownloader);
        final PmtilesDownloadController controller = result.controller;

        final List<DownloadState> states = <DownloadState>[];
        final StreamSubscription<DownloadState> sub = controller.stateStream.listen(states.add);
        addTearDown(sub.cancel);

        final CountryEntry entry = _entryFor(
          alpha3Raw: 'fra',
          chunkPayloads: <Uint8List>[a, b, c, d],
          chunkUrls: <String>[
            srvA.base.resolve('/a').toString(),
            srvB.base.resolve('/b').toString(),
            srvC.base.resolve('/c').toString(),
            srvD.base.resolve('/d').toString(),
          ],
        );

        final Future<DownloadState> completedFuture = controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await controller.enqueueCountry(entry);
        await completedFuture;

        expect(srvA.recordedRequests, isEmpty, reason: 'pre-frontier chunk 0 is trusted (no request)');
        expect(srvB.recordedRequests, isEmpty, reason: 'pre-frontier chunk 1 is trusted (no request)');
        expect(srvC.recordedRequests.map((r) => r.rangeHeader).toList(), <String?>['bytes=500-'], reason: 'frontier chunk 2 is Range-resumed');
        expect(srvD.recordedRequests.single.rangeHeader, isNull, reason: 'post-frontier chunk 3 is fresh-downloaded');

        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(await canonical.readAsBytes(), <int>[...a, ...b, ...c, ...d]);

        // verifyingChunk phase must NOT have fired for partIndex 0 or
        // 1 (trusted); it must have fired for 2 (frontier, Range-resumed)
        // and 3 (post-frontier, fresh).
        final Set<int> verifiedIndices = states
            .whereType<DownloadInProgress>()
            .where((DownloadInProgress s) => s.phase == DownloadPhase.verifyingChunk)
            .map((DownloadInProgress s) => s.progress.currentPartIndex)
            .toSet();
        expect(verifiedIndices.contains(0), isFalse, reason: 'pre-frontier chunks are not sha256-checked');
        expect(verifiedIndices.contains(1), isFalse, reason: 'pre-frontier chunks are not sha256-checked');
        expect(verifiedIndices, containsAll(<int>{2, 3}));
      });
    });

    test('path 2 sha256 mismatch → chunk is redownloaded from scratch', () async {
      // Simulates: prior session wrote a fully-sized chunk but the
      // bytes are corrupt (e.g. kill during a flush, cosmic ray). On
      // resume path 2 hashes, detects mismatch, deletes the chunk,
      // and restarts via path 1 (from scratch).
      await _withRealHttpClient(() async {
        final Uint8List a = Uint8List.fromList(List<int>.filled(1024, 0x11));
        final Uint8List corruptA = Uint8List.fromList(List<int>.filled(1024, 0xAA));
        final Uint8List b = Uint8List.fromList(List<int>.filled(1024, 0x22));

        final Directory fraStaging = Directory(p.join(tempDir.path, kStagingDir, 'fra'));
        await fraStaging.create(recursive: true);
        await File(p.join(fraStaging.path, 'part00')).writeAsBytes(corruptA);

        final FakeHttpServer srvA = await FakeHttpServer.bind(initialBytes: a);
        final FakeHttpServer srvB = await FakeHttpServer.bind(initialBytes: b);
        addTearDown(() async {
          await srvA.close();
          await srvB.close();
        });

        final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
        final _Harness result = await makeController(httpDownloader: httpDownloader);
        final PmtilesDownloadController controller = result.controller;

        final CountryEntry entry = _entryFor(
          alpha3Raw: 'fra',
          chunkPayloads: <Uint8List>[a, b],
          chunkUrls: <String>[srvA.base.resolve('/a').toString(), srvB.base.resolve('/b').toString()],
        );

        final Future<DownloadState> completedFuture = controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await controller.enqueueCountry(entry);
        await completedFuture;

        // After the mismatch the chunk is deleted and a fresh GET hits
        // the server (no Range header — full download from byte 0).
        expect(srvA.recordedRequests, isNotEmpty);
        expect(srvA.recordedRequests.first.rangeHeader, isNull, reason: 'from-scratch download uses no Range header');

        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(await canonical.readAsBytes(), <int>[...a, ...b]);
      });
    });
  });

  group('PmtilesDownloadController — mid-chunk progress emission', () {
    test('emits multiple DownloadInProgress events while a single chunk streams', () async {
      // Regression guard for the UX bug: before this fix, progress only
      // ticked at chunk boundaries — on France (split into ~4 parts)
      // the user saw the percent jump 0 → 23 % → 46 % with long pauses
      // between. The 250 ms throttle + onProgress re-emit should now
      // surface ~4 updates/s during the chunk body. This test uses a
      // ServeChunkedSlowly behaviour to feed 4 segments over 600 ms
      // real time → >=2 mid-chunk emits are expected in addition to
      // the start-of-chunk emit.
      await _withRealHttpClient(() async {
        // 4 × 2 KB segments = 8 KB total. The segment count + interval
        // must exceed kDownloadProgressEmitThrottleMs for the throttle
        // window to open at least twice during the chunk body.
        final List<Uint8List> segments = List<Uint8List>.generate(4, (i) => Uint8List.fromList(List<int>.filled(2048, 0x10 + i)));
        final Uint8List fullPayload = Uint8List.fromList(segments.expand((s) => s).toList());

        final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: fullPayload);
        server.behaviour = ServeChunkedSlowly(segments: segments, interval: const Duration(milliseconds: 200));
        addTearDown(server.close);

        final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
        final _Harness result = await makeController(httpDownloader: httpDownloader);

        final List<DownloadInProgress> progressEvents = <DownloadInProgress>[];
        final StreamSubscription<DownloadState> sub = result.controller.stateStream.listen((DownloadState state) {
          if (state is DownloadInProgress) progressEvents.add(state);
        });
        addTearDown(sub.cancel);

        final CountryEntry entry = _entryFor(
          alpha3Raw: 'fra',
          chunkPayloads: <Uint8List>[fullPayload],
          chunkUrls: <String>[server.base.resolve('/fra/part01').toString()],
        );
        final Future<DownloadState> completedFuture = result.controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await result.controller.enqueueCountry(entry);
        await completedFuture;

        // With a 600 ms chunk body + 250 ms throttle, we should see the
        // initial start-of-chunk emit at t=0 plus at least one throttled
        // re-emit from onProgress. Two emits total is the absolute floor.
        expect(progressEvents.length, greaterThanOrEqualTo(2), reason: 'Progress should tick at least twice during a 600 ms slow-streamed chunk');

        // At least one of the mid-chunk emits must surface non-zero
        // bytesDownloaded — proves the _accumulatedBytes counter is
        // reflected in the emitted state, not just the initial zero.
        expect(
          progressEvents.any((DownloadInProgress e) => e.progress.bytesDownloaded > 0),
          isTrue,
          reason: 'At least one emit must report non-zero bytesDownloaded',
        );
      });
    });
  });

  group('PmtilesDownloadController — preflight', () {
    test('insufficient disk space emits DownloadError(DiskSpaceInsufficient)', () async {
      // Preflight runs before any HTTP call, so this test does not
      // need the real HttpClient zone.
      final Uint8List chunk = Uint8List.fromList(List<int>.filled(1024, 0x55));
      final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: chunk);
      addTearDown(server.close);

      final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
      final _Harness result = await makeController(httpDownloader: httpDownloader, freeBytes: 100);

      final CountryEntry entry = _entryFor(alpha3Raw: 'fra', chunkPayloads: <Uint8List>[chunk], chunkUrls: <String>[server.base.resolve('/fra').toString()]);
      final Future<DownloadState> errFuture = result.controller.stateStream.firstWhere((DownloadState s) => s is DownloadError);
      await result.controller.enqueueCountry(entry);

      final DownloadError err = await errFuture as DownloadError;
      expect(err.cause.toString(), contains('DiskSpaceInsufficient'));
    });
  });
}

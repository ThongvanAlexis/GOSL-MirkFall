// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/downloads/download_errors.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/installed_maps/installed_manifest.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:mirkfall/infrastructure/downloads/atomic_renamer.dart';
import 'package:mirkfall/infrastructure/downloads/binary_concatenator.dart';
import 'package:mirkfall/infrastructure/downloads/download_queue_store.dart';
import 'package:mirkfall/infrastructure/downloads/http_chunk_downloader.dart';
import 'package:mirkfall/infrastructure/downloads/pmtiles_download_controller.dart';
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

  group('PmtilesDownloadController — duplicate enqueue guard', () {
    test('enqueueCountry on an alpha3 already in the queue is a no-op', () async {
      await _withRealHttpClient(() async {
        final Uint8List a = Uint8List.fromList(List<int>.filled(1024, 0x11));
        final FakeHttpServer srvA = await FakeHttpServer.bind(initialBytes: a);
        addTearDown(srvA.close);

        final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
        final _Harness result = await makeController(httpDownloader: httpDownloader);
        final PmtilesDownloadController controller = result.controller;

        // Pre-seed the persisted queue via rehydrate() to simulate the
        // "prior-session job was persisted" scenario (this is what the
        // device-walk bug did: a persisted fra job + a user-tapped fra
        // enqueue caused a post-completion re-download from scratch).
        final CountryEntry entry = _entryFor(alpha3Raw: 'fra', chunkPayloads: <Uint8List>[a], chunkUrls: <String>[srvA.base.resolve('/a').toString()]);
        final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
        await store.save(<DownloadJob>[DownloadJob(alpha3: entry.alpha3, entry: entry, enqueuedAtUtc: DateTime.utc(2026, 4, 23))]);

        final Future<DownloadState> completedFuture = controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);

        // Rehydrate loads the persisted job + starts processing. The
        // user-level "Télécharger" tap lands as a second enqueueCountry
        // call. Without the dedup guard, this would append a second fra
        // job — the download would complete once, then restart from
        // scratch (staging wiped by post-commit cleanup).
        await controller.rehydrate();
        await controller.enqueueCountry(entry);

        await completedFuture;

        // Single pass over the wire — the second enqueue was dropped.
        expect(srvA.recordedRequests.length, 1, reason: 'duplicate enqueue must not trigger a second download pass');
        expect(controller.queuedJobs, isEmpty, reason: 'queue drained to empty after the single job completes');
      });
    });
  });

  group('PmtilesDownloadController — resume from staging', () {
    test('fully-sized chunks on disk are trusted (no per-chunk sha256, no network)', () async {
      // Simulates: prior session downloaded chunks A and B completely;
      // app killed before starting chunk C. On resume the fully-sized
      // chunks are trusted as-is — no per-chunk sha256 runs, and the
      // two corresponding CDN endpoints are never hit. Correctness is
      // guaranteed by the reassembled sha256 that `concat` streams
      // inline during the finalize step.
      await _withRealHttpClient(() async {
        final Uint8List a = Uint8List.fromList(List<int>.filled(1024, 0x11));
        final Uint8List b = Uint8List.fromList(List<int>.filled(1024, 0x22));
        final Uint8List c = Uint8List.fromList(List<int>.filled(1024, 0x33));

        final Directory fraStaging = Directory(p.join(tempDir.path, kStagingDir, 'fra'));
        await fraStaging.create(recursive: true);
        await File(p.join(fraStaging.path, 'part00')).writeAsBytes(a);
        await File(p.join(fraStaging.path, 'part01')).writeAsBytes(b);

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
        final PmtilesDownloadController controller = result.controller;

        final CountryEntry entry = _entryFor(
          alpha3Raw: 'fra',
          chunkPayloads: <Uint8List>[a, b, c],
          chunkUrls: <String>[srvA.base.resolve('/a').toString(), srvB.base.resolve('/b').toString(), srvC.base.resolve('/c').toString()],
        );

        final Future<DownloadState> completedFuture = controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await controller.enqueueCountry(entry);
        await completedFuture;

        expect(srvA.recordedRequests, isEmpty, reason: 'trusted pre-existing chunk should not be re-downloaded');
        expect(srvB.recordedRequests, isEmpty, reason: 'trusted pre-existing chunk should not be re-downloaded');
        expect(srvC.recordedRequests.single.rangeHeader, isNull, reason: 'fresh chunk uses no Range header');

        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(await canonical.readAsBytes(), <int>[...a, ...b, ...c]);
      });
    });

    test('partial chunk on disk → HTTP Range resume finishes the chunk', () async {
      // Simulates: prior session was downloading chunk A and got killed
      // halfway through. On resume the controller sees localSize <
      // part.size, sends `Range: bytes=localSize-` to the CDN, appends
      // the remaining bytes; the final reassembled sha256 validates
      // the full file.
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

        expect(srvA.recordedRequests.map((r) => r.rangeHeader).toList(), <String?>['bytes=400-']);

        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(await canonical.readAsBytes(), <int>[...a, ...b]);
      });
    });

    test('corrupt pre-existing chunk: reassembled sha256 catches it → DownloadError', () async {
      // Simulates: prior session wrote chunk 0 but the bytes are
      // corrupt (kill during flush, cosmic ray, manual tampering,
      // whatever). The new model does NOT sha256 pre-existing chunks
      // individually — it trusts them on size alone and relies on the
      // single reassembled-file sha256 (streamed during concat) as
      // the correctness gate. So we expect the download to complete
      // all acquisitions, concat the (corrupt) bytes, detect the
      // reassembled-hash mismatch, and emit DownloadError.
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

        final Future<DownloadState> errorFuture = controller.stateStream.firstWhere((DownloadState s) => s is DownloadError);
        await controller.enqueueCountry(entry);
        final DownloadError err = await errorFuture as DownloadError;
        expect(err.cause, isA<Sha256MismatchException>());
        expect(srvA.recordedRequests, isEmpty, reason: 'corrupt pre-existing chunk is trusted at acquisition; only the reassembled hash catches it');

        // Canonical file must NOT be committed on mismatch.
        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(canonical.existsSync(), isFalse);
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

  group('PmtilesDownloadController — pause/resume (row #1 Blocker regression)', () {
    test('pause() breaks the processing loop, not busy-spin; resume() finishes the download', () async {
      // Plan 08-05 row #1 Blocker regression. Pre-fix behaviour: when
      // [_processJob] emitted DownloadPaused + returned, the outer
      // `while (_queue.isNotEmpty)` loop in [_processQueue] re-invoked
      // _processJob on the same paused job, re-emitted DownloadPaused,
      // and tight-spun until resume() flipped [_pauseRequested]. Fix
      // adds `if (_pauseRequested) break;` after the _processJob call;
      // this test proves the loop exits cleanly (bounded number of
      // DownloadPaused emits) and resume() restarts + completes.
      await _withRealHttpClient(() async {
        final Uint8List a = Uint8List.fromList(List<int>.filled(1024, 0x11));
        final Uint8List b = Uint8List.fromList(List<int>.filled(1024, 0x22));
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

        // Pause BEFORE any processing starts. The queue is rehydrated-
        // via-save so the first iteration of _processQueue sees
        // _pauseRequested=true at the first check inside _processJob.
        final DownloadQueueStore store = DownloadQueueStore(appSupportDir: tempDir.path);
        await store.save(<DownloadJob>[DownloadJob(alpha3: entry.alpha3, entry: entry, enqueuedAtUtc: DateTime.utc(2026, 4, 23))]);
        await controller.pause();
        await controller.rehydrate();

        // Wait for a DownloadPaused emit + let the loop breathe for a
        // window that would contain THOUSANDS of busy-spin iterations
        // if the bug still existed.
        await controller.stateStream.firstWhere((DownloadState s) => s is DownloadPaused);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final int pausedEmits = states.whereType<DownloadPaused>().length;
        expect(pausedEmits, lessThanOrEqualTo(2), reason: 'paused emits should be bounded (not busy-spin); observed $pausedEmits');

        // Resume → download should complete.
        final Future<DownloadState> completedFuture = controller.stateStream.firstWhere((DownloadState s) => s is DownloadCompleted);
        await controller.resume();
        await completedFuture;

        final File canonical = File(p.join(tempDir.path, kCountriesDir, 'fra.pmtiles'));
        expect(canonical.existsSync(), isTrue);
        expect(await canonical.readAsBytes(), <int>[...a, ...b]);
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

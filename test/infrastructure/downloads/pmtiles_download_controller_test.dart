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

CountryEntry _entryFor({
  required String alpha3Raw,
  required List<Uint8List> chunkPayloads,
  required List<String> chunkUrls,
}) {
  final List<ChunkPart> parts = <ChunkPart>[];
  for (int i = 0; i < chunkPayloads.length; i++) {
    parts.add(ChunkPart(
      sha256: sha256.convert(chunkPayloads[i]).toString(),
      size: chunkPayloads[i].length,
      url: chunkUrls[i],
    ));
  }
  final Uint8List reassembled = Uint8List.fromList(chunkPayloads.expand((Uint8List b) => b).toList());
  return CountryEntry(
    alpha3: CountryCode.parse(alpha3Raw),
    name: alpha3Raw.toUpperCase(),
    parts: parts,
    reassembled: ReassembledMeta(
      sha256: sha256.convert(reassembled).toString(),
      size: reassembled.length,
    ),
  );
}

typedef _Harness = ({
  PmtilesDownloadController controller,
  FakeInstalledManifestRepository manifestRepo,
  _FakeIosBackupExcluder excluder,
});

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

  Future<_Harness> makeController({
    required HttpChunkDownloader httpDownloader,
    int freeBytes = 100_000_000,
  }) async {
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
          chunkUrls: <String>[
            srvA.base.resolve('/a').toString(),
            srvB.base.resolve('/b').toString(),
            srvC.base.resolve('/c').toString(),
          ],
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

  group('PmtilesDownloadController — preflight', () {
    test('insufficient disk space emits DownloadError(DiskSpaceInsufficient)', () async {
      // Preflight runs before any HTTP call, so this test does not
      // need the real HttpClient zone.
      final Uint8List chunk = Uint8List.fromList(List<int>.filled(1024, 0x55));
      final FakeHttpServer server = await FakeHttpServer.bind(initialBytes: chunk);
      addTearDown(server.close);

      final HttpChunkDownloader httpDownloader = HttpChunkDownloader();
      final _Harness result = await makeController(httpDownloader: httpDownloader, freeBytes: 100);

      final CountryEntry entry = _entryFor(
        alpha3Raw: 'fra',
        chunkPayloads: <Uint8List>[chunk],
        chunkUrls: <String>[server.base.resolve('/fra').toString()],
      );
      final Future<DownloadState> errFuture = result.controller.stateStream.firstWhere((DownloadState s) => s is DownloadError);
      await result.controller.enqueueCountry(entry);

      final DownloadError err = await errFuture as DownloadError;
      expect(err.cause.toString(), contains('DiskSpaceInsufficient'));
    });
  });
}

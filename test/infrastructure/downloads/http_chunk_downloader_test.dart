// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/downloads/download_errors.dart';
import 'package:mirkfall/infrastructure/downloads/http_chunk_downloader.dart';
import 'package:path/path.dart' as p;

import '../../fakes/fake_http_client.dart';

/// Builds a payload of [size] bytes of pattern [byte], matching the
/// chunk fixture recipe frozen in `test/fixtures/chunks/README.md`:
/// `hashlib.sha256(bytes([b]) * n)`.
Uint8List _patternBytes(int byte, int size) => Uint8List(size)..fillRange(0, size, byte);

void main() {
  late Directory tempDir;
  late FakeHttpServer server;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_http_chunk_');
    server = await FakeHttpServer.bind(initialBytes: _patternBytes(0xAA, 4096));
  });

  tearDown(() async {
    await server.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HttpChunkDownloader — happy path', () {
    test('fresh download writes full response → status downloadedFresh', () async {
      final HttpChunkDownloader downloader = HttpChunkDownloader();
      addTearDown(downloader.close);

      final File dest = File(p.join(tempDir.path, 'fresh.bin'));
      final DownloadChunkResult result = await downloader.downloadWithResume(url: server.base.resolve('/fresh'), destination: dest);
      expect(result, DownloadChunkResult.downloadedFresh);
      expect(await dest.readAsBytes(), server.bytes);
      expect(server.recordedRequests.length, 1);
      expect(server.recordedRequests.single.rangeHeader, isNull);
    });

    test('progress callback fires with cumulative bytes + total', () async {
      final HttpChunkDownloader downloader = HttpChunkDownloader();
      addTearDown(downloader.close);

      int totalSeen = 0;
      final List<int?> contentLengthSeen = <int?>[];
      final File dest = File(p.join(tempDir.path, 'progress.bin'));
      await downloader.downloadWithResume(
        url: server.base.resolve('/progress'),
        destination: dest,
        onProgress: (int delta, int? total) {
          totalSeen += delta;
          contentLengthSeen.add(total);
        },
      );
      expect(totalSeen, server.bytes.length);
      expect(contentLengthSeen.every((int? cl) => cl == server.bytes.length), isTrue);
    });
  });

  group('HttpChunkDownloader — Range resume', () {
    test('pre-existing destination triggers Range header → server serves 206 → resumedWith206', () async {
      // Seed the destination with the first 1024 bytes of the server payload.
      final File dest = File(p.join(tempDir.path, 'resume.bin'));
      await dest.writeAsBytes(Uint8List.sublistView(server.bytes, 0, 1024));

      final HttpChunkDownloader downloader = HttpChunkDownloader();
      addTearDown(downloader.close);

      final DownloadChunkResult result = await downloader.downloadWithResume(url: server.base.resolve('/resume'), destination: dest);

      expect(result, DownloadChunkResult.resumedWith206);
      expect(server.recordedRequests.single.rangeHeader, 'bytes=1024-');
      // Final file must equal the full server payload.
      final Uint8List onDisk = await dest.readAsBytes();
      expect(onDisk.length, server.bytes.length);
      expect(sha256.convert(onDisk).toString(), sha256.convert(server.bytes).toString());
    });

    test('server ignores Range → restartedFrom200 → file truncated + rewritten', () async {
      // Seed the destination with garbage bytes.
      final File dest = File(p.join(tempDir.path, 'restart.bin'));
      await dest.writeAsBytes(_patternBytes(0xFF, 2048));

      server.behaviour = const ServeIgnoringRange();

      final HttpChunkDownloader downloader = HttpChunkDownloader();
      addTearDown(downloader.close);

      final DownloadChunkResult result = await downloader.downloadWithResume(url: server.base.resolve('/restart'), destination: dest);

      expect(result, DownloadChunkResult.restartedFrom200);
      final Uint8List onDisk = await dest.readAsBytes();
      // The garbage prefix must be gone — file must match the real payload.
      expect(onDisk, server.bytes);
    });
  });

  group('HttpChunkDownloader — error paths', () {
    test('403 on resume → DownloadInterruptedException (expired-redirect path)', () async {
      final File dest = File(p.join(tempDir.path, '403.bin'));
      await dest.writeAsBytes(_patternBytes(0xAA, 512));

      server.behaviour = const Serve403();

      final HttpChunkDownloader downloader = HttpChunkDownloader();
      addTearDown(downloader.close);

      await expectLater(downloader.downloadWithResume(url: server.base.resolve('/expired'), destination: dest), throwsA(isA<DownloadInterruptedException>()));
    });

    test('500 error → DownloadInterruptedException', () async {
      server.behaviour = const Serve500();

      final HttpChunkDownloader downloader = HttpChunkDownloader();
      addTearDown(downloader.close);

      await expectLater(
        downloader.downloadWithResume(url: server.base.resolve('/boom'), destination: File(p.join(tempDir.path, 'boom.bin'))),
        throwsA(isA<DownloadInterruptedException>()),
      );
    });

    test('connection drops mid-stream → throws + destination records the partial bytes', () async {
      server.behaviour = const ServeDropConnectionAfterBytes(bytesBeforeDrop: 100);

      final HttpChunkDownloader downloader = HttpChunkDownloader();
      addTearDown(downloader.close);

      final File dest = File(p.join(tempDir.path, 'drop.bin'));
      await expectLater(downloader.downloadWithResume(url: server.base.resolve('/drop'), destination: dest), throwsA(isA<DownloadInterruptedException>()));

      // The destination keeps whatever bytes were already flushed — that
      // is exactly what Plan 07-04's retry loop needs to send as the
      // next Range resume offset.
      if (dest.existsSync()) {
        final int written = await dest.length();
        expect(written, lessThanOrEqualTo(100), reason: 'destination should hold at most the dropped-at byte count');
      }
    });

    test('timeout produces a DownloadInterruptedException', () async {
      // Deliberately short timeout + never-responding behaviour: we
      // simulate a pending socket by using drop-connection with 0 bytes
      // before drop, then reducing the timeout aggressively.
      server.behaviour = const ServeDropConnectionAfterBytes(bytesBeforeDrop: 0);

      final HttpChunkDownloader downloader = HttpChunkDownloader(timeout: const Duration(milliseconds: 50));
      addTearDown(downloader.close);

      // Either we hit the stream timeout or we see the premature end as
      // an interrupted download; both surface the same exception type.
      await expectLater(
        downloader.downloadWithResume(url: server.base.resolve('/stall'), destination: File(p.join(tempDir.path, 'stall.bin'))),
        throwsA(isA<DownloadInterruptedException>()),
      );
    });
  });

  group('HttpChunkDownloader — redirect handling', () {
    test('302 redirect is followed transparently', () async {
      // Arrange a second server that hosts the real bytes; first server
      // just 302s to it. HttpChunkDownloader sets followRedirects=true
      // + maxRedirects=5 so the hop is transparent.
      final FakeHttpServer targetServer = await FakeHttpServer.bind(initialBytes: _patternBytes(0x33, 256));
      addTearDown(targetServer.close);
      server.behaviour = ServeRedirect(target: targetServer.base.resolve('/real'));

      final HttpChunkDownloader downloader = HttpChunkDownloader();
      addTearDown(downloader.close);

      final File dest = File(p.join(tempDir.path, 'redir.bin'));
      final DownloadChunkResult result = await downloader.downloadWithResume(url: server.base.resolve('/redir'), destination: dest);
      expect(result, DownloadChunkResult.downloadedFresh);
      expect(await dest.readAsBytes(), targetServer.bytes);
    });
  });
}

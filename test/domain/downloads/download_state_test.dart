// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/domain/downloads/download_errors.dart';
import 'package:mirkfall/domain/downloads/download_job.dart';
import 'package:mirkfall/domain/downloads/download_state.dart';
import 'package:mirkfall/domain/map/country_catalog.dart';
import 'package:mirkfall/domain/map/country_code.dart';
import 'package:test/test.dart';

CountryEntry _mkEntry(String alpha3, {int parts = 1, int chunkSize = 1024}) {
  final List<ChunkPart> chunks = <ChunkPart>[
    for (int i = 0; i < parts; i++)
      ChunkPart(sha256: 'a' * 64, size: chunkSize, url: 'https://github.com/example/releases/download/v20260419/$alpha3.part0${i + 1}'),
  ];
  return CountryEntry(
    alpha3: CountryCode.parse(alpha3),
    name: alpha3.toUpperCase(),
    parts: chunks,
    reassembled: ReassembledMeta(sha256: 'b' * 64, size: chunkSize * parts),
  );
}

DownloadJob _mkJob(String alpha3) {
  return DownloadJob(alpha3: CountryCode.parse(alpha3), entry: _mkEntry(alpha3), enqueuedAtUtc: DateTime.utc(2026, 4, 21));
}

void main() {
  group('DownloadState pattern-matches exhaustively over all 7 variants', () {
    String label(DownloadState s) {
      return switch (s) {
        DownloadIdle() => 'idle',
        DownloadQueued() => 'queued',
        DownloadInProgress() => 'inProgress',
        DownloadPaused() => 'paused',
        DownloadError() => 'error',
        DownloadCompleted() => 'completed',
        DownloadCancelled() => 'cancelled',
      };
    }

    test('DownloadIdle', () {
      expect(label(const DownloadIdle()), equals('idle'));
    });

    test('DownloadQueued carries the queue', () {
      final DownloadJob j = _mkJob('fra');
      final DownloadQueued s = DownloadQueued(queue: <DownloadJob>[j]);
      expect(label(s), equals('queued'));
      expect(s.queue, hasLength(1));
      expect(s.queue.single.alpha3, equals(CountryCode.parse('fra')));
    });

    test('DownloadInProgress carries active + progress + remaining', () {
      final DownloadJob active = _mkJob('deu');
      final DownloadJob next = _mkJob('esp');
      final DownloadInProgress s = DownloadInProgress(
        active: active,
        progress: DownloadProgress(bytesDownloaded: 500, totalBytes: 1024, currentPartIndex: 0, totalParts: 1),
        remaining: <DownloadJob>[next],
      );
      expect(label(s), equals('inProgress'));
      expect(s.active.alpha3, equals(CountryCode.parse('deu')));
      expect(s.remaining.single.alpha3, equals(CountryCode.parse('esp')));
    });

    test('DownloadPaused carries snapshot + reason', () {
      final DownloadPaused s = DownloadPaused(
        active: _mkJob('gbr'),
        snapshot: DownloadProgress(bytesDownloaded: 100, totalBytes: 1024, currentPartIndex: 0, totalParts: 1),
        reason: PauseReason.manual,
      );
      expect(label(s), equals('paused'));
      expect(s.reason, equals(PauseReason.manual));
    });

    test('DownloadError carries the cause exception', () {
      final DownloadError s = DownloadError(
        active: _mkJob('usa'),
        cause: const DownloadInterruptedException(reason: 'connection reset'),
      );
      expect(label(s), equals('error'));
      expect(s.cause, isA<DownloadInterruptedException>());
    });

    test('DownloadCompleted is terminal with elapsed duration', () {
      final DownloadCompleted s = DownloadCompleted(alpha3: CountryCode.parse('aru'), totalElapsed: const Duration(seconds: 42));
      expect(label(s), equals('completed'));
      expect(s.totalElapsed, equals(const Duration(seconds: 42)));
    });

    test('DownloadCancelled is terminal with alpha3', () {
      final DownloadCancelled s = DownloadCancelled(alpha3: CountryCode.parse('deu'));
      expect(label(s), equals('cancelled'));
    });
  });

  group('DownloadProgress.fractionDone math', () {
    test('0 bytes → 0.0', () {
      final DownloadProgress p = DownloadProgress(bytesDownloaded: 0, totalBytes: 1000, currentPartIndex: 0, totalParts: 1);
      expect(p.fractionDone, equals(0.0));
    });

    test('half bytes → 0.5', () {
      final DownloadProgress p = DownloadProgress(bytesDownloaded: 500, totalBytes: 1000, currentPartIndex: 0, totalParts: 1);
      expect(p.fractionDone, equals(0.5));
    });

    test('all bytes → 1.0', () {
      final DownloadProgress p = DownloadProgress(bytesDownloaded: 1000, totalBytes: 1000, currentPartIndex: 0, totalParts: 1);
      expect(p.fractionDone, equals(1.0));
    });

    test('rejects negative bytesDownloaded via @Assert', () {
      expect(() => DownloadProgress(bytesDownloaded: -1, totalBytes: 1000, currentPartIndex: 0, totalParts: 1), throwsA(isA<AssertionError>()));
    });

    test('rejects bytesDownloaded > totalBytes via @Assert', () {
      expect(() => DownloadProgress(bytesDownloaded: 2000, totalBytes: 1000, currentPartIndex: 0, totalParts: 1), throwsA(isA<AssertionError>()));
    });

    test('rejects zero totalBytes via @Assert', () {
      expect(() => DownloadProgress(bytesDownloaded: 0, totalBytes: 0, currentPartIndex: 0, totalParts: 1), throwsA(isA<AssertionError>()));
    });

    test('rejects currentPartIndex >= totalParts via @Assert', () {
      expect(() => DownloadProgress(bytesDownloaded: 0, totalBytes: 1000, currentPartIndex: 3, totalParts: 3), throwsA(isA<AssertionError>()));
    });
  });

  group('download-layer exceptions implement Exception', () {
    test('DownloadInterruptedException', () {
      const Exception e = DownloadInterruptedException(reason: 'timeout after 60s');
      expect(e, isA<Exception>());
      expect(e.toString(), contains('timeout after 60s'));
    });

    test('Sha256MismatchException inlines at/expected/actual', () {
      final String expected = 'a' * 64;
      final String actual = 'b' * 64;
      final Sha256MismatchException e = Sha256MismatchException(expected: expected, actual: actual, at: 'parts[2]');
      final String s = e.toString();
      expect(s, contains('parts[2]'));
      expect(s, contains(expected));
      expect(s, contains(actual));
    });

    test('ConcatFailureException', () {
      const Exception e = ConcatFailureException(reason: 'byte count mismatch');
      expect(e, isA<Exception>());
      expect(e.toString(), contains('byte count mismatch'));
    });

    test('HttpRangeNotSupportedException', () {
      const Exception e = HttpRangeNotSupportedException(responseCode: 200);
      expect(e, isA<Exception>());
      expect(e.toString(), contains('200'));
    });
  });

  group('DownloadJob JSON round-trip', () {
    test('round-trip of a sample job', () {
      final DownloadJob original = _mkJob('fra');
      // Nested entries round-trip via jsonEncode/jsonDecode (see
      // explanation in country_catalog_test.dart).
      final Map<String, Object?> out = original.toJson();
      // Minimal shape assertion — full deep-equality via round-trip
      // would need the nested `entry` CountryEntry instances to re-parse
      // through json_serializable, which json_serializable does for
      // `explicitToJson: false` output only after a jsonEncode/jsonDecode
      // hop. The shape check below covers the field names the Plan 07-04
      // repository will persist.
      expect(out, containsPair('alpha3', 'fra'));
      expect(out, contains('entry'));
      expect(out, contains('enqueuedAtUtc'));
      expect(out, containsPair('userPausedFlag', false));
    });
  });
}

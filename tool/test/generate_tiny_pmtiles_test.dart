// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../generate_tiny_pmtiles.dart' as gen;

/// Fixture-based paired tests for `tool/generate_tiny_pmtiles.dart`
/// (§3 row #16 — Phase 07 tool scripts needed paired tests).
///
/// The script's `runCheck({outputPath})` seam is public so we drive
/// it against a tempdir instead of mutating the real
/// `test/fixtures/pmtiles/tiny.pmtiles` file on every test run.
/// Covers the two documented exit codes (Phase 01 CLI contract):
///   0 — stub written
///   1 — IO failure (unwritable target)
///
/// Plus two sanity checks on the binary shape: PMTiles v3 magic at
/// offset 0 + total size = 1024 bytes. Re-running is idempotent.
void main() {
  group('generate_tiny_pmtiles.runCheck', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('generate_tiny_pmtiles_test_');
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

    test('writes 1024-byte stub with PMTiles v3 magic + zero padding + exit 0', () async {
      final String outputPath = p.join(tempDir.path, 'tiny.pmtiles');
      final int code = await gen.runCheck(outputPath: outputPath);
      expect(code, equals(0));

      final File f = File(outputPath);
      expect(f.existsSync(), isTrue);

      final List<int> bytes = f.readAsBytesSync();
      expect(bytes.length, equals(1024), reason: 'stub must be exactly 1 KB');

      // PMTiles v3 magic: "PMTiles" (7 ASCII) + version byte 0x03.
      // Spec: github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md
      expect(bytes.sublist(0, 8), equals(<int>[0x50, 0x4D, 0x54, 0x69, 0x6C, 0x65, 0x73, 0x03]));

      // Remaining 1016 bytes are zero-padded (Uint8List default init).
      for (int i = 8; i < bytes.length; i++) {
        if (bytes[i] != 0) {
          fail('byte at offset $i is ${bytes[i]}, expected 0 (zero-padding invariant broken)');
        }
      }
    });

    test('is idempotent — running twice produces byte-identical output', () async {
      final String outputPath = p.join(tempDir.path, 'tiny.pmtiles');

      expect(await gen.runCheck(outputPath: outputPath), equals(0));
      final List<int> first = File(outputPath).readAsBytesSync();

      // Second run overwrites in place — same bytes, no accumulation.
      expect(await gen.runCheck(outputPath: outputPath), equals(0));
      final List<int> second = File(outputPath).readAsBytesSync();

      expect(second, equals(first));
    });

    test('creates missing parent directories (recursive mkdir)', () async {
      // Deeply-nested target — the script should create the tree
      // rather than fail. Matches the real script's invocation shape
      // when `test/fixtures/pmtiles/` does not yet exist.
      final String outputPath = p.join(tempDir.path, 'nested', 'subdir', 'tiny.pmtiles');
      final int code = await gen.runCheck(outputPath: outputPath);
      expect(code, equals(0));
      expect(File(outputPath).existsSync(), isTrue);
      expect(File(outputPath).lengthSync(), equals(1024));
    });

    test('returns 1 when target path cannot be created (platform IO failure)', () async {
      // On POSIX, a path whose parent is a regular file cannot be
      // created — `File.parent.createSync(recursive: true)` throws
      // FileSystemException (IOException). On Windows the failure
      // mode differs but the same IOException → exit 1 contract
      // applies.
      final String blockingFile = p.join(tempDir.path, 'not_a_directory');
      File(blockingFile).writeAsStringSync('blocks the mkdir');

      // "not_a_directory/tiny.pmtiles" — parent is a file, not a dir.
      final String outputPath = p.join(blockingFile, 'tiny.pmtiles');
      final int code = await gen.runCheck(outputPath: outputPath);
      expect(code, equals(1), reason: 'IOException path must return exit 1 per Phase 01 contract');
    });
  });
}

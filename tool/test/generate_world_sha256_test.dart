// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../generate_world_sha256.dart' as gen;

/// Fixture-based paired tests for `tool/generate_world_sha256.dart`.
///
/// The script's `runCheck({assetPath, outputPath})` seam is public so
/// we drive it against synthetic PMTiles fixtures in a tempdir instead
/// of the 856 KB production asset. Covers the three documented exit
/// codes (Phase 01 CLI contract):
///   0 — asset read, hash computed, file written
///   1 — write failed (unwritable output path)
///   2 — misconfiguration (asset missing)
///
/// Plus one sanity-check that the emitted file contains the expected
/// `const String kWorldBundleSha256 = '<hex>';` shape + GOSL header.
void main() {
  group('generate_world_sha256.runCheck', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('generate_world_sha256_test_');
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

    test('writes kWorldBundleSha256 const with correct hex digest + exit 0', () async {
      // Deterministic fixture: 32 bytes of 0xAB — sha256 precomputed below.
      final Uint8List bytes = Uint8List.fromList(List<int>.filled(32, 0xAB));
      final String assetPath = p.join(tempDir.path, 'fixture.pmtiles');
      final String outputPath = p.join(tempDir.path, 'out.dart');
      File(assetPath).writeAsBytesSync(bytes);

      final int code = await gen.runCheck(assetPath: assetPath, outputPath: outputPath);
      expect(code, equals(0));

      final String generated = File(outputPath).readAsStringSync();
      final String expectedHex = sha256.convert(bytes).toString();

      expect(generated, contains("const String kWorldBundleSha256 = '$expectedHex';"));
      expect(generated, startsWith('// Copyright (c) 2026 THONGVAN Alexis'));
      expect(generated, contains('// Licensed under the Good Old Software License v1.0'));
      expect(generated, contains("Emitted build-time"));
    });

    test('returns 2 when asset is missing', () async {
      final String missingAssetPath = p.join(tempDir.path, 'nonexistent.pmtiles');
      final String outputPath = p.join(tempDir.path, 'out.dart');

      final int code = await gen.runCheck(assetPath: missingAssetPath, outputPath: outputPath);
      expect(code, equals(2));
      expect(File(outputPath).existsSync(), isFalse, reason: 'should not write output when asset is missing');
    });

    test('returns 1 when output path is unwritable (parent dir does not exist)', () async {
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final String assetPath = p.join(tempDir.path, 'fixture.pmtiles');
      File(assetPath).writeAsBytesSync(bytes);

      // Point at a nested path whose parent directory was never created —
      // `writeAsStringSync` throws `FileSystemException` (IOException).
      final String unwritableOutput = p.join(tempDir.path, 'does', 'not', 'exist', 'out.dart');

      final int code = await gen.runCheck(assetPath: assetPath, outputPath: unwritableOutput);
      expect(code, equals(1));
    });

    test('empty asset is valid input (sha256 of 0 bytes is a well-known constant)', () async {
      // sha256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      const String expectedEmptyHex = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      final String assetPath = p.join(tempDir.path, 'empty.pmtiles');
      final String outputPath = p.join(tempDir.path, 'out.dart');
      File(assetPath).writeAsBytesSync(<int>[]);

      final int code = await gen.runCheck(assetPath: assetPath, outputPath: outputPath);
      expect(code, equals(0));
      expect(File(outputPath).readAsStringSync(), contains("const String kWorldBundleSha256 = '$expectedEmptyHex';"));
    });

    test('rerunning the script is idempotent — output file is overwritten in full', () async {
      final Uint8List firstBytes = Uint8List.fromList(List<int>.filled(16, 0x11));
      final Uint8List secondBytes = Uint8List.fromList(List<int>.filled(16, 0x22));
      final String assetPath = p.join(tempDir.path, 'fixture.pmtiles');
      final String outputPath = p.join(tempDir.path, 'out.dart');

      File(assetPath).writeAsBytesSync(firstBytes);
      expect(await gen.runCheck(assetPath: assetPath, outputPath: outputPath), equals(0));
      final String firstGenerated = File(outputPath).readAsStringSync();
      final String firstHex = sha256.convert(firstBytes).toString();
      expect(firstGenerated, contains(firstHex));

      // Second run with different bytes must fully replace the output —
      // no leftover const declaration from the first run.
      File(assetPath).writeAsBytesSync(secondBytes);
      expect(await gen.runCheck(assetPath: assetPath, outputPath: outputPath), equals(0));
      final String secondGenerated = File(outputPath).readAsStringSync();
      final String secondHex = sha256.convert(secondBytes).toString();
      expect(secondGenerated, contains(secondHex));
      expect(secondGenerated, isNot(contains(firstHex)));
    });
  });
}

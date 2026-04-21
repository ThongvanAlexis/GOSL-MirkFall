// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/downloads/sha256_verifier.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_sha256_verifier_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Sha256Verifier — known vectors', () {
    test('empty file hashes to the canonical zero-length sha256', () async {
      // NIST-published empty-string sha256.
      const String expected = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      final File f = File(p.join(tempDir.path, 'empty.bin'));
      await f.writeAsBytes(<int>[]);

      const Sha256Verifier verifier = Sha256Verifier();
      expect(await verifier.ofFile(f), expected);
    });

    test('small payload matches crypto.sha256.convert reference', () async {
      final Uint8List payload = Uint8List.fromList(<int>[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]);
      final String reference = sha256.convert(payload).toString();

      final File f = File(p.join(tempDir.path, 'tiny.bin'));
      await f.writeAsBytes(payload);

      const Sha256Verifier verifier = Sha256Verifier();
      expect(await verifier.ofFile(f), reference);
    });

    test('single-byte-pattern chunk matches python recipe', () async {
      // Matches the chunk fixture recipe frozen in
      // test/fixtures/chunks/README.md:
      //   hashlib.sha256(bytes([b]) * n).hexdigest()
      // Chosen: 0xAA repeated 4096 bytes. Synthetic enough to stay
      // portable (no Python roundtrip needed on the CI host) while
      // exercising the same shape as the real chunk fixtures.
      final Uint8List payload = Uint8List(4096)..fillRange(0, 4096, 0xAA);
      final String reference = sha256.convert(payload).toString();

      final File f = File(p.join(tempDir.path, 'pattern.bin'));
      await f.writeAsBytes(payload);

      const Sha256Verifier verifier = Sha256Verifier();
      expect(await verifier.ofFile(f), reference);
    });
  });

  group('Sha256Verifier — large file memory safety', () {
    test('8 MB file — streaming reads successfully without heap explosion', () async {
      // 8 MB is large enough to exceed a few filesystem read chunks
      // but small enough to keep the test runtime under 2 seconds.
      // The actual constant-memory guarantee is a property of the
      // `sha256.bind` implementation; this test exercises the happy
      // path at a non-trivial size.
      const int size = 8 * 1024 * 1024;
      final Uint8List payload = Uint8List(size)..fillRange(0, size, 0x5A);

      final File f = File(p.join(tempDir.path, 'large.bin'));
      await f.writeAsBytes(payload);
      final String reference = sha256.convert(payload).toString();

      const Sha256Verifier verifier = Sha256Verifier();
      expect(await verifier.ofFile(f), reference);
    });
  });

  group('Sha256Verifier — error paths', () {
    test('missing file throws FileSystemException', () async {
      final File missing = File(p.join(tempDir.path, 'nope.bin'));
      const Sha256Verifier verifier = Sha256Verifier();
      await expectLater(verifier.ofFile(missing), throwsA(isA<FileSystemException>()));
    });
  });
}

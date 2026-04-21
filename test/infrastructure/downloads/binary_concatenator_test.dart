// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/downloads/download_errors.dart';
import 'package:mirkfall/infrastructure/downloads/binary_concatenator.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_concat_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> writePart(String name, Uint8List bytes) async {
    final File f = File(p.join(tempDir.path, name));
    await f.writeAsBytes(bytes);
    return f;
  }

  group('BinaryConcatenator — happy paths', () {
    test('single-part concat yields identical bytes + hash', () async {
      final Uint8List payload = Uint8List(128)..fillRange(0, 128, 0x11);
      final File part = await writePart('p1.bin', payload);

      final File dest = File(p.join(tempDir.path, 'out1.bin'));
      await const BinaryConcatenator().concat(parts: <File>[part], destination: dest);

      expect(await dest.readAsBytes(), payload);
      expect(sha256.convert(await dest.readAsBytes()).toString(), sha256.convert(payload).toString());
    });

    test('3-part concat matches reference byte-for-byte', () async {
      final Uint8List a = Uint8List(100)..fillRange(0, 100, 0xAA);
      final Uint8List b = Uint8List(200)..fillRange(0, 200, 0xBB);
      final Uint8List c = Uint8List(300)..fillRange(0, 300, 0xCC);

      final File pa = await writePart('a.bin', a);
      final File pb = await writePart('b.bin', b);
      final File pc = await writePart('c.bin', c);

      final File dest = File(p.join(tempDir.path, 'out3.bin'));
      await const BinaryConcatenator().concat(parts: <File>[pa, pb, pc], destination: dest);

      final Uint8List concatenated = Uint8List.fromList(<int>[...a, ...b, ...c]);
      expect(await dest.readAsBytes(), concatenated);
      expect(await dest.length(), 600);
    });

    test('5-part concat with mixed sizes sha256-matches in-memory reference', () async {
      final List<File> parts = <File>[];
      final List<int> expectedBytes = <int>[];
      for (int i = 0; i < 5; i++) {
        final Uint8List bytes = Uint8List(50 + i * 10)..fillRange(0, 50 + i * 10, 0x10 * (i + 1));
        parts.add(await writePart('p$i.bin', bytes));
        expectedBytes.addAll(bytes);
      }

      final File dest = File(p.join(tempDir.path, 'out5.bin'));
      await const BinaryConcatenator().concat(parts: parts, destination: dest);

      expect(await dest.readAsBytes(), expectedBytes);
      expect(sha256.convert(await dest.readAsBytes()).toString(), sha256.convert(expectedBytes).toString());
    });

    test('creates missing parent directory for destination', () async {
      final Uint8List payload = Uint8List(10)..fillRange(0, 10, 0x42);
      final File part = await writePart('p.bin', payload);

      final File dest = File(p.join(tempDir.path, 'nested', 'deep', 'out.bin'));
      expect(dest.parent.existsSync(), isFalse);

      await const BinaryConcatenator().concat(parts: <File>[part], destination: dest);
      expect(dest.existsSync(), isTrue);
      expect(dest.parent.existsSync(), isTrue);
    });
  });

  group('BinaryConcatenator — error paths', () {
    test('empty parts list throws ConcatFailureException', () async {
      final File dest = File(p.join(tempDir.path, 'out_empty.bin'));
      await expectLater(const BinaryConcatenator().concat(parts: const <File>[], destination: dest), throwsA(isA<ConcatFailureException>()));
    });

    test('missing part file throws ConcatFailureException + destination unlinked', () async {
      final Uint8List payload = Uint8List(10)..fillRange(0, 10, 0x55);
      final File ok = await writePart('ok.bin', payload);
      final File missing = File(p.join(tempDir.path, 'ghost.bin'));

      final File dest = File(p.join(tempDir.path, 'out_missing.bin'));
      await expectLater(const BinaryConcatenator().concat(parts: <File>[ok, missing], destination: dest), throwsA(isA<ConcatFailureException>()));
      // Destination did not get partially-written bytes — concat guards
      // against half-writes before the stream opens.
      expect(dest.existsSync(), isFalse);
    });
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/downloads/atomic_renamer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mirkfall_atomic_rename_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AtomicRenamer — happy paths', () {
    test('same-volume rename moves bytes + removes source', () async {
      final File source = File(p.join(tempDir.path, 'source.bin'));
      final Uint8List payload = Uint8List(16)..fillRange(0, 16, 0x7E);
      await source.writeAsBytes(payload);

      final File target = File(p.join(tempDir.path, 'target.bin'));
      await AtomicRenamer().commit(source: source, target: target);

      expect(target.existsSync(), isTrue);
      expect(await target.readAsBytes(), payload);
      expect(source.existsSync(), isFalse);
    });

    test('creates missing parent directory for target', () async {
      final File source = File(p.join(tempDir.path, 'source.bin'));
      await source.writeAsBytes(<int>[1, 2, 3]);

      final File target = File(p.join(tempDir.path, 'nested', 'deep', 'target.bin'));
      expect(target.parent.existsSync(), isFalse);

      await AtomicRenamer().commit(source: source, target: target);

      expect(target.parent.existsSync(), isTrue);
      expect(target.existsSync(), isTrue);
    });

    test('overwrites an existing target file', () async {
      final File source = File(p.join(tempDir.path, 'source.bin'));
      await source.writeAsBytes(<int>[0xAB, 0xCD, 0xEF]);

      final File target = File(p.join(tempDir.path, 'target.bin'));
      await target.writeAsBytes(<int>[0x00, 0x00, 0x00]);

      await AtomicRenamer().commit(source: source, target: target);

      expect(await target.readAsBytes(), <int>[0xAB, 0xCD, 0xEF]);
      expect(source.existsSync(), isFalse);
    });
  });

  group('AtomicRenamer — error paths', () {
    test('missing source throws FileSystemException', () async {
      final File missing = File(p.join(tempDir.path, 'ghost.bin'));
      final File target = File(p.join(tempDir.path, 'target.bin'));

      await expectLater(AtomicRenamer().commit(source: missing, target: target), throwsA(isA<FileSystemException>()));
    });
  });
}

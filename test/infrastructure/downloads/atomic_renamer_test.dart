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

  group('AtomicRenamer — cross-volume EXDEV fallback (row #9 regression)', () {
    // Cross-volume scenarios are a nightmare to stage on the CI runner
    // (needs two mount points). Instead, inject a fake rename primitive
    // that throws with OSError(18) = EXDEV — the production code path
    // then falls through to copy+delete, which IS testable on a single
    // volume. This nails the fallback semantics without requiring a
    // second volume.
    Future<File> rejectWithExdev(File src, String dest) async {
      throw const FileSystemException('simulated cross-volume', 'fake', OSError('EXDEV', 18));
    }

    Future<File> rejectWithWindowsNotSameDevice(File src, String dest) async {
      throw const FileSystemException('simulated cross-volume', 'fake', OSError('ERROR_NOT_SAME_DEVICE', 17));
    }

    test('EXDEV (POSIX errno 18) triggers copy+delete fallback that still delivers the bytes', () async {
      final File source = File(p.join(tempDir.path, 'source.bin'));
      final Uint8List payload = Uint8List.fromList(List<int>.generate(128, (int i) => i % 256));
      await source.writeAsBytes(payload);
      final File target = File(p.join(tempDir.path, 'target.bin'));

      await AtomicRenamer(renamePrimitive: rejectWithExdev).commit(source: source, target: target);

      expect(target.existsSync(), isTrue, reason: 'EXDEV fallback must still land the target');
      expect(await target.readAsBytes(), payload);
      expect(source.existsSync(), isFalse, reason: 'source must be deleted after successful cross-volume copy');
    });

    test('ERROR_NOT_SAME_DEVICE (Windows errno 17) also triggers the fallback', () async {
      final File source = File(p.join(tempDir.path, 'source.bin'));
      await source.writeAsBytes(<int>[0xAA, 0xBB, 0xCC]);
      final File target = File(p.join(tempDir.path, 'target.bin'));

      await AtomicRenamer(renamePrimitive: rejectWithWindowsNotSameDevice).commit(source: source, target: target);

      expect(await target.readAsBytes(), <int>[0xAA, 0xBB, 0xCC]);
      expect(source.existsSync(), isFalse);
    });

    test('non-EXDEV FileSystemException from rename is rethrown verbatim (permission denied etc.)', () async {
      final File source = File(p.join(tempDir.path, 'source.bin'));
      await source.writeAsBytes(<int>[1, 2, 3]);
      final File target = File(p.join(tempDir.path, 'target.bin'));

      Future<File> rejectWithPermissionDenied(File src, String dest) async {
        throw const FileSystemException('permission denied', 'fake', OSError('EACCES', 13));
      }

      await expectLater(AtomicRenamer(renamePrimitive: rejectWithPermissionDenied).commit(source: source, target: target), throwsA(isA<FileSystemException>()));
      expect(source.existsSync(), isTrue, reason: 'source must remain untouched when fallback does not fire');
      expect(target.existsSync(), isFalse, reason: 'target must not be created when rename fails with non-EXDEV error');
    });

    test('mid-copy failure: partial target file is CLEANED UP before rethrow', () async {
      // Simulates the ugly case: rename succeeds in saying "cross-
      // volume, fall through" → copy starts writing target → disk
      // fills up (or source read error, etc.) → copy throws. Without
      // the fix, the caller sees a truncated target file that would
      // poison sha256 verification + manifest write.
      final File source = File(p.join(tempDir.path, 'source.bin'));
      await source.writeAsBytes(<int>[0x11, 0x22, 0x33, 0x44]);
      final File target = File(p.join(tempDir.path, 'target.bin'));

      Future<File> copyThatPartiallyWritesThenFails(File src, String destination) async {
        // Simulate the broken state a real mid-flight failure leaves
        // behind: a truncated target already on disk.
        await File(destination).writeAsBytes(<int>[0x11, 0x22]); // half-written
        throw const FileSystemException('simulated mid-copy failure', 'fake', OSError('ENOSPC', 28));
      }

      await expectLater(
        AtomicRenamer(renamePrimitive: rejectWithExdev, copyPrimitive: copyThatPartiallyWritesThenFails).commit(source: source, target: target),
        throwsA(isA<FileSystemException>()),
      );

      expect(target.existsSync(), isFalse, reason: 'partial target must be removed to leave a clean "nothing happened" state');
      expect(source.existsSync(), isTrue, reason: 'source must survive when fallback fails (caller can retry)');
    });

    test('mid-copy failure with no partial target file: cleanup is a no-op + rethrow unchanged', () async {
      final File source = File(p.join(tempDir.path, 'source.bin'));
      await source.writeAsBytes(<int>[0xFE]);
      final File target = File(p.join(tempDir.path, 'target.bin'));

      Future<File> copyThatFailsBeforeCreatingTarget(File src, String dest) async {
        throw const FileSystemException('simulated source read failure', 'fake', OSError('EIO', 5));
      }

      await expectLater(
        AtomicRenamer(renamePrimitive: rejectWithExdev, copyPrimitive: copyThatFailsBeforeCreatingTarget).commit(source: source, target: target),
        throwsA(isA<FileSystemException>()),
      );

      expect(target.existsSync(), isFalse);
      expect(source.existsSync(), isTrue);
    });
  });
}

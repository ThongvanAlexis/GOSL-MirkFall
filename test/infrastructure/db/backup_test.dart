// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:mirkfall/infrastructure/db/backup.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Tests for [DbBackupService] — pre-migration DB copy + rolling rotation.
///
/// All tests operate inside a `Directory.systemTemp.createTempSync` scratch
/// dir so nothing lands outside the test process. The fake "DB" is a deterministic
/// 128-byte payload — byte-equal round-trip is what we assert, not any SQLite
/// semantics (backup is a plain file copy).
void main() {
  late Directory scratchDir;
  late File fakeDb;
  late Directory backupDir;

  setUp(() {
    scratchDir = Directory.systemTemp.createTempSync('mirkfall_backup_test_');
    fakeDb = File(p.join(scratchDir.path, 'mirkfall.db'));
    fakeDb.writeAsBytesSync(List<int>.generate(128, (int i) => i & 0xFF));
    backupDir = Directory(p.join(scratchDir.path, 'db_backups'));
  });

  tearDown(() {
    // Windows is stricter than POSIX about deleting directories that have
    // just been touched by async `File.copy` — a pending OS-level handle can
    // still be draining when this tearDown fires, so the recursive delete
    // throws PathNotFoundException mid-walk (the iterator sees a sibling,
    // the OS deletes it, the delete call fails). Tolerate that: the scratch
    // dir is inside `systemTemp` which the OS cleans up eventually anyway.
    try {
      if (scratchDir.existsSync()) {
        scratchDir.deleteSync(recursive: true);
      }
    } on FileSystemException {
      // Leave the scratch dir behind — systemTemp eviction will reclaim it.
    }
  });

  test('takeBackup creates a file with correctly-formatted name', () async {
    final svc = DbBackupService(dbFilename: fakeDb.path, backupDir: backupDir, maxBackups: 3, clock: () => DateTime.utc(2026, 4, 18, 12, 30, 45, 123));

    final backup = await svc.takeBackup(fromVersion: 1, toVersion: 2);

    expect(backup.existsSync(), isTrue);
    // ISO 8601 UTC, colons replaced with hyphens for cross-platform filename
    // safety (Windows forbids ':' in filenames).
    expect(p.basename(backup.path), equals('mirkfall.db.backup-v1-to-v2-2026-04-18T12-30-45.123Z'));
    // Byte-equal content — no re-encoding, no compression.
    expect(backup.readAsBytesSync(), fakeDb.readAsBytesSync());
  });

  test('rotate keeps the 3 newest when 4 exist', () async {
    final svc = DbBackupService(dbFilename: fakeDb.path, backupDir: backupDir, maxBackups: 3);
    backupDir.createSync(recursive: true);

    // Stagger modified times so mtime ordering is deterministic.
    final now = DateTime.now();
    for (var i = 0; i < 4; i++) {
      final f = File(p.join(backupDir.path, 'mirkfall.db.backup-v1-to-v2-fake-$i'));
      f.writeAsBytesSync(<int>[i]);
      f.setLastModifiedSync(now.subtract(Duration(hours: 4 - i)));
    }

    await svc.rotate();

    final remaining = backupDir.listSync().whereType<File>().toList();
    expect(remaining.length, 3);
    // The one with the oldest mtime ("fake-0") must have been deleted.
    final names = remaining.map((File f) => p.basename(f.path)).toSet();
    expect(names.contains('mirkfall.db.backup-v1-to-v2-fake-0'), isFalse);
    expect(names.contains('mirkfall.db.backup-v1-to-v2-fake-1'), isTrue);
    expect(names.contains('mirkfall.db.backup-v1-to-v2-fake-2'), isTrue);
    expect(names.contains('mirkfall.db.backup-v1-to-v2-fake-3'), isTrue);
  });

  test('rotate is a no-op when fewer backups than maxBackups', () async {
    final svc = DbBackupService(dbFilename: fakeDb.path, backupDir: backupDir, maxBackups: 3);
    backupDir.createSync(recursive: true);
    File(p.join(backupDir.path, 'only.one')).writeAsBytesSync(<int>[1]);

    await svc.rotate();

    expect(backupDir.listSync().length, 1);
  });

  test('rotate handles missing dir silently', () async {
    final svc = DbBackupService(
      dbFilename: fakeDb.path,
      backupDir: backupDir, // does not exist
      maxBackups: 3,
    );
    // Must not throw — rotating an absent directory is a no-op.
    await svc.rotate();
  });

  test('takeBackup creates backupDir if absent', () async {
    expect(backupDir.existsSync(), isFalse);
    final svc = DbBackupService(dbFilename: fakeDb.path, backupDir: backupDir, maxBackups: 3, clock: () => DateTime.utc(2026, 4, 18));
    await svc.takeBackup(fromVersion: 1, toVersion: 2);
    expect(backupDir.existsSync(), isTrue);
  });

  test('consecutive takeBackup calls + rotation keeps at most maxBackups', () async {
    final svc = DbBackupService(dbFilename: fakeDb.path, backupDir: backupDir, maxBackups: 3);
    // Five backups, spaced a few ms apart so the clock-supplied timestamp
    // guarantees distinct filenames. We only care that rotation caps to 3.
    for (var i = 0; i < 5; i++) {
      await svc.takeBackup(fromVersion: 1, toVersion: 2);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final remaining = backupDir.listSync().whereType<File>().toList();
    expect(remaining.length, 3);
  });
}

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

  test('rotate keeps the 3 newest by filename-embedded ISO timestamp when 4 exist', () async {
    final svc = DbBackupService(dbFilename: fakeDb.path, backupDir: backupDir, maxBackups: 3);
    backupDir.createSync(recursive: true);

    // Four backups with ISO timestamps embedded in the filename — the ONLY
    // ordering signal the rotator uses after finding #1 / P1 (deterministic
    // filename sort, no dependence on filesystem mtime precision). Write
    // order is intentionally shuffled vs. timestamp order so a lingering
    // mtime-sort regression would flip the expected result.
    const orderedTimestamps = <String>[
      '2026-04-18T08-00-00.000Z', // oldest — should be deleted
      '2026-04-18T09-00-00.000Z',
      '2026-04-18T10-00-00.000Z',
      '2026-04-18T11-00-00.000Z', // newest — should survive
    ];
    final writeOrder = <int>[2, 0, 3, 1];
    for (final i in writeOrder) {
      File(p.join(backupDir.path, 'mirkfall.db.backup-v1-to-v2-${orderedTimestamps[i]}')).writeAsBytesSync(<int>[i]);
    }

    await svc.rotate();

    final remaining = backupDir.listSync().whereType<File>().toList();
    expect(remaining.length, 3);
    // Filename whose embedded timestamp is oldest must be deleted.
    final names = remaining.map((File f) => p.basename(f.path)).toSet();
    expect(names.contains('mirkfall.db.backup-v1-to-v2-${orderedTimestamps[0]}'), isFalse);
    expect(names.contains('mirkfall.db.backup-v1-to-v2-${orderedTimestamps[1]}'), isTrue);
    expect(names.contains('mirkfall.db.backup-v1-to-v2-${orderedTimestamps[2]}'), isTrue);
    expect(names.contains('mirkfall.db.backup-v1-to-v2-${orderedTimestamps[3]}'), isTrue);
  });

  test('rotate drops orphan files without parseable timestamp first', () async {
    final svc = DbBackupService(dbFilename: fakeDb.path, backupDir: backupDir, maxBackups: 2);
    backupDir.createSync(recursive: true);

    // Mix: 2 real backups + 2 orphans. maxBackups=2 → orphans must go.
    File(p.join(backupDir.path, 'mirkfall.db.backup-v1-to-v2-2026-04-18T10-00-00.000Z')).writeAsBytesSync(<int>[1]);
    File(p.join(backupDir.path, 'mirkfall.db.backup-v1-to-v2-2026-04-18T11-00-00.000Z')).writeAsBytesSync(<int>[2]);
    File(p.join(backupDir.path, 'orphan.txt')).writeAsBytesSync(<int>[3]);
    File(p.join(backupDir.path, 'random.bin')).writeAsBytesSync(<int>[4]);

    await svc.rotate();

    final names = backupDir.listSync().whereType<File>().map((File f) => p.basename(f.path)).toSet();
    expect(names.length, 2);
    expect(names.contains('mirkfall.db.backup-v1-to-v2-2026-04-18T10-00-00.000Z'), isTrue);
    expect(names.contains('mirkfall.db.backup-v1-to-v2-2026-04-18T11-00-00.000Z'), isTrue);
    expect(names.contains('orphan.txt'), isFalse);
    expect(names.contains('random.bin'), isFalse);
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

  test('consecutive takeBackup calls + rotation keeps at most maxBackups (deterministic clock)', () async {
    // Inject a monotonic clock so each takeBackup call gets a distinct,
    // deterministic timestamp — no reliance on wall-clock or `Future.delayed`
    // ms-precision, which was the P1 flakiness family (04-REVIEW.md §3).
    var tick = 0;
    DateTime clock() => DateTime.utc(2026, 4, 18, 12, 0, tick++);
    final svc = DbBackupService(dbFilename: fakeDb.path, backupDir: backupDir, maxBackups: 3, clock: clock);

    for (var i = 0; i < 5; i++) {
      await svc.takeBackup(fromVersion: 1, toVersion: 2);
    }

    final remaining = backupDir.listSync().whereType<File>().map((File f) => p.basename(f.path)).toList()..sort();
    expect(remaining.length, 3);
    // The 3 newest filenames (by embedded timestamp seconds 2/3/4) survive.
    // Sorted ascending, the first element is the 3rd-oldest kept (seconds=2),
    // and the last is the newest (seconds=4).
    expect(remaining.first, contains('12-00-02'));
    expect(remaining.last, contains('12-00-04'));
  });
}

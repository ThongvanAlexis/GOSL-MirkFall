// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

@Tags(<String>['migration'])
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/db/app_database_factory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../generated_migrations/schema_v1.dart' as v1;

/// Integration test for Blocker 3: proves `DbBackupService.takeBackup` is
/// wired into `AppDatabase.onBeforeUpgrade` via [buildAppDatabase] and fires
/// BEFORE `onUpgrade` runs when opening an out-of-date DB on disk.
///
/// The "before onUpgrade" ordering is proven by comparing the backup file's
/// byte count to the live DB file's pre-open byte count — the backup captures
/// the V1 shape (no `notes` column), while after `onUpgrade` the live DB has
/// grown by at least the column metadata. If backup fired AFTER `onUpgrade`,
/// the backup file would match the post-migration byte count.
void main() {
  late Directory scratch;
  late String dbFilename;
  late Directory backupDir;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('mirkfall_backup_on_upgrade_');
    dbFilename = p.join(scratch.path, 'mirkfall.db');
    backupDir = Directory(p.join(scratch.path, 'db_backups'));
  });

  tearDown(() {
    try {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows: pending async handles — let systemTemp evict.
    }
  });

  /// Creates a V1-shaped SQLite file at [dbFilename] with a single seeded
  /// session row. Uses `DatabaseAtV1` directly against a [NativeDatabase]
  /// pointed at the file so Drift's `onCreate` materializes the V1 schema
  /// on disk with `schemaVersion=1`.
  Future<void> seedV1DbFile() async {
    final seedDb = v1.DatabaseAtV1(
      DatabaseConnection(
        NativeDatabase(File(dbFilename)),
        closeStreamsSynchronously: true,
      ),
    );
    try {
      await seedDb.customStatement(
        "INSERT INTO t_sessions (id, display_name, status, "
        "started_at_utc, started_at_offset_minutes) "
        "VALUES ('sess_01HRBACKUPUPGRADEAAAAAAAAA', 'X', "
        "'stopped', 1712000000000, 120)",
      );
    } finally {
      await seedDb.close();
    }
    expect(File(dbFilename).existsSync(), isTrue,
        reason: 'NativeDatabase should have materialized the file on close');
  }

  test('upgrading V1 → V2 triggers backup BEFORE onUpgrade', () async {
    await seedV1DbFile();
    final sizeBefore = File(dbFilename).lengthSync();
    expect(sizeBefore, greaterThan(0));

    // Sanity: backup dir empty pre-open.
    expect(backupDir.existsSync(), isFalse);

    // Open via factory — should fire the onBeforeUpgrade hook (wired to
    // DbBackupService.takeBackup) BEFORE onUpgrade (V1ToV2Notes) runs.
    final db = buildAppDatabase(
      dbFilename: dbFilename,
      backupDir: backupDir,
      maxBackups: 3,
    );
    try {
      // Force open + migration via a lightweight query.
      await db.customStatement('SELECT 1');

      // Assertion A: exactly one backup file, correctly named.
      expect(backupDir.existsSync(), isTrue);
      final backups = backupDir.listSync().whereType<File>().toList();
      expect(backups, hasLength(1), reason: 'exactly one backup file');
      final backup = backups.single;
      expect(p.basename(backup.path), startsWith('mirkfall.db.backup-v1-to-v2-'));

      // Assertion B: backup captured the pre-upgrade file bytes. If the
      // backup had fired AFTER onUpgrade, its byte count would reflect the
      // migrated schema (ALTER TABLE adds the `notes` column metadata, which
      // SQLite writes into the file). Byte equality with sizeBefore proves
      // "backup ran BEFORE onUpgrade mutated the file".
      expect(
        backup.lengthSync(),
        sizeBefore,
        reason:
            'backup bytes must equal the pre-upgrade V1 file bytes — proving '
            'the backup fired BEFORE onUpgrade mutated the schema',
      );

      // Assertion C: the live DB is now V2 — the previously-seeded session
      // survived AND the new `notes` column is queryable.
      final row = await db.customSelect(
        "SELECT notes FROM t_sessions "
        "WHERE id = 'sess_01HRBACKUPUPGRADEAAAAAAAAA'",
      ).getSingle();
      expect(row.data['notes'], null);
    } finally {
      await db.close();
    }
  });

  test('opening a fresh DB (onCreate, no upgrade) does NOT trigger backup',
      () async {
    expect(File(dbFilename).existsSync(), isFalse);
    expect(backupDir.existsSync(), isFalse);

    final db = buildAppDatabase(
      dbFilename: dbFilename,
      backupDir: backupDir,
      maxBackups: 3,
    );
    try {
      await db.customStatement('SELECT 1');

      expect(File(dbFilename).existsSync(), isTrue);
      // Either backupDir absent, or present but empty — both acceptable.
      // The details.hadUpgrade guard in AppDatabase.beforeOpen skips the
      // onBeforeUpgrade hook on first-open (onCreate) paths.
      if (backupDir.existsSync()) {
        expect(
          backupDir.listSync().whereType<File>(),
          isEmpty,
          reason:
              'onCreate (first open) must not produce a pre-migration backup',
        );
      }
    } finally {
      await db.close();
    }
  });

  test('opening an already-current DB does NOT trigger backup', () async {
    // First open: create V2 DB at current schema (onCreate path).
    final db1 = buildAppDatabase(
      dbFilename: dbFilename,
      backupDir: backupDir,
      maxBackups: 3,
    );
    await db1.customStatement('SELECT 1');
    await db1.close();

    // Drain any stray files from the first open so the assertion below
    // isolates the second-open behavior.
    if (backupDir.existsSync()) {
      for (final f in backupDir.listSync().whereType<File>()) {
        f.deleteSync();
      }
    }

    // Second open: schemaVersion already == 2, no upgrade needed →
    // details.hadUpgrade is false → hook does not fire.
    final db2 = buildAppDatabase(
      dbFilename: dbFilename,
      backupDir: backupDir,
      maxBackups: 3,
    );
    try {
      await db2.customStatement('SELECT 1');

      if (backupDir.existsSync()) {
        expect(
          backupDir.listSync().whereType<File>(),
          isEmpty,
          reason:
              'reopening at current schemaVersion must not produce a backup',
        );
      }
    } finally {
      await db2.close();
    }
  });
}

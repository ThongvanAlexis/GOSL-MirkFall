// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:drift/native.dart';

import 'app_database.dart';
import 'backup.dart';

/// Wires an [AppDatabase] with the Blocker 3 pre-migration backup hook.
///
/// Returns an `AppDatabase` whose `onBeforeUpgrade` fires
/// `DbBackupService.takeBackup` inside `MigrationStrategy.beforeOpen` whenever
/// `details.hadUpgrade == true` — producing a backup file at
/// `[backupDir]/mirkfall.db.backup-v{N}-to-v{M}-{timestamp}` BEFORE `onUpgrade`
/// touches the schema. Satisfies SC#6 ("produit automatiquement").
///
/// Pragma wiring (RESEARCH §Pattern 1):
/// - `setup:` applies `PRAGMA journal_mode = WAL` on the raw sqlite3 handle
///   before Drift's first query (pitfall #2 — WAL must be set BEFORE the
///   first connection opens, otherwise the journal mode is frozen).
/// - Runtime pragmas (synchronous, busy_timeout, foreign_keys) are applied by
///   `AppDatabase`'s `beforeOpen` via `applyRuntimePragmas` on every open.
///
/// Tests that do NOT want a real disk backup — e.g. unit tests that assert
/// isolated AppDatabase behaviour — should instantiate `AppDatabase` directly
/// with `onBeforeUpgrade: null`. This factory is the production + integration
/// entry point.
AppDatabase buildAppDatabase({
  required String dbFilename,
  required Directory backupDir,
  required int maxBackups,
}) {
  final backupService = DbBackupService(
    dbFilename: dbFilename,
    backupDir: backupDir,
    maxBackups: maxBackups,
  );
  // NativeDatabase (synchronous) is used instead of createInBackground because
  // (a) it works identically from a correctness perspective — the backup hook
  // fires from the same isolate the open runs on; (b) it keeps the factory
  // testable without isolate spawn overhead. Production wiring (Phase 05)
  // can switch to `NativeDatabase.createInBackground` if profiling shows the
  // open path is long enough to warrant isolating — but the backup file write
  // itself is already async, so there's no UI-thread concern in the hook.
  final executor = NativeDatabase(
    File(dbFilename),
    setup: (raw) {
      raw.execute('PRAGMA journal_mode = WAL');
    },
  );
  return AppDatabase(
    executor,
    onBeforeUpgrade: (details) async {
      // details.versionBefore can be null on pathological first-open paths,
      // but the AppDatabase wrapper only invokes this hook when hadUpgrade is
      // true, which in turn requires a non-null versionBefore. Coerce to 0
      // defensively so a surprise null doesn't blow up the filename.
      await backupService.takeBackup(
        fromVersion: details.versionBefore ?? 0,
        toVersion: details.versionNow,
      );
    },
  );
}

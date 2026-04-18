// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:path/path.dart' as p;

/// Copies the MirkFall SQLite DB file on demand, keeping a rolling window of
/// the N most recent backups.
///
/// Phase 03 use: pre-migration safety net (CONTEXT.md §Timing backups). 03-05
/// wires [takeBackup] into `AppDatabase.onBeforeUpgrade` so the snapshot lands
/// BEFORE `onUpgrade` runs — corrupted upgrades can roll back to the matching
/// bytes-on-disk file.
///
/// Phase 15 use: optional "Backup DB now" button in the debug menu.
///
/// Rotation semantics: after every successful [takeBackup], [rotate] deletes
/// the oldest files (by mtime) until at most [maxBackups] remain. Orphan files
/// left in [backupDir] (e.g. a manual user copy) are counted the same as real
/// backups — the service owns the whole directory.
class DbBackupService {
  /// Creates the service.
  ///
  /// [dbFilename] is the absolute path to the live DB file (typically
  /// `<app_support>/mirkfall.db`).
  /// [backupDir] is where backups land; created on first [takeBackup] if
  /// absent.
  /// [maxBackups] is the rolling retention limit (typically [kMaxDbBackups]).
  /// [clock] is injectable for deterministic filenames in tests; defaults to
  /// `DateTime.now`.
  DbBackupService({required this.dbFilename, required this.backupDir, required this.maxBackups, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Absolute path to the live DB file.
  final String dbFilename;

  /// Directory where backups are stored.
  final Directory backupDir;

  /// Rolling retention limit.
  final int maxBackups;

  final DateTime Function() _clock;

  /// Copies [dbFilename] to a new file in [backupDir], naming it
  /// `mirkfall.db.backup-v{from}-to-v{to}-{iso-utc}`, then triggers [rotate].
  ///
  /// The timestamp is ISO 8601 UTC with colons replaced by hyphens — Windows
  /// forbids `:` in filenames, so the hyphen variant keeps the filename valid
  /// on every platform MirkFall ships to.
  ///
  /// Returns the newly-created [File]. The file bytes are a byte-equal copy
  /// of the source DB at the moment of the call.
  Future<File> takeBackup({required int fromVersion, required int toVersion}) async {
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    final timestamp = _clock().toUtc().toIso8601String().replaceAll(':', '-');
    final backupBasename = 'mirkfall.db.backup-v$fromVersion-to-v$toVersion-$timestamp';
    final backupFilename = p.join(backupDir.path, backupBasename);

    final source = File(dbFilename);
    final target = await source.copy(backupFilename);
    await rotate();
    return target;
  }

  /// Deletes the oldest files in [backupDir] so at most [maxBackups] remain.
  ///
  /// "Oldest" = lowest `File.statSync().modified`. Silent no-op when the dir
  /// is absent or already at or below the retention limit.
  Future<void> rotate() async {
    if (!await backupDir.exists()) return;
    final entries = await backupDir.list(followLinks: false).where((FileSystemEntity e) => e is File).cast<File>().toList();
    if (entries.length <= maxBackups) return;
    // Descending mtime → newest first. Skip the first `maxBackups`, delete
    // the tail.
    entries.sort((File a, File b) => b.statSync().modified.compareTo(a.statSync().modified));
    for (final file in entries.skip(maxBackups)) {
      await file.delete();
    }
  }
}

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
/// the oldest files until at most [maxBackups] remain. "Oldest" is decided by
/// the ISO-8601 timestamp embedded in the filename (not the filesystem mtime,
/// which is fragile on Windows — see finding #1 / P1 in 04-REVIEW.md §3).
/// Orphan files left in [backupDir] (e.g. a manual user copy) without a
/// parseable timestamp suffix are treated as the oldest possible entries and
/// rotated first — the service owns the whole directory.
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
  /// "Oldest" = lowest ISO-8601 timestamp extracted from the filename via
  /// [_extractBackupSortKey]. Files without a parseable timestamp sort
  /// BEFORE any timestamped file (empty string compares lowest), so orphans
  /// are rotated out first. Silent no-op when the dir is absent or already
  /// at or below the retention limit.
  ///
  /// Filename-based sort is deterministic and immune to the Windows NTFS mtime
  /// resolution / antivirus / parallel-run fragility that made finding #1 /
  /// P1 a Blocker (04-REVIEW.md §3).
  Future<void> rotate() async {
    if (!await backupDir.exists()) return;
    final entries = await backupDir.list(followLinks: false).where((FileSystemEntity e) => e is File).cast<File>().toList();
    if (entries.length <= maxBackups) return;
    // Descending filename-sort-key → newest first. Skip the first `maxBackups`,
    // delete the tail. Files whose basename does not carry a parseable
    // `yyyy-MM-ddTHH-mm-ss.sssZ` suffix get empty sort key and rotate first.
    entries.sort((File a, File b) => _extractBackupSortKey(p.basename(b.path)).compareTo(_extractBackupSortKey(p.basename(a.path))));
    for (final file in entries.skip(maxBackups)) {
      await file.delete();
    }
  }

  /// Extracts the ISO-8601 sort key from [basename].
  ///
  /// Expected shape: `mirkfall.db.backup-v{from}-to-v{to}-{iso}` where `{iso}`
  /// is produced by [takeBackup] as
  /// `DateTime.toUtc().toIso8601String().replaceAll(':', '-')` — e.g.
  /// `2026-04-18T12-30-45.123Z`.
  ///
  /// Returns the `{iso}` segment when the shape matches, or the empty string
  /// otherwise. Empty strings lex-sort before any non-empty string, so malformed
  /// or orphan files rotate out first — the desired behaviour for directory
  /// cleanup.
  ///
  /// The regex anchors on the `mirkfall.db.backup-v{int}-to-v{int}-` prefix and
  /// captures everything up to end-of-string. That remainder is a sortable ISO
  /// timestamp by construction of [takeBackup]; lex comparison of two such
  /// timestamps is equivalent to chronological comparison (ISO-8601 property).
  static String _extractBackupSortKey(String basename) {
    final match = _backupFilenamePattern.firstMatch(basename);
    return match?.group(1) ?? '';
  }

  /// Matches `mirkfall.db.backup-v<int>-to-v<int>-<iso timestamp>` filenames.
  /// Capture group 1 is the ISO-8601 timestamp suffix (sort key).
  static final RegExp _backupFilenamePattern = RegExp(r'^mirkfall\.db\.backup-v\d+-to-v\d+-(.+)$');
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:io';

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/db/app_database_factory.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database_provider.g.dart';

/// Production [AppDatabase] — async-resolved because `path_provider`
/// yields the app-support directory via a platform channel.
///
/// Wiring:
/// 1. `getApplicationSupportDirectory()` resolves `<app_support>/`.
/// 2. `buildAppDatabase(...)` (03-05) composes the `NativeDatabase`
///    executor, the `DbBackupService` (rolling 3-wide), and the
///    `AppDatabase.onBeforeUpgrade` hook in one call. Runtime pragmas
///    (synchronous, busy_timeout, foreign_keys) are applied by
///    `AppDatabase`'s `beforeOpen`; WAL is pinned by the executor's
///    `setup:` hook (file-backed → reports 'wal', unlike in-memory).
/// 3. `ref.onDispose(db.close)` wires the lifecycle — a provider
///    invalidate closes the underlying DB cleanly before reopen.
///
/// Tests override with a fresh in-memory `AppDatabase` via
/// `ProviderScope(overrides: [appDatabaseProvider.overrideWith(...)])`.
/// Phase 03 unit tests skip this path entirely and instantiate
/// `AppDatabase(NativeDatabase.memory(...))` directly.
///
/// `keepAlive: true` — the database is a process singleton; re-opening
/// on every consumer subscription would both thrash the WAL and
/// invalidate any active transactions.
@Riverpod(keepAlive: true)
Future<AppDatabase> appDatabase(Ref ref) async {
  final supportDir = await getApplicationSupportDirectory();
  final dbFilename = p.join(supportDir.path, kDbFilename);
  final backupDir = Directory(p.join(supportDir.path, kDbBackupDirName));
  final db = buildAppDatabase(
    dbFilename: dbFilename,
    backupDir: backupDir,
    maxBackups: kMaxDbBackups,
  );
  ref.onDispose(() async {
    await db.close();
  });
  return db;
}

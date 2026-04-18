// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

/// One-off utility that opens the production `buildAppDatabase` against the
/// real filesystem and prints the resolved DB path + WAL/SHM file sizes.
/// Consumed by Phase 04 Plan 04-02 runtime walk; retention decided at
/// plan checkpoint. Do NOT import from lib/ code.
///
/// Wiring mirrors `lib/application/providers/app_database_provider.dart`
/// exactly — `buildAppDatabase` requires `dbFilename`, `backupDir`, and
/// `maxBackups`; resolution of `<app_support>/` via `path_provider` is the
/// caller's job (same contract as the Riverpod provider). This replicates
/// what Phase 05's first consumer will do, minus Riverpod plumbing.
library;

import 'dart:io';

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/db/app_database_factory.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  final supportDir = await getApplicationSupportDirectory();
  final dbFilename = p.join(supportDir.path, kDbFilename);
  final backupDir = Directory(p.join(supportDir.path, kDbBackupDirName));
  // ignore: avoid_print
  print('DB path: $dbFilename');

  // buildAppDatabase is synchronous — returns AppDatabase directly (the
  // underlying NativeDatabase opens lazily on first query). Mirrors the
  // app_database_provider.dart production wiring.
  final db = buildAppDatabase(dbFilename: dbFilename, backupDir: backupDir, maxBackups: kMaxDbBackups);
  // Force the lazy open so WAL + pragma setup actually fire before we
  // inspect the filesystem.
  await db.customSelect('SELECT 1').get();
  await db.close();

  for (final basename in <String>[kDbFilename, '$kDbFilename-wal', '$kDbFilename-shm']) {
    final file = File(p.join(supportDir.path, basename));
    // ignore: avoid_print
    print('$basename exists=${file.existsSync()} size=${file.existsSync() ? file.lengthSync() : "N/A"}');
  }
}

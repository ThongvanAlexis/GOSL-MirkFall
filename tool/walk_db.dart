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
/// `maxBackups`. Path resolution normally goes through `path_provider`, but
/// that package transitively imports `dart:ui` and therefore cannot load
/// under a vanilla `dart run` — it requires the Flutter engine binding.
///
/// Workaround: resolve the app-support directory manually from
/// `Platform.environment['APPDATA']` + `<CompanyName>\<ProductName>` as
/// declared in `windows/runner/Runner.rc` (CompanyName="app.gosl",
/// ProductName="mirkfall"). This matches exactly what `path_provider`'s
/// Windows implementation yields (`%APPDATA%\app.gosl\mirkfall\`), so the
/// DB file ends up at the same path the production app will open.
///
/// Platform scope: Windows-only. Fails loud on other hosts rather than
/// silently resolving to a bogus path.
library;

import 'dart:io';

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/infrastructure/db/app_database_factory.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  if (!Platform.isWindows) {
    stderr.writeln('walk_db: this tool currently targets Windows only.');
    exit(1);
  }
  final appData = Platform.environment['APPDATA'];
  if (appData == null || appData.isEmpty) {
    stderr.writeln('walk_db: APPDATA env var not set.');
    exit(1);
  }

  // Mirrors path_provider's Windows resolution:
  //   SHGetKnownFolderPath(RoamingAppData) \ CompanyName \ ProductName
  // CompanyName + ProductName come from windows/runner/Runner.rc.
  final supportDir = p.join(appData, 'app.gosl', 'mirkfall');
  Directory(supportDir).createSync(recursive: true);

  final dbFilename = p.join(supportDir, kDbFilename);
  final backupDir = Directory(p.join(supportDir, kDbBackupDirName));
  // ignore: avoid_print
  print('DB path: $dbFilename');

  // buildAppDatabase is synchronous — returns AppDatabase directly (the
  // underlying NativeDatabase opens lazily on first query). Mirrors the
  // app_database_provider.dart production wiring.
  final db = buildAppDatabase(dbFilename: dbFilename, backupDir: backupDir, maxBackups: kMaxDbBackups);
  // Force the lazy open so WAL + pragma setup actually fire before we
  // inspect the filesystem.
  await db.customSelect('SELECT 1').get();

  // Finding P5 (Batch J) — probe the 5 pragmas authoritatively through the
  // live Drift connection BEFORE db.close(). The sqlite3 CLI reads library
  // defaults on fresh connection open, so it can NOT observe the per-
  // connection pragmas Drift set via applyRuntimePragmas. Printing them
  // here via the same in-process connection that served `SELECT 1` proves
  // Drift applied them for real.
  //
  // The 5 pragmas correspond to the CONTEXT.md runtime walk contract:
  // journal_mode (WAL) + synchronous + busy_timeout + foreign_keys +
  // user_version. `page_size` is a DB-level pragma and already visible
  // via the CLI; the CLI-authoritative triple of db-level pragmas stays
  // in tool/inspect_db.sql (journal_mode, user_version, page_size).
  for (final pragma in <String>['journal_mode', 'synchronous', 'busy_timeout', 'foreign_keys', 'user_version']) {
    final row = await db.customSelect('PRAGMA $pragma').getSingle();
    final value = row.data.values.first;
    // ignore: avoid_print
    print('PRAGMA $pragma = $value (authoritative — read through live Drift connection)');
  }

  await db.close();

  for (final basename in <String>[kDbFilename, '$kDbFilename-wal', '$kDbFilename-shm']) {
    final file = File(p.join(supportDir, basename));
    // ignore: avoid_print
    print('$basename exists=${file.existsSync()} size=${file.existsSync() ? file.lengthSync() : "N/A"}');
  }
}

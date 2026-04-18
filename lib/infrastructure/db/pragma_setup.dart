// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:mirkfall/config/constants.dart';

/// Applies the runtime PRAGMAs expected by MirkFall on every DB connection
/// open. Called from [AppDatabase]'s `MigrationStrategy.beforeOpen` callback
/// so the pragmas are re-asserted on every cold + warm open.
///
/// Pragmas (CONTEXT.md §Stockage DB, RESEARCH §Pattern 1):
/// - `synchronous = NORMAL` — balances crash safety vs fsync cost for WAL.
/// - `busy_timeout = ${kDbBusyTimeoutMs}` — retry window before `SQLITE_BUSY`
///   surfaces to the caller.
/// - `foreign_keys = ON` — CRITICAL. Default is OFF, which silently voids
///   the `ON DELETE CASCADE` declarations (RESEARCH pitfall #1).
///
/// NOTE: `journal_mode = WAL` is NOT applied here. It must run on the raw
/// sqlite3 handle BEFORE Drift's first query via the `setup:` callback of
/// `NativeDatabase.memory` / `createInBackground` (pitfall #2 — `beforeOpen`
/// fires after the first connection is already established, at which point
/// WAL switching is a no-op if the first journal_mode read picked a
/// different mode).
Future<void> applyRuntimePragmas(DatabaseConnectionUser db) async {
  await db.customStatement('PRAGMA synchronous = NORMAL');
  await db.customStatement('PRAGMA busy_timeout = $kDbBusyTimeoutMs');
  await db.customStatement('PRAGMA foreign_keys = ON');
}

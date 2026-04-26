// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';

/// V5 → V6 migration — drops the dead `t_revealed_tiles` table and its
/// `(session_id, parent_x, parent_y)` index.
///
/// Phase 09 BUG-010 Option B Commit 5: end of the cell-bitmap data layer.
/// Reveals are now stored exclusively as continuous-geometry discs in
/// `t_revealed_disc` (added by V4→V5). The bitmap surface that lived in
/// `t_revealed_tiles` is fully orphan after Commit 4 rewired writes and
/// reads to the disc path; this migration finalises the cleanup.
///
/// No data migration of the V5 bitmap rows: existing local sessions are
/// decommissioned via fresh uninstall/install per-build during BUG-010
/// development (recorded in CONTEXT.md and the umbrella commit message).
/// The explicit `DROP IF EXISTS` semantics keep the migration idempotent
/// for any device that did upgrade through V4 → V5 → V6.
///
/// Implementation: raw `customStatement(...)` mirrors v4_to_v5 — portable
/// across Drift 2.x, no dependency on generated companions, no reverse
/// import of [AppDatabase] (the class hosts this migration in its
/// `MigrationStrategy.onUpgrade` chain).
class V5ToV6DropRevealedTiles {
  V5ToV6DropRevealedTiles._();

  /// Applies the V5 → V6 migration iff the version transition matches.
  /// No-op for every other `from`/`to` pair — the caller chains
  /// migrations linearly from `AppDatabase.migration.onUpgrade`.
  static Future<void> apply(Migrator m, int from, int to) async {
    if (from < 6 && to >= 6) {
      // Index named per the V5 schema (the `@TableIndex.sql` declaration on
      // `RevealedTiles`); confirmed against `app_database.g.dart` before
      // landing the deletion. Drop the index first so the DROP TABLE does
      // not race a stale index reference under concurrent connection
      // pools (defense-in-depth — SQLite drops dependent indexes when a
      // table is dropped, but explicit ordering survives any future
      // engine quirks).
      await m.database.customStatement('DROP INDEX IF EXISTS idx_t_revealed_tiles_session_id_parent_key');
      await m.database.customStatement('DROP TABLE IF EXISTS t_revealed_tiles');
    }
  }
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';

/// V4 → V5 migration — adds the `t_revealed_disc` table + two indexes.
///
/// Phase 09 BUG-010 Option B (continuous-geometry reveal): replaces the
/// V4 cell-bitmap model (`t_revealed_tiles`) with an immutable disc per
/// GPS fix. This commit introduces the new table only — `t_revealed_tiles`
/// stays untouched and continues to serve every reader/writer until
/// BUG-010 Commit 5, which drops the bitmap path entirely.
///
/// No data migration of the V4 bitmap rows: existing local sessions are
/// decommissioned via fresh uninstall/install per-build during BUG-010
/// development (recorded in CONTEXT and the umbrella commit message).
///
/// Implementation: raw `customStatement(...)` for the CREATE TABLE +
/// CREATE INDEX statements. Same rationale as v1_to_v2 / v3_to_v4:
/// * Portable across Drift 2.x versions (no dependency on the generated
///   `Migrator` companion APIs whose names change between minor releases).
/// * Avoids importing `AppDatabase` from this file — the prod
///   `MigrationStrategy.onUpgrade` closure imports this class, so a
///   reverse import would be a circular reference.
/// * Survives future schema refactors that might rename the generated
///   column / index accessors.
///
/// SQL shape mirrors exactly the `CREATE TABLE` + `CREATE INDEX`
/// statements emitted by Drift's codegen for the V5 schema (column
/// identifiers quoted, table/column references unquoted, FK clause +
/// `ON DELETE CASCADE`, real-column CHECK on `radius_m > 0`). The
/// byte-equal match keeps `SchemaVerifier.migrateAndValidate` happy when
/// V5 is added to the generated_migrations harness in a future plan.
class V4ToV5RevealedDisc {
  V4ToV5RevealedDisc._();

  /// Applies the V4 → V5 migration iff the version transition matches.
  /// No-op for every other `from`/`to` pair — the caller chains
  /// migrations linearly from `AppDatabase.migration.onUpgrade`.
  static Future<void> apply(Migrator m, int from, int to) async {
    if (from < 5 && to >= 5) {
      await m.database.customStatement(
        'CREATE TABLE IF NOT EXISTS "t_revealed_disc" ('
        '"id" TEXT NOT NULL PRIMARY KEY, '
        '"session_id" TEXT NOT NULL REFERENCES t_sessions (id) ON DELETE CASCADE, '
        '"lat" REAL NOT NULL, '
        '"lon" REAL NOT NULL, '
        '"radius_m" REAL NOT NULL CHECK("radius_m" > 0.0), '
        '"fixed_at_utc" INTEGER NOT NULL'
        ')',
      );
      await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_t_revealed_disc_session '
        'ON t_revealed_disc(session_id)',
      );
      await m.database.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_t_revealed_disc_session_latlon '
        'ON t_revealed_disc(session_id, lat, lon)',
      );
    }
  }
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';

/// V3 → V4 migration — adds `t_sessions.mirk_style_id` (nullable FK).
///
/// Phase 09 plan 09-05 introduces per-session mirk-style selection
/// (MIRK-07 wire-up). The new column references `t_mirk_styles(id)` with
/// `ON DELETE SET NULL` so deleting a user-imported style does not
/// orphan or cascade-delete the session — instead the session degrades
/// to the renderer-side default (atmospheric) at resolution time
/// (`activeMirkRendererProvider`). Built-in styles are protected from
/// deletion at the application layer in Phase 13 (OPT-04), so the
/// `SET NULL` semantics primarily matter for user imports.
///
/// Implementation: raw `customStatement('ALTER TABLE ... ADD COLUMN ...
/// REFERENCES ...')` rather than `m.addColumn(...)`. Rationale matches
/// `v1_to_v2_notes.dart`:
/// * The raw form is portable across Drift 2.x versions.
/// * Avoids importing `AppDatabase` from this file (the prod
///   `MigrationStrategy.onUpgrade` closure imports this class — a
///   reverse import would be a circular reference).
/// * Survives future schema refactors that might rename the generated
///   column accessor.
///
/// SQL shape: `ADD COLUMN "mirk_style_id" TEXT NULL REFERENCES
/// t_mirk_styles (id) ON DELETE SET NULL` — mirrors exactly the
/// `CREATE TABLE` clause emitted by Drift's codegen for the V4 schema
/// (column identifier quoted + table/column references unquoted +
/// explicit `NULL` nullability + standard FK clause). The byte-equal
/// match keeps `SchemaVerifier.migrateAndValidate` happy when V4 is
/// added to the generated_migrations harness in a future plan.
class V3ToV4SessionMirkStyle {
  V3ToV4SessionMirkStyle._();

  /// Applies the V3 → V4 migration if the version transition matches.
  /// No-op for every other `from`/`to` pair — the caller chains
  /// migrations linearly from `AppDatabase.migration.onUpgrade`.
  static Future<void> apply(Migrator m, int from, int to) async {
    if (from < 4 && to >= 4) {
      await m.database.customStatement(
        'ALTER TABLE t_sessions ADD COLUMN "mirk_style_id" TEXT NULL '
        'REFERENCES t_mirk_styles (id) ON DELETE SET NULL',
      );
    }
  }
}

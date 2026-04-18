// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';

/// V1 -> V2 symbolic migration (Phase 03 proof-of-framework).
///
/// Shape change: adds nullable `notes TEXT` column to `t_sessions`. Purpose
/// is to exercise the Drift migration tooling end-to-end (SchemaVerifier +
/// `drift_schemas/drift_schema_v{1,2}.json` + `test/generated_migrations/`)
/// before a real schema evolution lands. Explicitly fictive — there is no
/// product feature in v1.0 that writes `notes`; the column exists to prove
/// the pipeline works (Phase 03 SC#6, CONTEXT.md §Framework migration).
///
/// Implementation: raw `customStatement('ALTER TABLE t_sessions ADD COLUMN
/// notes TEXT')` rather than `m.addColumn(db.sessions, db.sessions.notes)`.
/// Rationale: the raw form is portable across Drift 2.x versions, avoids
/// having `V1ToV2Notes` depend on the `AppDatabase` reference (keeps the
/// migration file importable from the `onUpgrade` closure without circular
/// coupling), and survives future schema refactors that might rename the
/// generated column accessor.
class V1ToV2Notes {
  V1ToV2Notes._();

  /// Applies the V1 -> V2 migration if the version transition matches.
  /// Called from [AppDatabase]'s `MigrationStrategy.onUpgrade`.
  static Future<void> apply(Migrator m, int from, int to) async {
    if (from < 2 && to >= 2) {
      await m.database.customStatement(
        'ALTER TABLE t_sessions ADD COLUMN notes TEXT',
      );
    }
  }
}

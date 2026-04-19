// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';

import '../app_database.dart';

/// V2 → V3 migration — adds `t_fixes` table + indexes.
///
/// Implementation uses `m.createTable(m.database.tFixes)` — the
/// generator-native path, NOT `customStatement('CREATE TABLE ...')`. The
/// native path avoids whitespace / quoting drift between the runtime
/// migration output and the frozen `drift_schemas/drift_schema_v3.json`
/// snapshot that `SchemaVerifier.migrateAndValidate` byte-compares
/// against. V1→V2 used `customStatement` because `ALTER TABLE ... ADD
/// COLUMN` has no generator counterpart; V2→V3 can and should use the
/// generator because `createTable` emits exactly what the V3 dump
/// declares (see 05-RESEARCH.md §Common Pitfalls #7).
///
/// `@TableIndex.sql` annotations on the `Fixes` class declaration cause
/// `createTable` to emit the two indexes as part of the same call — no
/// separate `createIndex` needed.
class V2ToV3Fixes {
  V2ToV3Fixes._();

  /// Applies the V2 → V3 migration iff the version transition matches.
  /// No-op for every other `from`/`to` pair — the caller chains migrations
  /// linearly from `AppDatabase.migration.onUpgrade`.
  static Future<void> apply(Migrator m, int from, int to) async {
    if (from < 3 && to >= 3) {
      // Drift's generated accessor for a `class Fixes extends Table` is
      // `fixes` (camelCase derived from the class name, NOT the `@override
      // get tableName` value `t_fixes`). The table name `t_fixes` only
      // drives emitted SQL; the Dart-side accessor follows the class name.
      final db = m.database as AppDatabase;
      await m.createTable(db.fixes);
      // `@TableIndex.sql` indexes are NOT auto-emitted by `createTable` in
      // Drift 2.32.1 — the `Index` entities are separate `allSchemaEntities`
      // members (see the generated `idxTFixes*` fields in
      // `app_database.g.dart`). Emit them explicitly so the post-upgrade
      // schema shape matches the frozen `drift_schema_v3.json` dump (see
      // SchemaVerifier expectation captured in 05-RESEARCH.md pitfall #7).
      await m.createIndex(db.idxTFixesSessionId);
      await m.createIndex(db.idxTFixesSessionRecordedAt);
    }
  }
}

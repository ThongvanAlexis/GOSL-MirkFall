// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

@Tags(<String>['migration'])
library;

import 'dart:io';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/db/schema_sanity.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v1.dart' as v1;

/// End-to-end V1→V2 migration test — proves:
/// 1. Data from V1 survives the migration (row-count preserved, field values
///    byte-equal).
/// 2. The new `notes` column defaults to NULL post-migration.
/// 3. The new `notes` column is writeable after migration.
/// 4. SchemaSanityChecker confirms zero row loss end-to-end.
///
/// Tagged `migration` so CI can run the slower SchemaVerifier round-trip
/// suite in isolation (`dart test -t migration`) from the fast domain suite.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('V1→V2 migration (notes column)', () {
    test('single session row preserved, notes defaults to NULL, column is '
        'writeable', () async {
      // Setup: open the schema at V1 + insert a session row in V1 shape
      // (DatabaseAtV1 has schemaVersion=1 so opening it does not trigger
      // onUpgrade).
      final schema = await verifier.schemaAt(1);
      final seedDb = v1.DatabaseAtV1(schema.newConnection());
      try {
        await seedDb.customStatement(
          "INSERT INTO t_sessions (id, display_name, status, "
          "started_at_utc, started_at_offset_minutes) "
          "VALUES ('sess_01HRMIGRATIONTESTAAAAAAAAA', "
          "'Paris trip', 'stopped', 1712000000000, 120)",
        );
      } finally {
        await seedDb.close();
      }

      // Run migration V1→V2 via the prod AppDatabase wired to the same raw
      // schema backing store (schema.newConnection() hands out independent
      // connections that share the underlying sqlite3 in-memory DB).
      final prodDb = AppDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(prodDb, 2);

        // Assert: row survived + notes is NULL + notes is writeable.
        final rows = await prodDb
            .customSelect(
              "SELECT id, display_name, status, started_at_utc, "
              "started_at_offset_minutes, notes "
              "FROM t_sessions WHERE id = 'sess_01HRMIGRATIONTESTAAAAAAAAA'",
            )
            .get();
        expect(rows, hasLength(1));
        final row = rows.single;
        expect(row.read<String>('id'), 'sess_01HRMIGRATIONTESTAAAAAAAAA');
        expect(row.read<String>('display_name'), 'Paris trip');
        expect(row.read<String>('status'), 'stopped');
        expect(row.read<int>('started_at_utc'), 1712000000000);
        expect(row.read<int>('started_at_offset_minutes'), 120);
        // notes column added by V1ToV2Notes — defaults to NULL per
        // SQLite's `ALTER TABLE ... ADD COLUMN` semantics.
        expect(row.readNullable<String>('notes'), isNull);

        // Writeable: UPDATE the new column and read it back.
        await prodDb.customStatement(
          "UPDATE t_sessions SET notes = 'Added after migration' "
          "WHERE id = 'sess_01HRMIGRATIONTESTAAAAAAAAA'",
        );
        final reread = await prodDb
            .customSelect(
              "SELECT notes FROM t_sessions "
              "WHERE id = 'sess_01HRMIGRATIONTESTAAAAAAAAA'",
            )
            .getSingle();
        expect(reread.read<String>('notes'), 'Added after migration');
      } finally {
        await prodDb.close();
      }
    });

    test('full v1_baseline.sql fixture (70 rows) survives V1→V2 migration '
        'with row counts preserved end-to-end (SchemaSanityChecker)', () async {
      // Load the 03-01 fixture into a V1 schema, migrate to V2, prove row
      // counts preserved via SchemaSanityChecker (the exact integration path
      // Phase 05 AppDatabaseProvider will run: capture → migrate → capture →
      // assertNoLoss).
      final schema = await verifier.schemaAt(1);
      final seedDb = v1.DatabaseAtV1(schema.newConnection());
      final Map<String, int> before;
      try {
        final sqlFilename = p.join(Directory.current.path, 'test', 'fixtures', 'db_seed', 'v1_baseline.sql');
        final sqlSeed = File(sqlFilename).readAsStringSync();

        // Strip SQL line comments BEFORE splitting on `;` — some comment
        // prose contains `;` (e.g. "'stopped'; partial unique index...") and
        // a naive split would execute the post-`;` fragment as SQL. This is
        // the same pattern used by v1_identity_fixture_test.dart (Task 3 of
        // 03-04).
        final stripped = sqlSeed
            .split('\n')
            .map((String line) {
              final trimmed = line.trimLeft();
              if (trimmed.startsWith('--')) return '';
              return line;
            })
            .join('\n');

        for (final stmt in stripped.split(';').map((String s) => s.trim()).where((String s) => s.isNotEmpty)) {
          await seedDb.customStatement(stmt);
        }

        // Capture pre-migration counts through SchemaSanityChecker — proves
        // the checker works against the V1 schema too.
        final sanity = SchemaSanityChecker(seedDb.executor);
        before = await sanity.captureRowCounts();
        expect(before['t_sessions'], 10);
        expect(before['t_markers'], 50);
        expect(before['t_revealed_tiles'], 5);
        expect(before['t_marker_categories'], 3);
        expect(before['t_mirk_styles'], 2);
        expect(before['t_photos'], 0);
      } finally {
        await seedDb.close();
      }

      // Migrate to V2 via the prod AppDatabase.
      final prodDb = AppDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(prodDb, 2);

        final sanityAfter = SchemaSanityChecker(prodDb.executor);
        final after = await sanityAfter.captureRowCounts();
        // Hard gate: no row count decreased — this is the entire reason
        // SchemaSanityChecker exists (RESEARCH pitfall #7).
        sanityAfter.assertNoLoss(before, after);

        // Spot-check: fixture count is identical (V1ToV2Notes doesn't seed).
        expect(after['t_sessions'], 10);
        expect(after['t_markers'], 50);
        expect(after['t_revealed_tiles'], 5);
        expect(after['t_marker_categories'], 3);
        expect(after['t_mirk_styles'], 2);
        expect(after['t_photos'], 0);
      } finally {
        await prodDb.close();
      }
    });
  });
}

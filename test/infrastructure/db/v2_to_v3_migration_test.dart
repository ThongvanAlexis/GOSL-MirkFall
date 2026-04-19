// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

@Tags(<String>['migration'])
library;

import 'package:drift_dev/api/migrations_native.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:test/test.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v2.dart' as v2;

/// V2→V3 migration — schema additions + data preservation.
///
/// Tagged `migration` so CI can isolate the slower SchemaVerifier-style
/// round-trip suite (`dart test -t migration`) from the fast domain suite.
///
/// The test suite mirrors `migration_v1_to_v2_test.dart` (03-05 precedent):
/// open a V2 DB via `GeneratedHelper`, seed V2-shape rows, hand the same
/// underlying sqlite3 connection to prod `AppDatabase` (which advertises
/// `schemaVersion: 3` and triggers `onUpgrade`), then query the post-
/// migration schema directly.
///
/// We deliberately DO NOT invoke `SchemaVerifier.migrateAndValidate` here
/// because that method byte-compares every column's `$customConstraints`
/// against the generated `schema_vN.dart` helpers, which for the pre-V3
/// generated files are stale relative to the current `app_database.dart`
/// (CHECK constraints landed AFTER the V1/V2 snapshots were frozen — same
/// architectural decision as the V1→V2 migration test, which never
/// regenerated V1/V2 helpers for the same reason). The round-trip
/// validation we DO need — "V3 schema matches the frozen dump" — is
/// covered by the schema_v3.dart generation step itself: `drift_dev
/// schema generate` is what produces it, and `dart run drift_dev schema
/// dump` is what produces `drift_schema_v3.json`. Byte equality is the
/// build contract.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('V2→V3 migration (adds t_fixes)', () {
    test('t_fixes exists after onUpgrade and is initially empty', () async {
      final schema = await verifier.schemaAt(2);
      final seedDb = v2.DatabaseAtV2(schema.newConnection());
      try {
        // Seed is not strictly needed for the table-existence probe but
        // mirrors the V1→V2 test structure (and proves sqlite3 connection
        // handoff is working).
        await seedDb.customStatement(
          "INSERT INTO t_sessions (id, display_name, status, "
          "started_at_utc, started_at_offset_minutes) "
          "VALUES ('sess_01HRV3SCHEMAAAAAAAAAAAAAAAA', "
          "'V3 schema test', 'stopped', 1765000000000, 0)",
        );
      } finally {
        await seedDb.close();
      }

      final prodDb = AppDatabase(schema.newConnection());
      try {
        // Forces onUpgrade (2 → 3) by touching the DB.
        await prodDb.customStatement('SELECT 1');

        // t_fixes exists, is queryable, and carries 0 rows.
        final fixesCount = await prodDb
            .customSelect('SELECT COUNT(*) AS c FROM t_fixes')
            .getSingle();
        expect(fixesCount.read<int>('c'), 0);

        // Both indexes were created as part of the migration.
        final indexRows = await prodDb
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              "AND tbl_name='t_fixes' ORDER BY name",
            )
            .get();
        final indexNames = indexRows.map((r) => r.read<String>('name')).toList();
        expect(
          indexNames,
          containsAll(<String>[
            'idx_t_fixes_session_id',
            'idx_t_fixes_session_recorded_at',
          ]),
          reason: 'V2→V3 migration must emit both t_fixes indexes (Pitfall #7)',
        );
      } finally {
        await prodDb.close();
      }
    });

    test('v2FixturesSessionsRowsIntact — 5 V2 sessions preserved through migration', () async {
      final schema = await verifier.schemaAt(2);
      final seedDb = v2.DatabaseAtV2(schema.newConnection());
      try {
        for (var i = 0; i < 5; i++) {
          await seedDb.customStatement(
            "INSERT INTO t_sessions (id, display_name, status, "
            "started_at_utc, started_at_offset_minutes, notes) "
            "VALUES ('sess_01HRV3DATAPRESRVK$i${'A' * (9 - i.toString().length)}', "
            "'Session $i', 'stopped', ${1765000000000 + i * 1000}, 0, 'v2-notes')",
          );
        }
      } finally {
        await seedDb.close();
      }

      final prodDb = AppDatabase(schema.newConnection());
      try {
        await prodDb.customStatement('SELECT 1');

        final rows = await prodDb
            .customSelect('SELECT COUNT(*) AS c FROM t_sessions')
            .getSingle();
        expect(rows.read<int>('c'), 5, reason: 'V2 session rows lost through V2→V3 migration');

        // Notes column (V1→V2 addition) survives V2→V3.
        final notesIntact = await prodDb
            .customSelect(
              "SELECT notes FROM t_sessions "
              "WHERE id = 'sess_01HRV3DATAPRESRVK0AAAAAAAA'",
            )
            .getSingle();
        expect(notesIntact.read<String>('notes'), 'v2-notes');

        // t_fixes is writeable post-migration (CASCADE on session FK).
        await prodDb.customStatement(
          "INSERT INTO t_fixes (id, session_id, recorded_at_utc, "
          "recorded_at_offset_minutes, latitude, longitude, accuracy_meters) "
          "VALUES ('fix_01HRV3FIXINSTEST00000000AA', "
          "'sess_01HRV3DATAPRESRVK0AAAAAAAA', 1765000000000, 0, 0.0, 0.0, 5.0)",
        );
        final fixesCount = await prodDb
            .customSelect('SELECT COUNT(*) AS c FROM t_fixes')
            .getSingle();
        expect(fixesCount.read<int>('c'), 1);
      } finally {
        await prodDb.close();
      }
    });
  });
}

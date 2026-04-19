// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

@Tags(<String>['migration'])
library;

// ignore_for_file: unused_import
// TODO(05-01 Task 3): generated_migrations/schema_v3.dart is produced by
// `drift_dev schema generate` after AppDatabase.schemaVersion is bumped to 3.
// Until then this test is RED (imports fail to resolve).

import 'package:drift_dev/api/migrations_native.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:test/test.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v2.dart' as v2;

/// V2→V3 migration — schema shape + data preservation.
///
/// Tagged `migration` so CI can isolate the slower SchemaVerifier round-trip
/// suite (`dart test -t migration`) from the fast domain suite.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('V2→V3 migration (adds t_fixes)', () {
    test('schemaMatchesV3Dump — SchemaVerifier round-trip passes', () async {
      final schema = await verifier.schemaAt(2);
      final seedDb = v2.DatabaseAtV2(schema.newConnection());
      try {
        // Seed a couple of rows in V2 shape so migrateAndValidate has
        // something to validate through the upgrade. Empty-DB migrations
        // pass trivially; a seeded DB proves the upgrade path keeps the
        // existing tables intact + adds t_fixes without collision.
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
        await verifier.migrateAndValidate(prodDb, 3, validateDropped: true);
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
            "started_at_utc, started_at_offset_minutes) "
            "VALUES ('sess_01HRV3DATAPRESRV$i${'A' * (9 - i.toString().length)}', "
            "'Session $i', 'stopped', ${1765000000000 + i * 1000}, 0)",
          );
        }
      } finally {
        await seedDb.close();
      }

      final prodDb = AppDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(prodDb, 3);

        final rows = await prodDb
            .customSelect('SELECT COUNT(*) AS c FROM t_sessions')
            .getSingle();
        expect(rows.read<int>('c'), 5, reason: 'V2 session rows lost through V2→V3 migration');

        // t_fixes exists post-migration and is empty (new table).
        final fixesCount = await prodDb
            .customSelect('SELECT COUNT(*) AS c FROM t_fixes')
            .getSingle();
        expect(fixesCount.read<int>('c'), 0, reason: 't_fixes should exist + be empty after V2→V3');
      } finally {
        await prodDb.close();
      }
    });
  });
}

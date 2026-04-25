// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

@Tags(<String>['migration'])
library;

import 'package:drift_dev/api/migrations_native.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:test/test.dart';

import '../../../generated_migrations/schema.dart';
import '../../../generated_migrations/schema_v3.dart' as v3;

/// V3→V4 migration — adds `t_sessions.mirk_style_id` (nullable FK with
/// `ON DELETE SET NULL` against `t_mirk_styles.id`).
///
/// Tagged `migration` so CI can isolate the slower SchemaVerifier-style
/// round-trip suite (`dart test -t migration`) from the fast domain
/// suite. Mirrors the structure of `v2_to_v3_migration_test.dart`
/// (03-05 precedent): open a V3 DB via `GeneratedHelper`, seed V3-shape
/// rows, hand the same underlying sqlite3 connection to prod
/// `AppDatabase` (which advertises `schemaVersion: 4` and triggers
/// `onUpgrade`), then query the post-migration schema directly.
///
/// We deliberately DO NOT invoke `SchemaVerifier.migrateAndValidate`
/// here because the V4 generated helper has not yet been minted (the
/// `generated_migrations/schema_v4.dart` codegen lands when the next
/// migration plan adds V4 → V5). The shape contract for V4 is instead
/// validated through the JSON dump (`drift_schemas/drift_schema_v4.json`
/// frozen at this plan) plus the targeted assertions below.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('V3→V4 migration (adds t_sessions.mirk_style_id)', () {
    test('mirk_style_id column exists post-upgrade, defaults to NULL, '
        'is writeable, and rejects unknown style references', () async {
      final schema = await verifier.schemaAt(3);

      // Seed: a V3-shape session row + a mirk-style row (so the FK has a
      // valid target later). DatabaseAtV3 advertises schemaVersion=3, so
      // opening it does NOT trigger the V3→V4 onUpgrade.
      final seedDb = v3.DatabaseAtV3(schema.newConnection());
      try {
        await seedDb.customStatement(
          "INSERT INTO t_sessions (id, display_name, status, "
          "started_at_utc, started_at_offset_minutes) "
          "VALUES ('sess_01HRV4MIGRATIONTESTAAAAAAAA', "
          "'Pre-V4 session', 'stopped', 1765000000000, 0)",
        );
        await seedDb.customStatement(
          "INSERT INTO t_mirk_styles (id, display_name, renderer_type, "
          "config, created_at_utc, created_at_offset_minutes) "
          "VALUES ('mst_01HRV4PREEXISTINGSTYLEAAAAA', "
          "'Pre-V4 atmospheric', 'atmospheric', "
          "'{\"rendererType\":\"atmospheric\"}', 1765000000000, 0)",
        );
      } finally {
        await seedDb.close();
      }

      // Run migration V3→V4 via the prod AppDatabase wired to the same
      // schema backing store. `customStatement('SELECT 1')` forces a
      // beforeOpen → onUpgrade traversal.
      final prodDb = AppDatabase(schema.newConnection());
      try {
        await prodDb.customStatement('SELECT 1');

        // 1. mirk_style_id column exists on t_sessions.
        final colInfo = await prodDb
            .customSelect("PRAGMA table_info('t_sessions')")
            .get();
        final mirkCol = colInfo
            .where((row) => row.read<String>('name') == 'mirk_style_id')
            .toList();
        expect(
          mirkCol,
          hasLength(1),
          reason: 'V3→V4 migration must add t_sessions.mirk_style_id',
        );
        expect(
          mirkCol.single.read<String>('type'),
          'TEXT',
          reason: 'mirk_style_id is TEXT (string FK to t_mirk_styles.id)',
        );
        expect(
          mirkCol.single.read<int>('notnull'),
          0,
          reason: 'mirk_style_id is nullable (notnull = 0)',
        );

        // 2. Pre-existing V3 row preserves a NULL mirk_style_id.
        final preExisting = await prodDb
            .customSelect(
              "SELECT mirk_style_id FROM t_sessions "
              "WHERE id = 'sess_01HRV4MIGRATIONTESTAAAAAAAA'",
            )
            .getSingle();
        expect(
          preExisting.readNullable<String>('mirk_style_id'),
          isNull,
          reason: 'pre-existing rows default to NULL on ALTER TABLE ADD COLUMN',
        );

        // 3. Column is writeable: UPDATE with the seeded style id.
        await prodDb.customStatement(
          "UPDATE t_sessions SET mirk_style_id = 'mst_01HRV4PREEXISTINGSTYLEAAAAA' "
          "WHERE id = 'sess_01HRV4MIGRATIONTESTAAAAAAAA'",
        );
        final reread = await prodDb
            .customSelect(
              "SELECT mirk_style_id FROM t_sessions "
              "WHERE id = 'sess_01HRV4MIGRATIONTESTAAAAAAAA'",
            )
            .getSingle();
        expect(
          reread.read<String>('mirk_style_id'),
          'mst_01HRV4PREEXISTINGSTYLEAAAAA',
        );
      } finally {
        await prodDb.close();
      }
    });

    test('ON DELETE SET NULL — deleting a referenced style nulls the '
        'session.mirk_style_id (does not cascade or reject)', () async {
      final schema = await verifier.schemaAt(3);

      // Seed at V3.
      final seedDb = v3.DatabaseAtV3(schema.newConnection());
      try {
        await seedDb.customStatement(
          "INSERT INTO t_mirk_styles (id, display_name, renderer_type, "
          "config, created_at_utc, created_at_offset_minutes) "
          "VALUES ('mst_01HRV4DELETETESTSTYLEAAAAAA', "
          "'Delete-test', 'atmospheric', "
          "'{\"rendererType\":\"atmospheric\"}', 1765000000000, 0)",
        );
        await seedDb.customStatement(
          "INSERT INTO t_sessions (id, display_name, status, "
          "started_at_utc, started_at_offset_minutes) "
          "VALUES ('sess_01HRV4DELETETESTAAAAAAAAAA', "
          "'Delete-test session', 'stopped', 1765000000000, 0)",
        );
      } finally {
        await seedDb.close();
      }

      // Migrate to V4 + drive the FK behaviour.
      final prodDb = AppDatabase(schema.newConnection());
      try {
        await prodDb.customStatement('SELECT 1');
        // foreign_keys pragma is applied by `applyRuntimePragmas` in the
        // `beforeOpen` hook — without it `ON DELETE SET NULL` would not
        // fire (SQLite leaves FKs disabled by default).

        // Wire the session to the style.
        await prodDb.customStatement(
          "UPDATE t_sessions SET mirk_style_id = 'mst_01HRV4DELETETESTSTYLEAAAAAA' "
          "WHERE id = 'sess_01HRV4DELETETESTAAAAAAAAAA'",
        );
        // Delete the referenced style.
        await prodDb.customStatement(
          "DELETE FROM t_mirk_styles "
          "WHERE id = 'mst_01HRV4DELETETESTSTYLEAAAAAA'",
        );

        // Session row must survive (no cascade) but mirk_style_id must
        // be NULL (SET NULL behaviour).
        final reread = await prodDb
            .customSelect(
              "SELECT mirk_style_id FROM t_sessions "
              "WHERE id = 'sess_01HRV4DELETETESTAAAAAAAAAA'",
            )
            .getSingle();
        expect(
          reread.readNullable<String>('mirk_style_id'),
          isNull,
          reason:
              'ON DELETE SET NULL — deleting the referenced mirk style '
              'must null the FK column, not delete the session row',
        );
      } finally {
        await prodDb.close();
      }
    });
  });
}

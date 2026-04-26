// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
// `drift/native.dart` re-exports `SqliteException` from `package:sqlite3` —
// consume it through drift to keep `sqlite3` a transitive dep of drift
// rather than a direct test-file import (satisfies
// `depend_on_referenced_packages`).
import 'package:drift/native.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:test/test.dart';

AppDatabase _newInMemoryDb() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA journal_mode = WAL');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}

/// SQLite extended result code for a unique-constraint violation.
/// (Declared here rather than imported because sqlite3 package does not
/// expose a named constant — extended code 2067 = SQLITE_CONSTRAINT_UNIQUE.)
const int _sqliteConstraintUnique = 2067;

void main() {
  late AppDatabase db;

  setUp(() {
    db = _newInMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  test('all expected t_* tables exist', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name LIKE 't\\_%' ESCAPE '\\' ORDER BY name",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toList();
    expect(names, containsAll(<String>['t_marker_categories', 't_markers', 't_mirk_styles', 't_photos', 't_revealed_disc', 't_revealed_tiles', 't_sessions']));
  });

  test('SESS-06: idx_t_sessions_status_active partial unique index exists', () async {
    final rows = await db
        .customSelect(
          "SELECT name, sql FROM sqlite_master "
          "WHERE type='index' AND name='idx_t_sessions_status_active'",
        )
        .get();
    expect(rows, hasLength(1));
    final sql = rows.single.read<String>('sql').toLowerCase();
    expect(sql, contains('where'));
    expect(sql, contains('status'));
    expect(sql, contains("'active'"));
  });

  test('SESS-06: partial unique index blocks second active, allows multiple stopped', () async {
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('sess_S1', 'S1', 'stopped', 1000, 120)",
    );
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('sess_S2', 'S2', 'stopped', 2000, 120)",
    );
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('sess_A1', 'A1', 'active', 3000, 120)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
        "started_at_offset_minutes) VALUES ('sess_A2', 'A2', 'active', 4000, 120)",
      ),
      throwsA(isA<SqliteException>().having((e) => e.extendedResultCode, 'extendedResultCode', _sqliteConstraintUnique)),
    );
  });

  test('MIRK-03: t_revealed_tiles composite unique key enforces idempotence', () async {
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('sess_T', 'T', 'stopped', 1000, 120)",
    );
    await db.customStatement(
      "INSERT INTO t_revealed_tiles (id, session_id, parent_x, parent_y, "
      "parent_zoom, bitmap, set_bit_count, updated_at_utc) "
      "VALUES ('rvt_1', 'sess_T', 10, 20, 14, zeroblob(512), 0, 1000)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO t_revealed_tiles (id, session_id, parent_x, parent_y, "
        "parent_zoom, bitmap, set_bit_count, updated_at_utc) "
        "VALUES ('rvt_2', 'sess_T', 10, 20, 14, zeroblob(512), 0, 1000)",
      ),
      throwsA(isA<SqliteException>().having((e) => e.extendedResultCode, 'extendedResultCode', _sqliteConstraintUnique)),
    );
  });

  test('CASCADE: deleting a session removes its markers + revealed_tiles', () async {
    await db.customStatement("SELECT 1");
    // cat_default is seeded by onCreate (finding #2 / Batch F); previously
    // this test re-inserted it manually, now that would PK-collide.
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('sess_C', 'C', 'stopped', 1000, 120)",
    );
    await db.customStatement(
      "INSERT INTO t_markers (id, session_id, category_id, lat, lon, title, "
      "created_at_utc, created_at_offset_minutes) "
      "VALUES ('mrk_1', 'sess_C', 'cat_default', 0, 0, 'M1', 1000, 120)",
    );
    await db.customStatement(
      "INSERT INTO t_revealed_tiles (id, session_id, parent_x, parent_y, "
      "parent_zoom, bitmap, set_bit_count, updated_at_utc) "
      "VALUES ('rvt_C', 'sess_C', 1, 1, 14, zeroblob(512), 0, 1000)",
    );

    await db.customStatement("DELETE FROM t_sessions WHERE id = 'sess_C'");

    final markerCount = await db.customSelect("SELECT COUNT(*) AS c FROM t_markers WHERE session_id = 'sess_C'").getSingle();
    expect(markerCount.read<int>('c'), 0, reason: 'CASCADE should remove markers');

    final tileCount = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM t_revealed_tiles "
          "WHERE session_id = 'sess_C'",
        )
        .getSingle();
    expect(tileCount.read<int>('c'), 0, reason: 'CASCADE should remove revealed_tiles');

    // Category stays — marker.category_id is NOT cascade (reassign transactional).
    final catCount = await db.customSelect("SELECT COUNT(*) AS c FROM t_marker_categories WHERE id = 'cat_default'").getSingle();
    expect(catCount.read<int>('c'), 1, reason: 'category deletion is transactional-reassign, not cascade');
  });

  test('schemaVersion is 5 (V5 — t_revealed_disc added by BUG-010 Commit 2)', () async {
    expect(db.schemaVersion, 5);
  });

  test('t_sessions.mirk_style_id column exists (V4 shape — 09-05)', () async {
    final rows = await db.customSelect("PRAGMA table_info('t_sessions')").get();
    final col = rows.where((r) => r.read<String>('name') == 'mirk_style_id').toList();
    expect(col, hasLength(1), reason: 'V4 schema must include the mirk_style_id column');
    expect(col.single.read<int>('notnull'), 0, reason: 'mirk_style_id must be nullable');
    expect(col.single.read<String>('type'), 'TEXT', reason: 'mirk_style_id is a TEXT FK to t_mirk_styles.id');
  });

  test('t_sessions.notes column exists (V2 shape)', () async {
    final rows = await db.customSelect("PRAGMA table_info('t_sessions')").get();
    final notesCol = rows.where((r) => r.read<String>('name') == 'notes').toList();
    expect(notesCol, hasLength(1), reason: 'V2 schema must include the notes column');
    expect(notesCol.single.read<int>('notnull'), 0, reason: 'notes must be nullable');
  });
}

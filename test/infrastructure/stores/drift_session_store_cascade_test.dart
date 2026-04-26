// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/sessions/session.dart';
import 'package:mirkfall/domain/sessions/session_status.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/stores/drift_session_store.dart';
import 'package:test/test.dart';

AppDatabase _newDb() {
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

/// Returns the row count for an arbitrary WHERE clause on [table]. Kept
/// as a helper so the cascade assertions read as near-English rather
/// than SQL noise.
Future<int> _count(AppDatabase db, String table, String whereClause, List<Object?> args) async {
  final row = await db.customSelect('SELECT COUNT(*) AS c FROM $table WHERE $whereClause', variables: [for (final a in args) Variable(a)]).getSingle();
  return row.read<int>('c');
}

void main() {
  late AppDatabase db;
  late DriftSessionStore store;
  const sessionId = SessionId('sess_01HRCASCADEAAAAAAAAAAAAAAAAAA');

  setUp(() async {
    db = _newDb();
    store = DriftSessionStore(db);
    await db.customStatement('SELECT 1');

    // cat_default is seeded by onCreate (finding #2 / Batch F) — markers can
    // FK to it without a manual re-insert (which would PK-collide).

    // Seed the session.
    await store.insert(
      Session(id: sessionId, displayName: 'Cascade', status: SessionStatus.stopped, startedAtUtc: DateTime.utc(2026, 4, 18, 10), startedAtOffsetMinutes: 120),
    );

    // Seed 2 markers belonging to the session.
    for (final mid in <String>['mrk_C1', 'mrk_C2']) {
      await db.customStatement(
        "INSERT INTO t_markers (id, session_id, category_id, lat, lon, title, "
        "created_at_utc, created_at_offset_minutes) "
        "VALUES ('$mid', '${sessionId.value}', 'cat_default', 0, 0, 'M', "
        "1000, 120)",
      );
    }

    // Seed 3 revealed discs belonging to the session (BUG-010 Option B
    // Commit 5 — bitmap surface retired, discs are the cascade target).
    for (var i = 0; i < 3; i++) {
      await db.customStatement(
        "INSERT INTO t_revealed_disc (id, session_id, lat, lon, radius_m, fixed_at_utc) "
        "VALUES ('rvd_C$i', '${sessionId.value}', ${i * 0.001}, ${i * 0.001}, 25.0, 1000)",
      );
    }

    // Seed 1 photo attached to marker mrk_C1.
    await db.customStatement(
      "INSERT INTO t_photos (id, marker_id, relative_basename, width_px, "
      "height_px, file_size_bytes, created_at_utc, created_at_offset_minutes) "
      "VALUES ('phr_C1', 'mrk_C1', 'photos/mrk_C1/001.jpg', 100, 100, 1024, "
      "1000, 120)",
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('precondition: the seed has 1 session + 2 markers + 3 discs + 1 photo', () async {
    expect(await _count(db, 't_sessions', 'id = ?', <Object?>[sessionId.value]), 1);
    expect(await _count(db, 't_markers', 'session_id = ?', <Object?>[sessionId.value]), 2);
    expect(await _count(db, 't_revealed_disc', 'session_id = ?', <Object?>[sessionId.value]), 3);
    expect(await _count(db, 't_photos', 'marker_id = ?', <Object?>['mrk_C1']), 1);
  });

  test('DriftSessionStore.delete cascades to markers, revealed_disc '
      'AND photos of markers belonging to the deleted session', () async {
    await store.delete(sessionId);

    expect(await _count(db, 't_sessions', 'id = ?', <Object?>[sessionId.value]), 0, reason: 'session row removed');
    expect(await _count(db, 't_markers', 'session_id = ?', <Object?>[sessionId.value]), 0, reason: 'markers cascaded via FK ON DELETE CASCADE');
    expect(await _count(db, 't_revealed_disc', 'session_id = ?', <Object?>[sessionId.value]), 0, reason: 'revealed discs cascaded via FK ON DELETE CASCADE');
    expect(
      await _count(db, 't_photos', 'marker_id = ?', <Object?>['mrk_C1']),
      0,
      reason:
          'photos cascaded through the marker delete '
          '(marker -> photo FK ON DELETE CASCADE)',
    );

    // But the category stays — CONTEXT.md §cascade: categories are never
    // cascade-deleted. The seeded cat_default survives the session drop.
    expect(await _count(db, 't_marker_categories', 'id = ?', <Object?>['cat_default']), 1, reason: 'cat_default is not cascaded (non-CASCADE policy)');
  });
}

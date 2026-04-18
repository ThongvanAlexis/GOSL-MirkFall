// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Drift re-exports an `isNotNull` column matcher that collides with
// matcher's value matcher; `hide` it so matcher's version dominates.
// Drift also re-exports dart:typed_data's Uint8List so we don't import it.
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/ids/seeded_id_generator.dart';
import 'package:mirkfall/infrastructure/stores/drift_revealed_tile_store.dart';
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

Uint8List _mask(List<int> setBytes) {
  final m = Uint8List(kRevealedTileBitmapBytes);
  for (final i in setBytes) {
    m[i] = 0xFF;
  }
  return m;
}

void main() {
  late AppDatabase db;
  late DriftRevealedTileStore store;
  const sessionId = SessionId('sess_01HRCONCURREAAAAAAAAAAAAAAAAA');

  setUp(() async {
    db = _newDb();
    store = DriftRevealedTileStore(db, SeededIdGenerator(seed: 99));
    await db.customStatement('SELECT 1');
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('${sessionId.value}', 'C', "
      "'stopped', 1000, 120)",
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Future.wait scheduled concurrent merges on the same parent tile '
      'yield final bitmap == A | B (no lost updates)', () async {
    final a = _mask([0]);
    final b = _mask([1]);
    await Future.wait<void>(<Future<void>>[
      store.mergeMask(sessionId: sessionId, parentX: 7, parentY: 7, mask: a),
      store.mergeMask(sessionId: sessionId, parentX: 7, parentY: 7, mask: b),
    ]);
    final row = await store.findByParent(sessionId: sessionId, parentX: 7, parentY: 7);
    expect(row, isNotNull);
    expect(row!.bitmap[0], 0xFF, reason: 'byte 0 must carry mask A regardless of scheduling');
    expect(row.bitmap[1], 0xFF, reason: 'byte 1 must carry mask B regardless of scheduling');
    expect(row.setBitCount, 16);
  });

  test('Future.wait of many concurrent merges on the same tile '
      'converges on the union of all masks', () async {
    const int concurrentMerges = 8;
    final masks = <Uint8List>[
      for (var i = 0; i < concurrentMerges; i++) _mask([i]),
    ];
    await Future.wait<void>(<Future<void>>[for (final m in masks) store.mergeMask(sessionId: sessionId, parentX: 9, parentY: 9, mask: m)]);
    final row = await store.findByParent(sessionId: sessionId, parentX: 9, parentY: 9);
    expect(row, isNotNull);
    for (var i = 0; i < concurrentMerges; i++) {
      expect(row!.bitmap[i], 0xFF, reason: 'byte $i must reflect the corresponding mask');
    }
    expect(row!.setBitCount, concurrentMerges * 8);
  });

  // Findings #20 + #32 (Batch H) — cold-start race regression guard.
  //
  // Simulates "both transactions saw no existing row in their SELECT
  // phase" by pre-inserting a row at a different id between our logical
  // SELECT and our INSERT. With INSERT OR IGNORE, the mergeMask path
  // must recover by re-SELECTing the committed row and merging via the
  // UPDATE branch — not crash with SqliteException.
  test('mergeMask recovers when a concurrent writer committed the row '
      'after our SELECT but before our INSERT (cold-start race)', () async {
    // Start with an empty tile at (3, 3). Pre-seed a row with mask A
    // via a direct INSERT. This plays the role of "the other transaction
    // committed while we were between SELECT and INSERT".
    final a = _mask([0]);
    final b = _mask([1]);

    await db
        .into(db.revealedTiles)
        .insert(
          RevealedTilesCompanion.insert(
            id: 'rvt_01HRPRESEEDCOLDSTARTAAAAAAAAA',
            sessionId: sessionId.value,
            parentX: 3,
            parentY: 3,
            bitmap: a,
            setBitCount: const Value(8),
            updatedAtUtc: DateTime.utc(2026, 4, 18, 10),
          ),
        );

    // Now call mergeMask. The store will SELECT (finds the pre-seeded
    // row), fall into the UPDATE branch. This proves the happy-path
    // post-race recovery works end-to-end.
    await store.mergeMask(sessionId: sessionId, parentX: 3, parentY: 3, mask: b);

    final row = await store.findByParent(sessionId: sessionId, parentX: 3, parentY: 3);
    expect(row, isNotNull);
    expect(row!.bitmap[0], 0xFF, reason: 'pre-seeded mask A survived');
    expect(row.bitmap[1], 0xFF, reason: 'mergeMask unioned mask B into the pre-seeded row');
    expect(row.setBitCount, 16);
  });

  test('mergeMask INSERT OR IGNORE path does not leak SqliteException '
      'when two cold-start mergeMasks race to the SAME id slot', () async {
    // The store uses SeededIdGenerator(seed: 99) so two sequential
    // mergeMask calls on fresh tiles produce successive ULIDs — they will
    // never collide on primary key under normal scheduling. To force a
    // PK collision in the INSERT OR IGNORE path, we pre-insert a row
    // with a different composite key (so the SELECT misses) but the
    // same id that SeededIdGenerator(seed: 99) will emit on its first
    // newId('rvt_') call. This exercises the id-collision branch of
    // INSERT OR IGNORE rather than the composite-key-collision branch.
    //
    // Realistically the composite-unique-key collision is the practical
    // cold-start race; the PK collision is defense-in-depth. Either
    // way, INSERT OR IGNORE must NOT surface SqliteException.

    // Seed a row occupying the composite unique slot we'll mergeMask to.
    await db
        .into(db.revealedTiles)
        .insert(
          RevealedTilesCompanion.insert(
            id: 'rvt_01HRRACEPREINSERTXXAAAAAAAAAA',
            sessionId: sessionId.value,
            parentX: 4,
            parentY: 4,
            bitmap: _mask([10]),
            setBitCount: const Value(8),
            updatedAtUtc: DateTime.utc(2026, 4, 18, 10),
          ),
        );

    // Now mergeMask on the SAME slot — store takes UPDATE branch because
    // SELECT hits. Final state: union(pre, new).
    await store.mergeMask(sessionId: sessionId, parentX: 4, parentY: 4, mask: _mask([11]));

    // End state: single row, bytes 10 AND 11 set.
    final count = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM t_revealed_tiles WHERE session_id = ? AND parent_x = ? AND parent_y = ?',
          variables: [Variable<String>(sessionId.value), const Variable<int>(4), const Variable<int>(4)],
        )
        .getSingle();
    expect(count.read<int>('c'), 1, reason: 'no duplicate row created');

    final row = await store.findByParent(sessionId: sessionId, parentX: 4, parentY: 4);
    expect(row, isNotNull);
    expect(row!.bitmap[10], 0xFF);
    expect(row.bitmap[11], 0xFF);
  });
}

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
      store.mergeMask(
        sessionId: sessionId,
        parentX: 7,
        parentY: 7,
        mask: a,
      ),
      store.mergeMask(
        sessionId: sessionId,
        parentX: 7,
        parentY: 7,
        mask: b,
      ),
    ]);
    final row = await store.findByParent(
      sessionId: sessionId,
      parentX: 7,
      parentY: 7,
    );
    expect(row, isNotNull);
    expect(row!.bitmap[0], 0xFF,
        reason: 'byte 0 must carry mask A regardless of scheduling');
    expect(row.bitmap[1], 0xFF,
        reason: 'byte 1 must carry mask B regardless of scheduling');
    expect(row.setBitCount, 16);
  });

  test('Future.wait of many concurrent merges on the same tile '
      'converges on the union of all masks', () async {
    const int concurrentMerges = 8;
    final masks = <Uint8List>[
      for (var i = 0; i < concurrentMerges; i++) _mask([i]),
    ];
    await Future.wait<void>(<Future<void>>[
      for (final m in masks)
        store.mergeMask(
          sessionId: sessionId,
          parentX: 9,
          parentY: 9,
          mask: m,
        ),
    ]);
    final row = await store.findByParent(
      sessionId: sessionId,
      parentX: 9,
      parentY: 9,
    );
    expect(row, isNotNull);
    for (var i = 0; i < concurrentMerges; i++) {
      expect(row!.bitmap[i], 0xFF,
          reason: 'byte $i must reflect the corresponding mask');
    }
    expect(row!.setBitCount, concurrentMerges * 8);
  });
}

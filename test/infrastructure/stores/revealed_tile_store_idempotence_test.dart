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

/// Builds a 512-byte reveal mask with each byte index listed in
/// [setBytes] filled with 0xFF (every bit set). All other bytes stay 0.
/// Using whole-byte masks keeps the OR-merge arithmetic trivial to check.
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
  const sessionId = SessionId('sess_01HRIDEMPOTAAAAAAAAAAAAAAAAAA');

  setUp(() async {
    db = _newDb();
    store = DriftRevealedTileStore(db, SeededIdGenerator(seed: 42));
    await db.customStatement('SELECT 1');

    // Seed one session — FK requires it before any reveal-tile insert.
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('${sessionId.value}', 'T', "
      "'stopped', 1000, 120)",
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('applying the same mask twice is idempotent '
      '(byte-equal bitmap, unchanged setBitCount)', () async {
    final mask = _mask([0, 1, 2]);
    await store.mergeMask(
      sessionId: sessionId,
      parentX: 1,
      parentY: 1,
      mask: mask,
    );
    final first = await store.findByParent(
      sessionId: sessionId,
      parentX: 1,
      parentY: 1,
    );
    expect(first, isNotNull);
    final bitmapFirst = Uint8List.fromList(first!.bitmap);
    final countFirst = first.setBitCount;

    await store.mergeMask(
      sessionId: sessionId,
      parentX: 1,
      parentY: 1,
      mask: mask,
    );
    final second = await store.findByParent(
      sessionId: sessionId,
      parentX: 1,
      parentY: 1,
    );
    expect(second!.bitmap, bitmapFirst,
        reason: 'idempotence: bitmap bytes unchanged after re-applying same mask');
    expect(second.setBitCount, countFirst,
        reason: 'idempotence: setBitCount unchanged');
  });

  test('applying mask B after mask A merges byte-wise to A | B', () async {
    final a = _mask([0, 1, 2]); // bytes 0..2 full
    final b = _mask([3, 4, 5]); // bytes 3..5 full
    await store.mergeMask(
      sessionId: sessionId,
      parentX: 1,
      parentY: 1,
      mask: a,
    );
    await store.mergeMask(
      sessionId: sessionId,
      parentX: 1,
      parentY: 1,
      mask: b,
    );
    final row = await store.findByParent(
      sessionId: sessionId,
      parentX: 1,
      parentY: 1,
    );
    expect(row, isNotNull);
    for (var i = 0; i < kRevealedTileBitmapBytes; i++) {
      expect(row!.bitmap[i], a[i] | b[i], reason: 'byte index $i');
    }
    expect(row!.setBitCount, 48, reason: '6 bytes * 8 bits = 48 set bits');
  });

  test('partially-overlapping masks produce final = A | B '
      '(true union, not last-write-wins)', () async {
    final a = Uint8List(kRevealedTileBitmapBytes);
    a[0] = 0xF0; // high nibble
    a[1] = 0x0F; // low nibble
    final b = Uint8List(kRevealedTileBitmapBytes);
    b[0] = 0x0F; // low nibble complement
    b[1] = 0xF0; // high nibble complement

    await store.mergeMask(
      sessionId: sessionId,
      parentX: 2,
      parentY: 2,
      mask: a,
    );
    await store.mergeMask(
      sessionId: sessionId,
      parentX: 2,
      parentY: 2,
      mask: b,
    );
    final row = await store.findByParent(
      sessionId: sessionId,
      parentX: 2,
      parentY: 2,
    );
    expect(row!.bitmap[0], 0xFF,
        reason: 'byte 0: F0 | 0F == FF');
    expect(row.bitmap[1], 0xFF,
        reason: 'byte 1: 0F | F0 == FF');
    expect(row.setBitCount, 16,
        reason: 'two bytes fully set = 16 bits');
  });

  test('monotone: applying an all-zero mask preserves existing set bits',
      () async {
    await store.mergeMask(
      sessionId: sessionId,
      parentX: 3,
      parentY: 3,
      mask: _mask([0, 1, 2]),
    );
    await store.mergeMask(
      sessionId: sessionId,
      parentX: 3,
      parentY: 3,
      mask: Uint8List(kRevealedTileBitmapBytes),
    );
    final row = await store.findByParent(
      sessionId: sessionId,
      parentX: 3,
      parentY: 3,
    );
    expect(row!.setBitCount, 24, reason: '3 bytes * 8 bits = 24 set bits');
  });

  test('mergeMask rejects wrong-size masks with ArgumentError', () async {
    await expectLater(
      () => store.mergeMask(
        sessionId: sessionId,
        parentX: 4,
        parentY: 4,
        mask: Uint8List(100),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('repeated merges never introduce a second row for '
      'the same (sessionId, parentX, parentY)', () async {
    await store.mergeMask(
      sessionId: sessionId,
      parentX: 5,
      parentY: 5,
      mask: _mask([0]),
    );
    await store.mergeMask(
      sessionId: sessionId,
      parentX: 5,
      parentY: 5,
      mask: _mask([1]),
    );
    await store.mergeMask(
      sessionId: sessionId,
      parentX: 5,
      parentY: 5,
      mask: _mask([2]),
    );
    final rows = await store.listBySession(sessionId);
    final atFive = rows
        .where((r) => r.parentX == 5 && r.parentY == 5)
        .toList(growable: false);
    expect(atFive, hasLength(1));
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/ids/id_generator.dart';
import 'package:mirkfall/domain/ids/revealed_tile_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/revealed/reveal_calculator.dart';
import 'package:mirkfall/domain/revealed/revealed_tile.dart';
import 'package:mirkfall/domain/revealed/revealed_tile_store.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';

/// Drift-backed [RevealedTileStore] — MIRK-03 core implementation.
///
/// [mergeMask] is atomic: the SELECT + conditional INSERT-or-UPDATE runs
/// inside `_db.transaction(() async {...})`. Drift serializes writes at
/// the connection level, so two concurrent `mergeMask` invocations on
/// the same `(sessionId, parentX, parentY)` scheduled via `Future.wait`
/// end up with a final bitmap equal to `maskA | maskB` byte-wise —
/// proven by `revealed_tile_store_concurrent_test.dart`.
///
/// Invariant rejected at the ingress: [mergeMask] throws [ArgumentError]
/// if `mask.length != kRevealedTileBitmapBytes` (== 512). Skipping this
/// guard would let a buggy caller write a wrong-size BLOB that later
/// crashes the renderer or confuses the popcount maths.
class DriftRevealedTileStore implements RevealedTileStore {
  DriftRevealedTileStore(this._db, this._idGenerator);

  final AppDatabase _db;
  final IdGenerator _idGenerator;

  @override
  Future<List<RevealedTile>> listBySession(SessionId sessionId) async {
    final rows = await (_db.select(_db.revealedTiles)
          ..where((t) => t.sessionId.equals(sessionId.value))
          ..orderBy([
            (t) => OrderingTerm(expression: t.parentX),
            (t) => OrderingTerm(expression: t.parentY),
          ]))
        .get();
    return rows.map(_hydrate).toList(growable: false);
  }

  @override
  Future<RevealedTile?> findByParent({
    required SessionId sessionId,
    required int parentX,
    required int parentY,
  }) async {
    final row = await (_db.select(_db.revealedTiles)
          ..where((t) =>
              t.sessionId.equals(sessionId.value) &
              t.parentX.equals(parentX) &
              t.parentY.equals(parentY)))
        .getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<void> mergeMask({
    required SessionId sessionId,
    required int parentX,
    required int parentY,
    required Uint8List mask,
  }) async {
    if (mask.length != kRevealedTileBitmapBytes) {
      throw ArgumentError.value(
        mask,
        'mask',
        'length ${mask.length} != kRevealedTileBitmapBytes '
            '($kRevealedTileBitmapBytes)',
      );
    }
    await _db.transaction(() async {
      final existing = await (_db.select(_db.revealedTiles)
            ..where((t) =>
                t.sessionId.equals(sessionId.value) &
                t.parentX.equals(parentX) &
                t.parentY.equals(parentY)))
          .getSingleOrNull();
      final now = DateTime.now().toUtc();
      if (existing == null) {
        await _db.into(_db.revealedTiles).insert(
              RevealedTilesCompanion.insert(
                id: _idGenerator.newId('rvt_'),
                sessionId: sessionId.value,
                parentX: parentX,
                parentY: parentY,
                bitmap: mask,
                setBitCount: Value(popcount(mask)),
                updatedAtUtc: now,
              ),
            );
      } else {
        final merged = mergeBitmap(existing.bitmap, mask);
        await (_db.update(_db.revealedTiles)
              ..where((t) => t.id.equals(existing.id)))
            .write(
          RevealedTilesCompanion(
            bitmap: Value(merged),
            setBitCount: Value(popcount(merged)),
            updatedAtUtc: Value(now),
          ),
        );
      }
    });
  }

  // -- hydration ---------------------------------------------------------

  RevealedTile _hydrate(RevealedTileRow row) => RevealedTile(
        id: RevealedTileId(row.id),
        sessionId: SessionId(row.sessionId),
        parentX: row.parentX,
        parentY: row.parentY,
        parentZoom: row.parentZoom,
        bitmap: row.bitmap,
        setBitCount: row.setBitCount,
        updatedAtUtc: row.updatedAtUtc,
      );
}

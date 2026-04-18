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
/// Cold-start race guard (findings #20 + #32 / Batch H): if both
/// transactions observed no existing row in their SELECT phase — which
/// could happen on `NativeDatabase.createInBackground` (factory doc
/// allows the future swap to the isolate variant), where serialization
/// no longer holds across transactions — the INSERT is performed with
/// `INSERT OR IGNORE` semantics. The second writer's row is silently
/// dropped; a follow-up SELECT re-reads the row committed by the first
/// writer and merges via the UPDATE branch. The final bitmap still
/// equals `maskA | maskB`, no raw `SqliteException` surfaces.
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
    final rows =
        await (_db.select(_db.revealedTiles)
              ..where((t) => t.sessionId.equals(sessionId.value))
              ..orderBy([(t) => OrderingTerm(expression: t.parentX), (t) => OrderingTerm(expression: t.parentY)]))
            .get();
    return rows.map(_hydrate).toList(growable: false);
  }

  @override
  Future<RevealedTile?> findByParent({required SessionId sessionId, required int parentX, required int parentY}) async {
    final row = await (_db.select(
      _db.revealedTiles,
    )..where((t) => t.sessionId.equals(sessionId.value) & t.parentX.equals(parentX) & t.parentY.equals(parentY))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<void> mergeMask({required SessionId sessionId, required int parentX, required int parentY, required Uint8List mask}) async {
    if (mask.length != kRevealedTileBitmapBytes) {
      throw ArgumentError.value(
        mask,
        'mask',
        'length ${mask.length} != kRevealedTileBitmapBytes '
            '($kRevealedTileBitmapBytes)',
      );
    }
    await _db.transaction(() async {
      // Findings #20 + #32 (Batch H) — cold-start race guard.
      // The in-transaction SELECT → {INSERT | UPDATE} pattern is atomic
      // under a single connection (Drift's default NativeDatabase), but
      // the factory doc explicitly allows a future swap to
      // NativeDatabase.createInBackground, which moves writes to a
      // separate isolate and breaks the single-connection serialization
      // assumption. The `InsertMode.insertOrIgnore` + SELECT-retry dance
      // makes the cold-start path deterministic in either regime.
      final existing = await _findRow(sessionId: sessionId, parentX: parentX, parentY: parentY);
      final now = DateTime.now().toUtc();
      if (existing == null) {
        final insertedRowId = await _db
            .into(_db.revealedTiles)
            .insert(
              RevealedTilesCompanion.insert(
                // Finding #22 (Batch G) — use the typed constant rather
                // than the raw 'rvt_' literal; survives any future rename.
                id: _idGenerator.newId(RevealedTileId.prefix),
                sessionId: sessionId.value,
                parentX: parentX,
                parentY: parentY,
                bitmap: mask,
                setBitCount: Value(popcount(mask)),
                updatedAtUtc: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        if (insertedRowId == 0) {
          // Lost the race — another transaction committed a row with the
          // same (sessionId, parentX, parentY) after our SELECT but before
          // our INSERT. Re-read and merge.
          final raced = await _findRow(sessionId: sessionId, parentX: parentX, parentY: parentY);
          if (raced == null) {
            // Defensive: the only way rowid == 0 should be reachable is a
            // unique-constraint collision on the composite key; if we also
            // fail to find the row, something outside the test invariant
            // happened — surface rather than swallow (CLAUDE.md §Error
            // handling: no silently-swallowed errors).
            throw StateError(
              'mergeMask: INSERT OR IGNORE returned 0 rowid but no conflicting row found for '
              '(sessionId=${sessionId.value}, parentX=$parentX, parentY=$parentY)',
            );
          }
          await _mergeInto(raced, mask, now);
        }
      } else {
        await _mergeInto(existing, mask, now);
      }
    });
  }

  /// Re-reads the `(sessionId, parentX, parentY)` row to allow the
  /// mergeMask cold-start race path to recover from a lost INSERT OR
  /// IGNORE. Factored for readability; no independent contract.
  Future<RevealedTileRow?> _findRow({required SessionId sessionId, required int parentX, required int parentY}) async {
    return (_db.select(
      _db.revealedTiles,
    )..where((t) => t.sessionId.equals(sessionId.value) & t.parentX.equals(parentX) & t.parentY.equals(parentY))).getSingleOrNull();
  }

  /// Merges [mask] byte-wise into [existing] and writes back the result,
  /// preserving the row's id and updating `set_bit_count` + `updated_at_utc`.
  Future<void> _mergeInto(RevealedTileRow existing, Uint8List mask, DateTime now) async {
    final merged = mergeBitmap(existing.bitmap, mask);
    await (_db.update(_db.revealedTiles)..where((t) => t.id.equals(existing.id))).write(
      RevealedTilesCompanion(bitmap: Value(merged), setBitCount: Value(popcount(merged)), updatedAtUtc: Value(now)),
    );
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

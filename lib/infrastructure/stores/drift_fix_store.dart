// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/fixes/fix_store.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';

/// Drift-backed [FixStore] implementation.
///
/// Contract notes — aligned with Phase 03 conventions:
///
/// - [insert] does NOT wrap `SqliteException` — a duplicate [FixId] is an
///   infrastructure bug (the ID generator MUST produce uniques), identical
///   to `DriftMarkerStore.insert` semantics. The driver exception
///   propagates as-is.
/// - [listBySession] orders by `recorded_at_utc` ASC (chronological trace).
/// - [watchBySession] wraps Drift's `select().watch()` — first emission
///   carries the current snapshot; downstream emissions fire on every
///   insert/update/delete affecting the `t_fixes` rows for the given
///   [SessionId]. Ordering mirrors [listBySession].
/// - [deleteAllForSession] is idempotent — the WHERE-driven DELETE
///   returns rowCount=0 on an empty session without throwing, as per the
///   port contract.
class DriftFixStore implements FixStore {
  DriftFixStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> insert(Fix fix) async {
    await _db.into(_db.fixes).insert(_toInsertCompanion(fix));
  }

  @override
  Future<List<Fix>> listBySession(SessionId sessionId) async {
    final rows =
        await (_db.select(_db.fixes)
              ..where((f) => f.sessionId.equals(sessionId.value))
              ..orderBy([(f) => OrderingTerm(expression: f.recordedAtUtc)]))
            .get();
    return rows.map(_hydrate).toList(growable: false);
  }

  @override
  Stream<List<Fix>> watchBySession(SessionId sessionId) {
    final query = _db.select(_db.fixes)
      ..where((f) => f.sessionId.equals(sessionId.value))
      ..orderBy([(f) => OrderingTerm(expression: f.recordedAtUtc)]);
    return query.watch().map((rows) => rows.map(_hydrate).toList(growable: false));
  }

  @override
  Future<int> countBySession(SessionId sessionId) async {
    final countExpr = _db.fixes.id.count();
    final query = _db.selectOnly(_db.fixes)
      ..addColumns([countExpr])
      ..where(_db.fixes.sessionId.equals(sessionId.value));
    final row = await query.getSingle();
    return row.read<int>(countExpr) ?? 0;
  }

  @override
  Future<void> deleteAllForSession(SessionId sessionId) async {
    await (_db.delete(_db.fixes)..where((f) => f.sessionId.equals(sessionId.value))).go();
  }

  // -- hydration ---------------------------------------------------------

  Fix _hydrate(FixRow row) => Fix(
    id: FixId(row.id),
    sessionId: SessionId(row.sessionId),
    recordedAtUtc: row.recordedAtUtc,
    recordedAtOffsetMinutes: row.recordedAtOffsetMinutes,
    latitude: row.latitude,
    longitude: row.longitude,
    accuracyMeters: row.accuracyMeters,
    altitudeMeters: row.altitudeMeters,
    speedMps: row.speedMps,
    headingDegrees: row.headingDegrees,
  );

  FixesCompanion _toInsertCompanion(Fix fix) => FixesCompanion.insert(
    id: fix.id.value,
    sessionId: fix.sessionId.value,
    recordedAtUtc: fix.recordedAtUtc,
    recordedAtOffsetMinutes: fix.recordedAtOffsetMinutes,
    latitude: fix.latitude,
    longitude: fix.longitude,
    accuracyMeters: fix.accuracyMeters,
    altitudeMeters: Value(fix.altitudeMeters),
    speedMps: Value(fix.speedMps),
    headingDegrees: Value(fix.headingDegrees),
  );
}

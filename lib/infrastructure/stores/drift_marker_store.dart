// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:mirkfall/domain/errors/marker_errors.dart';
import 'package:mirkfall/domain/ids/category_id.dart';
import 'package:mirkfall/domain/ids/marker_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/markers/marker.dart';
import 'package:mirkfall/domain/markers/marker_store.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';

/// Drift-backed [MarkerStore] implementation.
///
/// Hydration note: Phase 03 returns [`Marker.photos`] as the empty list —
/// the photo-join is intentionally deferred to Phase 11 when the
/// `FilesystemPhotoStore` lands. `PhotoStore` (the port) is already
/// shipped in 03-03 but no implementation exists yet, and adding a naive
/// DB-only `Photos` join here would leak the on-disk filename resolution
/// responsibility into the marker store. Callers that need photos in
/// Phase 03 (none exist yet) must hydrate them explicitly via the
/// future [PhotoStore.listByMarker].
class DriftMarkerStore implements MarkerStore {
  DriftMarkerStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<Marker>> listBySession(SessionId sessionId) async {
    final rows =
        await (_db.select(_db.markers)
              ..where((t) => t.sessionId.equals(sessionId.value))
              ..orderBy([(t) => OrderingTerm(expression: t.createdAtUtc)]))
            .get();
    return rows.map(_hydrate).toList(growable: false);
  }

  @override
  Future<Marker?> findById(MarkerId id) async {
    final row = await (_db.select(_db.markers)..where((t) => t.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<Marker> requireById(MarkerId id) async {
    final marker = await findById(id);
    if (marker == null) {
      throw MarkerNotFoundException(id: id);
    }
    return marker;
  }

  @override
  Future<void> insert(Marker marker) async {
    await _db.into(_db.markers).insert(_toInsertCompanion(marker));
  }

  @override
  Future<void> update(Marker marker) async {
    await _db.update(_db.markers).replace(_toInsertCompanion(marker));
  }

  @override
  Future<void> delete(MarkerId id) async {
    await (_db.delete(_db.markers)..where((t) => t.id.equals(id.value))).go();
  }

  // -- hydration ---------------------------------------------------------

  Marker _hydrate(MarkerRow row) => Marker(
    id: MarkerId(row.id),
    sessionId: SessionId(row.sessionId),
    categoryId: CategoryId(row.categoryId),
    lat: row.lat,
    lon: row.lon,
    title: row.title,
    createdAtUtc: row.createdAtUtc,
    createdAtOffsetMinutes: row.createdAtOffsetMinutes,
    notes: row.notes,
  );

  MarkersCompanion _toInsertCompanion(Marker m) => MarkersCompanion.insert(
    id: m.id.value,
    sessionId: m.sessionId.value,
    categoryId: m.categoryId.value,
    lat: m.lat,
    lon: m.lon,
    title: m.title,
    notes: Value(m.notes),
    createdAtUtc: m.createdAtUtc,
    createdAtOffsetMinutes: m.createdAtOffsetMinutes,
  );
}

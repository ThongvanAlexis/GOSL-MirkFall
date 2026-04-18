// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:mirkfall/domain/errors/category_errors.dart';
import 'package:mirkfall/domain/ids/category_id.dart';
import 'package:mirkfall/domain/ids/default_ids.dart';
import 'package:mirkfall/domain/markers/marker_category.dart';
import 'package:mirkfall/domain/markers/marker_category_store.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';

/// Drift-backed [MarkerCategoryStore] implementation.
///
/// Deletion policy (CONTEXT.md §Politique cascade) — the schema layer does
/// NOT cascade `t_markers.category_id`. Instead, [delete] runs inside a
/// single Drift transaction that:
///   1. Reassigns every marker previously referencing `id` to
///      [`kCategoryDefaultId`].
///   2. Deletes the category row itself.
///
/// Deleting [`kCategoryDefaultId`] is forbidden — the reassign target must
/// always exist. That branch counts markers currently in the default
/// category (so the exception's `markerCount` is accurate for logs) and
/// throws [CategoryInUseException] without touching the DB. Any other
/// non-default id that still has markers is NOT an error at this layer —
/// the reassign step makes `markerCount == 0` before the DELETE.
class DriftMarkerCategoryStore implements MarkerCategoryStore {
  DriftMarkerCategoryStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<MarkerCategory>> listAll() async {
    final rows = await (_db.select(_db.markerCategories)..orderBy([(t) => OrderingTerm(expression: t.displayName)])).get();
    return rows.map(_hydrate).toList(growable: false);
  }

  @override
  Future<MarkerCategory?> findById(CategoryId id) async {
    final row = await (_db.select(_db.markerCategories)..where((t) => t.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<MarkerCategory> requireById(CategoryId id) async {
    final cat = await findById(id);
    if (cat == null) {
      throw CategoryNotFoundException(id: id);
    }
    return cat;
  }

  @override
  Future<void> insert(MarkerCategory category) async {
    await _db.into(_db.markerCategories).insert(_toInsertCompanion(category));
  }

  @override
  Future<void> update(MarkerCategory category) async {
    await _db.update(_db.markerCategories).replace(_toInsertCompanion(category));
  }

  @override
  Future<void> delete(CategoryId id) async {
    if (id == kCategoryDefaultId) {
      final countRow = await _db.customSelect('SELECT COUNT(*) AS c FROM t_markers WHERE category_id = ?', variables: [Variable<String>(id.value)]).getSingle();
      throw CategoryInUseException(id: id, markerCount: countRow.read<int>('c'));
    }
    await _db.transaction(() async {
      await _db.customStatement('UPDATE t_markers SET category_id = ? WHERE category_id = ?', <Object?>[kCategoryDefaultId.value, id.value]);
      await (_db.delete(_db.markerCategories)..where((t) => t.id.equals(id.value))).go();
    });
  }

  // -- hydration ---------------------------------------------------------

  MarkerCategory _hydrate(MarkerCategoryRow row) => MarkerCategory(
    id: CategoryId(row.id),
    displayName: row.displayName,
    iconName: row.iconName,
    createdAtUtc: row.createdAtUtc,
    createdAtOffsetMinutes: row.createdAtOffsetMinutes,
  );

  MarkerCategoriesCompanion _toInsertCompanion(MarkerCategory c) => MarkerCategoriesCompanion.insert(
    id: c.id.value,
    displayName: c.displayName,
    iconName: c.iconName,
    createdAtUtc: c.createdAtUtc,
    createdAtOffsetMinutes: c.createdAtOffsetMinutes,
  );
}

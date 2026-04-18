// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mirkfall/domain/errors/category_errors.dart';
import 'package:mirkfall/domain/ids/category_id.dart';
import 'package:mirkfall/domain/ids/default_ids.dart';
import 'package:mirkfall/domain/markers/marker_category.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';
import 'package:mirkfall/infrastructure/stores/drift_marker_category_store.dart';
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

Future<int> _count(
  AppDatabase db,
  String table,
  String whereClause,
  List<Object?> args,
) async {
  final row = await db
      .customSelect(
        'SELECT COUNT(*) AS c FROM $table WHERE $whereClause',
        variables: [for (final a in args) Variable(a)],
      )
      .getSingle();
  return row.read<int>('c');
}

Future<String?> _categoryIdOfMarker(AppDatabase db, String markerId) async {
  final row = await db
      .customSelect(
        'SELECT category_id AS c FROM t_markers WHERE id = ?',
        variables: [Variable<String>(markerId)],
      )
      .getSingleOrNull();
  return row?.read<String>('c');
}

void main() {
  late AppDatabase db;
  late DriftMarkerCategoryStore store;
  // A 26-char ULID body so CategoryId.isValid returns true for this one.
  const customId = CategoryId('cat_01HRCUSTOMCATAAAAAAAAAAAAAAAA');

  setUp(() async {
    db = _newDb();
    store = DriftMarkerCategoryStore(db);
    await db.customStatement('SELECT 1');

    // Seed cat_default via the store's insert.
    await store.insert(
      MarkerCategory(
        id: kCategoryDefaultId,
        displayName: 'Default',
        iconName: 'pin',
        createdAtUtc: DateTime.utc(2026, 4, 18, 10),
        createdAtOffsetMinutes: 120,
      ),
    );

    // Seed a custom category.
    await store.insert(
      MarkerCategory(
        id: customId,
        displayName: 'Custom',
        iconName: 'star',
        createdAtUtc: DateTime.utc(2026, 4, 18, 11),
        createdAtOffsetMinutes: 120,
      ),
    );

    // Seed a session (markers FK to session).
    await db.customStatement(
      "INSERT INTO t_sessions (id, display_name, status, started_at_utc, "
      "started_at_offset_minutes) VALUES ('sess_S', 'S', 'stopped', 1000, 120)",
    );

    // Seed 3 markers: 2 in custom, 1 in default.
    for (final entry in <List<String>>[
      <String>['mrk_A', customId.value],
      <String>['mrk_B', customId.value],
      <String>['mrk_C', kCategoryDefaultId.value],
    ]) {
      await db.customStatement(
        "INSERT INTO t_markers (id, session_id, category_id, lat, lon, title, "
        "created_at_utc, created_at_offset_minutes) "
        "VALUES ('${entry[0]}', 'sess_S', '${entry[1]}', 0, 0, 'M', 1000, 120)",
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  test('precondition: 2 markers in custom, 1 in default', () async {
    expect(
      await _count(db, 't_markers', 'category_id = ?', <Object?>[customId.value]),
      2,
    );
    expect(
      await _count(db, 't_markers', 'category_id = ?',
          <Object?>[kCategoryDefaultId.value]),
      1,
    );
  });

  test('deleting a custom category reassigns its markers to cat_default '
      'and drops the category row', () async {
    await store.delete(customId);

    // Markers formerly in custom are now in default.
    expect(await _categoryIdOfMarker(db, 'mrk_A'), kCategoryDefaultId.value);
    expect(await _categoryIdOfMarker(db, 'mrk_B'), kCategoryDefaultId.value);
    // Marker already in default is untouched.
    expect(await _categoryIdOfMarker(db, 'mrk_C'), kCategoryDefaultId.value);
    // Custom category row is gone.
    expect(
      await _count(db, 't_marker_categories', 'id = ?',
          <Object?>[customId.value]),
      0,
    );
    // cat_default still exists (required for the reassign target invariant).
    expect(
      await _count(db, 't_marker_categories', 'id = ?',
          <Object?>[kCategoryDefaultId.value]),
      1,
    );
  });

  test('deleting cat_default throws CategoryInUseException '
      'WITHOUT removing anything', () async {
    await expectLater(
      () => store.delete(kCategoryDefaultId),
      throwsA(
        isA<CategoryInUseException>()
            .having((e) => e.id, 'id', kCategoryDefaultId)
            // Before any deletion there is exactly one marker in cat_default.
            .having((e) => e.markerCount, 'markerCount', 1),
      ),
    );
    // Category row survives the failed delete.
    expect(
      await _count(db, 't_marker_categories', 'id = ?',
          <Object?>[kCategoryDefaultId.value]),
      1,
    );
    // No markers reassigned.
    expect(
      await _categoryIdOfMarker(db, 'mrk_A'),
      customId.value,
    );
  });

  test('delete-reassign is transactional: no window where markers '
      'reference a non-existent category', () async {
    // We cannot literally observe a window inside a transaction, but we
    // can prove the end state has no orphan markers.
    await store.delete(customId);
    final orphanCount = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM t_markers m '
          'WHERE NOT EXISTS (SELECT 1 FROM t_marker_categories c '
          'WHERE c.id = m.category_id)',
        )
        .getSingle();
    expect(orphanCount.read<int>('c'), 0,
        reason: 'every marker must reference an existing category after delete');
  });
}

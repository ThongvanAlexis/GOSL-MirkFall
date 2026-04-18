// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:mirkfall/domain/ids/mirk_style_id.dart';
import 'package:mirkfall/domain/mirk/mirk_style.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_style_store.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';

/// Drift-backed [MirkStyleStore] implementation.
///
/// The `t_mirk_styles.renderer_type` column is a denormalized top-level
/// copy of `config.rendererType` — lets SELECT-WHERE queries filter on
/// renderer kind without scanning the JSON blob. Kept consistent with
/// `config` automatically: derived from the sealed pattern match at
/// insert/update time; never stored independently.
///
/// Phase 09 adds a dedicated editor UI; Phase 03 ships the port + the
/// Drift impl only. No domain-specific exceptions are thrown from this
/// layer — `requireById` delegates to the generic contract (`StateError`)
/// per [MirkStyleStore] port docstring.
class DriftMirkStyleStore implements MirkStyleStore {
  DriftMirkStyleStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<MirkStyle>> listAll() async {
    final rows = await (_db.select(_db.mirkStyles)..orderBy([(t) => OrderingTerm(expression: t.displayName)])).get();
    return rows.map(_hydrate).toList(growable: false);
  }

  @override
  Future<MirkStyle?> findById(MirkStyleId id) async {
    final row = await (_db.select(_db.mirkStyles)..where((t) => t.id.equals(id.value))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  }

  @override
  Future<MirkStyle> requireById(MirkStyleId id) async {
    final style = await findById(id);
    if (style == null) {
      throw StateError('MirkStyle not found: ${id.value}');
    }
    return style;
  }

  @override
  Future<void> insert(MirkStyle style) async {
    await _db.into(_db.mirkStyles).insert(_toInsertCompanion(style));
  }

  @override
  Future<void> update(MirkStyle style) async {
    await _db.update(_db.mirkStyles).replace(_toInsertCompanion(style));
  }

  @override
  Future<void> delete(MirkStyleId id) async {
    await (_db.delete(_db.mirkStyles)..where((t) => t.id.equals(id.value))).go();
  }

  // -- hydration ---------------------------------------------------------

  MirkStyle _hydrate(MirkStyleRow row) => MirkStyle(
    id: MirkStyleId(row.id),
    displayName: row.displayName,
    config: row.config,
    createdAtUtc: row.createdAtUtc,
    createdAtOffsetMinutes: row.createdAtOffsetMinutes,
  );

  /// Derives the denormalized `renderer_type` column value from the
  /// sealed [MirkStyleConfig] variant. Kept in sync with the Freezed
  /// `unionKey: 'rendererType'` declaration + the `fallbackUnion:
  /// 'unknown'` fallback.
  String _rendererTypeFor(MirkStyleConfig config) => switch (config) {
    AtmosphericConfig() => 'atmospheric',
    ShaderConfig() => 'shader',
    UnknownConfig() => 'unknown',
  };

  MirkStylesCompanion _toInsertCompanion(MirkStyle s) => MirkStylesCompanion.insert(
    id: s.id.value,
    displayName: s.displayName,
    rendererType: _rendererTypeFor(s.config),
    config: s.config,
    createdAtUtc: s.createdAtUtc,
    createdAtOffsetMinutes: s.createdAtOffsetMinutes,
  );
}

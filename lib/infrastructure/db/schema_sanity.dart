// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';

import '../../domain/errors/migration_errors.dart';

/// Captures per-table row counts and hard-fails on any post-migration loss.
///
/// RESEARCH pitfall #7: `SchemaVerifier.migrateAndValidate` verifies schema
/// shape only — it does NOT assert that the data inside the old schema
/// survived the migration. A malformed `onUpgrade` can pass the shape check
/// while silently dropping rows. This class is the independent data-survival
/// gate: capture a row-count snapshot before the migration, a second snapshot
/// after, and throw [MigrationFailureException] if any table shrunk.
///
/// Growth is silently accepted — a legitimate `onUpgrade` seeding a default
/// row (e.g. `cat_default`) would increase a count.
class SchemaSanityChecker {
  /// Creates a checker bound to the given [QueryExecutor]. The same executor
  /// is used for every `SELECT COUNT(*)` — callers typically pass
  /// `db.executor` from the AppDatabase.
  const SchemaSanityChecker(this._executor);

  final QueryExecutor _executor;

  /// MirkFall's six tables, queried in a fixed order so `captureRowCounts`
  /// always returns a stable key set. BUG-010 Option B Commit 5 swapped
  /// the legacy `t_revealed_tiles` for the continuous-geometry
  /// `t_revealed_disc` (V5→V6 — table count unchanged at six).
  static const List<String> _tables = <String>['t_sessions', 't_markers', 't_revealed_disc', 't_marker_categories', 't_mirk_styles', 't_photos'];

  /// Returns row-count per MirkFall table.
  ///
  /// Tables in [_tables] track the **current** schema. When called against
  /// an older schema (e.g. pre-migration capture from a V1 fixture during a
  /// V1→V2 round-trip test) a not-yet-introduced table simply yields no
  /// entry in the returned map — `assertNoLoss` already treats a missing
  /// `after` key as 0, and the symmetry holds for missing `before` keys
  /// (the table just didn't exist yet). This keeps the checker robust to
  /// the moving frontier of the current schema without forcing every
  /// migration test to re-list the historical table set.
  Future<Map<String, int>> captureRowCounts() async {
    final result = <String, int>{};
    for (final table in _tables) {
      try {
        final row = await _executor.runSelect('SELECT COUNT(*) AS c FROM $table', const <Object?>[]);
        result[table] = row.first['c']! as int;
      } on Object {
        // Table absent from this schema — leave the key out of the map
        // (assertNoLoss treats missing-after as 0; missing-before is a
        // symmetric signal that the table was added by a later migration
        // and has nothing to compare against).
      }
    }
    return result;
  }

  /// Throws [MigrationFailureException] if any table's row count decreased
  /// from [before] to [after].
  ///
  /// Growth is silently accepted (an `onUpgrade` step legitimately adding
  /// seed rows would increase counts — e.g., seeding a default category).
  /// Missing post-migration table key defaults to 0, which fails iff the
  /// before-count was non-zero.
  void assertNoLoss(Map<String, int> before, Map<String, int> after) {
    for (final entry in before.entries) {
      final afterCount = after[entry.key] ?? 0;
      if (afterCount < entry.value) {
        throw MigrationFailureException(
          reason:
              'row count decreased on ${entry.key}: '
              '${entry.value} → $afterCount (migration likely dropped data)',
        );
      }
    }
  }
}

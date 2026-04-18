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
  /// always returns a stable key set.
  static const List<String> _tables = <String>['t_sessions', 't_markers', 't_revealed_tiles', 't_marker_categories', 't_mirk_styles', 't_photos'];

  /// Returns row-count per MirkFall table.
  ///
  /// Every table in [_tables] is queried individually — a single table missing
  /// raises the underlying SQLite error (caller context: pre-migration should
  /// always return the full set; post-migration a missing-table signal is
  /// itself a red flag).
  Future<Map<String, int>> captureRowCounts() async {
    final result = <String, int>{};
    for (final table in _tables) {
      final row = await _executor.runSelect('SELECT COUNT(*) AS c FROM $table', const <Object?>[]);
      result[table] = row.first['c']! as int;
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

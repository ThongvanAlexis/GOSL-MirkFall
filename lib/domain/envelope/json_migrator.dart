// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../errors/migration_errors.dart';
import 'json_migration.dart';

/// Chain-of-migrations executor (decision D9).
///
/// Given a list of [JsonMigration] steps (one per `v_n -> v_n+1`
/// transition), runs them sequentially to migrate a payload from any
/// registered source version to any registered target version.
///
/// Future schema bumps add a new [JsonMigration] entry to the list at
/// construction time; existing tests stay green because the chain only
/// walks the steps it needs.
class JsonMigrator {
  JsonMigrator(List<JsonMigration> migrations)
    : _migrations = List<JsonMigration>.unmodifiable(migrations);

  final List<JsonMigration> _migrations;

  /// Migrates [payload] from [fromVersion] to [toVersion] applying each
  /// registered step in order.
  ///
  /// Throws [MigrationFailureException] if:
  /// - [toVersion] < [fromVersion] (downgrade not supported);
  /// - no step is registered for some `v_n -> v_n+1` transition in the range;
  /// - more than one step is registered for the same transition.
  Map<String, Object?> migrate({
    required int fromVersion,
    required int toVersion,
    required Map<String, Object?> payload,
  }) {
    if (toVersion < fromVersion) {
      throw MigrationFailureException(
        reason: 'downgrade not supported (from=$fromVersion, to=$toVersion)',
      );
    }
    var current = payload;
    var v = fromVersion;
    while (v < toVersion) {
      final candidates = _migrations.where((m) => m.fromVersion == v).toList(growable: false);
      if (candidates.isEmpty) {
        throw MigrationFailureException(
          reason: 'no migrator registered for v$v -> v${v + 1}',
        );
      }
      if (candidates.length > 1) {
        throw MigrationFailureException(
          reason: 'multiple migrators registered for v$v -> v${v + 1}',
        );
      }
      current = candidates.single.apply(current);
      v++;
    }
    return current;
  }
}

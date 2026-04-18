// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'json_migration.dart';

/// Symbolic anchor for the v1 schema baseline.
///
/// `v1 -> v1` is conceptually a no-op (the chain executor's `while
/// (v < toVersion)` loop simply does not execute when `from == to`),
/// so a functional v1 entry would be redundant. Worse, a step with
/// `fromVersion = 1` would double-match against [`V1ToV2RenameRadius`]
/// and trigger the JsonMigrator's "multiple migrators" failure path.
///
/// The sentinel `fromVersion = -1` keeps the class type-anchored
/// (importable, instantiable, surveyable) without ever being picked by
/// the migrator's `where(m.fromVersion == v)` filter. It is a
/// documentation device and a place to hang future v1 schema-baseline
/// invariants if the project ever needs them.
class IdentityMigrationV1 extends JsonMigration {
  @override
  int get fromVersion => -1;

  @override
  Map<String, Object?> apply(Map<String, Object?> payload) => payload;
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'json_migration.dart';

/// Fictive v1 to v2 migration used to prove the [`JsonMigrator`] framework
/// works end-to-end before any real v2 schema lands.
///
/// Symbolic change: rename session payload key `mirk_radius_m` to
/// `reveal_radius_m`. All other keys pass through unchanged. If the
/// source key is absent, the rename is a no-op (the entry is simply
/// not produced).
///
/// Delete this class once a real v1 to v2 migration lands (probably
/// Phase 13 import format hardening).
class V1ToV2RenameRadius extends JsonMigration {
  @override
  int get fromVersion => 1;

  @override
  Map<String, Object?> apply(Map<String, Object?> payload) {
    // Always copy first — the contract forbids mutating the input.
    final clone = Map<String, Object?>.from(payload);
    if (clone.containsKey('mirk_radius_m')) {
      clone['reveal_radius_m'] = clone.remove('mirk_radius_m');
    }
    return clone;
  }
}

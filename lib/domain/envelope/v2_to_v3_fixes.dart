// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'json_migration.dart';

/// Symbolic v2 → v3 JSON migration.
///
/// Phase 05 introduces the `t_fixes` table at the DB layer (V2 → V3
/// schema bump) but does NOT define an export-payload shape for fixes —
/// that is Phase 13 scope (SCHEMA.md finalization). Keeping the chain
/// complete at this step means a Phase 05 envelope with
/// `schemaVersion: 2` can still round-trip to `schemaVersion: 3` without
/// loss; when Phase 13 adds a `fixes` key to session payloads, this
/// class becomes the natural home for the shape migration.
///
/// Mirrors the fictive [`V1ToV2RenameRadius`] precedent — the framework
/// is additive, and empty-transformation steps are cheap.
class V2ToV3Fixes extends JsonMigration {
  @override
  int get fromVersion => 2;

  @override
  Map<String, Object?> apply(Map<String, Object?> payload) {
    // Always copy first — the contract forbids mutating the input.
    return Map<String, Object?>.from(payload);
  }
}

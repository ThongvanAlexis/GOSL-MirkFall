// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/session_id.dart';
import 'fix.dart';

/// Port for GPS-fix persistence + per-session reads.
///
/// Implementations live in `lib/infrastructure/stores/` (Plan 05-01 Task 4
/// ships `DriftFixStore`). Matches the Phase 03 store-port conventions:
/// no domain-level wrapping of `SqliteException` (duplicate-id inserts
/// throw the raw driver exception — domain never produces duplicate
/// `FixId`s, so a duplicate is an infrastructure bug); separate `find`
/// vs `list`-by-session readers; watch-stream semantics match Drift's
/// `SELECT ... watch()` contract.
abstract class FixStore {
  /// Persists a single [fix]. Throws `SqliteException` (extended code 1555
  /// / UNIQUE constraint) on duplicate `id` — by design, matches the
  /// Phase 03 Markers convention.
  Future<void> insert(Fix fix);

  /// Returns every [Fix] for [sessionId] ordered by `recorded_at_utc`
  /// ASCENDING (time-of-day, chronological). Empty list when the session
  /// has no recorded fixes.
  Future<List<Fix>> listBySession(SessionId sessionId);

  /// Broadcasts the current list of fixes for [sessionId] on every
  /// insert/update/delete that affects the `t_fixes` table filtered on
  /// that session. First emission carries the current snapshot. Ordering
  /// matches [listBySession] (ASC by `recorded_at_utc`).
  Stream<List<Fix>> watchBySession(SessionId sessionId);

  /// Count of recorded fixes for [sessionId]. Cheaper than
  /// `listBySession(...).length` for Phase 05 status dashboards.
  Future<int> countBySession(SessionId sessionId);

  /// Removes every fix attached to [sessionId]. Idempotent — calling
  /// twice (or on an empty session) is a no-op. Does NOT delete the
  /// session row itself.
  Future<void> deleteAllForSession(SessionId sessionId);
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import '../ids/marker_id.dart';
import '../ids/session_id.dart';
import 'marker.dart';

/// Port for marker persistence.
///
/// Implementations live in `lib/infrastructure/stores/` (Phase 03-06 Drift
/// impl). The find-vs-require split mirrors [SessionStore] (CONTEXT.md
/// §Stratégie erreurs).
abstract class MarkerStore {
  /// Returns every marker belonging to [sessionId], ordered by
  /// `createdAtUtc` descending (most-recent-first).
  ///
  /// Typical UX surface is a reverse-chronological timeline where the
  /// most recent marker appears at the top — the port contract matches
  /// that to avoid callers sorting on the way back out. Callers that
  /// want ascending order can `.reversed.toList()` post hoc (cheap for
  /// the marker-per-session cardinality we expect).
  Future<List<Marker>> listBySession(SessionId sessionId);

  /// Returns the marker with [id] or null (find semantic).
  Future<Marker?> findById(MarkerId id);

  /// Returns the marker with [id] or throws `MarkerNotFoundException`
  /// (require semantic).
  Future<Marker> requireById(MarkerId id);

  Future<void> insert(Marker marker);

  Future<void> update(Marker marker);

  /// Deletes the marker. The attached [`PhotoRef`] rows are cascaded by
  /// FK ON DELETE CASCADE at the DB level; the on-disk photo files are
  /// cleaned up by the Phase 11 `FilesystemPhotoStore` in the same
  /// logical unit of work.
  Future<void> delete(MarkerId id);
}

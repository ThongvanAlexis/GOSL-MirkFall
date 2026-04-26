// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';

import '../mirk/mirk_viewport_bbox.dart';
import 'reveal_disc.dart';

/// Port for [RevealDisc] persistence — the BUG-010 Option B replacement
/// for [RevealedTileStore]'s cell-bitmap persistence model.
///
/// Implementations live in `lib/infrastructure/stores/` (Phase 09 BUG-010
/// Commit 2 Drift impl). The contract is deliberately narrow: writers
/// append immutable discs, readers fetch by session or bbox, and an
/// offline compaction step collapses GPS-jitter clusters at session
/// flush — no mutating updates, no per-disc deletes from the consumer
/// side.
abstract class RevealedDiscStore {
  /// Insert one disc. Idempotent on `disc.id`: re-inserting the same id
  /// is a no-op (`INSERT OR IGNORE` / `INSERT ... ON CONFLICT DO NOTHING`).
  /// The id collision is the application-level signal that the disc has
  /// already been recorded — replay-safe across restart, retry, and the
  /// future Wave-7 batch ingestion path.
  Future<void> addDisc(RevealDisc disc);

  /// All discs for [sessionId] whose extent intersects [bbox].
  ///
  /// Implementations may over-fetch from SQL and refine in Dart via
  /// [RevealDisc.intersectsBbox] — false positives are acceptable, false
  /// negatives are not. The downstream SDF builder filters again at
  /// paint time anyway, so a few extra in-memory candidates are harmless.
  Future<List<RevealDisc>> discsInBbox({required String sessionId, required MirkViewportBbox bbox});

  /// All discs for one session, ordered by `fixedAtUtc` ascending.
  ///
  /// The chronological order is the natural traversal for the SDF
  /// builder's pre-frame replay, the offline compactor's containment
  /// walk (after a separate radius sort), and any future export of the
  /// session timeline. Other orderings are the consumer's responsibility.
  Future<List<RevealDisc>> discsForSession(String sessionId);

  /// Offline compaction: drop every disc whose extent is (almost) fully
  /// contained inside another disc of the same session. The merge rule
  /// is conservative — see the docstring on [RevealDisc.mergeWith].
  ///
  /// Specifically: discard disc `A` if there exists disc `B` (same
  /// session) with
  /// `B.distanceMetersTo(A.lat, A.lon) + A.radiusMeters
  ///    <= B.radiusMeters * (1 + tolerance)`.
  ///
  /// Does NOT change the union of revealed area beyond [tolerance] slop;
  /// a walking path stays intact (consecutive non-overlapping fixes are
  /// kept), only stationary GPS-jitter clusters collapse into the largest
  /// covering disc.
  ///
  /// The default [tolerance] is sourced from
  /// [kRevealedDiscCompactionContainmentTolerance] (5 %) — at the 25 m
  /// default reveal radius that is a sub-GPS-accuracy slop.
  ///
  /// Returns the number of discs deleted.
  Future<int> compactSession(String sessionId, {double tolerance = kRevealedDiscCompactionContainmentTolerance});
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/domain/revealed/revealed_disc_store.dart';

/// Observable in-memory [RevealedDiscStore] for widget + provider tests
/// that need to assert which discs get queried, when, and how often —
/// without spinning a Drift database. Mirrors [`FakeRevealedTileStore`]'s
/// counter + observable pattern; the BUG-010 Option B path's contract is
/// narrower (no merge, no popcount, no monotonic-OR semantic), so the
/// fake stays minimal.
class FakeRevealedDiscStore implements RevealedDiscStore {
  /// Backing list — appended on [addDisc], rebuilt on [compactSession].
  /// Public for test inspection.
  final List<RevealDisc> discs = <RevealDisc>[];

  /// Counter incremented on every [addDisc] invocation. Lets tests
  /// assert the reveal pipeline actually wrote.
  int addDiscCallCount = 0;

  /// Counter incremented on every [discsInBbox] invocation.
  int discsInBboxCallCount = 0;

  /// Counter incremented on every [discsForSession] invocation.
  int discsForSessionCallCount = 0;

  /// Counter incremented on every [compactSession] invocation.
  int compactSessionCallCount = 0;

  /// When non-null, the next call to ANY method throws
  /// [throwOnNextCall] then resets it.
  Object? throwOnNextCall;

  /// Resets all counters + clears the in-memory disc list.
  void reset() {
    discs.clear();
    addDiscCallCount = 0;
    discsInBboxCallCount = 0;
    discsForSessionCallCount = 0;
    compactSessionCallCount = 0;
    throwOnNextCall = null;
  }

  void _maybeThrow() {
    final t = throwOnNextCall;
    if (t != null) {
      throwOnNextCall = null;
      throw t;
    }
  }

  @override
  Future<void> addDisc(RevealDisc disc) async {
    _maybeThrow();
    addDiscCallCount++;
    // Idempotent on `disc.id` — mirror the prod `INSERT OR IGNORE`.
    final exists = discs.any((d) => d.id == disc.id);
    if (exists) return;
    discs.add(disc);
  }

  @override
  Future<List<RevealDisc>> discsInBbox({required String sessionId, required MirkViewportBbox bbox}) async {
    _maybeThrow();
    discsInBboxCallCount++;
    return discs.where((d) => d.sessionId == sessionId && d.intersectsBbox(bbox)).toList(growable: false);
  }

  @override
  Future<List<RevealDisc>> discsForSession(String sessionId) async {
    _maybeThrow();
    discsForSessionCallCount++;
    final List<RevealDisc> sessionDiscs = discs.where((d) => d.sessionId == sessionId).toList(growable: false);
    final List<RevealDisc> sortedDiscs = List<RevealDisc>.from(sessionDiscs)..sort((a, b) => a.fixedAtUtc.compareTo(b.fixedAtUtc));
    return sortedDiscs;
  }

  @override
  Future<int> compactSession(String sessionId, {double tolerance = kRevealedDiscCompactionContainmentTolerance}) async {
    _maybeThrow();
    compactSessionCallCount++;
    // Same containment-walk algorithm as `DriftRevealedDiscStore`: sort
    // by radius DESC, keep a "kept" list, drop any disc contained in
    // any earlier (larger-or-equal) kept disc.
    final List<RevealDisc> sessionDiscs = discs.where((d) => d.sessionId == sessionId).toList(growable: false);
    final List<RevealDisc> sortedDiscs = List<RevealDisc>.from(sessionDiscs)..sort((a, b) => b.radiusMeters.compareTo(a.radiusMeters));

    final List<RevealDisc> keptDiscs = <RevealDisc>[];
    int droppedCount = 0;
    for (final candidate in sortedDiscs) {
      bool contained = false;
      for (final keeper in keptDiscs) {
        final distance = keeper.distanceMetersTo(candidate.lat, candidate.lon);
        if (distance + candidate.radiusMeters <= keeper.radiusMeters * (1.0 + tolerance)) {
          contained = true;
          break;
        }
      }
      if (contained) {
        droppedCount++;
        continue;
      }
      keptDiscs.add(candidate);
    }

    // Rebuild `discs`: keep every other-session disc + the
    // post-compaction subset for the target session.
    final List<RevealDisc> otherSessionDiscs = discs.where((d) => d.sessionId != sessionId).toList(growable: false);
    discs
      ..clear()
      ..addAll(otherSessionDiscs)
      ..addAll(keptDiscs);
    return droppedCount;
  }

  /// Number of discs currently held — useful in tests for sanity-checking
  /// seeders and post-compaction state.
  int get discCount => discs.length;
}

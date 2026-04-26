// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/domain/revealed/revealed_disc_store.dart';

/// Observable in-memory [RevealedDiscStore] for widget + provider tests
/// that need to assert which discs get queried, when, and how often —
/// without spinning a Drift database. The BUG-010 Option B contract is
/// narrow (no merge, no popcount, no monotonic-OR semantic), so the
/// fake stays minimal — counters per method, a backing list, and a
/// throw-injection hook for error-path tests.
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

  /// When non-null, the NEXT call to [compactSession] throws this error
  /// (then resets). Lets BUG-010 Commit 6 tests assert the
  /// `ActiveSessionController.stop()` flow swallows compaction failures
  /// without preventing the session from settling to stopped.
  Object? throwOnNextCompactSession;

  /// Monotonic counter used to record the order in which methods are
  /// invoked. Each call to [addDisc] / [compactSession] increments it
  /// and stores the resulting sequence number on the call. Lets tests
  /// assert that compaction runs AFTER all reveal writes (BUG-010
  /// Commit 6 — compaction must see a fully flushed table).
  int _callSequence = 0;

  /// Sequence numbers for every [addDisc] call, in invocation order.
  final List<int> addDiscCallSequenceNumbers = <int>[];

  /// Sequence numbers for every [compactSession] call, in invocation
  /// order.
  final List<int> compactSessionCallSequenceNumbers = <int>[];

  /// Resets all counters + clears the in-memory disc list.
  void reset() {
    discs.clear();
    addDiscCallCount = 0;
    discsInBboxCallCount = 0;
    discsForSessionCallCount = 0;
    compactSessionCallCount = 0;
    throwOnNextCall = null;
    throwOnNextCompactSession = null;
    _callSequence = 0;
    addDiscCallSequenceNumbers.clear();
    compactSessionCallSequenceNumbers.clear();
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
    _callSequence++;
    addDiscCallSequenceNumbers.add(_callSequence);
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
    final scheduledThrow = throwOnNextCompactSession;
    if (scheduledThrow != null) {
      throwOnNextCompactSession = null;
      // Count + sequence the call BEFORE throwing — the test assertion
      // is "compactSession was attempted at the right point in stop()",
      // which is true even when the implementation later raises.
      compactSessionCallCount++;
      _callSequence++;
      compactSessionCallSequenceNumbers.add(_callSequence);
      throw scheduledThrow;
    }
    compactSessionCallCount++;
    _callSequence++;
    compactSessionCallSequenceNumbers.add(_callSequence);
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

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/domain/revealed/revealed_disc_store.dart';
import 'package:mirkfall/infrastructure/db/app_database.dart';

final Logger _log = Logger('infrastructure.stores.drift_revealed_disc');

/// Drift-backed [RevealedDiscStore] — BUG-010 Option B core implementation.
///
/// Storage model: one row per immutable [RevealDisc], primary-keyed on
/// `id` (`rvd_<26-char-ULID>` per the [RevealDisc] class docstring), FK
/// to `t_sessions(id)` with `ON DELETE CASCADE`. There is no
/// per-`(session, location)` uniqueness — two GPS fixes that happen to
/// land at the same lat/lon still produce two separate discs (different
/// ids); idempotence is solely on the application-level `id`.
///
/// Concurrency: `addDisc` is a single `INSERT OR IGNORE` and atomic on
/// any Drift connection regime (the default `NativeDatabase`, the
/// background-isolate variant, in-memory). `compactSession` brackets the
/// delete-then-reinsert dance inside a `_db.transaction(...)` so a
/// concurrent `addDisc` arriving mid-compaction either commits before
/// the compactor reads its working set (and its disc participates in the
/// containment walk) or after the compactor commits (and survives as a
/// fresh post-compaction disc). The transaction guarantees no partial
/// state ever escapes — the table is either pre-compaction or
/// post-compaction, never the gap between the two.
class DriftRevealedDiscStore implements RevealedDiscStore {
  DriftRevealedDiscStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> addDisc(RevealDisc disc) async {
    // FINE-level diagnostic: every reveal disc landing on disk has a
    // breadcrumb, mirroring `DriftRevealedTileStore.mergeMask`'s
    // verbosity. The per-fix cadence (≤ 1 per GPS fix) does not drown
    // the log file — orders of magnitude lighter than the bitmap
    // mergeMask path.
    _log.fine('addDisc: id=${disc.id} sessionId=${disc.sessionId} lat=${disc.lat} lon=${disc.lon} radiusMeters=${disc.radiusMeters}');
    final inserted = await _db
        .into(_db.revealedDiscs)
        .insert(
          RevealedDiscsCompanion.insert(
            id: disc.id,
            sessionId: disc.sessionId,
            lat: disc.lat,
            lon: disc.lon,
            radiusMeters: disc.radiusMeters,
            fixedAtUtc: disc.fixedAtUtc,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    _log.fine('addDisc: rowid=$inserted (0 = id collision, ignored)');
  }

  @override
  Future<List<RevealDisc>> discsInBbox({required String sessionId, required MirkViewportBbox bbox}) async {
    _log.fine('discsInBbox: sessionId=$sessionId bbox=$bbox');
    // Future-perf: SQL-side bbox filter via padded lat/lon range. Today's
    // session-scoped sets stay in the few-thousand-discs range (a 25 m
    // radius walked over a typical session covers a few km², per
    // 09-RESEARCH §reveal-density), so a Dart-side `intersectsBbox`
    // refinement on the session subset is well below the 16 ms paint
    // budget. The composite index `idx_t_revealed_disc_session_latlon`
    // exists already so a future SQL bbox prefilter has the access path
    // ready.
    final rows = await (_db.select(_db.revealedDiscs)..where((t) => t.sessionId.equals(sessionId))).get();
    final List<RevealDisc> discs = <RevealDisc>[];
    for (final row in rows) {
      final disc = _hydrate(row);
      if (disc.intersectsBbox(bbox)) discs.add(disc);
    }
    _log.fine('discsInBbox: rowCount=${rows.length} hitCount=${discs.length}');
    return discs;
  }

  @override
  Future<List<RevealDisc>> discsForSession(String sessionId) async {
    _log.fine('discsForSession: sessionId=$sessionId');
    final rows =
        await (_db.select(_db.revealedDiscs)
              ..where((t) => t.sessionId.equals(sessionId))
              ..orderBy([(t) => OrderingTerm(expression: t.fixedAtUtc)]))
            .get();
    _log.fine('discsForSession: rowCount=${rows.length}');
    return rows.map(_hydrate).toList(growable: false);
  }

  @override
  Future<int> compactSession(String sessionId, {double tolerance = kRevealedDiscCompactionContainmentTolerance}) async {
    _log.fine('compactSession: sessionId=$sessionId tolerance=$tolerance');
    return await _db.transaction(() async {
      // Load the working set inside the transaction so a concurrent
      // `addDisc` cannot land between the load and the
      // delete-then-reinsert (the transaction holds the writer lock for
      // the full duration). Sort radius-DESC so the largest discs are
      // walked first — every successive disc only needs to check the
      // already-kept (larger-or-equal) discs for a containment hit.
      final allRows = await (_db.select(_db.revealedDiscs)..where((t) => t.sessionId.equals(sessionId))).get();
      final allDiscs = allRows.map(_hydrate).toList(growable: false);
      final sortedDiscs = List<RevealDisc>.from(allDiscs)..sort((a, b) => b.radiusMeters.compareTo(a.radiusMeters));

      final List<RevealDisc> keptDiscs = <RevealDisc>[];
      int droppedCount = 0;
      for (final candidate in sortedDiscs) {
        if (_isContainedInAny(candidate, keptDiscs, tolerance)) {
          droppedCount++;
          continue;
        }
        keptDiscs.add(candidate);
      }

      if (droppedCount == 0) {
        _log.fine('compactSession: no-op (allDiscs=${allDiscs.length} keptDiscs=${keptDiscs.length})');
        return 0;
      }

      // Replace the table rows atomically: delete the full session
      // working set, then re-insert only the kept discs. Inside a
      // transaction the gap is never observable to readers.
      await (_db.delete(_db.revealedDiscs)..where((t) => t.sessionId.equals(sessionId))).go();
      for (final disc in keptDiscs) {
        await _db
            .into(_db.revealedDiscs)
            .insert(
              RevealedDiscsCompanion.insert(
                id: disc.id,
                sessionId: disc.sessionId,
                lat: disc.lat,
                lon: disc.lon,
                radiusMeters: disc.radiusMeters,
                fixedAtUtc: disc.fixedAtUtc,
              ),
            );
      }

      _log.fine('compactSession: deleted=$droppedCount keptDiscs=${keptDiscs.length}');
      return droppedCount;
    });
  }

  /// True iff [candidate] is contained in any disc of [keptDiscs] under
  /// the [tolerance] containment slack. Factored for readability — see
  /// the [RevealedDiscStore.compactSession] docstring for the rule.
  bool _isContainedInAny(RevealDisc candidate, List<RevealDisc> keptDiscs, double tolerance) {
    for (final keeper in keptDiscs) {
      final distance = keeper.distanceMetersTo(candidate.lat, candidate.lon);
      if (distance + candidate.radiusMeters <= keeper.radiusMeters * (1.0 + tolerance)) {
        return true;
      }
    }
    return false;
  }

  RevealDisc _hydrate(RevealedDiscRow row) =>
      RevealDisc(id: row.id, sessionId: row.sessionId, lat: row.lat, lon: row.lon, radiusMeters: row.radiusMeters, fixedAtUtc: row.fixedAtUtc);
}

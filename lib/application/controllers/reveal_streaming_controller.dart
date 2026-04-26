// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/id_generator.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/domain/revealed/revealed_disc_store.dart';

final Logger _log = Logger('application.controllers.reveal_streaming');

/// ID prefix for reveal disc rows. Kept inline (not promoted to a typed
/// extension type yet — see [RevealDisc.id] docstring) so the controller
/// mints `rvd_<26-char-ULID>` ids that match the Drift `t_revealed_disc.id`
/// column shape. Trailing underscore matches the project convention used
/// by every other id namespace (`sess_`, `rvt_`, `fix_`, …).
const String _kRevealDiscIdPrefix = 'rvd_';

/// Buffers GPS fixes and flushes reveal-disc writes to [RevealedDiscStore]
/// in batches.
///
/// Flush triggers (first-to-fire wins):
/// * [kRevealFlushIntervalSeconds] elapsed since the oldest buffered fix.
/// * [kRevealFlushMaxFixes] fixes buffered.
///
/// Per-fix reveal radius: [kDefaultRevealRadiusMeters] (25 m). Initial
/// session-open reveal uses [kInitialRevealRadiusMeters] (20 m) via
/// [revealInitial] and bypasses the buffer entirely.
///
/// ## BUG-010 Option B (Commit 4)
///
/// Pre-Commit-4 the controller wrote a 512-byte cell-bitmap mask per
/// touched parent tile per fix (the 64×64 cell grid produced "blocky"
/// reveal corners visible in BUG-010 UAT walks). The new path appends a
/// single immutable [RevealDisc] per fix — the SDF builder consumes the
/// continuous geometry directly at render time, so there is no per-tile
/// fan-out and no quantisation. See `docs/phase09-bug-tracking/
/// BUG-010-cell-grid-resolution-blocky.md` for the full rationale.
///
/// Disposal semantics: [dispose] flushes any still-buffered fixes before
/// returning — guarantees no fix is lost on session end / app background.
///
/// Error-handling tier (CLAUDE.md §Error handling level 2): a single
/// `addDisc` write failure on one fix is logged and the loop continues.
/// The whole batch is not dropped — partial progress is strictly better
/// than no progress in a fog-of-war reveal pipeline.
class RevealStreamingController {
  RevealStreamingController({
    required this.sessionId,
    required this.discStore,
    required this.idGenerator,
    Duration? flushInterval,
    int? flushMaxFixes,
    double? revealRadiusMeters,
  }) : flushInterval = flushInterval ?? const Duration(seconds: kRevealFlushIntervalSeconds),
       flushMaxFixes = flushMaxFixes ?? kRevealFlushMaxFixes,
       revealRadiusMeters = revealRadiusMeters ?? kDefaultRevealRadiusMeters;

  final SessionId sessionId;
  final RevealedDiscStore discStore;
  final IdGenerator idGenerator;
  final Duration flushInterval;
  final int flushMaxFixes;
  final double revealRadiusMeters;

  final List<Fix> _buffer = <Fix>[];
  Timer? _flushTimer;
  bool _disposed = false;

  /// In-flight flush future. Re-entrant calls during a running flush
  /// await the same future rather than firing a parallel batch (which
  /// could otherwise interleave `addDisc` writes).
  Future<void>? _inFlightFlush;

  /// Buffers [fix] and triggers a flush if [flushMaxFixes] is reached.
  /// Otherwise arms (or leaves armed) the [flushInterval] timer that
  /// fires the time-bound flush.
  Future<void> onFix(Fix fix) async {
    if (_disposed) return;
    _buffer.add(fix);
    // BUG-009 follow-up diagnostic (2026-04-25) — FINE-level per-fix
    // breadcrumb. At kRevealFlushIntervalSeconds + kRevealFlushMaxFixes
    // cadence the buffer rarely exceeds ~10 entries, so this is far
    // below the FileLogger flush budget even on long walks.
    _log.fine('onFix: lat=${fix.latitude.toStringAsFixed(6)} lon=${fix.longitude.toStringAsFixed(6)} bufferLen=${_buffer.length}');
    if (_buffer.length >= flushMaxFixes) {
      await _flush();
      return;
    }
    _flushTimer ??= Timer(flushInterval, _flush);
  }

  /// Writes a [kInitialRevealRadiusMeters] reveal around [fix] without
  /// touching the buffer. Used by [`ActiveSessionController.start`] at
  /// session open to seed an immediate disc around the user position.
  Future<void> revealInitial(Fix fix) async {
    if (_disposed) return;
    await _writeDisc(fix, radiusMeters: kInitialRevealRadiusMeters.toDouble());
  }

  /// Triggers a flush of the buffered fixes immediately — bypasses the
  /// time-bound timer. Returns when the resulting batch is fully
  /// committed to the store. Re-entrant safe (concurrent callers await
  /// the same in-flight future).
  Future<void> flush() => _flush();

  Future<void> _flush() async {
    final inFlight = _inFlightFlush;
    if (inFlight != null) return inFlight;

    _flushTimer?.cancel();
    _flushTimer = null;
    if (_buffer.isEmpty) return;

    final batch = List<Fix>.from(_buffer);
    _buffer.clear();

    final flushFuture = _flushBatch(batch);
    _inFlightFlush = flushFuture;
    try {
      await flushFuture;
    } finally {
      _inFlightFlush = null;
    }
  }

  Future<void> _flushBatch(List<Fix> batch) async {
    _log.info('flush: writing ${batch.length} disc(s) to RevealedDiscStore (radius=${revealRadiusMeters.toStringAsFixed(1)}m)');
    for (final fix in batch) {
      await _writeDisc(fix, radiusMeters: revealRadiusMeters);
    }
  }

  /// Writes a single [RevealDisc] for [fix] with [radiusMeters] radius.
  ///
  /// BUG-010 Option B: the per-parent-tile fan-out is gone — a single
  /// disc carries the geometry the SDF builder needs at render time.
  /// `addDisc` is idempotent on the disc id (`INSERT OR IGNORE`), so a
  /// retry after a transient DB error is replay-safe.
  Future<void> _writeDisc(Fix fix, {required double radiusMeters}) async {
    final disc = RevealDisc(
      id: idGenerator.newId(_kRevealDiscIdPrefix),
      sessionId: sessionId.value,
      lat: fix.latitude,
      lon: fix.longitude,
      radiusMeters: radiusMeters,
      fixedAtUtc: fix.recordedAtUtc,
    );
    try {
      await discStore.addDisc(disc);
    } on Object catch (e, stack) {
      // CLAUDE.md §Error handling level 2: a per-fix DB write failure
      // is recoverable noise — log and continue with the rest of the
      // batch. Surfacing it would drop later fixes' reveal data on the
      // floor, which is strictly worse than losing one disc.
      _log.warning('addDisc failed for fix lat=${fix.latitude} lon=${fix.longitude} — continuing', e, stack);
    }
  }

  /// Flushes any still-buffered fixes synchronously, then marks the
  /// controller disposed. Subsequent [onFix] / [revealInitial] calls
  /// no-op rather than throwing — easier to reason about under a
  /// chain of overlapping disposes (e.g. provider invalidation racing
  /// with explicit `stop()`).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flush();
  }
}

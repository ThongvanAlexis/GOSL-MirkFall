// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/revealed/reveal_calculator.dart';
import 'package:mirkfall/domain/revealed/revealed_tile_store.dart';
import 'package:mirkfall/domain/revealed/tile_math.dart';

final Logger _log = Logger('application.controllers.reveal_streaming');

/// Buffers GPS fixes and flushes reveal-mask writes to [RevealedTileStore]
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
/// Disposal semantics: [dispose] flushes any still-buffered fixes
/// before returning — guarantees no fix is lost on session
/// end / app background.
///
/// Error-handling tier (CLAUDE.md §Error handling level 2): a single
/// `mergeMask` write failure on one parent tile is logged and the loop
/// continues. The whole batch is not dropped — partial progress is
/// strictly better than no progress in a fog-of-war reveal pipeline.
class RevealStreamingController {
  RevealStreamingController({required this.sessionId, required this.store, Duration? flushInterval, int? flushMaxFixes, double? revealRadiusMeters})
    : flushInterval = flushInterval ?? const Duration(seconds: kRevealFlushIntervalSeconds),
      flushMaxFixes = flushMaxFixes ?? kRevealFlushMaxFixes,
      revealRadiusMeters = revealRadiusMeters ?? kDefaultRevealRadiusMeters;

  final SessionId sessionId;
  final RevealedTileStore store;
  final Duration flushInterval;
  final int flushMaxFixes;
  final double revealRadiusMeters;

  final List<Fix> _buffer = <Fix>[];
  Timer? _flushTimer;
  bool _disposed = false;

  /// In-flight flush future. Re-entrant calls during a running flush
  /// await the same future rather than firing a parallel batch (which
  /// could otherwise interleave `mergeMask` writes for the same tile).
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
    await _writeCircleReveal(fix.latitude, fix.longitude, kInitialRevealRadiusMeters.toDouble());
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
    // BUG-009 follow-up diagnostic (2026-04-25) — count distinct parent
    // tiles touched across the batch so a "flush ran but nothing was
    // written" failure mode is observable in the logs. We sum tile
    // counts per fix BEFORE the actual mergeMask call so the log
    // appears even if a downstream write throws.
    var totalCells = 0;
    final touchedTileSet = <int>{};
    for (final fix in batch) {
      for (final tile in _touchedParentTiles(fix.latitude, fix.longitude, revealRadiusMeters)) {
        // Pack (x, y) into a 53-bit-safe key for set dedup. parentX/Y
        // at zoom 14 fit in 14 bits each.
        touchedTileSet.add((tile.x << 20) ^ tile.y);
        totalCells++;
      }
    }
    _log.info('flush: writing $totalCells cells across ${touchedTileSet.length} tiles to RevealedTileStore (batch=${batch.length} fixes)');
    for (final fix in batch) {
      await _writeCircleReveal(fix.latitude, fix.longitude, revealRadiusMeters);
    }
  }

  /// Computes the per-parent-tile reveal masks for a circle of [radius]
  /// metres around ([lat], [lon]) and writes each non-empty mask via
  /// [`RevealedTileStore.mergeMask`].
  ///
  /// A fix near a parent-tile boundary touches 2+ tiles — every touched
  /// tile gets its own write. Empty masks (circle does not actually
  /// intersect a candidate tile after the per-cell Haversine prune) are
  /// skipped to save a no-op DB write.
  Future<void> _writeCircleReveal(double lat, double lon, double radius) async {
    final touchedTiles = _touchedParentTiles(lat, lon, radius);
    for (final tile in touchedTiles) {
      final mask = computeRevealMask(
        centerLat: lat,
        centerLon: lon,
        radiusMeters: radius,
        parentX: tile.x,
        parentY: tile.y,
        parentZoom: kRevealedTileParentZoom,
      );
      if (!_hasAnyBit(mask)) continue;
      try {
        await store.mergeMask(sessionId: sessionId, parentX: tile.x, parentY: tile.y, mask: mask);
      } on Object catch (e, stack) {
        // CLAUDE.md §Error handling level 2: a per-tile DB write failure
        // is recoverable noise — log and continue with the rest of the
        // batch. Surfacing it would drop later tiles' reveal data on
        // the floor, which is strictly worse than losing one tile's
        // update.
        _log.warning('mergeMask failed for parent (${tile.x}, ${tile.y}) — continuing', e, stack);
      }
    }
  }

  /// Enumerates the zoom-14 parent tiles touched by a circle of [radius]
  /// metres around ([lat], [lon]).
  ///
  /// Uses a crude Mercator inverse (fixed metres-per-degree-lat,
  /// cos-scaled metres-per-degree-lon) to compute the bbox-corner tile
  /// indices. The downstream [computeRevealMask] runs the per-cell
  /// Haversine clamp, so a slight bbox over-estimate here produces at
  /// most a few empty-mask candidates that get filtered by the
  /// `_hasAnyBit` guard.
  Iterable<({int x, int y})> _touchedParentTiles(double lat, double lon, double radius) {
    const latDegPerMeter = 1.0 / 111320.0;
    // Guard the cosine against the polar Mercator clamp (cos(±90°) →
    // 0 → infinite lon-degree-per-metre).
    final clampedCosLat = math.cos(lat.clamp(-TileMath.maxLatMercator, TileMath.maxLatMercator) * math.pi / 180.0);
    final lonDegPerMeter = 1.0 / (111320.0 * clampedCosLat);

    final minLat = lat - radius * latDegPerMeter;
    final maxLat = lat + radius * latDegPerMeter;
    final minLon = lon - radius * lonDegPerMeter;
    final maxLon = lon + radius * lonDegPerMeter;

    final nw = TileMath.latLonToTile(lat: maxLat, lon: minLon, zoom: kRevealedTileParentZoom);
    final se = TileMath.latLonToTile(lat: minLat, lon: maxLon, zoom: kRevealedTileParentZoom);

    final tiles = <({int x, int y})>[];
    for (var y = nw.y; y <= se.y; y++) {
      for (var x = nw.x; x <= se.x; x++) {
        tiles.add((x: x, y: y));
      }
    }
    return tiles;
  }

  bool _hasAnyBit(Uint8List bytes) {
    for (final b in bytes) {
      if (b != 0) return true;
    }
    return false;
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

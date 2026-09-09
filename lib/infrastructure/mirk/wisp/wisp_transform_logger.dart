// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';

/// 1-second JSONL rollup of per-paint wisp diagnostic state (POC WISP-05, ported by Phase 09.1
/// plan 09.1-05).
///
/// Diagnostic ported from the POC — active ONLY in verbose logging (`--dart-define=DEBUG=true` or
/// the debug-menu "Verbose logging" toggle, CLAUDE.md §Logging). While
/// `Logger('infrastructure.mirk.wisp').isLoggable(Level.FINE)` is false, [recordPaint] and the
/// rollup are no-ops. The periodic timer is armed LAZILY by the first verbose sample after
/// [start] and disarmed by the first rollup that finds verbose off (same idiom as
/// `SdfRebuildLogger`): zero timers in non-verbose renderers and widget tests, toggle acts live.
///
/// Sibling of the frame-delta probe, the fog-transform logger and `SdfRebuildLogger`: all four
/// emit on the [kMirkFogDiagRollupSeconds] cadence with a wall-clock `epochSecond` so post-walk
/// grep can join the streams (invariant 6).
///
/// Captured per paint: `activeCount`, `meanAge`, lat / lon bounds of the wisp positions, screen
/// x / y bounds of their projections, `spawnRatePerSecond`. The rollup emits stats-of-stats
/// (min / median / max of every per-paint bound, ~35 keys, ~600 bytes) so worst-case screen-bounds
/// extremes are readable without re-aggregating. Idle seconds emit nothing. Buffer cap
/// [kMirkFogDiagWispTransformBufferMaxSamples], FIFO drop on overflow.
class WispTransformLogger {
  /// [rollupInterval] is a test seam — defaults to [kMirkFogDiagRollupSeconds] in production.
  WispTransformLogger({Duration? rollupInterval}) : _rollupInterval = rollupInterval ?? const Duration(seconds: kMirkFogDiagRollupSeconds);

  static final Logger _log = Logger('infrastructure.mirk.wisp');

  final Duration _rollupInterval;
  final List<_WispTransformSample> _buffer = <_WispTransformSample>[];

  /// Between [start] and [stop]. The timer itself only exists while there is verbose traffic.
  bool _running = false;
  Timer? _timer;
  int _frameCounter = 0;

  /// Verbose gate — evaluated on every record / rollup so the debug-menu toggle acts live.
  bool get _isVerbose => _log.isLoggable(Level.FINE);

  /// Marks the logger as running; the rollup timer is armed by the first verbose sample.
  /// Idempotent.
  void start() {
    _running = true;
  }

  /// Cancels the timer and emits a final rollup if the buffer is non-empty. Idempotent.
  void stop() {
    _running = false;
    _disarm();
    if (_buffer.isNotEmpty) {
      _emitRollup();
    }
  }

  void _armIfNeeded() {
    if (!_running || _timer != null) return;
    _timer = Timer.periodic(_rollupInterval, (_) => _onTick());
  }

  void _disarm() {
    _timer?.cancel();
    _timer = null;
  }

  /// Periodic tick: emits, or — once verbose is off — drops the buffer and disarms so the
  /// logger goes back to owning no timer.
  void _onTick() {
    if (!_isVerbose) {
      _disarm();
    }
    _emitRollup();
  }

  /// Records one paint observation (no-op unless verbose). Overflow drops the oldest sample.
  void recordPaint({
    required int activeCount,
    required double meanAge,
    required (double, double) latBounds,
    required (double, double) lonBounds,
    required (double, double) screenXBounds,
    required (double, double) screenYBounds,
    required double spawnRatePerSecond,
  }) {
    if (!_isVerbose) return;
    _frameCounter += 1;
    _buffer.add(
      _WispTransformSample(
        frameCounter: _frameCounter,
        activeCount: activeCount,
        meanAge: meanAge,
        latMin: latBounds.$1,
        latMax: latBounds.$2,
        lonMin: lonBounds.$1,
        lonMax: lonBounds.$2,
        screenXMin: screenXBounds.$1,
        screenXMax: screenXBounds.$2,
        screenYMin: screenYBounds.$1,
        screenYMax: screenYBounds.$2,
        spawnRatePerSecond: spawnRatePerSecond,
      ),
    );
    while (_buffer.length > kMirkFogDiagWispTransformBufferMaxSamples) {
      _buffer.removeAt(0);
    }
    _armIfNeeded();
  }

  /// `(min, median, max)` of a non-empty ASCENDING list. Static + `@visibleForTesting` so the
  /// stat math is unit-testable without a full logger.
  @visibleForTesting
  static (double min, double median, double max) computeStats(List<double> sortedAscending) {
    assert(sortedAscending.isNotEmpty, 'computeStats requires a non-empty sorted list');
    return (sortedAscending.first, sortedAscending[sortedAscending.length ~/ 2], sortedAscending.last);
  }

  void _emitRollup() {
    if (_buffer.isEmpty) return;
    if (!_isVerbose) {
      _buffer.clear();
      return;
    }
    final int sampleCount = _buffer.length;

    final (double, double, double) meanAgeStats = computeStats(_buffer.map((_WispTransformSample s) => s.meanAge).toList()..sort());
    final (double, double, double) latMinStats = computeStats(_buffer.map((_WispTransformSample s) => s.latMin).toList()..sort());
    final (double, double, double) latMaxStats = computeStats(_buffer.map((_WispTransformSample s) => s.latMax).toList()..sort());
    final (double, double, double) lonMinStats = computeStats(_buffer.map((_WispTransformSample s) => s.lonMin).toList()..sort());
    final (double, double, double) lonMaxStats = computeStats(_buffer.map((_WispTransformSample s) => s.lonMax).toList()..sort());
    final (double, double, double) screenXMinStats = computeStats(_buffer.map((_WispTransformSample s) => s.screenXMin).toList()..sort());
    final (double, double, double) screenXMaxStats = computeStats(_buffer.map((_WispTransformSample s) => s.screenXMax).toList()..sort());
    final (double, double, double) screenYMinStats = computeStats(_buffer.map((_WispTransformSample s) => s.screenYMin).toList()..sort());
    final (double, double, double) screenYMaxStats = computeStats(_buffer.map((_WispTransformSample s) => s.screenYMax).toList()..sort());
    final (double, double, double) spawnRateStats = computeStats(_buffer.map((_WispTransformSample s) => s.spawnRatePerSecond).toList()..sort());

    int activeMax = 0;
    int activeSum = 0;
    for (final _WispTransformSample s in _buffer) {
      if (s.activeCount > activeMax) activeMax = s.activeCount;
      activeSum += s.activeCount;
    }
    final double activeMean = activeSum / sampleCount;

    // WALL-CLOCK source — required for the post-walk join with the sibling streams. Do not
    // switch to a Stopwatch-derived value.
    final int epochSecond = DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;

    final String line = json.encode(<String, Object>{
      'epochSecond': epochSecond,
      'sampleCount': sampleCount,
      'activeCountMax': activeMax,
      'activeCountMean': activeMean.toStringAsFixed(_fractionDigits),
      'meanAgeMin': meanAgeStats.$1.toStringAsFixed(_fractionDigits),
      'meanAgeMedian': meanAgeStats.$2.toStringAsFixed(_fractionDigits),
      'meanAgeMax': meanAgeStats.$3.toStringAsFixed(_fractionDigits),
      'latMinMin': latMinStats.$1.toStringAsFixed(_fractionDigits),
      'latMinMedian': latMinStats.$2.toStringAsFixed(_fractionDigits),
      'latMinMax': latMinStats.$3.toStringAsFixed(_fractionDigits),
      'latMaxMin': latMaxStats.$1.toStringAsFixed(_fractionDigits),
      'latMaxMedian': latMaxStats.$2.toStringAsFixed(_fractionDigits),
      'latMaxMax': latMaxStats.$3.toStringAsFixed(_fractionDigits),
      'lonMinMin': lonMinStats.$1.toStringAsFixed(_fractionDigits),
      'lonMinMedian': lonMinStats.$2.toStringAsFixed(_fractionDigits),
      'lonMinMax': lonMinStats.$3.toStringAsFixed(_fractionDigits),
      'lonMaxMin': lonMaxStats.$1.toStringAsFixed(_fractionDigits),
      'lonMaxMedian': lonMaxStats.$2.toStringAsFixed(_fractionDigits),
      'lonMaxMax': lonMaxStats.$3.toStringAsFixed(_fractionDigits),
      'screenXMinMin': screenXMinStats.$1.toStringAsFixed(_fractionDigits),
      'screenXMinMedian': screenXMinStats.$2.toStringAsFixed(_fractionDigits),
      'screenXMinMax': screenXMinStats.$3.toStringAsFixed(_fractionDigits),
      'screenXMaxMin': screenXMaxStats.$1.toStringAsFixed(_fractionDigits),
      'screenXMaxMedian': screenXMaxStats.$2.toStringAsFixed(_fractionDigits),
      'screenXMaxMax': screenXMaxStats.$3.toStringAsFixed(_fractionDigits),
      'screenYMinMin': screenYMinStats.$1.toStringAsFixed(_fractionDigits),
      'screenYMinMedian': screenYMinStats.$2.toStringAsFixed(_fractionDigits),
      'screenYMinMax': screenYMinStats.$3.toStringAsFixed(_fractionDigits),
      'screenYMaxMin': screenYMaxStats.$1.toStringAsFixed(_fractionDigits),
      'screenYMaxMedian': screenYMaxStats.$2.toStringAsFixed(_fractionDigits),
      'screenYMaxMax': screenYMaxStats.$3.toStringAsFixed(_fractionDigits),
      'spawnRatePerSecondMin': spawnRateStats.$1.toStringAsFixed(_fractionDigits),
      'spawnRatePerSecondMedian': spawnRateStats.$2.toStringAsFixed(_fractionDigits),
      'spawnRatePerSecondMax': spawnRateStats.$3.toStringAsFixed(_fractionDigits),
    });
    _log.info(line);
    _buffer.clear();
  }
}

/// Decimal places written for every double column (sub-µdegree / sub-µpixel resolution).
const int _fractionDigits = 6;

/// Immutable per-paint observation — private because the JSONL rollup is its only consumer.
@immutable
class _WispTransformSample {
  const _WispTransformSample({
    required this.frameCounter,
    required this.activeCount,
    required this.meanAge,
    required this.latMin,
    required this.latMax,
    required this.lonMin,
    required this.lonMax,
    required this.screenXMin,
    required this.screenXMax,
    required this.screenYMin,
    required this.screenYMax,
    required this.spawnRatePerSecond,
  });

  final int frameCounter;
  final int activeCount;
  final double meanAge;
  final double latMin;
  final double latMax;
  final double lonMin;
  final double lonMax;
  final double screenXMin;
  final double screenXMax;
  final double screenYMin;
  final double screenYMax;
  final double spawnRatePerSecond;
}

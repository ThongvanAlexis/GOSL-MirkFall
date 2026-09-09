// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';

/// 1-second JSONL rollup of SDF rebuild stats (POC FOG-03, ported by Phase 09.1 plan 09.1-05).
///
/// Diagnostic ported from the POC — active ONLY in verbose logging (`--dart-define=DEBUG=true` or
/// the debug-menu "Verbose logging" toggle, CLAUDE.md §Logging). While
/// `Logger('infrastructure.mirk.sdf').isLoggable(Level.FINE)` is false, [recordRebuild] and the
/// rollup are no-ops. The periodic timer is armed LAZILY by the first verbose sample after
/// [start] and disarmed by the first rollup that finds verbose off, so a non-verbose renderer
/// (production default, every widget test) owns zero timers while the debug-menu toggle still
/// acts live on the next sample — no renderer re-creation needed.
///
/// Per-rebuild lines are noise during a 120 Hz pan; 1-second rollups give post-walk grep enough
/// resolution to correlate SDF activity with the frame-delta probe. Every Phase 09.1 diagnostic
/// logger (frame-delta, fog-transform, this one, wisp-transform) emits on the same
/// [kMirkFogDiagRollupSeconds] cadence with a wall-clock `epochSecond` so the four streams can be
/// joined by that key (invariant 6). Idle seconds (no [recordRebuild] call) emit nothing.
///
/// Sample stats over the buffered durations: median = `sorted[len ~/ 2]`,
/// p95 = `sorted[(len * 0.95).floor()]`, max = `sorted.last`.
class SdfRebuildLogger {
  /// [rollupInterval] is a test seam — defaults to [kMirkFogDiagRollupSeconds] in production.
  /// Tests pass a shorter interval (e.g. 100 ms) to keep the suite fast.
  SdfRebuildLogger({Duration? rollupInterval}) : _rollupInterval = rollupInterval ?? const Duration(seconds: kMirkFogDiagRollupSeconds);

  static final Logger _log = Logger('infrastructure.mirk.sdf');

  final Duration _rollupInterval;
  final List<double> _elapsedMsBuffer = <double>[];
  int _lastDiscCount = 0;
  int _lastIntersectingDiscCount = 0;

  /// Between [start] and [stop]. The timer itself only exists while there is verbose traffic.
  bool _running = false;
  Timer? _timer;

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
    if (_elapsedMsBuffer.isNotEmpty) {
      _emitRollup();
    }
  }

  /// Records one rebuild's duration + disc context. No-op unless verbose. The buffer clears on
  /// every emit.
  void recordRebuild({required double elapsedMs, required int discCount, required int intersectingDiscCount}) {
    if (!_isVerbose) return;
    _elapsedMsBuffer.add(elapsedMs);
    _lastDiscCount = discCount;
    _lastIntersectingDiscCount = intersectingDiscCount;
    _armIfNeeded();
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

  void _emitRollup() {
    if (_elapsedMsBuffer.isEmpty) return;
    if (!_isVerbose) {
      // Samples recorded before the toggle went off are dropped rather than emitted late.
      _elapsedMsBuffer.clear();
      return;
    }
    final List<double> sorted = List<double>.from(_elapsedMsBuffer)..sort();
    final double median = sorted[sorted.length ~/ 2];
    final int p95Index = (sorted.length * _p95Fraction).floor().clamp(0, sorted.length - 1);
    final double p95 = sorted[p95Index];
    final double maxMs = sorted.last;
    // Wall-clock second — REQUIRED for the post-walk join with the sibling streams.
    final int epochSecond = DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final String line = json.encode(<String, Object>{
      'epochSecond': epochSecond,
      'discCount': _lastDiscCount,
      'intersectingDiscCount': _lastIntersectingDiscCount,
      'rebuildCount': _elapsedMsBuffer.length,
      'medianMs': double.parse(median.toStringAsFixed(_msFractionDigits)),
      'p95Ms': double.parse(p95.toStringAsFixed(_msFractionDigits)),
      'maxMs': double.parse(maxMs.toStringAsFixed(_msFractionDigits)),
    });
    _log.info(line);
    _elapsedMsBuffer.clear();
  }
}

/// Percentile fraction of the p95 column.
const double _p95Fraction = 0.95;

/// Millisecond precision written to the JSONL line (µs resolution is enough for a CPU build).
const int _msFractionDigits = 3;

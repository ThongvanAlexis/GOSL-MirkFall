// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 — port of the POC `FrameDeltaProbe`
// (`mirk-poc-debug` @ 90c9321, `lib/infrastructure/mirk/frame_delta_probe.dart`).
// Changes vs the POC: `kPoc*` constants → `kMirkFogDiag*`, verbose-only gating
// (CLAUDE.md §Logging), production `record*` is a no-op before `start()`.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mirkfall/config/constants.dart';

/// Per-second probe rollup payload — emitted on the [FrameDeltaProbe.rollups]
/// stream and persisted as one JSONL line via `Logger('infrastructure.mirk.frame_delta')`.
///
/// All `*Micros` fields are integer microseconds derived from a monotonic
/// `Stopwatch.elapsedMicroseconds` source (see [FrameDeltaProbe] dual-clock
/// discipline). The `*Ms` getters are 3-decimal convenience values that match
/// the millisecond convention of the other diagnostic loggers so post-walk
/// tooling reads both formats with the same parser.
class FrameDeltaRollup {
  /// Constructs a rollup payload.
  const FrameDeltaRollup({required this.epochSecond, required this.sampleCount, required this.medianMicros, required this.p95Micros, required this.maxMicros});

  /// Wall-clock epoch second of this rollup window (`DateTime.now() / 1000`).
  /// Required for grep-correlation with the other rollup loggers, which use
  /// the same wall-clock derivation. NEVER Stopwatch-derived.
  final int epochSecond;

  /// Number of raw samples that fed into this rollup
  /// (always <= [kMirkFogDiagFrameDeltaBufferMaxSamples]).
  final int sampleCount;

  /// Median camera-snapshot → fog-uniform-population delta in microseconds.
  final int medianMicros;

  /// p95 of the same delta in microseconds.
  final int p95Micros;

  /// Max of the same delta in microseconds.
  final int maxMicros;

  /// Median delta in milliseconds (post-walk tooling parity).
  double get medianMs => medianMicros / _kMicrosPerMilli;

  /// p95 delta in milliseconds.
  double get p95Ms => p95Micros / _kMicrosPerMilli;

  /// Max delta in milliseconds.
  double get maxMs => maxMicros / _kMicrosPerMilli;
}

/// Frame-delta self-debug probe (FOG-08 / PERF-07) — POC diagnostic, active
/// only in verbose logging (`--dart-define=DEBUG=true` or the debug-menu
/// toggle) — CLAUDE.md §Logging.
///
/// Records the per-frame delta between the moment `FogLayer.build` reads
/// `MapCamera.of(context)` (the camera snapshot) and the moment the painter
/// hands the `MirkPaintContext` to the renderer (uniform population).
/// Aggregates raw samples into rollups at [kMirkFogDiagRollupSeconds] cadence,
/// exposes them as a broadcast `Stream<FrameDeltaRollup>` and persists each
/// rollup as a structured JSONL line.
///
/// ## Wire flow
///
/// 1. `FogLayer.build()` reads `MapCamera.of(context)` once, then calls
///    [recordCameraSnapshot]; the returned microsecond stamp is threaded into
///    the painter's constructor.
/// 2. `_FogPainter.paint()` calls [recordFogUniformPopulation] right before
///    `renderer.paint(...)`; the probe records `now - snapshot`.
///
/// ## Verbose gating
///
/// [recordFogUniformPopulation] and the rollup timer callback early-return
/// while `Logger('infrastructure.mirk.frame_delta').isLoggable(Level.FINE)`
/// is false, so production (root level INFO) pays a boolean check per paint
/// and emits nothing. The timer stays armed so the debug-menu toggle acts
/// without remounting the layer. Production `record*` before [start] is a
/// no-op as well.
///
/// ## Dual-clock discipline (DO NOT collapse into one clock)
///
/// * `_clock` (monotonic `Stopwatch`) — sole source for delta math. Immune to
///   NTP corrections during a walk. A non-monotonic input clamps the delta at
///   0 instead of throwing — the probe must never crash the paint path.
/// * `DateTime.now()` (wall-clock) — sole source for [FrameDeltaRollup.epochSecond],
///   required so the diagnostic streams can be joined post-walk.
class FrameDeltaProbe {
  /// Constructs a probe. The rollup timer does NOT start until [start] is called.
  ///
  /// Test seams: [rollupInterval] (default [kMirkFogDiagRollupSeconds]) and
  /// [clock] (default a fresh started `Stopwatch`; started here if not running).
  FrameDeltaProbe({Duration? rollupInterval, Stopwatch? clock})
    : _rollupInterval = rollupInterval ?? const Duration(seconds: kMirkFogDiagRollupSeconds),
      _clock = clock ?? (Stopwatch()..start()) {
    if (!_clock.isRunning) _clock.start();
  }

  static final Logger _log = Logger('infrastructure.mirk.frame_delta');

  final Duration _rollupInterval;
  final Stopwatch _clock;
  final List<int> _buffer = <int>[];
  final StreamController<FrameDeltaRollup> _controller = StreamController<FrameDeltaRollup>.broadcast();

  Timer? _timer;

  /// Whether the diagnostic is enabled (verbose logging active).
  bool get _isVerbose => _log.isLoggable(Level.FINE);

  /// Whether [start] has been called and [stop] has not.
  bool get isRunning => _timer != null;

  /// Multi-subscriber stream of rollups (overlay + post-walk inspectors).
  Stream<FrameDeltaRollup> get rollups => _controller.stream;

  /// Returns the monotonic Stopwatch microsecond reading at "right now".
  /// Pair each call with a later [recordFogUniformPopulation] passing this value.
  int recordCameraSnapshot() => _clock.elapsedMicroseconds;

  /// Records the per-frame delta `max(0, now - snapshotMicros)` into the ring
  /// buffer. No-op unless verbose AND [isRunning]. Oldest samples are dropped
  /// FIFO past [kMirkFogDiagFrameDeltaBufferMaxSamples].
  void recordFogUniformPopulation(int snapshotMicros) {
    if (!_isVerbose || !isRunning) return;
    final int now = _clock.elapsedMicroseconds;
    _pushDelta(now - snapshotMicros);
  }

  /// Test-only seam — appends [micros] directly to the ring buffer (clamped at
  /// >= 0), bypassing the live Stopwatch read AND the running / verbose gates
  /// so unit tests can inject deterministic samples before [start]. The
  /// rollup emission itself stays verbose-gated. Production code MUST NOT call this.
  @visibleForTesting
  void debugRecordRawDelta(int micros) => _pushDelta(micros);

  /// Schedules the periodic rollup timer. Idempotent.
  void start() {
    _timer ??= Timer.periodic(_rollupInterval, (_) => _emitRollup());
  }

  /// Cancels the rollup timer. Idempotent. The [rollups] stream stays open until [dispose].
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels the timer, clears the ring buffer and closes the rollup stream.
  /// Idempotent (`StreamController.close` is idempotent).
  Future<void> dispose() async {
    stop();
    _buffer.clear();
    await _controller.close();
  }

  void _pushDelta(int delta) {
    _buffer.add(math.max(0, delta));
    while (_buffer.length > kMirkFogDiagFrameDeltaBufferMaxSamples) {
      _buffer.removeAt(0);
    }
  }

  /// Computes one rollup from the current buffer and emits it on both the
  /// stream and the JSONL logger. Idle windows (empty buffer) emit nothing;
  /// non-verbose windows drop the buffer silently.
  void _emitRollup() {
    if (!_isVerbose) {
      _buffer.clear();
      return;
    }
    if (_buffer.isEmpty) return;
    final List<int> sorted = List<int>.from(_buffer)..sort();
    final int medianMicros = sorted[sorted.length ~/ 2];
    final int p95Index = (sorted.length * _kP95Quantile).floor().clamp(0, sorted.length - 1);
    final int p95Micros = sorted[p95Index];
    final int maxMicros = sorted.last;
    // WALL-CLOCK source — REQUIRED for the post-walk join with the other rollup loggers.
    final int epochSecond = DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final FrameDeltaRollup rollup = FrameDeltaRollup(
      epochSecond: epochSecond,
      sampleCount: _buffer.length,
      medianMicros: medianMicros,
      p95Micros: p95Micros,
      maxMicros: maxMicros,
    );
    _controller.add(rollup);
    _log.info(
      json.encode(<String, Object>{
        'epochSecond': epochSecond,
        'sampleCount': rollup.sampleCount,
        'medianMicros': rollup.medianMicros,
        'p95Micros': rollup.p95Micros,
        'maxMicros': rollup.maxMicros,
        'medianMs': double.parse(rollup.medianMs.toStringAsFixed(_kMsDecimals)),
        'p95Ms': double.parse(rollup.p95Ms.toStringAsFixed(_kMsDecimals)),
        'maxMs': double.parse(rollup.maxMs.toStringAsFixed(_kMsDecimals)),
      }),
    );
    _buffer.clear();
  }
}

/// Microseconds per millisecond, as a double for the `*Ms` getters.
const double _kMicrosPerMilli = 1000.0;

/// Decimal places of the `*Ms` JSONL fields (matches the other rollup loggers).
const int _kMsDecimals = 3;

/// Quantile of the p95 statistic.
const double _kP95Quantile = 0.95;

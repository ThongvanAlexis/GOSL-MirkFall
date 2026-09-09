// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:flutter/foundation.dart';

/// 1-second JSONL rollup of per-paint wisp diagnostic state (POC WISP-05, verbose-only).
///
/// RED stub — Phase 09.1 plan 09.1-05 Task 2. Replaced by the ported implementation in the GREEN commit.
class WispTransformLogger {
  /// [rollupInterval] is a test seam — defaults to `kMirkFogDiagRollupSeconds` in production.
  WispTransformLogger({Duration? rollupInterval});

  /// Starts the rollup timer.
  void start() => throw UnimplementedError('09.1-05 Task 2 GREEN');

  /// Cancels the timer and flushes a final rollup.
  void stop() => throw UnimplementedError('09.1-05 Task 2 GREEN');

  /// Records one paint observation.
  void recordPaint({
    required int activeCount,
    required double meanAge,
    required (double, double) latBounds,
    required (double, double) lonBounds,
    required (double, double) screenXBounds,
    required (double, double) screenYBounds,
    required double spawnRatePerSecond,
  }) => throw UnimplementedError('09.1-05 Task 2 GREEN');

  /// `(min, median, max)` of a non-empty ascending list.
  @visibleForTesting
  static (double min, double median, double max) computeStats(List<double> sortedAscending) => throw UnimplementedError('09.1-05 Task 2 GREEN');
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:logging/logging.dart';

/// 1-second JSONL rollup of SDF rebuild stats (POC FOG-03, verbose-only).
///
/// RED stub — Phase 09.1 plan 09.1-05 Task 1. Replaced by the ported implementation in the GREEN commit.
class SdfRebuildLogger {
  /// [rollupInterval] is a test seam — defaults to `kMirkFogDiagRollupSeconds` in production.
  SdfRebuildLogger({Duration? rollupInterval});

  static final Logger _log = Logger('infrastructure.mirk.sdf');

  /// Starts the rollup timer.
  void start() => throw UnimplementedError('09.1-05 Task 1 GREEN — ${_log.fullName}');

  /// Cancels the timer and flushes a final rollup.
  void stop() => throw UnimplementedError('09.1-05 Task 1 GREEN');

  /// Records one rebuild's duration + disc context.
  void recordRebuild({required double elapsedMs, required int discCount, required int intersectingDiscCount}) =>
      throw UnimplementedError('09.1-05 Task 1 GREEN');
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' as ui;

import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

import '../sdf_rebuild_logger.dart';
import 'revealed_sdf_builder.dart';

/// Quantised-key cache in front of [RevealedSdfBuilder] (POC FOG-03 / PERF-08).
///
/// RED stub — Phase 09.1 plan 09.1-05 Task 1. Replaced by the ported implementation in the GREEN commit.
class SdfCache {
  /// [builder] is a test seam — production wires the const [RevealedSdfBuilder].
  SdfCache({required SdfRebuildLogger rebuildLogger, RevealedSdfBuilder? builder});

  /// Returns the cached image on a key hit, or rebuilds through the builder on a miss.
  Future<ui.Image> getOrBuild({required List<RevealDisc> discs, required MirkViewportBbox viewport}) => throw UnimplementedError('09.1-05 Task 1 GREEN');

  /// Releases the cached image.
  void dispose() => throw UnimplementedError('09.1-05 Task 1 GREEN');
}

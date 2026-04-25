// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:freezed_annotation/freezed_annotation.dart';

import '../fixes/fix.dart';
import 'mirk_viewport_bbox.dart';
import 'visible_mirk_tile.dart';

part 'mirk_paint_context.freezed.dart';

/// Inputs passed to [MirkRenderer.paint] on every frame.
///
/// Phase 09 extends the Phase 07 shape with three fields ([viewportBbox],
/// [currentFix], [visibleTiles]). The Freezed-codegen friction of new
/// required fields is INTENTIONAL per the Phase 07 docstring: adding to
/// this record forces every call site to be reviewed. This is the
/// **single extension event** for Phase 09 — downstream plans
/// (09-04 renderers, 09-07 overlay, etc.) consume the extended shape
/// without re-opening the Freezed.
///
/// Fields:
/// * [zoomLevel] — current MapLibre zoom (>= 0).
/// * [pixelRatio] — device pixel ratio (> 0).
/// * [sessionElapsed] — monotonic elapsed-since-session-start. Retained
///   verbatim from Phase 07 (NOT renamed to `frameElapsed`). Drives
///   animation phase in the noise-based renderers
///   (atmospheric / candlelight / heavenly_clouds). A future phase may
///   reassess whether a separate per-frame Ticker time is needed; Phase
///   09 consolidates on this one field per research §MirkPaintContext
///   Extension Spec recommendation.
/// * [viewportBbox] — current viewport bounds in lat/lon. Populated by
///   `MirkOverlay` (plan 09-07) from the `MapView.viewportUpdates`
///   stream, debounced.
/// * [currentFix] — the most recently accepted GPS fix, or `null` before
///   the first fix arrives. Consumed by `CandlelightMirkRenderer` to
///   centre the radial glow; atmospheric / solid / heavenly_clouds may
///   ignore it.
/// * [visibleTiles] — list of parent tiles intersecting [viewportBbox]
///   with their pre-projected lat/lon extents + bitmap. Empty list
///   (`const []`) is valid (no session, or no visible revealed areas).
@freezed
abstract class MirkPaintContext with _$MirkPaintContext {
  @Assert('zoomLevel >= 0.0', 'MirkPaintContext.zoomLevel must be >= 0')
  @Assert('pixelRatio > 0.0', 'MirkPaintContext.pixelRatio must be > 0')
  factory MirkPaintContext({
    required double zoomLevel,
    required double pixelRatio,
    required Duration sessionElapsed,
    required MirkViewportBbox viewportBbox,
    required List<VisibleMirkTile> visibleTiles,
    Fix? currentFix,
  }) = _MirkPaintContext;
}

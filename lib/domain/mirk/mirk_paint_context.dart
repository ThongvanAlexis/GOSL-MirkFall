// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'package:freezed_annotation/freezed_annotation.dart';

import '../fixes/fix.dart';
import '../revealed/reveal_disc.dart';
import 'mirk_viewport_bbox.dart';

part 'mirk_paint_context.freezed.dart';

/// Inputs passed to [MirkRenderer.paint] on every frame.
///
/// BUG-010 Option B Commit 5 collapsed the dual-input shape (the
/// per-tile `visibleTiles` bitmap surface kept around through
/// Commit 4 for tests-during-transition) down to the canonical
/// continuous-geometry input: a list of [RevealDisc]s. The renderers
/// feed [discs] directly to [`RevealedSdfBuilder.buildFromDiscs`] and
/// to [`buildViewportFogClipPathFromDiscs`] for the clip path.
///
/// Fields:
/// * [zoomLevel] — current MapLibre zoom (>= 0).
/// * [pixelRatio] — device pixel ratio (> 0).
/// * [sessionElapsed] — monotonic elapsed-since-session-start. Drives
///   animation phase in the noise-based renderers
///   (atmospheric / candlelight / heavenly_clouds).
/// * [viewportBbox] — current viewport bounds in lat/lon. Populated by
///   `MirkOverlay` (plan 09-07) from the `MapView.viewportUpdates`
///   stream, debounced.
/// * [currentFix] — the most recently accepted GPS fix, or `null` before
///   the first fix arrives. Consumed by `CandlelightMirkRenderer` to
///   centre the radial glow; atmospheric / solid / heavenly_clouds may
///   ignore it.
/// * [discs] — list of [RevealDisc]s of the active session intersecting
///   [viewportBbox]. Empty list is the canonical "nothing revealed yet"
///   shape — fog covers the entire viewport rect, the SDF degenerates to
///   uniform far-fog. Required (no default): callers must explicitly
///   decide what disc set the renderer sees.
@freezed
abstract class MirkPaintContext with _$MirkPaintContext {
  @Assert('zoomLevel >= 0.0', 'MirkPaintContext.zoomLevel must be >= 0')
  @Assert('pixelRatio > 0.0', 'MirkPaintContext.pixelRatio must be > 0')
  factory MirkPaintContext({
    required double zoomLevel,
    required double pixelRatio,
    required Duration sessionElapsed,
    required MirkViewportBbox viewportBbox,
    required List<RevealDisc> discs,
    Fix? currentFix,
  }) = _MirkPaintContext;
}

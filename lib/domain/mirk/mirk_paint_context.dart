// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Offset;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../fixes/fix.dart';
import '../geo/geo_point.dart';
import '../revealed/reveal_disc.dart';
import 'mirk_viewport_bbox.dart';

part 'mirk_paint_context.freezed.dart';

/// Projects a geographic point to screen pixels in the painter's IDENTITY frame — i.e.
/// after the `FogLayer` has applied `canvas.translate(-canvasOffset)`. Supplied by the
/// `FogLayer` from the single per-paint `MapCamera` snapshot (FOG-07) so every renderer
/// projects with exactly the camera the tile layer painted with.
typedef ScreenProjector = Offset Function(GeoPoint point);

/// Converts a metric distance to screen pixels at [atLatitude] (distance between two points
/// 1 m apart on the latitude axis). Lets renderers size disc radii and wisp spawns without
/// knowing the projection or the engine.
typedef MetersToPixels = double Function(double meters, {required double atLatitude});

/// Inputs passed to [MirkRenderer.paint] on every frame.
///
/// Built by the `FogLayer` on every paint from the unique `MapCamera` snapshot (FOG-07): the
/// renderers never see flutter_map — this context is the whole seam. `dart:ui` `Offset` in a
/// domain type follows the `Canvas` / `Size` precedent of `mirk_renderer.dart` and is
/// permitted by `tool/check_domain_purity.dart` (the gate forbids `package:flutter/*` and
/// `package:drift/*`, not `dart:ui`).
///
/// ## Extension history
///
/// * Phase 07: `zoomLevel`, `pixelRatio`, `sessionElapsed`.
/// * Phase 09 plan 09-02 / BUG-010 Commit 5: `viewportBbox`, `discs`, `currentFix`.
/// * **Phase 09.1 plan 09.1-03 — single extension of the phase**: `pixelOrigin`, `zoomScale`,
///   `sdfRect`, `canvasOffset`, `projectToScreen`, `metersToPixels`. One extension event per
///   phase is the rule (precedent: plan 09-02); any further field goes through a Phase 10
///   review, not an ad-hoc addition.
///
/// ## Phase 09 fields
///
/// * [zoomLevel] — current map zoom (>= 0).
/// * [pixelRatio] — device pixel ratio (> 0).
/// * [sessionElapsed] — monotonic elapsed-since-session-start. Drives animation phase in the
///   noise-based renderers (atmospheric / candlelight / heavenly_clouds). The same-canvas
///   painter derives it from a `Stopwatch` read on every paint (invariant 10).
/// * [viewportBbox] — current viewport bounds in lat/lon.
/// * [discs] — [RevealDisc]s of the active session intersecting [viewportBbox]. Empty list is
///   the canonical "nothing revealed yet" shape — fog covers the whole viewport, the SDF
///   degenerates to uniform far-fog. Required (no default): callers decide the disc set.
/// * [currentFix] — most recently accepted GPS fix, or `null` before the first fix. Consumed
///   by `CandlelightMirkRenderer` to centre the radial glow.
///
/// ## Phase 09.1 fields (camera-derived, one snapshot per paint)
///
/// * [pixelOrigin] — `camera.pixelOrigin`, full-precision world-pixel origin of the viewport
///   (magnitudes ~1e6 at zoom 13, ~4e6 at zoom 15). Feeds `uPixelOrigin` (slots 3-4) so the
///   shader samples noise at each fragment's WORLD position (FOG-17/18). The `.y` component
///   is ALREADY sign-flipped on Android when it reaches the renderers (FOG-23, applied once
///   per paint by `applyPlatformShaderCorrections`) — renderers forward it verbatim.
/// * [zoomScale] — `pow(2, zoomLevel - kMirkFogReferenceZoom)` (> 0). Feeds `uZoomScale`
///   (slot 41) so noise cells stay anchored to lat/lon across zoom transitions; equals 1.0 at
///   the reference zoom where sampling is bit-identical to the pre-FOG-19 formula.
/// * [sdfRect] — the four `uSdfRect*` scalars (slots 37-40): `(0, 0, 1, 1)` identity on iOS,
///   `(0, 1, 1, -1)` V-flip on Android to cancel Impeller-Vulkan's V-up texture sampling
///   (FOG-21). Platform-static by construction — there is NEVER a dynamic viewport→SDF
///   remapping here (the BUG-014 lineage is closed by the same-canvas architecture, not by a
///   rect).
/// * [canvasOffset] — translation the `MobileLayerTransformer` applied to the layer canvas,
///   already compensated by the `FogLayer`'s `translate(-canvasOffset)` before the renderer
///   paints. Informational (diag loggers FOG-12/13); renderers must not re-apply it.
/// * [projectToScreen] — see [ScreenProjector]. Equality is by closure identity.
/// * [metersToPixels] — see [MetersToPixels]. Equality is by closure identity.
@freezed
abstract class MirkPaintContext with _$MirkPaintContext {
  @Assert('zoomLevel >= 0.0', 'MirkPaintContext.zoomLevel must be >= 0')
  @Assert('pixelRatio > 0.0', 'MirkPaintContext.pixelRatio must be > 0')
  @Assert('zoomScale > 0.0', 'MirkPaintContext.zoomScale must be > 0 (pow(2, zoomLevel - kMirkFogReferenceZoom))')
  factory MirkPaintContext({
    required double zoomLevel,
    required double pixelRatio,
    required Duration sessionElapsed,
    required MirkViewportBbox viewportBbox,
    required List<RevealDisc> discs,
    // --- Phase 09.1 — single extension event of the phase ---
    required ({double x, double y}) pixelOrigin,
    required double zoomScale,
    required (double, double, double, double) sdfRect,
    required ({double dx, double dy}) canvasOffset,
    required ScreenProjector projectToScreen,
    required MetersToPixels metersToPixels,
    Fix? currentFix,
  }) = _MirkPaintContext;
}

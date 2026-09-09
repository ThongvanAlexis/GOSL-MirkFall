// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-06 — the edge feather shared by every CPU-painted fog
// body (solid_fill, candlelight, and the fallback paths of the two shader
// renderers). Replaces the pre-09.1 `drawPath(rect − discs, MaskFilter.blur)`
// each renderer did on its own clip path.

import 'dart:ui' show BlendMode, BlurStyle, Canvas, MaskFilter, Offset, Paint, PaintingStyle, Path, Rect, Size;

import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';

import 'fog_clip_geometry.dart';

/// Signature of the body painter handed to [paintFogBodyWithFeatheredEdges]:
/// fills [viewport] (`Offset.zero & size`) with the variant's fog.
typedef FogBodyPainter = void Function(Canvas canvas, Rect viewport);

/// Width of the feather stroke in sigmas, straddling the clip edge by ±2σ.
///
/// The blurred stroke is centred ON the reveal edge: at the edge its coverage
/// is ≈ 0.95, so the fog alpha there is ≈ 0.05 and ramps up to full over the
/// next ~4σ outward. The inner half of the stroke lies inside the hole, which
/// the `FogLayer` clip has already cut — only the outer half is ever visible.
const double _kFeatherStrokeWidthSigmas = 4.0;

/// Paints a fog body inside the clipped identity frame the `FogLayer` provides
/// (Phase 09.1: ONE `clipPath(rect − discs)` per frame, owned by the layer),
/// then softens the reveal edges on the fog side of the cut.
///
/// The feather is a stroke along [buildFogHoleOutlinePath] — same projection
/// and metric radius as the layer's clip — blurred by [featherSigma] and drawn
/// with `BlendMode.dstOut` so it ERASES fog next to the edge. Without the
/// clip the body stays whole (the stroke only touches a ring around each
/// disc): the renderer never cuts the holes itself, it only rounds them.
///
/// `saveLayer` is mandatory, not cosmetic: the fog shares its canvas with the
/// basemap tiles (same-canvas architecture, no `RepaintBoundary`), and an
/// un-layered `dstOut` would punch the map itself. With no disc, or no feather,
/// the body is painted directly (no layer, no stroke).
void paintFogBodyWithFeatheredEdges({
  required Canvas canvas,
  required Size size,
  required MirkPaintContext context,
  required double featherSigma,
  required FogBodyPainter paintBody,
}) {
  final Rect viewport = Offset.zero & size;
  if (context.discs.isEmpty || featherSigma <= 0.0) {
    paintBody(canvas, viewport);
    return;
  }
  final Path holeOutline = buildFogHoleOutlinePath(discs: context.discs, projectToScreen: context.projectToScreen, metersToPixels: context.metersToPixels);
  final Paint featherStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = featherSigma * _kFeatherStrokeWidthSigmas
    ..blendMode = BlendMode.dstOut
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, featherSigma);
  canvas.saveLayer(viewport, Paint());
  paintBody(canvas, viewport);
  canvas.drawPath(holeOutline, featherStroke);
  canvas.restore();
}

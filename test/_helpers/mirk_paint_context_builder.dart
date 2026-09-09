// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-03 — the ONE place tests construct a [MirkPaintContext].
//
// The Phase 09.1 extension added six camera-derived fields to the context. Funnelling
// every fixture through this builder means a future field lands in one file instead of
// every renderer / overlay / domain suite, and keeps the "extension unique" discipline
// visible: a test that needs a new field is a signal to reopen the contract, not to
// hand-roll a context.

import 'dart:ui' show Offset, Size;

import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/mirk_projection.dart';

/// Canvas the default projection maps the viewport onto (256×256 — same as the renderer
/// suites' `kTestCanvasSize`, small enough for sub-millisecond rasterisation).
const Size kTestPaintContextCanvasSize = Size(256, 256);

/// Neutral camera inputs: no world-pixel origin, reference zoom, identity SDF rect, no
/// MobileLayerTransformer translation. What the pre-09.1 screen-space overlay passed.
const ({double x, double y}) kTestNeutralPixelOrigin = (x: 0.0, y: 0.0);
const double kTestNeutralZoomScale = 1.0;
const (double, double, double, double) kTestIdentitySdfRect = (0.0, 0.0, 1.0, 1.0);
const ({double dx, double dy}) kTestNeutralCanvasOffset = (dx: 0.0, dy: 0.0);

/// Default viewport: Paris, 48.85 ± 0.01 lat / 2.35 ± 0.01 lon.
MirkViewportBbox parisTestViewport() => MirkViewportBbox(south: 48.84, west: 2.34, north: 48.86, east: 2.36);

/// Full paint context for renderer / overlay / domain tests. Defaults: Paris viewport,
/// 256×256 canvas, linear projection inside the bbox (what the screen-space overlay did before Phase
/// 09.1), no platform correction. Every field is overridable by named parameter.
///
/// The default [metersToPixels] is the linear latitude-axis scale of the viewport
/// (`meters * canvasHeight / (latSpanDegrees * kMetersPerDegreeLat)`); it ignores
/// `atLatitude` because the linear projection has no latitude-dependent scale.
MirkPaintContext buildTestMirkPaintContext({
  double zoomLevel = 15.0,
  double pixelRatio = 1.0,
  Duration sessionElapsed = Duration.zero,
  MirkViewportBbox? viewportBbox,
  List<RevealDisc> discs = const <RevealDisc>[],
  Fix? currentFix,
  ({double x, double y}) pixelOrigin = kTestNeutralPixelOrigin,
  double zoomScale = kTestNeutralZoomScale,
  (double, double, double, double) sdfRect = kTestIdentitySdfRect,
  ({double dx, double dy}) canvasOffset = kTestNeutralCanvasOffset,
  Size canvasSize = kTestPaintContextCanvasSize,
  ScreenProjector? projectToScreen,
  MetersToPixels? metersToPixels,
}) {
  final MirkViewportBbox viewport = viewportBbox ?? parisTestViewport();
  final double latSpanDegrees = viewport.north - viewport.south;
  Offset defaultProjectToScreen(GeoPoint point) =>
      MirkProjection.latLonToScreen(lat: point.latitude, lon: point.longitude, viewport: viewport, size: canvasSize);
  double defaultMetersToPixels(double meters, {required double atLatitude}) => meters * canvasSize.height / (latSpanDegrees * kMetersPerDegreeLat);
  return MirkPaintContext(
    zoomLevel: zoomLevel,
    pixelRatio: pixelRatio,
    sessionElapsed: sessionElapsed,
    viewportBbox: viewport,
    discs: discs,
    pixelOrigin: pixelOrigin,
    zoomScale: zoomScale,
    sdfRect: sdfRect,
    canvasOffset: canvasOffset,
    projectToScreen: projectToScreen ?? defaultProjectToScreen,
    metersToPixels: metersToPixels ?? defaultMetersToPixels,
    currentFix: currentFix,
  );
}

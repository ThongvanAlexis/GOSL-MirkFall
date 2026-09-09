// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 — pure geometry half of the POC `computeFogClipPath`
// (`mirk-poc-debug` @ 90c9321, `lib/presentation/widgets/fog_clip_path.dart`).
// The camera → projector bridge lives in `lib/presentation/widgets/fog_clip_path.dart`
// (inside the flutter_map import perimeter); this file knows nothing about the engine.

import 'dart:ui' show Offset, Path, PathOperation, Rect, Size;

import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart' show MetersToPixels, ScreenProjector;
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

/// Viewport-rect-minus-disc-circles clip path in screen pixel space (FOG-06).
///
/// `Path.combine(difference, viewportRect, discCircles)`:
///
///   * inside-disc pixels → outside the path → not clipped in → fog NOT drawn
///     (the reveal hole);
///   * outside-disc pixels → inside the path → clipped in → fog DRAWN.
///
/// Each disc centre goes through [projectToScreen] (the single per-paint camera
/// snapshot, FOG-07) and its radius through [metersToPixels] at the disc's own
/// latitude — metric-distance arithmetic, the same discipline as the SDF
/// builder. A pixel-space radius would draw a north-south oval at non-equatorial
/// latitudes (BUG-011).
///
/// Empty [discs] → the viewport rect itself (full fog, no holes).
///
/// [canvasOffset] pre-shifts BOTH the rect and every hole centre by
/// `-canvasOffset`. The production painter does NOT use it (03.1-08-FIX: the
/// `FogLayer` translates the canvas to the identity frame before clipping, so a
/// shift here would double-compensate the hole position); it is kept for the
/// geometry tests and for a caller that clips a non-pre-translated canvas.
Path buildFogClipPath({
  required Size size,
  required List<RevealDisc> discs,
  required ScreenProjector projectToScreen,
  required MetersToPixels metersToPixels,
  Offset canvasOffset = Offset.zero,
}) {
  final Rect viewportRect = Rect.fromLTWH(-canvasOffset.dx, -canvasOffset.dy, size.width, size.height);
  final Path worldPath = Path()..addRect(viewportRect);
  if (discs.isEmpty) return worldPath;
  final Path holesPath = buildFogHoleOutlinePath(discs: discs, projectToScreen: projectToScreen, metersToPixels: metersToPixels, canvasOffset: canvasOffset);
  return Path.combine(PathOperation.difference, worldPath, holesPath);
}

/// The reveal discs alone — one oval contour per disc, same projection and
/// metric radius as [buildFogClipPath] (Phase 09.1-06).
///
/// The `FogLayer` clip already cuts the holes out of the frame; the renderers
/// use this outline to FEATHER the cut (a blurred stroke along it), so both
/// paths agree on the edge to the pixel. Empty [discs] → empty path.
Path buildFogHoleOutlinePath({
  required List<RevealDisc> discs,
  required ScreenProjector projectToScreen,
  required MetersToPixels metersToPixels,
  Offset canvasOffset = Offset.zero,
}) {
  final Path holesPath = Path();
  for (final RevealDisc disc in discs) {
    final GeoPoint discCentre = (latitude: disc.lat, longitude: disc.lon);
    final Offset holeCentre = projectToScreen(discCentre) - canvasOffset;
    final double holeRadiusPx = metersToPixels(disc.radiusMeters, atLatitude: disc.lat);
    holesPath.addOval(Rect.fromCircle(center: holeCentre, radius: holeRadiusPx));
  }
  return holesPath;
}

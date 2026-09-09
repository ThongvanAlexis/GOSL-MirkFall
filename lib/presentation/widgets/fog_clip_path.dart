// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 — camera half of the POC `computeFogClipPath`
// (`mirk-poc-debug` @ 90c9321, `lib/presentation/widgets/fog_clip_path.dart`).
// This file is one of the three presentation files allowed to import flutter_map
// (`tool/check_avoid_flutter_map_leak.dart`): it turns a `MapCamera` snapshot into
// the engine-agnostic `ScreenProjector` / `MetersToPixels` closures the renderers
// and the pure clip geometry consume.

import 'dart:math' show Point;
import 'dart:ui' show Offset, Path, Size;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart' show MetersToPixels, ScreenProjector;
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_clip_geometry.dart';

/// Projects a [GeoPoint] to screen pixels through [camera] (rotation is
/// disabled on the map, so this is the identity frame of the sibling
/// `CircleLayer` puck). Same call site the reveal holes and — via the
/// `MirkPaintContext` — the wisps use: one projection for every pipeline (FOG-07).
ScreenProjector cameraScreenProjector(MapCamera camera) =>
    (GeoPoint point) => _pointToOffset(camera.latLngToScreenPoint(LatLng(point.latitude, point.longitude)));

/// Converts a metric distance to screen pixels at `atLatitude` by projecting
/// two points 1 m apart along the latitude axis through [camera].
///
/// Why the latitude axis: a meridian is a great circle, so 1 m of latitude is
/// `1 / kMetersPerDegreeLat` degrees everywhere (accurate to ~0.5 %, far below
/// GPS accuracy); the longitude axis would need a `cos(lat)` correction.
MetersToPixels cameraMetersToPixels(MapCamera camera) => (double meters, {required double atLatitude}) {
  final Point<double> origin = camera.latLngToScreenPoint(LatLng(atLatitude, 0));
  final Point<double> oneMetreNorth = camera.latLngToScreenPoint(LatLng(atLatitude + 1.0 / kMetersPerDegreeLat, 0));
  final double pixelsPerMetre = origin.distanceTo(oneMetreNorth);
  return meters * pixelsPerMetre;
};

/// Viewport rect minus the projected reveal discs (FOG-06) — see [buildFogClipPath].
///
/// The production painter leaves [canvasOffset] at zero: it has already
/// translated the canvas to the identity frame (03.1-08-FIX).
Path computeFogClipPath({required MapCamera camera, required List<RevealDisc> discs, Offset canvasOffset = Offset.zero}) => buildFogClipPath(
  size: Size(camera.size.x, camera.size.y),
  discs: discs,
  projectToScreen: cameraScreenProjector(camera),
  metersToPixels: cameraMetersToPixels(camera),
  canvasOffset: canvasOffset,
);

/// flutter_map projects to `dart:math` `Point<double>`; `dart:ui` wants `Offset`.
Offset _pointToOffset(Point<double> point) => Offset(point.x, point.y);

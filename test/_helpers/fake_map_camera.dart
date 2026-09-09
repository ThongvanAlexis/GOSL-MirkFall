// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 — port of the POC `test/_helpers/fake_map_camera.dart`
// (`mirk-poc-debug` @ 90c9321) merged with the `_fakeCamera()` idiom of the POC
// `fog_clip_path_test.dart` (real `MapCamera` constructor, `Epsg3857`, explicit
// `nonRotatedSize`).

import 'dart:math' show Point;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Melun town centre — the POC walk theatre. Every fog widget test keeps it so
/// the numeric expectations (pixelOrigin ~1.06M at zoom 13, ~411 px pan delta
/// for the FOG-09 trajectory) port unchanged.
const LatLng kTestMapCenter = LatLng(48.5397, 2.6553);

/// Default test zoom == `kMirkFogReferenceZoom` (zoomScale 1.0).
const double kTestMapZoom = 13.0;

/// Default synthetic viewport (portrait phone) as flutter_map's `Point<double>`.
const Point<double> kTestMapViewportSize = Point<double>(400, 800);

/// Builds a real flutter_map `MapCamera` (rotation 0) for the pure clip-path /
/// projection tests — no widget tree needed.
MapCamera fakeMapCamera({LatLng center = kTestMapCenter, double zoom = kTestMapZoom, Point<double> nonRotatedSize = kTestMapViewportSize}) =>
    MapCamera(crs: const Epsg3857(), center: center, zoom: zoom, rotation: 0, nonRotatedSize: nonRotatedSize);

/// Counts `MapCamera.of(context)` reads during widget tests by capturing
/// invocations of the `FogLayer.debugOnCameraRead` static seam (FOG-07).
class CameraAccessCounter {
  /// Live read count. Wire [recordRead] to `FogLayer.debugOnCameraRead` before pumping.
  int count = 0;

  /// Increment hook — pass as the `FogLayer.debugOnCameraRead` callback.
  void recordRead() => count++;
}

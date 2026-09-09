// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_clip_path_test.dart — invariant FOG-06 (+ BUG-011 metric radius)

import 'dart:math' show Point, cos, pi;
import 'dart:ui' show Offset, Path, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/presentation/widgets/fog_clip_path.dart';

import '../../_helpers/fake_map_camera.dart';
import '../../_helpers/fog_layer_test_harness.dart';

/// FOG-06 — `computeFogClipPath` through a real flutter_map `MapCamera`
/// (`Epsg3857`, Melun, z13, 400×800): the camera → projector bridge plus the
/// metric-radius converter (`cameraMetersToPixels`).
void main() {
  const double discRadiusMeters = 100.0;
  final RevealDisc centreDisc = centreTestDisc(radiusMeters: discRadiusMeters, id: 'rvd_a');

  group('computeFogClipPath (FOG-06)', () {
    test('empty discs returns the viewport rect (no holes)', () {
      final camera = fakeMapCamera();
      final Path path = computeFogClipPath(camera: camera, discs: const <RevealDisc>[]);
      expect(path.getBounds(), equals(const Rect.fromLTWH(0, 0, 400, 800)));
      expect(path.contains(const Offset(200, 400)), isTrue);
      expect(path.contains(const Offset(10, 10)), isTrue);
    });

    test('one disc at the camera centre carves a hole centred on camera.latLngToScreenPoint with a metric radius (± 0.5 px)', () {
      final camera = fakeMapCamera();
      final Path path = computeFogClipPath(camera: camera, discs: <RevealDisc>[centreDisc]);
      final Point<double> projected = camera.latLngToScreenPoint(LatLng(centreDisc.lat, centreDisc.lon));
      final Offset holeCentre = Offset(projected.x, projected.y);
      final double holeRadiusPx = cameraMetersToPixels(camera)(discRadiusMeters, atLatitude: centreDisc.lat);

      expect(holeCentre.dx, closeTo(200, 1e-6), reason: 'camera centre projects to the viewport centre');
      expect(holeCentre.dy, closeTo(400, 1e-6));
      expect(holeRadiusPx, greaterThan(2.0), reason: '100 m at z13 / 48.5° N is ~7.9 px — enough to probe ± 0.5 px');
      expect(path.getBounds(), equals(const Rect.fromLTWH(0, 0, 400, 800)), reason: 'the hole is INSIDE the rect');
      expect(path.contains(holeCentre), isFalse, reason: 'inside the disc → fog NOT drawn');
      expect(path.contains(const Offset(10, 10)), isTrue, reason: 'near the corner → still fog');
      for (final Offset axis in <Offset>[const Offset(1, 0), const Offset(0, 1), const Offset(-1, 0), const Offset(0, -1)]) {
        expect(path.contains(holeCentre + axis * (holeRadiusPx - 0.5)), isFalse, reason: 'just inside the metric radius along $axis');
        expect(path.contains(holeCentre + axis * (holeRadiusPx + 0.5)), isTrue, reason: 'just outside the metric radius along $axis');
      }
    });

    test('disc far outside the viewport leaves every interior point fog-drawn', () {
      final camera = fakeMapCamera();
      final RevealDisc farDisc = RevealDisc(id: 'rvd_far', sessionId: 's', lat: 49.5397, lon: 2.6553, radiusMeters: 100.0, fixedAtUtc: DateTime.utc(2026, 5));
      final Path path = computeFogClipPath(camera: camera, discs: <RevealDisc>[farDisc]);
      expect(path.contains(const Offset(200, 400)), isTrue);
      expect(path.contains(const Offset(10, 10)), isTrue);
    });

    test('CANVAS-FRAME-ALIGNMENT (FOG-12 unit) — canvasOffset shifts the rect and the hole by -canvasOffset', () {
      final camera = fakeMapCamera();
      final Path pathWithoutOffset = computeFogClipPath(camera: camera, discs: <RevealDisc>[centreDisc]);
      final Path pathWithOffset = computeFogClipPath(camera: camera, discs: <RevealDisc>[centreDisc], canvasOffset: const Offset(5, -44));
      final Rect boundsZero = pathWithoutOffset.getBounds();
      final Rect boundsOffset = pathWithOffset.getBounds();
      expect((boundsOffset.left - (boundsZero.left - 5)).abs(), lessThan(kTestCanvasTransformEpsilon));
      expect((boundsOffset.top - (boundsZero.top - (-44))).abs(), lessThan(kTestCanvasTransformEpsilon));
      expect(pathWithOffset.contains(const Offset(200 - 5, 400 + 44)), isFalse, reason: 'the hole moved with the rect');
    });
  });

  group('camera bridges', () {
    test('cameraScreenProjector projects the camera centre to the viewport centre and tracks the camera', () {
      final camera = fakeMapCamera();
      final Offset centre = cameraScreenProjector(camera)((latitude: kTestMapCenter.latitude, longitude: kTestMapCenter.longitude));
      expect(centre.dx, closeTo(200, 1e-6));
      expect(centre.dy, closeTo(400, 1e-6));
      final Offset north = cameraScreenProjector(camera)((latitude: kTestMapCenter.latitude + 0.01, longitude: kTestMapCenter.longitude));
      expect(north.dy, lessThan(centre.dy), reason: 'screen y grows southward');
      expect(north.dx, closeTo(centre.dx, 1e-6));
    });

    test('cameraMetersToPixels matches the Web Mercator ground resolution at the camera latitude', () {
      final camera = fakeMapCamera();
      const double earthCircumferenceMeters = 40075016.686;
      const double worldPixelsAtZ13 = 256.0 * 8192.0;
      final double expectedPixelsPerMetre = worldPixelsAtZ13 / (earthCircumferenceMeters * cos(kTestMapCenter.latitude * pi / 180.0));
      expect(cameraMetersToPixels(camera)(1.0, atLatitude: kTestMapCenter.latitude), closeTo(expectedPixelsPerMetre, 5e-4));
      expect(cameraMetersToPixels(camera)(100.0, atLatitude: kTestMapCenter.latitude), closeTo(100.0 * expectedPixelsPerMetre, 5e-2));
    });

    test('cameraMetersToPixels scales with zoom (×4 from z13 to z15)', () {
      final double atZ13 = cameraMetersToPixels(fakeMapCamera())(50.0, atLatitude: kTestMapCenter.latitude);
      final double atZ15 = cameraMetersToPixels(fakeMapCamera(zoom: 15))(50.0, atLatitude: kTestMapCenter.latitude);
      expect(atZ15 / atZ13, closeTo(4.0, 1e-6));
    });
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

import 'dart:ui' show Offset, Path, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_clip_geometry.dart';

/// FOG-06 — `buildFogClipPath` pure geometry (no flutter_map): viewport rect
/// minus one projected oval per disc, radius through the injected metric
/// converter (BUG-011), optional `canvasOffset` pre-shift kept for the tests.
void main() {
  const Size viewport = Size(200, 100);
  const Offset centre = Offset(100, 50);
  const double holeRadiusPx = 10.0;

  final RevealDisc disc = RevealDisc(id: 'rvd_a', sessionId: 's', lat: 48.5397, lon: 2.6553, radiusMeters: holeRadiusPx, fixedAtUtc: DateTime.utc(2026, 5));

  /// Projects every point to the viewport centre.
  Offset projectToCentre(GeoPoint point) => centre;

  /// 1 px per metre so `radiusMeters` == radius in px.
  double onePixelPerMetre(double meters, {required double atLatitude}) => meters;

  group('buildFogClipPath (FOG-06)', () {
    test('empty discs → the viewport rect, every interior point inside', () {
      final Path path = buildFogClipPath(size: viewport, discs: const <RevealDisc>[], projectToScreen: projectToCentre, metersToPixels: onePixelPerMetre);
      expect(path.getBounds(), equals(const Rect.fromLTWH(0, 0, 200, 100)));
      expect(path.contains(centre), isTrue);
      expect(path.contains(const Offset(5, 5)), isTrue);
    });

    test('one disc projected at the centre with a 10 px radius carves a circular hole', () {
      final Path path = buildFogClipPath(size: viewport, discs: <RevealDisc>[disc], projectToScreen: projectToCentre, metersToPixels: onePixelPerMetre);
      expect(path.getBounds(), equals(const Rect.fromLTWH(0, 0, 200, 100)), reason: 'the hole is INSIDE the rect; bounds are the viewport');
      expect(path.contains(centre), isFalse, reason: 'inside the disc → outside the path → fog NOT drawn');
      expect(path.contains(const Offset(5, 5)), isTrue, reason: 'outside the disc → inside the path → fog drawn');
      expect(path.contains(centre + const Offset(holeRadiusPx - 0.5, 0)), isFalse);
      expect(path.contains(centre + const Offset(holeRadiusPx + 0.5, 0)), isTrue);
      expect(path.contains(centre + const Offset(0, holeRadiusPx - 0.5)), isFalse);
      expect(path.contains(centre + const Offset(0, holeRadiusPx + 0.5)), isTrue);
    });

    test('the projector receives the disc centre and the converter receives (radiusMeters, atLatitude: disc.lat)', () {
      final List<GeoPoint> projected = <GeoPoint>[];
      final List<(double, double)> converted = <(double, double)>[];
      buildFogClipPath(
        size: viewport,
        discs: <RevealDisc>[disc],
        projectToScreen: (GeoPoint point) {
          projected.add(point);
          return centre;
        },
        metersToPixels: (double meters, {required double atLatitude}) {
          converted.add((meters, atLatitude));
          return meters;
        },
      );
      expect(projected, equals(<GeoPoint>[(latitude: 48.5397, longitude: 2.6553)]));
      expect(converted, equals(<(double, double)>[(holeRadiusPx, 48.5397)]), reason: 'metric radius at the disc latitude (BUG-011)');
    });

    test('two discs carve two holes', () {
      final RevealDisc second = RevealDisc(id: 'rvd_b', sessionId: 's', lat: 48.6, lon: 2.7, radiusMeters: 5.0, fixedAtUtc: DateTime.utc(2026, 5));
      const Offset secondCentre = Offset(30, 30);
      final Path path = buildFogClipPath(
        size: viewport,
        discs: <RevealDisc>[disc, second],
        projectToScreen: (GeoPoint point) => point.latitude == disc.lat ? centre : secondCentre,
        metersToPixels: onePixelPerMetre,
      );
      expect(path.contains(centre), isFalse);
      expect(path.contains(secondCentre), isFalse);
      expect(path.contains(const Offset(60, 60)), isTrue);
    });

    test('canvasOffset (3, 4) shifts the rect AND the hole by (-3, -4)', () {
      const Offset canvasOffset = Offset(3, 4);
      final Path path = buildFogClipPath(
        size: viewport,
        discs: <RevealDisc>[disc],
        projectToScreen: projectToCentre,
        metersToPixels: onePixelPerMetre,
        canvasOffset: canvasOffset,
      );
      final Rect bounds = path.getBounds();
      expect(bounds.left, closeTo(-3, 1e-6));
      expect(bounds.top, closeTo(-4, 1e-6));
      expect(bounds.width, closeTo(200, 1e-6));
      expect(bounds.height, closeTo(100, 1e-6));
      const Offset shiftedCentre = Offset(97, 46);
      expect(path.contains(shiftedCentre), isFalse);
      expect(path.contains(shiftedCentre + const Offset(holeRadiusPx - 0.5, 0)), isFalse);
      expect(path.contains(shiftedCentre + const Offset(holeRadiusPx + 0.5, 0)), isTrue);
    });
  });
}

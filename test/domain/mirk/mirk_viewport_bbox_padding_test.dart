// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-07 — `padMirkViewportBbox`, the disc-query padding of the
// `FogLayerConnector` (RESEARCH §7: discs at the edge of the viewport must already be
// loaded when a pan brings them into view, between two throttled bbox refreshes).
// Plain Dart on purpose: the suite runs under `flutter test` AND the CI plain-Dart
// domain step (`dart test test/domain/...`).

import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:test/test.dart';

const double _epsilon = 1e-9;

/// Web Mercator latitude limit (OSM slippy-map convention, `TileMath.maxLatMercator`).
const double _mercatorLatLimitDeg = 85.0511;

MirkViewportBbox _paris() => MirkViewportBbox(south: 48.80, west: 2.30, north: 48.90, east: 2.40);

void main() {
  group('padMirkViewportBbox', () {
    test('widens a Paris bbox by factor × (height, width) on every side', () {
      final MirkViewportBbox padded = padMirkViewportBbox(_paris(), 0.5);
      expect(padded.south, closeTo(48.75, _epsilon));
      expect(padded.north, closeTo(48.95, _epsilon));
      expect(padded.west, closeTo(2.25, _epsilon));
      expect(padded.east, closeTo(2.45, _epsilon));
    });

    test('factor 0 is the identity', () {
      expect(padMirkViewportBbox(_paris(), 0.0), equals(_paris()));
    });

    test('north is clamped to the Web Mercator limit near the north pole', () {
      final MirkViewportBbox padded = padMirkViewportBbox(MirkViewportBbox(south: 84.9, west: 10.0, north: 85.0, east: 10.2), 1.0);
      expect(padded.north, closeTo(_mercatorLatLimitDeg, 1e-3));
      expect(padded.south, closeTo(84.8, _epsilon));
      expect(padded.south, lessThanOrEqualTo(padded.north));
    });

    test('south is clamped to the Web Mercator limit near the south pole', () {
      final MirkViewportBbox padded = padMirkViewportBbox(MirkViewportBbox(south: -85.0, west: 10.0, north: -84.9, east: 10.2), 1.0);
      expect(padded.south, closeTo(-_mercatorLatLimitDeg, 1e-3));
      expect(padded.north, closeTo(-84.8, _epsilon));
    });

    test('a bbox already crossing the antimeridian (west 179.9, east -179.9) pads without an AssertionError', () {
      final MirkViewportBbox padded = padMirkViewportBbox(MirkViewportBbox(south: 10.0, west: 179.9, north: 10.2, east: -179.9), 0.5);
      // Span is 0.2° across the seam, so the padding is 0.1° on each side.
      expect(padded.west, closeTo(179.8, _epsilon));
      expect(padded.east, closeTo(-179.8, _epsilon));
      expect(padded.south, closeTo(9.9, _epsilon));
      expect(padded.north, closeTo(10.3, _epsilon));
    });

    test('padding that crosses +180° wraps east into the negative range', () {
      final MirkViewportBbox padded = padMirkViewportBbox(MirkViewportBbox(south: 10.0, west: 179.5, north: 10.2, east: 179.9), 0.5);
      expect(padded.west, closeTo(179.3, _epsilon));
      expect(padded.east, closeTo(-179.9, _epsilon));
    });

    test('padding that crosses -180° wraps west into the positive range', () {
      final MirkViewportBbox padded = padMirkViewportBbox(MirkViewportBbox(south: 10.0, west: -179.9, north: 10.2, east: -179.5), 0.5);
      expect(padded.west, closeTo(179.9, _epsilon));
      expect(padded.east, closeTo(-179.3, _epsilon));
    });

    test('a padded span of 360° or more degrades to the full longitude range', () {
      final MirkViewportBbox padded = padMirkViewportBbox(MirkViewportBbox(south: -10.0, west: -100.0, north: 10.0, east: 100.0), 0.5);
      expect(padded.west, equals(-180.0));
      expect(padded.east, equals(180.0));
      expect(padded.south, closeTo(-20.0, _epsilon));
      expect(padded.north, closeTo(20.0, _epsilon));
    });

    test('a wrapped pair the bbox convention cannot express degrades to the full longitude range', () {
      // A world-overview viewport (140° wide, zoom 2 on a phone) hugging the antimeridian:
      // west' wraps to +110.1°, east' = +30.1° — both positive with west > east, which the
      // `MirkViewportBbox` assertion rejects. Over-fetching the whole ring is harmless; an
      // AssertionError on a frame is not.
      final MirkViewportBbox padded = padMirkViewportBbox(MirkViewportBbox(south: -10.0, west: -179.9, north: 10.0, east: -39.9), 0.5);
      expect(padded.west, equals(-180.0));
      expect(padded.east, equals(180.0));
    });
  });
}

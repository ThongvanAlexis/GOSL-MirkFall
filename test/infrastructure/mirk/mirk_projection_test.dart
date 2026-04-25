// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 1 RED test suite for `MirkProjection`.
//
// Drives the lat/lon → screen-pixel projection helper consumed by all
// 4 concrete renderers (atmospheric / solid / candlelight / heavenly).
// Linear-Mercator within the viewport bbox — sufficient for the fog
// overlay because the underlying MapLibre canvas does its own
// web-mercator projection at the platform layer.
//
// Pure-Dart suite — uses `package:test` (not `flutter_test`); the
// projection helper has no Flutter widget dependency, only `dart:ui`
// `Offset` + `Size` which are part of the SDK.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/infrastructure/mirk/mirk_projection.dart';

void main() {
  group('09-04 — MirkProjection.latLonToScreen', () {
    final bbox = MirkViewportBbox(
      south: 43.0,
      west: 5.0,
      north: 44.0,
      east: 6.0,
    );
    const size = Size(400, 800);

    test('NW corner (lat=north, lon=west) maps to (0, 0)', () {
      final off = MirkProjection.latLonToScreen(
        lat: 44.0,
        lon: 5.0,
        viewport: bbox,
        size: size,
      );
      expect(off.dx, closeTo(0.0, 1e-9));
      expect(off.dy, closeTo(0.0, 1e-9));
    });

    test(
      'SE corner (lat=south, lon=east) maps to (size.width, size.height)',
      () {
        final off = MirkProjection.latLonToScreen(
          lat: 43.0,
          lon: 6.0,
          viewport: bbox,
          size: size,
        );
        expect(off.dx, closeTo(400.0, 1e-9));
        expect(off.dy, closeTo(800.0, 1e-9));
      },
    );

    test('NE corner (lat=north, lon=east) maps to (size.width, 0)', () {
      final off = MirkProjection.latLonToScreen(
        lat: 44.0,
        lon: 6.0,
        viewport: bbox,
        size: size,
      );
      expect(off.dx, closeTo(400.0, 1e-9));
      expect(off.dy, closeTo(0.0, 1e-9));
    });

    test('SW corner (lat=south, lon=west) maps to (0, size.height)', () {
      final off = MirkProjection.latLonToScreen(
        lat: 43.0,
        lon: 5.0,
        viewport: bbox,
        size: size,
      );
      expect(off.dx, closeTo(0.0, 1e-9));
      expect(off.dy, closeTo(800.0, 1e-9));
    });

    test('centre (lat=43.5, lon=5.5) maps to (width/2, height/2)', () {
      final off = MirkProjection.latLonToScreen(
        lat: 43.5,
        lon: 5.5,
        viewport: bbox,
        size: size,
      );
      expect(off.dx, closeTo(200.0, 1e-9));
      expect(off.dy, closeTo(400.0, 1e-9));
    });

    test('outside-viewport coordinates return finite Offset (no clamping)', () {
      // lat=42 is one full bbox-height SOUTH of bbox.south=43, so y must
      // map to height + 1*height = 1600. lon=4 is one full bbox-width
      // WEST of bbox.west=5, so x must map to -width = -400.
      final off = MirkProjection.latLonToScreen(
        lat: 42.0,
        lon: 4.0,
        viewport: bbox,
        size: size,
      );
      expect(off.dx, closeTo(-400.0, 1e-9));
      expect(off.dy, closeTo(1600.0, 1e-9));
      expect(off.dx.isFinite, isTrue);
      expect(off.dy.isFinite, isTrue);
    });

    test('zero-span bbox (north == south) returns Offset.zero (defensive)', () {
      final zeroLatSpan = MirkViewportBbox(
        south: 44.0,
        west: 5.0,
        north: 44.0,
        east: 6.0,
      );
      final off = MirkProjection.latLonToScreen(
        lat: 44.0,
        lon: 5.5,
        viewport: zeroLatSpan,
        size: size,
      );
      expect(off, equals(Offset.zero));
    });

    test('zero-span bbox (east == west) returns Offset.zero (defensive)', () {
      final zeroLonSpan = MirkViewportBbox(
        south: 43.0,
        west: 5.0,
        north: 44.0,
        east: 5.0,
      );
      final off = MirkProjection.latLonToScreen(
        lat: 43.5,
        lon: 5.0,
        viewport: zeroLonSpan,
        size: size,
      );
      expect(off, equals(Offset.zero));
    });
  });
}

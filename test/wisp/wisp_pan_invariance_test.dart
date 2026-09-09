// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-05 — wisp pan invariance (POC Success Criterion #1, WISP-01).
//
// A wisp's WORLD position must be invariant under a camera pan; only its PROJECTION moves, by
// the pixel delta of the pan. If the pre-09.1 screen-pixel `Offset position` ever crept back, a
// 100 m pan would leave the wisp glued to the screen instead of to the map (BUG-014 lineage).
//
// The POC exercised two real `MapCamera`s; MirkFall keeps flutter_map behind the adapter
// perimeter (MAP-06), so the two "cameras" are two `MirkPaintContext.projectToScreen` closures
// built over viewports shifted by the pan — the only projection API a renderer may use.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle.dart';

import '../_helpers/mirk_paint_context_builder.dart';

const GeoPoint _wispPoint = (latitude: 48.8566, longitude: 2.3522);
const double _lonSpanDegrees = 0.02;
const double _latSpanDegrees = 0.02;

MirkPaintContext _contextCentredOn({required double centreLat, required double centreLon}) => buildTestMirkPaintContext(
  viewportBbox: MirkViewportBbox(
    south: centreLat - _latSpanDegrees / 2,
    west: centreLon - _lonSpanDegrees / 2,
    north: centreLat + _latSpanDegrees / 2,
    east: centreLon + _lonSpanDegrees / 2,
  ),
);

void main() {
  group('09.1-05 — wisp pan invariance (SC #1 / WISP-01)', () {
    test('a 100 m eastward camera pan does NOT change wisp.position; its projection moves west by the pan\'s pixel delta', () {
      final WispParticle wisp = WispParticle(position: _wispPoint, velocityMetersPerSecond: Offset.zero, life: 2.5, maxLife: 2.5);
      final GeoPoint before = wisp.position;

      // 100 m east at 48.86° lat → Δlon = 100 / (kMetersPerDegreeLat · cos lat).
      const double panMeters = 100.0;
      final double panDegLon = panMeters / (kMetersPerDegreeLat * math.cos(_wispPoint.latitude * math.pi / 180.0));
      final MirkPaintContext cameraBefore = _contextCentredOn(centreLat: _wispPoint.latitude, centreLon: _wispPoint.longitude);
      final MirkPaintContext cameraAfter = _contextCentredOn(centreLat: _wispPoint.latitude, centreLon: _wispPoint.longitude + panDegLon);

      final Offset screenBefore = cameraBefore.projectToScreen(wisp.position);
      final Offset screenAfter = cameraAfter.projectToScreen(wisp.position);

      // Invariant A — the world position is untouched by any camera.
      expect(wisp.position.latitude, before.latitude);
      expect(wisp.position.longitude, before.longitude);
      expect(wisp.position, _wispPoint);

      // Invariant B — the projection moved by exactly the pan's pixel delta (linear projection:
      // Δx = −Δlon / lonSpan · canvasWidth), i.e. west on screen for an eastward camera pan.
      final double expectedDx = -panDegLon / _lonSpanDegrees * kTestPaintContextCanvasSize.width;
      expect(screenAfter.dx - screenBefore.dx, closeTo(expectedDx, 1e-6));
      expect(screenAfter.dx - screenBefore.dx, lessThan(-1.0), reason: 'measurable (> 1 px) and westward');
      expect(screenAfter.dy - screenBefore.dy, closeTo(0.0, 1e-9), reason: 'a pure eastward pan does not move the projection vertically');
      expect(screenBefore, kTestPaintContextCanvasSize.center(Offset.zero), reason: 'sanity: the wisp sits at the centre of the un-panned camera');
    });
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_pan_translation_test.dart — invariant FOG-09 (pan tracking, FOG-18 raw forward)

import 'dart:math' show Point;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';

import '../../_helpers/fake_map_camera.dart';
import '../../_helpers/fog_layer_test_harness.dart';

/// FOG-09 — after a programmatic `MapController.move(...)`, the context the
/// renderer receives carries a `pixelOrigin` that moved by the camera's
/// world-pixel delta, and `projectToScreen(fixedPoint)` moved by the SAME delta
/// with the opposite sign (screen = project(P) - pixelOrigin at rotation 0).
///
/// Keystone behavioural transform-equality test: widget-tree containment under
/// `MobileLayerTransformer` (`fog_layer_test`) is necessary but NOT sufficient;
/// this asserts the consequence the user sees. Pre-fix POC HEAD forwarded a
/// constant `(0, 0)` and tripped it. The value is the RAW `camera.pixelOrigin`
/// (FOG-18): zoom-13 magnitude ~1e6, ~411 px delta on X for this trajectory.
void main() {
  /// ~1.5 km NE of Melun town centre — ~86 px X / ~91 px Y of world-pixel delta at zoom 13
  /// (the POC comment's "~411 / ~205" overstated it; the assertions below use the live camera).
  const LatLng pannedCenter = LatLng(48.5500, 2.6700);
  const GeoPoint fixedPoint = (latitude: 48.5397, longitude: 2.6553);

  /// Sanity floor on the world-pixel delta of the trajectory (actual ≈ 86 / 91 px).
  const double kMinPanDeltaPx = 50.0;

  group('FOG-09 (03.1-02 keystone)', () {
    testWidgets('pixelOrigin and projectToScreen track the camera pan by the same world-pixel delta (opposite signs)', (tester) async {
      final mapController = MapController();
      addTearDown(mapController.dispose);
      final renderer = SpyMirkRenderer();
      await pumpFogLayerInFlutterMap(tester, renderer: renderer, mapController: mapController);

      final initialPainter = findFogPainter(tester);
      initialPainter.paint(IdentityCanvasFake(), kTestFogViewportSize);
      final MirkPaintContext initialContext = renderer.lastContext;
      final Point<double> initialCameraOrigin = mapController.camera.pixelOrigin;
      final Offset initialProjection = initialContext.projectToScreen(fixedPoint);

      mapController.move(pannedCenter, kTestMapZoom);
      await tester.pump();
      await tester.pump();

      // The painter is rebuilt on every camera change — re-find it so the
      // post-pan camera snapshot is the one painting (FOG-07).
      final pannedPainter = findFogPainter(tester);
      expect(identical(pannedPainter, initialPainter), isFalse, reason: 'a new camera snapshot → a new painter');
      pannedPainter.paint(IdentityCanvasFake(), kTestFogViewportSize);
      final MirkPaintContext pannedContext = renderer.lastContext;
      final Point<double> pannedCameraOrigin = mapController.camera.pixelOrigin;
      final Offset pannedProjection = pannedContext.projectToScreen(fixedPoint);

      final double expectedDx = pannedCameraOrigin.x - initialCameraOrigin.x;
      final double expectedDy = pannedCameraOrigin.y - initialCameraOrigin.y;
      expect(expectedDx.abs(), greaterThan(kMinPanDeltaPx), reason: 'the trajectory moves the camera by tens of world pixels at z13');
      expect(expectedDy.abs(), greaterThan(kMinPanDeltaPx));

      // pixelOrigin forwarded RAW (FOG-18), so its delta IS the camera delta.
      expect(
        (pannedContext.pixelOrigin.x - initialContext.pixelOrigin.x).abs(),
        greaterThan(kTestCanvasTransformEpsilon),
        reason: 'POC regression: uPixelOrigin.x did not change after a programmatic pan',
      );
      expect((pannedContext.pixelOrigin.y - initialContext.pixelOrigin.y).abs(), greaterThan(kTestCanvasTransformEpsilon));
      expect(pannedContext.pixelOrigin.x - initialContext.pixelOrigin.x, closeTo(expectedDx, kTestCanvasTransformEpsilon));
      expect(pannedContext.pixelOrigin.y - initialContext.pixelOrigin.y, closeTo(expectedDy, kTestCanvasTransformEpsilon));
      expect(initialContext.pixelOrigin.x, greaterThan(1e6), reason: 'raw world-pixel magnitude at z13 (no modulo, no normalised UV)');

      // A fixed geographic point moves on screen by -delta (screen = project(P) - pixelOrigin).
      expect(pannedProjection.dx - initialProjection.dx, closeTo(-expectedDx, kTestCanvasTransformEpsilon));
      expect(pannedProjection.dy - initialProjection.dy, closeTo(-expectedDy, kTestCanvasTransformEpsilon));

      // The camera-derived fields of the context travel together (one snapshot).
      expect(initialContext.zoomLevel, equals(kTestMapZoom));
      expect(pannedContext.zoomLevel, equals(kTestMapZoom));
      expect(pannedContext.viewportBbox, isNot(equals(initialContext.viewportBbox)), reason: 'visibleBounds moved with the camera');
      expect(pannedContext.canvasOffset, equals((dx: 0.0, dy: 0.0)), reason: 'identity canvas in this test');
    });
  });
}

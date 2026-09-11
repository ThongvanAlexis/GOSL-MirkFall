// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 UAT follow-up — pixel-level proof that the fog reveal hole and the blue puck share
// one projection through the REAL layer tree MirkFall composes (not through a canvas fake):
//
//   * flutter_map's `CirclePainter` projects the puck with `camera.getOffsetFromOrigin(p)`
//     (= `project(p) − pixelOrigin`, flutter_map 7.0.2 circle_layer/painter.dart:53);
//   * the fog clip hole is projected with `camera.latLngToScreenPoint(p)` through
//     `cameraScreenProjector` (fog_clip_path.dart) — algebraically the same at rotation 0
//     (`size == nonRotatedSize`, camera.dart:77 vs :263).
//
// Both are asserted numerically at a FRACTIONAL zoom and off-centre points, then rasterised at
// DPR 3.5 with the `FadeTransition` wrapper `MirkInitialRevealFade` puts around the fog (at 0.6 —
// while the fade is a repaint boundary — and at 1.0), before and after a pan that moves the puck
// off the screen centre. The hole must be centred on the puck to the pixel, with fog outside it.

import 'dart:math' show Point;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/config/constants.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';
import 'package:mirkfall/infrastructure/mirk/frame_delta_probe.dart';
import 'package:mirkfall/presentation/widgets/fog_clip_path.dart';
import 'package:mirkfall/presentation/widgets/fog_layer.dart';

import '../../_helpers/fake_map_camera.dart';

/// The UAT session's fix (Melun) at a FRACTIONAL zoom — the pixel-origin arithmetic is exercised
/// with a non-integer scale, the way a pinch leaves the camera.
const LatLng kPuckLatLng = LatLng(48.528644, 2.655185);
const double kFractionalZoom = 16.37;
const double kDevicePixelRatio = 3.5;
const Size kLogicalViewport = Size(400, 800);
const double kDiscRadiusMeters = 25.0;

/// Pan that moves the puck off the screen centre by a non-round vector.
const Offset kPanLogicalPx = Offset(95.0, -60.0);

/// Radius of the row / column scan around the puck, in logical px — well past the ~20 px hole.
const double kScanRadiusLogicalPx = 60.0;

/// Scan starts outside the puck disc + white border so the puck's own pixels are never mistaken
/// for the fog edge.
const double kPuckOuterRadiusLogicalPx = kMapUserPuckRadiusPx + kMapUserPuckBorderWidthPx + 2.0;

/// Tolerance on the left-vs-right / top-vs-bottom hole-edge distances, in PHYSICAL px: the edge
/// is anti-aliased over one physical pixel on each side.
const int kEdgeSymmetryTolerancePhysicalPx = 2;

/// Tolerance on the projector identity (`getOffsetFromOrigin` vs `latLngToScreenPoint`), in
/// logical px — pure floating-point noise.
const double kProjectionEpsilonPx = 1e-9;

const Color kBackground = Color(0xFFFFFFFF);
const Color kFog = Color(0xFF000000);

/// Renderer that fills the clipped identity frame with an opaque colour — the FogLayer's clip
/// is what cuts the hole, which is exactly what this test measures.
class _SolidFogRenderer implements MirkRenderer {
  const _SolidFogRenderer();

  @override
  void paint(Canvas canvas, Size size, MirkPaintContext context) => canvas.drawRect(Offset.zero & size, Paint()..color = kFog);

  @override
  void update(Duration elapsed) {}

  @override
  Future<void> dispose() async {}
}

/// Mounts the MirkFall map composition around a solid-fog `FogLayer` under a `FadeTransition`
/// at [fadeOpacity] and the puck `CircleLayer`, inside a `RepaintBoundary` that the test
/// rasterises. Same child order as `FlutterMapMapViewWidget` (tiles omitted: white background).
Future<GlobalKey> _pumpComposition(WidgetTester tester, {required MapController mapController, required double fadeOpacity}) async {
  tester.view.physicalSize = kLogicalViewport * kDevicePixelRatio;
  tester.view.devicePixelRatio = kDevicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final probe = FrameDeltaProbe();
  addTearDown(() async => probe.dispose());
  final fogTransformLogger = FogTransformLogger();
  addTearDown(fogTransformLogger.stop);
  final boundaryKey = GlobalKey();
  final RevealDisc disc = RevealDisc(
    id: 'rvd_puck',
    sessionId: 'sess_test',
    lat: kPuckLatLng.latitude,
    lon: kPuckLatLng.longitude,
    radiusMeters: kDiscRadiusMeters,
    fixedAtUtc: DateTime.utc(2026, 9, 11),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: kLogicalViewport.width,
            height: kLogicalViewport.height,
            child: FlutterMap(
              mapController: mapController,
              options: const MapOptions(
                initialCenter: kPuckLatLng,
                initialZoom: kFractionalZoom,
                backgroundColor: kBackground,
                interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: <Widget>[
                FadeTransition(
                  opacity: AlwaysStoppedAnimation<double>(fadeOpacity),
                  child: FogLayer(
                    renderer: const _SolidFogRenderer(),
                    discs: <RevealDisc>[disc],
                    frameDeltaProbe: probe,
                    fogTransformLogger: fogTransformLogger,
                    isAndroid: true,
                  ),
                ),
                const CircleLayer<Object>(
                  circles: <CircleMarker<Object>>[
                    CircleMarker<Object>(
                      point: kPuckLatLng,
                      radius: kMapUserPuckRadiusPx,
                      color: Color(kMapUserPuckColorArgb),
                      borderStrokeWidth: kMapUserPuckBorderWidthPx,
                      borderColor: Color(kMapUserPuckBorderColorArgb),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return boundaryKey;
}

/// Rasterises the boundary at the device pixel ratio (real event loop: `toImage` needs it).
Future<({ByteData rgba, int width})> _rasterise(WidgetTester tester, GlobalKey boundaryKey) async {
  late final ByteData rgba;
  late final int width;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary = tester.renderObject(find.byKey(boundaryKey));
    final ui.Image image = await boundary.toImage(pixelRatio: kDevicePixelRatio);
    final ByteData? bytes = await image.toByteData();
    if (bytes == null) fail('toByteData returned null');
    rgba = bytes;
    width = image.width;
    image.dispose();
  });
  return (rgba: rgba, width: width);
}

bool _isBackground(ByteData rgba, int width, int x, int y) {
  final int index = (y * width + x) * 4;
  return rgba.getUint8(index) == 0xFF && rgba.getUint8(index + 1) == 0xFF && rgba.getUint8(index + 2) == 0xFF;
}

/// Distance in physical px from [centrePhysical] to the first non-background pixel along
/// ([dx], [dy]), starting just outside the puck. Fails if no fog edge is met within the scan.
int _distanceToFogEdge(ByteData rgba, int width, Point<int> centrePhysical, {required int dx, required int dy}) {
  final int start = (kPuckOuterRadiusLogicalPx * kDevicePixelRatio).round();
  final int end = (kScanRadiusLogicalPx * kDevicePixelRatio).round();
  for (int step = start; step <= end; step++) {
    if (!_isBackground(rgba, width, centrePhysical.x + dx * step, centrePhysical.y + dy * step)) return step;
  }
  fail('no fog edge within $end physical px along ($dx, $dy) — the hole is not around the puck');
}

/// Asserts the reveal hole is centred on the puck's LIVE projection: the fog edge sits at the
/// same distance left / right and top / bottom (±[kEdgeSymmetryTolerancePhysicalPx]) and the
/// puck centre itself shows the map, not fog.
Future<void> _expectHoleCentredOnPuck(WidgetTester tester, GlobalKey boundaryKey, MapController mapController, {required String scenario}) async {
  final MapCamera camera = mapController.camera;
  final Offset puckLogical = camera.getOffsetFromOrigin(kPuckLatLng);
  final ({ByteData rgba, int width}) raster = await _rasterise(tester, boundaryKey);
  final Point<int> centre = Point<int>((puckLogical.dx * kDevicePixelRatio).round(), (puckLogical.dy * kDevicePixelRatio).round());

  final int left = _distanceToFogEdge(raster.rgba, raster.width, centre, dx: -1, dy: 0);
  final int right = _distanceToFogEdge(raster.rgba, raster.width, centre, dx: 1, dy: 0);
  final int up = _distanceToFogEdge(raster.rgba, raster.width, centre, dx: 0, dy: -1);
  final int down = _distanceToFogEdge(raster.rgba, raster.width, centre, dx: 0, dy: 1);
  expect(
    (left - right).abs(),
    lessThanOrEqualTo(kEdgeSymmetryTolerancePhysicalPx),
    reason: '$scenario: hole off-centre horizontally (left=$left right=$right)',
  );
  expect((up - down).abs(), lessThanOrEqualTo(kEdgeSymmetryTolerancePhysicalPx), reason: '$scenario: hole off-centre vertically (up=$up down=$down)');

  final double expectedRadiusPhysical = cameraMetersToPixels(camera)(kDiscRadiusMeters, atLatitude: kPuckLatLng.latitude) * kDevicePixelRatio;
  for (final int edge in <int>[left, right, up, down]) {
    expect(
      (edge - expectedRadiusPhysical).abs(),
      lessThanOrEqualTo(kEdgeSymmetryTolerancePhysicalPx),
      reason: '$scenario: hole radius $edge vs metric $expectedRadiusPhysical',
    );
  }
}

void main() {
  test('CirclePainter projection (getOffsetFromOrigin) == fog clip projection (latLngToScreenPoint) at fractional zoom, off-centre', () {
    final MapCamera camera = fakeMapCamera(center: kPuckLatLng, zoom: kFractionalZoom);
    final ScreenProjector fogProjector = cameraScreenProjector(camera);
    const List<GeoPoint> samples = <GeoPoint>[
      (latitude: 48.528644, longitude: 2.655185),
      (latitude: 48.5301, longitude: 2.6570),
      (latitude: 48.5270, longitude: 2.6530),
      (latitude: 48.5320, longitude: 2.6600),
    ];
    for (final GeoPoint sample in samples) {
      final Offset puck = camera.getOffsetFromOrigin(LatLng(sample.latitude, sample.longitude));
      final Offset hole = fogProjector(sample);
      expect((puck - hole).distance, lessThan(kProjectionEpsilonPx), reason: 'puck $puck vs hole $hole for $sample');
    }
  });

  for (final double fadeOpacity in <double>[1.0, 0.6]) {
    testWidgets('rasterised at DPR 3.5 under FadeTransition($fadeOpacity): the reveal hole is centred on the puck, before and after a pan', (tester) async {
      final mapController = MapController();
      addTearDown(mapController.dispose);
      final GlobalKey boundaryKey = await _pumpComposition(tester, mapController: mapController, fadeOpacity: fadeOpacity);
      await _expectHoleCentredOnPuck(tester, boundaryKey, mapController, scenario: 'fade $fadeOpacity, puck at centre');

      final MapCamera before = mapController.camera;
      final Point<double> screenCentre = before.size / 2;
      final LatLng pannedCenter = before.pointToLatLng(Point<double>(screenCentre.x + kPanLogicalPx.dx, screenCentre.y + kPanLogicalPx.dy));
      mapController.move(pannedCenter, kFractionalZoom);
      await tester.pump();
      await _expectHoleCentredOnPuck(tester, boundaryKey, mapController, scenario: 'fade $fadeOpacity, puck panned by $kPanLogicalPx');
    });
  }
}

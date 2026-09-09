// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_zoom_invariant_basis_test.dart — invariant FOG-19

import 'dart:io' show File;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_helpers/atmospheric_fog_layer_harness.dart';
import '../../_helpers/fake_map_camera.dart';

/// FOG-19 — `uZoomScale = pow(2, camera.zoom - kMirkFogReferenceZoom)` is
/// forwarded to the seam so the noise cells stay anchored to lat/lng during
/// zoom transitions (Walk #5 "numbers sliding / incorrect scaling").
///
/// Visual-identity preservation: at `camera.zoom == kMirkFogReferenceZoom`
/// (13.0) the scale is 1.0 and the shader sampling is bit-identical to the
/// validated pre-FOG-19 build.
void main() {
  group('FOG-19 — uZoomScale forwarded by the painter', () {
    test('STATIC source: fog_layer.dart imports dart:math, references kMirkFogReferenceZoom and forwards zoomScale', () {
      final source = File('lib/presentation/widgets/fog_layer.dart').readAsStringSync();
      expect(source, contains("import 'dart:math'"), reason: 'math.pow(2, ...)');
      expect(source, contains('kMirkFogReferenceZoom'));
      expect(source, contains('math.pow('));
      expect(source, contains('zoomScale: zoomScale'), reason: 'forwarded through the MirkPaintContext');
    });

    testWidgets('BEHAVIOURAL: 1.0 at the reference zoom, 4.0 after move(center, 15), 0.5 after move(center, 12)', (tester) async {
      final mapController = MapController();
      addTearDown(mapController.dispose);
      final harness = await pumpAtmosphericFogLayer(tester, mapController: mapController);
      expect(harness.recorder.renders.last.zoomScale, closeTo(1.0, 1e-9), reason: 'reference zoom → bit-identical sampling');

      mapController.move(kTestMapCenter, 15);
      var alreadyRecorded = harness.recorder.renders.length;
      await pumpUntilShaderRendered(tester, harness.recorder, alreadyRecorded: alreadyRecorded);
      expect(harness.recorder.renders.last.zoomScale, closeTo(4.0, 1e-9), reason: 'two levels above the reference → pow(2, 2)');

      mapController.move(kTestMapCenter, 12);
      alreadyRecorded = harness.recorder.renders.length;
      await pumpUntilShaderRendered(tester, harness.recorder, alreadyRecorded: alreadyRecorded);
      expect(harness.recorder.renders.last.zoomScale, closeTo(0.5, 1e-9), reason: 'one level below the reference → pow(2, -1)');
      await harness.renderer.dispose();
    });
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_smooth_noise_test.dart — invariant FOG-11

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/config/constants.dart';

import '../../_helpers/atmospheric_fog_layer_harness.dart';
import '../../_helpers/fake_map_camera.dart';

/// FOG-11 — the `pixelOrigin` reaching the shader seam evolves SMOOTHLY across
/// a sequence of small programmatic `MapController.move(...)` calls.
///
/// Catches the shader-modulo-wrap failure mode (03.1-FALSIFICATION obs. 2,
/// "the seed of the mirk was changing"): a Dart-side `% period` produces
/// `kMirkFogNoiseTilePx`-magnitude jumps at the wrap frame, a raw forward
/// produces single-digit raw-pixel deltas for these gentle pans (~3 px each at
/// zoom 13). `kMirkFogDiagSmoothCoordinateMaxDelta` (2000 px) leaves three
/// orders of magnitude of headroom while still catching a re-introduced wrap.
///
/// Higher-fidelity gate than FOG-09 (binary "moved at all?"): CONTINUOUS evolution.
void main() {
  const int stepCount = 10;
  const double stepDegrees = 0.0001;

  group('FOG-11 (03.1-04 keystone)', () {
    testWidgets('pixelOrigin evolves smoothly across small consecutive pans (no modulo-wrap discontinuity)', (tester) async {
      final mapController = MapController();
      addTearDown(mapController.dispose);
      final harness = await pumpAtmosphericFogLayer(tester, mapController: mapController);

      final captured = <({double x, double y})>[];
      for (var i = 0; i < stepCount; i++) {
        mapController.move(LatLng(kTestMapCenter.latitude + i * stepDegrees, kTestMapCenter.longitude + i * stepDegrees), kTestMapZoom);
        final int alreadyRecorded = harness.recorder.renders.length;
        await pumpUntilShaderRendered(tester, harness.recorder, alreadyRecorded: alreadyRecorded);
        captured.add(harness.recorder.renders.last.pixelOrigin);
      }

      for (var i = 1; i < captured.length; i++) {
        final dx = (captured[i].x - captured[i - 1].x).abs();
        final dy = (captured[i].y - captured[i - 1].y).abs();
        expect(dx, lessThan(kMirkFogDiagSmoothCoordinateMaxDelta), reason: 'FOG-18 regression at step $i: pixelOrigin.x jumped by $dx');
        expect(dy, lessThan(kMirkFogDiagSmoothCoordinateMaxDelta), reason: 'FOG-18 regression at step $i: pixelOrigin.y jumped by $dy');
        expect(dx + dy, greaterThan(0.0), reason: 'each step moved the camera — the forwarded value must follow');
      }
      expect(captured.last.x, greaterThan(1e3), reason: 'raw world-pixel magnitude (~1.06 M at z13), not a normalised UV nor a bounded composite');
      await harness.renderer.dispose();
    });
  });
}

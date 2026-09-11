// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09.1 plan 09.1-04 — harness of the POC uniform / noise-anchoring widget
// tests (FOG-05/11/18/19): a `FogLayer` delegating to the production
// `AtmosphericMirkRenderer` whose GPU seam is a `RecordingFogShaderRenderer`.
// Kept apart from `fog_layer_test_harness.dart` so the painter-level tests do not
// depend on the shader renderer's compile state.

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';

import 'fake_map_camera.dart';
import 'fog_layer_test_harness.dart';
import 'recording_fog_shader_renderer.dart';

/// Upper bound on the real-time iterations spent waiting for the renderer's
/// SDF to resolve (the seam is only reached once the SDF exists).
const int kMaxSdfSettleFrames = 30;

/// Real delay per iteration (POC idiom): the SDF builder finishes through
/// `ui.decodeImageFromPixels`, which needs the real event loop — fake-time
/// `tester.pump(duration)` never completes it, so the wait runs under
/// `tester.runAsync`. 30 × 20 ms = 600 ms worst case.
const Duration kSdfSettleRealDelay = Duration(milliseconds: 20);

/// The renderer + recorder pair mounted by [pumpAtmosphericFogLayer].
typedef AtmosphericFogHarness = ({AtmosphericMirkRenderer renderer, RecordingFogShaderRenderer recorder});

/// Mounts a `FlutterMap` + `FogLayer` whose renderer is the production
/// `AtmosphericMirkRenderer` with a recording GPU seam, then waits (real event
/// loop, bounded) until the seam has recorded at least one render (SDF resolved).
///
/// The renderer owns timers and an in-flight SDF build (rebuild logger, cache): the test
/// body MUST end with `await harness.renderer.dispose()` — a teardown callback
/// runs after the widget-test pending-timer check and would be too late.
Future<AtmosphericFogHarness> pumpAtmosphericFogLayer(
  WidgetTester tester, {
  List<RevealDisc> discs = const <RevealDisc>[],
  MapController? mapController,
  LatLng initialCenter = kTestMapCenter,
  double initialZoom = kTestMapZoom,
}) async {
  final recorder = RecordingFogShaderRenderer();
  final renderer = AtmosphericMirkRenderer(const AtmosphericConfig(), shaderRenderer: recorder);
  await pumpFogLayerInFlutterMap(
    tester,
    renderer: renderer,
    discs: discs,
    mapController: mapController,
    initialCenter: initialCenter,
    initialZoom: initialZoom,
  );
  await pumpUntilShaderRendered(tester, recorder);
  return (renderer: renderer, recorder: recorder);
}

/// Lets the renderer's SDF future settle through the REAL event loop
/// (`tester.runAsync`, POC idiom) and pumps until [recorder] has more renders
/// than [alreadyRecorded]; the Ticker paints every frame, so the first frame
/// after the SDF resolves reaches the seam. Bounded by [kMaxSdfSettleFrames].
Future<void> pumpUntilShaderRendered(WidgetTester tester, RecordingFogShaderRenderer recorder, {int alreadyRecorded = 0}) async {
  await tester.runAsync(() async {
    for (var i = 0; i < kMaxSdfSettleFrames && recorder.renders.length <= alreadyRecorded; i++) {
      await Future<void>.delayed(kSdfSettleRealDelay);
      await tester.pump();
    }
  });
  await tester.pump();
  expect(
    recorder.renders.length,
    greaterThan(alreadyRecorded),
    reason: 'the shader seam was not reached within $kMaxSdfSettleFrames real-time iterations — SDF never resolved?',
  );
}

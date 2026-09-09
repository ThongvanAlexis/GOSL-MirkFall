// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_layer_test.dart — invariants FOG-04 (structure) + FOG-05 (uniform coverage through the seam)

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_platform_corrections.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_shader_renderer.dart';
import 'package:mirkfall/presentation/widgets/fog_layer.dart';

import '../../_helpers/atmospheric_fog_layer_harness.dart';
import '../../_helpers/fog_layer_test_harness.dart';

/// FOG-04 — `FogLayer.build()` returns `MobileLayerTransformer(child: CustomPaint(...))`
/// (flutter_map does NOT wrap its children; each layer wraps itself).
///
/// Structural containment is necessary but NOT sufficient (POC lesson, Plan
/// 03-08): the behavioural transform-equality contract lives in
/// `fog_pan_translation_test.dart` (FOG-09). Both run on every CI push.
///
/// FOG-05 — through `AtmosphericMirkRenderer` + `RecordingFogShaderRenderer`,
/// every paint forwards the 20 tunables, the platform-corrected `sdfRect`
/// (identity with `isAndroid: false`) and a LIVE `uTime`.
void main() {
  testWidgets('FogLayer is wrapped by MobileLayerTransformer when mounted inside FlutterMap (FOG-04)', (tester) async {
    await pumpFogLayerInFlutterMap(tester, renderer: SpyMirkRenderer());
    expect(
      find.descendant(of: find.byType(FogLayer), matching: find.byType(MobileLayerTransformer)),
      findsOneWidget,
      reason: 'FOG-04: FogLayer.build() must wrap its CustomPaint in MobileLayerTransformer',
    );
    expect(find.descendant(of: find.byType(MobileLayerTransformer), matching: find.byType(CustomPaint)), findsOneWidget);
  });

  testWidgets('the seam receives the 20 tunables, 31 observed float slots, identity sdfRect and a live uTime (FOG-05)', (tester) async {
    final harness = await pumpAtmosphericFogLayer(tester);
    final first = harness.recorder.renders.first;
    expect(first.namedFloatArgs.keys, unorderedEquals(FogShaderTunableKey.all), reason: '20 named tunables in slot order');
    expect(first.totalFloatSlotsObserved, equals(31));
    expect(first.sdfRect, equals(kFogSdfRectIdentity), reason: 'isAndroid: false → no V-flip (FOG-21)');
    expect(first.resolution, equals(kTestFogViewportSize), reason: 'uResolution == camera.size');

    // uTime is read from the live Stopwatch on every paint (invariant 10).
    final int alreadyRecorded = harness.recorder.renders.length;
    await pumpUntilShaderRendered(tester, harness.recorder, alreadyRecorded: alreadyRecorded);
    final last = harness.recorder.renders.last;
    expect(last.timeSeconds, greaterThan(first.timeSeconds), reason: 'a frozen sessionElapsed would freeze the fog drift');
    await harness.renderer.dispose();
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_layer_wisp_render_test.dart — invariant WISP-04
//
// MirkFall difference: the wisps live behind the `MirkRenderer` seam
// (`AtmosphericMirkRenderer._renderWisps`, plan 09.1-05), so the paint sequence
// is proved through a `FogLayer` hosting the PRODUCTION renderer with a DRAWING
// shader seam and a pre-spawned world-anchored wisp system, driven through a
// recording canvas: shader rect → wisp circles → restore, all inside the layer's
// single clip, every circle at `context.projectToScreen(wisp.position)`.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_shader_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_particle_system.dart';
import 'package:mirkfall/infrastructure/mirk/wisp/wisp_transform_logger.dart';

import '../../_helpers/atmospheric_fog_layer_harness.dart' show kMaxSdfSettleFrames, kSdfSettleRealDelay;
import '../../_helpers/fake_stopwatch.dart';
import '../../_helpers/fog_layer_test_harness.dart';
import '../../infrastructure/mirk/_render_helpers.dart' show immediateStubSdfCache;

/// Past the BUG-015 5 s warm-up, so `spawnAtNewDisc` spawns immediately.
const int _pastWarmUpMs = 6000;

/// ~20 wisps along the perimeter of a 25 m disc (`kMirkFogMetersPerWisp`).
const int _minWispsPer25mDisc = 18;
const int _maxWispsPer25mDisc = 22;

/// Shader seam that DRAWS one viewport rect (so the canvas sees the fog body)
/// and counts its renders (so the test knows when the SDF has resolved).
class _CountingDrawRectShaderRenderer implements FogShaderRenderer {
  int renderCount = 0;

  @override
  bool render({
    required Canvas canvas,
    required ui.FragmentShader? shader,
    required Size size,
    required double timeSeconds,
    required ({double x, double y}) pixelOrigin,
    required double zoomScale,
    required (double, double, double, double) sdfRect,
    required ui.Image sdfImage,
    required int baseArgb,
    required double baseAlpha,
    required int highlightArgb,
    required int shadowArgb,
    required Map<String, double> tunables,
  }) {
    renderCount++;
    canvas.drawRect(Offset.zero & size, Paint());
    return true;
  }
}

/// Records every `recordPaint` (verbose gating bypassed — the spy never emits).
class _CountingWispTransformLogger extends WispTransformLogger {
  final List<int> activeCounts = <int>[];

  @override
  void recordPaint({
    required int activeCount,
    required double meanAge,
    required (double, double) latBounds,
    required (double, double) lonBounds,
    required (double, double) screenXBounds,
    required (double, double) screenYBounds,
    required double spawnRatePerSecond,
  }) {
    activeCounts.add(activeCount);
  }
}

/// [RecordingCanvasFake] + the wisp circles.
class _WispRecordingCanvas extends RecordingCanvasFake {
  _WispRecordingCanvas() : super(canvasTx: 0, canvasTy: 0);

  final List<Offset> circleCentres = <Offset>[];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    calls.add((op: 'drawCircle', args: (c, radius)));
    circleCentres.add(c);
  }
}

/// Mounts the layer, lets the stub SDF resolve on the REAL event loop (the
/// builder finishes through `decodeImageFromPixels`), and returns once the
/// shader seam has rendered at least once.
Future<void> _pumpUntilShaderPath(WidgetTester tester, AtmosphericMirkRenderer renderer, _CountingDrawRectShaderRenderer seam, RevealDisc disc) async {
  await pumpFogLayerInFlutterMap(tester, renderer: renderer, discs: <RevealDisc>[disc]);
  await tester.runAsync(() async {
    for (int i = 0; i < kMaxSdfSettleFrames && seam.renderCount == 0; i++) {
      await Future<void>.delayed(kSdfSettleRealDelay);
      await tester.pump();
    }
  });
  await tester.pump();
  expect(seam.renderCount, greaterThan(0), reason: 'the shader seam was never reached — SDF did not resolve within $kMaxSdfSettleFrames iterations');
}

/// Unmounts the layer first so no Ticker frame paints with a disposed renderer.
Future<void> _teardown(WidgetTester tester, AtmosphericMirkRenderer renderer) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await renderer.dispose();
}

void main() {
  testWidgets('wisp circles are drawn AFTER the shader rect and BEFORE restore, inside the layer clip, one per active wisp at its projected position', (
    WidgetTester tester,
  ) async {
    final RevealDisc disc = centreTestDisc(id: 'rvd_wisp_paint_seq');
    final WispParticleSystem wispSystem = WispParticleSystem(wallClock: FakeStopwatch(initialMs: _pastWarmUpMs))..spawnAtNewDisc(discId: disc.id, disc: disc);
    expect(
      wispSystem.activeCount,
      inInclusiveRange(_minWispsPer25mDisc, _maxWispsPer25mDisc),
      reason: 'pre-condition: ~20 wisps spawned along the 25 m perimeter',
    );
    final _CountingDrawRectShaderRenderer seam = _CountingDrawRectShaderRenderer();
    final _CountingWispTransformLogger wispLogger = _CountingWispTransformLogger();
    final AtmosphericMirkRenderer renderer = AtmosphericMirkRenderer(
      const AtmosphericConfig(),
      shaderRenderer: seam,
      sdfCache: immediateStubSdfCache(),
      wispSystem: wispSystem,
      wispTransformLogger: wispLogger,
    );
    await _pumpUntilShaderPath(tester, renderer, seam, disc);

    final CustomPainter painter = findFogPainter(tester);
    final _WispRecordingCanvas canvas = _WispRecordingCanvas();
    painter.paint(canvas, kTestFogViewportSize);

    final Map<String, int> firstIndexByOp = canvas.firstIndexByOp;
    expect(firstIndexByOp['clipPath'], isNotNull, reason: 'FOG-06: the layer clips before the renderer paints');
    expect(firstIndexByOp['drawRect'], isNotNull, reason: 'the shader seam drew the fog body');
    expect(firstIndexByOp['drawCircle'], isNotNull, reason: 'WISP-04: at least one wisp circle when activeCount > 0');
    expect(firstIndexByOp['restore'], isNotNull);
    expect(firstIndexByOp['clipPath']!, lessThan(firstIndexByOp['drawCircle']!), reason: 'wisps are drawn inside the clipped identity frame');
    expect(firstIndexByOp['drawRect']!, lessThan(firstIndexByOp['drawCircle']!), reason: 'WISP-04: shader rect BEFORE the wisps, same frame');
    expect(firstIndexByOp['drawCircle']!, lessThan(firstIndexByOp['restore']!), reason: 'WISP-04: wisps inside the save / restore block');

    // `advanceFromElapsed` runs before the loop, so the count is the post-paint one.
    expect(canvas.circleCentres, hasLength(wispSystem.activeCount), reason: 'exactly one drawCircle per active wisp');
    for (final Offset centre in canvas.circleCentres) {
      // Spawned within ±25 m of the camera centre → a few px around (200, 400) at z13.
      expect(centre.dx, inExclusiveRange(0.0, kTestFogViewportSize.width), reason: 'wisp projected inside the viewport (x)');
      expect(centre.dy, inExclusiveRange(0.0, kTestFogViewportSize.height), reason: 'wisp projected inside the viewport (y)');
    }
    expect(wispLogger.activeCounts, isNotEmpty, reason: 'one recordPaint per paint');
    expect(wispLogger.activeCounts.last, equals(wispSystem.activeCount));
    await _teardown(tester, renderer);
  });

  testWidgets('an empty wisp system draws no circle and records nothing, while the clip / restore block still runs', (WidgetTester tester) async {
    final RevealDisc disc = centreTestDisc(id: 'rvd_wisp_empty');
    // Real stopwatch → still inside the warm-up → spawns are recorded but inert.
    final WispParticleSystem wispSystem = WispParticleSystem();
    final _CountingDrawRectShaderRenderer seam = _CountingDrawRectShaderRenderer();
    final _CountingWispTransformLogger wispLogger = _CountingWispTransformLogger();
    final AtmosphericMirkRenderer renderer = AtmosphericMirkRenderer(
      const AtmosphericConfig(),
      shaderRenderer: seam,
      sdfCache: immediateStubSdfCache(),
      wispSystem: wispSystem,
      wispTransformLogger: wispLogger,
    );
    await _pumpUntilShaderPath(tester, renderer, seam, disc);
    expect(wispSystem.activeCount, 0);

    final CustomPainter painter = findFogPainter(tester);
    final _WispRecordingCanvas canvas = _WispRecordingCanvas();
    painter.paint(canvas, kTestFogViewportSize);

    expect(canvas.circleCentres, isEmpty, reason: 'WISP-04: an empty system produces ZERO drawCircle');
    expect(wispLogger.activeCounts, isEmpty, reason: 'nothing recorded when no wisp is alive');
    expect(canvas.firstIndexByOp['clipPath'], isNotNull, reason: 'the fog clip does not depend on the wisps');
    expect(canvas.firstIndexByOp['drawRect'], isNotNull, reason: 'the fog body is still painted');
    expect(canvas.firstIndexByOp['restore'], isNotNull);
    await _teardown(tester, renderer);
  });
}

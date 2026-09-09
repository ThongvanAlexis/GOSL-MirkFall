// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_rect_viewport_coverage_test.dart — invariant FOG-13

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/fog_transform_logger.dart';

import '../../_helpers/fog_layer_test_harness.dart';

/// FOG-13 (03.1-08 → 03.1-08-FIX) — `_FogPainter.paint()` calls
/// `canvas.translate(-canvasTx, -canvasTy)` at the TOP of paint (before
/// `clipPath` and before the renderer draws) so the whole painter operates in
/// the identity frame: the clip lands at world coordinates and the renderer's
/// viewport rect covers the whole screen regardless of the canvas translation
/// (Walk #2: sustained `(+757.35, +319.46)` left un-fogged strips at high zoom).
///
/// Invariants:
///   1. Call order `getTransform → save → translate → clipPath → drawRect → restore`.
///   2. Exactly ONE `translate(-canvasTx, -canvasTy)` per paint, args within
///      [kTestCanvasTransformEpsilon].
///   3. Clip geometry identical regardless of canvasOffset (reveal-hole position).
///   4. On a REAL canvas pre-translated by the same magnitudes, the renderer
///      observes an identity transform, `size == camera.size` and a local clip
///      covering exactly the viewport.
void main() {
  /// iPhone logical viewport — matches Walk #2's device.
  const Size walkViewport = Size(390, 844);

  group('FOG-13 (03.1-08-FIX keystone)', () {
    testWidgets('paint call order: getTransform → save → translate → clipPath → drawRect → restore at extreme canvas-translation magnitudes', (tester) async {
      final renderer = SpyMirkRenderer();
      await pumpFogLayerInFlutterMap(tester, renderer: renderer, discs: <RevealDisc>[centreTestDisc()], viewportSize: walkViewport);
      final painter = findFogPainter(tester);

      final mockCanvas = RecordingCanvasFake(canvasTx: 757.35, canvasTy: 319.46);
      painter.paint(mockCanvas, walkViewport);
      final indexByOp = mockCanvas.firstIndexByOp;

      for (final op in <String>['getTransform', 'save', 'translate', 'clipPath', 'drawRect', 'restore']) {
        expect(indexByOp[op], isNotNull, reason: 'painter must call canvas.$op');
      }
      expect(indexByOp['getTransform']! < indexByOp['save']!, isTrue, reason: 'the matrix read happens before the block opens');
      expect(indexByOp['save']! < indexByOp['translate']!, isTrue);
      expect(
        indexByOp['translate']! < indexByOp['clipPath']!,
        isTrue,
        reason: '03.1-08-FIX: translate BEFORE clipPath (double-compensation regression on build 8a37bfd)',
      );
      expect(indexByOp['clipPath']! < indexByOp['drawRect']!, isTrue, reason: 'the renderer draws inside the clip');
      expect(indexByOp['drawRect']! < indexByOp['restore']!, isTrue, reason: 'the renderer draws inside the translate block');

      final translateCalls = mockCanvas.translateCallArgs;
      expect(translateCalls, hasLength(1), reason: 'single-snapshot at the matrix level');
      final (dx, dy) = translateCalls.single;
      expect((dx - (-757.35)).abs(), lessThan(kTestCanvasTransformEpsilon), reason: 'translate dx == -canvasTx');
      expect((dy - (-319.46)).abs(), lessThan(kTestCanvasTransformEpsilon), reason: 'translate dy == -canvasTy');
      expect(mockCanvas.getTransformCallCount, equals(1));
    });

    testWidgets('reveal-hole-position invariant: clip-path geometry identical regardless of canvasOffset', (tester) async {
      final renderer = SpyMirkRenderer();
      await pumpFogLayerInFlutterMap(tester, renderer: renderer, discs: <RevealDisc>[centreTestDisc()], viewportSize: walkViewport);
      final painter = findFogPainter(tester);

      final identityCanvas = RecordingCanvasFake(canvasTx: 0, canvasTy: 0);
      painter.paint(identityCanvas, walkViewport);
      expect(identityCanvas.clipPathCalls, hasLength(1), reason: 'exactly one clipPath per paint');
      final identityBounds = identityCanvas.clipPathCalls.single.getBounds();

      final shiftedCanvas = RecordingCanvasFake(canvasTx: 757.35, canvasTy: 319.46);
      painter.paint(shiftedCanvas, walkViewport);
      expect(shiftedCanvas.clipPathCalls, hasLength(1));
      final shiftedBounds = shiftedCanvas.clipPathCalls.single.getBounds();

      expect(
        (shiftedBounds.left - identityBounds.left).abs(),
        lessThan(kTestSubPixelTolerance),
        reason: 'the painter must not pass canvasOffset to computeFogClipPath',
      );
      expect((shiftedBounds.top - identityBounds.top).abs(), lessThan(kTestSubPixelTolerance));
      expect((shiftedBounds.right - identityBounds.right).abs(), lessThan(kTestSubPixelTolerance));
      expect((shiftedBounds.bottom - identityBounds.bottom).abs(), lessThan(kTestSubPixelTolerance));
      expect(identityBounds.width, closeTo(walkViewport.width, kTestSubPixelTolerance), reason: 'the clip covers exactly the viewport');
      expect(identityBounds.height, closeTo(walkViewport.height, kTestSubPixelTolerance));
    });

    testWidgets('identity canvas transform still gets translate(0, 0) so the call sequence is invariant', (tester) async {
      final renderer = SpyMirkRenderer();
      await pumpFogLayerInFlutterMap(tester, renderer: renderer, viewportSize: walkViewport);
      final painter = findFogPainter(tester);
      final mockCanvas = RecordingCanvasFake(canvasTx: 0, canvasTy: 0);
      painter.paint(mockCanvas, walkViewport);
      final translateCalls = mockCanvas.translateCallArgs;
      expect(translateCalls, hasLength(1), reason: 'no special-case branch at identity — always translate');
      final (dx, dy) = translateCalls.single;
      expect(dx, equals(0.0));
      expect(dy, equals(0.0));
    });

    testWidgets('REAL canvas pre-translated by (757.35, 319.46): the renderer paints in the identity frame, at camera.size, clipped to the viewport', (
      tester,
    ) async {
      final renderer = SpyMirkRenderer(inspectCanvas: true);
      await pumpFogLayerInFlutterMap(tester, renderer: renderer, discs: <RevealDisc>[centreTestDisc()], viewportSize: walkViewport);
      final painter = findFogPainter(tester);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(757.35, 319.46);
      painter.paint(canvas, walkViewport);
      recorder.endRecording().dispose();

      // `.last`: the widget's own paint pass also went through the spy (real canvas).
      final transform = renderer.canvasTransforms.last;
      expect(
        transform[kCanvasTransformTxIndex].abs(),
        lessThan(kTestCanvasTransformEpsilon),
        reason: 'after translate(-canvasOffset) the renderer sees tx == 0',
      );
      expect(transform[kCanvasTransformTyIndex].abs(), lessThan(kTestCanvasTransformEpsilon), reason: 'ty == 0');
      expect(transform[kCanvasTransformSxIndex], equals(1.0));
      expect(transform[kCanvasTransformSyIndex], equals(1.0));
      expect(renderer.paintSizes.last, equals(walkViewport), reason: 'size == camera.size (CustomPaint fills the MobileLayerTransformer box)');
      final clip = renderer.localClipBounds.last;
      expect(clip.left, closeTo(0, kTestSubPixelTolerance), reason: 'the clip covers exactly the viewport in the identity frame');
      expect(clip.top, closeTo(0, kTestSubPixelTolerance));
      expect(clip.right, closeTo(walkViewport.width, kTestSubPixelTolerance));
      expect(clip.bottom, closeTo(walkViewport.height, kTestSubPixelTolerance));
      // A real canvas stores its matrix in float32 — compare within sub-pixel tolerance.
      expect(renderer.lastContext.canvasOffset.dx, closeTo(757.35, kTestSubPixelTolerance), reason: 'informational canvasOffset forwarded to the context');
      expect(renderer.lastContext.canvasOffset.dy, closeTo(319.46, kTestSubPixelTolerance));
    });
  });
}

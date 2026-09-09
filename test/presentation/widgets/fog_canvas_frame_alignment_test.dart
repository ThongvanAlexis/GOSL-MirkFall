// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Porté de mirk-poc-debug@90c9321 test/presentation/widgets/fog_canvas_frame_alignment_test.dart — invariant FOG-12

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';

import '../../_helpers/fog_layer_test_harness.dart';

/// FOG-12 (03.1-05 + 03.1-08-FIX) — `_FogPainter.paint()` normalises its local
/// Canvas to the identity frame BEFORE any clip / draw, so the reveal frame
/// stays co-located with the sibling puck `CircleLayer` regardless of the
/// translation `MobileLayerTransformer` applied above.
///
/// Three layered invariants:
///   1. `translate(-tx, -ty)` is called BEFORE `clipPath(...)`.
///   2. The clip-path geometry is INVARIANT under the canvas transform (the
///      painter passes no `canvasOffset` to `computeFogClipPath`).
///   3. Exactly ONE `getTransform()` per paint (matrix-level FOG-07).
///
/// By composition of (1) + (2) the device position of the reveal hole is the
/// same for any canvas offset — "the blue dot stays inside the hole during pan / zoom".
void main() {
  group('FOG-12 (03.1-05 + 03.1-08-FIX keystone)', () {
    testWidgets('translate-before-clipPath + clip-path geometry invariant under non-zero Canvas transform', (tester) async {
      final renderer = SpyMirkRenderer();
      await pumpFogLayerInFlutterMap(tester, renderer: renderer, discs: <RevealDisc>[centreTestDisc()]);
      final painter = findFogPainter(tester);

      // Paint #1 — identity canvas transform.
      final identityCanvas = RecordingCanvasFake(canvasTx: 0, canvasTy: 0);
      painter.paint(identityCanvas, kTestFogViewportSize);
      expect(identityCanvas.clipPathCalls, hasLength(1));
      final identityBounds = identityCanvas.clipPathCalls.single.getBounds();

      // Paint #2 — 03.1-FALSIFICATION.md Finding 1 magnitudes.
      final shiftedCanvas = RecordingCanvasFake(canvasTx: 5.035, canvasTy: -44.198);
      painter.paint(shiftedCanvas, kTestFogViewportSize);
      expect(shiftedCanvas.clipPathCalls, hasLength(1));
      final shiftedBounds = shiftedCanvas.clipPathCalls.single.getBounds();

      // Invariant #1 — translate BEFORE clipPath.
      expect(
        shiftedCanvas.translateBeforeClipPath,
        isTrue,
        reason:
            '03.1-08-FIX regression: canvas.translate(-tx, -ty) MUST be called BEFORE canvas.clipPath(...) so the prevailing transform is identity '
            'when the clip is registered. Translate AFTER clipPath forced computeFogClipPath to pre-shift the path, which double-compensated the hole.',
      );

      // Invariant #2 — clip geometry invariant under canvasOffset.
      expect(
        (shiftedBounds.left - identityBounds.left).abs(),
        lessThan(kTestSubPixelTolerance),
        reason: 'the painter must not pass canvasOffset to computeFogClipPath',
      );
      expect((shiftedBounds.top - identityBounds.top).abs(), lessThan(kTestSubPixelTolerance));
      expect((shiftedBounds.right - identityBounds.right).abs(), lessThan(kTestSubPixelTolerance));
      expect((shiftedBounds.bottom - identityBounds.bottom).abs(), lessThan(kTestSubPixelTolerance));

      // Invariant #3 — exactly ONE getTransform() per paint.
      expect(shiftedCanvas.getTransformCallCount, equals(1), reason: 'single-snapshot invariant at the matrix level (mirrors FOG-07)');
      expect(identityCanvas.getTransformCallCount, equals(1));

      // Exactly ONE translate, cancelling the canvas transform.
      expect(shiftedCanvas.translateCallArgs, hasLength(1), reason: 'a second translate would undo the normalisation');
      final (translateDx, translateDy) = shiftedCanvas.translateCallArgs.single;
      expect(translateDx, equals(-5.035), reason: 'translate dx == -canvasTx');
      expect(translateDy, equals(44.198), reason: 'translate dy == -canvasTy');

      // The renderer paints INSIDE the block: after clipPath, before restore.
      final indexByOp = shiftedCanvas.firstIndexByOp;
      expect(indexByOp['drawRect'], isNotNull, reason: 'the renderer (spy) draws the viewport rect');
      expect(indexByOp['clipPath']! < indexByOp['drawRect']!, isTrue);
      expect(indexByOp['drawRect']! < indexByOp['restore']!, isTrue);
      expect(renderer.paintSizes.last, equals(kTestFogViewportSize));
    });

    testWidgets('the context reports the compensated canvasOffset (informational, FOG-12/13) and the renderer is told the elapsed time', (tester) async {
      final renderer = SpyMirkRenderer();
      await pumpFogLayerInFlutterMap(tester, renderer: renderer);
      final painter = findFogPainter(tester);
      painter.paint(RecordingCanvasFake(canvasTx: 757.35, canvasTy: 319.46), kTestFogViewportSize);
      expect(renderer.lastContext.canvasOffset, equals((dx: 757.35, dy: 319.46)));
      expect(renderer.updateElapsed.last, equals(renderer.lastContext.sessionElapsed), reason: 'renderer.update(sessionElapsed) precedes renderer.paint');
    });
  });
}

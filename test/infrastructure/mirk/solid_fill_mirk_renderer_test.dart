// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 2 RED test suite for `SolidFillMirkRenderer`.
//
// Solid is the simplest variant — uniform colour fill, no animation,
// no noise. Tests verify single-frame correctness, frame-to-frame
// invariance (the proof-of-static for MIRK-06 contrast against the
// 3 animated variants), and dispose idempotence.

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

import '_render_helpers.dart';

void main() {
  group('09-04 — SolidFillMirkRenderer (MIRK-06)', () {
    test(
      'paint() output is identical across frames (no animation, deterministic)',
      () async {
        final renderer = SolidFillMirkRenderer(
          MirkStyleConfig.solid() as SolidConfig,
        );
        final ctx0 = fakeContext(elapsedMs: 0);
        final ctx10s = fakeContext(elapsedMs: 10000);
        final bytes0 = await renderToBytes(renderer, context: ctx0);
        final bytes10s = await renderToBytes(renderer, context: ctx10s);
        expect(
          bytes0,
          equals(bytes10s),
          reason:
              'Solid is time-invariant — different sessionElapsed must '
              'still produce byte-identical output',
        );
        await renderer.dispose();
      },
    );

    test(
      'paint() with empty visibleTiles list issues no draw calls (no-op)',
      () async {
        final renderer = SolidFillMirkRenderer(
          MirkStyleConfig.solid() as SolidConfig,
        );
        // Override tiles with an empty list — paint should early-return.
        final ctx = fakeContext(tiles: const []);
        // Use renderToPicture so we can ask the picture for an
        // approximate byte size; an empty picture is < 200 bytes
        // (recorder header only).
        final pic = renderToPicture(renderer, context: ctx);
        // ApproximateBytesUsed reflects native command-buffer size.
        expect(
          pic.approximateBytesUsed,
          lessThan(500),
          reason: 'Empty visibleTiles should produce a near-empty picture',
        );
        pic.dispose();
        await renderer.dispose();
      },
    );

    test(
      'paint() with all-revealed bitmap draws nothing (every cell skipped)',
      () async {
        final renderer = SolidFillMirkRenderer(
          MirkStyleConfig.solid() as SolidConfig,
        );
        // All-unrevealed tiles drive maximum draw work; all-revealed tiles
        // drive zero draw work. Compare picture sizes as a coarse signal.
        final ctxAllRevealed = fakeContext(
          tiles: [
            // Fully revealed tile — every bit = 1, no fog drawn.
            (() {
              final t = fakeContext().visibleTiles.first;
              return t.copyWith(bitmap: makeAllRevealedBitmap());
            })(),
          ],
        );
        final ctxAllUnrevealed = fakeContext(
          tiles: [
            (() {
              final t = fakeContext().visibleTiles.first;
              return t.copyWith(bitmap: makeAllUnrevealedBitmap());
            })(),
          ],
        );
        final picRevealed = renderToPicture(
          renderer,
          context: ctxAllRevealed,
        );
        final picUnrevealed = renderToPicture(
          renderer,
          context: ctxAllUnrevealed,
        );
        expect(
          picRevealed.approximateBytesUsed,
          lessThan(picUnrevealed.approximateBytesUsed),
          reason:
              'All-revealed tile must produce a smaller picture than '
              'all-unrevealed (no cells drawn vs all cells drawn)',
        );
        picRevealed.dispose();
        picUnrevealed.dispose();
        await renderer.dispose();
      },
    );

    test('update() is a no-op (does not throw, does not mutate output)', () async {
      final renderer = SolidFillMirkRenderer(
        MirkStyleConfig.solid() as SolidConfig,
      );
      final ctx = fakeContext();
      final bytesBefore = await renderToBytes(renderer, context: ctx);
      // Drive 10 frames worth of update() calls.
      for (var i = 0; i < 10; i++) {
        renderer.update(const Duration(milliseconds: 16));
      }
      final bytesAfter = await renderToBytes(renderer, context: ctx);
      expect(bytesBefore, equals(bytesAfter));
      await renderer.dispose();
    });

    test('dispose() is idempotent (calling twice does not throw)', () async {
      final renderer = SolidFillMirkRenderer(
        MirkStyleConfig.solid() as SolidConfig,
      );
      await renderer.dispose();
      await renderer.dispose(); // Must not throw.
    });

    test('paint() after dispose() is a no-op (does not throw)', () async {
      final renderer = SolidFillMirkRenderer(
        MirkStyleConfig.solid() as SolidConfig,
      );
      await renderer.dispose();
      final ctx = fakeContext();
      // Should not throw even though the renderer was disposed.
      expect(() => renderToPicture(renderer, context: ctx).dispose(), returnsNormally);
    });
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 2 RED test suite for `SolidFillMirkRenderer`.
//
// BUG-010 Option B Commit 5 — fixture surface migrated from cell-bitmap
// to continuous-geometry discs (see atmospheric renderer test for the
// "all-revealed" → "viewport-spanning disc" rationale).
//
// Phase 09.1 plan 09.1-06 — the reveal holes are cut by the `FogLayer`'s
// single `clipPath` (reproduced by `renderToBytes`); the renderer paints the
// clipped identity frame and never clips itself. Solid has no noise to
// anchor, so its bytes must be invariant to the camera-derived fields.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

import '../../_helpers/mirk_paint_context_builder.dart';
import '_render_helpers.dart';

/// Centre pixel of the 256×256 test canvas.
const int _centrePx = 128;

/// Disc radius that yields a ~18 px hole on the 1° × 1° test viewport (the
/// default 100 m fixture disc is sub-pixel at that scale).
const double _visibleHoleRadiusMeters = 8000.0;

void main() {
  group('09-04 — SolidFillMirkRenderer (MIRK-06)', () {
    test('paint() output is identical across frames (no animation, deterministic)', () async {
      final renderer = SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig);
      final ctx0 = fakeContext();
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
    });

    test('paint() with empty discs list paints full fog (BUG-013 fix)', () async {
      final renderer = SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig);
      // Override discs with an empty list — fog should cover the entire
      // viewport rect (user panned away from revealed area).
      final ctx = fakeContext(discs: const <RevealDisc>[]);
      final bytes = await renderToBytes(renderer, context: ctx);
      // BUG-013: empty discs = user panned away from revealed area →
      // entire viewport must be fog, not transparent/clear.
      expect(
        alphaAt(bytes, x: _centrePx, y: _centrePx),
        greaterThan(200),
        reason: 'Empty discs list should produce full fog, not a no-op',
      );
      expect(alphaAt(bytes, x: 0, y: 0), greaterThan(200));
      expect(alphaAt(bytes, x: 255, y: 255), greaterThan(200));
      await renderer.dispose();
    });

    test('paint() with a viewport-spanning disc draws nothing (every region revealed)', () async {
      final renderer = SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig);
      final bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final swallowingDisc = RevealDisc(
        id: 'rvd_test_swallow_s',
        sessionId: 'sess_test',
        lat: 43.5,
        lon: 5.5,
        radiusMeters: 200000.0,
        fixedAtUtc: DateTime.utc(2026, 4, 26),
      );
      final ctxAllRevealed = fakeContext(viewport: bbox, discs: [swallowingDisc]);
      final ctxLocalised = fakeContext(
        viewport: bbox,
        discs: [singleCentreDisc(bbox: bbox, radiusMeters: _visibleHoleRadiusMeters)],
      );
      final bytesRevealed = await renderToBytes(renderer, context: ctxAllRevealed);
      final bytesLocalised = await renderToBytes(renderer, context: ctxLocalised);
      expect(isFullyTransparent(bytesRevealed), isTrue, reason: 'Viewport-spanning disc → the shared clip is empty → nothing rasterised');
      expect(isFullyTransparent(bytesLocalised), isFalse, reason: 'A localised disc leaves fog around its hole');
      await renderer.dispose();
    });

    test('update() is a no-op (does not throw, does not mutate output)', () async {
      final renderer = SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig);
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
      final renderer = SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig);
      await renderer.dispose();
      await renderer.dispose(); // Must not throw.
    });

    test('paint() after dispose() is a no-op (does not throw)', () async {
      final renderer = SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig);
      await renderer.dispose();
      final ctx = fakeContext();
      // Should not throw even though the renderer was disposed.
      expect(() => renderToPicture(renderer, context: ctx).dispose(), returnsNormally);
    });
  });

  group('09.1-06 — clip owned by the FogLayer, nothing to anchor', () {
    final MirkViewportBbox bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);

    /// One ~18 px hole at the canvas centre; camera-derived fields overridable.
    MirkPaintContext holeContext({({double x, double y}) pixelOrigin = kTestNeutralPixelOrigin, double zoomScale = kTestNeutralZoomScale}) =>
        buildTestMirkPaintContext(
          zoomLevel: 14.0,
          viewportBbox: bbox,
          discs: <RevealDisc>[singleCentreDisc(bbox: bbox, radiusMeters: _visibleHoleRadiusMeters)],
          pixelOrigin: pixelOrigin,
          zoomScale: zoomScale,
        );

    test('without the shared clip the renderer covers the disc centre (it no longer clips itself)', () async {
      final renderer = SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig);
      addTearDown(renderer.dispose);
      final Uint8List unclipped = await renderToBytes(renderer, context: holeContext(), applyClip: false);
      expect(
        alphaAt(unclipped, x: _centrePx, y: _centrePx),
        greaterThan(200),
        reason: 'no clip → no hole: the renderer paints Offset.zero & size',
      );
      final Uint8List clipped = await renderToBytes(renderer, context: holeContext());
      expect(
        alphaAt(clipped, x: _centrePx, y: _centrePx),
        0,
        reason: 'the FogLayer clip (reproduced by the helper) is what cuts the hole',
      );
    });

    test('bytes are identical for contexts differing only by pixelOrigin / zoomScale (no noise to anchor)', () async {
      final renderer = SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig);
      addTearDown(renderer.dispose);
      final Uint8List neutral = await renderToBytes(renderer, context: holeContext());
      final Uint8List shifted = await renderToBytes(renderer, context: holeContext(pixelOrigin: (x: 1e6, y: 1e6), zoomScale: 4.0));
      expect(shifted, equals(neutral), reason: 'solid_fill must be bit-identical whatever the camera-derived fields carry');
    });
  });
}

// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 2 RED test suite for `SolidFillMirkRenderer`.
//
// BUG-010 Option B Commit 5 — fixture surface migrated from cell-bitmap
// to continuous-geometry discs (see atmospheric renderer test for the
// "all-revealed" → "viewport-spanning disc" rationale).

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

import '_render_helpers.dart';

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
      final pic = renderToPicture(renderer, context: ctx);
      // BUG-013: empty discs = user panned away from revealed area →
      // entire viewport must be fog, not transparent/clear. The fallback
      // path emits a single drawPath (~300 bytes); a true no-op produces
      // ~120 bytes (recorder header only).
      expect(pic.approximateBytesUsed, greaterThan(200), reason: 'Empty discs list should produce full-fog picture, not a no-op');
      pic.dispose();
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
      final ctxLocalised = fakeContext(viewport: bbox);
      final picRevealed = renderToPicture(renderer, context: ctxAllRevealed);
      final picLocalised = renderToPicture(renderer, context: ctxLocalised);
      expect(
        picRevealed.approximateBytesUsed,
        lessThan(picLocalised.approximateBytesUsed),
        reason:
            'Viewport-spanning disc must produce a smaller picture than '
            'a localised disc (clip path empty vs disc-shaped fog hole)',
      );
      picRevealed.dispose();
      picLocalised.dispose();
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
}

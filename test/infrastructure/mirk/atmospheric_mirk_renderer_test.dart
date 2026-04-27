// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 2 RED test suite for `AtmosphericMirkRenderer`
// (MIRK-04 default builtin).
//
// Tests cover:
// - Animation proof: two frames at different `sessionElapsed` differ.
// - Determinism: same `sessionElapsed` rendered twice → byte-identical.
// - Empty discs → no-op (near-empty picture).
// - All-viewport-covered (one giant disc swallowing the viewport) → no fog.
// - dispose() idempotence + post-dispose paint guarded.
//
// BUG-010 Option B Commit 5 — fixture surface migrated from cell-bitmap
// to continuous-geometry discs. The "all-revealed bitmap" assertion of
// pre-Commit-5 is preserved by feeding a single disc large enough to
// cover the entire viewport.

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';

import '_render_helpers.dart';

void main() {
  group('09-04 — AtmosphericMirkRenderer (MIRK-04)', () {
    test('paint() output differs between frames at different sessionElapsed (animation proof)', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      final bytes0 = await renderToBytes(renderer, context: fakeContext());
      final bytes5s = await renderToBytes(renderer, context: fakeContext(elapsedMs: 5000));
      expect(
        bytes0,
        isNot(equals(bytes5s)),
        reason:
            'Atmospheric must animate — sessionElapsed delta of 5s must '
            'produce visually distinct output (MIRK-04 animation proof)',
      );
      await renderer.dispose();
    });

    test('paint() output is deterministic at fixed sessionElapsed + seed', () async {
      // Same seed, same elapsed → identical output across two render passes.
      final r1 = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      final r2 = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      final ctx = fakeContext(elapsedMs: 1234);
      final bytes1 = await renderToBytes(r1, context: ctx);
      final bytes2 = await renderToBytes(r2, context: ctx);
      expect(
        bytes1,
        equals(bytes2),
        reason:
            'Two AtmosphericMirkRenderer instances with the same default '
            'seed must produce byte-identical output for the same context',
      );
      await r1.dispose();
      await r2.dispose();
    });

    test('paint() with empty discs list paints full fog (BUG-013 fix)', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
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

    test('paint() with a viewport-spanning disc draws no fog (smaller picture than localised disc)', () async {
      // Pre-Commit-5 this asserted "all-revealed bitmap → no draw" against
      // an all-bits-set 64×64 mask. With continuous geometry the
      // equivalent setup is "one disc whose radius covers the entire
      // viewport". The clip path then degenerates to "viewport rect minus
      // a giant circle that contains the rect" → empty bounds → renderer
      // early-returns. The localised-disc context produces a non-empty
      // path, and therefore a larger picture.
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      final bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      // 1° lat × 1° lon viewport ≈ 110 km × 80 km at 43° lat → 200 km
      // disc radius covers the entire viewport with margin.
      const swallowingRadiusMeters = 200000.0;
      final swallowingDisc = RevealDisc(
        id: 'rvd_test_swallow',
        sessionId: 'sess_test',
        lat: 43.5,
        lon: 5.5,
        radiusMeters: swallowingRadiusMeters,
        fixedAtUtc: DateTime.utc(2026, 4, 26),
      );
      final ctxAllRevealed = fakeContext(viewport: bbox, discs: [swallowingDisc]);
      final ctxLocalised = fakeContext(viewport: bbox);
      final picRevealed = renderToPicture(renderer, context: ctxAllRevealed);
      final picLocalised = renderToPicture(renderer, context: ctxLocalised);
      expect(
        picRevealed.approximateBytesUsed,
        lessThan(picLocalised.approximateBytesUsed),
        reason: 'Viewport-spanning disc must draw less than a localised reveal',
      );
      picRevealed.dispose();
      picLocalised.dispose();
      await renderer.dispose();
    });

    test('dispose() is idempotent (calling twice does not throw)', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      await renderer.dispose();
      await renderer.dispose(); // Must not throw.
    });

    test('paint() after dispose() is a no-op (does not throw)', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      await renderer.dispose();
      final ctx = fakeContext();
      expect(() => renderToPicture(renderer, context: ctx).dispose(), returnsNormally);
    });

    test('different seeds produce different output (seed wired through)', () async {
      final r1 = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, seed: 1);
      final r2 = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig, seed: 2);
      final ctx = fakeContext(elapsedMs: 1000);
      final bytes1 = await renderToBytes(r1, context: ctx);
      final bytes2 = await renderToBytes(r2, context: ctx);
      expect(bytes1, isNot(equals(bytes2)), reason: 'Different seeds should produce visually distinct fog patterns');
      await r1.dispose();
      await r2.dispose();
    });
  });
}

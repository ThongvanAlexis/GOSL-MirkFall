// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 2 RED test suite for `AtmosphericMirkRenderer`
// (MIRK-04 default builtin).
//
// Tests cover:
// - Animation proof: two frames at different `sessionElapsed` differ.
// - Determinism: same `sessionElapsed` rendered twice → byte-identical.
// - Empty visibleTiles → no-op (near-empty picture).
// - All-revealed bitmap → no fog drawn (smaller picture than all-unrevealed).
// - dispose() idempotence + post-dispose paint guarded.

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';

import '_render_helpers.dart';

void main() {
  group('09-04 — AtmosphericMirkRenderer (MIRK-04)', () {
    test(
      'paint() output differs between frames at different sessionElapsed (animation proof)',
      () async {
        final renderer = AtmosphericMirkRenderer(
          MirkStyleConfig.atmospheric() as AtmosphericConfig,
        );
        final bytes0 = await renderToBytes(
          renderer,
          context: fakeContext(elapsedMs: 0),
        );
        final bytes5s = await renderToBytes(
          renderer,
          context: fakeContext(elapsedMs: 5000),
        );
        expect(
          bytes0,
          isNot(equals(bytes5s)),
          reason:
              'Atmospheric must animate — sessionElapsed delta of 5s must '
              'produce visually distinct output (MIRK-04 animation proof)',
        );
        await renderer.dispose();
      },
    );

    test(
      'paint() output is deterministic at fixed sessionElapsed + seed',
      () async {
        // Same seed, same elapsed → identical output across two render passes.
        final r1 = AtmosphericMirkRenderer(
          MirkStyleConfig.atmospheric() as AtmosphericConfig,
        );
        final r2 = AtmosphericMirkRenderer(
          MirkStyleConfig.atmospheric() as AtmosphericConfig,
        );
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
      },
    );

    test(
      'paint() with empty visibleTiles list issues no draw calls',
      () async {
        final renderer = AtmosphericMirkRenderer(
          MirkStyleConfig.atmospheric() as AtmosphericConfig,
        );
        final ctx = fakeContext(tiles: const []);
        final pic = renderToPicture(renderer, context: ctx);
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
      'paint() with all-revealed bitmap draws no fog (smaller picture than all-unrevealed)',
      () async {
        final renderer = AtmosphericMirkRenderer(
          MirkStyleConfig.atmospheric() as AtmosphericConfig,
        );
        final ctxAllRevealed = fakeContext(
          tiles: [
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
        final picRevealed = renderToPicture(renderer, context: ctxAllRevealed);
        final picUnrevealed = renderToPicture(
          renderer,
          context: ctxAllUnrevealed,
        );
        expect(
          picRevealed.approximateBytesUsed,
          lessThan(picUnrevealed.approximateBytesUsed),
          reason: 'All-revealed tile must draw less than all-unrevealed tile',
        );
        picRevealed.dispose();
        picUnrevealed.dispose();
        await renderer.dispose();
      },
    );

    test('dispose() is idempotent (calling twice does not throw)', () async {
      final renderer = AtmosphericMirkRenderer(
        MirkStyleConfig.atmospheric() as AtmosphericConfig,
      );
      await renderer.dispose();
      await renderer.dispose(); // Must not throw.
    });

    test('paint() after dispose() is a no-op (does not throw)', () async {
      final renderer = AtmosphericMirkRenderer(
        MirkStyleConfig.atmospheric() as AtmosphericConfig,
      );
      await renderer.dispose();
      final ctx = fakeContext();
      expect(
        () => renderToPicture(renderer, context: ctx).dispose(),
        returnsNormally,
      );
    });

    test('different seeds produce different output (seed wired through)', () async {
      final r1 = AtmosphericMirkRenderer(
        MirkStyleConfig.atmospheric() as AtmosphericConfig,
        seed: 1,
      );
      final r2 = AtmosphericMirkRenderer(
        MirkStyleConfig.atmospheric() as AtmosphericConfig,
        seed: 2,
      );
      final ctx = fakeContext(elapsedMs: 1000);
      final bytes1 = await renderToBytes(r1, context: ctx);
      final bytes2 = await renderToBytes(r2, context: ctx);
      expect(
        bytes1,
        isNot(equals(bytes2)),
        reason:
            'Different seeds should produce visually distinct fog patterns',
      );
      await r1.dispose();
      await r2.dispose();
    });
  });
}

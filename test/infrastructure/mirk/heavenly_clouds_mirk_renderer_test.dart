// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 3 RED test suite for `HeavenlyCloudsMirkRenderer`
// (MIRK-06 builtin).
//
// Heavenly clouds is a slow drifting overlay — coarse-noise blobs that
// drift NE (45°). Tests cover:
// - Animation proof (output differs across 5-second sessionElapsed delta).
// - dispose idempotence + post-dispose paint guard.
// - Empty visibleTiles → no-op picture.

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';

import '_render_helpers.dart';

void main() {
  group('09-04 — HeavenlyCloudsMirkRenderer (MIRK-06)', () {
    test(
      'paint() output differs between two frames at 5s sessionElapsed apart (drift animation proof)',
      () async {
        final renderer = HeavenlyCloudsMirkRenderer(
          const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
        );
        final bytes0 = await renderToBytes(
          renderer,
          context: fakeContext(),
        );
        final bytes5s = await renderToBytes(
          renderer,
          context: fakeContext(elapsedMs: 5000),
        );
        expect(
          bytes0,
          isNot(equals(bytes5s)),
          reason:
              'Heavenly clouds must drift — sessionElapsed delta of 5s '
              'must produce visually distinct output',
        );
        await renderer.dispose();
      },
    );

    test(
      'paint() output is deterministic at fixed sessionElapsed + seed',
      () async {
        final r1 = HeavenlyCloudsMirkRenderer(
          const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
        );
        final r2 = HeavenlyCloudsMirkRenderer(
          const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
        );
        final ctx = fakeContext(elapsedMs: 2500);
        final bytes1 = await renderToBytes(r1, context: ctx);
        final bytes2 = await renderToBytes(r2, context: ctx);
        expect(
          bytes1,
          equals(bytes2),
          reason:
              'Two HeavenlyCloudsMirkRenderer instances with the same '
              'default seed must produce byte-identical output',
        );
        await r1.dispose();
        await r2.dispose();
      },
    );

    test(
      'paint() with empty visibleTiles list issues no draw calls',
      () async {
        final renderer = HeavenlyCloudsMirkRenderer(
          const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
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
        final renderer = HeavenlyCloudsMirkRenderer(
          const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
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
      final renderer = HeavenlyCloudsMirkRenderer(
        const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
      );
      await renderer.dispose();
      await renderer.dispose(); // Must not throw.
    });

    test('paint() after dispose() is a no-op (does not throw)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(
        const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig,
      );
      await renderer.dispose();
      final ctx = fakeContext();
      expect(
        () => renderToPicture(renderer, context: ctx).dispose(),
        returnsNormally,
      );
    });
  });
}

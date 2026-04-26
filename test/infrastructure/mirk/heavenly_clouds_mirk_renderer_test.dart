// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 3 RED test suite for `HeavenlyCloudsMirkRenderer`
// (MIRK-06 builtin).
//
// BUG-010 Option B Commit 5 — fixture surface migrated from cell-bitmap
// to continuous-geometry discs (see atmospheric renderer test for the
// "all-revealed" → "viewport-spanning disc" rationale).

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';

import '_render_helpers.dart';

void main() {
  group('09-04 — HeavenlyCloudsMirkRenderer (MIRK-06)', () {
    test('paint() output differs between two frames at 5s sessionElapsed apart (drift animation proof)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final bytes0 = await renderToBytes(renderer, context: fakeContext());
      final bytes5s = await renderToBytes(renderer, context: fakeContext(elapsedMs: 5000));
      expect(
        bytes0,
        isNot(equals(bytes5s)),
        reason:
            'Heavenly clouds must drift — sessionElapsed delta of 5s '
            'must produce visually distinct output',
      );
      await renderer.dispose();
    });

    test('paint() output is deterministic at fixed sessionElapsed + seed', () async {
      final r1 = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final r2 = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
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
    });

    test('paint() with empty discs list issues no draw calls', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final ctx = fakeContext(discs: const <RevealDisc>[]);
      final pic = renderToPicture(renderer, context: ctx);
      expect(pic.approximateBytesUsed, lessThan(500), reason: 'Empty discs list should produce a near-empty picture');
      pic.dispose();
      await renderer.dispose();
    });

    test('paint() with a viewport-spanning disc draws no fog (smaller picture than localised disc)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final swallowingDisc = RevealDisc(
        id: 'rvd_test_swallow_h',
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
        reason: 'Viewport-spanning disc must draw less than a localised reveal',
      );
      picRevealed.dispose();
      picLocalised.dispose();
      await renderer.dispose();
    });

    test('dispose() is idempotent (calling twice does not throw)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      await renderer.dispose();
      await renderer.dispose(); // Must not throw.
    });

    test('paint() after dispose() is a no-op (does not throw)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      await renderer.dispose();
      final ctx = fakeContext();
      expect(() => renderToPicture(renderer, context: ctx).dispose(), returnsNormally);
    });
  });
}

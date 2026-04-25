// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 3 RED test suite for `CandlelightMirkRenderer`
// (MIRK-06 builtin).
//
// Candlelight is a slow warm flicker — radial gradient centred on the
// current GPS fix (or viewport centre when no fix yet). Tests cover:
// - Animation proof (output differs across frames at fixed sessionElapsed delta).
// - currentFix-null path falls back to viewport centre.
// - dispose idempotence + post-dispose paint guard.

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';

import '_render_helpers.dart';

Fix _testFix({double lat = 43.6, double lon = 5.5}) {
  return Fix(
    id: const FixId('fix_test'),
    sessionId: const SessionId('sess_test'),
    latitude: lat,
    longitude: lon,
    accuracyMeters: 10.0,
    recordedAtUtc: DateTime.utc(2026, 4, 25, 10),
    recordedAtOffsetMinutes: 0,
  );
}

void main() {
  group('09-04 — CandlelightMirkRenderer (MIRK-06)', () {
    test('paint() output differs between two frames at sessionElapsed apart (flicker animation proof)', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      final bytes0 = await renderToBytes(renderer, context: fakeContext(currentFix: _testFix()));
      // 100ms apart for flicker (fast oscillation).
      final bytes100 = await renderToBytes(renderer, context: fakeContext(elapsedMs: 100, currentFix: _testFix()));
      expect(
        bytes0,
        isNot(equals(bytes100)),
        reason:
            'Candlelight must flicker — sessionElapsed delta of 100ms '
            'must produce visually distinct output',
      );
      await renderer.dispose();
    });

    test('paint() with null currentFix falls back to viewport centre (does not throw)', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      // No currentFix passed — the radial gradient must default to the
      // viewport centre and paint must succeed without throwing.
      final ctx = fakeContext();
      expect(ctx.currentFix, isNull);
      expect(() => renderToPicture(renderer, context: ctx).dispose(), returnsNormally);
      await renderer.dispose();
    });

    test('paint() output differs between currentFix=null and currentFix=present', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      final bytesNoFix = await renderToBytes(renderer, context: fakeContext(elapsedMs: 1000));
      final bytesWithFix = await renderToBytes(renderer, context: fakeContext(elapsedMs: 1000, currentFix: _testFix(lat: 43.55, lon: 5.55)));
      // The fix is offset from the viewport centre (43.5, 5.5), so
      // the gradient centres differ → outputs must differ.
      expect(
        bytesNoFix,
        isNot(equals(bytesWithFix)),
        reason:
            'Gradient centre changes when currentFix moves from null '
            'to off-centre — outputs must differ',
      );
      await renderer.dispose();
    });

    test('dispose() is idempotent (calling twice does not throw)', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      await renderer.dispose();
      await renderer.dispose(); // Must not throw.
    });

    test('paint() after dispose() is a no-op (does not throw)', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      await renderer.dispose();
      final ctx = fakeContext();
      expect(() => renderToPicture(renderer, context: ctx).dispose(), returnsNormally);
    });

    test('paint() with empty visibleTiles list issues no draw calls', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      final ctx = fakeContext(tiles: const []);
      final pic = renderToPicture(renderer, context: ctx);
      expect(pic.approximateBytesUsed, lessThan(500), reason: 'Empty visibleTiles should produce a near-empty picture');
      pic.dispose();
      await renderer.dispose();
    });
  });
}

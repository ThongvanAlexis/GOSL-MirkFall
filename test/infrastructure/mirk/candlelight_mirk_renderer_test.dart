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

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/fixes/fix.dart';
import 'package:mirkfall/domain/geo/geo_point.dart';
import 'package:mirkfall/domain/ids/fix_id.dart';
import 'package:mirkfall/domain/ids/session_id.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';

import '../../_helpers/mirk_paint_context_builder.dart';
import '_render_helpers.dart';

/// Canvas edge in pixels (the builder default is 256×256, matching `kTestCanvasSize`).
const int _canvasPx = 256;

/// Centroid of the pixels whose R+G+B sum is maximal — the radial gradient's
/// centre colour is the brightest, so this is where the glow is centred
/// (a centroid rather than a single argmax absorbs the 8-bit plateau).
Offset _brightestCentroid(Uint8List rgba) {
  var best = -1;
  var sumX = 0;
  var sumY = 0;
  var count = 0;
  for (var y = 0; y < _canvasPx; y++) {
    for (var x = 0; x < _canvasPx; x++) {
      final idx = (y * _canvasPx + x) * 4;
      final brightness = rgba[idx] + rgba[idx + 1] + rgba[idx + 2];
      if (brightness > best) {
        best = brightness;
        sumX = x;
        sumY = y;
        count = 1;
      } else if (brightness == best) {
        sumX += x;
        sumY += y;
        count++;
      }
    }
  }
  return Offset(sumX / count, sumY / count);
}

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

    test('paint() with empty discs list paints full fog (BUG-013 fix)', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      final ctx = fakeContext(discs: const <RevealDisc>[]);
      final bytes = await renderToBytes(renderer, context: ctx);
      // BUG-013: empty discs = user panned away from revealed area →
      // entire viewport must be fog, not transparent/clear.
      expect(alphaAt(bytes, x: 128, y: 128), greaterThan(150), reason: 'Empty discs list should produce full fog, not a no-op');
      expect(alphaAt(bytes, x: 0, y: 0), greaterThan(150));
      await renderer.dispose();
    });
  });

  group('09.1-06 — glow centred through context.projectToScreen (exact camera projection)', () {
    /// Tolerance on the brightest-pixel centroid vs the projected fix (px).
    const double centreTolerancePx = 2.0;

    /// Context whose projector is a spy: whatever point it receives lands on
    /// [target] (no disc, so the fix is the only point ever projected).
    MirkPaintContext spyContext({required Offset target, required List<GeoPoint> projected, Fix? currentFix}) => buildTestMirkPaintContext(
      zoomLevel: 14.0,
      sessionElapsed: const Duration(milliseconds: 1000),
      currentFix: currentFix,
      projectToScreen: (GeoPoint point) {
        projected.add(point);
        return target;
      },
    );

    test('currentFix present: the halo is centred on projectToScreen(fix) — not on a linear viewport projection', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      addTearDown(renderer.dispose);
      const Offset target = Offset(60.0, 200.0);
      final List<GeoPoint> projected = <GeoPoint>[];
      final Fix fix = _testFix(lat: 43.55, lon: 5.55);
      final Uint8List bytes = await renderToBytes(
        renderer,
        context: spyContext(target: target, projected: projected, currentFix: fix),
      );
      expect(projected, contains((latitude: 43.55, longitude: 5.55)), reason: 'the fix goes through the context projector');
      final Offset centroid = _brightestCentroid(bytes);
      expect((centroid - target).distance, lessThanOrEqualTo(centreTolerancePx), reason: 'brightest pixel centroid $centroid vs projected fix $target');
    });

    test('currentFix null: the halo falls back to the canvas centre and the projector is never called', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      addTearDown(renderer.dispose);
      final List<GeoPoint> projected = <GeoPoint>[];
      final Uint8List bytes = await renderToBytes(
        renderer,
        context: spyContext(target: const Offset(60.0, 200.0), projected: projected),
      );
      expect(projected, isEmpty);
      const Offset canvasCentre = Offset(_canvasPx / 2, _canvasPx / 2);
      expect((_brightestCentroid(bytes) - canvasCentre).distance, lessThanOrEqualTo(centreTolerancePx));
    });

    test('candlelight_mirk_renderer.dart no longer imports mirk_projection (projection comes from the context)', () {
      final List<String> importLines = File(
        'lib/infrastructure/mirk/candlelight_mirk_renderer.dart',
      ).readAsLinesSync().where((String line) => line.startsWith('import ')).toList();
      expect(importLines.where((String line) => line.contains('mirk_projection')), isEmpty);
      expect(importLines.where((String line) => line.contains('tile_cell_iteration')), isEmpty);
    });
  });
}

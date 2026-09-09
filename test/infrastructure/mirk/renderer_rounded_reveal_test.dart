// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-006 regression test — guards against the "stair-step grid of squares"
// pattern around the reveal radius. Moved from
// `test/presentation/widgets/mirk_overlay_rounded_reveal_test.dart` in Phase
// 09.1 plan 09.1-06 (C4): the suite never touched `MirkOverlay`; it exercises
// the four builtin renderers under the composition the `FogLayer` applies
// (ONE `clipPath(rect − discs)` per frame, then `renderer.paint`), reproduced
// by `renderToBytes` / `paintLikeFogLayer` in `_render_helpers.dart`.
//
// Strategy (BUG-010 Option B Commit 5 port): render a single fully-fogged
// scene with ONE reveal disc at the centre of the viewport. The disc's hole
// boundary in the rendered image must be SOFT (alpha transitions smoothly
// between fog and clear) rather than HARD (a binary step function). The
// shared clip cuts a hard, anti-aliased hole (≤ 1 px of transition); the
// renderer's feather widens the transition on the fog side of the edge to
// several pixels.
//
// Discrimination: without the feather only the AA pixels at the hole edge
// contribute (typically 1-2 pixels total across both edges of the scanline).
// With the feather → ≥ 3 pixels of intermediate alpha (anything strictly
// between 16 and 240).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

import '../../_helpers/mirk_paint_context_builder.dart';
import '_render_helpers.dart';

/// Centre pixel of the 256×256 canvas — the reveal disc lands there.
const int _centrePx = 128;

/// Pixel-ratio of the reference device the BUG-006 fixture was tuned on.
const double _fixturePixelRatio = 4.0;

/// Single-disc context at the viewport centre. 1° viewport ≈ 110 km × 80 km
/// at 43° lat; an 8000 m radius yields a ~18 px hole — wide enough for the
/// feather to span several intermediate-alpha pixels yet narrow enough that
/// the sample range crosses both edges of the hole.
MirkPaintContext _singleHoleContext({int elapsedMs = 1000}) {
  final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
  final disc = RevealDisc(id: 'rvd_rounded_centre', sessionId: 'sess_test', lat: 43.5, lon: 5.5, radiusMeters: 8000.0, fixedAtUtc: DateTime.utc(2026, 4, 26));
  return buildTestMirkPaintContext(
    zoomLevel: 14.0,
    pixelRatio: _fixturePixelRatio,
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: viewport,
    discs: <RevealDisc>[disc],
  );
}

/// Counts pixels along a horizontal scanline at [y] within `[xMin, xMax)`
/// that have alpha strictly between 16 and 240 (i.e. neither fully clear
/// nor fully fog — an intermediate-alpha pixel produced by the feather).
int _countIntermediateAlphaPixels(Uint8List rgba, {required int y, required int xMin, required int xMax}) {
  var count = 0;
  for (var x = xMin; x < xMax; x++) {
    final a = alphaAt(rgba, x: x, y: y);
    if (a > 16 && a < 240) count++;
  }
  return count;
}

/// The four builtin renderers, freshly constructed per call (each test owns and disposes its own).
List<(String, MirkRenderer)> _builtinRenderers() => <(String, MirkRenderer)>[
  ('atmospheric', AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig)),
  ('candlelight', CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig)),
  ('heavenly_clouds', HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig)),
  ('solid', SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig)),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-006 — rounded reveal corners (feather on the fog side of the shared clip)', () {
    // Scanline crosses the disc horizontally through its centre at y=128.
    // Sample a range that brackets the disc edge transitions on both
    // sides — start before the west edge, end after the east edge.
    const scanlineY = _centrePx;
    const sampleXMin = 100;
    const sampleXMax = 156;
    // Threshold: expect >= 3 intermediate-alpha pixels (the rounded
    // transition spans at least 1.5 px on each side of the hole). With no
    // feather only the AA pixels at the hole edge contribute (1-2 pixels).
    const minIntermediateAlphaPixels = 3;

    for (final (String name, MirkRenderer renderer) in _builtinRenderers()) {
      test('$name: hole edge has >= $minIntermediateAlphaPixels intermediate-alpha pixels (rounded)', () async {
        addTearDown(renderer.dispose);
        final bytes = await renderToBytes(renderer, context: _singleHoleContext());
        final intermediates = _countIntermediateAlphaPixels(bytes, y: scanlineY, xMin: sampleXMin, xMax: sampleXMax);
        expect(
          intermediates,
          greaterThanOrEqualTo(minIntermediateAlphaPixels),
          reason:
              '$name hole edge must show $minIntermediateAlphaPixels+ intermediate-alpha pixels '
              '(the feather rounding). Got $intermediates. A near-zero count means the '
              'renderer paints a hard edge right at the shared clip.',
        );
      });
    }
  });

  group('09.1-06 — clip ownership: the shared clip cuts the hole, every renderer fills the rest', () {
    for (final (String name, MirkRenderer renderer) in _builtinRenderers()) {
      test('$name: centre pixel transparent (hole), corner pixel covered (fog) under the shared clip', () async {
        addTearDown(renderer.dispose);
        final bytes = await renderToBytes(renderer, context: _singleHoleContext());
        expect(
          alphaAt(bytes, x: _centrePx, y: _centrePx),
          0,
          reason: '$name: the hole interior is clipped out by the FogLayer clip',
        );
        expect(alphaAt(bytes, x: 2, y: 2), greaterThan(0), reason: '$name: fog covers the viewport outside the hole');
      });
    }
  });
}

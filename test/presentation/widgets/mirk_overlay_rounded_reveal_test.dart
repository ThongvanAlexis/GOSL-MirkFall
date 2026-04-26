// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-006 regression test — guards against the "stair-step grid of squares"
// pattern around the reveal radius.
//
// Strategy (BUG-010 Option B Commit 5 port): render a single fully-fogged
// scene with ONE 100 m reveal disc at the centre of the viewport. The
// disc's hole boundary in the rendered image must be SOFT (alpha
// transitions smoothly between fog and clear) rather than HARD (a binary
// step function). With BlurStyle.normal applied, the transition spans
// several pixels; with no mask filter the transition is at most 1 pixel
// wide because Skia rasterises path edges with sub-pixel anti-aliasing
// only.
//
// Pre-Commit-5 the fixture was a single-cell-revealed bitmap on a 64×64
// grid. The continuous-geometry equivalent is a single disc — cleaner
// silhouette, no row-coalescing artefacts to confuse the alpha-band
// counter.
//
// Discrimination: pre-fix (no blur leaking into hole) → only ~1 pixel of
// transition between alpha=0 (hole interior) and alpha=255 (fog interior).
// Post-fix (BlurStyle.normal sigma > 0) → ≥ 3 pixels of intermediate
// alpha (anything strictly between 16 and 240).

import 'dart:typed_data';
import 'dart:ui' as ui;

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

/// Single-tile canvas — one viewport fills the entire 256×256 area. The
/// reveal disc lands at the canvas centre (128, 128) at radius ≈ 24 px
/// (scaled from a 100 m disc against a 1° × 1° viewport).
const ui.Size _canvasSize = ui.Size(256, 256);

/// Renders [renderer] over a single-disc fog scene and decodes the result
/// as raw RGBA.
Future<Uint8List> _renderSingleHole(MirkRenderer renderer, {int elapsedMs = 1000}) async {
  final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
  // Disc at the centre of the viewport, radius chosen so the hole spans
  // ~16-30 px of the 256-px canvas — wide enough for the blur to span
  // multiple intermediate-alpha pixels yet narrow enough that the
  // sample range (24 px) crosses both edges of the hole.
  // 1° viewport ≈ 110 km × 80 km at 43° lat. 1500 m radius → ~3.5 px
  // hole radius — too small. 8000 m radius → ~20 px hole radius — good.
  final disc = RevealDisc(id: 'rvd_rounded_centre', sessionId: 'sess_test', lat: 43.5, lon: 5.5, radiusMeters: 8000.0, fixedAtUtc: DateTime.utc(2026, 4, 26));
  final context = MirkPaintContext(
    zoomLevel: 14.0,
    pixelRatio: 4.0,
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: viewport,
    discs: <RevealDisc>[disc],
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, _canvasSize.width, _canvasSize.height), ui.Paint()..color = const ui.Color(0x00000000));
  renderer.paint(canvas, _canvasSize, context);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_canvasSize.width.toInt(), _canvasSize.height.toInt());
  final byteData = await image.toByteData();
  picture.dispose();
  image.dispose();
  if (byteData == null) {
    throw StateError('toByteData returned null — image rasterisation failed');
  }
  return byteData.buffer.asUint8List();
}

/// Counts pixels along a horizontal scanline at [y] within `[xMin, xMax)`
/// that have alpha strictly between 16 and 240 (i.e. neither fully clear
/// nor fully fog — an intermediate-alpha pixel produced by mask blur).
int _countIntermediateAlphaPixels(Uint8List rgba, {required int y, required int xMin, required int xMax}) {
  final width = _canvasSize.width.toInt();
  var count = 0;
  for (var x = xMin; x < xMax; x++) {
    final idx = (y * width + x) * 4;
    final a = rgba[idx + 3];
    if (a > 16 && a < 240) count++;
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-006 — rounded reveal corners (BlurStyle.normal applied)', () {
    // Scanline crosses the disc horizontally through its centre at y=128.
    // Sample a range that brackets the disc edge transitions on both
    // sides — start before the west edge, end after the east edge.
    const scanlineY = 128;
    const sampleXMin = 100;
    const sampleXMax = 156;
    // Threshold: post-fix expect >= 3 intermediate-alpha pixels (the
    // rounded transition spans at least 1.5 px on each side of the
    // hole). Pre-fix with no blur leaking inward, only the AA pixels at
    // the hole edge contribute (typically 1-2 pixels total).
    const minIntermediateAlphaPixels = 3;

    test('atmospheric: hole edge has >= $minIntermediateAlphaPixels intermediate-alpha pixels (rounded)', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      final bytes = await _renderSingleHole(renderer);
      final intermediates = _countIntermediateAlphaPixels(bytes, y: scanlineY, xMin: sampleXMin, xMax: sampleXMax);
      expect(
        intermediates,
        greaterThanOrEqualTo(minIntermediateAlphaPixels),
        reason:
            'Atmospheric hole edge must show $minIntermediateAlphaPixels+ intermediate-alpha '
            'pixels (the BlurStyle.normal feather rounding). Got $intermediates. '
            'A near-zero count means MaskFilter.blur is missing or BlurStyle is set '
            'to inner-only (pre-BUG-006 behaviour).',
      );
      await renderer.dispose();
    });

    test('candlelight: hole edge has >= $minIntermediateAlphaPixels intermediate-alpha pixels (rounded)', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      final bytes = await _renderSingleHole(renderer);
      final intermediates = _countIntermediateAlphaPixels(bytes, y: scanlineY, xMin: sampleXMin, xMax: sampleXMax);
      expect(
        intermediates,
        greaterThanOrEqualTo(minIntermediateAlphaPixels),
        reason: 'Candlelight hole edge must show >= $minIntermediateAlphaPixels feathered transition pixels. Got $intermediates.',
      );
      await renderer.dispose();
    });

    test('heavenly_clouds: hole edge has >= $minIntermediateAlphaPixels intermediate-alpha pixels (rounded)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final bytes = await _renderSingleHole(renderer);
      final intermediates = _countIntermediateAlphaPixels(bytes, y: scanlineY, xMin: sampleXMin, xMax: sampleXMax);
      expect(
        intermediates,
        greaterThanOrEqualTo(minIntermediateAlphaPixels),
        reason: 'HeavenlyClouds hole edge must show >= $minIntermediateAlphaPixels feathered transition pixels. Got $intermediates.',
      );
      await renderer.dispose();
    });

    test('solid: hole edge has >= $minIntermediateAlphaPixels intermediate-alpha pixels (rounded)', () async {
      // Solid was added to the BlurStyle.normal cohort in BUG-006 too —
      // visual consistency across the 4 builtins.
      final renderer = SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig);
      final bytes = await _renderSingleHole(renderer);
      final intermediates = _countIntermediateAlphaPixels(bytes, y: scanlineY, xMin: sampleXMin, xMax: sampleXMax);
      expect(
        intermediates,
        greaterThanOrEqualTo(minIntermediateAlphaPixels),
        reason: 'Solid hole edge must show >= $minIntermediateAlphaPixels feathered transition pixels. Got $intermediates.',
      );
      await renderer.dispose();
    });
  });
}

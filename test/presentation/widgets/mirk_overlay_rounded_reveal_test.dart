// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-006 regression test — guards against the "stair-step grid of squares"
// pattern around the reveal radius.
//
// Strategy: render a single fully-fogged tile that has ONE revealed cell
// in the middle. The cell's hole boundary in the rendered image must be
// SOFT (alpha transitions smoothly between fog and clear) rather than
// HARD (a binary step function). With BlurStyle.normal applied, the
// transition spans several pixels; with no mask filter (or BlurStyle.inner
// only — the pre-fix behaviour), the transition is at most 1 pixel wide
// because Skia rasterises path edges with sub-pixel anti-aliasing only,
// not blur.
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
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

/// Single-tile canvas — one tile fills the entire 256×256 area, so the
/// 64×64 cell grid resolves at 4 px / cell. A single revealed cell at
/// the centre (col 32, row 32) maps to a 4×4 hole at pixel (128, 128).
/// We sample alpha along a horizontal line crossing this hole and assert
/// the transition is gradual.
const ui.Size _canvasSize = ui.Size(256, 256);

/// Builds a 512-byte bitmap with EXACTLY one revealed cell at column
/// [col], row [row]. All other cells stay unrevealed.
Uint8List _bitmapWithOneRevealedCell({required int col, required int row}) {
  final bytes = Uint8List(512);
  final bitIndex = row * 64 + col;
  bytes[bitIndex >> 3] |= 1 << (bitIndex & 7);
  return bytes;
}

/// Renders [renderer] over a single-tile fog scene with one revealed
/// cell at the centre and decodes the result as raw RGBA.
Future<Uint8List> _renderSingleHole(MirkRenderer renderer, {int elapsedMs = 1000}) async {
  final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
  final tile = VisibleMirkTile(
    parentX: 8456,
    parentY: 5959,
    bitmap: _bitmapWithOneRevealedCell(col: 32, row: 32),
    tileNorthLat: 44.0,
    tileWestLon: 5.0,
    tileSouthLat: 43.0,
    tileEastLon: 6.0,
  );
  final context = MirkPaintContext(
    zoomLevel: 14.0,
    // pixelRatio 4.0 inflates featherSigma from ~0.4 px to ~1.6 px —
    // small but enough to span >= 3 intermediate-alpha pixels at a 4 px
    // cell boundary, which is the discrimination threshold below.
    pixelRatio: 4.0,
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: viewport,
    visibleTiles: [tile],
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
    // Scanline crosses the hole vertically through its centre. With a
    // 4 px cell at (col 32, row 32), the hole occupies x in [128, 132)
    // at y=128–132. Sampling y=130 (mid-hole) and the x range
    // [120, 144) — covering 8 px of fog, the 4 px hole, 8 px more fog
    // and a couple of safety margin px — captures both edges of the
    // hole including their feathered transition.
    const scanlineY = 130;
    const sampleXMin = 120;
    const sampleXMax = 144;
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

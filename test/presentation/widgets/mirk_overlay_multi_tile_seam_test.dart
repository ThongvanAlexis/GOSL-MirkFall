// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-003 (issue A) regression test — guards against the "damier"
// pattern produced by `BlurStyle.inner` over a path of 4096 disjoint
// cell rects per tile.
//
// Strategy: paint each of the 3 mask-filtered renderers
// (atmospheric / candlelight / heavenly_clouds) over a 2x2 layout of
// fully-unrevealed tiles arranged so they tile a 512x512 canvas with
// no gaps. Then sample interior pixels across the tile seams and assert
// that the cumulative alpha is high — i.e. the basemap does NOT leak
// through. With the pre-fix path strategy this test fails because the
// inner-blur erodes alpha along every cell-cell internal edge, dropping
// alpha towards zero at hundreds of locations inside each tile.
//
// Solid is excluded — it has no mask filter and never showed the bug;
// the existing solid_fill_mirk_renderer_test already covers it.

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

import '../../infrastructure/mirk/_render_helpers.dart';

/// Canvas size matching the 2x2 tile layout (256 px per tile).
const ui.Size _canvasSize = ui.Size(512, 512);

/// Builds a [MirkPaintContext] that places 4 fully-unrevealed parent
/// tiles in a 2x2 grid spanning the entire canvas. Tile lat/lon
/// extents are arbitrary but consistent across the 4 tiles so the
/// projection lays them out edge-to-edge.
MirkPaintContext _twoByTwoFogContext({int elapsedMs = 1000}) {
  // Viewport spans 1° lat × 2° lon, mapped to 512x512 px.
  // Each tile is 0.5° lat × 1° lon → 256 px on each axis.
  final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 7.0);
  final tiles = <VisibleMirkTile>[
    VisibleMirkTile(
      parentX: 8456,
      parentY: 5959,
      bitmap: makeAllUnrevealedBitmap(),
      tileNorthLat: 44.0,
      tileWestLon: 5.0,
      tileSouthLat: 43.5,
      tileEastLon: 6.0,
    ),
    VisibleMirkTile(
      parentX: 8457,
      parentY: 5959,
      bitmap: makeAllUnrevealedBitmap(),
      tileNorthLat: 44.0,
      tileWestLon: 6.0,
      tileSouthLat: 43.5,
      tileEastLon: 7.0,
    ),
    VisibleMirkTile(
      parentX: 8456,
      parentY: 5960,
      bitmap: makeAllUnrevealedBitmap(),
      tileNorthLat: 43.5,
      tileWestLon: 5.0,
      tileSouthLat: 43.0,
      tileEastLon: 6.0,
    ),
    VisibleMirkTile(
      parentX: 8457,
      parentY: 5960,
      bitmap: makeAllUnrevealedBitmap(),
      tileNorthLat: 43.5,
      tileWestLon: 6.0,
      tileSouthLat: 43.0,
      tileEastLon: 7.0,
    ),
  ];
  // pixelRatio 4.0 inflates featherSigma from ~0.8 px to ~3.2 px —
  // enough that the pre-BUG-003 path-of-4096-cells strategy produces a
  // visible damier (alpha eroded over a wide band along every cell-cell
  // internal edge). pixelRatio matches a typical iOS @3x or Android xxhdpi
  // device so the test exercises a realistic feather scale.
  return MirkPaintContext(
    zoomLevel: 14.0,
    pixelRatio: 4.0,
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: viewport,
    visibleTiles: tiles,
  );
}

/// Paints [renderer] across the 2x2 fog layout and decodes the output
/// as a raw RGBA byte buffer.
Future<Uint8List> _renderTwoByTwo(MirkRenderer renderer, {int elapsedMs = 1000}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // Transparent base — pixels the renderer doesn't touch stay alpha=0
  // so the test can detect leakage.
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, _canvasSize.width, _canvasSize.height), ui.Paint()..color = const ui.Color(0x00000000));
  renderer.paint(canvas, _canvasSize, _twoByTwoFogContext(elapsedMs: elapsedMs));
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

/// Returns the alpha byte at pixel ([x], [y]).
int _alphaAt(Uint8List rgba, int x, int y) {
  final width = _canvasSize.width.toInt();
  final idx = (y * width + x) * 4;
  return rgba[idx + 3];
}

/// Returns the minimum alpha along the horizontal seam at y=[seamY]
/// across the seamline x range [xMin, xMax). Pre-fix per-tile feather
/// cumulation drops alpha at seam pixels by 2x; post-fix the seam is
/// continuous (no feather inside the global fog union).
int _minAlphaAlongHorizontalSeam(Uint8List rgba, {required int seamY, required int xMin, required int xMax}) {
  var minA = 255;
  for (var x = xMin; x < xMax; x++) {
    final a = _alphaAt(rgba, x, seamY);
    if (a < minA) minA = a;
  }
  return minA;
}

/// Returns the minimum alpha along the vertical seam at x=[seamX]
/// across the seamline y range [yMin, yMax).
int _minAlphaAlongVerticalSeam(Uint8List rgba, {required int seamX, required int yMin, required int yMax}) {
  var minA = 255;
  for (var y = yMin; y < yMax; y++) {
    final a = _alphaAt(rgba, seamX, y);
    if (a < minA) minA = a;
  }
  return minA;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-003 — multi-tile seam (no damier across 2x2 fog layout)', () {
    // 2x2 tile layout on a 512x512 canvas → tile boundaries fall on
    // x=256 (between west and east columns) and y=256 (between north
    // and south rows).
    const horizontalSeamY = 256;
    const verticalSeamX = 256;
    // Sample range along each seam — exclude the outer 32 px on each
    // end (those are inside the intentional viewport-edge feather).
    const seamSampleMin = 32;
    const seamSampleMax = 480;
    // Threshold on the per-pixel minimum alpha along each seam.
    // The intentional feather sigma at pixelRatio=4 is roughly 3.2 px;
    // the inner-blur erodes alpha smoothly across that range. With
    // viewport-level rendering (post-BUG-003 fix) the seam pixels lie
    // INSIDE the global fog silhouette and are NOT eroded — alpha
    // stays above ~200 (close to the renderer's baseline alpha × 255).
    // With per-tile rendering (pre-BUG-003) each tile's outer edge is
    // ON the seam, so BOTH tiles erode alpha there → seam pixels drop
    // below ~100 even with cumulative compositing of two semi-
    // transparent fog layers. 150 is comfortably between both regimes.
    const minSeamAlpha = 150;

    test('atmospheric: seam pixels stay above $minSeamAlpha (no damier)', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      final bytes = await _renderTwoByTwo(renderer);
      final hMin = _minAlphaAlongHorizontalSeam(bytes, seamY: horizontalSeamY, xMin: seamSampleMin, xMax: seamSampleMax);
      final vMin = _minAlphaAlongVerticalSeam(bytes, seamX: verticalSeamX, yMin: seamSampleMin, yMax: seamSampleMax);
      expect(
        hMin,
        greaterThan(minSeamAlpha),
        reason:
            'Atmospheric horizontal-seam minimum alpha = $hMin, expected > $minSeamAlpha. '
            'Pre-BUG-003 per-tile feather cumulation halves alpha at seams. Check '
            'atmospheric_mirk_renderer.dart uses buildViewportFogClipPath, NOT a per-tile loop.',
      );
      expect(vMin, greaterThan(minSeamAlpha), reason: 'Atmospheric vertical-seam minimum alpha = $vMin, expected > $minSeamAlpha.');
      await renderer.dispose();
    });

    test('candlelight: seam pixels stay above $minSeamAlpha (no damier)', () async {
      final renderer = CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig);
      final bytes = await _renderTwoByTwo(renderer);
      final hMin = _minAlphaAlongHorizontalSeam(bytes, seamY: horizontalSeamY, xMin: seamSampleMin, xMax: seamSampleMax);
      final vMin = _minAlphaAlongVerticalSeam(bytes, seamX: verticalSeamX, yMin: seamSampleMin, yMax: seamSampleMax);
      expect(
        hMin,
        greaterThan(minSeamAlpha),
        reason:
            'Candlelight horizontal-seam minimum alpha = $hMin, expected > $minSeamAlpha. '
            'Check candlelight_mirk_renderer.dart uses buildViewportFogClipPath.',
      );
      expect(vMin, greaterThan(minSeamAlpha), reason: 'Candlelight vertical-seam minimum alpha = $vMin, expected > $minSeamAlpha.');
      await renderer.dispose();
    });

    test('heavenly_clouds: seam pixels stay above $minSeamAlpha (no damier)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final bytes = await _renderTwoByTwo(renderer);
      final hMin = _minAlphaAlongHorizontalSeam(bytes, seamY: horizontalSeamY, xMin: seamSampleMin, xMax: seamSampleMax);
      final vMin = _minAlphaAlongVerticalSeam(bytes, seamX: verticalSeamX, yMin: seamSampleMin, yMax: seamSampleMax);
      expect(
        hMin,
        greaterThan(minSeamAlpha),
        reason:
            'HeavenlyClouds horizontal-seam minimum alpha = $hMin, expected > $minSeamAlpha. '
            'Check heavenly_clouds_mirk_renderer.dart uses buildViewportFogClipPath.',
      );
      expect(vMin, greaterThan(minSeamAlpha), reason: 'HeavenlyClouds vertical-seam minimum alpha = $vMin, expected > $minSeamAlpha.');
      await renderer.dispose();
    });
  });
}

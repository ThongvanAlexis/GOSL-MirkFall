// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-004 regression test — guards against the "uniform fog with no
// visible noise pattern" regression that the BUG-003 fix introduced
// when it collapsed per-tile noise modulation into a single global
// alpha sample.
//
// Strategy:
//
//  (1) Pixel-spatial variance — render the renderer over a fully-
//      fogged tile, await the noise texture's async build, then sample
//      a 64-pixel-wide horizontal strip inside the fog. With the noise
//      overlay applied via ImageShader + softLight, those pixels have
//      visibly different RGB values (variance > threshold). Without
//      the overlay (regression), every pixel has the same RGB (a
//      single fog colour), variance ≈ 0.
//
//  (2) Temporal motion — render two frames at sessionElapsed=0 and
//      sessionElapsed=5s. Sample the SAME pixel at the same location
//      in both frames. The noise pattern's translation matrix evolves
//      over time, so the same pixel's RGB differs between frames.
//      Pre-fix the only inter-frame difference was the alpha pulse,
//      which is too subtle to discriminate at our threshold.
//
// We test both atmospheric and heavenly_clouds — the 2 renderers that
// the bug doc identified as missing the texture. Candlelight uses a
// radial gradient + flicker which is a fundamentally different visual,
// not the "moving noise" path; not in scope for this bug.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/mirk/visible_mirk_tile.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';

import '_render_helpers.dart';

/// Builds a context with a SINGLE fully-unrevealed tile filling the
/// entire test canvas. No holes → no rounded-reveal interference with
/// pixel sampling. Default canvas is 256×256 (see [kTestCanvasSize]).
MirkPaintContext _fullyFoggedContext({int elapsedMs = 0}) {
  final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
  return MirkPaintContext(
    zoomLevel: 14.0,
    pixelRatio: 1.0,
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: viewport,
    visibleTiles: <VisibleMirkTile>[
      VisibleMirkTile(
        parentX: 8456,
        parentY: 5959,
        bitmap: makeAllUnrevealedBitmap(),
        tileNorthLat: 44.0,
        tileWestLon: 5.0,
        tileSouthLat: 43.0,
        tileEastLon: 6.0,
      ),
    ],
  );
}

/// Renders [renderer] and decodes raw RGBA. Wrapper around
/// [renderToBytes] that uses the fully-fogged scene.
Future<Uint8List> _renderFog(MirkRenderer renderer, {int elapsedMs = 0}) {
  return renderToBytes(renderer, context: _fullyFoggedContext(elapsedMs: elapsedMs));
}

/// Returns the RGB triplet at pixel ([x], [y]) on a [width]×N RGBA byte
/// buffer (alpha ignored).
({int r, int g, int b}) _rgbAt(Uint8List rgba, int width, int x, int y) {
  final idx = (y * width + x) * 4;
  return (r: rgba[idx], g: rgba[idx + 1], b: rgba[idx + 2]);
}

/// Computes the standard-deviation of a single RGB channel across pixels
/// [xMin, xMax) on row [y]. With uniform-fog rendering, all pixels in
/// the strip have the same channel value → stdev = 0. With visible
/// noise overlay, the softLight blend between fog colour and the noise
/// grayscale produces variation → stdev > threshold.
double _channelStdevAlongRow(Uint8List rgba, {required int width, required int y, required int xMin, required int xMax, required int channelOffset}) {
  final values = <int>[];
  for (var x = xMin; x < xMax; x++) {
    final idx = (y * width + x) * 4 + channelOffset;
    values.add(rgba[idx]);
  }
  final mean = values.reduce((a, b) => a + b) / values.length;
  var sumSq = 0.0;
  for (final v in values) {
    final d = v - mean;
    sumSq += d * d;
  }
  return (sumSq / values.length).clamp(0.0, double.infinity).toDouble();
  // ^ returns variance, not stdev — but variance > threshold is the
  // same discrimination signal at lower compute cost (skip sqrt).
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-004 — visible animated noise overlay', () {
    // Pixel sampling parameters — interior strip away from any blur
    // affecting the viewport edges. Canvas is 256×256.
    const width = 256;
    const sampleY = 128;
    const sampleXMin = 32;
    const sampleXMax = 224; // 192 px wide strip
    // Threshold on per-channel variance. Empirically:
    //   - Uniform fog (no noise overlay): variance < 1 (all pixels
    //     equal up to AA jitter at edges, none of which fall in the
    //     interior strip).
    //   - With noise overlay (atmospheric, alpha 128): variance > 30
    //     (softLight blend produces visible RGB variation).
    // 10 sits comfortably between the regimes.
    const minNoiseVariance = 10.0;

    test('atmospheric: fog has visible spatial RGB variance (noise overlay applied)', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      // Wait for the noise texture's async build.
      await renderer.noiseReady;
      final bytes = await _renderFog(renderer, elapsedMs: 1000);
      final variance = _channelStdevAlongRow(bytes, width: width, y: sampleY, xMin: sampleXMin, xMax: sampleXMax, channelOffset: 0);
      expect(
        variance,
        greaterThan(minNoiseVariance),
        reason:
            'Atmospheric must paint a visibly textured fog (noise variance > $minNoiseVariance). Got $variance. '
            'A near-zero value means the noise overlay is not being applied — the renderer is producing '
            'uniform-coloured fog (BUG-004 regression).',
      );
      await renderer.dispose();
    });

    test('atmospheric: noise pattern moves between frames (same pixel differs)', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      await renderer.noiseReady;
      final bytes0 = await _renderFog(renderer);
      final bytes5 = await _renderFog(renderer, elapsedMs: 5000);
      // Sample 16 different pixels along the strip. Atomic-pixel RGB
      // diffs are noisy (even uniform-alpha pulse causes ~1-byte jitter
      // due to softLight blend math), so we count "pixels whose R-byte
      // changed by >= 5 between t=0 and t=5s" and require >= 4 of 16.
      // With static noise (no translation), zero pixels would clear the
      // 5-byte threshold. With translation at 30 px/s × 5s = 150 px of
      // shift, every interior pixel sees an entirely different sample
      // → easily >= 4 / 16.
      var movedCount = 0;
      for (var i = 0; i < 16; i++) {
        final x = sampleXMin + (sampleXMax - sampleXMin) * i ~/ 16;
        final rgb0 = _rgbAt(bytes0, width, x, sampleY);
        final rgb5 = _rgbAt(bytes5, width, x, sampleY);
        if ((rgb0.r - rgb5.r).abs() >= 5) movedCount++;
      }
      expect(
        movedCount,
        greaterThanOrEqualTo(4),
        reason:
            'Atmospheric noise pattern must visibly translate between frames at 5s apart. '
            'Pixels with R-byte delta >= 5: $movedCount / 16. A near-zero count means the '
            'shader translation matrix is not animating with sessionElapsed.',
      );
      await renderer.dispose();
    });

    test('heavenly_clouds: fog has visible spatial RGB variance (cloud texture applied)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      await renderer.noiseReady;
      final bytes = await _renderFog(renderer, elapsedMs: 1000);
      final variance = _channelStdevAlongRow(bytes, width: width, y: sampleY, xMin: sampleXMin, xMax: sampleXMax, channelOffset: 0);
      expect(
        variance,
        greaterThan(minNoiseVariance),
        reason: 'HeavenlyClouds must paint a visibly textured fog (variance > $minNoiseVariance). Got $variance.',
      );
      await renderer.dispose();
    });

    test('heavenly_clouds: noise pattern moves between frames (same pixel differs)', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      await renderer.noiseReady;
      final bytes0 = await _renderFog(renderer);
      final bytes5 = await _renderFog(renderer, elapsedMs: 5000);
      var movedCount = 0;
      for (var i = 0; i < 16; i++) {
        final x = sampleXMin + (sampleXMax - sampleXMin) * i ~/ 16;
        final rgb0 = _rgbAt(bytes0, width, x, sampleY);
        final rgb5 = _rgbAt(bytes5, width, x, sampleY);
        if ((rgb0.r - rgb5.r).abs() >= 5) movedCount++;
      }
      expect(movedCount, greaterThanOrEqualTo(4), reason: 'HeavenlyClouds noise pattern must visibly drift between frames. Pixels moved: $movedCount / 16.');
      await renderer.dispose();
    });

    test('atmospheric: pre-noise-ready paint is a no-op overlay (solid fog only) and does not throw', () async {
      // Construction kicks off the async noise build — but if paint is
      // called immediately (before `noiseReady` resolves), the
      // renderer must NOT crash; it should just paint the solid fog
      // pass without the noise overlay. This guards the "first frame
      // before texture loaded" production path.
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      // Do NOT await noiseReady. Render immediately.
      final bytes = await _renderFog(renderer);
      // Sanity: the fog was actually painted (alpha is not zero) — if
      // the renderer aborted, every pixel would have alpha=0.
      final width = 256;
      final centreIdx = (128 * width + 128) * 4;
      expect(bytes[centreIdx + 3], greaterThan(200), reason: 'solid-fog fallback must paint visible fog at the canvas centre (alpha>200)');
      await renderer.dispose();
    });

    test('candlelight is intentionally NOT in the noise-overlay cohort (radial gradient + flicker)', () {
      // Documentation test: candlelight uses a different visual idiom
      // (radial gradient anchored on the GPS fix + 1D flicker) — not
      // a moving noise pattern. BUG-004 is scoped to atmospheric +
      // heavenly_clouds; reading this test should make that scope
      // boundary obvious to a future investigator.
      expect(true, isTrue);
    });
  });
}

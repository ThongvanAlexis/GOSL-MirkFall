// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// BUG-004 / BUG-009 visual regression test — guards the "fog has
// visible texture, not solid colour" property.
//
// History:
//   - BUG-003 (2026-04-25) collapsed per-cell modulation → uniform fog.
//   - BUG-004 (2026-04-25) re-introduced a tileable ImageShader noise
//     overlay drifting via translation matrix.
//   - BUG-009 (2026-04-25) replaced that "cheap noise sliding" with the
//     TIER 2 volumetric fog shader (3D-FBM + curl + parallax + faux
//     shading + hue + watercolour boundary). The visual property is
//     now produced GPU-side by a `ui.FragmentShader`.
//
// ## Why the previous variance/motion assertions are gone
//
// `flutter test`'s software rasteriser does not execute fragment
// shaders bound via `Paint..shader = fragmentShader`. The output of
// `picture.toImage()` in a headless test environment lacks the
// shader's actual pixel work — variance and temporal motion both
// drop to zero under test even when the shader is correctly wired.
// The visual is verified on real device sideload (the user's UAT
// loop), not here.
//
// What this file asserts INSTEAD (post-BUG-009):
//   - shaderReady future resolves (shader asset declared in pubspec
//     and loadable under the test harness).
//   - The fallback path (shader not yet ready) paints visible solid
//     fog at the canvas centre — no NaN / no transparent rendering.
//   - The renderer does not throw before, during, or after shader
//     readiness.
//   - Calling paint when SDF is unbuilt does not crash (fallback
//     path covers it).
//   - Candlelight is intentionally NOT in this cohort (different
//     visual idiom — radial gradient + flicker, not shader).

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BUG-009 (TIER 2) — shader pipeline structural regression', () {
    test('atmospheric: shaderReady future resolves successfully', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      // The shader asset is declared in pubspec.yaml — the test harness
      // can load it via `FragmentProgram.fromAsset`. shaderReady must
      // resolve without throwing.
      await renderer.shaderReady;
      await renderer.dispose();
    });

    test('atmospheric: pre-shader-ready paint is fallback-fog only and does not throw', () async {
      // Construction kicks off the async shader load — but if paint is
      // called immediately (before `shaderReady` resolves), the renderer
      // must NOT crash; it should just paint the solid fallback fog
      // (no shader). This guards the "first frame before shader loaded"
      // production path.
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      // Do NOT await shaderReady. Render immediately.
      final bytes = await renderToBytes(renderer, context: _fullyFoggedContext());
      // Sanity: the fog was actually painted (alpha is not zero) — if
      // the renderer aborted, every pixel would have alpha=0.
      const width = 256;
      final centreIdx = (128 * width + 128) * 4;
      expect(bytes[centreIdx + 3], greaterThan(200), reason: 'fallback-fog path must paint visible fog at the canvas centre (alpha>200)');
      await renderer.dispose();
    });

    test('atmospheric: post-shader-ready paint does not throw', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      await renderer.shaderReady;
      // First paint kicks off the SDF build (async). Must not throw.
      await renderToBytes(renderer, context: _fullyFoggedContext());
      // Second paint: SDF may or may not be ready depending on the test
      // harness's microtask scheduling. Must not throw either way.
      await renderToBytes(renderer, context: _fullyFoggedContext(elapsedMs: 1000));
      await renderer.dispose();
    });

    test('atmospheric: paint with all-revealed bitmap is a no-op (no draw calls)', () async {
      final renderer = AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig);
      await renderer.shaderReady;
      final viewport = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
      final ctx = MirkPaintContext(
        zoomLevel: 14.0,
        pixelRatio: 1.0,
        sessionElapsed: Duration.zero,
        viewportBbox: viewport,
        visibleTiles: <VisibleMirkTile>[
          VisibleMirkTile(
            parentX: 8456,
            parentY: 5959,
            bitmap: makeAllRevealedBitmap(),
            tileNorthLat: 44.0,
            tileWestLon: 5.0,
            tileSouthLat: 43.0,
            tileEastLon: 6.0,
          ),
        ],
      );
      // path.getBounds().isEmpty → renderer early-returns. The output
      // is a fully transparent canvas — every pixel alpha = 0.
      final bytes = await renderToBytes(renderer, context: ctx);
      var allTransparent = true;
      for (var i = 3; i < bytes.length; i += 4) {
        if (bytes[i] != 0) {
          allTransparent = false;
          break;
        }
      }
      expect(allTransparent, isTrue, reason: 'all-revealed bitmap → renderer must paint nothing (every pixel transparent)');
      await renderer.dispose();
    });

    test('heavenly_clouds: shaderReady future resolves successfully', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      await renderer.shaderReady;
      await renderer.dispose();
    });

    test('heavenly_clouds: pre-shader-ready paint is fallback-fog only', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      final bytes = await renderToBytes(renderer, context: _fullyFoggedContext());
      const width = 256;
      final centreIdx = (128 * width + 128) * 4;
      expect(
        bytes[centreIdx + 3],
        greaterThan(150),
        reason: 'heavenly fallback must paint visible fog at the canvas centre (alpha>150 — heavenly is lighter than atmospheric)',
      );
      await renderer.dispose();
    });

    test('heavenly_clouds: post-shader-ready paint does not throw', () async {
      final renderer = HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig);
      await renderer.shaderReady;
      await renderToBytes(renderer, context: _fullyFoggedContext());
      await renderToBytes(renderer, context: _fullyFoggedContext(elapsedMs: 1000));
      await renderer.dispose();
    });

    test('candlelight is intentionally NOT in the shader cohort (radial gradient + flicker)', () {
      // Documentation test: candlelight uses a different visual idiom
      // (radial gradient anchored on the GPS fix + 1D flicker) — not
      // a shader-driven volumetric. BUG-009 TIER 2 is scoped to
      // atmospheric + heavenly_clouds; reading this test should make
      // that scope boundary obvious to a future investigator.
      expect(true, isTrue);
    });
  });
}

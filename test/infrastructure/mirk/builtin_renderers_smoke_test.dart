// Copyright (c) 2026 THONGVAN Alexis
// Licensed under the Good Old Software License v1.0
// See LICENSE file for details

// Phase 09 plan 09-04 Task 4 smoke test for the 4 builtin
// `MirkRenderer` implementations (MIRK-06).
//
// Cheap canary that catches missing constructor arguments / null
// derefs / dispose-of-unowned-resource bugs across the variant set in
// one place. Each renderer must:
// - Instantiate with its default config
// - Run paint() on a non-empty context without throwing
// - Run update() without throwing
// - Run dispose() without throwing
//
// Phase 09.1 plan 09.1-06 — the 4 variants are also resolved through the
// registry + factory (the picker's path) and painted under the EXTENDED
// context the `FogLayer` hands out: one disc, a ~1e6 world-pixel origin,
// zoomScale 4, on iOS (identity sdfRect) AND on Android (V-flip sdfRect +
// sign-flipped pixelOrigin.y, FOG-21 / FOG-23). Every variant must keep the
// reveal hole at the centre (the shared clip) and cover the corner.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirkfall/domain/mirk/mirk_paint_context.dart';
import 'package:mirkfall/domain/mirk/mirk_renderer.dart';
import 'package:mirkfall/domain/mirk/mirk_style_config.dart';
import 'package:mirkfall/domain/mirk/mirk_viewport_bbox.dart';
import 'package:mirkfall/domain/revealed/reveal_disc.dart';
import 'package:mirkfall/infrastructure/mirk/atmospheric_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/builtin_mirk_styles.dart';
import 'package:mirkfall/infrastructure/mirk/candlelight_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/heavenly_clouds_mirk_renderer.dart';
import 'package:mirkfall/infrastructure/mirk/mirk_renderer_factory.dart';
import 'package:mirkfall/infrastructure/mirk/shader/fog_platform_corrections.dart';
import 'package:mirkfall/infrastructure/mirk/solid_fill_mirk_renderer.dart';

import '../../_helpers/mirk_paint_context_builder.dart';
import '_render_helpers.dart';

/// Centre pixel of the 256×256 test canvas.
const int _centrePx = 128;

/// Disc radius that yields a ~18 px hole on the 1° × 1° test viewport.
const double _visibleHoleRadiusMeters = 8000.0;

/// Raw camera pixelOrigin at a high zoom (~1e6 / 2e6 magnitudes, FOG-18).
const ({double x, double y}) _highZoomRawPixelOrigin = (x: 1e6, y: 2e6);

/// Camera zoomScale two zoom levels above the reference (z15).
const double _extendedZoomScale = 4.0;

/// Extended context on [isAndroid]: one centre disc + the camera-derived
/// fields as the `FogLayer` produces them (platform corrections applied once).
MirkPaintContext _extendedContext({required bool isAndroid, int elapsedMs = 1000}) {
  final MirkViewportBbox bbox = MirkViewportBbox(south: 43.0, west: 5.0, north: 44.0, east: 6.0);
  final PlatformShaderCorrections corrected = applyPlatformShaderCorrections(pixelOrigin: _highZoomRawPixelOrigin, isAndroid: isAndroid);
  return buildTestMirkPaintContext(
    sessionElapsed: Duration(milliseconds: elapsedMs),
    viewportBbox: bbox,
    discs: <RevealDisc>[singleCentreDisc(bbox: bbox, radiusMeters: _visibleHoleRadiusMeters)],
    pixelOrigin: corrected.pixelOrigin,
    zoomScale: _extendedZoomScale,
    sdfRect: corrected.sdfRect,
  );
}

void main() {
  group('09-04 — 4 builtin renderers smoke (MIRK-06)', () {
    test('all 4 instantiate + paint + update + dispose without throw', () async {
      final renderers = <MirkRenderer>[
        AtmosphericMirkRenderer(const MirkStyleConfig.atmospheric() as AtmosphericConfig),
        SolidFillMirkRenderer(const MirkStyleConfig.solid() as SolidConfig),
        CandlelightMirkRenderer(const MirkStyleConfig.candlelight() as CandlelightConfig),
        HeavenlyCloudsMirkRenderer(const MirkStyleConfig.heavenly() as HeavenlyCloudsConfig),
      ];

      for (final renderer in renderers) {
        final ctx = fakeContext(elapsedMs: 1000);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        // paint must not throw
        expect(() => renderer.paint(canvas, kTestCanvasSize, ctx), returnsNormally, reason: '${renderer.runtimeType}.paint() threw');
        // update must not throw
        expect(() => renderer.update(const Duration(milliseconds: 16)), returnsNormally, reason: '${renderer.runtimeType}.update() threw');
        // Release the picture so the recorder doesn't leak.
        recorder.endRecording().dispose();
        // dispose must not throw + must complete
        await renderer.dispose();
      }
    });
  });

  group('09.1-06 — registry + factory under the extended FogLayer context (iOS + Android)', () {
    const MirkRendererFactory factory = MirkRendererFactory();

    test('the registry still exposes exactly the 4 builtin variants', () {
      expect(kBuiltinMirkStyles.map((BuiltinMirkStyleDescriptor d) => d.id).toList(), <String>[
        'style_builtin_atmospheric',
        'style_builtin_solid',
        'style_builtin_candlelight',
        'style_builtin_heavenly_clouds',
      ]);
    });

    for (final bool isAndroid in <bool>[false, true]) {
      final String platform = isAndroid ? 'Android (V-flip sdfRect, negative pixelOrigin.y)' : 'iOS (identity sdfRect)';

      for (final BuiltinMirkStyleDescriptor descriptor in kBuiltinMirkStyles) {
        test('${descriptor.id} on $platform: paints without throwing, hole at the centre, fog at the corner', () async {
          final MirkRenderer renderer = factory.create(descriptor.defaultConfig());
          addTearDown(renderer.dispose);
          final MirkPaintContext context = _extendedContext(isAndroid: isAndroid);
          final bytes = await renderToBytes(renderer, context: context);
          expect(
            alphaAt(bytes, x: _centrePx, y: _centrePx),
            0,
            reason: '${descriptor.id}: the shared clip cuts the reveal hole',
          );
          expect(alphaAt(bytes, x: 2, y: 2), greaterThan(0), reason: '${descriptor.id}: fog covers the viewport outside the hole');
          expect(() => renderer.update(const Duration(milliseconds: 16)), returnsNormally);
          // A second paint at a later sessionElapsed must be just as safe (timers, SDF scheduling).
          await renderToBytes(renderer, context: _extendedContext(isAndroid: isAndroid, elapsedMs: 2000));
        });
      }
    }
  });
}
